import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../core/config/srm_config.dart';
import '../data/local/database_helper.dart';
import '../data/remote/api_service.dart';
import 'formulaire_config_mobile_service.dart';
import 'offline_basemap_service.dart';
import 'photo_reference_service.dart';
import 'projection_service.dart';
import 'reference_overlay_sync_service.dart';

class SyncResult {
  int successCount = 0;
  int entitySuccessCount = 0;
  int photoSuccessCount = 0;
  int failedCount = 0;
  int skippedCount = 0;
  bool interrupted = false;
  String? interruptionMessage;
  final List<String> errors = [];
  final List<String> warnings = [];

  int get warningCount => warnings.length;
  int get displaySuccessCount => entitySuccessCount;

  void stopForInterruption(String message) {
    interrupted = true;
    interruptionMessage = message;
    if (!errors.contains(message)) {
      errors.add(message);
    }
  }

  @override
  String toString() =>
      'Synchronisation: $displaySuccessCount succès, $failedCount échecs, '
      '$skippedCount ignorés, $warningCount avertissements';
}

class DownloadInterruptedException implements Exception {
  final String message;

  const DownloadInterruptedException(this.message);

  @override
  String toString() => message;
}

class _TableInfo {
  final String metier;
  final String entity;
  final String schema;
  final String table;
  final String endpoint;
  final String geometryLabel;
  final bool isReference;

  const _TableInfo({
    required this.metier,
    required this.entity,
    required this.schema,
    required this.table,
    required this.endpoint,
    required this.geometryLabel,
    this.isReference = false,
  });
}

class SyncService {
  final DatabaseHelper dbHelper = DatabaseHelper();
  final Map<String, int> _serverIdsByLocalObjectKey = {};
  static const String _downloadInterruptedMessage =
      'Connexion interrompue. Vérifiez Internet puis relancez pour reprendre.';

  Future<SyncResult> downloadAllData({
    Function(double, String, int, int)? onProgress,
  }) async {
    final tables = await _collectSrmTables();
    final result = SyncResult();
    final total = tables.length + 2;
    final nowIso = DateTime.now().toIso8601String();
    final downloadStartedAt = DateTime.now().toUtc();
    final updatedAfter = await dbHelper.getLastDownloadTime();

    final canContinueAfterBasemap = await _ensureBasemapCoverageForDownload(
      result: result,
      onProgress: onProgress,
      total: total,
    );
    if (!canContinueAfterBasemap || result.interrupted) {
      return result;
    }

    await _ensureReferenceOverlaysForDownload(result: result);

    for (int index = 0; index < tables.length; index++) {
      final info = tables[index];
      final current = index + 2;
      final tableStartedAt = DateTime.now().toUtc();
      final tableStatus = await dbHelper.getDownloadTableStatus(info.table);
      final statusText =
          tableStatus?['status']?.toString().trim().toLowerCase() ?? '';
      final canResumeTable =
          statusText == 'downloading' || statusText == 'failed';
      final statusUpdatedAfterRaw =
          tableStatus?['updated_after']?.toString().trim() ?? '';
      final statusUpdatedAfter = statusUpdatedAfterRaw.isEmpty
          ? null
          : DateTime.tryParse(statusUpdatedAfterRaw);
      final lastTableDownload =
          await dbHelper.getLastDownloadTimeForTable(info.table);
      final tableUpdatedAfter = (canResumeTable ? statusUpdatedAfter : null) ??
          lastTableDownload ??
          updatedAfter;
      final updatedAfterIso =
          tableUpdatedAfter?.toUtc().toIso8601String() ?? '';
      var nextPage =
          canResumeTable ? (_asIntOrNull(tableStatus?['next_page']) ?? 1) : 1;
      if (nextPage < 1) {
        nextPage = 1;
      }
      var downloadedForTable = canResumeTable
          ? (_asIntOrNull(tableStatus?['downloaded_count']) ?? 0)
          : 0;
      if (canResumeTable && nextPage > 1) {
        result.warnings.add(
          'Reprise ${info.table}: page $nextPage.',
        );
      }

      onProgress?.call(
        (current - 1) / total,
        'Téléchargement ${info.geometryLabel} - ${info.endpoint}',
        current - 1,
        total,
      );

      try {
        while (true) {
          await dbHelper.saveDownloadTableStatus(
            info.table,
            status: 'downloading',
            downloadedCount: downloadedForTable,
            nextPage: nextPage,
            updatedAfter: updatedAfterIso,
          );

          onProgress?.call(
            (current - 1) / total,
            'Téléchargement ${info.geometryLabel} - page $nextPage',
            current - 1,
            total,
          );

          final pageResult = await ApiService.fetchDataPage(
            info.endpoint,
            updatedAfter: tableUpdatedAfter,
            page: nextPage,
          );

          for (final item in pageResult.items) {
            final map = _normalizeRemoteItem(item);
            if (map == null) {
              result.skippedCount++;
              continue;
            }

            if (info.isReference && info.table == 'onep_db') {
              await dbHelper.upsertDownloadedOnepDb(map);
              downloadedForTable++;
              result.successCount++;
              result.entitySuccessCount++;
              continue;
            }

            final uuid = map['uuid']?.toString();
            if (uuid == null || uuid.isEmpty) {
              result.skippedCount++;
              continue;
            }

            map.remove('id');
            map.remove('id_projet');
            map.remove('id_mission');
            map['downloaded'] = 1;
            map['synced'] = 1;
            map['date_sync'] = nowIso;

            await dbHelper.upsertDownloadedEntitySrm(
              info.table,
              map,
              recordHistory: false,
            );
            downloadedForTable++;
            result.successCount++;
            result.entitySuccessCount++;
          }

          final followingPage = pageResult.nextPage;
          if (followingPage == null || followingPage <= 0) {
            break;
          }
          nextPage = followingPage;
          await dbHelper.saveDownloadTableStatus(
            info.table,
            status: 'downloading',
            downloadedCount: downloadedForTable,
            nextPage: nextPage,
            totalCount: pageResult.count,
            updatedAfter: updatedAfterIso,
          );
        }

        await dbHelper.saveLastDownloadTimeForTable(
          info.table,
          tableStartedAt,
        );
        await dbHelper.saveDownloadTableStatus(
          info.table,
          status: 'completed',
          downloadedCount: downloadedForTable,
        );
      } catch (e) {
        final message = _short(e);
        await dbHelper.saveDownloadTableStatus(
          info.table,
          status: 'failed',
          downloadedCount: downloadedForTable,
          nextPage: nextPage,
          updatedAfter: updatedAfterIso,
          error: message,
        );
        if (_isNetworkInterruption(e)) {
          result.failedCount++;
          result.stopForInterruption(_downloadInterruptedMessage);
          onProgress?.call(
            (current - 1) / total,
            'Téléchargement arrêté - connexion interrompue',
            current - 1,
            total,
          );
          return result;
        }
        result.failedCount++;
        result.errors.add('Téléchargement ${info.table}: $message');
      }

      onProgress?.call(
        current / total,
        'Téléchargement ${info.geometryLabel} - ${info.endpoint}',
        current,
        total,
      );
    }

    await _downloadTerrainInterventions(
      result: result,
      onProgress: onProgress,
      current: tables.length + 2,
      total: total,
      updatedAfterFallback: updatedAfter,
      nowIso: nowIso,
    );
    if (result.interrupted) {
      return result;
    }

    if (await _shouldDownloadEpRegardMiroir()) {
      await refreshEpRegardMiroirCache(result: result);
    }

    if (result.failedCount == 0 && result.skippedCount == 0) {
      await dbHelper.saveLastDownloadTime(downloadStartedAt);
    }

    return result;
  }

