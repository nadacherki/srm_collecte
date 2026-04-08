import 'package:flutter/material.dart';
import '../../controllers/home_controller.dart';

class MapControlsWidget extends StatelessWidget {
  final HomeController controller;
  final VoidCallback onAddPoint;
  final VoidCallback onStartLigne;
  final VoidCallback onStartPolygon;
  final VoidCallback onToggleLigne;
  final VoidCallback onTogglePolygon;
  final VoidCallback onFinishLigne;
  final VoidCallback onFinishPolygon;
  final VoidCallback onRefresh;
  final bool isSpecialCollection;
  final bool isPolygonCollection;
  final VoidCallback onStopSpecial;

  const MapControlsWidget({
    super.key,
    required this.controller,
    required this.onAddPoint,
    required this.onStartLigne,
    required this.onStartPolygon,
    required this.onToggleLigne,
    required this.onTogglePolygon,
    required this.onFinishLigne,
    required this.onFinishPolygon,
    required this.onRefresh,
    required this.isSpecialCollection,
    this.isPolygonCollection = false,
    required this.onStopSpecial,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Bouton Rafraîchir
        Positioned(
          top: 8,
          right: 55,
          child: FloatingActionButton(
            heroTag: "refreshBtn",
            mini: true,
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            onPressed: onRefresh,
            elevation: 6,
            child: const Icon(Icons.refresh, size: 20),
          ),
        ),

        // ===== Boutons principaux en bas =====
        Positioned(
          bottom: 10,
          left: 0,
          right: 50,
          child: SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                SizedBox(width: 110, child: _buildPointControls()),
                SizedBox(width: 110, child: _buildLigneControls()),
                SizedBox(width: 110, child: _buildPolygonControls()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPointControls() {
    if (isSpecialCollection && !isPolygonCollection) {
      return FloatingActionButton.extended(
        heroTag: "stopSpecialBtn",
        backgroundColor: const Color(0xFFE53E3E),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.stop),
        label: const Text("Arrêt"),
        onPressed: onStopSpecial,
        elevation: 6,
        highlightElevation: 12,
      );
    }

    if (controller.hasActiveCollection) {
      return const SizedBox.shrink();
    }

    return FloatingActionButton.extended(
      heroTag: "pointBtn",
      backgroundColor: const Color(0xFFE53E3E),
      foregroundColor: Colors.white,
      icon: const Icon(Icons.place),
      label: const Text("Point"),
      onPressed: onAddPoint,
      elevation: 6,
      highlightElevation: 12,
    );
  }

  Widget _buildLigneControls() {
    final ligneCollection = controller.ligneCollection;

    if (ligneCollection == null || ligneCollection.isInactive) {
      if (controller.hasActiveCollection) {
        return const SizedBox.shrink();
      }

      // Bouton démarrer ligne
      return FloatingActionButton.extended(
        heroTag: "ligneBtn",
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.timeline),
        label: const Text("Ligne"),
        onPressed: onStartLigne,
        elevation: 6,
        highlightElevation: 12,
      );
    } else {
      // Contrôles ligne active/en pause
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: "pauseLigneBtn",
            backgroundColor: const Color(0xFF1976D2),
            foregroundColor: Colors.white,
            onPressed: onToggleLigne,
            mini: true,
            elevation: 4,
            child: Icon(
              ligneCollection.isPaused ? Icons.play_arrow : Icons.pause,
              size: 20,
            ),
          ),
          const SizedBox(width: 8),

          // Bouton stop
          FloatingActionButton(
            heroTag: "stopLigneBtn",
            backgroundColor: const Color(0xFFE53E3E),
            foregroundColor: Colors.white,
            onPressed: onFinishLigne,
            mini: true,
            elevation: 4,
            child: const Icon(Icons.stop, size: 20),
          ),
        ],
      );
    }
  }

  Widget _buildPolygonControls() {
    final specialCollection = controller.specialCollection;
    final isPolygonActive =
        isSpecialCollection && isPolygonCollection && specialCollection != null;

    if (!isPolygonActive) {
      if (controller.hasActiveCollection) {
        return const SizedBox.shrink();
      }

      return FloatingActionButton.extended(
        heroTag: "polygonBtn",
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.pentagon),
        label: const Text("Polygone"),
        onPressed: onStartPolygon,
        elevation: 6,
        highlightElevation: 12,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: "pausePolygonBtn",
          backgroundColor: const Color(0xFF1B5E20),
          foregroundColor: Colors.white,
          onPressed: onTogglePolygon,
          mini: true,
          elevation: 4,
          child: Icon(
            specialCollection.isPaused ? Icons.play_arrow : Icons.pause,
            size: 20,
          ),
        ),
        const SizedBox(width: 8),
        FloatingActionButton(
          heroTag: "stopPolygonBtn",
          backgroundColor: const Color(0xFFE53E3E),
          foregroundColor: Colors.white,
          onPressed: onFinishPolygon,
          mini: true,
          elevation: 4,
          child: const Icon(Icons.stop, size: 20),
        ),
      ],
    );
  }
}
