part of 'home_page.dart';

extension _HomePageCollectionActions on _HomePageState {
  bool _ensureGpsReadyForCapture() {
    if (homeController.gpsEnabled && homeController.currentAltitude != null) {
      return true;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Veuillez activer le GPS')),
    );
    return false;
  }

  Future<void> _finishPolygonCollectionImpl() async {
    final currentPolygonPoints =
        homeController.polygonCollection?.points.length ?? 0;
    if (currentPolygonPoints < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Un polygone doit contenir au moins 3 points. ($currentPolygonPoints collectes)',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = homeController.finishPolygonCollection();
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Impossible de finaliser le polygone pour le moment. Reessayez apres avoir ajoute des points.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    _polygonRedoPoints.clear();

    _setStateFromPart(() {
      _pendingPolygonPreviewPoints = List<LatLng>.from(result.points);
    });

    final polygonMetier = _pendingSrmPolygoneMetier;
    final polygonEntityType = _pendingSrmPolygoneEntityType;
    final polygonTitleApp = _pendingSrmPolygoneTitleApp;
    if (polygonMetier == null || polygonEntityType == null) {
      _setStateFromPart(() {
        _isPolygonCollection = false;
        _polygonEntityType = null;
        _pendingPolygonPreviewPoints = null;
      });
      _pendingSrmPolygoneMetier = null;
      _pendingSrmPolygoneEntityType = null;
      _pendingSrmPolygoneTitleApp = null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contexte du polygone introuvable.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final formResult = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PolygonFormPage(
          polygonPoints: result.points,
          startTime: result.startTime,
          endTime: result.endTime,
          agentName: widget.agentName,
          metier: polygonMetier,
          entityType: polygonEntityType,
          displayTitle: polygonTitleApp,
        ),
      ),
    );
    _pendingSrmPolygoneMetier = null;
    _pendingSrmPolygoneEntityType = null;
    _pendingSrmPolygoneTitleApp = null;

    if (!mounted) return;
    _refreshAfterNavigation();

    _setStateFromPart(() {
      _isPolygonCollection = false;
      _polygonEntityType = null;
      if (formResult == null) {
        _pendingPolygonPreviewPoints = null;
      }
    });

    if (formResult != null) {
      final savedTitle = (polygonTitleApp?.trim().isNotEmpty == true)
          ? polygonTitleApp!.trim()
          : polygonEntityType;
      await _loadDisplayedPolygons();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$savedTitle enregistre avec succes'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _cancelPolygonCollectionImpl() async {
    final wasPolygon = _isPolygonCollection;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(wasPolygon ? 'Annuler le polygone' : 'Annuler le tracé'),
        content: Text(
          wasPolygon
              ? 'Voulez-vous vraiment annuler ce polygone ? Les points collectés ne seront pas enregistrés.'
              : 'Voulez-vous vraiment annuler ce tracé ? Les points collectés ne seront pas enregistrés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Non'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53E3E),
              foregroundColor: Colors.white,
            ),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    homeController.cancelPolygonCollection();
    if (!mounted) return;

    _setStateFromPart(() {
      _polygonRedoPoints.clear();
      _isPolygonCollection = false;
      _polygonEntityType = null;
      _pendingPolygonPreviewPoints = null;
      _pendingSrmPolygoneMetier = null;
      _pendingSrmPolygoneEntityType = null;
      _pendingSrmPolygoneTitleApp = null;
      homeController.collectedPolylines.clear();
      collectedPolylines.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(wasPolygon ? 'Polygone annulé' : 'Tracé annulé'),
        backgroundColor: const Color(0xFFE53E3E),
      ),
    );
  }

