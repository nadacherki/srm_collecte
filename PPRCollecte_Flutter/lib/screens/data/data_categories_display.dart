import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'dart:math' as math;
import '../../core/config/infrastructure_config.dart';
import '../../widgets/forms/type_selector_widget.dart';
import '../../widgets/forms/point_form_widget.dart';
import '../../widgets/lists/data_list_view.dart';
import '../../data/local/database_helper.dart';
import '../home/home_page.dart';
import '../forms/polygon_form_page.dart';
import '../../services/form_lock_service.dart';

const bool _DBG_FOCUS_POINT = true;

extension on double {
  double sqrt() => math.sqrt(this);
}

class DataCategoriesDisplay extends StatefulWidget {
  final String mainCategory;
  final String dataFilter; // "unsynced", "synced", "saved"
  final bool isOnline;
  final String agentName;
  const DataCategoriesDisplay({
    super.key,
    required this.mainCategory,
    required this.dataFilter,
    required this.isOnline,
    required this.agentName,
  });

  @override
  State<DataCategoriesDisplay> createState() => _DataCategoriesDisplayState();
}

class _DataCategoriesDisplayState extends State<DataCategoriesDisplay> {
  String? selectedCategory;
  String? selectedType;
  List<Map<String, dynamic>> currentData = [];

  @override
  void initState() {
    super.initState();

    // POUR TOUTES LES CATÉGORIES: définir selectedCategory
    selectedCategory = widget.mainCategory;

    // UNIQUEMENT pour Pistes/Chaussées: définir aussi selectedType
    if (widget.mainCategory == "Pistes" || widget.mainCategory == "Chaussées") {
      selectedType = widget.mainCategory;
      // Charger les données après un petit délai
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _fetchData();
        }
      });
    }
  }

  double? _toD(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '.').trim());
    return null;
  }

  bool _isLat(double v) => v >= -90 && v <= 90;
  bool _isLon(double v) => v >= -180 && v <= 180;

  /// Choisit la meilleure orientation entre (lat,lon) et (lon,lat)
  /// CORRECTION: Ne JAMAIS inverser les coordonnées automatiquement
  LatLng? _bestLatLon(double? a, double? b) {
    if (a == null || b == null) return null;

    // ⭐⭐ SUPPRIMER LA LOGIQUE D'INVERSION - toujours considérer a=lat, b=lon
    // ou selon la convention établie dans votre base de données
    if (_isLat(a) && _isLon(b)) {
      return LatLng(a, b);
    }

    // ⭐⭐ NE PAS inverser automatiquement - si les coordonnées ne sont pas valides, retourner null
    return null;
  }

  /// Valide une paire SANS inversion automatique
  LatLng? _validateAndFix(double? lat, double? lng) {
    if (lat == null || lng == null) return null;
    if (_isLat(lat) && _isLng(lng)) return LatLng(lat, lng);

    // ⭐⭐ NE PAS inverser - si c'est invalide, c'est invalide
    return null;
  }