  Future<bool> _ensureBasemapCoverageForDownload({
    required SyncResult result,
    required Function(double, String, int, int)? onProgress,
    required int total,
  }) async {
    onProgress?.call(
      0,
      'Téléchargement des cartes offline',
      0,
      total,
    );

    try {
      final downloadResult =
          await OfflineBasemapService().ensureRegionalBasemapDownloaded();
      if (downloadResult.success) {
        result.warnings.add(
          downloadResult.alreadyUpToDate
              ? 'Carte régionale offline déjà à jour.'
              : 'Carte régionale offline téléchargée.',
        );
      } else {
        final errorText =
            downloadResult.errorMessage ?? downloadResult.userMessage ?? '';
        if (_isNetworkInterruption(errorText)) {
          result.failedCount++;
          result.stopForInterruption(_downloadInterruptedMessage);
          onProgress?.call(
            0,
            'Téléchargement arrêté - connexion interrompue',
            0,
            total,
          );
          return false;
        }
        result.warnings.add(
          'Carte offline non mise à jour : ${errorText.isNotEmpty ? errorText : "erreur inconnue"}',
        );
      }
    } catch (e) {
      if (_isNetworkInterruption(e)) {
        result.failedCount++;
        result.stopForInterruption(_downloadInterruptedMessage);
        onProgress?.call(
          0,
          'Téléchargement arrêté - connexion interrompue',
          0,
          total,
        );
        return false;
      }
      result.warnings.add(
        'Carte offline non mise à jour : ${_short(e)}',
      );
    }

    onProgress?.call(
      1 / total,
      'Carte offline vérifiée',
      1,
      total,
    );
    return true;
  }

  Future<void> _ensureReferenceOverlaysForDownload({
    required SyncResult result,
  }) async {
    try {
      final overlayResult = await ReferenceOverlaySyncService(
        databaseHelper: dbHelper,
      ).refreshOverlays(includeFondPlan: true);
      result.warnings.add(
        'Couches contexte offline: '
        '${overlayResult['planches_count'] ?? 0} planches, '
        '${overlayResult['zones_count'] ?? 0} zones, '
        '${overlayResult['fond_plan_count'] ?? 0} objets fond plan.',
      );
    } catch (e) {
      result.warnings.add(
        'Couches contexte offline non mises à jour : ${_short(e)}',
      );
    }
  }

