// lib/data/local/line_storage_helper.dart
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/line_model.dart';
import 'database_helper.dart';

class LineStorageHelper {
  static const _storageDatabaseName = 'line_storage.db';
  static const _databaseVersion = 2;
  static const _linesTable = 'lines';
  static const _displayedLinesTable = 'displayed_lines';
  static const _lineCodeColumn = 'line_code';
  static const _originNameColumn = 'origin_name';
  static const _destinationNameColumn = 'destination_name';

  static final LineStorageHelper _instance = LineStorageHelper._internal();
  factory LineStorageHelper() => _instance;
  static Database? _database;

  LineStorageHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), _storageDatabaseName);
    debugPrint('[LINE-STORAGE] Base SQLite lignes: $path');

    return openDatabase(
      path,
      version: _databaseVersion,
      onCreate: (db, version) async {
        debugPrint('[LINE-STORAGE] Creation des tables lignes...');
        await _createLinesTable(db);
        await _createDisplayedLinesTable(db);
        await _createIndexes(db);

        debugPrint('[LINE-STORAGE] Tables créées avec succès');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _migrateToVersion2(db);
        }
      },
    );
  }

  Future<void> _createLinesTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE $_linesTable (
        id INTEGER PRIMARY KEY,
        api_id INTEGER,
        line_code TEXT NOT NULL,
        user_login TEXT,
        start_time TEXT,
        end_time TEXT,
        origin_name TEXT,
        origin_x REAL,
        origin_y REAL,
        destination_name TEXT,
        destination_x REAL,
        destination_y REAL,
        has_intersection INTEGER DEFAULT 0,
        intersection_count INTEGER DEFAULT 0,
        intersections_json TEXT DEFAULT '[]',
        completed_works TEXT,
        work_date TEXT,
        company TEXT,
        platform TEXT,
        relief TEXT,
        vegetation TEXT,
        work_start TEXT,
        work_end TEXT,
        funding TEXT,
        points_json TEXT NOT NULL,
        created_at TEXT,
        updated_at TEXT,
        sync_status TEXT DEFAULT 'pending',
        login_id INTEGER,
        saved_by_user_id INTEGER,
        synced INTEGER DEFAULT 0,
        sync_date TEXT,
        downloaded INTEGER DEFAULT 0,
        service_level REAL,
        functionality REAL,
        socio_administrative_interest REAL,
        served_population REAL,
        agricultural_potential REAL,
        investment_cost REAL,
        environmental_protection REAL,
        global_score REAL,
        region_name TEXT,
        prefecture_name TEXT,
        commune_name TEXT
      )
    ''');
  }

  Future<void> _createDisplayedLinesTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_displayedLinesTable (
        id INTEGER PRIMARY KEY,
        login_id INTEGER NOT NULL,
        line_code TEXT NOT NULL,
        points_json TEXT NOT NULL,
        color INTEGER NOT NULL,
        width REAL NOT NULL,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');
  }

  Future<void> _createIndexes(DatabaseExecutor db) async {
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_lines_api_user
      ON $_linesTable(api_id, saved_by_user_id)
    ''');

    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_displayed_lines_user_code
      ON $_displayedLinesTable(login_id, line_code)
    ''');
  }

  Future<void> _migrateToVersion2(Database db) async {
    debugPrint(
      '[LINE-STORAGE] migration v2: suppression des colonnes commune/occupation/trafic',
    );

    await db.transaction((txn) async {
      const tmpLinesTable = '${_linesTable}_v2_tmp';
      await txn.execute('DROP TABLE IF EXISTS $tmpLinesTable');
      await txn.execute('''
        CREATE TABLE $tmpLinesTable AS
        SELECT
          id,
          api_id,
          line_code,
          user_login,
          start_time,
          end_time,
          origin_name,
          origin_x,
          origin_y,
          destination_name,
          destination_x,
          destination_y,
          has_intersection,
          intersection_count,
          intersections_json,
          completed_works,
          work_date,
          company,
          platform,
          relief,
          vegetation,
          work_start,
          work_end,
          funding,
          points_json,
          created_at,
          updated_at,
          sync_status,
          login_id,
          saved_by_user_id,
          synced,
          sync_date,
          downloaded,
          service_level,
          functionality,
          socio_administrative_interest,
          served_population,
          agricultural_potential,
          investment_cost,
          environmental_protection,
          global_score,
          region_name,
          prefecture_name,
          commune_name
        FROM $_linesTable
      ''');

      await txn.execute('DROP TABLE $_linesTable');
      await _createLinesTable(txn);
      await _createDisplayedLinesTable(txn);
      await _createIndexes(txn);

      await txn.execute('''
        INSERT INTO $_linesTable (
          id,
          api_id,
          line_code,
          user_login,
          start_time,
          end_time,
          origin_name,
          origin_x,
          origin_y,
          destination_name,
          destination_x,
          destination_y,
          has_intersection,
          intersection_count,
          intersections_json,
          completed_works,
          work_date,
          company,
          platform,
          relief,
          vegetation,
          work_start,
          work_end,
          funding,
          points_json,
          created_at,
          updated_at,
          sync_status,
          login_id,
          saved_by_user_id,
          synced,
          sync_date,
          downloaded,
          service_level,
          functionality,
          socio_administrative_interest,
          served_population,
          agricultural_potential,
          investment_cost,
          environmental_protection,
          global_score,
          region_name,
          prefecture_name,
          commune_name
        )
        SELECT
          id,
          api_id,
          line_code,
          user_login,
          start_time,
          end_time,
          origin_name,
          origin_x,
          origin_y,
          destination_name,
          destination_x,
          destination_y,
          has_intersection,
          intersection_count,
          intersections_json,
          completed_works,
          work_date,
          company,
          platform,
          relief,
          vegetation,
          work_start,
          work_end,
          funding,
          points_json,
          created_at,
          updated_at,
          sync_status,
          login_id,
          saved_by_user_id,
          synced,
          sync_date,
          downloaded,
          service_level,
          functionality,
          socio_administrative_interest,
          served_population,
          agricultural_potential,
          investment_cost,
          environmental_protection,
          global_score,
          region_name,
          prefecture_name,
          commune_name
        FROM $tmpLinesTable
      ''');

      await txn.execute('DROP TABLE $tmpLinesTable');
    });
  }

  int _apiHasIntersectionToInt(dynamic value) {
    if (value == null) return 0;
    if (value is bool) return value ? 1 : 0;
    if (value is int) return value;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == '1' || normalized == 'true' || normalized == 'oui') {
        return 1;
      }
    }
    return 0;
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Color getLineTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'bitume':
        return Colors.black;
      case 'terre':
        return const Color(0xFFD2691E);
      case 'latérite':
        return Colors.red.shade700;
      case 'bouwal':
      case 'bowal':
        return Colors.yellow.shade700;
      case 'déviation':
      case 'deviation':
        return Colors.orange.shade700;
      case 'coupure':
        return Colors.deepPurple;
      case 'submersible':
        return Colors.teal;
      case 'col':
        return Colors.green.shade800;
      default:
        return Colors.blueGrey;
    }
  }

  StrokePattern? getLineTypePattern(String type) {
    switch (type.toLowerCase()) {
      case 'bitume':
      case 'asphalte':
        return null;
      case 'terre':
        return StrokePattern.dashed(segments: const [8, 4, 20, 4]);
      case 'latérite':
        return StrokePattern.dashed(segments: const [15, 8]);
      case 'bouwal':
      case 'bowal':
        return StrokePattern.dashed(segments: const [12, 6]);
      case 'déviation':
      case 'deviation':
        return StrokePattern.dashed(segments: const [15, 5, 5, 5]);
      case 'coupure':
        return const StrokePattern.dotted(spacingFactor: 1.2);
      case 'submersible':
        return StrokePattern.dashed(segments: const [6, 3, 6, 3]);
      case 'col':
        return StrokePattern.dashed(segments: const [20, 5]);
      case 'béton':
        return const StrokePattern.dotted(spacingFactor: 1.5);
      case 'pavée':
        return StrokePattern.dashed(segments: const [10, 5]);
      default:
        return null;
    }
  }

  Future<bool> _tableExists(String tableName) async {
    final db = await database;
    final result = await db.query(
      'sqlite_master',
      columns: ['name'],
      where: 'type = ? AND name = ?',
      whereArgs: ['table', tableName],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> loadDisplayedLinesFromStorageMaps() async {
    try {
      if (!await _tableExists(_displayedLinesTable)) {
        return [];
      }
      final db = await database;
      final loginId = await DatabaseHelper().resolveLoginId();
      if (loginId == null) return [];

      return db.query(
        _displayedLinesTable,
        where: 'login_id = ?',
        whereArgs: [loginId],
        orderBy: 'created_at DESC',
      );
    } catch (e) {
      debugPrint('[LINE-STORAGE] erreur chargement displayed_lines: $e');
      return [];
    }
  }

  Future<void> saveDisplayedLine(
    String lineCode,
    List<LatLng> points,
    Color color,
    double width,
  ) async {
    try {
      final db = await database;
      final loginId = await DatabaseHelper().resolveLoginId();

      if (loginId == null) {
        debugPrint('[LINE-STORAGE] login_id introuvable pour displayed_lines');
        return;
      }

      final pointsJson = jsonEncode(
        points
            .map((point) => {'lat': point.latitude, 'lng': point.longitude})
            .toList(),
      );

      await db.insert(
        _displayedLinesTable,
        {
          'login_id': loginId,
          _lineCodeColumn: lineCode,
          'points_json': pointsJson,
          'color': color.toARGB32(),
          'width': width,
          'created_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      debugPrint('[LINE-STORAGE] ligne affichee sauvegardee: $lineCode');
    } catch (e) {
      debugPrint('[LINE-STORAGE] erreur sauvegarde ligne affichee: $e');
    }
  }

  Future<List<Polyline>> loadDisplayedLines() async {
    try {
      final db = await database;
      final loginId = await DatabaseHelper().resolveLoginId();

      if (loginId == null) {
        debugPrint(
            '[LINE-STORAGE] login_id introuvable, aucune ligne affichee rechargee');
        return [];
      }

      final maps = await db.query(
        _displayedLinesTable,
        where: 'login_id = ?',
        whereArgs: [loginId],
      );

      final polylines = <Polyline>[];
      for (final map in maps) {
        final pointsData = jsonDecode(map['points_json'] as String) as List;
        final points = <LatLng>[];

        for (final item in pointsData) {
          final lat = _asDouble(item['lat']);
          final lng = _asDouble(item['lng']);
          if (lat != null && lng != null) {
            points.add(LatLng(lat, lng));
          }
        }

        if (points.isNotEmpty) {
          polylines.add(
            Polyline(
              points: points,
              color: Color(map['color'] as int),
              strokeWidth: (map['width'] as num).toDouble(),
              pattern: const StrokePattern.dotted(spacingFactor: 2.0),
            ),
          );
        }
      }

      debugPrint('[LINE-STORAGE] ${polylines.length} ligne(s) rechargee(s)');
      return polylines;
    } catch (e) {
      debugPrint('[LINE-STORAGE] erreur chargement lignes affichees: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> loadDisplayedLinesMaps() async {
    try {
      final db = await database;
      final loginId = await DatabaseHelper().resolveLoginId();

      if (loginId == null) {
        debugPrint(
            '[LINE-STORAGE] loadDisplayedLinesMaps: login_id introuvable');
        return [];
      }

      return db.query(
        _displayedLinesTable,
        where: 'login_id = ?',
        whereArgs: [loginId],
        orderBy: 'created_at DESC',
      );
    } catch (e) {
      debugPrint('[LINE-STORAGE] erreur loadDisplayedLinesMaps: $e');
      return [];
    }
  }

  Future<int?> saveLine(Map<String, dynamic> formData) async {
    try {
      final dbHelper = DatabaseHelper();
      final loginId = await dbHelper.resolveLoginId();
      final data = Map<String, dynamic>.from(formData);
      data['login_id'] = loginId;

      final line = LineModel.fromFormData(data);
      final id = await dbHelper.insertEntityLocal(
        _linesTable,
        line.toMap(),
        recordHistory: true,
      );

      debugPrint(
          '[LINE-STORAGE] ligne "${line.lineCode}" sauvegardee avec ID: $id');
      return id;
    } catch (e) {
      debugPrint('[LINE-STORAGE] erreur sauvegarde ligne: $e');
      return null;
    }
  }

  Future<void> debugPrintAllLines() async {
    try {
      final db = await database;
      final rows = await db.query(_linesTable);

      debugPrint('[LINE-STORAGE] liste complète des lignes');
      debugPrint('[LINE-STORAGE] nombre total de lignes: ${rows.length}');

      for (var i = 0; i < rows.length; i++) {
        final row = rows[i];
        debugPrint('\n[LINE-STORAGE] ligne #${i + 1}');
        row.forEach((key, value) {
          if (key != 'points_json') {
            debugPrint('   $key: $value');
          } else {
            final pointsJson = value.toString();
            debugPrint('   $key: [${pointsJson.length} caracteres]');
          }
        });
      }
    } catch (e) {
      debugPrint('[LINE-STORAGE] erreur lecture lignes: $e');
    }
  }

  Future<List<LineModel>> getAllLines() async {
    try {
      final db = await database;
      final maps = await db.query(_linesTable, orderBy: 'created_at DESC');
      return maps.map(LineModel.fromMap).toList();
    } catch (e) {
      debugPrint('[LINE-STORAGE] erreur lecture lignes: $e');
      return [];
    }
  }

  Future<Map<String, int>> getCount() async {
    try {
      final db = await database;
      final lineCount = Sqflite.firstIntValue(
              await db.rawQuery('SELECT COUNT(*) FROM $_linesTable')) ??
          0;
      return {'lines': lineCount, 'total': lineCount};
    } catch (e) {
      debugPrint('[LINE-STORAGE] erreur comptage: $e');
      return {'lines': 0, 'total': 0};
    }
  }

  Future<List<Map<String, dynamic>>> getUserLines() async {
    final db = await database;
    return db.query(
      _linesTable,
      where: 'synced = ? AND downloaded = ?',
      whereArgs: [0, 0],
    );
  }

  Future<List<Map<String, dynamic>>> getDownloadedLines() async {
    final db = await database;
    return db.query(
      _linesTable,
      where: 'synced = ? AND downloaded = ?',
      whereArgs: [0, 1],
    );
  }

  Future<List<Map<String, dynamic>>> getUnsyncedLines() async {
    try {
      final db = await database;
      final loginId = await DatabaseHelper().resolveLoginId();
      final maps = await db.query(
        _linesTable,
        where: 'synced = ? AND downloaded = ? AND login_id = ?',
        whereArgs: [0, 0, loginId],
      );

      debugPrint(
          '[LINE-STORAGE] lignes non synchronisées trouvées: ${maps.length}');
      return maps;
    } catch (e) {
      debugPrint('[LINE-STORAGE] erreur lecture lignes non synchronisées: $e');
      return [];
    }
  }

  Future<void> markLineAsSynced(int lineId) async {
    try {
      await DatabaseHelper().updateEntityLocal(
        _linesTable,
        lineId,
        {
          'synced': 1,
          'downloaded': 0,
          'sync_date': DateTime.now().toIso8601String(),
          'sync_status': 'synced',
        },
        recordHistory: true,
      );
      debugPrint('[LINE-STORAGE] ligne $lineId marquée comme synchronisée');
    } catch (e) {
      debugPrint('[LINE-STORAGE] erreur marquage ligne synchronisée: $e');
    }
  }

  Future<void> markLineAsSyncedAndUpdated(
    int lineId,
    Map<String, dynamic> apiResponse,
  ) async {
    try {
      final db = await database;
      final oldRows = await db.query(
        _linesTable,
        columns: [_lineCodeColumn],
        where: 'id = ?',
        whereArgs: [lineId],
        limit: 1,
      );
      final oldLineCode = oldRows.isNotEmpty
          ? oldRows.first[_lineCodeColumn]?.toString()
          : null;

      final updates = <String, dynamic>{
        'synced': 1,
        'downloaded': 0,
        'sync_date': DateTime.now().toIso8601String(),
        'sync_status': 'synced',
        'api_id': apiResponse['id'],
      };

      final properties =
          apiResponse['properties'] as Map<String, dynamic>? ?? apiResponse;
      final newLineCode = properties[_lineCodeColumn]?.toString();
      if (newLineCode != null) {
        updates[_lineCodeColumn] = newLineCode;
      }
      if (properties['region_name'] != null) {
        updates['region_name'] = properties['region_name'];
      }
      if (properties['prefecture_name'] != null) {
        updates['prefecture_name'] = properties['prefecture_name'];
      }
      if (properties['commune_name'] != null) {
        updates['commune_name'] = properties['commune_name'];
      }
      if (properties['has_intersection'] != null) {
        updates['has_intersection'] =
            _apiHasIntersectionToInt(properties['has_intersection']);
      }
      if (properties['intersection_count'] != null) {
        updates['intersection_count'] = properties['intersection_count'];
      }
      if (properties['intersections_json'] != null) {
        updates['intersections_json'] =
            properties['intersections_json'] is String
                ? properties['intersections_json']
                : jsonEncode(properties['intersections_json']);
      }

      await DatabaseHelper().updateEntityLocal(
        _linesTable,
        lineId,
        updates,
        recordHistory: true,
      );

      if (newLineCode != null &&
          oldLineCode != null &&
          newLineCode != oldLineCode) {
        final loginId = await DatabaseHelper().resolveLoginId();
        await db.update(
          _displayedLinesTable,
          {_lineCodeColumn: newLineCode},
          where: '$_lineCodeColumn = ? AND login_id = ?',
          whereArgs: [oldLineCode, loginId],
        );

        final mainDb = await DatabaseHelper().database;
        final relatedTables = [
          'localites',
          'ecoles',
          'marches',
          'services_santes',
          'batiments_administratifs',
          'infrastructures_hydrauliques',
          'autres_infrastructures',
          'ponts',
          'bacs',
          'buses',
          'dalots',
          'passages_submersibles',
          'points_critiques',
          'points_coupures',
          'site_enquete',
          'enquete_polygone',
        ];

        for (final table in relatedTables) {
          try {
            final impactedRows = await mainDb.query(
              table,
              columns: ['id'],
              where: '$_lineCodeColumn = ? AND synced = 0',
              whereArgs: [oldLineCode],
            );

            for (final row in impactedRows) {
              final localId = row['id'] as int?;
              if (localId == null) continue;
              await DatabaseHelper().updateEntityLocal(
                table,
                localId,
                {_lineCodeColumn: newLineCode},
                recordHistory: true,
              );
            }
          } catch (_) {}
        }

        try {
          await mainDb.update(
            'displayed_points',
            {_lineCodeColumn: newLineCode},
            where: '$_lineCodeColumn = ?',
            whereArgs: [oldLineCode],
          );
        } catch (_) {}
      }

      debugPrint('[LINE-STORAGE] ligne $lineId synchronisée et mise à jour');
    } catch (e) {
      debugPrint('[LINE-STORAGE] erreur markLineAsSyncedAndUpdated: $e');
    }
  }

  Future<void> updateLine(Map<String, dynamic> lineData) async {
    try {
      final updateData = {
        _lineCodeColumn: lineData[_lineCodeColumn] ?? lineData['line_code'],
        'user_login': lineData['user_login'],
        'start_time': lineData['start_time'],
        'end_time': lineData['end_time'],
        _originNameColumn:
            lineData[_originNameColumn] ?? lineData['origin_name'],
        'origin_x': lineData['origin_x'],
        'origin_y': lineData['origin_y'],
        _destinationNameColumn:
            lineData[_destinationNameColumn] ?? lineData['destination_name'],
        'destination_x': lineData['destination_x'],
        'destination_y': lineData['destination_y'],
        'has_intersection': lineData['has_intersection'],
        'intersection_count': lineData['intersection_count'],
        'intersections_json': lineData['intersections_json'] is String
            ? lineData['intersections_json']
            : jsonEncode(lineData['intersections_json'] ?? []),
        'completed_works': lineData['completed_works'],
        'work_date': lineData['work_date'],
        'company': lineData['company'],
        'platform': lineData['platform'],
        'relief': lineData['relief'],
        'vegetation': lineData['vegetation'],
        'work_start': lineData['work_start'],
        'work_end': lineData['work_end'],
        'funding': lineData['funding'],
        'points_json': jsonEncode(lineData['points']),
        'updated_at': lineData['updated_at'],
        'login_id': lineData['login_id'],
      };

      await DatabaseHelper().updateEntityLocal(
        _linesTable,
        lineData['id'] as int,
        updateData,
        recordHistory: true,
      );

      debugPrint(
          '[LINE-STORAGE] ligne ${lineData['id']} mise à jour avec succès');
    } catch (e) {
      debugPrint('[LINE-STORAGE] erreur mise à jour ligne: $e');
      rethrow;
    }
  }

  Future<void> deleteLine(int id) async {
    await DatabaseHelper().deleteEntityLocal(
      _linesTable,
      id,
      recordHistory: true,
    );
  }

  Future<String?> findNearestLineCode(
    LatLng position, {
    String? activeLineCode,
  }) async {
    try {
      final db = await database;

      if (activeLineCode != null) {
        debugPrint('[LINE-STORAGE] utilisation ligne active: $activeLineCode');
        return activeLineCode;
      }

      final loginId = await DatabaseHelper().resolveLoginId();
      if (loginId == null) {
        debugPrint('[LINE-STORAGE] login_id introuvable pour recherche ligne');
        return null;
      }

      final lineRows = await db.rawQuery('''
        SELECT id, $_lineCodeColumn, points_json FROM $_linesTable
        WHERE login_id = ?
        UNION
        SELECT id, $_lineCodeColumn, points_json FROM $_linesTable
        WHERE saved_by_user_id = ? AND downloaded = 1
      ''', [loginId, loginId]);

      if (lineRows.isEmpty) return null;

      String? nearestCode;
      var minDistance = double.maxFinite;

      for (final row in lineRows) {
        try {
          final pointsData = jsonDecode(row['points_json'] as String) as List;

          for (final pointData in pointsData) {
            final lat = _asDouble(pointData['latitude'] ?? pointData['lat']);
            final lng = _asDouble(pointData['longitude'] ?? pointData['lng']);

            if (lat != null && lng != null) {
              final distance = _calculateDistance(position, LatLng(lat, lng));
              if (distance < minDistance) {
                minDistance = distance;
                nearestCode = row[_lineCodeColumn] as String?;
              }
            }
          }
        } catch (e) {
          debugPrint('[LINE-STORAGE] erreur lecture ligne ${row['id']}: $e');
        }
      }

      debugPrint(
        '[LINE-STORAGE] ligne la plus proche: $nearestCode (${minDistance.toStringAsFixed(0)} m)',
      );
      return nearestCode;
    } catch (e) {
      debugPrint('[LINE-STORAGE] erreur recherche ligne proche: $e');
      return null;
    }
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const earthRadius = 6371000.0;

    final dLat = _degreesToRadians(point2.latitude - point1.latitude);
    final dLon = _degreesToRadians(point2.longitude - point1.longitude);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(point1.latitude)) *
            cos(_degreesToRadians(point2.latitude)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) => degrees * (pi / 180);

  Future<void> deleteDisplayedLine(int lineId) async {
    try {
      final db = await database;
      final loginId = await DatabaseHelper().resolveLoginId();

      final lineRows = await db.query(
        _linesTable,
        where: 'id = ?',
        whereArgs: [lineId],
        limit: 1,
      );

      if (lineRows.isNotEmpty) {
        final lineCode = lineRows.first[_lineCodeColumn] as String?;
        if (lineCode != null) {
          await db.delete(
            _displayedLinesTable,
            where: '$_lineCodeColumn = ? AND login_id = ?',
            whereArgs: [lineCode, loginId],
          );
          debugPrint('[LINE-STORAGE] ligne affichee supprimee: $lineCode');
        }
      }
    } catch (e) {
      debugPrint('[LINE-STORAGE] erreur suppression ligne affichee: $e');
    }
  }
}
