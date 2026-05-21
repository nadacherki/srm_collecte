import 'dart:convert';

/// Moteur d'évaluation des contraintes métier (table
/// `public.attribut_config_mobile.contraintes_regles`, format JSONB).
///
/// Le moteur Dart est le miroir client de `api/constraint_engine.py` côté
/// serveur. Il évalue toutes les actions pour l'UX :
///   - `warn` : alerte visible (n'empêche pas le submit)
///   - `error` : bloque le submit (re-vérifié côté serveur)
///   - `disable_others` : grise tous les champs sauf except_fields
///   - `disable_and_clear` : grise + vide les `fields` cibles
///   - `side_effects` : liste de `{set_field, value}` appliqués au submit
///
/// Schéma d'une règle :
/// ```json
/// {
///   "id":        "kebab-case-unique",
///   "when":      <condition>,
///   "requires_fields": ["..."] (optionnel : skip si l'un null),
///   "action":    "warn" | "error" | "disable_others" | "disable_and_clear",
///   "fields":    [...] (pour disable_and_clear et highlight des warn),
///   "except_fields": [...] (pour disable_others),
///   "side_effects": [{"set_field": "...", "value": ...}],
///   "message":   "string avec interpolation {{field}} ou {{expr}}"
/// }
/// ```
///
/// `<condition>` :
///   `{field, eq/in/!=/>/</>=/<=}` — simple comparaison
///   `{expr: "..."}`              — expression arithmetique/booleenne
///   `{all: [..]}` / `{any: [..]}` / `{not: ..}` — composeurs

enum ConstraintAction {
  warn,
  error,
  disableOthers,
  disableAndClear,
  unknown;

  static ConstraintAction fromString(String? s) {
    switch (s?.trim().toLowerCase()) {
      case 'warn':
        return warn;
      case 'error':
        return error;
      case 'disable_others':
        return disableOthers;
      case 'disable_and_clear':
        return disableAndClear;
      default:
        return unknown;
    }
  }
}

class ConstraintRule {
  final String id;
  final Map<String, dynamic>? when;
  final ConstraintAction action;
  final List<String> fields;
  final List<String> exceptFields;
  final List<String> requiresFields;
  final List<Map<String, dynamic>> sideEffects;
  final String message;

  const ConstraintRule({
    required this.id,
    required this.when,
    required this.action,
    required this.fields,
    required this.exceptFields,
    required this.requiresFields,
    required this.sideEffects,
    required this.message,
  });

  factory ConstraintRule.fromMap(Map<String, dynamic> m) {
    List<String> strList(dynamic v) {
      if (v is List) {
        return v
            .map((e) => e?.toString().trim() ?? '')
            .where((s) => s.isNotEmpty)
            .toList(growable: false);
      }
      return const [];
    }

    List<Map<String, dynamic>> mapList(dynamic v) {
      if (v is List) {
        return v
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      }
      return const [];
    }

    return ConstraintRule(
      id: m['id']?.toString() ?? '',
      when: m['when'] is Map ? Map<String, dynamic>.from(m['when']) : null,
      action: ConstraintAction.fromString(m['action']?.toString()),
      fields: strList(m['fields']),
      exceptFields: strList(m['except_fields']),
      requiresFields: strList(m['requires_fields']),
      sideEffects: mapList(m['side_effects']),
      message: m['message']?.toString() ?? '',
    );
  }

  static List<ConstraintRule> parseList(dynamic raw) {
    if (raw == null) return const [];
    dynamic decoded = raw;
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty || trimmed == '[]') return const [];
      try {
        decoded = jsonDecode(trimmed);
      } catch (_) {
        return const [];
      }
    }
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((m) => ConstraintRule.fromMap(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }
}

/// Résultat de l'évaluation pour un état donné du formulaire.
class ConstraintEvaluation {
  /// Messages `warn` à afficher (couple field → liste de messages).
  final Map<String, List<String>> warningsByField;

  /// Messages `error` qui bloquent le submit (couple field → liste).
  final Map<String, List<String>> errorsByField;

  /// Champs grisés/non saisissables (union de disable_others + disable_and_clear).
  final Set<String> disabledFields;

  /// Champs dont la valeur doit être forcée à null (action disable_and_clear).
  final Set<String> clearedFields;

  /// Raison textuelle du verrouillage par champ (premier message rencontré).
  /// Sert au rendu UI (ConstraintFieldHint avec cadenas + label explicatif).
  final Map<String, String> disableReasonsByField;

