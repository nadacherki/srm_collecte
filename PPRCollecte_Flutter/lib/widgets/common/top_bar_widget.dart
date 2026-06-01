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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF1976D2),
            Color(0xFF42A5F5),
          ],
        ),
      ),
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
                    color: Colors.white.withValues(alpha: 0.96),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.55),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0D47A1).withValues(alpha: 0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _getInitials(agentName),
                      style: const TextStyle(
                        color: Color(0xFF1976D2),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
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
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    // Sous-titre cliquable
                    Row(
                      children: [
                        const Text(
                          'Voir profil & dashboard',
                          style: TextStyle(
                            color: Color(0xE6FFFFFF),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 9,
                          color: Colors.white.withValues(alpha: 0.7),
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
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
              elevation: 0,
              shadowColor: Colors.transparent,
            ),
            onPressed: onLogout,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.logout,
                  color: Colors.white,
                  size: 15,
                ),
                SizedBox(width: 6),
                Text(
                  'Se déconnecter',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