// Conversion UTM -> WGS84 (lon/lat), zone par défaut = 28N (SRID 32628)
  LatLng _utmToLatLng({
    required double easting, // X
    required double northing, // Y
    int zone = 28,
    bool northernHemisphere = true,
  }) {
    // Formules classiques (WGS84)
    const double a = 6378137.0;
    const double f = 1 / 298.257223563;
    const double k0 = 0.9996;
    const double b = a * (1 - f);
    final double e = (1 - (b / a) * (b / a)).sqrt();

    // helpers
    double asinh(double x) => math.log(x + math.sqrt(x * x + 1));
    double atanh(double x) => 0.5 * math.log((1 + x) / (1 - x));

    // enlever les faux-est & faux-nord pour l’hémisphère sud
    double x = easting - 500000.0;
    double y = northing;
    if (!northernHemisphere) y -= 10000000.0;

    final double m = y / k0;
    final double mu = m / (a * (1 - math.pow(e, 2) / 4 - 3 * math.pow(e, 4) / 64 - 5 * math.pow(e, 6) / 256));

    final double e1 = (1 - math.sqrt(1 - e * e)) / (1 + math.sqrt(1 - e * e));
    final double j1 = 3 * e1 / 2 - 27 * math.pow(e1, 3) / 32;
    final double j2 = 21 * math.pow(e1, 2) / 16 - 55 * math.pow(e1, 4) / 32;
    final double j3 = 151 * math.pow(e1, 3) / 96;
    final double j4 = 1097 * math.pow(e1, 4) / 512;

    final double fp = mu + j1 * math.sin(2 * mu) + j2 * math.sin(4 * mu) + j3 * math.sin(6 * mu) + j4 * math.sin(8 * mu);

    final double e2 = (e * e) / (1 - e * e);
    final double c1 = e2 * math.pow(math.cos(fp), 2);
    final double t1 = math.pow(math.tan(fp), 2).toDouble();
    final double r1 = a * (1 - e * e) / math.pow(1 - e * e * math.pow(math.sin(fp), 2), 1.5);
    final double n1 = a / math.sqrt(1 - e * e * math.pow(math.sin(fp), 2));
    final double d = x / (n1 * k0);

    double q1 = n1 * math.tan(fp) / r1;
    double q2 = (d * d) / 2;
    double q3 = (5 + 3 * t1 + 10 * c1 - 4 * c1 * c1 - 9 * e2) * math.pow(d, 4) / 24;
    double q4 = (61 + 90 * t1 + 298 * c1 + 45 * t1 * t1 - 252 * e2 - 3 * c1 * c1) * math.pow(d, 6) / 720;
    double lat = fp - q1 * (q2 - q3 + q4);

    double q5 = d;
    double q6 = (1 + 2 * t1 + c1) * math.pow(d, 3) / 6;
    double q7 = (5 - 2 * c1 + 28 * t1 - 3 * c1 * c1 + 8 * e2 + 24 * t1 * t1) * math.pow(d, 5) / 120;
    double lon = (q5 - q6 + q7) / math.cos(fp);

    final double lonOrigin = (zone - 1) * 6 - 180 + 3; // méridien central
    final double lonDeg = lonOrigin + lon * 180 / math.pi;
    final double latDeg = lat * 180 / math.pi;

    return LatLng(latDeg, lonDeg);
  }

  double? _toDoubleStrict(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim().replaceAll(',', '.'));
    return null;
  }

  bool _isLng(double v) => v >= -180 && v <= 180;

  /// Valide une paire et corrige si inversion possible

  LatLng _centroidOf(List<LatLng> line) {
    if (line.isEmpty) return const LatLng(0, 0);
    double sx = 0, sy = 0;
    for (final p in line) {
      sx += p.latitude;
      sy += p.longitude;
    }
    return LatLng(sx / line.length, sy / line.length);
  }

  /// WKT: "POINT(lon lat)"
  // parse WKT "POINT(lon lat)"
  LatLng? _parseWktPoint(String wkt) {
    final m = RegExp(r'POINT\s*\(\s*([-\d\.,]+)\s+([-\d\.,]+)\s*\)', caseSensitive: false).firstMatch(wkt);
    if (m == null) return null;
    final lon = double.tryParse(m.group(1)!.replaceAll(',', '.'));
    final lat = double.tryParse(m.group(2)!.replaceAll(',', '.'));
    if (lat == null || lon == null) return null;
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return null;
    return LatLng(lat, lon);
  }

