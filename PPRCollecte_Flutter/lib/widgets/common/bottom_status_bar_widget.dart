import 'package:flutter/material.dart';

class BottomStatusBarWidget extends StatelessWidget {
  final bool gpsEnabled;
  final String gpsSourceLabel;
  final String? gpsDetailsLine;
  final bool isOnline;
  final String? lastSyncTime;

  const BottomStatusBarWidget({
    super.key,
    required this.gpsEnabled,
    this.gpsSourceLabel = 'téléphone',
    this.gpsDetailsLine,
    required this.isOnline,
    this.lastSyncTime,
  });

  @override
  Widget build(BuildContext context) {
    final onlineText = isOnline ? 'En ligne' : 'Hors ligne';
    final onlineColor = isOnline ? Colors.green.shade700 : Colors.red.shade700;
    final syncText = lastSyncTime ?? '--:--';
    final details = gpsDetailsLine?.trim();

    return Container(
      color: const Color(0xFFE3F2FD),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
              children: [
                TextSpan(
                  text:
                      "GPS: ${gpsEnabled ? 'Activé' : 'Désactivé'} | Source: $gpsSourceLabel | Sync: $syncText | ",
                ),
                TextSpan(
                  text: onlineText,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: onlineColor,
                  ),
                ),
              ],
            ),
          ),
          if (details != null && details.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                details,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.15,
                  color: Colors.black87,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
