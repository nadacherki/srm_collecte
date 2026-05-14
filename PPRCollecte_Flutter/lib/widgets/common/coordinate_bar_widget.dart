// lib/widgets/common/coordinate_bar_widget.dart
// ── SPRINT 3 : Barre X/Y Merchich Nord (EPSG:26191) pendant la collecte ──

import 'package:flutter/material.dart';

class CoordinateBarWidget extends StatelessWidget {
  final double merchichX;
  final double merchichY;
  final double accuracy;
  final double? altitude;
  final bool isGpsActive;

  const CoordinateBarWidget({
    super.key,
    required this.merchichX,
    required this.merchichY,
    required this.accuracy,
    this.altitude,
    this.isGpsActive = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isGpsActive
            ? const Color(0xFF1E293B).withValues(alpha: 0.92)
            : const Color(0xFF7F1D1D).withValues(alpha: 0.92),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Indicateur GPS
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isGpsActive ? const Color(0xFF22C55E) : Colors.red,
                boxShadow: [
                  BoxShadow(
                    color: (isGpsActive ? const Color(0xFF22C55E) : Colors.red)
                        .withValues(alpha: 0.5),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),

            // Coordonnées Merchich Nord
            Expanded(
              child: Row(
                children: [
                  _coordLabel('X'),
                  const SizedBox(width: 4),
                  _coordValue(merchichX.toStringAsFixed(2)),
                  const SizedBox(width: 12),
                  _coordLabel('Y'),
                  const SizedBox(width: 4),
                  _coordValue(merchichY.toStringAsFixed(2)),
                  if (altitude != null) ...[
                    const SizedBox(width: 12),
                    _coordLabel('Z'),
                    const SizedBox(width: 4),
                    _coordValue('${altitude!.toStringAsFixed(1)}m'),
                  ],
                ],
              ),
            ),

            // Précision GPS
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _accuracyColor(accuracy).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _accuracyColor(accuracy).withValues(alpha: 0.5),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.gps_fixed,
                      size: 12, color: _accuracyColor(accuracy)),
                  const SizedBox(width: 4),
                  Text(
                    '${accuracy.toStringAsFixed(1)}m',
                    style: TextStyle(
                      color: _accuracyColor(accuracy),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coordLabel(String label) {
    return Text(label,
        style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 11,
            fontWeight: FontWeight.w600));
  }

  Widget _coordValue(String value) {
    return Text(value,
        style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            fontFamily: 'monospace'));
  }

  Color _accuracyColor(double accuracy) {
    if (accuracy <= 1.0) return const Color(0xFF22C55E); // RTK fix
    if (accuracy <= 5.0) return const Color(0xFF3B82F6); // Bon
    if (accuracy <= 15.0) return const Color(0xFFF59E0B); // Moyen
    return const Color(0xFFEF4444); // Mauvais
  }
}
