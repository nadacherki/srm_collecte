"""Moteur d'evaluation des contraintes metier (action=error) cote serveur.

Source des regles : `public.attribut_config_mobile.contraintes_regles` (JSONB).
Schema documente dans `sql/2026-05-21_attribut_config_contraintes_split.sql`.

Le mobile evalue TOUTES les actions (warn, disable_others, disable_and_clear,
side_effects) pour l'UX. Le serveur ne re-evalue QUE les regles d'action=error
pour blinder le POST contre un client compromis ou bugue. Les warn/disable ne
font sens qu'a l'UX : pas de re-evaluation cote serveur.

Le moteur est volontairement minimal : pas de eval(), pas d'import dynamique.
Les conditions sont declaratives (operateurs eq/in/cmp/all/any/not) ou des
expressions arithmetiques simples (parsing manuel des operateurs +-*/<>=!&|).
"""

from __future__ import annotations

import re
from typing import Any, Dict, List, Optional, Tuple

from django.db import connection


def _to_number(value: Any) -> Optional[float]:
    """Cast best-effort vers float. Retourne None si non convertible."""
    if value is None or value == '':
        return None
    if isinstance(value, bool):
        return 1.0 if value else 0.0
    if isinstance(value, (int, float)):
        return float(value)
    try:
        return float(str(value).replace(',', '.').strip())
    except (TypeError, ValueError):
        return None


def _normalize_value(value: Any) -> Any:
    """Strip et lower pour les comparaisons string. Laisse les autres types intacts."""
    if isinstance(value, str):
        return value.strip()
    return value


def _evaluate_simple_condition(cond: Dict[str, Any], payload: Dict[str, Any]) -> bool:
    """Conditions simples : {field, eq/in/!=/>/</>=/<=}."""
    field = cond.get('field')
    if not field:
        return False
    value = _normalize_value(payload.get(field))

    if 'eq' in cond:
        return _normalize_value(cond['eq']) == value
    if '!=' in cond:
        return _normalize_value(cond['!=']) != value
    if 'in' in cond:
        wanted = [_normalize_value(v) for v in (cond['in'] or [])]
        return value in wanted
    for op_key in ('>', '<', '>=', '<='):
        if op_key in cond:
            num = _to_number(value)
            ref = _to_number(cond[op_key])
            if num is None or ref is None:
                return False
            if op_key == '>':
                return num > ref
            if op_key == '<':
                return num < ref
            if op_key == '>=':
                return num >= ref
            if op_key == '<=':
                return num <= ref
    return False


# Expressions : champs (identifiants), nombres, parentheses, operateurs
# arithmetiques (+-*/) et booleens (<, >, <=, >=, ==, !=, &&, ||).
# Pas de fonctions, pas de strings.
_TOKEN_RE = re.compile(
    r'\s*(?:(?P<num>\d+(?:\.\d+)?)|(?P<ident>[a-zA-Z_][a-zA-Z0-9_]*)|'
    r'(?P<op>\|\||&&|<=|>=|==|!=|[+\-*/()<>]))\s*'
)


def _tokenize(expr: str) -> List[Tuple[str, str]]:
    tokens: List[Tuple[str, str]] = []
    pos = 0
    while pos < len(expr):
        match = _TOKEN_RE.match(expr, pos)
        if not match or match.end() == pos:
            raise ValueError(f"Token invalide a la position {pos}: {expr[pos:pos + 8]!r}")
        if match.group('num'):
            tokens.append(('num', match.group('num')))
        elif match.group('ident'):
            tokens.append(('ident', match.group('ident')))
        elif match.group('op'):
            tokens.append(('op', match.group('op')))
        pos = match.end()
    return tokens


class _ExprParser:
    """Parser recursif simple (precedence : || < && < cmp < +/- < */ < unary)."""

    def __init__(self, tokens: List[Tuple[str, str]], payload: Dict[str, Any]):
        self.tokens = tokens
        self.pos = 0
        self.payload = payload

    def _peek(self) -> Optional[Tuple[str, str]]:
        return self.tokens[self.pos] if self.pos < len(self.tokens) else None

    def _consume(self) -> Tuple[str, str]:
        tok = self.tokens[self.pos]
        self.pos += 1
        return tok

    def parse(self) -> Any:
        result = self._parse_or()
        if self.pos != len(self.tokens):
            raise ValueError(f"Tokens restants apres parse: {self.tokens[self.pos:]}")
        return result

    def _parse_or(self) -> Any:
        left = self._parse_and()
        while self._peek() == ('op', '||'):
            self._consume()
            right = self._parse_and()
            left = bool(left) or bool(right)
        return left

    def _parse_and(self) -> Any:
        left = self._parse_cmp()
        while self._peek() == ('op', '&&'):
            self._consume()
            right = self._parse_cmp()
            left = bool(left) and bool(right)
        return left

    def _parse_cmp(self) -> Any:
        left = self._parse_addsub()
        while self._peek() and self._peek()[0] == 'op' and self._peek()[1] in ('<', '>', '<=', '>=', '==', '!='):
            op = self._consume()[1]
            right = self._parse_addsub()
            ln = _to_number(left)
            rn = _to_number(right)
            if ln is None or rn is None:
                return False
            if op == '<':
                left = ln < rn
            elif op == '>':
                left = ln > rn
            elif op == '<=':
                left = ln <= rn
            elif op == '>=':
                left = ln >= rn
            elif op == '==':
                left = ln == rn
            elif op == '!=':
                left = ln != rn
        return left

    def _parse_addsub(self) -> Any:
        left = self._parse_muldiv()
        while self._peek() and self._peek() in (('op', '+'), ('op', '-')):
            op = self._consume()[1]
            right = self._parse_muldiv()
            ln = _to_number(left)
            rn = _to_number(right)
            if ln is None or rn is None:
                return None
            left = ln + rn if op == '+' else ln - rn
        return left

    def _parse_muldiv(self) -> Any:
        left = self._parse_unary()
        while self._peek() and self._peek() in (('op', '*'), ('op', '/')):
            op = self._consume()[1]
            right = self._parse_unary()
            ln = _to_number(left)
            rn = _to_number(right)
            if ln is None or rn is None:
                return None
            if op == '*':
                left = ln * rn
            else:
                if rn == 0:
                    return None
                left = ln / rn
        return left

    def _parse_unary(self) -> Any:
        if self._peek() == ('op', '-'):
            self._consume()
            value = self._parse_unary()
            num = _to_number(value)
            return -num if num is not None else None
        return self._parse_atom()

    def _parse_atom(self) -> Any:
        tok = self._consume()
        if tok[0] == 'num':
            return float(tok[1])
        if tok[0] == 'ident':
            return _to_number(self.payload.get(tok[1]))
        if tok == ('op', '('):
            value = self._parse_or()
            close = self._consume()
            if close != ('op', ')'):
                raise ValueError(f"Parenthese fermante attendue, recu {close}")
            return value
        raise ValueError(f"Token inattendu: {tok}")


