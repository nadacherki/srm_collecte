import '../core/config/srm_config.dart';
import '../data/local/database_helper.dart';
import '../data/remote/api_service.dart';

class SyncResult {
  int successCount = 0;
  int failedCount = 0;
  int skippedCount = 0;
  final List<String> errors = [];

  @override
  String toString() =>
      'Synchronisation: $successCount succes, $failedCount echecs, $skippedCount ignores';
}

class _TableInfo {
  final String metier;
  final String entity;
  final String schema;
  final String table;
  final String endpoint;
  final String geometryLabel;

  const _TableInfo({
    required this.metier,
    required this.entity,
    required this.schema,
    required this.table,
    required this.endpoint,
    required this.geometryLabel,
  });
}

class SyncService {
  final DatabaseHelper dbHelper = DatabaseHelper();

  Future<SyncResult> downloadAllData({
    Function(double, String, int, int)? onProgress,
  }) async {
    final tables = _collectSrmTables();
    final result = SyncResult();
    final total = tables.isEmpty ? 1 : tables.length;
    final nowIso = DateTime.now().toIso8601String();
    final downloadStartedAt = DateTime.now().toUtc();
    final updatedAfter = await dbHelper.getLastDownloadTime();

    for (int index = 0; index < tables.length; index++) {
      final info = tables[index];
      final current = index + 1;

      onProgress?.call(
        current / total,
        'Téléchargement ${info.geometryLabel} · ${info.endpoint}',
        current,
        total,
      );

      try {
        final remoteItems = await ApiService.fetchData(
          info.endpoint,
          updatedAfter: updatedAfter,
        );

        for (final item in remoteItems) {
          final map = _normalizeRemoteItem(item);
          if (map == null) {
            result.skippedCount++;
            continue;
          }

          final uuid = map['uuid']?.toString();
          if (uuid == null || uuid.isEmpty) {
            result.skippedCount++;
            continue;
          }

          map.remove('id');
          map['downloaded'] = 1;
          map['synced'] = 1;
          map['date_sync'] = nowIso;

          await dbHelper.insertEntitySrm(info.table, map);
          result.successCount++;
        }
      } catch (e) {
        result.failedCount++;
        result.errors.add('Telechargement ${info.table}: ${_short(e)}');
      }
    }

    if (result.failedCount == 0 && result.skippedCount == 0) {
      await dbHelper.saveLastDownloadTime(downloadStartedAt);
    }

    return result;
  }

  Future<SyncResult> syncAllDataSequential({
    Function(double, String, int, int)? onProgress,
  }) async {
    final tables = _collectSrmTables();
    final result = SyncResult();
    final total = tables.isEmpty ? 1 : tables.length;
    final nowIso = DateTime.now().toIso8601String();

    for (int index = 0; index < tables.length; index++) {
      final info = tables[index];
      final current = index + 1;

      onProgress?.call(
        (current - 1) / total,
        'Synchronisation ${info.geometryLabel} · ${info.endpoint}',
        current - 1,
        total,
      );

      try {
        final rows = await dbHelper.getUnsyncedSrm(info.table);

        if (rows.isEmpty) {
          result.skippedCount++;
          onProgress?.call(
            current / total,
            'Synchronisation ${info.geometryLabel} · ${info.endpoint}',
            current,
            total,
          );
          continue;
        }

        for (final row in rows) {
          if (_isDownloadedRow(row)) {
            result.skippedCount++;
            continue;
          }

          final payload = Map<String, dynamic>.from(row);
          payload.remove('id');
          payload.remove('downloaded');
          payload.remove('synced');
          payload.remove('date_sync');
          _normalizeSyncPayload(payload);

          final response = await ApiService.postData(
            info.endpoint,
            payload,
            throwOnError: true,
          );
          if (response == null) {
            throw Exception('reponse vide API');
          }

          final localId = row['id'];
          if (localId is int) {
            await dbHelper.updateEntitySrm(
              info.table,
              localId,
              {
                'synced': 1,
                'date_sync': nowIso,
              },
            );
          } else {
            final db = await dbHelper.database;
            await db.update(
              info.table,
              {
                'synced': 1,
                'date_sync': nowIso,
              },
              where: 'uuid = ?',
              whereArgs: [row['uuid']],
            );
          }

          result.successCount++;
        }
      } catch (e) {
        result.failedCount++;
        result.errors.add('Sync ${info.table}: ${_short(e)}');
      }

      onProgress?.call(
        current / total,
        'Synchronisation ${info.geometryLabel} · ${info.endpoint}',
        current,
        total,
      );
    }

    return result;
  }

