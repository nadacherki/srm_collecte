part of 'home_page.dart';

extension _HomePageCollectionActions on _HomePageState {
  Future<void> _startSpecialCollectionImpl(String type) async {
    if (!homeController.gpsEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez activer le GPS')),
      );
      return;
    }

    if (homeController.hasActiveCollection) {
      final activeType = homeController.activeCollectionType;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Veuillez mettre en pause la collecte de $activeType en cours',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await homeController.startSpecialCollection(type);
      if (!mounted) return;

      _setStateFromPart(() {
        _isSpecialCollection = true;
        _specialCollectionType = type;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Collecte de $type démarrée'),
          backgroundColor: Colors.purple,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _finishSpecialCollectionImpl() async {
    if (_isPolygonCollection) {
      final currentPolygonPoints =
          homeController.specialCollection?.points.length ?? 0;
      if (currentPolygonPoints < 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Un polygone doit contenir au moins 3 points. ($currentPolygonPoints collectés)',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final result = homeController.finishSpecialCollection();
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Impossible de finaliser le polygone pour le moment. Réessayez après avoir ajouté des points.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      _setStateFromPart(() {
        _pendingPolygonPreviewPoints = List<LatLng>.from(result.points);
      });

      final polygonMetier = _pendingSrmPolygoneMetier;
      final polygonEntityType = _pendingSrmPolygoneEntityType;
      if (polygonMetier == null || polygonEntityType == null) {
        _setStateFromPart(() {
          _isSpecialCollection = false;
          _isPolygonCollection = false;
          _specialCollectionType = null;
          _pendingPolygonPreviewPoints = null;
        });
        _pendingSrmPolygoneMetier = null;
        _pendingSrmPolygoneEntityType = null;
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
          ),
        ),
      );
      _pendingSrmPolygoneMetier = null;
      _pendingSrmPolygoneEntityType = null;

      if (!mounted) return;
      _refreshAfterNavigation();

      _setStateFromPart(() {
        _isSpecialCollection = false;
        _isPolygonCollection = false;
        _specialCollectionType = null;
        if (formResult == null) {
          _pendingPolygonPreviewPoints = null;
        }
      });

      if (formResult != null) {
        await _loadDisplayedPolygons();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$polygonEntityType enregistré avec succès'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
      return;
    }

    final result = homeController.finishSpecialCollection();
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Une ligne doit contenir au moins 2 points.')),
      );
      return;
    }

    if (result.points.length >= 2 &&
        result.points.first.latitude == result.points.last.latitude &&
        result.points.first.longitude == result.points.last.longitude) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La ligne doit avoir un point de début et de fin différents. Veuillez vous déplacer pendant la collecte.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      _setStateFromPart(() {
        _isSpecialCollection = false;
        _specialCollectionType = null;
      });
      return;
    }

    final formResult = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SpecialLineFormPage(
          linePoints: result.points,
          provisionalCode: result.lineCode ?? '',
          startTime: result.startTime,
          endTime: result.endTime,
          agentName: widget.agentName,
          specialType: _specialCollectionType!,
          totalDistance: result.totalDistance,
          activeLineCode: homeController.activeLineCode,
        ),
      ),
    );

    if (!mounted) return;
    _refreshAfterNavigation();

    _setStateFromPart(() {
      _isSpecialCollection = false;
      _specialCollectionType = null;
    });

    if (formResult != null) {
      await _loadDisplayedSpecialLines();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Données enregistrées avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _cancelSpecialCollectionImpl() async {
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

    homeController.cancelSpecialCollection();
    if (!mounted) return;

    _setStateFromPart(() {
      _isSpecialCollection = false;
      _isPolygonCollection = false;
      _specialCollectionType = null;
      _pendingPolygonPreviewPoints = null;
      _pendingSrmPolygoneMetier = null;
      _pendingSrmPolygoneEntityType = null;
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
        (homeController.specialCollection?.isActive ?? false)) {
      _addCurrentPointToActiveCollection();
      return;
    }

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
          latitude: current.latitude,
          longitude: current.longitude,
          altitude: homeController.collectionManager.currentAltitude,
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

  void _addCurrentPointToActiveCollection() {
    final error = homeController.addCurrentPointToActiveCollection();

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final pointCount = homeController.ligneCollection?.points.length ??
        homeController.specialCollection?.points.length ??
        0;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Point ajouté au tracé ($pointCount total)'),
        backgroundColor: const Color(0xFFF59E0B),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  Future<void> _startLigneSrmCollectionImpl() async {
    if (!mounted) return;
    final selection = await showSrmLigneSelector(context);
    if (!mounted || selection == null) return;

    if (!homeController.gpsEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez activer le GPS')),
      );
      return;
    }
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Tracé ${selection.entityType} démarré, ajoutez les points avec le bouton jaune',
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
    if (m == null || e == null) {
      if (!mounted) return;
      final sel = await showSrmPolygoneSelector(context);
      if (!mounted || sel == null) return;
      m = sel.metier;
      e = sel.entityType;
    }

    _pendingSrmPolygoneMetier = m;
    _pendingSrmPolygoneEntityType = e;

    try {
      await homeController.startSpecialCollection(e);
      if (!mounted) return;

      _setStateFromPart(() {
        _isSpecialCollection = true;
        _isPolygonCollection = true;
        _specialCollectionType = e;
        _pendingPolygonPreviewPoints = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Tracé $e démarré. Ajoutez les points avec le bouton jaune'),
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

  void _toggleSpecialCollectionImpl() {
    try {
      if (homeController.specialCollection?.isActive ?? false) {
        homeController.collectionManager.setSrmMetadata({
          'srmMetier': _pendingSrmPolygoneMetier,
          'srmEntityType': _pendingSrmPolygoneEntityType,
          'isPolygonCollection': _isPolygonCollection,
          'isSpecialCollection': _isSpecialCollection,
          'specialCollectionType': _specialCollectionType,
        });
      }
      homeController.toggleSpecialCollection();
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
              'Trace remis en pause. Une selection SRM est requise pour finaliser la ligne.',
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
}
