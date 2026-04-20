part of 'home_page.dart';

void _showSpecialLineDetailsSheetImpl(
  _HomePageState state, {
  required BuildContext context,
  required String specialType,
  required String statut,
  String? enqueteur,
  required String region,
  required String prefecture,
  required String commune,
  required double distanceKm,
  required double startLat,
  required double startLng,
  required double endLat,
  required double endLng,
}) {
  String safe(dynamic value) {
    final text = (value ?? '').toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return '----';
    return text;
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 14,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              safe(specialType),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            state._detailRow('Statut', safe(statut)),
            state._detailRow(
              'Enqueteur',
              state.enqueteurDisplayByStatut(
                enqueteurValue: enqueteur,
                statut: statut,
              ),
            ),
            if (!statut.toLowerCase().contains('localement')) ...[
              state._detailRow('Region', safe(region)),
              state._detailRow('Prefecture', safe(prefecture)),
              state._detailRow('Commune', safe(commune)),
            ],
            state._detailRow(
              'Debut',
              'X=${startLng.toStringAsFixed(6)} / Y=${startLat.toStringAsFixed(6)}',
            ),
            state._detailRow(
              'Fin',
              'X=${endLng.toStringAsFixed(6)} / Y=${endLat.toStringAsFixed(6)}',
            ),
            state._detailRow('Distance', '${distanceKm.toStringAsFixed(2)} km'),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Fermer'),
              ),
            ),
          ],
        ),
      );
    },
  );
}

void _showLineDetailsSheetImpl(
  _HomePageState state, {
  required BuildContext context,
  required String lineCode,
  String? enqueteur,
  required String region,
  required String prefecture,
  required String commune,
  required String statut,
  required int nbPoints,
  required double startLat,
  required double startLng,
  required double endLat,
  required double endLng,
  required double distanceKm,
  String? plateforme,
  String? relief,
  String? vegetation,
  String? debutTravaux,
  String? finTravaux,
  String? financement,
  String? projet,
  String? entreprise,
}) {
  String safe(String? value) => (value ?? '').trim().isEmpty ? '----' : value!.trim();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) {
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.45,
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 14,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Ligne - ${safe(lineCode)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      state._detailRow('Statut', safe(statut)),
                      state._detailRow(
                        'Enqueteur',
                        state.enqueteurDisplayByStatut(
                          enqueteurValue: enqueteur,
                          statut: statut,
                        ),
                      ),
                      if (!statut.toLowerCase().contains('localement')) ...[
                        state._detailRow('Region', safe(region)),
                        state._detailRow('Prefecture', safe(prefecture)),
                        state._detailRow('Commune', safe(commune)),
                      ],
                      state._detailRow('Nb points', nbPoints.toString()),
                      state._detailRow(
                        'Debut',
                        'X=${startLng.toStringAsFixed(6)} / Y=${startLat.toStringAsFixed(6)}',
                      ),
                      state._detailRow(
                        'Fin',
                        'X=${endLng.toStringAsFixed(6)} / Y=${endLat.toStringAsFixed(6)}',
                      ),
                      state._detailRow('Distance', '${distanceKm.toStringAsFixed(2)} km'),
                      const Divider(),
                      state._detailRow('Plateforme', safe(plateforme)),
                      state._detailRow('Relief', safe(relief)),
                      state._detailRow('Vegetation', safe(vegetation)),
                      state._detailRow('Debut travaux', safe(debutTravaux)),
                      state._detailRow('Fin travaux', safe(finTravaux)),
                      state._detailRow('Financement', safe(financement)),
                      state._detailRow('Projet', safe(projet)),
                      state._detailRow('Entreprise', safe(entreprise)),
                    ],
                  ),
                ),
              ),
              const Divider(),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Fermer'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

void _showPointDetailsSheetImpl(
  _HomePageState state, {
  required BuildContext context,
  required String type,
  required String name,
  required String region,
  required String prefecture,
  required String commune,
  required String enqueteur,
  required String lineCode,
  required double lat,
  required double lng,
  required String statut,
}) {
  String safe(String value) => value.trim().isEmpty ? '----' : value.trim();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 14,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '$type - ${safe(name)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            state._detailRow('Statut', safe(statut)),
            if (!statut.toLowerCase().contains('localement')) ...[
              state._detailRow('Region', safe(region)),
              state._detailRow('Prefecture', safe(prefecture)),
              state._detailRow('Commune', safe(commune)),
            ],
            state._detailRow(
              'Enqueteur',
              state.enqueteurDisplayByStatut(
                enqueteurValue: enqueteur,
                statut: statut,
              ),
            ),
            state._detailRow('Code ligne', safe(lineCode)),
            state._detailRow(
              'Coordonnees',
              'X=${lng.toStringAsFixed(6)} / Y=${lat.toStringAsFixed(6)}',
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Fermer'),
              ),
            ),
          ],
        ),
      );
    },
  );
}