// GeoJSON {"type":"Point","coordinates":[lon,lat]}
  LatLng? _parseGeoJsonPoint(dynamic geo) {
    try {
      final obj = (geo is String) ? jsonDecode(geo) : geo;
      if (obj is Map && obj['type']?.toString().toLowerCase() == 'point') {
        final c = obj['coordinates'];
        if (c is List && c.length >= 2) {
          final lon = (c[0] is String) ? double.tryParse(c[0].replaceAll(',', '.')) : (c[0] as num).toDouble();
          final lat = (c[1] is String) ? double.tryParse(c[1].replaceAll(',', '.')) : (c[1] as num).toDouble();
          if (lat == null || lon == null) return null;
          if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return null;
          return LatLng(lat, lon);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Helper unique: extrait un Point WGS84 (lat, lon) depuis un item
  /// Helper unique: extrait un Point WGS84 (lat, lon) depuis un item
  LatLng? _extractPointWgs84(Map<String, dynamic> row) {
    // 0) normalise les clés -> lowercase
    final r = <String, dynamic>{};
    row.forEach((k, v) => r[k.toString().toLowerCase()] = v);

    if (_DBG_FOCUS_POINT) {
      final show = r.keys.where((k) => k.contains('lat') || k.contains('lon') || k.contains('lng') || k.startsWith('x') || k.startsWith('y') || k == 'geom' || k == 'geometry' || k.contains('geojson') || k.contains('point')).toList();
      print('👁️ [FOCUS-ROW] keys=$show');
    }

    //  STRATÉGIE 1: Chercher d'abord les paires EXPLICITES selon la convention de votre base
    // Dans votre cas, x=longitude, y=latitude
    final explicitPairs = [
      // Format: [clé_longitude, clé_latitude] - x=longitude, y=latitude

      [
        'x_localite',
        'y_localite'
      ],
      [
        'x_ecole',
        'y_ecole'
      ],
      [
        'x_marche',
        'y_marche'
      ],
      [
        'x_sante',
        'y_sante'
      ],
      [
        'x_batiment_administratif',
        'y_batiment_administratif'
      ],
      [
        'x_infrastructure_hydraulique',
        'y_infrastructure_hydraulique'
      ],
      [
        'x_autre_infrastructure',
        'y_autre_infrastructure'
      ],
      [
        'x_pont',
        'y_pont'
      ],
      [
        'x_buse',
        'y_buse'
      ],
      [
        'x_dalot',
        'y_dalot'
      ],
      [
        'x_point_critique',
        'y_point_critique'
      ],
      [
        'x_point_coupure',
        'y_point_coupure'
      ],
      [
        'x_site',
        'y_site'
      ],
      // Pour les lignes spéciales - début
      [
        'x_debut_traversee_bac',
        'y_debut_traversee_bac'
      ],
      [
        'x_debut_passage_submersible',
        'y_debut_passage_submersible'
      ],

      // Variantes avec lng/lat
      [
        'lng_localite',
        'lat_localite'
      ],
      [
        'lng_ecole',
        'lat_ecole'
      ],
      [
        'lng_marche',
        'lat_marche'
      ],
      [
        'lng_sante',
        'lat_sante'
      ],
      [
        'lng_pont',
        'lat_pont'
      ],
      [
        'lng_dalot',
        'lat_dalot'
      ],
      [
        'x_point_co',
        'y_point_co'
      ],
      [
        'x_point_cr',
        'y_point_cr'
      ],
    ];

    for (final pair in explicitPairs) {
      final lng = _toD(r[pair[0]]); // Premier = longitude (x)
      final lat = _toD(r[pair[1]]); // Second = latitude (y)

      if (lat != null && lng != null) {
        //  VALIDATION SIMPLE - pas d'inversion automatique
        if (_isLat(lat) && _isLng(lng)) {
          if (_DBG_FOCUS_POINT) {
            print('✅ [FOCUS] Paire explicite $pair -> lat=$lat, lon=$lng');
          }
          return LatLng(lat, lng);
        } else {
          if (_DBG_FOCUS_POINT) {
            print('⚠️ [FOCUS] Paire $pair invalide: lat=$lat, lon=$lng');
          }
        }
      }
    }

    //  STRATÉGIE 2: GeoJSON (coordinates = [lon, lat])
    for (final k in [
      'geom',
      'geometry',
      'geojson',
      'point_geojson',
      'geom_geojson'
    ]) {
      final v = r[k];
      if (v == null) continue;
      try {
        final obj = (v is String) ? jsonDecode(v) : v;
        if (obj is Map && (obj['type']?.toString().toLowerCase() == 'point')) {
          final c = obj['coordinates'];
          if (c is List && c.length >= 2) {
            final lon = _toD(c[0]); // Premier = longitude
            final lat = _toD(c[1]); // Second = latitude
            if (lat != null && lon != null && _isLat(lat) && _isLng(lon)) {
              if (_DBG_FOCUS_POINT) {
                print('✅ [FOCUS] GeoJSON -> lat=$lat, lon=$lon');
              }
              return LatLng(lat, lon);
            }
          }
        }
      } catch (_) {}
    }

    //  STRATÉGIE 3: Chercher latitude/longitude explicites
    double? foundLat, foundLng;
    const ignoredKeys = {
      'intersections_json',
      'nombre_intersections',
      'existence_intersection'
    };
    for (final k in r.keys) {
      if (ignoredKeys.contains(k)) continue; //  IGNORER les clés d'intersection

      if (foundLat == null && (k.contains('latitude') || k == 'lat' || k.contains('_lat'))) {
        foundLat = _toD(r[k]);
      }
      if (foundLng == null && (k.contains('longitude') || k == 'lng' || k == 'lon' || k.contains('_lng') || k.contains('_lon'))) {
        foundLng = _toD(r[k]);
      }
      if (foundLat != null && foundLng != null) break;
    }

    if (foundLat != null && foundLng != null && _isLat(foundLat) && _isLng(foundLng)) {
      if (_DBG_FOCUS_POINT) {
        print('✅ [FOCUS] Champs séparés -> lat=$foundLat, lon=$foundLng');
      }
      return LatLng(foundLat, foundLng);
    }

    if (_DBG_FOCUS_POINT) {
      print('❌ [FOCUS] Impossible d\'extraire un point WGS84 valide');
      print('   Données disponibles:');
      r.forEach((key, value) {
        if (key.contains('x_') || key.contains('y_') || key.contains('lat') || key.contains('lng') || key.contains('lon')) {
          print('     $key: $value');
        }
      });
    }

    return null;
  }

  List<LatLng>? _extractPolyline(Map<String, dynamic> item) {
    double? toDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v.trim());
      return null;
    }

    LatLng? latLngFrom(Map p) {
      final lat = toDouble(p['latitude'] ?? p['lat'] ?? p['y']);
      final lng = toDouble(p['longitude'] ?? p['lng'] ?? p['lon'] ?? p['x']);
      if (lat == null || lng == null) return null;
      return LatLng(lat, lng);
    }

    // ---------- 1) PISTES / CHAUSSEES : points_collectes ----------
    if (item['points_collectes'] is List) {
      final raw = item['points_collectes'] as List;
      final pts = raw.whereType<Map>().map(latLngFrom).whereType<LatLng>().toList();
      if (pts.length >= 2) return pts;
    }

    // ---------- 2) points_json (JSON string OR list) ----------
    dynamic rawJson = item['points_json'];
    if (rawJson is String && rawJson.trim().isNotEmpty) {
      try {
        rawJson = jsonDecode(rawJson);
      } catch (_) {}
    }
    if (rawJson is List) {
      final pts = <LatLng>[];
      for (final e in rawJson) {
        if (e is Map) {
          final p = latLngFrom(e);
          if (p != null) pts.add(p);
        } else if (e is List && e.length >= 2) {
          // cas [lon,lat]
          final lon = toDouble(e[0]);
          final lat = toDouble(e[1]);
          if (lat != null && lon != null) pts.add(LatLng(lat, lon));
        }
      }
      if (pts.length >= 2) return pts;
    }

    // ---------- 3) LIGNES SPECIALES : debut/fin ----------
    // ---------- 3) LIGNES SPECIALES : debut/fin ----------
    LatLng? pair(dynamic latV, dynamic lngV) {
      final lat = toDouble(latV);
      final lng = toDouble(lngV);
      if (lat == null || lng == null) return null;
      return LatLng(lat, lng);
    }

// ⭐⭐ CORRECTION: Ajouter les paires spécifiques pour Bac et Passage Submersible ⭐⭐
    final start = pair(item['lat_debut'], item['lng_debut']) ??
        pair(item['start_lat'], item['start_lng'])
        // Bac (x=longitude, y=latitude)
        ??
        pair(item['y_debut_traversee_bac'], item['x_debut_traversee_bac'])
        // Passage Submersible (x=longitude, y=latitude)
        ??
        pair(item['y_debut_passage_submersible'], item['x_debut_passage_submersible']);

    final end = pair(item['lat_fin'], item['lng_fin']) ??
        pair(item['end_lat'], item['end_lng'])
        // Bac
        ??
        pair(item['y_fin_traversee_bac'], item['x_fin_traversee_bac'])
        // Passage Submersible
        ??
        pair(item['y_fin_passage_submersible'], item['x_fin_passage_submersible']);

    if (start != null && end != null) {
      return [
        start,
        end
      ];
    }

    // ---------- 4) GeoJSON optional ----------
    for (final k in [
      'geom',
      'geometry',
      'geojson'
    ]) {
      final v = item[k];
      if (v == null) continue;
      try {
        final obj = (v is String) ? jsonDecode(v) : v;
        if (obj is Map) {
          final type = (obj['type'] ?? '').toString();
          final coords = obj['coordinates'];
          List<dynamic>? line;

          if (type == 'LineString' && coords is List) line = coords;
          if (type == 'MultiLineString' && coords is List && coords.isNotEmpty) {
            line = (coords.first is List) ? coords.first : null;
          }

          if (line != null) {
            final pts = <LatLng>[];
            for (final c in line) {
              if (c is List && c.length >= 2) {
                final lon = toDouble(c[0]);
                final lat = toDouble(c[1]);
                if (lat != null && lon != null) pts.add(LatLng(lat, lon));
              }
            }
            if (pts.length >= 2) return pts;
          }
        }
      } catch (_) {}
    }

    return null;
  }

  /// Retourne le nom de la table SQLite pour la catégorie/type actuellement sélectionnés
  String? _getCurrentTableName() {
    if (selectedCategory == null) return null;
    if (selectedCategory == "Pistes") return 'pistes';
    if (selectedCategory == "Chaussées") return 'chaussees';
    if (selectedType == null) return null;

    final config = InfrastructureConfig.getEntityConfig(selectedCategory!, selectedType!);
    return config?['tableName']?.toString();
  }

  Future<void> _goToMapForItem(Map<String, dynamic> item) async {
    MapFocusTarget? target;

    //  Récupérer la table source (injectée par DataListView ou présente dans l'item)
    final sourceTable = item['source_table']?.toString() ?? item['table']?.toString() ?? item['original_table']?.toString() ?? _getCurrentTableName();

    if (_DBG_FOCUS_POINT) {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('👁️ [FOCUS] _goToMapForItem appelé');
      print('   source_table = $sourceTable');
      print('   selectedCategory = $selectedCategory');
      print('   selectedType = $selectedType');
      print('   item keys = ${item.keys.toList()}');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    }

    //  ÉTAPE 1 : Pour les pistes/chaussées → polyligne
    // SEULEMENT si c'est effectivement une piste ou chaussée
    final bool isPisteOrChaussee = (sourceTable == 'pistes' || sourceTable == 'chaussees' || selectedCategory == "Pistes" || selectedCategory == "Chaussées");

    if (isPisteOrChaussee) {
      final poly = _extractPolyline(item);
      if (poly != null && poly.length >= 2) {
        final st = (item['special_type'] ?? item['type'] ?? '').toString().trim();
        final label = st.isNotEmpty ? st : (item['code_piste'] ?? item['nom'] ?? item['name'] ?? '').toString();

        target = MapFocusTarget.polyline(
          polyline: poly,
          label: label,
          id: item['id']?.toString(),
        );
      }
    }

    //  ÉTAPE 2 : Si pas de polyline (ou pas piste/chaussée) → extraire un point
    if (target == null) {
      LatLng? pt = _extractPointWgs84(item);

      //  ÉTAPE 3 : Fallback - recharger depuis la DB avec la bonne table
      if (pt == null) {
        final id = item['id'] ?? item['ID'] ?? item['Id'];
        final table = sourceTable; //  Utiliser sourceTable au lieu de item['table']

        if (_DBG_FOCUS_POINT) {
          print('⚠️ [FOCUS] Point non trouvé directement, fallback DB: id=$id, table=$table');
        }

        if (id != null && table != null && table.isNotEmpty) {
          try {
            final db = await DatabaseHelper().database;
            final res = await db.query(
              table,
              where: 'id = ?',
              whereArgs: [
                id
              ],
              limit: 1,
            );
            if (res.isNotEmpty) {
              if (_DBG_FOCUS_POINT) {
                print('✅ [FOCUS] Rechargé depuis $table, keys=${res.first.keys.toList()}');
              }
              pt = _extractPointWgs84(res.first);
            }
          } catch (e) {
            if (_DBG_FOCUS_POINT) {
              print('❌ [FOCUS] Erreur requête table=$table: $e');
            }
          }
        }
      }

      if (pt != null) {
        final label = (item['nom'] ?? item['point_name'] ?? item['name'] ?? '').toString();
        if (_DBG_FOCUS_POINT) {
          print('🎯 [FOCUS->MAP] lat=${pt.latitude}, lon=${pt.longitude}, label=$label, id=${item['id']}');
        }
        target = MapFocusTarget.point(point: pt, label: label, id: item['id']?.toString());
      }
    }

    if (target == null) {
      if (!mounted) return;
      if (_DBG_FOCUS_POINT) {
        print('❌ [FOCUS] ÉCHEC TOTAL - Impossible de localiser');
        print('   Données item:');
        item.forEach((key, value) {
          if (key.contains('x_') || key.contains('y_') || key.contains('lat') || key.contains('lng') || key.contains('lon') || key.contains('geom') || key.contains('point')) {
            print('     $key: $value');
          }
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible de localiser cette donnée (pas de géométrie).")),
      );
      return;
    }

    if (!mounted) return;
    HomePage.pendingFocusTarget = target;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _onCategorySelected(String category) {
    setState(() {
      selectedCategory = category;
      selectedType = null;
      currentData = [];
    });
  }

  void _onTypeSelected(String type) {
    setState(() {
      selectedType = type;
      _fetchData();
    });
  }

  void _onBackToCategories() {
    // CAS SPÉCIAL: Pour Pistes/Chaussées, retour direct à l'écran précédent
    if (selectedCategory == "Pistes" || selectedCategory == "Chaussées") {
      Navigator.pop(context); // ← Retour direct sans refresh
    } else {
      // CAS NORMAL: Comportement existant pour autres catégories
      setState(() {
        selectedCategory = null;
        selectedType = null;
        currentData = [];
      });
    }
  }

  void _onBackToTypes() {
    // CAS SPÉCIAL: Pour Pistes/Chaussées, retour direct à l'écran précédent
    if (selectedCategory == "Pistes" || selectedCategory == "Chaussées") {
      Navigator.pop(context); // ← Retour direct sans refresh
    } else {
      // CAS NORMAL: Comportement existant pour autres catégories
      setState(() {
        selectedType = null;
        currentData = [];
      });
    }
  }

  void _showDataViewMessage(String type) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Visualisation des données: $type'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showLegacyRemovedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Le flux legacy pistes/chaussees est en cours de retrait.'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Future<void> _fetchData() async {
    if (selectedCategory == null) return;

    // ✅ Initialiser avec liste vide
    List<Map<String, dynamic>> filteredData = [];

    try {
      if (selectedCategory == "Pistes" || selectedCategory == "Chauss\u00e9es") {
        setState(() => currentData = []);
        return;
      }

      final dbHelper = DatabaseHelper();
      final loginId = await dbHelper.resolveLoginId();
      final config = InfrastructureConfig.getEntityConfig(selectedCategory!, selectedType!);
      final tableName = config?['tableName'] ?? '';

      if (tableName.isEmpty) {
        setState(() => currentData = []);
        return;
      }

      List<Map<String, dynamic>> allData = await dbHelper.getEntities(tableName);

      // FILTRAGE STANDARD POUR POINTS
      if (widget.dataFilter == "unsynced") {
        filteredData = allData.where((item) => (item['synced'] == 0 || item['synced'] == null) && (item['downloaded'] == 0 || item['downloaded'] == null) && item['login_id'] == loginId).toList();
      } else if (widget.dataFilter == "synced") {
        filteredData = allData.where((item) => item['synced'] == 1 && (item['downloaded'] == 0 || item['downloaded'] == null) && item['login_id'] == loginId).toList();
      } else if (widget.dataFilter == "saved") {
        filteredData = allData.where((item) => item['downloaded'] == 1 && item['saved_by_user_id'] == loginId).toList();
      } else {
        filteredData = allData.where((item) => item['login_id'] == loginId || item['saved_by_user_id'] == loginId).toList();
      }

      //  METTRE À JOUR L'ÉTAT
      setState(() => currentData = filteredData);
    } catch (e) {
      print('❌ Erreur récupération $selectedCategory: $e');
      setState(() => currentData = []);
    }
  }

  Future<void> _editItem(Map<String, dynamic> item) async {
    if (selectedCategory == "Pistes") {
      _showLegacyRemovedMessage();
    } else if (selectedCategory == "Chaussées") {
      _showLegacyRemovedMessage();
    } else if (FormLockService.isLocked(item)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.lock_outline, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(FormLockService.lockReason(item))),
            ],
          ),
          backgroundColor: Colors.grey.shade700,
        ),
      );
      return;
    } else if (selectedType == "Zone de Plaine") {
      await _editZoneDePlaine(item);
    } else {
      final config = InfrastructureConfig.getEntityConfig(selectedCategory!, selectedType!);
      final tableName = config?['tableName'] ?? '';

      if (tableName.isEmpty) return;
      final String agentName = item['enqueteur'] ?? 'Agent';
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            // ✅ Ajout du Scaffold ici
            body: PointFormWidget(
              category: selectedCategory!,
              type: selectedType!,
              pointData: item, // ✅ Données à modifier
              onBack: () => Navigator.pop(context),
              onSaved: () {
                _fetchData();
                Navigator.pop(context);
              },
              agentName: agentName,
            ),
          ),
        ),
      );

      if (result != null) {
        _fetchData();
      }
    }
  }

  Future<void> _editZoneDePlaine(Map<String, dynamic> item) async {
    try {
      // Décoder les points du polygone
      List<LatLng> points = [];
      final pointsJson = item['points_json'];
      if (pointsJson != null && pointsJson is String) {
        try {
          final coordsList = jsonDecode(pointsJson) as List;
          points = coordsList.map<LatLng>((c) {
            if (c is List && c.length >= 2) {
              return LatLng(c[1].toDouble(), c[0].toDouble());
            }
            return const LatLng(0, 0);
          }).toList();
          // Retirer le dernier point s'il est identique au premier (polygone fermé)
          if (points.length > 1 && points.first.latitude == points.last.latitude && points.first.longitude == points.last.longitude) {
            points.removeLast();
          }
        } catch (e) {
          print('❌ Erreur décodage points polygone: $e');
        }
      }

      if (points.length < 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Polygone invalide (moins de 3 points)'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PolygonFormPage(
            polygonPoints: points,
            startTime: item['date_creation'] != null ? DateTime.tryParse(item['date_creation']) ?? DateTime.now() : DateTime.now(),
            endTime: DateTime.now(),
            agentName: item['enqueteur'] ?? 'Agent',
            nearestPisteCode: item['code_piste'],
            existingData: item,
          ),
        ),
      );

      if (result != null) {
        _fetchData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zone de Plaine modifiée avec succès')),
        );
      }
    } catch (e) {
      print('❌ Erreur édition zone de plaine: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Future<void> _deleteItem(int id) async {
    if (selectedCategory == "Pistes") {
      _showLegacyRemovedMessage();
    } else if (selectedCategory == "Chaussées") {
      _showLegacyRemovedMessage();
    } else {
      final config = InfrastructureConfig.getEntityConfig(selectedCategory!, selectedType!);
      final tableName = config?['tableName'] ?? '';

      if (tableName.isEmpty) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: const Text('Êtes-vous sûr de vouloir supprimer cet élément ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Supprimer'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        try {
          final dbHelper = DatabaseHelper();

          if (tableName == 'bacs' || tableName == 'passages_submersibles') {
            final db = await dbHelper.database;
            await db.delete(
              'displayed_special_lines',
              where: 'original_id = ? AND original_table = ?',
              whereArgs: [
                id,
                tableName
              ],
            );
            print('🗑️ Ligne spéciale supprimée de displayed_special_lines: $id / $tableName');
          }
          // Sprint 4: deleteDisplayedPoint et deleteEntity remplacés par db.delete direct
          await dbHelper.deleteEntitySrm(
            tableName,
            id,
            recordHistory: true,
          );
          _fetchData(); // Rafraîchir la liste

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Élément supprimé avec succès')),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur lors de la suppression: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F8FF),
      appBar: AppBar(
        title: Text(
          '📊 ${widget.mainCategory}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: _getAppBarColor(),
        elevation: 4,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildContent(),
    );
  }

  Color _getAppBarColor() {
    switch (widget.mainCategory) {
      case "Infrastructures Rurales":
        return const Color(0xFFFF9800);
      case "Ouvrages":
        return const Color(0xFF9C27B0);
      case "Points Critiques":
        return const Color(0xFFF44336);
      case "Enquête":
        return const Color(0xFF212121);
      default:
        return const Color(0xFF1976D2);
    }
  }

  Widget _buildContent() {
    // POUR TOUTES LES CATÉGORIES: même logique
    if (selectedType == null) {
      // Afficher le sélecteur de type
      return _buildTypeSelector();
    } else {
      // Afficher la liste des données
      return _buildDataView();
    }
  }

  Widget _buildTypeSelector() {
    // CAS SPÉCIAL: Pistes/Chaussées - afficher directement
    if (selectedCategory == "Pistes" || selectedCategory == "Chaussées") {
      return _buildDirectTypeView();
    }

    // CAS NORMAL: autres catégories - sélecteur normal
    return TypeSelectorWidget(
      category: selectedCategory!,
      onTypeSelected: _onTypeSelected,
      onBack: _onBackToCategories,
    );
  }

  Widget _buildDirectTypeView() {
    return Column(
      children: [
        // EN-TÊTE UNIFORME pour toutes les catégories
        Container(
          padding: const EdgeInsets.all(16),
          color: _getAppBarColor().withOpacity(0.1),
          child: Row(
            children: [
              // FLÈCHE DE RETOUR UNIFIÉE
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _onBackToCategories, // ← Même comportement partout
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  selectedCategory!,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        // CONTENU SPÉCIFIQUE
        const Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Chargement des données...',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 20),
                CircularProgressIndicator(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDataView() {
    return Column(
      children: [
        // EN-TÊTE UNIFORME avec chemin de navigation
        Container(
          padding: const EdgeInsets.all(16),
          color: _getAppBarColor().withOpacity(0.1),
          child: Row(
            children: [
              // FLÈCHE DE RETOUR - COMPORTEMENT DIFFÉRENTIÉ
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  // COMPORTEMENT DIFFÉRENTIÉ
                  if (selectedCategory == "Pistes" || selectedCategory == "Chaussées") {
                    Navigator.pop(context); // ← Retour direct pour pistes/chaussées
                  } else {
                    _onBackToTypes(); // ← Comportement normal pour autres
                  }
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  selectedCategory == "Pistes" || selectedCategory == "Chaussées"
                      ? selectedCategory! // ← Juste le nom pour pistes/chaussées
                      : '$selectedCategory > $selectedType', // ← Chemin complet pour autres
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _fetchData,
              ),
            ],
          ),
        ),

        // LISTE DES DONNÉES
        Expanded(
          child: DataListView(
            data: currentData,
            entityType: selectedType!,
            dataFilter: widget.dataFilter,
            tableName: _getCurrentTableName(),
            onEdit: _editItem,
            onDelete: _deleteItem,
            onView: (item) => _goToMapForItem(item),
          ),
        ),
      ],
    );
  }
}
