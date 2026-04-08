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
  final VoidCallback onCancelLigne;
  final VoidCallback onCancelPolygon;
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
    required this.onCancelLigne,
    required this.onCancelPolygon,
    required this.onRefresh,
    required this.isSpecialCollection,
    this.isPolygonCollection = false,
    required this.onStopSpecial,
  });

  @override
  Widget build(BuildContext context) {
    final hasLigneContext = controller.ligneCollection != null;
    final hasPolygonContext =
        isSpecialCollection && isPolygonCollection && controller.specialCollection != null;
    final showAddPointForLigne = controller.ligneCollection?.isActive ?? false;
    final showAddPointForPolygon =
        isPolygonCollection && (controller.specialCollection?.isActive ?? false);

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
              mainAxisAlignment: MainAxisAlignment.center,
              children: hasLigneContext
                  ? [
                      if (showAddPointForLigne) _buildPointControls(),
                      if (showAddPointForLigne) const SizedBox(width: 12),
                      _buildLigneControls(),
                    ]
                  : hasPolygonContext
                      ? [
                          if (showAddPointForPolygon) _buildPointControls(),
                          if (showAddPointForPolygon) const SizedBox(width: 12),
                          _buildPolygonControls(),
                        ]
                      : [
                          SizedBox(width: 110, child: _buildPointControls()),
                          const SizedBox(width: 12),
                          SizedBox(width: 110, child: _buildLigneControls()),
                          const SizedBox(width: 12),
                          SizedBox(width: 110, child: _buildPolygonControls()),
                        ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPointControls() {
    final isManualCollectionActive =
        (controller.ligneCollection?.isActive ?? false) ||
        (controller.chausseeCollection?.isActive ?? false) ||
        (isPolygonCollection && (controller.specialCollection?.isActive ?? false));
    final hasManualCollectionContext =
        controller.ligneCollection != null ||
        controller.chausseeCollection != null ||
        (isPolygonCollection && controller.specialCollection != null);

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

    if (isManualCollectionActive) {
      return FloatingActionButton.extended(
        heroTag: "addPointBtn",
        backgroundColor: const Color(0xFFF59E0B),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt),
        label: const Text("Ajout point"),
        onPressed: onAddPoint,
        elevation: 6,
        highlightElevation: 12,
      );
    }

    if (hasManualCollectionContext || controller.hasActiveCollection || controller.hasPausedCollection) {
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
      if (controller.hasActiveCollection || controller.hasPausedCollection || controller.specialCollection != null || controller.chausseeCollection != null) {
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
            heroTag: "cancelLigneBtn",
            backgroundColor: const Color(0xFFE53E3E),
            foregroundColor: Colors.white,
            onPressed: onCancelLigne,
            mini: true,
            elevation: 4,
            child: const Icon(Icons.close, size: 20),
          ),
          const SizedBox(width: 8),

          FloatingActionButton(
            heroTag: "stopLigneBtn",
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            onPressed: onFinishLigne,
            mini: true,
            elevation: 4,
            child: const Icon(Icons.check, size: 20),
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
      if (controller.hasActiveCollection || controller.hasPausedCollection || controller.ligneCollection != null || controller.chausseeCollection != null || controller.specialCollection != null) {
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
          backgroundColor: const Color(0xFF1976D2),
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
          heroTag: "cancelPolygonBtn",
          backgroundColor: const Color(0xFFE53E3E),
          foregroundColor: Colors.white,
          onPressed: onCancelPolygon,
          mini: true,
          elevation: 4,
          child: const Icon(Icons.close, size: 20),
        ),
        const SizedBox(width: 8),
        FloatingActionButton(
          heroTag: "stopPolygonBtn",
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          onPressed: onFinishPolygon,
          mini: true,
          elevation: 4,
          child: const Icon(Icons.check, size: 20),
        ),
      ],
    );
  }
}
