import 'package:flutter/material.dart';

/// Bandeau récapitulatif placé en haut du formulaire quand le moteur
/// de contraintes a remonté au moins une alerte ou une erreur.
/// Compact (1 ligne quand replie), expandable pour voir le détail.
class ConstraintHeaderBanner extends StatefulWidget {
  final List<String> warnings;
  final List<String> errors;

  const ConstraintHeaderBanner({
    super.key,
    required this.warnings,
    required this.errors,
  });

  @override
  State<ConstraintHeaderBanner> createState() => _ConstraintHeaderBannerState();
}

class _ConstraintHeaderBannerState extends State<ConstraintHeaderBanner> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final hasErrors = widget.errors.isNotEmpty;
    final hasWarnings = widget.warnings.isNotEmpty;
    if (!hasErrors && !hasWarnings) return const SizedBox.shrink();

    final color = hasErrors
        ? Colors.red.shade50
        : Colors.amber.shade50;
    final borderColor = hasErrors ? Colors.red.shade400 : Colors.amber.shade700;
    final icon = hasErrors ? Icons.error_outline : Icons.warning_amber_rounded;
    final iconColor = hasErrors ? Colors.red.shade700 : Colors.amber.shade800;

    final summary = _summaryLabel(hasErrors, hasWarnings);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    summary,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: iconColor,
                    ),
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: iconColor,
                  size: 20,
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 8),
            for (final msg in widget.errors)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '• $msg',
                  style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                ),
              ),
            for (final msg in widget.warnings)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '• $msg',
                  style: TextStyle(color: Colors.amber.shade900, fontSize: 13),
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _summaryLabel(bool hasErrors, bool hasWarnings) {
    final nE = widget.errors.length;
    final nW = widget.warnings.length;
    final parts = <String>[];
    if (hasErrors) {
      parts.add(nE == 1 ? '1 erreur bloquante' : '$nE erreurs bloquantes');
    }
    if (hasWarnings) {
      parts.add(nW == 1 ? '1 alerte' : '$nW alertes');
    }
    return parts.join(', ');
  }
}

/// Petit bloc placé au-dessus d'un input de formulaire pour signaler
/// soit une alerte (warn, jaune), soit une erreur (error, rouge), soit
/// un état "non saisissable" (lock, gris).
class ConstraintFieldHint extends StatelessWidget {
  /// Messages warn associés au champ (au moins 1 => bandeau jaune).
  final List<String> warnings;

  /// Messages error associés au champ (au moins 1 => bandeau rouge,
  /// passe au-dessus des warnings).
  final List<String> errors;

  /// Si le champ est verrouillé par une règle disable_*, on affiche
  /// un cadenas avec un texte explicatif.
  final bool locked;

  /// Texte affiché à côté du cadenas (ex: nom de la règle qui verrouille).
  final String lockReason;

  const ConstraintFieldHint({
    super.key,
    this.warnings = const [],
    this.errors = const [],
    this.locked = false,
    this.lockReason = '',
  });

  @override
  Widget build(BuildContext context) {
    final blocks = <Widget>[];

    if (errors.isNotEmpty) {
      blocks.add(_buildLine(
        icon: Icons.error_outline,
        color: Colors.red.shade700,
        bg: Colors.red.shade50,
        border: Colors.red.shade300,
        lines: errors,
      ));
    }
    if (warnings.isNotEmpty) {
      blocks.add(_buildLine(
        icon: Icons.warning_amber_rounded,
        color: Colors.amber.shade900,
        bg: Colors.amber.shade50,
        border: Colors.amber.shade400,
        lines: warnings,
      ));
    }
    if (locked && lockReason.isNotEmpty) {
      blocks.add(_buildLine(
        icon: Icons.lock_outline,
        color: Colors.grey.shade700,
        bg: Colors.grey.shade100,
        border: Colors.grey.shade400,
        lines: [lockReason],
      ));
    }

    if (blocks.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: blocks,
      ),
    );
  }

  Widget _buildLine({
    required IconData icon,
    required Color color,
    required Color bg,
    required Color border,
    required List<String> lines,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in lines)
                  Text(
                    line,
                    style: TextStyle(color: color, fontSize: 12.5),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
