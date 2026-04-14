// lib/data/local/piste_storage_helper.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../models/piste_model.dart';
import 'dart:convert'; // Pour jsonEncode/jsonDecode
import 'package:flutter/material.dart'; // Pour Color
import 'package:flutter_map/flutter_map.dart'; // Pour Polyline
import 'package:latlong2/latlong.dart'; // Pour LatLng
import '../remote/api_service.dart';
import 'dart:math';
import 'database_helper.dart';

class PisteStorageHelper {
  static final PisteStorageHelper _instance = PisteStorageHelper._internal();
  factory PisteStorageHelper() => _instance;
  static Database? _database;

  PisteStorageHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'piste_chaussee_storage.db');
    print('[PISTE-STORAGE] Base SQLite pistes: $path');

    return await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        print('[PISTE-STORAGE] Creation des tables pistes...');

        // Table Pistes
        await db.execute('''
          CREATE TABLE pistes (
            id INTEGER PRIMARY KEY ,
            api_id INTEGER,

            code_piste TEXT NOT NULL,
            commune_rurale_id TEXT,
            commune_rurales INTEGER,
            user_login TEXT ,
            heure_debut TEXT ,
            heure_fin TEXT ,
            nom_origine_piste TEXT ,
            x_origine REAL ,
            y_origine REAL ,
            nom_destination_piste TEXT ,
            x_destination REAL ,
            y_destination REAL ,
            existence_intersection INTEGER DEFAULT 0,
            nombre_intersections INTEGER DEFAULT 0,
            intersections_json TEXT DEFAULT '[]',
            type_occupation TEXT,
            debut_occupation TEXT,
            fin_occupation TEXT,
            largeur_emprise REAL,
            frequence_trafic TEXT,
            type_trafic TEXT,
            travaux_realises TEXT,
            date_travaux TEXT,
            entreprise TEXT,
            plateforme TEXT,
            relief TEXT,
            vegetation TEXT,
            debut_travaux TEXT,
            fin_travaux TEXT,
            financement TEXT,
            projet TEXT,
            points_json TEXT NOT NULL,
            created_at TEXT ,
            updated_at TEXT,
            sync_status TEXT DEFAULT 'pending',
            login_id INTEGER,
            saved_by_user_id INTEGER,
            synced INTEGER DEFAULT 0,
            date_sync TEXT,
            downloaded INTEGER DEFAULT 0,
            niveau_service REAL,
            fonctionnalite REAL,
            interet_socio_administratif REAL,
            population_desservie REAL,
            potentiel_agricole REAL,
            cout_investissement REAL,
            protection_environnement REAL,
            note_globale REAL,
            region_name TEXT,
            prefecture_name TEXT,
            commune_name TEXT
          )
        ''');
        await db.execute('''
CREATE UNIQUE INDEX IF NOT EXISTS idx_pistes_api_user
ON pistes(api_id, saved_by_user_id);

''');
        // Table pour le cache des pistes affichÃ©es
        await db.execute('''
CREATE TABLE IF NOT EXISTS displayed_pistes (
  id INTEGER PRIMARY KEY,
  login_id INTEGER NOT NULL,
  code_piste TEXT NOT NULL,
  points_json TEXT NOT NULL,
  color INTEGER NOT NULL,
  width REAL NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
''');

        await db.execute('''
CREATE UNIQUE INDEX IF NOT EXISTS idx_displayed_pistes_user_code
ON displayed_pistes(login_id, code_piste);
''');

        print('[PISTE-STORAGE] Tables creees avec succes');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          print('[PISTE-STORAGE] migration base vers version 2');
          await db.execute('ALTER TABLE pistes ADD COLUMN plateforme TEXT');
          await db.execute('ALTER TABLE pistes ADD COLUMN relief TEXT');
          await db.execute('ALTER TABLE pistes ADD COLUMN vegetation TEXT');
          await db.execute('ALTER TABLE pistes ADD COLUMN debut_travaux TEXT');
          await db.execute('ALTER TABLE pistes ADD COLUMN fin_travaux TEXT');
          await db.execute('ALTER TABLE pistes ADD COLUMN financement TEXT');
          await db.execute('ALTER TABLE pistes ADD COLUMN projet TEXT');
          print('[PISTE-STORAGE] colonnes version 2 ajoutees');
        }
        if (oldVersion < 3) {
          print('[PISTE-STORAGE] migration base vers version 3');
          await db.execute('ALTER TABLE pistes ADD COLUMN niveau_service REAL');
          await db.execute('ALTER TABLE pistes ADD COLUMN fonctionnalite REAL');
          await db.execute('ALTER TABLE pistes ADD COLUMN interet_socio_administratif REAL');
          await db.execute('ALTER TABLE pistes ADD COLUMN population_desservie REAL');
          await db.execute('ALTER TABLE pistes ADD COLUMN potentiel_agricole REAL');
          await db.execute('ALTER TABLE pistes ADD COLUMN cout_investissement REAL');
          await db.execute('ALTER TABLE pistes ADD COLUMN protection_environnement REAL');
          await db.execute('ALTER TABLE pistes ADD COLUMN note_globale REAL');
          print('[PISTE-STORAGE] colonnes d evaluation ajoutees');
        }
      },
    );
  }

  int _apiExistenceToInt(dynamic value) {
    if (value == null) return 0;
    if (value is bool) return value ? 1 : 0;
    if (value is int) return value;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == '1' || normalized == 'true' || normalized == 'oui') {
        return 1;
      }
      return 0;
    }
    return 0;
  }

  Color getChausseeColor(String type) {
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

  StrokePattern? getChausseePattern(String type) {
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

  Future<List<Map<String, dynamic>>> loadDisplayedChausseesMaps() async {
    try {
      final db = await database;
      final loginId = await DatabaseHelper().resolveLoginId();
      if (loginId == null) return [];

      return await db.query(
        'displayed_chaussees',
        where: 'login_id = ?',
        whereArgs: [loginId],
        orderBy: 'created_at DESC',
      );
    } catch (e) {
      print('[PISTE-STORAGE] Erreur loadDisplayedChausseesMaps: $e');
      return [];
    }
  }
// Sauvegarder une piste affichÃ©e
  Future<void> saveDisplayedPiste(
    String codePiste,
    List<LatLng> points,
    Color color,
    double width,
  ) async {
    try {
      final db = await database;
      final dbHelper = DatabaseHelper();
      final loginId = await dbHelper.resolveLoginId();

      if (loginId == null) {
        print('[PISTE-STORAGE] impossible de determiner login_id pour displayed_pistes');
        return;
      }

      final pointsJson = jsonEncode(points
          .map((p) => {
                'lat': p.latitude,
                'lng': p.longitude
              })
          .toList());

      await db.insert(
        'displayed_pistes',
        {
          'login_id': loginId,
          'code_piste': codePiste, // âœ… IMPORTANT
          'points_json': pointsJson,
          'color': color.value,
          'width': width, // âœ… REAL, pas toInt
          'created_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace, // âœ… UPSERT
      );

      print('[PISTE-STORAGE] piste affichee sauvegardee: $codePiste (user=$loginId)');
    } catch (e) {
      print('[PISTE-STORAGE] erreur sauvegarde displayed_pistes: $e');
    }
  }
  // Charger toutes les pistes affichÃ©es
  Future<List<Polyline>> loadDisplayedPistes() async {
    try {
      final db = await database;
      final dbHelper = DatabaseHelper();
      final loginId = await dbHelper.resolveLoginId();

      if (loginId == null) {
        print('[PISTE-STORAGE] login_id introuvable, aucune piste affichee rechargee');
        return [];
      }
      //  FILTRER PAR UTILISATEUR
      final List<Map<String, dynamic>> maps = await db.query(
        'displayed_pistes',
        where: 'login_id = ?', // â† FILTRE IMPORTANT
        whereArgs: [
          loginId
        ], // â† ID de l'utilisateur connectÃ©
      );

      final List<Polyline> polylines = [];

      for (final map in maps) {
        final pointsData = jsonDecode(map['points_json']) as List;
        final List<LatLng> points = [];

        for (final p in pointsData) {
          final lat = p['lat'] as double?;
          final lng = p['lng'] as double?;
          if (lat != null && lng != null) {
            points.add(LatLng(lat, lng));
          }
        }

        if (points.isNotEmpty) {
          polylines.add(Polyline(
            points: points,
            color: Color(map['color'] as int),
            strokeWidth: (map['width'] as num).toDouble(),
            pattern: const StrokePattern.dotted(spacingFactor: 2.0),
          ));
        }
      }

      print('[PISTE-STORAGE] ${polylines.length} piste(s) rechargee(s) pour user=$loginId');
      return polylines;
    } catch (e) {
      print('[PISTE-STORAGE] erreur chargement displayed_pistes: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> loadDisplayedPistesMaps() async {
    try {
      final db = await database;
      final loginId = await DatabaseHelper().resolveLoginId();

      if (loginId == null) {
        print('âŒ [loadDisplayedPistesMaps] loginId null');
        return [];
      }

      return await db.query(
        'displayed_pistes',
        where: 'login_id = ?',
        whereArgs: [
          loginId
        ],
        orderBy: 'created_at DESC',
      );
    } catch (e) {
      print('âŒ Erreur loadDisplayedPistesMaps: $e');
      return [];
    }
  }

  /// Sauvegarder une piste depuis le formulaire
  Future<int?> savePiste(Map<String, dynamic> formData) async {
    try {
      final dbHelper = DatabaseHelper();
      final loginId = await dbHelper.resolveLoginId();
      print('[PISTE-STORAGE] debut sauvegarde piste');
      print('[PISTE-STORAGE] commune_rurales recue: ${formData['commune_rurales']}');
      // Ajouter le login_id aux donnÃ©es du formulaire
      final formDataWithLoginId = Map<String, dynamic>.from(formData);
      formDataWithLoginId['login_id'] = loginId;
      print('[PISTE-STORAGE] donnees recues:');
      formData.forEach((key, value) {
        // Ne pas logger les donnÃ©es trop longues (comme points_json)
        if (key != 'points' && key != 'points_json') {
          print('   $key: $value');
        }
      });

      final piste = PisteModel.fromFormData(formData);
      final id = await dbHelper.insertEntityLocal(
        'pistes',
        piste.toMap(),
        recordHistory: true,
      );

      print('[PISTE-STORAGE] piste "${piste.codePiste}" sauvegardee avec ID: $id pour login_id=$loginId');

      // AFFICHER TOUS LES CHAMPS DE LA PISTE
      print('[PISTE-STORAGE] details de la piste enregistree:');
      final pisteMap = piste.toMap();
      pisteMap.forEach((key, value) {
        if (key != 'points_json') {
          // Ã‰viter le JSON trop long
          print('   $key: $value');
        } else {
          print('   $key: [JSON contenant ${piste.pointsJson.length} caracteres]');
        }
      });

      return id;
    } catch (e) {
      print('[PISTE-STORAGE] erreur sauvegarde piste: $e');
      print('[PISTE-STORAGE] donnees ayant cause l erreur:');
      formData.forEach((key, value) {
        print('   $key: $value (type: ${value.runtimeType})');
      });
      return null;
    }
  }

// Dans PisteStorageHelper, ajoutez cette mÃ©thode
  Future<void> debugPrintAllPistes() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> pistes = await db.query('pistes');

      print('ðŸ“Š === LISTE COMPLÃˆTE DES PISTES ===');
      print('ðŸ“ˆ Nombre total de pistes: ${pistes.length}');

      for (var i = 0; i < pistes.length; i++) {
        final piste = pistes[i];
        print('\nðŸŽ¯ PISTE #${i + 1}');
        piste.forEach((key, value) {
          if (key != 'points_json') {
            print('   $key: $value');
          } else {
            final pointsJson = value.toString();
            print('   $key: [${pointsJson.length} caractÃ¨res]');
            // Pour voir un extrait du JSON :
            if (pointsJson.length > 50) {
              print('        Extrait: ${pointsJson.substring(0, 50)}...');
            }
          }
        });
      }
      print('====================================');
    } catch (e) {
      print('âŒ Erreur lecture pistes: $e');
    }
  }

// Dans la classe PisteStorageHelper
  Future<int?> _getCommuneId() async {
    try {
      /* GPS-BASED ATTRIBUTION: 
         On retourne null pour laisser le backend dÃ©terminer la commune 
         spatialement via ST_Contains lors de la synchronisation.
      */
      return null;
    } catch (e) {
      print('âŒ Erreur _getCommuneId: $e');
      return null;
    }
  }
  /// Lister toutes les pistes (optionnel pour debug)
  Future<List<PisteModel>> getAllPistes() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query('pistes', orderBy: 'created_at DESC');
      return maps.map((map) => PisteModel.fromMap(map)).toList();
    } catch (e) {
      print('âŒ Erreur lecture pistes: $e');
      return [];
    }
  }
  /// Compter le total d'Ã©lÃ©ments sauvegardÃ©s (optionnel pour debug)
  Future<Map<String, int>> getCount() async {
    try {
      final db = await database;
      final pisteCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM pistes')) ?? 0;
      
      return {
        'pistes': pisteCount,
        'total': pisteCount,
      };
    } catch (e) {
      print('âŒ Erreur comptage: $e');
      return {
        'pistes': 0,
        'total': 0
      };
    }
  }

// RÃ©cupÃ©rer seulement les pistes crÃ©Ã©es par l'utilisateur (Ã  synchroniser)
  Future<List<Map<String, dynamic>>> getUserPistes() async {
    final db = await database;
    return await db.query(
      'pistes',
      where: 'synced = ? AND downloaded = ?',
      whereArgs: [
        0,
        0
      ], // CrÃ©Ã©es par user, pas encore synchronisÃ©es
    );
  }

// RÃ©cupÃ©rer seulement les pistes tÃ©lÃ©chargÃ©es (autres users)
  Future<List<Map<String, dynamic>>> getDownloadedPistes() async {
    final db = await database;
    return await db.query(
      'pistes',
      where: 'synced = ? AND downloaded = ?',
      whereArgs: [
        0,
        1
      ], // TÃ©lÃ©chargÃ©es, pas crÃ©Ã©es par cet user
    );
  }

  Future<List<Map<String, dynamic>>> getUnsyncedPistes() async {
    try {
      final db = await database;
      final loginId = await DatabaseHelper().resolveLoginId();
      final List<Map<String, dynamic>> maps = await db.query(
        'pistes',
        where: 'synced = ? AND downloaded = ? AND login_id = ?',
        whereArgs: [
          0,
          0,
          loginId
        ],
        columns: [
          'id',
          'code_piste',
          'commune_rurale_id',
          'commune_rurales',
          'user_login',
          'heure_debut',
          'heure_fin',
          'nom_origine_piste',
          'x_origine',
          'y_origine',
          'nom_destination_piste',
          'x_destination',
          'y_destination',
          'existence_intersection',
          'nombre_intersections',
          'intersections_json',
          'type_occupation',
          'debut_occupation',
          'fin_occupation',
          'largeur_emprise',
          'frequence_trafic',
          'type_trafic',
          'travaux_realises',
          'date_travaux',
          'entreprise',
          'plateforme',
          'relief',
          'vegetation',
          'debut_travaux',
          'fin_travaux',
          'financement',
          'projet',
          'points_json',
          'niveau_service',
          'fonctionnalite',
          'interet_socio_administratif',
          'population_desservie',
          'potentiel_agricole',
          'cout_investissement',
          'protection_environnement',
          'note_globale',
          'created_at',
          'updated_at',
          'login_id',
          'synced',
          'date_sync'
        ],
      );

      print('[PISTE-STORAGE] pistes non synchronisees trouvees: ${maps.length}');
      if (maps.isNotEmpty) {
        print('[PISTE-STORAGE] premier login_id=${maps.first['login_id']}');
      }

      return maps;
    } catch (e) {
      print('[PISTE-STORAGE] erreur lecture pistes non synchronisees: $e');
      return [];
    }
  }

  Future<void> markPisteAsSynced(int pisteId) async {
    try {
      final dbHelper = DatabaseHelper();
      await dbHelper.updateEntityLocal(
        'pistes',
        pisteId,
        {
          'synced': 1,
          'downloaded': 0,
          'date_sync': DateTime.now().toIso8601String(),
          'sync_status': 'synced',
        },
        recordHistory: true,
      );
      print('[PISTE-STORAGE] piste $pisteId marquee comme synchronisee');
    } catch (e) {
      print('[PISTE-STORAGE] erreur marquage piste synchronisee: $e');
    }
  }

  Future<void> markPisteAsSyncedAndUpdated(int pisteId, Map<String, dynamic> apiResponse) async {
    try {
      final db = await database;

      // 1. RÃ©cupÃ©rer l'ancien code_piste AVANT la mise Ã  jour
      final oldRows = await db.query(
        'pistes',
        columns: [
          'code_piste'
        ],
        where: 'id = ?',
        whereArgs: [
          pisteId
        ],
        limit: 1,
      );
      final String? oldCodePiste = oldRows.isNotEmpty ? oldRows.first['code_piste']?.toString() : null;

      // 2. PrÃ©parer les mises Ã  jour
      final updates = <String, dynamic>{
        'synced': 1,
        'downloaded': 0,
        'date_sync': DateTime.now().toIso8601String(),
        'sync_status': 'synced',
        'api_id': apiResponse['id'],
      };

      final props = apiResponse['properties'] as Map<String, dynamic>? ?? apiResponse;

      //  RÃ©cupÃ©rer le nouveau code_piste du serveur
      final String? newCodePiste = props['code_piste']?.toString();
      if (newCodePiste != null) {
        updates['code_piste'] = newCodePiste;
        print('[PISTE-STORAGE] code piste mis a jour: $oldCodePiste -> $newCodePiste');
      }

      if (props['communes_rurales_id'] != null) {
        updates['commune_rurale_id'] = props['communes_rurales_id'].toString();
      }
      if (props['region_name'] != null) {
        updates['region_name'] = props['region_name'];
      }
      if (props['prefecture_name'] != null) {
        updates['prefecture_name'] = props['prefecture_name'];
      }
      if (props['commune_name'] != null) {
        updates['commune_name'] = props['commune_name'];
      }
      //  Stocker les donnÃ©es d'intersection renvoyÃ©es par le serveur
      if (props['existence_intersection'] != null) {
        updates['existence_intersection'] = _apiExistenceToInt(props['existence_intersection']);
      }
      if (props['nombre_intersections'] != null) {
        updates['nombre_intersections'] = props['nombre_intersections'];
      }
      if (props['intersections_json'] != null) {
        updates['intersections_json'] = props['intersections_json'] is String ? props['intersections_json'] : jsonEncode(props['intersections_json']);
      }

      // 3. Mettre Ã  jour la table pistes
      await DatabaseHelper().updateEntityLocal(
        'pistes',
        pisteId,
        updates,
        recordHistory: true,
      );

      //  4. Mettre Ã  jour AUSSI la table displayed_pistes
      if (newCodePiste != null && oldCodePiste != null && newCodePiste != oldCodePiste) {
        final dbHelper = DatabaseHelper();
        final loginId = await dbHelper.resolveLoginId();

        await db.update(
          'displayed_pistes',
          {
            'code_piste': newCodePiste
          },
          where: 'code_piste = ? AND login_id = ?',
          whereArgs: [
            oldCodePiste,
            loginId
          ],
        );
        print('[PISTE-STORAGE] displayed_pistes mis a jour: $oldCodePiste -> $newCodePiste');
      }

      //  5. PROPAGER le nouveau code_piste Ã  TOUTES les entitÃ©s locales non synchronisÃ©es
      // Ceci corrige le cas oÃ¹ la connexion est coupÃ©e aprÃ¨s la sync de la piste
      // mais avant la sync des autres entitÃ©s qui rÃ©fÃ©rencent l'ancien code temporaire
      if (newCodePiste != null && oldCodePiste != null && newCodePiste != oldCodePiste) {
        final mainDb = await DatabaseHelper().database;

        // Tables dans la BD principale (database_helper.dart)
        final pointTables = [
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

        for (final table in pointTables) {
          try {
            final impactedRows = await mainDb.query(
              table,
              columns: ['id'],
              where: 'code_piste = ? AND synced = 0',
              whereArgs: [oldCodePiste],
            );

            for (final row in impactedRows) {
              final localId = row['id'] as int?;
              if (localId == null) continue;
              await DatabaseHelper().updateEntityLocal(
                table,
                localId,
                {'code_piste': newCodePiste},
                recordHistory: true,
              );
            }

            if (impactedRows.isNotEmpty) {
              print('[PISTE-STORAGE] $table: ${impactedRows.length} entite(s) mises a jour $oldCodePiste -> $newCodePiste');
            }
          } catch (e) {
            // Table n'existe peut-Ãªtre pas encore, on continue
          }
        }

        // Tables d'affichage
        try {
          await mainDb.update(
            'displayed_points',
            {
              'code_piste': newCodePiste
            },
            where: 'code_piste = ?',
            whereArgs: [
              oldCodePiste
            ],
          );
        } catch (e) {
          // Ignore si table n'existe pas
        }
      }

      print('[PISTE-STORAGE] piste $pisteId synchronisee et mise a jour');
    } catch (e) {
      print('[PISTE-STORAGE] erreur markPisteAsSyncedAndUpdated: $e');
    }
  }

  Future<void> updatePiste(Map<String, dynamic> pisteData) async {
    try {
      final dbHelper = DatabaseHelper();

      final updateData = {
        'code_piste': pisteData['code_piste'],
        'commune_rurale_id': pisteData['commune_rurale_id'],
        'commune_rurales': null,
        'user_login': pisteData['user_login'],
        'heure_debut': pisteData['heure_debut'],
        'heure_fin': pisteData['heure_fin'],
        'nom_origine_piste': pisteData['nom_origine_piste'],
        'x_origine': pisteData['x_origine'],
        'y_origine': pisteData['y_origine'],
        'nom_destination_piste': pisteData['nom_destination_piste'],
        'x_destination': pisteData['x_destination'],
        'y_destination': pisteData['y_destination'],
        'existence_intersection': pisteData['existence_intersection'],
        'nombre_intersections': pisteData['nombre_intersections'],
        'intersections_json': pisteData['intersections_json'] is String
            ? pisteData['intersections_json']
            : jsonEncode(pisteData['intersections_json'] ?? []),
        'type_occupation': pisteData['type_occupation'],
        'debut_occupation': pisteData['debut_occupation'],
        'fin_occupation': pisteData['fin_occupation'],
        'largeur_emprise': pisteData['largeur_emprise'],
        'frequence_trafic': pisteData['frequence_trafic'],
        'type_trafic': pisteData['type_trafic'],
        'travaux_realises': pisteData['travaux_realises'],
        'date_travaux': pisteData['date_travaux'],
        'entreprise': pisteData['entreprise'],
        'plateforme': pisteData['plateforme'],
        'relief': pisteData['relief'],
        'vegetation': pisteData['vegetation'],
        'debut_travaux': pisteData['debut_travaux'],
        'fin_travaux': pisteData['fin_travaux'],
        'financement': pisteData['financement'],
        'projet': pisteData['projet'],
        'points_json': jsonEncode(pisteData['points']),
        'updated_at': pisteData['updated_at'],
        'login_id': pisteData['login_id'],
      };

      await dbHelper.updateEntityLocal(
        'pistes',
        pisteData['id'] as int,
        updateData,
        recordHistory: true,
      );

      print('[PISTE-STORAGE] piste ${pisteData['id']} mise a jour avec succes');
    } catch (e) {
      print('[PISTE-STORAGE] erreur mise a jour piste: $e');
      rethrow;
    }
  }

  Future<void> deletePiste(int id) async {
    final dbHelper = DatabaseHelper();
    await dbHelper.deleteEntityLocal(
      'pistes',
      id,
      recordHistory: true,
    );
  }

  Future<String?> findNearestPisteCode(LatLng position, {String? activePisteCode}) async {
    try {
      final db = await database;

      if (activePisteCode != null) {
        print('[PISTE-STORAGE] utilisation piste active: $activePisteCode');
        return activePisteCode;
      }

      final dbHelper = DatabaseHelper();
      final loginId = await dbHelper.resolveLoginId();

      if (loginId == null) {
        print('[PISTE-STORAGE] impossible de determiner le login_id (API + local)');
        return null;
      }

      final List<Map<String, dynamic>> pistes = await db.rawQuery('''
        SELECT id, code_piste, points_json FROM pistes
        WHERE login_id = ?
        UNION
        SELECT id, code_piste, points_json FROM pistes
        WHERE saved_by_user_id = ? AND downloaded = 1
      ''', [
        loginId,
        loginId
      ]);

      if (pistes.isEmpty) return null;

      String? nearestCode;
      double minDistance = double.maxFinite;

      for (final piste in pistes) {
        try {
          final pointsJson = piste['points_json'] as String;
          final pointsData = jsonDecode(pointsJson) as List;

          for (final pointData in pointsData) {
            final lat = pointData['latitude'] as double? ?? pointData['lat'] as double?;
            final lng = pointData['longitude'] as double? ?? pointData['lng'] as double?;

            if (lat != null && lng != null) {
              final pistePoint = LatLng(lat, lng);
              final distance = _calculateDistance(position, pistePoint);

              if (distance < minDistance) {
                minDistance = distance;
                nearestCode = piste['code_piste'] as String?;
              }
            }
          }
        } catch (e) {
          print('[PISTE-STORAGE] erreur lecture piste ${piste['id']}: $e');
        }
      }

      print('[PISTE-STORAGE] piste la plus proche: $nearestCode (${minDistance.toStringAsFixed(0)} m)');
      return nearestCode;
    } catch (e) {
      print('[PISTE-STORAGE] erreur recherche piste proche: $e');
      return null;
    }
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000;

    final double dLat = _degreesToRadians(point2.latitude - point1.latitude);
    final double dLon = _degreesToRadians(point2.longitude - point1.longitude);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(point1.latitude)) *
            cos(_degreesToRadians(point2.latitude)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  Future<void> deleteDisplayedPiste(int pisteId) async {
    try {
      final db = await database;
      final dbHelper = DatabaseHelper();
      final loginId = await dbHelper.resolveLoginId();

      final piste = await db.query('pistes',
          where: 'id = ?',
          whereArgs: [
            pisteId
          ],
          limit: 1);

      if (piste.isNotEmpty) {
        final codePiste = piste.first['code_piste'] as String?;

        if (codePiste != null) {
          await db.delete(
            'displayed_pistes',
            where: 'code_piste = ? AND login_id = ?',
            whereArgs: [
              codePiste,
              loginId
            ],
          );
          print('[PISTE-STORAGE] piste affichee supprimee: $codePiste');
        }
      }
    } catch (e) {
      print('[PISTE-STORAGE] erreur suppression piste affichee: $e');
    }
  }
}


