import 'dart:io';
import 'dart:convert';

import '../core/config/srm_config.dart';
import '../data/local/database_helper.dart';
import '../data/remote/api_service.dart';
import 'photo_reference_service.dart';
import 'projection_service.dart';

class SyncResult {
  int successCount = 0;
  int entitySuccessCount = 0;
  int photoSuccessCount = 0;
  int failedCount = 0;
  int skippedCount = 0;
  final List<String> errors = [];
  final List<String> warnings = [];

  int get warningCount => warnings.length;
  int get displaySuccessCount => entitySuccessCount;

  @override
  String toString() =>
      'Synchronisation: $displaySuccessCount succès, $failedCount échecs, '
      '$skippedCount ignorés, $warningCount avertissements';
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
          if (ApiService.currentProjetId != null &&
              (map['id_projet'] == null ||
                  map['id_projet'].toString().trim().isEmpty)) {
            map['id_projet'] = ApiService.currentProjetId;
          }
          map['downloaded'] = 1;
          map['synced'] = 1;
          map['date_sync'] = nowIso;

          await dbHelper.upsertDownloadedEntitySrm(
            info.table,
            map,
            recordHistory: true,
          );
          result.successCount++;
          result.entitySuccessCount++;
        }
      } catch (e) {
        result.failedCount++;
        result.errors.add('Téléchargement ${info.table}: ${_short(e)}');
      }
    }

    await refreshEpRegardMiroirCache(result: result);

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
      if (await _syncRowsForTableV2(
        info: info,
        current: current,
        total: total,
        nowIso: nowIso,
        result: result,
        onProgress: onProgress,
      )) {
        continue;
      }

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
          final localPhotos = _extractLocalPhotos(payload);
          _sanitizePayloadForSync(info, payload);

          final response = await ApiService.postData(
            info.endpoint,
            payload,
            throwOnError: true,
          );
          if (response == null) {
            throw Exception('réponse vide API');
          }
          _assertResponseUuidMatches(
            tableName: info.table,
            expectedUuid: payload['uuid']?.toString(),
            response: response,
          );

          final localId = _asIntOrNull(row['id']);
          if (localId != null) {
            await dbHelper.updateEntitySrm(
              info.table,
              localId,
              {
                'synced': 1,
                'date_sync': nowIso,
              },
              recordHistory: true,
            );
          } else {
            await _markRowSyncedByUuid(
              tableName: info.table,
              uuid: row['uuid']?.toString(),
              nowIso: nowIso,
            );
          }

          final uuid = row['uuid']?.toString().trim();
          if (uuid != null && uuid.isNotEmpty) {
            await _enqueuePhotosForRow(
              info,
              row,
              localPhotos,
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

    await _processPendingPhotoQueue(result);
    await _syncLocalHistoryJournal(result);

    return result;
  }

  Future<void> refreshEpRegardMiroirCache({
    SyncResult? result,
  }) async {
    try {
      final remoteItems = await ApiService.fetchRegardsMiroirEP();
      final rows = <Map<String, dynamic>>[];
      final nowIso = DateTime.now().toIso8601String();
      var skippedWithoutGeometry = 0;

      for (final item in remoteItems) {
        final map = _normalizeRemoteItem(item);
        if (map == null) continue;

        final geometryText = map['geometry_geojson']?.toString().trim();
        final pointsJson = _buildPolygonPointsJsonFromGeometry(geometryText);
        if (pointsJson == null || pointsJson.isEmpty) {
          skippedWithoutGeometry++;
          continue;
        }

        final row = Map<String, dynamic>.from(map);
        row['points_json'] = pointsJson;
        row['downloaded'] = 1;
        row['synced'] = 1;
        row['date_sync'] = nowIso;
        rows.add(row);
      }

      await dbHelper.saveRegardMiroirCache(
        rows,
        projetId: ApiService.currentProjetId,
      );
      print(
        '[REGARD-MIROIR] cache maj depuis serveur: ${rows.length}/${remoteItems.length}'
        ' (géométrie ignorée: $skippedWithoutGeometry)',
      );
    } catch (e) {
      result?.warnings.add(
        'Miroir Regard non mis à jour: ${_short(e)}',
      );
    }
  }

  Future<bool> _syncRowsForTableV2({
    required _TableInfo info,
    required int current,
    required int total,
    required String nowIso,
    required SyncResult result,
    required Function(double, String, int, int)? onProgress,
  }) async {
    onProgress?.call(
      (current - 1) / total,
      'Synchronisation ${info.geometryLabel} · ${info.endpoint}',
      current - 1,
      total,
    );

    List<Map<String, dynamic>> rows;
    try {
      rows = await dbHelper.getUnsyncedSrm(info.table);
    } catch (e) {
      result.failedCount++;
      result.errors.add('Sync ${info.table}: lecture impossible - ${_short(e)}');
      onProgress?.call(
        current / total,
        'Synchronisation ${info.geometryLabel} · ${info.endpoint}',
        current,
        total,
      );
      return true;
    }

    if (rows.isEmpty) {
      result.skippedCount++;
      onProgress?.call(
        current / total,
        'Synchronisation ${info.geometryLabel} · ${info.endpoint}',
        current,
        total,
      );
      return true;
    }

    for (final row in rows) {
      if (_isDownloadedRow(row)) {
        result.skippedCount++;
        continue;
      }

      try {
        final payload = Map<String, dynamic>.from(row);
        final localPhotos = _extractLocalPhotos(payload);
        _sanitizePayloadForSync(info, payload);

        final response = await ApiService.postData(
          info.endpoint,
          payload,
          throwOnError: true,
        );
        if (response == null) {
          throw Exception('réponse vide API');
        }
        _assertResponseUuidMatches(
          tableName: info.table,
          expectedUuid: payload['uuid']?.toString(),
          response: response,
        );

        final localId = _asIntOrNull(row['id']);
        if (localId != null) {
          await dbHelper.updateEntitySrm(
            info.table,
            localId,
            {
              'synced': 1,
              'date_sync': nowIso,
            },
            recordHistory: true,
          );
        } else {
          await _markRowSyncedByUuid(
            tableName: info.table,
            uuid: row['uuid']?.toString(),
            nowIso: nowIso,
          );
        }

        final uuid = row['uuid']?.toString().trim();
        if (uuid != null && uuid.isNotEmpty) {
          await _enqueuePhotosForRow(
            info,
            row,
            localPhotos,
          );
        }

        result.successCount++;
        result.entitySuccessCount++;
      } catch (e) {
        result.failedCount++;
        result.errors.add(_formatRowSyncError(info, row, e));
      }
    }

    onProgress?.call(
      current / total,
      'Synchronisation ${info.geometryLabel} · ${info.endpoint}',
      current,
      total,
    );
    return true;
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
      final properties = Map<String, dynamic>.from(raw['properties'] as Map);
      properties['fid'] ??= raw['id'];
      final geometry = raw['geometry'];
      if (geometry != null) {
        properties['geometry_geojson'] = jsonEncode(geometry);
      }
      return properties;
    }
    return raw;
  }

  Map<String, dynamic>? _normalizeSyncResponseItem(dynamic item) {
    if (item is! Map) return null;

    final raw = Map<String, dynamic>.from(item);
    if (raw['properties'] is Map) {
      return Map<String, dynamic>.from(raw['properties'] as Map);
    }
    return raw;
  }

  void _assertResponseUuidMatches({
    required String tableName,
    required String? expectedUuid,
    required dynamic response,
  }) {
    final cleanExpected = expectedUuid?.trim() ?? '';
    if (cleanExpected.isEmpty) {
      throw Exception('uuid local manquant pour $tableName');
    }

    final normalizedResponse = _normalizeSyncResponseItem(response);
    if (normalizedResponse == null) {
      throw Exception('réponse API invalide pour $tableName');
    }

    final responseUuid = normalizedResponse['uuid']?.toString().trim() ?? '';
    if (responseUuid.isEmpty) {
      throw Exception(
        'uuid absent dans la réponse serveur pour $tableName',
      );
    }

    if (responseUuid != cleanExpected) {
      throw Exception(
        'uuid incohérent pour $tableName (local=$cleanExpected, serveur=$responseUuid)',
      );
    }
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
      'ep/regard': 'ep/regards',
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

  void _sanitizePayloadForSync(
    _TableInfo info,
    Map<String, dynamic> payload,
  ) {
    payload.remove('id');
    payload.remove('downloaded');
    payload.remove('synced');
    payload.remove('date_sync');
    payload.remove('photo_1');
    payload.remove('photo_2');
    payload.remove('photo_3');
    payload.remove('photo_4');
    _removeKnownObsoleteKeys(info, payload);

    if (info.schema == 'ep' && info.table == 'regard') {
      _normalizeRegardPayload(payload);
      return;
    }

    _normalizeSyncPayload(payload);
  }

  Future<void> _markRowSyncedByUuid({
    required String tableName,
    required String? uuid,
    required String nowIso,
  }) async {
    final cleanUuid = uuid?.trim();
    if (cleanUuid == null || cleanUuid.isEmpty) {
      return;
    }

    final db = await dbHelper.database;
    final rows = await db.query(
      tableName,
      columns: ['id'],
      where: 'uuid = ?',
      whereArgs: [cleanUuid],
      limit: 1,
    );

    final localId = rows.isEmpty ? null : rows.first['id'];
    if (localId is! int) {
      return;
    }

    await dbHelper.updateEntitySrm(
      tableName,
      localId,
      {
        'synced': 1,
        'date_sync': nowIso,
      },
      recordHistory: true,
    );
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

  Map<int, String> _extractLocalPhotos(Map<String, dynamic> payload) {
    final photos = <int, String>{};
    for (var slot = 1; slot <= 4; slot++) {
      final raw = payload['photo_$slot']?.toString().trim() ?? '';
      if (raw.isEmpty || !PhotoReferenceService.isLocalReference(raw)) {
        continue;
      }

      final localPath = PhotoReferenceService.toLocalFilePath(raw);
      if (!File(localPath).existsSync()) {
        continue;
      }
      photos[slot] = localPath;
    }
    if (photos.isNotEmpty) {
      print('[PHOTO] Photos locales détectées: ${photos.keys.join(',')}');
    }
    return photos;
  }

  Future<void> _enqueuePhotosForRow(
    _TableInfo info,
    Map<String, dynamic> row,
    Map<int, String> localPhotos,
  ) async {
    final uuid = row['uuid']?.toString().trim();
    if (uuid == null || uuid.isEmpty || localPhotos.isEmpty) {
      return;
    }

    for (final entry in localPhotos.entries) {
      print('[PHOTO] Enqueue ${info.table} uuid=$uuid slot=${entry.key}');
      await dbHelper.enqueuePhotoSyncItem(
        schemaName: info.schema,
        tableName: info.table,
        uuidObjet: uuid,
        photoSlot: entry.key,
        localPath: entry.value,
        idProjet: _asIntOrNull(row['id_projet']),
        idMission: _asIntOrNull(row['id_mission']),
        idAgentCrea: _asIntOrNull(row['id_agent_crea']),
      );
    }
  }

  Future<void> _processPendingPhotoQueue(SyncResult result) async {
    final items = await dbHelper.getPendingPhotoSyncItems();
    print('[PHOTO] Queue pending count=${items.length}');
    for (final item in items) {
      final id = _asIntOrNull(item['id']);
      final schemaName = item['schema_name']?.toString().trim() ?? '';
      final tableName = item['table_name']?.toString().trim() ?? '';
      final uuidObjet = item['uuid_objet']?.toString().trim() ?? '';
      final localPath = item['local_path']?.toString().trim() ?? '';
      final photoSlot = _asIntOrNull(item['photo_slot']);

      if (id == null ||
          schemaName.isEmpty ||
          tableName.isEmpty ||
          uuidObjet.isEmpty ||
          localPath.isEmpty ||
          photoSlot == null) {
        continue;
      }

      try {
        print('[PHOTO] Upload $tableName uuid=$uuidObjet slot=$photoSlot');
        final response = await ApiService.uploadPhoto(
          schemaName: schemaName,
          tableName: tableName,
          uuidObjet: uuidObjet,
          photoSlot: photoSlot,
          localPath: localPath,
          idProjet: _asIntOrNull(item['id_projet']),
          idMission: _asIntOrNull(item['id_mission']),
          idAgentCrea: _asIntOrNull(item['id_agent_crea']),
        );

        final remotePath = response['relative_path']?.toString().trim() ?? '';
        final datePriseReelle =
            response['date_prise_reelle']?.toString().trim();
        if (remotePath.isEmpty) {
          throw Exception('chemin photo distant vide');
        }

        await dbHelper.markPhotoSyncItemSynced(
          id,
          remotePath: remotePath,
          datePriseReelle: (datePriseReelle == null || datePriseReelle.isEmpty)
              ? null
              : datePriseReelle,
        );
        await dbHelper.updatePhotoReferenceByUuid(
          tableName,
          uuidObjet,
          photoSlot,
          remotePath,
          recordHistory: true,
        );
        result.successCount++;
        result.photoSuccessCount++;
      } catch (e) {
        await dbHelper.markPhotoSyncItemFailed(id, _short(e));
        result.failedCount++;
        result.errors.add(
          'Photo $tableName#$uuidObjet:$photoSlot: ${_short(e)}',
        );
      }
    }
  }

  Future<void> _syncLocalHistoryJournal(SyncResult result) async {
    await _syncLocalAttributeHistory(result);
    await _syncLocalEventHistory(result);
  }

  Future<void> _syncLocalAttributeHistory(SyncResult result) async {
    final rows = await dbHelper.getPendingLocalAttributeHistory(limit: 500);
    if (rows.isEmpty) {
      return;
    }

    await _syncLocalHistoryChunks(
      rows: rows,
      syncLabel: 'historique attributaire local',
      buildPayload: (row) => _buildAttributeHistoryPayload(row),
      sendBatch: (chunk) => ApiService.uploadLocalHistory(
        attributes: chunk,
        events: const [],
      ),
      markSynced: dbHelper.markLocalAttributeHistorySynced,
      markFailed: dbHelper.markLocalAttributeHistoryFailed,
      result: result,
    );
  }

  Future<void> _syncLocalEventHistory(SyncResult result) async {
    final rows = await dbHelper.getPendingLocalEventHistory(limit: 500);
    if (rows.isEmpty) {
      return;
    }

    await _syncLocalHistoryChunks(
      rows: rows,
      syncLabel: 'historique événementiel local',
      buildPayload: (row) => _buildEventHistoryPayload(row),
      sendBatch: (chunk) => ApiService.uploadLocalHistory(
        attributes: const [],
        events: chunk,
      ),
      markSynced: dbHelper.markLocalEventHistorySynced,
      markFailed: dbHelper.markLocalEventHistoryFailed,
      result: result,
    );
  }

  Future<void> _syncLocalHistoryChunks({
    required List<Map<String, dynamic>> rows,
    required String syncLabel,
    required Map<String, dynamic> Function(Map<String, dynamic>) buildPayload,
    required Future<Map<String, dynamic>> Function(List<Map<String, dynamic>>) sendBatch,
    required Future<void> Function(List<String>) markSynced,
    required Future<void> Function(List<String>, String) markFailed,
    required SyncResult result,
  }) async {
    const batchSize = 100;
    for (var start = 0; start < rows.length; start += batchSize) {
      final end = (start + batchSize > rows.length) ? rows.length : start + batchSize;
      final chunkRows = rows.sublist(start, end);
      final payloadChunk = chunkRows.map(buildPayload).toList();
      final syncUuids = payloadChunk
          .map((item) => item['sync_uuid']?.toString().trim() ?? '')
          .where((value) => value.isNotEmpty)
          .toList();

      try {
        await sendBatch(payloadChunk);
        await markSynced(syncUuids);
      } catch (e) {
        if (chunkRows.length == 1) {
          final warning = '$syncLabel: ${_short(e)}';
          await markFailed(syncUuids, warning);
          result.warnings.add(warning);
          continue;
        }

        for (final row in chunkRows) {
          final payload = buildPayload(row);
          final rowSyncUuid = payload['sync_uuid']?.toString().trim() ?? '';
          try {
            await sendBatch([payload]);
            if (rowSyncUuid.isNotEmpty) {
              await markSynced([rowSyncUuid]);
            }
          } catch (rowError) {
            final warning = '$syncLabel: ${_describeLocalHistoryRow(row)} - ${_short(rowError)}';
            if (rowSyncUuid.isNotEmpty) {
              await markFailed([rowSyncUuid], warning);
            }
            result.warnings.add(warning);
          }
        }
      }
    }
  }

  Map<String, dynamic> _buildAttributeHistoryPayload(Map<String, dynamic> row) {
    return {
      'sync_uuid': row['sync_uuid'],
      'id_historique_local': _asIntOrNull(row['id_historique_local']),
      'id_objet': _asIntOrNull(row['id_objet']),
      'cle_ligne': row['cle_ligne']?.toString(),
      'uuid_objet': row['uuid_objet']?.toString(),
      'nom_schema': row['nom_schema']?.toString(),
      'nom_table': row['nom_table']?.toString(),
      'nom_classe': row['nom_classe']?.toString(),
      'nom_attribut': row['nom_attribut']?.toString(),
      'ancienne_valeur': row['ancienne_valeur']?.toString(),
      'nouvelle_valeur': row['nouvelle_valeur']?.toString(),
      'date_action': row['date_action']?.toString(),
      'id_agent': _asIntOrNull(row['id_agent']),
      'type_action': row['type_action']?.toString(),
    };
  }

  Map<String, dynamic> _buildEventHistoryPayload(Map<String, dynamic> row) {
    dynamic payloadJson;
    final rawPayload = row['payload_json'];
    if (rawPayload is String && rawPayload.trim().isNotEmpty) {
      try {
        payloadJson = jsonDecode(rawPayload);
      } catch (_) {
        payloadJson = {'raw_payload': rawPayload};
      }
    }

    return {
      'sync_uuid': row['sync_uuid'],
      'id_evenement_local': _asIntOrNull(row['id_evenement_local']),
      'type_evenement': row['type_evenement']?.toString(),
      'nom_schema': row['nom_schema']?.toString(),
      'nom_table': row['nom_table']?.toString(),
      'cle_ligne': row['cle_ligne']?.toString(),
      'uuid_objet': row['uuid_objet']?.toString(),
      'id_objet': _asIntOrNull(row['id_objet']),
      'id_agent': _asIntOrNull(row['id_agent']),
      'payload_json': payloadJson,
      'date_action': row['date_action']?.toString(),
    };
  }

  String _describeLocalHistoryRow(Map<String, dynamic> row) {
    final typeEvenement = row['type_evenement']?.toString().trim();
    if (typeEvenement != null && typeEvenement.isNotEmpty) {
      return typeEvenement;
    }

    final table = row['nom_table']?.toString().trim();
    final attribute = row['nom_attribut']?.toString().trim();
    final uuid = row['uuid_objet']?.toString().trim();
    final localId = row['id_objet']?.toString().trim();

    final parts = <String>[
      if (table != null && table.isNotEmpty) table,
      if (attribute != null && attribute.isNotEmpty) attribute,
      if (uuid != null && uuid.isNotEmpty) 'uuid=$uuid',
      if ((uuid == null || uuid.isEmpty) && localId != null && localId.isNotEmpty)
        'id=$localId',
    ];
    return parts.isEmpty ? 'entrée locale' : parts.join(' | ');
  }

  int? _asIntOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  String _formatRowSyncError(
    _TableInfo info,
    Map<String, dynamic> row,
    Object error,
  ) {
    final uuid = row['uuid']?.toString().trim();
    final localId = row['id']?.toString().trim();
    final label = row['display_title']?.toString().trim();

    final parts = <String>[
      info.table,
      if (label != null && label.isNotEmpty) '"$label"',
      if (uuid != null && uuid.isNotEmpty) 'uuid=$uuid',
      if ((uuid == null || uuid.isEmpty) && localId != null && localId.isNotEmpty)
        'id=$localId',
    ];

    return 'Sync ${parts.join(' · ')}: ${_short(error)}';
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

  String? _buildPolygonPointsJsonFromGeometry(String? geometryText) {
    if (geometryText == null || geometryText.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(geometryText);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final type = decoded['type']?.toString();
      final coordinates = decoded['coordinates'];
      List<dynamic>? ring;

      if (type == 'Polygon' && coordinates is List && coordinates.isNotEmpty) {
        final first = coordinates.first;
        if (first is List) {
          ring = first;
        }
      } else if (type == 'MultiPolygon' &&
          coordinates is List &&
          coordinates.isNotEmpty) {
        final firstPolygon = coordinates.first;
        if (firstPolygon is List && firstPolygon.isNotEmpty) {
          final firstRing = firstPolygon.first;
          if (firstRing is List) {
            ring = firstRing;
          }
        }
      }

      if (ring == null || ring.isEmpty) {
        return null;
      }

      final points = <List<double>>[];
      for (final vertex in ring) {
        if (vertex is List && vertex.length >= 2) {
          final lng = vertex[0];
          final lat = vertex[1];
          if (lng is num && lat is num) {
            points.add(_toWgs84GeometryPoint(lng.toDouble(), lat.toDouble()));
          }
        }
      }

      if (points.length < 4) {
        return null;
      }

      return jsonEncode(points);
    } catch (_) {
      return null;
    }
  }

  List<double> _toWgs84GeometryPoint(double x, double y) {
    if (x.abs() <= 180 && y.abs() <= 90) {
      return <double>[x, y];
    }

    final projected = ProjectionService().merchichToWgs84(x: x, y: y);
    return <double>[projected.longitude, projected.latitude];
  }

  void _normalizeRegardPayload(Map<String, dynamic> payload) {
    final hasAnomalie = _isTruthy(payload['ep_anomalie']) ||
        _isTruthy(payload['anomalie']);

    payload['ep_anomalie'] = hasAnomalie ? 1 : 0;

    final anomalyLabel = payload['anomalie_regard']?.toString().trim();
    final fallbackAnomalyLabel = payload['type_anomalie']?.toString().trim();
    if ((anomalyLabel == null || anomalyLabel.isEmpty) &&
        fallbackAnomalyLabel != null &&
        fallbackAnomalyLabel.isNotEmpty) {
      payload['anomalie_regard'] = fallbackAnomalyLabel;
    }

    if (!hasAnomalie) {
      payload['anomalie_regard'] = null;
      payload['anomalie_tamp'] = null;
    }

    final rawMode = payload['mode_localisation']?.toString().trim();
    if (rawMode == null || rawMode.isEmpty) {
      payload['mode_localisation'] = 'Levé topographique';
    } else {
      switch (rawMode.toLowerCase()) {
        case 'gps':
        case 'gps mock':
        case 'gps_mock':
        case 'mock':
        case 'gnss':
        case 'levé topographique':
        case 'leve topographique':
          payload['mode_localisation'] = 'Levé topographique';
          break;
        case 'dessin':
          payload['mode_localisation'] = 'Dessin';
          break;
        case 'georadar':
        case 'geo-radar':
        case 'géo-radar':
          payload['mode_localisation'] = 'Géo-radar';
          break;
        default:
          payload['mode_localisation'] = rawMode;
      }
    }

    payload['id_user_creat'] ??= payload['id_agent_crea'];

    const localOnlyKeys = <String>{
      'anomalie',
      'type_anomalie',
      'objet_incomplet',
      'latitude_gps',
      'longitude_gps',
      'altitude_gps',
      'id_projet',
      'id_agent_crea',
      'id_mission',
      'id_planche',
      'x_debut',
      'y_debut',
      'x_fin',
      'y_fin',
      'lat_debut',
      'lon_debut',
      'lat_fin',
      'lon_fin',
      'nb_points',
      'distance_m',
      'points_json',
      'date_collecte',
    };
    payload.removeWhere((key, _) => localOnlyKeys.contains(key));
  }

  bool _isTruthy(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value?.toString().trim().toLowerCase();
    return normalized == '1' ||
        normalized == 'true' ||
        normalized == 'oui' ||
        normalized == 'yes';
  }

  void _removeKnownObsoleteKeys(_TableInfo info, Map<String, dynamic> payload) {
    if (info.table == 'ventouse') {
      payload.remove('ep_etat');
      return;
    }

    if (info.table == 'hydrant') {
      const obsoleteKeys = <String>{
        'ep_modele',
        'ep_marque',
        'ep_pression',
        'etage_aqua',
        'secteur_aqua',
        'id_regard',
        'id_conduite',
      };
      payload.removeWhere((key, _) => obsoleteKeys.contains(key));
      return;
    }

    if (info.table == 'borne_fontaine') {
      const obsoleteKeys = <String>{
        'ep_marque',
        'etage_aqua',
        'secteur_aqua',
      };
      payload.removeWhere((key, _) => obsoleteKeys.contains(key));
      return;
    }

    if (info.table == 'bouche_cles') {
      const obsoleteKeys = <String>{
        'ep_num',
        'ep_type',
        'ep_etat',
        'emplacement',
        'ref_rue',
        'ep_statut',
        'ep_coor_x',
        'ep_coor_y',
        'etage_aqua',
        'secteur_aqua',
        'photo_1',
        'photo_2',
        'photo_3',
        'photo_4',
      };
      payload.removeWhere((key, _) => obsoleteKeys.contains(key));
      return;
    }

    if (info.table == 'compteur_reseau') {
      const obsoleteKeys = <String>{
        'ep_etat',
        'emplacement',
      };
      payload.removeWhere((key, _) => obsoleteKeys.contains(key));
      return;
    }

    if (info.table == 'compteur_abonne') {
      const obsoleteKeys = <String>{
        'ep_num',
        'ep_type',
        'ep_calibre',
        'ep_marque',
        'ep_etat',
        'etage_aqua',
        'secteur_aqua',
        'ep_statut',
      };
      payload.removeWhere((key, _) => obsoleteKeys.contains(key));
      return;
    }

    if (info.table == 'cone_de_reduction') {
      const obsoleteKeys = <String>{
        'ep_etat',
        'emplacement',
        'id_conduite',
      };
      payload.removeWhere((key, _) => obsoleteKeys.contains(key));
      return;
    }

    if (info.table == 'regard_ep') {
      const obsoleteKeys = <String>{
        'ep_type',
        'ep_forme',
        'ep_longueur',
        'ep_largeur',
        'ep_cote_tampon',
        'ep_cote_radier',
        'ep_cote_fil_eau',
        'ep_etat',
        'etage_aqua',
        'secteur_aqua',
        'points_json',
        'nb_points',
      };
      payload.removeWhere((key, _) => obsoleteKeys.contains(key));
    }
  }
}
