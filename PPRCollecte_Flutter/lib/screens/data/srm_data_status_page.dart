// lib/screens/data/srm_data_status_page.dart
// Sprint 6 â€” Liste donnÃ©es SRM + filtration avancÃ©e
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:latlong2/latlong.dart';
import '../../core/config/srm_config.dart';
import '../../data/local/database_helper.dart';
import '../../data/remote/api_service.dart';
import '../../widgets/lists/data_list_view.dart';
import '../../widgets/forms/srm_point_form_widget.dart';
import '../forms/srm_ligne_form_page.dart';
import '../forms/polygon_form_page.dart';

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

  Future<void> _editItem(Map<String, dynamic> item) async {
    final metier = item['source_metier']?.toString();
    final entityType = item['source_entity']?.toString();
    final geoType = item['geometry_type']?.toString() ?? 'Point';
    if (metier == null || entityType == null) return;

    if (geoType == 'LineString') {
      List<LatLng> points = [];
      final pointsJson = item['points_json'];
      if (pointsJson is String && pointsJson.isNotEmpty) {
        try {
          final raw = jsonDecode(pointsJson) as List;
          points = raw.map<LatLng>((coord) {
            if (coord is Map) {
              return LatLng(
                (coord['lat'] as num).toDouble(),
                (coord['lon'] as num).toDouble(),
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
        } catch (_) {}
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SrmLigneFormPage(
            metier: metier,
            entityType: entityType,
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
          ),
        ),
      );
    } else {
      final lat = (item['latitude_gps'] as num?)?.toDouble() ?? 0.0;
      final lon = (item['longitude_gps'] as num?)?.toDouble() ?? 0.0;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            body: SrmPointFormWidget(
              metier: metier,
              entityType: entityType,
              latitude: lat,
              longitude: lon,
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

  // â”€â”€ Filtres actifs â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  String? _filterMetier;       // null = tous
  String? _filterGeometrie;    // 'Point' | 'LineString' | 'Polygon' | null
  String? _filterEntite;       // nom entitÃ©, null = tous
  DateTimeRange? _filterDateRange;
  bool _filtersVisible = false;

  // Listes pour les dropdowns
  List<String> _metiers = [];
  List<String> _entitesDisponibles = [];

  @override
  void initState() {
    super.initState();
    _metiers = SrmConfig.getMetiers();
    _loadData();
  }

  // â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
    final currentProjetId = ApiService.currentProjetId;
    final rowProjetId = _toInt(item['id_projet']);
    final rowMissionId = _toInt(item['id_mission']);
    if (currentProjetId != null && rowProjetId != currentProjetId) return false;
    return true;
  }

  bool _matchesStatusFilter(Map<String, dynamic> item, int? loginId) {
    final synced = _toInt(item['synced']) == 1;
    final downloaded = _toInt(item['downloaded']) == 1;
    final creatorId = _toInt(item['id_agent_crea']);

    if (!_matchesCurrentContext(item)) return false;

    switch (widget.dataFilter) {
      case 'unsynced':
        return !synced && !downloaded && (loginId == null || creatorId == loginId);
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
      'nom', 'code', 'ep_num', 'ep_numero', 'reference', 'type',
      'type_objet', 'type_regard', 'type_conduite', 'type_station',
      'type_poste', 'type_support', 'type_bassin',
    ];
    for (final key in preferredKeys) {
      final raw = row[key]?.toString().trim();
      if (raw != null && raw.isNotEmpty && raw.toLowerCase() != 'null') {
        return '$entity • $raw';
      }
    }
    return entity;
  }

  // â”€â”€ Chargement donnÃ©es â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final loginId = await _dbHelper.resolveLoginId();
      final items = <Map<String, dynamic>>[];

      for (final metier in SrmConfig.getMetiers()) {
        for (final entity in SrmConfig.getEntitiesForMetier(metier)) {
          final tableName = SrmConfig.getTableName(metier, entity);
          if (tableName == null || tableName.isEmpty) continue;

          final rows = await _dbHelper.getEntitiesSrm(tableName);
          for (final row in rows) {
            if (!_matchesStatusFilter(row, loginId)) continue;

            final item = Map<String, dynamic>.from(row);
            item['source_table'] = tableName;
            item['source_metier'] = metier;
            item['source_entity'] = entity;
            item['display_title'] = _buildDisplayTitle(entity, item);

            // GÃ©omÃ©trie depuis config
            final config = SrmConfig.getEntityConfig(metier, entity);
            item['geometry_type'] =
                config?['geometryType'] as String? ?? 'Point';

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
        _applyFilters();
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

  // â”€â”€ Application des filtres â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _applyFilters() {
    List<Map<String, dynamic>> result = List.from(_allData);

    // Filtre mÃ©tier
    if (_filterMetier != null) {
      result = result
          .where((item) => item['source_metier'] == _filterMetier)
          .toList();
    }

    // Filtre gÃ©omÃ©trie
    if (_filterGeometrie != null) {
      result = result
          .where((item) => item['geometry_type'] == _filterGeometrie)
          .toList();
    }

    // Filtre entitÃ©
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
        return d.isAfter(_filterDateRange!.start
                .subtract(const Duration(seconds: 1))) &&
            d.isBefore(
                _filterDateRange!.end.add(const Duration(days: 1)));
      }).toList();
    }

    setState(() => _filteredData = result);
  }

  // â”€â”€ Mise Ã  jour entitÃ©s disponibles selon mÃ©tier choisi â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _updateEntitesDisponibles() {
    if (_filterMetier == null) {
      _entitesDisponibles = [];
      _filterEntite = null;
    } else {
      _entitesDisponibles =
          SrmConfig.getEntitiesForMetier(_filterMetier!);
      if (!_entitesDisponibles.contains(_filterEntite)) {
        _filterEntite = null;
      }
    }
  }

  // â”€â”€ RÃ©initialiser filtres â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _resetFilters() {
    setState(() {
      _filterMetier = null;
      _filterGeometrie = null;
      _filterEntite = null;
      _filterDateRange = null;
      _entitesDisponibles = [];
      _applyFilters();
    });
  }

  int get _activeFiltersCount {
    int count = 0;
    if (_filterMetier != null) count++;
    if (_filterGeometrie != null) count++;
    if (_filterEntite != null) count++;
    if (_filterDateRange != null) count++;
    return count;
  }

  // â”€â”€ SÃ©lection plage date â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
        _applyFilters();
      });
    }
  }

  // â”€â”€ BUILD â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
          // â”€â”€ Bandeau compteur â”€â”€
          _buildCounterBanner(),

          // â”€â”€ Panneau filtres â”€â”€
          if (_filtersVisible) _buildFilterPanel(),

          // â”€â”€ Liste â”€â”€
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : DataListView(
                    data: _filteredData,
                    entityType: widget.title,
                    dataFilter: widget.dataFilter,
                    onEdit: _editItem,
                    onDelete: null,
                    onView: null,
                    tableName: null,
                  ),
          ),
        ],
      ),
    );
  }

  // â”€â”€ Bandeau compteur â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildCounterBanner() {
    final total = _allData.length;
    final shown = _filteredData.length;
    final isFiltered = _activeFiltersCount > 0;

    return Container(
      color: const Color(0xFF1976D2).withOpacity(0.08),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 16,
            color: const Color(0xFF1976D2),
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
              label: const Text('Réinitialiser',
                  style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
        ],
      ),
    );
  }

  // â”€â”€ Panneau filtres â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildFilterPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
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

          // â”€â”€ Ligne 1 : MÃ©tier + GÃ©omÃ©trie â”€â”€
          Row(
            children: [
              Expanded(child: _buildMetierDropdown()),
              const SizedBox(width: 8),
              Expanded(child: _buildGeometrieDropdown()),
            ],
          ),
          const SizedBox(height: 8),

          // â”€â”€ Ligne 2 : EntitÃ© (si mÃ©tier choisi) â”€â”€
          if (_filterMetier != null) ...[
            _buildEntiteDropdown(),
            const SizedBox(height: 8),
          ],

          // â”€â”€ Ligne 3 : Date â”€â”€
          _buildDateFilter(),
        ],
      ),
    );
  }

  // â”€â”€ Filtre mÃ©tier â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildMetierDropdown() {
    final metierColors = {
      'Eau Potable': const Color(0xFF1976D2),
      'Assainissement': const Color(0xFF27AE60),
      'Électricité': const Color(0xFFF39C12),
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
                    .withOpacity(0.06)
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
                  child: Text('Tous les métiers',
                      style: TextStyle(fontSize: 13)),
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
                          Text(m,
                              style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    )),
              ],
              onChanged: (val) {
                setState(() {
                  _filterMetier = val;
                  _updateEntitesDisponibles();
                  _applyFilters();
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  // â”€â”€ Filtre gÃ©omÃ©trie â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
                ? const Color(0xFF8E44AD).withOpacity(0.06)
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
                  child: Text('Tous les types',
                      style: TextStyle(fontSize: 13)),
                ),
                ...geoOptions.entries.map((e) => DropdownMenuItem<String>(
                      value: e.key,
                      child: Row(
                        children: [
                          Icon(e.value, size: 16, color: const Color(0xFF8E44AD)),
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
                  _applyFilters();
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  // â”€â”€ Filtre entitÃ© â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
                ? const Color(0xFF1976D2).withOpacity(0.06)
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
                  child: Text('Tous les types',
                      style: TextStyle(fontSize: 13)),
                ),
                ..._entitesDisponibles.map((e) => DropdownMenuItem<String>(
                      value: e,
                      child: Text(e, style: const TextStyle(fontSize: 13)),
                    )),
              ],
              onChanged: (val) {
                setState(() {
                  _filterEntite = val;
                  _applyFilters();
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  // â”€â”€ Filtre date â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
              ? const Color(0xFFE74C3C).withOpacity(0.06)
              : Colors.white,
        ),
        child: Row(
          children: [
            Icon(
              Icons.date_range,
              size: 18,
              color: hasDate
                  ? const Color(0xFFE74C3C)
                  : const Color(0xFF666666),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hasDate
                    ? '${_formatDate(_filterDateRange!.start)} → ${_formatDate(_filterDateRange!.end)}'
                    : 'Filtrer par date de collecte',
                style: TextStyle(
                  fontSize: 13,
                  color: hasDate
                      ? const Color(0xFFE74C3C)
                      : Colors.grey,
                  fontWeight: hasDate
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
            ),
            if (hasDate)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _filterDateRange = null;
                    _applyFilters();
                  });
                },
                child: const Icon(Icons.clear,
                    size: 16, color: Color(0xFFE74C3C)),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