  /// Side-effects à appliquer au submit (set_field → valeur).
  final Map<String, dynamic> sideEffects;

  /// Liste linéaire de tous les warnings (utile pour le bandeau en-tête).
  final List<String> allWarningMessages;

  /// Liste linéaire de toutes les erreurs (utile pour bloquer + afficher).
  final List<String> allErrorMessages;

  const ConstraintEvaluation({
    required this.warningsByField,
    required this.errorsByField,
    required this.disabledFields,
    required this.clearedFields,
    required this.disableReasonsByField,
    required this.sideEffects,
    required this.allWarningMessages,
    required this.allErrorMessages,
  });

  bool get hasErrors => allErrorMessages.isNotEmpty;
  bool get hasWarnings => allWarningMessages.isNotEmpty;
  bool isFieldDisabled(String field) => disabledFields.contains(field);
}

class ConstraintEngine {
  /// Évalue toutes les règles fournies contre l'état courant du formulaire.
  ///
  /// `rulesByPivotField` : map nomChamp → liste de règles dont le champ
  /// est le pivot (typiquement, la sortie agrégée de tous les
  /// AttributConfigMobileField.contraintesRegles du formulaire).
  ///
  /// `allFields` : liste de tous les champs du formulaire (sert à étendre
  /// `disable_others` aux champs *autres* que les except_fields).
  static ConstraintEvaluation evaluate({
    required Map<String, List<ConstraintRule>> rulesByPivotField,
    required Map<String, dynamic> values,
    required Iterable<String> allFields,
  }) {
    final warnings = <String, List<String>>{};
    final errors = <String, List<String>>{};
    final disabled = <String>{};
    final cleared = <String>{};
    final disableReasons = <String, String>{};
    final sideEffects = <String, dynamic>{};
    final allWarnings = <String>[];
    final allErrors = <String>[];

    final allFieldsList = allFields.toList(growable: false);

    void recordDisableReason(String field, String message) {
      if (message.isEmpty) return;
      disableReasons.putIfAbsent(field, () => message);
    }

    for (final entry in rulesByPivotField.entries) {
      for (final rule in entry.value) {
        if (_missingRequiredFields(rule, values)) continue;
        if (!_evaluateCondition(rule.when, values)) continue;

        final message = _interpolateMessage(rule.message, values);

        switch (rule.action) {
          case ConstraintAction.warn:
            final targets = rule.fields.isNotEmpty ? rule.fields : [entry.key];
            for (final f in targets) {
              warnings.putIfAbsent(f, () => []).add(message);
            }
            if (message.isNotEmpty) allWarnings.add(message);
            break;

          case ConstraintAction.error:
            final targets = rule.fields.isNotEmpty ? rule.fields : [entry.key];
            for (final f in targets) {
              errors.putIfAbsent(f, () => []).add(message);
            }
            if (message.isNotEmpty) allErrors.add(message);
            break;

          case ConstraintAction.disableOthers:
            final except = rule.exceptFields.toSet();
            for (final f in allFieldsList) {
              if (!except.contains(f)) {
                disabled.add(f);
                recordDisableReason(f, message);
              }
            }
            break;

          case ConstraintAction.disableAndClear:
            for (final f in rule.fields) {
              disabled.add(f);
              cleared.add(f);
              recordDisableReason(f, message);
            }
            break;

          case ConstraintAction.unknown:
            // Action non reconnue : on ignore silencieusement plutot que
            // de bloquer le formulaire. Logue eventuellement en debug.
            break;
        }

        for (final se in rule.sideEffects) {
          final key = se['set_field']?.toString();
          if (key != null && key.isNotEmpty) {
            sideEffects[key] = se['value'];
          }
        }
      }
    }

    return ConstraintEvaluation(
      warningsByField: warnings,
      errorsByField: errors,
      disabledFields: disabled,
      clearedFields: cleared,
      disableReasonsByField: disableReasons,
      sideEffects: sideEffects,
      allWarningMessages: allWarnings,
      allErrorMessages: allErrors,
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Conditions
  // ─────────────────────────────────────────────────────────────────

  static bool _missingRequiredFields(
    ConstraintRule rule,
    Map<String, dynamic> values,
  ) {
    for (final field in rule.requiresFields) {
      final v = values[field];
      if (v == null) return true;
      if (v is String && v.trim().isEmpty) return true;
    }
    return false;
  }

  static bool _evaluateCondition(
    Map<String, dynamic>? cond,
    Map<String, dynamic> values,
  ) {
    if (cond == null) return false;
    if (cond.containsKey('all')) {
      final list = cond['all'];
      if (list is! List) return false;
      return list.every((c) => _evaluateCondition(
            c is Map ? Map<String, dynamic>.from(c) : null,
            values,
          ));
    }
    if (cond.containsKey('any')) {
      final list = cond['any'];
      if (list is! List) return false;
      return list.any((c) => _evaluateCondition(
            c is Map ? Map<String, dynamic>.from(c) : null,
            values,
          ));
    }
    if (cond.containsKey('not')) {
      final inner = cond['not'];
      return !_evaluateCondition(
        inner is Map ? Map<String, dynamic>.from(inner) : null,
        values,
      );
    }
    if (cond.containsKey('expr')) {
      return _evaluateExpression(cond['expr']?.toString() ?? '', values);
    }
    return _evaluateSimpleCondition(cond, values);
  }

  static bool _evaluateSimpleCondition(
    Map<String, dynamic> cond,
    Map<String, dynamic> values,
  ) {
    final field = cond['field']?.toString();
    if (field == null || field.isEmpty) return false;
    final value = _normalize(values[field]);

    if (cond.containsKey('eq')) return _normalize(cond['eq']) == value;
    if (cond.containsKey('!=')) return _normalize(cond['!=']) != value;
    if (cond.containsKey('in')) {
      final raw = cond['in'];
      if (raw is! List) return false;
      final wanted = raw.map(_normalize).toList();
      return wanted.contains(value);
    }
    for (final op in ['>', '<', '>=', '<=']) {
      if (cond.containsKey(op)) {
        final n = _toNum(value);
        final r = _toNum(cond[op]);
        if (n == null || r == null) return false;
        switch (op) {
          case '>':
            return n > r;
          case '<':
            return n < r;
          case '>=':
            return n >= r;
          case '<=':
            return n <= r;
        }
      }
    }
    return false;
  }

  static dynamic _normalize(dynamic v) {
    if (v is String) return v.trim();
    return v;
  }

  static num? _toNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v;
    if (v is bool) return v ? 1 : 0;
    final s = v.toString().trim().replaceAll(',', '.');
    if (s.isEmpty) return null;
    return num.tryParse(s);
  }

  // ─────────────────────────────────────────────────────────────────
  // Expressions arithmétiques/booléennes (tokenizer + parser récursif)
  // ─────────────────────────────────────────────────────────────────

  static bool _evaluateExpression(String expr, Map<String, dynamic> values) {
    try {
      final tokens = _tokenize(expr);
      final parser = _ExprParser(tokens, values);
      final result = parser.parse();
      if (result is bool) return result;
      if (result is num) return result != 0;
      return false;
    } catch (_) {
      return false;
    }
  }

  static String _interpolateMessage(
    String message,
    Map<String, dynamic> values,
  ) {
    if (message.isEmpty) return message;
    return message.replaceAllMapped(RegExp(r'\{\{([^}]+)\}\}'), (m) {
      final inner = m.group(1)?.trim() ?? '';
      if (_isIdentifier(inner) && values.containsKey(inner)) {
        final v = values[inner];
        if (v == null) return '';
        if (v is num) {
          // Si entier, pas de virgule. Sinon, conserve la representation.
          if (v == v.truncate()) return v.toInt().toString();
        }
        return v.toString();
      }
      try {
        final tokens = _tokenize(inner);
        final parser = _ExprParser(tokens, values);
        final value = parser.parse();
        if (value is num) {
          if (value == value.truncate()) return value.toInt().toString();
          return value.toString();
        }
        return value?.toString() ?? '';
      } catch (_) {
        return m.group(0) ?? '';
      }
    });
  }

  static bool _isIdentifier(String s) =>
      RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$').hasMatch(s);

  static List<_Token> _tokenize(String expr) {
    final tokens = <_Token>[];
    final pattern = RegExp(
      r'\s*(?:(\d+(?:\.\d+)?)|([a-zA-Z_][a-zA-Z0-9_]*)|(\|\||&&|<=|>=|==|!=|[+\-*/()<>]))\s*',
    );
    int pos = 0;
    while (pos < expr.length) {
      final match = pattern.matchAsPrefix(expr, pos);
      if (match == null || match.end == pos) {
        throw FormatException('Token invalide pos=$pos: ${expr.substring(pos)}');
      }
      if (match.group(1) != null) {
        tokens.add(_Token(_TT.num, match.group(1)!));
      } else if (match.group(2) != null) {
        tokens.add(_Token(_TT.ident, match.group(2)!));
      } else if (match.group(3) != null) {
        tokens.add(_Token(_TT.op, match.group(3)!));
      }
      pos = match.end;
    }
    return tokens;
  }
}

// ─────────────────────────────────────────────────────────────────────
// Parser interne (visible uniquement dans ce fichier).
// ─────────────────────────────────────────────────────────────────────

enum _TT { num, ident, op }

class _Token {
  final _TT type;
  final String value;
  const _Token(this.type, this.value);
  @override
  String toString() => '${type.name}:$value';
}

class _ExprParser {
  final List<_Token> tokens;
  final Map<String, dynamic> values;
  int _pos = 0;