  Future<void> _downloadTerrainInterventions({
    required SyncResult result,
    required Function(double, String, int, int)? onProgress,
    required int current,
    required int total,
    required DateTime? updatedAfterFallback,
    required String nowIso,
  }) async {
    const tableName = 'intervention_anomalie';
    const scopeMetadataKey = 'intervention_anomalie_download_scope';
    const scopeMetadataValue = 'active_all_v1';
    final startedAt = DateTime.now().toUtc();
    final currentScope = await dbHelper.getAppMetadataValue(scopeMetadataKey);
    final updatedAfter = currentScope == scopeMetadataValue
        ? await dbHelper.getLastDownloadTimeForTable(tableName) ??
            updatedAfterFallback
        : null;

    onProgress?.call(
      (current - 1) / total,
      'Téléchargement anomalie',
      current - 1,
      total,
    );

    try {
      final rows = await ApiService.fetchTerrainInterventions(
        updatedAfter: updatedAfter,
      );
      for (final row in rows) {
        final normalized = Map<String, dynamic>.from(row);
        normalized['downloaded'] = 1;
        normalized['synced'] = 1;
        normalized['date_sync'] = nowIso;
        await dbHelper.upsertDownloadedInterventionAnomalieTerrain(normalized);
        result.successCount++;
        result.entitySuccessCount++;
      }
      await dbHelper.saveLastDownloadTimeForTable(tableName, startedAt);
      await dbHelper.saveAppMetadataValue(scopeMetadataKey, scopeMetadataValue);
      await dbHelper.saveDownloadTableStatus(
        tableName,
        status: 'completed',
        downloadedCount: rows.length,
      );
    } catch (e) {
      final message = _short(e);
      await dbHelper.saveDownloadTableStatus(
        tableName,
        status: 'failed',
        error: message,
      );
      if (_isNetworkInterruption(e)) {
        result.failedCount++;
        result.stopForInterruption(_downloadInterruptedMessage);
        onProgress?.call(
          (current - 1) / total,
          'Téléchargement arrêté - connexion interrompue',
          current - 1,
          total,
        );
        return;
      }
      result.failedCount++;
      result.errors.add('Téléchargement anomalie: $message');
    }

    onProgress?.call(
      current / total,
      'Téléchargement anomalie',
      current,
      total,
    );
  }