def _evaluate_expr(expr: str, payload: Dict[str, Any]) -> bool:
    """Evalue une expression arithmetique/booleenne avec les valeurs du payload."""
    try:
        tokens = _tokenize(expr)
        parser = _ExprParser(tokens, payload)
        return bool(parser.parse())
    except (ValueError, ZeroDivisionError):
        # Expression malformee : on considere que la condition n'est pas remplie
        # (= la regle ne se declenche pas). On ne fait pas planter le POST.
        return False


def _evaluate_condition(cond: Any, payload: Dict[str, Any]) -> bool:
    if not isinstance(cond, dict):
        return False
    if 'all' in cond:
        return all(_evaluate_condition(c, payload) for c in cond['all'])
    if 'any' in cond:
        return any(_evaluate_condition(c, payload) for c in cond['any'])
    if 'not' in cond:
        return not _evaluate_condition(cond['not'], payload)
    if 'expr' in cond:
        return _evaluate_expr(str(cond['expr']), payload)
    return _evaluate_simple_condition(cond, payload)


def _missing_required_fields(rule: Dict[str, Any], payload: Dict[str, Any]) -> bool:
    """Retourne True si une regle a `requires_fields` et au moins un manque."""
    required = rule.get('requires_fields') or []
    for field in required:
        value = payload.get(field)
        if value is None or value == '':
            return True
    return False


def _interpolate_message(message: str, payload: Dict[str, Any]) -> str:
    """Remplace les {{field}} et {{expr}} dans le message par leur valeur."""
    if not message:
        return message

    def _replace(match: re.Match) -> str:
        inner = match.group(1).strip()
        # Si c'est un simple identifiant connu : on prend la valeur du payload.
        if inner.isidentifier() and inner in payload:
            value = payload[inner]
            return '' if value is None else str(value)
        # Sinon, on tente l'evaluation comme expression numerique.
        try:
            tokens = _tokenize(inner)
            parser = _ExprParser(tokens, payload)
            value = parser.parse()
            if isinstance(value, float) and value.is_integer():
                return str(int(value))
            return str(value)
        except (ValueError, ZeroDivisionError):
            return match.group(0)

    return re.sub(r'\{\{([^}]+)\}\}', _replace, message)


def fetch_error_rules_for_table(schema: str, table: str) -> List[Tuple[str, Dict[str, Any]]]:
    """Charge toutes les regles action=error d'une table metier donnee.

    Retourne une liste de tuples (nom_champ_pivot, regle). Le champ pivot est
    informatif (debug), seule la regle est evaluee.
    """
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT nom_champ, contraintes_regles
            FROM   public.attribut_config_mobile
            WHERE  nom_metier = %s
              AND  nom_table  = %s
              AND  contraintes_regles <> '[]'::jsonb
            """,
            [schema, table],
        )
        rows = cursor.fetchall()

    error_rules: List[Tuple[str, Dict[str, Any]]] = []
    for nom_champ, rules_json in rows:
        if not isinstance(rules_json, list):
            continue
        for rule in rules_json:
            if isinstance(rule, dict) and rule.get('action') == 'error':
                error_rules.append((nom_champ, rule))
    return error_rules


def evaluate_error_rules(
    schema: str,
    table: str,
    payload: Dict[str, Any],
) -> List[Dict[str, Any]]:
    """Re-evalue les regles `action=error` cote serveur.

    Retourne une liste vide si tout est OK. Sinon, retourne pour chaque regle
    declenchee : {rule_id, message_interpole, fields, nom_champ_pivot}.
    """
    rules = fetch_error_rules_for_table(schema, table)
    failed: List[Dict[str, Any]] = []
    for nom_champ, rule in rules:
        if _missing_required_fields(rule, payload):
            continue
        condition = rule.get('when')
        if not _evaluate_condition(condition, payload):
            continue
        failed.append({
            'rule_id': rule.get('id'),
            'message': _interpolate_message(rule.get('message') or '', payload),
            'fields': rule.get('fields') or [],
            'pivot_field': nom_champ,
        })
    return failed