  _ExprParser(this.tokens, this.values);

  _Token? _peek() => _pos < tokens.length ? tokens[_pos] : null;
  _Token _consume() => tokens[_pos++];

  bool _isOp(String s) {
    final p = _peek();
    return p != null && p.type == _TT.op && p.value == s;
  }

  dynamic parse() {
    final result = _parseOr();
    if (_pos != tokens.length) {
      throw const FormatException('Tokens restants');
    }
    return result;
  }

  dynamic _parseOr() {
    var left = _parseAnd();
    while (_isOp('||')) {
      _consume();
      final right = _parseAnd();
      left = _toBool(left) || _toBool(right);
    }
    return left;
  }

  dynamic _parseAnd() {
    var left = _parseCmp();
    while (_isOp('&&')) {
      _consume();
      final right = _parseCmp();
      left = _toBool(left) && _toBool(right);
    }
    return left;
  }

  dynamic _parseCmp() {
    var left = _parseAddSub();
    const cmpOps = {'<', '>', '<=', '>=', '==', '!='};
    while (_peek() != null &&
        _peek()!.type == _TT.op &&
        cmpOps.contains(_peek()!.value)) {
      final op = _consume().value;
      final right = _parseAddSub();
      final ln = ConstraintEngine._toNum(left);
      final rn = ConstraintEngine._toNum(right);
      if (ln == null || rn == null) {
        left = false;
        continue;
      }
      switch (op) {
        case '<':
          left = ln < rn;
          break;
        case '>':
          left = ln > rn;
          break;
        case '<=':
          left = ln <= rn;
          break;
        case '>=':
          left = ln >= rn;
          break;
        case '==':
          left = ln == rn;
          break;
        case '!=':
          left = ln != rn;
          break;
      }
    }
    return left;
  }

