import 'package:flutter/material.dart';
import '../../controllers/home_controller.dart';

class MapControlsWidget extends StatelessWidget {
  final HomeController controller;
  final VoidCallback onAddPoint;
  final VoidCallback onStartLigne;
  final VoidCallback onStartPolygon;
  final VoidCallback onToggleLigne;
  final VoidCallback onTogglePolygon;
  final VoidCallback onUndoLigne;
  final VoidCallback onRedoLigne;
  final VoidCallback onUndoPolygon;
  final VoidCallback onRedoPolygon;
  final VoidCallback onFinishLigne;
  final VoidCallback onFinishPolygon;
  final VoidCallback onCancelLigne;
  final VoidCallback onCancelPolygon;
  final VoidCallback onRefresh;
  final bool canRedoLigne;
  final bool canRedoPolygon;
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
    required this.onUndoLigne,
    required this.onRedoLigne,
    required this.onUndoPolygon,
    required this.onRedoPolygon,
    required this.onFinishLigne,
    required this.onFinishPolygon,
    required this.onCancelLigne,
    required this.onCancelPolygon,
    required this.onRefresh,
    required this.canRedoLigne,
    required this.canRedoPolygon,
    required this.isSpecialCollection,
    this.isPolygonCollection = false,
    required this.onStopSpecial,
  });

  @override
  Widget build(BuildContext context) {
    final hasLigneContext = controller.ligneCollection != null;
    final hasPolygonContext =
        isSpecialCollection && isPolygonCollection && controller.specialCollection != null;
    // SPRINT 7 fix : le bouton Point doit apparaître aussi quand la collecte est en PAUSE
    final showAddPointForLigne = (controller.ligneCollection?.isActive ?? false) ||
        (controller.ligneCollection?.isPaused ?? false);
    final showAddPointForPolygon = isPolygonCollection &&
        ((controller.specialCollection?.isActive ?? false) ||
            (controller.specialCollection?.isPaused ?? false));

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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final gap = constraints.maxWidth < 330 ? 8.0 : 12.0;
                final rawButtonWidth = (constraints.maxWidth - (gap * 2)) / 3;
                final buttonWidth =
                    rawButtonWidth > 110 ? 110.0 : rawButtonWidth;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: hasLigneContext
                      ? [
                          if (showAddPointForLigne)
                            _buildPointControls(compact: true),
                          if (showAddPointForLigne) SizedBox(width: gap),
                          _buildLigneControls(),
                        ]
                      : hasPolygonContext
                          ? [
                              if (showAddPointForPolygon)
                                _buildPointControls(compact: true),
                              if (showAddPointForPolygon) SizedBox(width: gap),
                              _buildPolygonControls(),
                            ]
                          : [
                              _buildDefaultControlButton(
                                width: buttonWidth,
                                child: _buildPointControls(),
                              ),
                              SizedBox(width: gap),
                              _buildDefaultControlButton(
                                width: buttonWidth,
                                child: _buildLigneControls(),
                              ),
                              SizedBox(width: gap),
                              _buildDefaultControlButton(
                                width: buttonWidth,
                                child: _buildPolygonControls(),
                              ),
                            ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultControlButton({
    required double width,
    required Widget child,
  }) {
    return SizedBox(
      width: width <= 0 ? 1 : width,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(width: 110, child: child),
      ),
    );
  }

  Widget _buildPointControls({bool compact = false}) {
    final isManualCollectionActive =
        (controller.ligneCollection?.isActive ?? false) ||
        (isPolygonCollection && (controller.specialCollection?.isActive ?? false));
    final hasManualCollectionContext =
        controller.ligneCollection != null ||
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
      if (compact) {
        return Tooltip(
          message: "Ajouter un point au tracé",
          child: FloatingActionButton(
            heroTag: "addPointBtn",
            mini: true,
            backgroundColor: const Color(0xFFF59E0B),
            foregroundColor: Colors.white,
            onPressed: onAddPoint,
            elevation: 4,
            child: const Icon(Icons.add_location_alt, size: 20),
          ),
        );
      }

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

    // ── SPRINT 7 : Quand une collecte est en PAUSE, afficher le bouton Point
    // pour permettre le levé de points indépendants ──
    if (!controller.hasPausedCollection) {
      if (hasManualCollectionContext || controller.hasActiveCollection) {
        return const SizedBox.shrink();
      }
    }

    if (compact) {
      return Tooltip(
        message: "Point",
        child: FloatingActionButton(
          heroTag: "pointBtn",
          mini: true,
          backgroundColor: const Color(0xFFE53E3E),
          foregroundColor: Colors.white,
          onPressed: onAddPoint,
          elevation: 4,
          child: const Icon(Icons.place, size: 20),
        ),
      );
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

  Widget _buildTraceActionButton({
    required String heroTag,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    required String tooltip,
  }) {
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: FloatingActionButton(
        heroTag: heroTag,
        backgroundColor: enabled ? color : Colors.grey.shade400,
        foregroundColor: Colors.white,
        onPressed: onPressed,
        mini: true,
        elevation: enabled ? 4 : 1,
        child: Icon(icon, size: 20),
      ),
    );
  }

  Widget _buildLigneControls() {
    final ligneCollection = controller.ligneCollection;

    if (ligneCollection == null || ligneCollection.isInactive) {
      if (controller.hasActiveCollection || controller.hasPausedCollection || controller.specialCollection != null) {
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
      return FittedBox(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTraceActionButton(
              heroTag: "undoLigneBtn",
              icon: Icons.undo,
              color: const Color(0xFF455A64),
              onPressed: ligneCollection.points.isNotEmpty ? onUndoLigne : null,
              tooltip: "Revenir en arrière",
            ),
            const SizedBox(width: 6),
            _buildTraceActionButton(
              heroTag: "redoLigneBtn",
              icon: Icons.redo,
              color: const Color(0xFF455A64),
              onPressed: canRedoLigne ? onRedoLigne : null,
              tooltip: "Rétablir",
            ),
            const SizedBox(width: 6),
            _buildTraceActionButton(
              heroTag: "pauseLigneBtn",
              icon: ligneCollection.isPaused ? Icons.play_arrow : Icons.pause,
              color: const Color(0xFF1976D2),
              onPressed: onToggleLigne,
              tooltip: ligneCollection.isPaused ? "Reprendre" : "Pause",
            ),
            const SizedBox(width: 6),
            _buildTraceActionButton(
              heroTag: "cancelLigneBtn",
              icon: Icons.close,
              color: const Color(0xFFE53E3E),
              onPressed: onCancelLigne,
              tooltip: "Annuler le tracé",
            ),
            const SizedBox(width: 6),
            _buildTraceActionButton(
              heroTag: "stopLigneBtn",
              icon: Icons.check,
              color: const Color(0xFF2E7D32),
              onPressed: onFinishLigne,
              tooltip: "Valider",
            ),
          ],
        ),
      );
    }
  }

  Widget _buildPolygonControls() {
    final specialCollection = controller.specialCollection;
    final isPolygonActive =
        isSpecialCollection && isPolygonCollection && specialCollection != null;

    if (!isPolygonActive) {
      if (controller.hasActiveCollection || controller.hasPausedCollection || controller.ligneCollection != null || controller.specialCollection != null) {
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

    return FittedBox(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTraceActionButton(
            heroTag: "undoPolygonBtn",
            icon: Icons.undo,
            color: const Color(0xFF455A64),
            onPressed: specialCollection.points.isNotEmpty ? onUndoPolygon : null,
            tooltip: "Revenir en arrière",
          ),
          const SizedBox(width: 6),
          _buildTraceActionButton(
            heroTag: "redoPolygonBtn",
            icon: Icons.redo,
            color: const Color(0xFF455A64),
            onPressed: canRedoPolygon ? onRedoPolygon : null,
            tooltip: "Rétablir",
          ),
          const SizedBox(width: 6),
          _buildTraceActionButton(
            heroTag: "pausePolygonBtn",
            icon: specialCollection.isPaused ? Icons.play_arrow : Icons.pause,
            color: const Color(0xFF1976D2),
            onPressed: onTogglePolygon,
            tooltip: specialCollection.isPaused ? "Reprendre" : "Pause",
          ),
          const SizedBox(width: 6),
          _buildTraceActionButton(
            heroTag: "cancelPolygonBtn",
            icon: Icons.close,
            color: const Color(0xFFE53E3E),
            onPressed: onCancelPolygon,
            tooltip: "Annuler le polygone",
          ),
          const SizedBox(width: 6),
          _buildTraceActionButton(
            heroTag: "stopPolygonBtn",
            icon: Icons.check,
            color: const Color(0xFF2E7D32),
            onPressed: onFinishPolygon,
            tooltip: "Valider",
          ),
        ],
      ),
    );
  }
}
