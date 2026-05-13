// lib/screens/data/srm_data_status_page.dart
// Sprint 6 : Liste donnees SRM + filtration avancee
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:latlong2/latlong.dart';
import '../../core/config/srm_config.dart';
import '../../data/local/database_helper.dart';
import '../../services/formulaire_config_mobile_service.dart';
import '../../services/projection_service.dart';
import '../../services/srm_status_flags.dart';
import '../../widgets/lists/data_list_view.dart';
import '../../widgets/forms/srm_point_form_widget.dart';
import '../forms/srm_ligne_form_page.dart';
import '../forms/polygon_form_page.dart';
import '../home/home_page.dart';

class SrmDataStatusPage extends StatefulWidget {
  final String title;
  final String dataFilter;
  final bool isOnline;
  final String agentName;

  const SrmDataStatusPage({
    super.key,
    required this.title,
    required this.dataFilter,
    required this.isOnline,
    required this.agentName,
  });

  @override
  State<SrmDataStatusPage> createState() => _SrmDataStatusPageState();
}

class _SrmDataStatusPageState extends State<SrmDataStatusPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  bool _isLoading = true;
  List<Map<String, dynamic>> _allData = [];
  List<Map<String, dynamic>> _filteredData = [];

  List<LatLng> _decodeGeometryPoints(dynamic rawPoints) {
    if (rawPoints == null) return const [];

    try {
      final decoded = rawPoints is String ? jsonDecode(rawPoints) : rawPoints;
      final decodedPoints = _latLngsFromDecodedGeometry(decoded);
      if (decodedPoints.isNotEmpty) return decodedPoints;
    } catch (_) {
      // La valeur peut etre du WKT ou une ancienne chaine "lat/lon".
    }

    if (rawPoints is! String) return const [];
    final wktPoints = _decodeWktPoints(rawPoints);
    if (wktPoints.isNotEmpty) return wktPoints;

    return RegExp(r'lat:\s*([-0-9.]+),\s*lon:\s*([-0-9.]+)')
        .allMatches(rawPoints)
        .map((match) {
          final lat = double.tryParse(match.group(1) ?? '');
          final lon = double.tryParse(match.group(2) ?? '');
          if (lat == null || lon == null) return null;
          return LatLng(lat, lon);
        })
        .whereType<LatLng>()
        .toList();
  }

  List<LatLng> _latLngsFromDecodedGeometry(dynamic decoded) {
    if (decoded is Map) {
      final geometry = decoded['geometry'];
      if (geometry is Map) {
        return _latLngsFromDecodedGeometry(geometry);
      }

      final directPoint = _latLngFromCoordinate(decoded);
      if (directPoint != null) return [directPoint];

      final type = decoded['type']?.toString().toLowerCase();
      final coordinates = decoded['coordinates'];
      if (type == 'point') {
        final point = _latLngFromCoordinate(coordinates);
        return point == null ? const [] : [point];
      }
      if (type == 'linestring' || type == 'multipoint') {
        return _latLngsFromDecodedGeometry(coordinates);
      }
      if (type == 'multilinestring' &&
          coordinates is List &&
          coordinates.isNotEmpty) {
        return _latLngsFromDecodedGeometry(coordinates.first);
      }
      if (type == 'polygon' && coordinates is List && coordinates.isNotEmpty) {
        return _latLngsFromDecodedGeometry(coordinates.first);
      }
      if (type == 'multipolygon' &&
          coordinates is List &&
          coordinates.isNotEmpty) {
        final firstPolygon = coordinates.first;
        if (firstPolygon is List && firstPolygon.isNotEmpty) {
          return _latLngsFromDecodedGeometry(firstPolygon.first);
        }
      }
      return const [];
    }

    if (decoded is List) {
      final points = <LatLng>[];
      for (final coord in decoded) {
        final point = _latLngFromCoordinate(coord);
        if (point != null) {
          points.add(point);
        }
      }
      return points;
    }

    return const [];
  }

  LatLng? _latLngFromCoordinate(dynamic coord) {
    if (coord is Map) {
      final lat = _toDouble(coord['lat'] ?? coord['latitude']);
      final lng = _toDouble(coord['lon'] ?? coord['lng'] ?? coord['longitude']);
      if (lat != null && lng != null) return LatLng(lat, lng);

      final x = _toDouble(coord['x']);
      final y = _toDouble(coord['y']);
      if (x != null && y != null) {
        return _toWgs84LatLng(x: x, y: y);
      }
    }

    if (coord is List && coord.length >= 2) {
      final x = _toDouble(coord[0]);
      final y = _toDouble(coord[1]);
      if (x == null || y == null) return null;
      return _toWgs84LatLng(x: x, y: y);
    }

    return null;
  }

  List<LatLng> _decodeWktPoints(String value) {
    final text = value.trim();
    final upper = text.toUpperCase();
    if (!upper.startsWith('POINT') &&
        !upper.startsWith('LINESTRING') &&
        !upper.startsWith('POLYGON') &&
        !upper.startsWith('MULTILINESTRING') &&
        !upper.startsWith('MULTIPOLYGON')) {
      return const [];
    }

    return RegExp(r'(-?\d+(?:\.\d+)?)\s+(-?\d+(?:\.\d+)?)')
        .allMatches(text)
        .map((match) {
          final x = double.tryParse(match.group(1) ?? '');
          final y = double.tryParse(match.group(2) ?? '');
          if (x == null || y == null) return null;
          return _toWgs84LatLng(x: x, y: y);
        })
        .whereType<LatLng>()
        .toList();
  }

  LatLng _toWgs84LatLng({required double x, required double y}) {
    if (x.abs() <= 180 && y.abs() <= 90) {
      return LatLng(y, x);
    }

    final projected = ProjectionService().merchichToWgs84(x: x, y: y);
    return LatLng(projected.latitude, projected.longitude);
  }

  Future<void> _editItem(Map<String, dynamic> item) async {
    final metier = item['source_metier']?.toString();
    final entityType = item['source_entity']?.toString();
    final geoType = item['geometry_type']?.toString() ?? 'Point';
    if (metier == null || entityType == null) return;

    if (geoType == 'LineString') {
      final points = _decodeGeometryPoints(item['points_json']);
      if (points.length < 2) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ligne invalide'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SrmLigneFormPage(
            metier: metier,
            entityType: entityType,
            displayTitle: item['source_title']?.toString(),
            linePoints: points,
            agentName: widget.agentName,
            existingData: item,
          ),
        ),
      );
    } else if (geoType == 'Polygon') {
      List<LatLng> points = [];
      final pointsJson = item['points_json'];
      if (pointsJson is String && pointsJson.isNotEmpty) {
        try {
          final raw = jsonDecode(pointsJson) as List;
          points = raw.map<LatLng>((coord) {
            if (coord is Map) {
              return LatLng(
                ((coord['lat'] ?? 0) as num).toDouble(),
                ((coord['lon'] ?? 0) as num).toDouble(),
              );
            }
            if (coord is List && coord.length >= 2) {
              return LatLng(
                (coord[1] as num).toDouble(),
                (coord[0] as num).toDouble(),
              );
            }
            return const LatLng(0, 0);
          }).toList();
          if (points.length > 1 &&
              points.first.latitude == points.last.latitude &&
              points.first.longitude == points.last.longitude) {
            points.removeLast();
          }
        } catch (_) {}
      }

      if (points.length < 3) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Polygone invalide'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PolygonFormPage(
            polygonPoints: points,
            startTime: item['date_collecte'] != null
                ? DateTime.tryParse(item['date_collecte'].toString()) ??
                    DateTime.now()
                : DateTime.now(),
            endTime: DateTime.now(),
            agentName: widget.agentName,
            existingData: item,
            metier: metier,
            entityType: entityType,
            displayTitle: item['source_title']?.toString(),
          ),
        ),
      );
    } else {
      final latLng = _resolveEditablePointLatLng(
        item: item,
        metier: metier,
        entityType: entityType,
      );

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            body: SrmPointFormWidget(
              metier: metier,
              entityType: entityType,
              displayTitle: item['source_title']?.toString(),
              latitude: latLng?.latitude ?? 0.0,
              longitude: latLng?.longitude ?? 0.0,
              altitude: (item['altitude_gps'] as num?)?.toDouble(),
              agentName: widget.agentName,
              existingData: item,
              onSaved: () {
                _loadData();
                Navigator.pop(context);
              },
              onCancel: () => Navigator.pop(context),
            ),
          ),
        ),
      );
    }

    if (mounted) {
      _loadData();
    }
  }

  LatLng? _resolveEditablePointLatLng({
    required Map<String, dynamic> item,
    required String metier,
    required String entityType,
  }) {
    final latitude = (item['latitude_gps'] as num?)?.toDouble();
    final longitude = (item['longitude_gps'] as num?)?.toDouble();
    if (latitude != null && longitude != null) {
      return LatLng(latitude, longitude);
    }

    final directLat = _toDouble(item['lat'] ?? item['latitude']);
    final directLng =
        _toDouble(item['lon'] ?? item['lng'] ?? item['longitude']);
    if (directLat != null && directLng != null) {
      return LatLng(directLat, directLng);
    }

    final schema = item['source_schema']?.toString().trim().isNotEmpty == true
        ? item['source_schema'].toString().trim()
        : SrmConfig.getSchema(metier, entityType);
    if (schema != null && schema.isNotEmpty) {
      final x = _toDouble(item['${schema}_coor_x']);
      final y = _toDouble(item['${schema}_coor_y']);
      if (x != null && y != null) {
        return _toWgs84LatLng(x: x, y: y);
      }
    }

    for (final key in ['points_json', 'geometry_geojson', 'geometry', 'geom']) {
      final points = _decodeGeometryPoints(item[key]);
      if (points.isNotEmpty) return points.first;
    }

    return null;
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim());
  }

  List<LatLng> _resolveStoredGeometryPoints(Map<String, dynamic> item) {
    for (final key in ['points_json', 'geometry_geojson', 'geometry', 'geom']) {
      final points = _decodeGeometryPoints(item[key]);
      if (points.isNotEmpty) return points;
    }
    return const [];
  }

  List<LatLng> _resolveLineEndpointPoints(Map<String, dynamic> item) {
    const endpointGroups = [
      ['start_lng', 'start_lat', 'end_lng', 'end_lat'],
      ['x_debut', 'y_debut', 'x_fin', 'y_fin'],
      ['lon_debut', 'lat_debut', 'lon_fin', 'lat_fin'],
      ['longitude_debut', 'latitude_debut', 'longitude_fin', 'latitude_fin'],
    ];

    for (final group in endpointGroups) {
      final x1 = _toDouble(item[group[0]]);
      final y1 = _toDouble(item[group[1]]);
      final x2 = _toDouble(item[group[2]]);
      final y2 = _toDouble(item[group[3]]);
      if (x1 != null && y1 != null && x2 != null && y2 != null) {
        return [
          _toWgs84LatLng(x: x1, y: y1),
          _toWgs84LatLng(x: x2, y: y2),
        ];
      }
    }

    return const [];
  }

  String _buildFocusLabel(Map<String, dynamic> item) {
    final title = item['display_title']?.toString().trim();
    if (title != null && title.isNotEmpty) return title;

    final entity = item['source_entity']?.toString().trim();
    if (entity != null && entity.isNotEmpty) return entity;

    final table = item['source_table']?.toString().trim();
    if (table != null && table.isNotEmpty) return table;

    return 'Objet';
  }

  MapFocusTarget? _buildMapFocusTarget(Map<String, dynamic> item) {
    final geoType = item['geometry_type']?.toString() ?? 'Point';
    final label = _buildFocusLabel(item);

    if (geoType == 'LineString') {
      var points = _resolveStoredGeometryPoints(item);
      if (points.length < 2) {
        points = _resolveLineEndpointPoints(item);
      }
      if (points.length < 2) return null;
      return MapFocusTarget.polyline(polyline: points, label: label);
    }

    if (geoType == 'Polygon') {
      final points = [..._resolveStoredGeometryPoints(item)];
      if (points.length < 3) return null;
      if (points.first.latitude != points.last.latitude ||
          points.first.longitude != points.last.longitude) {
        points.add(points.first);
      }
      return MapFocusTarget.polyline(polyline: points, label: label);
    }

    final point = _resolveEditablePointLatLng(
      item: item,
      metier: item['source_metier']?.toString() ?? '',
      entityType: item['source_entity']?.toString() ?? '',
    );
    if (point == null) return null;
    return MapFocusTarget.point(point: point, label: label);
  }

  void _goToMapForItem(Map<String, dynamic> item) {
    final target = _buildMapFocusTarget(item);
    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucune geometrie exploitable pour cet objet'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    HomePage.pendingFocusTarget = target;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // Filtres actifs
  String? _filterMetier; // null = tous
  String? _filterGeometrie; // 'Point' | 'LineString' | 'Polygon' | null
  String? _filterEntite; // nom entite, null = tous
  DateTimeRange? _filterDateRange;
  bool? _filterAnomalie; // null = tous, true = avec, false = sans
  bool? _filterIncomplet; // null = tous, true = incomplets, false = complets
  bool _filtersVisible = false;

  // Listes pour les dropdowns
  List<String> _metiers = [];
  List<String> _entitesDisponibles = [];
  Map<String, String> _entityTitlesByEntity = {};
  Map<String, List<String>> _entitiesByMetier = {};

  @override
  void initState() {
    super.initState();
    _metiers = SrmConfig.getMetiers();
    _loadData();
  }

  // Helpers
  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return null;
    }
  }

  DateTime? _sortDateFor(Map<String, dynamic> item) {
    return _parseDate(item['date_sync']) ??
        _parseDate(item['date_collecte']) ??
        _parseDate(item['updated_at']) ??
        _parseDate(item['created_at']) ??
        _parseDate(item['date_creation']);
  }

  bool _matchesCurrentContext(Map<String, dynamic> item) {
    return true;
  }

  bool _matchesStatusFilter(Map<String, dynamic> item, int? loginId) {
    final synced = _toInt(item['synced']) == 1;
    final downloaded = _toInt(item['downloaded']) == 1;
    final creatorId = _toInt(item['id_agent_crea']);

    if (!_matchesCurrentContext(item)) return false;

    switch (widget.dataFilter) {
      case 'unsynced':
        return !synced &&
            !downloaded &&
            (loginId == null || creatorId == loginId);
      case 'synced':
        if (loginId == null) {
          return synced && !downloaded;
        }
        return synced && creatorId == loginId;
      case 'saved':
        if (loginId == null) {
          return downloaded;
        }
        return downloaded && creatorId != loginId;
      default:
        return true;
    }
  }

  String _buildDisplayTitle(String entity, Map<String, dynamic> row) {
    const preferredKeys = [
      'nom',
      'code',
      'ep_num',
      'reference',
      'type',
      'type_objet',
      'type_regard',
      'type_conduite',
      'type_station',
      'type_bassin',
    ];
    for (final key in preferredKeys) {
      final raw = row[key]?.toString().trim();
      if (raw != null && raw.isNotEmpty && raw.toLowerCase() != 'null') {
        return '$entity • $raw';
      }
    }
    return entity;
  }

  // Chargement donnees
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final loginId = await _dbHelper.resolveLoginId();
      final items = <Map<String, dynamic>>[];
      final entityTitlesByEntity = <String, String>{};
      final entitiesByMetier = <String, List<String>>{};
      final formulaireConfigService = FormulaireConfigMobileService();

      for (final metier in SrmConfig.getMetiers()) {
        final entities = await _dataEntitiesForMetier(
          metier,
          formulaireConfigService,
        );
        if (entities.isEmpty) {
          continue;
        }
        entitiesByMetier[metier] = [
          for (final entity in entities) entity.entityType,
        ];

        for (final entity in entities) {
          final tableName = entity.tableName.trim();
          if (tableName.isEmpty) continue;
          final entityTitle = entity.titleApp.trim().isNotEmpty
              ? entity.titleApp.trim()
              : entity.entityType;
          entityTitlesByEntity[entity.entityType] = entityTitle;

          final rows = await _dbHelper.getEntitiesSrm(tableName);
          for (final row in rows) {
            if (!_matchesStatusFilter(row, loginId)) continue;

            final item = Map<String, dynamic>.from(row);
            item['source_table'] = tableName;
            item['source_schema'] = entity.schema;
            item['source_metier'] = metier;
            item['source_entity'] = entity.entityType;
            item['source_title'] = entityTitle;
            item['display_title'] = _buildDisplayTitle(entityTitle, item);
            item['geometry_type'] = _geometryTypeForEntity(entity);

            items.add(item);
          }
        }
      }

      // Tri par date desc
      items.sort((a, b) {
        final da = _sortDateFor(a);
        final db = _sortDateFor(b);
        if (da != null && db != null) return db.compareTo(da);
        if (da != null) return -1;
        if (db != null) return 1;
        return _toInt(b['id']).compareTo(_toInt(a['id']));
      });

      if (!mounted) return;
      setState(() {
        _allData = items;
        _entityTitlesByEntity = entityTitlesByEntity;
        _entitiesByMetier = entitiesByMetier;
        _metiers = entitiesByMetier.keys.toList();
        if (_filterMetier != null && !_metiers.contains(_filterMetier)) {
          _filterMetier = null;
          _filterEntite = null;
          _entitesDisponibles = [];
        } else {
          _updateEntitesDisponibles();
        }
        _filteredData = _filterItems(items);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _allData = [];
        _filteredData = [];
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de chargement : $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<List<FormulaireConfigMobileEntity>> _dataEntitiesForMetier(
    String metier,
    FormulaireConfigMobileService service,
  ) async {
    final entities = <FormulaireConfigMobileEntity>[];
    final seenTables = <String>{};

    for (final geometryFilter in const ['point', 'line', 'polygon']) {
      final configured = await service.getMobileEntities(
        mobileMetier: metier,
        geometryFilter: geometryFilter,
        refreshIfEmpty: false,
      );
      for (final entity in configured) {
        final key = '${entity.schema}.${entity.tableName}'.toLowerCase();
        if (seenTables.add(key)) {
          entities.add(entity);
        }
      }
    }

    return entities;
  }

  String _geometryTypeForEntity(FormulaireConfigMobileEntity entity) {
    if (entity.isPolygon) return 'Polygon';
    if (entity.isLine) return 'LineString';
    return 'Point';
  }

  List<Map<String, dynamic>> _filterItems(
    List<Map<String, dynamic>> source,
  ) {
    List<Map<String, dynamic>> result = List.from(source);

    // Filtre metier
    if (_filterMetier != null) {
      result = result
          .where((item) => item['source_metier'] == _filterMetier)
          .toList();
    }

    // Filtre geometrie
    if (_filterGeometrie != null) {
      result = result
          .where((item) => item['geometry_type'] == _filterGeometrie)
          .toList();
    }

    // Filtre entite
    if (_filterEntite != null) {
      result = result
          .where((item) => item['source_entity'] == _filterEntite)
          .toList();
    }

    // Filtre date
    if (_filterDateRange != null) {
      result = result.where((item) {
        final d = _sortDateFor(item);
        if (d == null) return false;
        return d.isAfter(
                _filterDateRange!.start.subtract(const Duration(seconds: 1))) &&
            d.isBefore(_filterDateRange!.end.add(const Duration(days: 1)));
      }).toList();
    }

    // Filtre anomalie
    if (_filterAnomalie != null) {
      result = result
          .where((item) => SrmStatusFlags.hasAnomalie(item) == _filterAnomalie)
          .toList();
    }

    // Filtre objet incomplet
    if (_filterIncomplet != null) {
      result = result
          .where(
              (item) => SrmStatusFlags.hasIncomplet(item) == _filterIncomplet)
          .toList();
    }

    return result;
  }

  // Mise a jour entites disponibles selon metier choisi
  void _updateEntitesDisponibles() {
    if (_filterMetier == null) {
      _entitesDisponibles = [];
      _filterEntite = null;
    } else {
      _entitesDisponibles = _entitiesByMetier[_filterMetier!] ?? [];
      if (!_entitesDisponibles.contains(_filterEntite)) {
        _filterEntite = null;
      }
    }
  }

  // Reinitialiser filtres
  void _resetFilters() {
    setState(() {
      _filterMetier = null;
      _filterGeometrie = null;
      _filterEntite = null;
      _filterDateRange = null;
      _filterAnomalie = null;
      _filterIncomplet = null;
      _entitesDisponibles = [];
      _filteredData = _filterItems(_allData);
    });
  }

  int get _activeFiltersCount {
    int count = 0;
    if (_filterMetier != null) count++;
    if (_filterGeometrie != null) count++;
    if (_filterEntite != null) count++;
    if (_filterDateRange != null) count++;
    if (_filterAnomalie != null) count++;
    if (_filterIncomplet != null) count++;
    return count;
  }

  // Selection plage date
  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _filterDateRange,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1B4F72),
            ),
          ),
          child: child!,
        );
      },
    );
    if (range != null) {
      setState(() {
        _filterDateRange = range;
        _filteredData = _filterItems(_allData);
      });
    }
  }

  // Build
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F8FF),
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1976D2),
        elevation: 4,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Bouton filtres avec badge
          Stack(
            children: [
              IconButton(
                icon: Icon(
                  _filtersVisible ? Icons.filter_list_off : Icons.filter_list,
                  color: Colors.white,
                ),
                tooltip: 'Filtres',
                onPressed: () =>
                    setState(() => _filtersVisible = !_filtersVisible),
              ),
              if (_activeFiltersCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$_activeFiltersCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          // Bandeau compteur
          _buildCounterBanner(),

          // Panneau filtres
          if (_filtersVisible) _buildFilterPanel(),

          // Liste
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : DataListView(
                    data: _filteredData,
                    entityType: widget.title,
                    dataFilter: widget.dataFilter,
                    onEdit: _editItem,
                    onDelete: null,
                    onView: _goToMapForItem,
                    tableName: null,
                  ),
          ),
        ],
      ),
    );
  }

  // Bandeau compteur
  Widget _buildCounterBanner() {
    final total = _allData.length;
    final shown = _filteredData.length;
    final isFiltered = _activeFiltersCount > 0;

    return Container(
      color: const Color(0xFF1976D2).withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            size: 16,
            color: Color(0xFF1976D2),
          ),
          const SizedBox(width: 8),
          Text(
            isFiltered
                ? '$shown / $total objet${total > 1 ? 's' : ''} (filtrés)'
                : '$total objet${total > 1 ? 's' : ''}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1976D2),
            ),
          ),
          const Spacer(),
          if (isFiltered)
            TextButton.icon(
              onPressed: _resetFilters,
              icon: const Icon(Icons.clear, size: 14),
              label:
                  const Text('Réinitialiser', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
        ],
      ),
    );
  }

  // Panneau filtres
  Widget _buildFilterPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre filtres
          Row(
            children: [
              const Icon(Icons.tune, size: 16, color: Color(0xFF1976D2)),
              const SizedBox(width: 6),
              const Text(
                'Filtres',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1976D2),
                ),
              ),
              const Spacer(),
              if (_activeFiltersCount > 0)
                TextButton(
                  onPressed: _resetFilters,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                  ),
                  child: const Text('Tout effacer',
                      style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Ligne 1 : Metier + Geometrie
          Row(
            children: [
              Expanded(child: _buildMetierDropdown()),
              const SizedBox(width: 8),
              Expanded(child: _buildGeometrieDropdown()),
            ],
          ),
          const SizedBox(height: 8),

          // Ligne 2 : Entite (si metier choisi)
          if (_filterMetier != null) ...[
            _buildEntiteDropdown(),
            const SizedBox(height: 8),
          ],

          // Ligne 3 : Anomalie + Incomplet
          Row(
            children: [
              Expanded(child: _buildAnomalieDropdown()),
              const SizedBox(width: 8),
              Expanded(child: _buildIncompletDropdown()),
            ],
          ),
          const SizedBox(height: 8),

          // Ligne 4 : Date
          _buildDateFilter(),
        ],
      ),
    );
  }

  // Filtre anomalie
  Widget _buildAnomalieDropdown() {
    const accent = Color(0xFFE74C3C);
    final isActive = _filterAnomalie != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Anomalies',
            style: TextStyle(fontSize: 12, color: Color(0xFF666666))),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: isActive ? accent : const Color(0xFFDDDDDD),
              width: isActive ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: isActive ? accent.withValues(alpha: 0.06) : Colors.white,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<bool?>(
              value: _filterAnomalie,
              isExpanded: true,
              hint: const Text('Tous',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              items: const [
                DropdownMenuItem<bool?>(
                  value: null,
                  child: Text('Tous', style: TextStyle(fontSize: 13)),
                ),
                DropdownMenuItem<bool?>(
                  value: true,
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 16, color: accent),
                      SizedBox(width: 6),
                      Text('Avec anomalies', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
                DropdownMenuItem<bool?>(
                  value: false,
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 16, color: Color(0xFF27AE60)),
                      SizedBox(width: 6),
                      Text('Sans anomalies', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ],
              onChanged: (val) {
                setState(() {
                  _filterAnomalie = val;
                  _filteredData = _filterItems(_allData);
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  // Filtre objet incomplet
  Widget _buildIncompletDropdown() {
    const accent = Color(0xFFFF9800);
    final isActive = _filterIncomplet != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Saisie',
            style: TextStyle(fontSize: 12, color: Color(0xFF666666))),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: isActive ? accent : const Color(0xFFDDDDDD),
              width: isActive ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: isActive ? accent.withValues(alpha: 0.06) : Colors.white,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<bool?>(
              value: _filterIncomplet,
              isExpanded: true,
              hint: const Text('Tous',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              items: const [
                DropdownMenuItem<bool?>(
                  value: null,
                  child: Text('Tous', style: TextStyle(fontSize: 13)),
                ),
                DropdownMenuItem<bool?>(
                  value: true,
                  child: Row(
                    children: [
                      Icon(Icons.edit_note, size: 16, color: accent),
                      SizedBox(width: 6),
                      Text('Incomplets', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
                DropdownMenuItem<bool?>(
                  value: false,
                  child: Row(
                    children: [
                      Icon(Icons.task_alt, size: 16, color: Color(0xFF27AE60)),
                      SizedBox(width: 6),
                      Text('Complets', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ],
              onChanged: (val) {
                setState(() {
                  _filterIncomplet = val;
                  _filteredData = _filterItems(_allData);
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  // Filtre metier
  Widget _buildMetierDropdown() {
    final metierColors = {
      'Eau Potable': const Color(0xFF1976D2),
      'Assainissement': const Color(0xFF27AE60),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Métier',
            style: TextStyle(fontSize: 12, color: Color(0xFF666666))),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: _filterMetier != null
                  ? Color(SrmConfig.getMetierColor(_filterMetier!))
                  : const Color(0xFFDDDDDD),
              width: _filterMetier != null ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: _filterMetier != null
                ? Color(SrmConfig.getMetierColor(_filterMetier!))
                    .withValues(alpha: 0.06)
                : Colors.white,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: _filterMetier,
              isExpanded: true,
              hint: const Text('Tous',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child:
                      Text('Tous les métiers', style: TextStyle(fontSize: 13)),
                ),
                ..._metiers.map((m) => DropdownMenuItem<String>(
                      value: m,
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: metierColors[m] ?? Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(m, style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    )),
              ],
              onChanged: (val) {
                setState(() {
                  _filterMetier = val;
                  _updateEntitesDisponibles();
                  _filteredData = _filterItems(_allData);
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  // Filtre geometrie
  Widget _buildGeometrieDropdown() {
    final geoOptions = {
      'Point': Icons.place,
      'LineString': Icons.show_chart,
      'Polygon': Icons.pentagon_outlined,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Géométrie',
            style: TextStyle(fontSize: 12, color: Color(0xFF666666))),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: _filterGeometrie != null
                  ? const Color(0xFF8E44AD)
                  : const Color(0xFFDDDDDD),
              width: _filterGeometrie != null ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: _filterGeometrie != null
                ? const Color(0xFF8E44AD).withValues(alpha: 0.06)
                : Colors.white,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: _filterGeometrie,
              isExpanded: true,
              hint: const Text('Tous',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Tous les types', style: TextStyle(fontSize: 13)),
                ),
                ...geoOptions.entries.map((e) => DropdownMenuItem<String>(
                      value: e.key,
                      child: Row(
                        children: [
                          Icon(e.value,
                              size: 16, color: const Color(0xFF8E44AD)),
                          const SizedBox(width: 6),
                          Text(
                            e.key == 'LineString' ? 'Ligne' : e.key,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    )),
              ],
              onChanged: (val) {
                setState(() {
                  _filterGeometrie = val;
                  _filteredData = _filterItems(_allData);
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  // Filtre entite
  Widget _buildEntiteDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Type d'objet",
            style: TextStyle(fontSize: 12, color: Color(0xFF666666))),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: _filterEntite != null
                  ? const Color(0xFF1976D2)
                  : const Color(0xFFDDDDDD),
              width: _filterEntite != null ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: _filterEntite != null
                ? const Color(0xFF1976D2).withValues(alpha: 0.06)
                : Colors.white,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: _filterEntite,
              isExpanded: true,
              hint: const Text('Tous les types',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Tous les types', style: TextStyle(fontSize: 13)),
                ),
                ..._entitesDisponibles.map((e) => DropdownMenuItem<String>(
                      value: e,
                      child: Text(
                        _entityTitlesByEntity[e] ?? e,
                        style: const TextStyle(fontSize: 13),
                      ),
                    )),
              ],
              onChanged: (val) {
                setState(() {
                  _filterEntite = val;
                  _filteredData = _filterItems(_allData);
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  // Filtre date
  Widget _buildDateFilter() {
    final hasDate = _filterDateRange != null;
    return GestureDetector(
      onTap: _pickDateRange,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: hasDate ? const Color(0xFFE74C3C) : const Color(0xFFDDDDDD),
            width: hasDate ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: hasDate
              ? const Color(0xFFE74C3C).withValues(alpha: 0.06)
              : Colors.white,
        ),
        child: Row(
          children: [
            Icon(
              Icons.date_range,
              size: 18,
              color:
                  hasDate ? const Color(0xFFE74C3C) : const Color(0xFF666666),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hasDate
                    ? '${_formatDate(_filterDateRange!.start)} → ${_formatDate(_filterDateRange!.end)}'
                    : 'Filtrer par date de collecte',
                style: TextStyle(
                  fontSize: 13,
                  color: hasDate ? const Color(0xFFE74C3C) : Colors.grey,
                  fontWeight: hasDate ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (hasDate)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _filterDateRange = null;
                    _filteredData = _filterItems(_allData);
                  });
                },
                child:
                    const Icon(Icons.clear, size: 16, color: Color(0xFFE74C3C)),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