  dynamic _parseAddSub() {
    var left = _parseMulDiv();
    while (_isOp('+') || _isOp('-')) {
      final op = _consume().value;
      final right = _parseMulDiv();
      final ln = ConstraintEngine._toNum(left);
      final rn = ConstraintEngine._toNum(right);
      if (ln == null || rn == null) return null;
      left = op == '+' ? ln + rn : ln - rn;
    }
    return left;
  }

  dynamic _parseMulDiv() {
    var left = _parseUnary();
    while (_isOp('*') || _isOp('/')) {
      final op = _consume().value;
      final right = _parseUnary();
      final ln = ConstraintEngine._toNum(left);
      final rn = ConstraintEngine._toNum(right);
      if (ln == null || rn == null) return null;
      if (op == '*') {
        left = ln * rn;
      } else {
        if (rn == 0) return null;
        left = ln / rn;
      }
    }
    return left;
  }

  dynamic _parseUnary() {
    if (_isOp('-')) {
      _consume();
      final v = _parseUnary();
      final n = ConstraintEngine._toNum(v);
      return n == null ? null : -n;
    }
    return _parseAtom();
  }

  dynamic _parseAtom() {
    final tok = _consume();
    if (tok.type == _TT.num) return num.tryParse(tok.value);
    if (tok.type == _TT.ident) {
      return ConstraintEngine._toNum(values[tok.value]);
    }
    if (tok.type == _TT.op && tok.value == '(') {
      final value = _parseOr();
      final close = _consume();
      if (close.type != _TT.op || close.value != ')') {
        throw const FormatException('Parenthese fermante attendue');
      }
      return value;
    }
    throw FormatException('Token inattendu: $tok');
  }

  bool _toBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    return false;
  }
}