  Future<void> _addPointOfInterestImpl() async {
    if ((homeController.ligneCollection?.isActive ?? false) ||
        (homeController.polygonCollection?.isActive ?? false)) {
      _addCurrentPointToActiveCollection();
      return;
    }

    if (!_ensureGpsReadyForCapture()) return;

    if (!mounted) return;
    final selection = await showSrmPointSelector(context);
    if (!mounted || selection == null) return;

    final current = homeController.userPosition;

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SrmPointFormWidget(
          metier: selection.metier,
          entityType: selection.entityType,
          displayTitle: selection.titleApp,
          latitude: current.latitude,
          longitude: current.longitude,
          altitude: homeController.currentAltitude,
          agentName: widget.agentName,
          onSaved: () {
            if (!mounted) return;
            Navigator.pop(context);
            _refreshAfterNavigation();
          },
          onCancel: () {
            if (!mounted) return;
            Navigator.pop(context);
          },
        ),
      ),
    );
    if (!mounted) return;
    _refreshAfterNavigation();
  }

  void _undoLignePointImpl() {
    _undoTracePoint(
      type: CollectionType.ligne,
      redoStack: _ligneRedoPoints,
      emptyMessage: 'Aucun point de ligne à retirer.',
      restoredLabel: 'ligne',
    );
  }

  void _redoLignePointImpl() {
    _redoTracePoint(
      type: CollectionType.ligne,
      redoStack: _ligneRedoPoints,
      emptyMessage: 'Aucun point de ligne à rétablir.',
      restoredLabel: 'ligne',
    );
  }

  void _undoPolygonPointImpl() {
    _undoTracePoint(
      type: CollectionType.polygon,
      redoStack: _polygonRedoPoints,
      emptyMessage: 'Aucun point de polygone à retirer.',
      restoredLabel: 'polygone',
    );
  }

  void _redoPolygonPointImpl() {
    _redoTracePoint(
      type: CollectionType.polygon,
      redoStack: _polygonRedoPoints,
      emptyMessage: 'Aucun point de polygone à rétablir.',
      restoredLabel: 'polygone',
    );
  }

  void _undoTracePoint({
    required CollectionType type,
    required List<CollectionPointEdit> redoStack,
    required String emptyMessage,
    required String restoredLabel,
  }) {
    final edit = homeController.undoLastCollectionPoint(type);
    if (edit == null) {
      _showTraceEditSnack(emptyMessage, Colors.orange);
      return;
    }

    redoStack.add(edit);
    final remaining = _collectionPointCount(type);
    _setStateFromPart(() {});
    _showTraceEditSnack(
      'Dernier point retiré du $restoredLabel ($remaining restant)',
      const Color(0xFF455A64),
    );
  }

  void _redoTracePoint({
    required CollectionType type,
    required List<CollectionPointEdit> redoStack,
    required String emptyMessage,
    required String restoredLabel,
  }) {
    if (redoStack.isEmpty) {
      _showTraceEditSnack(emptyMessage, Colors.orange);
      return;
    }

    final edit = redoStack.removeLast();
    final restored = homeController.redoCollectionPoint(type, edit);
    if (!restored) {
      redoStack.add(edit);
      _showTraceEditSnack(
        'Impossible de rétablir ce point pour le moment.',
        Colors.orange,
      );
      return;
    }

    final total = _collectionPointCount(type);
    _setStateFromPart(() {});
    _showTraceEditSnack(
      'Point rétabli dans le $restoredLabel ($total total)',
      const Color(0xFF455A64),
    );
  }

  int _collectionPointCount(CollectionType type) {
    if (type == CollectionType.ligne) {
      return homeController.ligneCollection?.points.length ?? 0;
    }
    return homeController.polygonCollection?.points.length ?? 0;
  }

  void _showTraceEditSnack(String message, Color color) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: color,
            duration: const Duration(milliseconds: 1100),
          ),
        );
    });
  }

  void _addCurrentPointToActiveCollection() {
    if (!_ensureGpsReadyForCapture()) return;

    final error = homeController.addCurrentPointToActiveCollection();

    if (error != null) {
      _showTraceEditSnack(error, Colors.orange);
      return;
    }

    if (homeController.ligneCollection?.isActive ?? false) {
      _ligneRedoPoints.clear();
    }
    if (_isPolygonCollection &&
        (homeController.polygonCollection?.isActive ?? false)) {
      _polygonRedoPoints.clear();
    }

    _setStateFromPart(() {});
  }

  Future<void> _startLigneSrmCollectionImpl() async {
    if (!mounted) return;
    if (!_ensureGpsReadyForCapture()) return;

    final selection = await showSrmLigneSelector(context);
    if (!mounted || selection == null) return;

    if (homeController.hasActiveCollection) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Collecte de ${homeController.activeCollectionType} en cours, mettez-la en pause d'abord",
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    _pendingSrmLigneSelection = selection;

    final fakeCode =
        'SRM_${selection.tableName}_${DateTime.now().millisecondsSinceEpoch}';
    try {
      await homeController.startLigneCollection(fakeCode);
      if (!mounted) return;
      _ligneRedoPoints.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Tracé ${selection.titleApp} démarré, ajoutez les points avec le bouton jaune',
          ),
          backgroundColor: Color(SrmConfig.getMetierColor(selection.metier)),
          duration: const Duration(seconds: 3),
        ),
      );
      _setStateFromPart(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _startPolygonCollectionImpl({
    String? metier,
    String? entityType,
  }) async {
    if (!homeController.gpsEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez activer le GPS')),
      );
      return;
    }

    if (homeController.hasActiveCollection) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez terminer la collecte en cours'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    var m = metier;
    var e = entityType;
    String? titleApp;
    if (m == null || e == null) {
      if (!mounted) return;
      final sel = await showSrmPolygoneSelector(context);
      if (!mounted || sel == null) return;
      m = sel.metier;
      e = sel.entityType;
      titleApp = sel.titleApp;
    }

    _pendingSrmPolygoneMetier = m;
    _pendingSrmPolygoneEntityType = e;
    _pendingSrmPolygoneTitleApp = titleApp ?? e;

    try {
      await homeController.startPolygonCollection(e);
      if (!mounted) return;

      _setStateFromPart(() {
        _isPolygonCollection = true;
        _polygonEntityType = e;
        _pendingPolygonPreviewPoints = null;
        _polygonRedoPoints.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Tracé ${_pendingSrmPolygoneTitleApp ?? e} démarré. Ajoutez les points avec le bouton jaune',
          ),
          backgroundColor: _pendingSrmPolygoneMetier != null
              ? Color(SrmConfig.getMetierColor(_pendingSrmPolygoneMetier!))
              : const Color(0xFF1B5E20),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err.toString()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _togglePolygonCollectionImpl() {
    try {
      if (homeController.polygonCollection?.isActive ?? false) {
        homeController.collectionManager.setSrmMetadata({
          'srmMetier': _pendingSrmPolygoneMetier,
          'srmEntityType': _pendingSrmPolygoneEntityType,
          'srmTitleApp': _pendingSrmPolygoneTitleApp,
          'isPolygonCollection': _isPolygonCollection,
          'polygonEntityType': _polygonEntityType,
        });
      }
      homeController.togglePolygonCollection();
      _setStateFromPart(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _toggleLigneCollectionImpl() {
    try {
      if (homeController.ligneCollection?.isActive ?? false) {
        final sel = _pendingSrmLigneSelection;
        homeController.collectionManager.setSrmMetadata({
          'srmMetier': sel?.metier,
          'srmEntityType': sel?.entityType,
          'srmTitleApp': sel?.titleApp,
          'srmTableName': sel?.tableName,
          'srmSchema': sel?.schema,
        });
      }
      homeController.toggleLigneCollection();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _finishLigneCollectionImpl() async {
    final result = homeController.finishLigneCollection();
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le tracé doit contenir au moins 2 points.'),
        ),
      );
      _pendingSrmLigneSelection = null;
      return;
    }

    final lineId = result['id'] as int;
    final lineCode = result['lineCode'] as String;
    final points = List<LatLng>.from(result['points'] as List<LatLng>);
    final startTime = result['startTime'] as DateTime;
    final endTime = result['endTime'] as DateTime?;
    final totalDistance = (result['totalDistance'] as num).toDouble();

    final geometryEditItem = _geometryEditLineItem;
    if (geometryEditItem != null) {
      await _saveEditedLineGeometry(
        geometryEditItem: geometryEditItem,
        lineId: lineId,
        lineCode: lineCode,
        points: points,
        startTime: startTime,
        endTime: endTime,
        totalDistance: totalDistance,
      );
      return;
    }

    var sel = _pendingSrmLigneSelection;
    if (sel == null) {
      if (!mounted) return;
      sel = await showSrmLigneSelector(context);
      if (!mounted) return;

      if (sel == null) {
        await homeController.restoreFinishedLigneAsPaused(
          id: lineId,
          lineCode: lineCode,
          points: points,
          startTime: startTime,
          lastPointTime: endTime,
          totalDistance: totalDistance,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Trace remise en pause. Une sélection SRM est requise pour finaliser la ligne.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    final effectiveSel = sel;
    final srmMetadata = {
      'srmMetier': effectiveSel.metier,
      'srmEntityType': effectiveSel.entityType,
      'srmTitleApp': effectiveSel.titleApp,
      'srmTableName': effectiveSel.tableName,
      'srmSchema': effectiveSel.schema,
    };

    await homeController.restoreFinishedLigneAsPaused(
      id: lineId,
      lineCode: lineCode,
      points: points,
      startTime: startTime,
      lastPointTime: endTime,
      totalDistance: totalDistance,
      srmMetadata: srmMetadata,
    );
    if (!mounted) return;

    _pendingSrmLigneSelection = null;

    _setStateFromPart(() {
      homeController.collectedPolylines.clear();
      collectedPolylines.clear();
    });

    if (!mounted) return;
    final formResult = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SrmLigneFormPage(
          metier: effectiveSel.metier,
          entityType: effectiveSel.entityType,
          displayTitle: effectiveSel.titleApp,
          linePoints: points,
          startTime: startTime,
          endTime: endTime,
          agentName: widget.agentName,
          averageAltitude: homeController.collectionManager.averageAltitude,
        ),
      ),
    );
    if (!mounted) return;

    if (formResult == null) {
      _pendingSrmLigneSelection = effectiveSel;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tracé remis en pause après fermeture du formulaire'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    homeController.cancelLigneCollection();
    _ligneRedoPoints.clear();
    _refreshAfterNavigation();
  }

  Future<void> _cancelLigneCollectionImpl() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler le tracé'),
        content: const Text(
          'Voulez-vous vraiment annuler ce tracé ? Les points collectés ne seront pas enregistrés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Non'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53E3E),
              foregroundColor: Colors.white,
            ),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    homeController.cancelLigneCollection();
    _pendingSrmLigneSelection = null;
    _ligneRedoPoints.clear();
    _geometryEditLineItem = null;

    if (!mounted) return;
    _setStateFromPart(() {
      homeController.collectedPolylines.clear();
      collectedPolylines.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tracé annulé'),
        backgroundColor: Color(0xFFE53E3E),
      ),
    );
  }

  Future<void> _saveEditedLineGeometry({
    required Map<String, dynamic> geometryEditItem,
    required int lineId,
    required String lineCode,
    required List<LatLng> points,
    required DateTime startTime,
    required DateTime? endTime,
    required double totalDistance,
  }) async {
    final tableName = geometryEditItem['source_table']?.toString() ?? '';
    final id = _dynamicToIntImpl(geometryEditItem['id']) ?? lineId;
    if (tableName.isEmpty || id <= 0 || points.length < 2) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Géométrie de ligne invalide.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final projection = ProjectionService();
    final startProjected = projection.wgs84ToMerchich(
      longitude: points.first.longitude,
      latitude: points.first.latitude,
    );
    final endProjected = projection.wgs84ToMerchich(
      longitude: points.last.longitude,
      latitude: points.last.latitude,
    );

    final data = <String, dynamic>{
      'points_json': jsonEncode(
        points.map((p) => {'lat': p.latitude, 'lon': p.longitude}).toList(),
      ),
      'nb_points': points.length,
      'distance_m': totalDistance,
      'x_debut': startProjected.x,
      'y_debut': startProjected.y,
      'x_fin': endProjected.x,
      'y_fin': endProjected.y,
      'lat_debut': points.first.latitude,
      'lon_debut': points.first.longitude,
      'lat_fin': points.last.latitude,
      'lon_fin': points.last.longitude,
      'synced': 0,
      'date_collecte': DateTime.now().toIso8601String(),
      'mode_localisation': 'gnss',
    };

    try {
      await DatabaseHelper().updateEntitySrm(
        tableName,
        id,
        data,
        recordHistory: true,
      );

      _geometryEditLineItem = null;
      _ligneRedoPoints.clear();
      _pendingSrmLigneSelection = null;
      await _refreshAfterNavigation();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Géométrie de ligne mise à jour.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      await homeController.restoreFinishedLigneAsPaused(
        id: id,
        lineCode: lineCode,
        points: points,
        startTime: startTime,
        lastPointTime: endTime,
        totalDistance: totalDistance,
        srmMetadata: {
          'srmMetier': geometryEditItem['source_metier'],
          'srmEntityType': geometryEditItem['source_entity'],
          'srmTitleApp': geometryEditItem['source_title'],
          'srmTableName': tableName,
          'geometryEdit': true,
        },
      );
      _geometryEditLineItem = geometryEditItem;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur édition géométrie : $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