  Future<SyncResult> syncAllDataSequential({
    Function(double, String, int, int)? onProgress,
  }) async {
    final tables = (await _collectSrmTables())
        .where((table) => !table.isReference)
        .toList();
    final result = SyncResult();
    final total = tables.isEmpty ? 1 : tables.length;
    final nowIso = DateTime.now().toIso8601String();
    String? syncSessionUuid;

    try {
      onProgress?.call(
        0,
        'Preparation du journal de synchronisation',
        0,
        total,
      );
      syncSessionUuid = await _createSyncManifestForPendingRows(tables);
    } catch (e) {
      result.failedCount++;
      result.errors.add('Journal de synchronisation: ${_short(e)}');
      return result;
    }

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
        syncSessionUuid: syncSessionUuid,
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
          final localPhotos = _extractLocalPhotos(
            payload,
            strictMissing: false,
          );
          final uuid = row['uuid']?.toString().trim();
          if (uuid != null && uuid.isNotEmpty) {
            await _enqueuePhotosForRow(
              info,
              row,
              localPhotos,
            );
          }
          _sanitizePayloadForSync(info, payload);

          final response = await ApiService.postData(
            info.endpoint,
            payload,
            throwOnError: true,
            syncSessionUuid: syncSessionUuid,
            syncClientItemUuid: _clientItemUuid(info, row),
          );
          if (response == null) {
            throw Exception('réponse vide API');
          }
          _assertResponseUuidMatches(
            tableName: info.table,
            expectedUuid: payload['uuid']?.toString(),
            response: response,
          );
          _rememberServerObjectId(info, row, response);

          final localId = _asIntOrNull(row['id']);
          if (localId != null) {
            await dbHelper.updateEntitySrm(
              info.table,
              localId,
              _syncedPatchForResponse(info, response, nowIso),
              recordHistory: false,
            );
            await dbHelper.markLocalHistoryForObjectSynced(
              tableName: info.table,
              row: row,
            );
          } else {
            await _markRowSyncedByUuid(
              tableName: info.table,
              uuid: row['uuid']?.toString(),
              nowIso: nowIso,
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

    await _syncPendingConduiteValidations(
      result,
      syncSessionUuid: syncSessionUuid,
    );
    await _syncPendingTerrainInterventions(
      result,
      syncSessionUuid: syncSessionUuid,
    );
    await _processPendingPhotoQueue(
      result,
      syncSessionUuid: syncSessionUuid,
    );

    return result;
  }

  Future<void> _syncPendingConduiteValidations(
    SyncResult result, {
    String? syncSessionUuid,
  }) async {
    final items = await dbHelper.getPendingConduiteSyncItems(limit: 1000);
    for (final item in items) {
      final localId = _asIntOrNull(item['id']);
      if (localId == null) {
        continue;
      }
      final rawMetier = item['metier']?.toString().trim() ?? '';
      final metier = rawMetier.isEmpty ? 'ep' : rawMetier;
      final syncUuid = item['sync_uuid']?.toString().trim() ?? '';
      final jourText = item['jour']?.toString().trim() ?? '';
      final nodesText = item['nodes_json']?.toString().trim() ?? '';
      final jour = DateTime.tryParse(jourText);
      if (jour == null || nodesText.isEmpty) {
        await dbHelper.markConduiteSyncItemFailed(
          localId,
          'Conduite locale invalide: jour ou noeuds manquants',
        );
        result.failedCount++;
        continue;
      }

      try {
        final decoded = jsonDecode(nodesText);
        if (decoded is! List) {
          throw Exception('Liste des regards invalide');
        }
        final nodes = decoded
            .whereType<Map>()
            .map((node) => Map<String, dynamic>.from(node))
            .toList();
        final realNodeCount = nodes
            .where(
              (node) =>
                  node['separator'] != true && node['type'] != 'separator',
            )
            .length;
        if (realNodeCount < 2) {
          throw Exception('Au moins deux regards sont necessaires');
        }

        await ApiService.validateStatistiqueConduite(
          metier: metier,
          idAgent: _asIntOrNull(item['id_agent']),
          jour: jour,
          nodes: nodes,
          syncUuid: syncUuid,
          syncSessionUuid: syncSessionUuid,
          syncClientItemUuid: syncUuid,
          acceptFrozenConflict: true,
        );
        await dbHelper.markConduiteSyncItemSynced(localId);
        result.successCount++;
        result.entitySuccessCount++;
      } catch (e) {
        final message = 'Conduite $metier $jourText: ${_short(e)}';
        await dbHelper.markConduiteSyncItemFailed(localId, message);
        result.failedCount++;
        result.errors.add(message);
      }
    }
  }

  Future<void> _syncPendingTerrainInterventions(
    SyncResult result, {
    String? syncSessionUuid,
  }) async {
    final rows = await dbHelper.getUnsyncedInterventionAnomalieTerrain(
      limit: 1000,
    );
    for (final row in rows) {
      final localId = _asIntOrNull(row['id']);
      final idIntervention = _asIntOrNull(row['id_intervention']);
      final etatTerrain = row['etat_terrain']?.toString().trim() ?? '';

      if (localId == null || idIntervention == null || etatTerrain.isEmpty) {
        if (localId != null) {
          await dbHelper.markInterventionAnomalieTerrainFailed(
            localId,
            'Intervention terrain locale invalide',
          );
        }
        result.failedCount++;
        continue;
      }

      try {
        final response = await ApiService.updateTerrainIntervention(
          idIntervention: idIntervention,
          etatTerrain: etatTerrain,
          commentaireTerrain: row['commentaire_terrain']?.toString(),
          idUserTerrain:
              _asIntOrNull(row['id_user_terrain']) ?? ApiService.userId,
          syncSessionUuid: syncSessionUuid,
          syncClientItemUuid: _terrainInterventionClientItemUuid(row),
        );
        await dbHelper.markInterventionAnomalieTerrainSynced(
          localId,
          response,
        );
        result.successCount++;
        result.entitySuccessCount++;
      } catch (e) {
        final message = 'Intervention terrain #$idIntervention: ${_short(e)}';
        await dbHelper.markInterventionAnomalieTerrainFailed(localId, message);
        result.failedCount++;
        result.errors.add(message);
      }
    }
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

      await dbHelper.saveRegardMiroirCache(rows);
      debugPrint(
        '[REGARD-MIROIR] cache maj depuis serveur: ${rows.length}/${remoteItems.length}'
        ' (géométrie ignorée: $skippedWithoutGeometry)',
      );
    } catch (e) {
      result?.warnings.add(
        'Miroir Regard non mis à jour: ${_short(e)}',
      );
    }
  }

  Future<bool> _shouldDownloadEpRegardMiroir() async {
    try {
      final rows = await FormulaireConfigMobileService().getFormulaires(
        nomMetier: 'ep',
        nomTable: 'ep_regard',
        downloadOnly: true,
      );
      return rows.any((row) => row.downloadMobile);
    } catch (_) {
      return true;
    }
  }

  Future<bool> _syncRowsForTableV2({
    required _TableInfo info,
    required int current,
    required int total,
    required String nowIso,
    required SyncResult result,
    required Function(double, String, int, int)? onProgress,
    String? syncSessionUuid,
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
      result.errors
          .add('Sync ${info.table}: lecture impossible - ${_short(e)}');
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
        final localPhotos = _extractLocalPhotos(
          payload,
          strictMissing: false,
        );
        final uuid = row['uuid']?.toString().trim();
        if (uuid != null && uuid.isNotEmpty) {
          await _enqueuePhotosForRow(
            info,
            row,
            localPhotos,
          );
        }
        _sanitizePayloadForSync(info, payload);

        final response = await ApiService.postData(
          info.endpoint,
          payload,
          throwOnError: true,
          syncSessionUuid: syncSessionUuid,
          syncClientItemUuid: _clientItemUuid(info, row),
        );
        if (response == null) {
          throw Exception('réponse vide API');
        }
        _assertResponseUuidMatches(
          tableName: info.table,
          expectedUuid: payload['uuid']?.toString(),
          response: response,
        );
        _rememberServerObjectId(info, row, response);

        final localId = _asIntOrNull(row['id']);
        if (localId != null) {
          await dbHelper.updateEntitySrm(
            info.table,
            localId,
            _syncedPatchForResponse(info, response, nowIso),
            recordHistory: false,
          );
          await dbHelper.markLocalHistoryForObjectSynced(
            tableName: info.table,
            row: row,
          );
        } else {
          await _markRowSyncedByUuid(
            tableName: info.table,
            uuid: row['uuid']?.toString(),
            nowIso: nowIso,
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

  Future<String?> _createSyncManifestForPendingRows(
    List<_TableInfo> tables,
  ) async {
    final items = <Map<String, dynamic>>[];
    final attachments = <Map<String, dynamic>>[];
    final attachmentKeys = <String>{};

    for (final info in tables) {
      final rows = await dbHelper.getUnsyncedSrm(info.table);
      for (final row in rows) {
        if (_isDownloadedRow(row)) {
          continue;
        }

        final uuid = row['uuid']?.toString().trim() ?? '';
        if (uuid.isEmpty) {
          continue;
        }

        final payload = Map<String, dynamic>.from(row);
        final localPhotos = _extractLocalPhotos(
          payload,
          strictMissing: false,
        );
        _sanitizePayloadForSync(info, payload);

        items.add({
          'client_item_uuid': _clientItemUuid(info, row),
          'nom_schema': info.schema,
          'nom_table': info.table,
          'uuid_objet': uuid,
          'local_id': _asIntOrNull(row['id']),
          'operation': 'upsert',
          'payload_hash': _hashPayload(payload),
          'payload_summary': {
            'table': info.table,
            'local_id': _asIntOrNull(row['id']),
            'photos_locales': localPhotos.length,
          },
        });

        for (final photo in localPhotos.entries) {
          _addManifestAttachment(
            attachments: attachments,
            attachmentKeys: attachmentKeys,
            schemaName: info.schema,
            tableName: info.table,
            uuidObjet: uuid,
            photoSlot: photo.key,
            localPath: photo.value,
          );
        }
      }
    }

    final pendingConduites = await dbHelper.getPendingConduiteSyncItems(
      limit: 10000,
    );
    for (final item in pendingConduites) {
      final syncUuid = item['sync_uuid']?.toString().trim() ?? '';
      final metier = item['metier']?.toString().trim() ?? 'ep';
      if (syncUuid.isEmpty) continue;
      final statSchema = _conduiteStatSchemaForMetier(metier);
      final statTable = _conduiteStatTableName();

      final payload = {
        'metier': metier,
        'id_agent': item['id_agent'],
        'jour': item['jour'],
        'nodes': item['nodes_json'],
      };
      items.add({
        'client_item_uuid': syncUuid,
        'nom_schema': statSchema,
        'nom_table': statTable,
        'uuid_objet': syncUuid,
        'local_id': _asIntOrNull(item['id']),
        'operation': 'validate',
        'payload_hash': _hashPayload(payload),
        'payload_summary': {
          'schema': statSchema,
          'table': statTable,
          'local_id': _asIntOrNull(item['id']),
          'metier': metier,
          'jour': item['jour'],
        },
      });
    }

    final pendingTerrainInterventions =
        await dbHelper.getUnsyncedInterventionAnomalieTerrain(limit: 10000);
    for (final item in pendingTerrainInterventions) {
      final idIntervention = _asIntOrNull(item['id_intervention']);
      if (idIntervention == null) continue;

      final payload = {
        'etat_terrain': item['etat_terrain'],
        'commentaire_terrain': item['commentaire_terrain'],
        'id_user_terrain': item['id_user_terrain'] ?? ApiService.userId,
      };
      items.add({
        'client_item_uuid': _terrainInterventionClientItemUuid(item),
        'nom_schema': 'public',
        'nom_table': 'intervention_anomalie',
        'uuid_objet': idIntervention.toString(),
        'local_id': _asIntOrNull(item['id']),
        'operation': 'terrain_update',
        'payload_hash': _hashPayload(payload),
        'payload_summary': {
          'table': 'intervention_anomalie',
          'local_id': _asIntOrNull(item['id']),
          'id_intervention': idIntervention,
          'etat_terrain': item['etat_terrain'],
        },
      });
    }

    final pendingPhotos = await dbHelper.getPendingPhotoSyncItems(limit: 10000);
    for (final item in pendingPhotos) {
      final schemaName = item['schema_name']?.toString().trim() ?? '';
      final tableName = item['table_name']?.toString().trim() ?? '';
      final uuidObjet = item['uuid_objet']?.toString().trim() ?? '';
      final localPath = item['local_path']?.toString().trim() ?? '';
      final photoSlot = _asIntOrNull(item['photo_slot']);
      if (photoSlot == null) {
        continue;
      }
      _addManifestAttachment(
        attachments: attachments,
        attachmentKeys: attachmentKeys,
        schemaName: schemaName,
        tableName: tableName,
        uuidObjet: uuidObjet,
        photoSlot: photoSlot,
        localPath: localPath,
      );
    }

    if (items.isEmpty && attachments.isEmpty) {
      return null;
    }

    final syncUuid = const Uuid().v4();
    final response = await ApiService.createSyncManifest(
      syncUuid: syncUuid,
      items: items,
      attachments: attachments,
      metadata: {
        'client': 'flutter',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'items_count': items.length,
        'attachments_count': attachments.length,
      },
    );

    final responseUuid = response['sync_uuid']?.toString().trim() ?? '';
    return responseUuid.isNotEmpty ? responseUuid : syncUuid;
  }

  Future<List<_TableInfo>> _collectSrmTables() async {
    final tables = <_TableInfo>[];

    try {
      final manifest =
          await FormulaireConfigMobileService().getMobileExportManifest();
      for (final row in manifest) {
        if (!_isTruthy(row['download_mobile'])) continue;

        var endpoint = row['endpoint']?.toString().trim() ?? '';
        final table = row['mobile_table']?.toString().trim() ?? '';
        final schema = row['nom_metier']?.toString().trim() ?? '';
        final configTable = row['nom_table']?.toString().trim() ?? '';
        final title = row['titre_app']?.toString().trim() ?? table;
        final isReference = _isTruthy(row['reference']);
        if (schema == 'ep' && configTable == 'ep_regard') {
          // Mirror polygons are refreshed by refreshEpRegardMiroirCache().
          continue;
        }
        if (endpoint.isEmpty) {
          endpoint = isReference && table == 'onep_db'
              ? 'ep/onep-db'
              : (_resolveEndpoint(schema, table) ?? '');
        }
        if (endpoint.isEmpty || table.isEmpty || schema.isEmpty) {
          debugPrint('[DOWNLOAD-MANIFEST] Table ignoree sans endpoint: '
              '$schema.${row['nom_table']}');
          continue;
        }
        final mobileMetier = _mobileMetierForSchema(schema);
        final entity = _entityForMobileTable(mobileMetier, table) ?? title;
        if (!isReference &&
            (mobileMetier.isEmpty ||
                _entityForMobileTable(mobileMetier, table) == null)) {
          debugPrint('[DOWNLOAD-MANIFEST] Table ignoree sans SrmConfig: '
              '$schema.$table');
          continue;
        }
        tables.add(
          _TableInfo(
            metier: mobileMetier.isEmpty ? schema : mobileMetier,
            entity: entity,
            schema: schema,
            table: table,
            endpoint: endpoint,
            geometryLabel: isReference
                ? 'Referentiel'
                : _geometryLabel(mobileMetier, entity),
            isReference: isReference,
          ),
        );
      }
    } catch (e) {
      debugPrint('[DOWNLOAD-MANIFEST] Fallback SrmConfig: $e');
    }

    if (tables.isEmpty) {
      tables.addAll(_collectSrmTablesFallback());
    }

    tables.add(
      const _TableInfo(
        metier: 'public',
        entity: 'objet_incomplet',
        schema: 'public',
        table: 'objet_incomplet',
        endpoint: 'objets-incomplets',
        geometryLabel: 'Objets incomplets',
      ),
    );

    return _dedupeTables(tables);
  }

  List<_TableInfo> _collectSrmTablesFallback() {
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

  List<_TableInfo> _dedupeTables(List<_TableInfo> tables) {
    final seen = <String>{};
    final result = <_TableInfo>[];
    for (final table in tables) {
      final key = '${table.schema}.${table.table}.${table.endpoint}';
      if (seen.add(key)) {
        result.add(table);
      }
    }
    return result;
  }

  String _mobileMetierForSchema(String schema) {
    final normalized = schema.trim().toLowerCase();
    if (normalized == 'ep') return 'Eau Potable';
    if (normalized == 'asst' || normalized == 'ass') return 'Assainissement';
    return '';
  }

  String? _entityForMobileTable(String mobileMetier, String tableName) {
    if (mobileMetier.isEmpty) return null;
    for (final entity in SrmConfig.getEntitiesForMetier(mobileMetier)) {
      if (SrmConfig.getTableName(mobileMetier, entity) == tableName) {
        return entity;
      }
    }
    return null;
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
    if (tableName == 'objet_incomplet') {
      return;
    }

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
      'ep/bouche_a_cles': 'ep/bouches-cles',
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
      'ep/ep_bache': 'ep/baches',
      'ep/station_de_pompage': 'ep/stations-pompage',
      'ep/ep_regard_point': 'ep/regards',
      'ep/regard': 'ep/regards',
      'ep/regard_ep': 'ep/regards',
      'ep/autre_objet': 'ep/autres-objets',
      'ep/anomalie_conduite': 'ep/anomalies-conduite',
      'ep/conduite_terrain': 'ep/conduites-terrain',
      'ep/ep_conduite_terrain': 'ep/conduites-terrain',
      'ep/branchement': 'ep/branchements',
      'ep/traverse': 'ep/traverses',
      'ep/tn': 'ep/tn',
      'ep/voie': 'ep/voies',
      'ass/asst_regard': 'ass/regards',
      'asst/asst_regard': 'ass/regards',
      'asst/ASS_REGARD': 'ass/regards',
      'ass/asst_regard_branchement': 'ass/regards-branchement',
      'asst/asst_regard_branchement': 'ass/regards-branchement',
      'asst/ASS_REGARD_FACADE': 'ass/regards-facade',
      'asst/ASS_BORGNE': 'ass/regards-borgnes',
      'asst/ASS_BOUCHE': 'ass/bouches',
      'asst/ASS_DEVERSOIR': 'ass/deversoirs',
      'asst/ASS__EXUTOIRE': 'ass/exutoires',
      'asst/ASS_STA_POMP': 'ass/stations-pompage',
      'ass/asst_canalisation': 'ass/canalisations',
      'asst/asst_canalisation': 'ass/canalisations',
      'asst/ASS_COLLECTEUR': 'ass/collecteurs',
      'ass/asst_canalisation_reutilisation': 'ass/canalisations-reutilisation',
      'asst/asst_canalisation_reutilisation': 'ass/canalisations-reutilisation',
      'asst/ASS_REFOULEMENTR': 'ass/canalisations-reutilisation',
      'ass/asst_branchement': 'ass/branchements',
      'asst/asst_branchement': 'ass/branchements',
      'asst/ASS_BRANCHEMENT': 'ass/branchements',
      'asst/ASS_CANIVEAU': 'ass/caniveaux',
      'asst/ASS_CANIV_BRANCHE': 'ass/caniveaux-branchement',
      'asst/ASS_COL_BOUCHE': 'ass/collecteurs-bouche',
      'ass/asst_bassin': 'ass/bassins',
      'asst/asst_bassin': 'ass/bassins',
      'asst/ASS_BASSIN_VERSANT': 'ass/bassins-versants',
      'ass/asst_ouvrage': 'ass/ouvrages',
      'asst/asst_ouvrage': 'ass/ouvrages',
      'asst/ASS_OUV_TRAVERSEE': 'ass/ouvrages',
      'ass/asst_equipement': 'ass/equipements',
      'asst/asst_equipement': 'ass/equipements',
      'asst/ASS_POMPE': 'ass/equipements',
      'ass/asst_station': 'ass/stations',
      'asst/asst_station': 'ass/stations',
      'asst/ASS_STA_EPUR': 'ass/stations-epuration',
    };

    return endpointMap['$schema/$table'];
  }

  String _conduiteStatTableName() {
    return 'statistique_conduite';
  }

  String _conduiteStatSchemaForMetier(String metier) {
    final normalized = metier.trim().toLowerCase();
    if (normalized == 'asst' || normalized == 'ass') {
      return 'asst';
    }
    return 'ep';
  }

  String _short(Object e) {
    if (_isNetworkInterruption(e)) {
      return _downloadInterruptedMessage;
    }

    var value = e.toString().trim();
    value = value
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .replaceFirst(RegExp(r'^SocketException:\s*'), '')
        .replaceFirst(RegExp(r'^TimeoutException(?: after .*?)?:\s*'), '')
        .replaceFirst(RegExp(r'^ClientException:\s*'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (value.isEmpty) {
      value = 'Operation impossible.';
    }
    return value.length > 180 ? value.substring(0, 180) : value;
  }

  bool _isNetworkInterruption(Object e) {
    if (e is DownloadInterruptedException) {
      return true;
    }

    final value = e.toString().toLowerCase();
    return value.contains('connexion interrompue') ||
        value.contains('erreur reseau') ||
        value.contains('erreur réseau') ||
        value.contains('timeout') ||
        value.contains('socketexception') ||
        value.contains('clientexception') ||
        value.contains('failed host lookup') ||
        value.contains('connection refused') ||
        value.contains('connection reset') ||
        value.contains('connection closed') ||
        value.contains('network is unreachable') ||
        value.contains('no route to host') ||
        value.contains('software caused connection abort') ||
        value.contains('broken pipe');
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

    if (info.schema == 'public' && info.table == 'objet_incomplet') {
      payload.remove('date_collecte');
      _normalizeObjetIncompletPayloadForSync(payload);
      return;
    }

    if (info.schema == 'ep' && info.table == 'regard') {
      _normalizeRegardPayload(payload);
      return;
    }

    _normalizeSyncPayload(payload);
  }

  void _normalizeObjetIncompletPayloadForSync(Map<String, dynamic> payload) {
    final nomTable = payload['nom_table']?.toString().trim() ?? '';
    final localIdObjet = _asIntOrNull(payload['id_objet']);
    if (nomTable.isEmpty || localIdObjet == null) {
      return;
    }

    final serverId = _mappedServerObjectId(nomTable, localIdObjet);
    if (serverId != null) {
      payload['id_objet'] = serverId;
    }
  }

  int? _mappedServerObjectId(String nomTable, int localId) {
    final direct = _serverIdsByLocalObjectKey['$nomTable:$localId'];
    if (direct != null) return direct;

    if (nomTable.contains('.')) return null;

    int? match;
    final suffix = '.$nomTable:$localId';
    for (final entry in _serverIdsByLocalObjectKey.entries) {
      if (!entry.key.endsWith(suffix)) continue;
      if (match != null && match != entry.value) return null;
      match = entry.value;
    }
    return match;
  }

  void _rememberServerObjectId(
    _TableInfo info,
    Map<String, dynamic> row,
    dynamic response,
  ) {
    if (info.schema == 'public' || info.table == 'objet_incomplet') {
      return;
    }

    final localId = _asIntOrNull(row['id']);
    final serverId = _responseServerObjectId(response);
    if (localId == null || serverId == null) {
      return;
    }

    _serverIdsByLocalObjectKey['${info.schema}.${info.table}:$localId'] =
        serverId;
  }

  int? _responseServerObjectId(dynamic response) {
    if (response is! Map) return null;
    final raw = Map<String, dynamic>.from(response);
    final featureId = _asIntOrNull(raw['id']);
    if (featureId != null) return featureId;

    final properties = raw['properties'];
    if (properties is Map) {
      return _asIntOrNull(properties['id']);
    }

    return null;
  }

  Map<String, dynamic> _syncedPatchForResponse(
    _TableInfo info,
    dynamic response,
    String nowIso,
  ) {
    final patch = <String, dynamic>{
      'synced': 1,
      'date_sync': nowIso,
    };

    final normalizedResponse = _normalizeSyncResponseItem(response);

    if (info.schema == 'public' && info.table == 'objet_incomplet') {
      final idIncomplet = _asIntOrNull(normalizedResponse?['id_incomplet']);
      if (idIncomplet != null) {
        patch['id_incomplet'] = idIncomplet;
      }
      return patch;
    }

    // Aligner les FK locales (id_commune, id_province) sur ce que le serveur
    // a effectivement enregistre. Si la valeur locale ne pointait sur aucune
    // ligne du referentiel serveur (commune_oriental.fid, ...), le backend
    // l'a neutralisee a NULL : il faut refleter ce NULL en local pour que
    // la prochaine edition n'envoie pas a nouveau l'id invalide.
    if (normalizedResponse != null) {
      for (final fkColumn in const ['id_commune', 'id_province']) {
        if (normalizedResponse.containsKey(fkColumn)) {
          patch[fkColumn] = normalizedResponse[fkColumn];
        }
      }
    }

    return patch;
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
      recordHistory: false,
    );
    await dbHelper.markLocalHistoryForObjectSynced(
      tableName: tableName,
      row: {
        'id': localId,
        'uuid': cleanUuid,
      },
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

  Map<int, String> _extractLocalPhotos(
    Map<String, dynamic> payload, {
    bool strictMissing = true,
  }) {
    final photos = <int, String>{};
    for (var slot = 1; slot <= 4; slot++) {
      final raw = payload['photo_$slot']?.toString().trim() ?? '';
      if (raw.isEmpty || !PhotoReferenceService.isLocalReference(raw)) {
        continue;
      }

      final localPath = PhotoReferenceService.toLocalFilePath(raw);
      if (!File(localPath).existsSync()) {
        if (!strictMissing) {
          debugPrint('[PHOTO] Photo locale introuvable ignoree au manifest: '
              'photo_$slot ($localPath)');
          continue;
        }
        throw Exception('Photo locale introuvable: photo_$slot ($localPath)');
      }
      photos[slot] = localPath;
    }
    if (photos.isNotEmpty) {
      debugPrint('[PHOTO] Photos locales détectées: ${photos.keys.join(',')}');
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
      debugPrint('[PHOTO] Enqueue ${info.table} uuid=$uuid slot=${entry.key}');
      await dbHelper.enqueuePhotoSyncItem(
        schemaName: info.schema,
        tableName: info.table,
        uuidObjet: uuid,
        photoSlot: entry.key,
        localPath: entry.value,
        idAgentCrea: _asIntOrNull(row['id_agent_crea']),
      );
    }
  }

  Future<void> _processPendingPhotoQueue(
    SyncResult result, {
    String? syncSessionUuid,
  }) async {
    final items = await dbHelper.getPendingPhotoSyncItems();
    debugPrint('[PHOTO] Queue pending count=${items.length}');
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
        if (!File(localPath).existsSync()) {
          throw Exception('Photo locale introuvable: $localPath');
        }

        debugPrint('[PHOTO] Upload $tableName uuid=$uuidObjet slot=$photoSlot');
        // L'endpoint mobile (ex: 'ep/hydrants') sert au serveur a resoudre
        // la table Postgres reelle (ex: ep_hydrant), car le mobile envoie
        // le tableName local Flutter qui peut differer du db_table reel.
        final endpoint = _resolveEndpoint(schemaName, tableName);
        final response = await ApiService.uploadPhoto(
          schemaName: schemaName,
          tableName: tableName,
          uuidObjet: uuidObjet,
          photoSlot: photoSlot,
          localPath: localPath,
          idAgentCrea: _asIntOrNull(item['id_agent_crea']),
          syncSessionUuid: syncSessionUuid,
          endpoint: endpoint,
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
          recordHistory: false,
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

  int? _asIntOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  String _clientItemUuid(_TableInfo info, Map<String, dynamic> row) {
    final uuid = row['uuid']?.toString().trim() ?? '';
    if (uuid.isNotEmpty) {
      return '${info.schema}.${info.table}:$uuid';
    }
    final localId = row['id']?.toString().trim() ?? 'unknown';
    return '${info.schema}.${info.table}:local:$localId';
  }

  String _terrainInterventionClientItemUuid(Map<String, dynamic> row) {
    final idIntervention = row['id_intervention']?.toString().trim() ?? '';
    if (idIntervention.isNotEmpty) {
      return 'public.intervention_anomalie:$idIntervention';
    }
    final localId = row['id']?.toString().trim() ?? 'unknown';
    return 'public.intervention_anomalie:local:$localId';
  }

  String _hashPayload(Map<String, dynamic> payload) {
    final canonical = jsonEncode(_canonicalizeJson(payload));
    return sha256.convert(utf8.encode(canonical)).toString();
  }

  dynamic _canonicalizeJson(dynamic value) {
    if (value is Map) {
      final entries = value.entries
          .map((entry) => MapEntry(entry.key.toString(), entry.value))
          .toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      return {
        for (final entry in entries) entry.key: _canonicalizeJson(entry.value),
      };
    }
    if (value is Iterable) {
      return value.map(_canonicalizeJson).toList();
    }
    return value;
  }

  void _addManifestAttachment({
    required List<Map<String, dynamic>> attachments,
    required Set<String> attachmentKeys,
    required String schemaName,
    required String tableName,
    required String uuidObjet,
    required int photoSlot,
    required String localPath,
  }) {
    final schema = schemaName.trim();
    final table = tableName.trim();
    final uuid = uuidObjet.trim();
    final path = localPath.trim();
    if (schema.isEmpty || table.isEmpty || uuid.isEmpty || path.isEmpty) {
      return;
    }

    final key = '$schema|$table|$uuid|$photoSlot';
    if (!attachmentKeys.add(key)) {
      return;
    }

    attachments.add({
      'nom_schema': schema,
      'nom_table': table,
      'uuid_objet': uuid,
      'photo_slot': photoSlot,
      'local_path': path,
      'taille_octets': _fileSizeOrNull(path),
    });
  }

  int? _fileSizeOrNull(String path) {
    try {
      final file = File(path);
      if (!file.existsSync()) {
        return null;
      }
      return file.lengthSync();
    } catch (_) {
      return null;
    }
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
      if ((uuid == null || uuid.isEmpty) &&
          localId != null &&
          localId.isNotEmpty)
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
    final hasAnomalie =
        _isTruthy(payload['ep_anomalie']) || _isTruthy(payload['anomalie']);

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
      'altitude_z_moy',
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

    if (info.table == 'bouche_a_cles' || info.table == 'bouche_cles') {
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