  List<_TableInfo> _collectSrmTables() {
    final tables = <_TableInfo>[];

    for (final metier in SrmConfig.getMetiers()) {
      final entities = [
        ...SrmConfig.getPointEntities(metier),
        ...SrmConfig.getLineEntities(metier),
        ...SrmConfig.getPolygonEntities(metier),
      ];

      for (final entity in entities) {
        final table = SrmConfig.getTableName(metier, entity);
        final schema = SrmConfig.getSchema(metier, entity);
        if (table == null || table.isEmpty || schema == null) {
          continue;
        }

        final endpoint = _resolveEndpoint(schema, table);
        if (endpoint == null) {
          continue;
        }

        tables.add(
          _TableInfo(
            metier: metier,
            entity: entity,
            schema: schema,
            table: table,
            endpoint: endpoint,
            geometryLabel: _geometryLabel(metier, entity),
          ),
        );
      }
    }

    return tables;
  }

  Map<String, dynamic>? _normalizeRemoteItem(dynamic item) {
    if (item is! Map) return null;

    final raw = Map<String, dynamic>.from(item);
    if (raw['properties'] is Map) {
      return Map<String, dynamic>.from(raw['properties'] as Map);
    }
    return raw;
  }

  String? _resolveEndpoint(String schema, String table) {
    const endpointMap = <String, String>{
      'ep/vanne': 'ep/vannes',
      'ep/vanne_de_vidange': 'ep/vannes-vidange',
      'ep/ventouse': 'ep/ventouses',
      'ep/hydrant': 'ep/hydrants',
      'ep/borne_fontaine': 'ep/bornes-fontaine',
      'ep/borne_onep': 'ep/bornes-onep',
      'ep/bouche_cles': 'ep/bouches-cles',
      'ep/bouche_darrosage': 'ep/bouches-arrosage',
      'ep/compteur_reseau': 'ep/compteurs-reseau',
      'ep/compteur_abonne': 'ep/compteurs-abonne',
      'ep/cone_de_reduction': 'ep/cones-reduction',
      'ep/centre_tampon': 'ep/centres-tampon',
      'ep/noeud': 'ep/noeuds',
      'ep/obturateur': 'ep/obturateurs',
      'ep/reducteur_de_pression': 'ep/reducteurs-pression',
      'ep/forage': 'ep/forages',
      'ep/puit': 'ep/puits',
      'ep/pompe': 'ep/pompes',
      'ep/reservoir': 'ep/reservoirs',
      'ep/station_de_pompage': 'ep/stations-pompage',
      'ep/regard_ep': 'ep/regards',
      'ep/autre_objet': 'ep/autres-objets',
      'ep/ep_conduite_terrain': 'ep/conduites-terrain',
      'ep/branchement': 'ep/branchements',
      'ep/traverse': 'ep/traverses',
      'ep/planche': 'ep/planches',
      'ass/asst_regard': 'ass/regards',
      'ass/asst_regard_branchement': 'ass/regards-branchement',
      'ass/asst_canalisation': 'ass/canalisations',
      'ass/asst_canalisation_reutilisation': 'ass/canalisations-reutilisation',
      'ass/asst_branchement': 'ass/branchements',
      'ass/asst_bassin': 'ass/bassins',
      'ass/asst_ouvrage': 'ass/ouvrages',
      'ass/asst_equipement': 'ass/equipements',
      'ass/asst_station': 'ass/stations',
      'elec/support': 'elec/supports',
      'elec/poste': 'elec/postes',
      'elec/coffret_bt': 'elec/coffrets-bt',
      'elec/noeud_raccord': 'elec/noeuds-raccord',
      'elec/point_desserte': 'elec/points-desserte',
      'elec/troncon_bt': 'elec/troncons-bt',
      'elec/troncon_hta': 'elec/troncons-hta',
    };

    return endpointMap['$schema/$table'];
  }

  String _short(Object e) {
    final value = e.toString();
    return value.length > 180 ? value.substring(0, 180) : value;
  }

  String _geometryLabel(String metier, String entity) {
    if (SrmConfig.isPolygonEntity(metier, entity)) {
      return 'Polygones';
    }
    if (SrmConfig.isLineEntity(metier, entity)) {
      return 'Lignes';
    }
    return 'Points';
  }

  bool _isDownloadedRow(Map<String, dynamic> row) {
    final value = row['downloaded'];
    if (value is int) return value == 1;
    return value?.toString() == '1';
  }

  void _normalizeSyncPayload(Map<String, dynamic> payload) {
    final rawMode = payload['mode_localisation']?.toString().trim();
    if (rawMode == null || rawMode.isEmpty) {
      payload['mode_localisation'] = 'gnss';
      return;
    }

    switch (rawMode.toLowerCase()) {
      case 'gps':
      case 'gps mock':
      case 'gps_mock':
      case 'mock':
      case 'gnss':
        payload['mode_localisation'] = 'gnss';
        return;
      case 'dessin':
        payload['mode_localisation'] = 'dessin';
        return;
      case 'georadar':
      case 'geo-radar':
        payload['mode_localisation'] = 'georadar';
        return;
      default:
        payload['mode_localisation'] = rawMode.toLowerCase();
    }
  }
}
