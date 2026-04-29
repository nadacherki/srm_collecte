// lib/widgets/common/top_bar_widget.dart
// Sprint 6 — Icône profil cliquable → ProfilePage
import 'dart:async';

import 'package:flutter/material.dart';
import '../../screens/profile/profile_page.dart';

class TopBarWidget extends StatelessWidget {
  final String agentName;
  final VoidCallback onLogout;
  final FutureOr<void> Function(String metier)? onStartConduiteDrawing;

  const TopBarWidget({
    super.key,
    required this.agentName,
    required this.onLogout,
    this.onStartConduiteDrawing,
  });

  String _getInitials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1B4F72),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ── Icône profil cliquable ──
          GestureDetector(
            onTap: () async {
              final result = await Navigator.push<Object?>(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfilePage(
                    agentName: agentName,
                    onLogout: onLogout,
                  ),
                ),
              );
              if (result == ProfilePage.startConduiteDrawingEpResult ||
                  result == ProfilePage.startConduiteDrawingResult) {
                await onStartConduiteDrawing?.call('ep');
              } else if (result == ProfilePage.startConduiteDrawingAsstResult) {
                await onStartConduiteDrawing?.call('asst');
              }
            },
            child: Row(
              children: [
                // Avatar cercle avec initiales
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _getInitials(agentName),
                      style: const TextStyle(
                        color: Color(0xFF1B4F72),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      agentName.isNotEmpty ? agentName : 'Agent',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    // Sous-titre cliquable
                    Row(
                      children: [
                        const Text(
                          'Voir profil & dashboard',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 9,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Bouton déconnexion ──
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF64B5F6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding:
                  const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              elevation: 0,
            ),
            onPressed: onLogout,
            child: const Text(
              'Se déconnecter',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