void _handlePolylineTapImpl(_HomePageState state, Object? hitValue) {
  if (hitValue == null || hitValue is! PolylineTapData) return;

  final tapData = hitValue;
  final type = tapData.type;
  final data = tapData.data;

  debugPrint('[Polyline] tapped: type=$type');

  switch (type) {
    case 'line_local':
    case 'line_downloaded':
      state._showLineDetailsSheet(
        context: state.context,
        lineCode: (data['line_code'] ?? '----').toString(),
        statut: type == 'line_local'
            ? ((data['synced'].toString() == '1')
                ? 'Synchronisee'
                : 'Enregistree localement')
            : 'Sauvegardee (downloaded)',
        region: type == 'line_downloaded'
            ? (data['region_name'] ?? '----').toString()
            : (data['region_name'] ?? '').toString().isNotEmpty
                ? (data['region_name']).toString()
                : state._regionNom,
        prefecture: type == 'line_downloaded'
            ? (data['prefecture_name'] ?? '----').toString()
            : (data['prefecture_name'] ?? '').toString().isNotEmpty
                ? (data['prefecture_name']).toString()
                : state._prefectureNom,
        commune: type == 'line_downloaded'
            ? (data['commune_name'] ?? '----').toString()
            : (data['commune_name'] ?? '').toString().isNotEmpty
                ? (data['commune_name']).toString()
                : state._communeNom,
        enqueteur: (data['enqueteur'] ?? '').toString(),
        nbPoints: (data['nb_points'] as int?) ?? 0,
        distanceKm: (data['distance_km'] as num?)?.toDouble() ?? 0.0,
        startLat: (data['start_lat'] as num).toDouble(),
        startLng: (data['start_lng'] as num).toDouble(),
        endLat: (data['end_lat'] as num).toDouble(),
        endLng: (data['end_lng'] as num).toDouble(),
        plateforme: (data['platform'] ?? '----').toString(),
        relief: (data['relief'] ?? '----').toString(),
        vegetation: (data['vegetation'] ?? '----').toString(),
        debutTravaux: (data['work_start'] ?? '----').toString(),
        finTravaux: (data['work_end'] ?? '----').toString(),
        financement: (data['funding'] ?? '----').toString(),
        projet: (data['project'] ?? '----').toString(),
        entreprise: (data['company'] ?? '----').toString(),
      );
      break;

    case 'special_local':
    case 'special_downloaded':
      state._showSpecialLineDetailsSheet(
        context: state.context,
        specialType: (data['special_type'] ?? '----').toString(),
        statut: type == 'special_local'
            ? ((data['synced'].toString() == '1')
                ? 'Synchronisee'
                : 'Enregistree localement')
            : 'Sauvegardee (downloaded)',
        region: type == 'special_downloaded'
            ? (data['region_name'] ?? '----').toString()
            : (data['region_name'] ?? '').toString().isNotEmpty
                ? (data['region_name']).toString()
                : state._regionNom,
        prefecture: type == 'special_downloaded'
            ? (data['prefecture_name'] ?? '----').toString()
            : (data['prefecture_name'] ?? '').toString().isNotEmpty
                ? (data['prefecture_name']).toString()
                : state._prefectureNom,
        commune: type == 'special_downloaded'
            ? (data['commune_name'] ?? '----').toString()
            : (data['commune_name'] ?? '').toString().isNotEmpty
                ? (data['commune_name']).toString()
                : state._communeNom,
        enqueteur: (data['enqueteur'] ?? '').toString(),
        distanceKm: (data['distance_km'] as num?)?.toDouble() ?? 0.0,
        startLat: (data['start_lat'] as num).toDouble(),
        startLng: (data['start_lng'] as num).toDouble(),
        endLat: (data['end_lat'] as num).toDouble(),
        endLng: (data['end_lng'] as num).toDouble(),
      );
      break;
  }
}

void _handlePolygonTapImpl(_HomePageState state, Object? hitValue) {
  if (hitValue == null || hitValue is! PolygonTapData) return;
  final data = hitValue;

  showModalBottomSheet(
    context: state.context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 14,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Zone de Plaine - ${data.nom}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            state._detailRow('Statut', data.statut),
            state._detailRow('Code ligne', data.lineCode),
            if (data.downloaded || data.synced) ...[
              state._detailRow('Region', data.regionName.isEmpty ? '----' : data.regionName),
              state._detailRow('Prefecture', data.prefectureName.isEmpty ? '----' : data.prefectureName),
              state._detailRow('Commune', data.communeName.isEmpty ? '----' : data.communeName),
            ],
            state._detailRow('Superficie', '${data.superficie.toStringAsFixed(4)} ha'),
            state._detailRow('Sommets', '${data.nbSommets} points'),
            state._detailRow(
              'Enqueteur',
              state.enqueteurDisplayByStatut(
                enqueteurValue: data.enqueteur,
                statut: data.statut,
              ),
            ),
            state._detailRow(
              'Date creation',
              data.dateCreation.length > 10
                  ? data.dateCreation.substring(0, 10)
                  : data.dateCreation,
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Fermer'),
              ),
            ),
          ],
        ),
      );
    },
  );
}
