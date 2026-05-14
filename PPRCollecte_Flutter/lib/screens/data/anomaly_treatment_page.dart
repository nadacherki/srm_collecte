import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../core/config/srm_config.dart';
import '../../data/local/database_helper.dart';
import '../../services/attribut_config_mobile_service.dart';
import '../../services/projection_service.dart';
import '../../services/srm_status_flags.dart';
import '../../widgets/forms/srm_point_form_widget.dart';
import '../forms/polygon_form_page.dart';
import '../forms/srm_ligne_form_page.dart';
import '../home/home_page.dart';

class AnomalyTreatmentPage extends StatefulWidget {
  final bool isOnline;
  final String agentName;

  const AnomalyTreatmentPage({
    super.key,
    required this.isOnline,
    required this.agentName,
  });

  @override
  State<AnomalyTreatmentPage> createState() => _AnomalyTreatmentPageState();
}

class _AnomalyTreatmentPageState extends State<AnomalyTreatmentPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  bool _isLoading = true;
  String _filter = 'retour_terrain_a_faire';
  Map<String, int> _summary = const {};
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final summary = await _dbHelper.getInterventionAnomalieTreatmentSummary();
      final items = await _dbHelper.getInterventionAnomalieTreatmentItems(
        filter: _filter,
      );
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _items = const [];
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de chargement des anomalies : $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _selectFilter(String filter) async {
    if (_filter == filter) return;
    setState(() => _filter = filter);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F8FF),
      appBar: AppBar(
        title: const Text(
          'Traitement des anomalies',
          style: TextStyle(
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
          IconButton(
            tooltip: 'Rafraîchir',
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _load,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSummaryCard(),
            const SizedBox(height: 16),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_items.isEmpty)
              _buildEmptyState()
            else
              ..._items.map(_buildInterventionCard),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.construction, color: Color(0xFFFF9800)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Cycle de vie des anomalies',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B4F72),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildStatusTile(
                  filter: 'en_attente_exploitant',
                  label: 'En attente exploitant',
                  value: _summary['en_attente_exploitant'] ?? 0,
                  icon: Icons.hourglass_bottom,
                  color: const Color(0xFFFF9800),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatusTile(
                  filter: 'retour_terrain_a_faire',
                  label: 'Retour terrain',
                  value: _summary['retour_terrain_a_faire'] ?? 0,
                  icon: Icons.assignment_return,
                  color: const Color(0xFF1976D2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatusTile(
                  filter: 'retour_terrain_effectue',
                  label: 'Effectué',
                  value: _summary['retour_terrain_effectue'] ?? 0,
                  icon: Icons.task_alt,
                  color: const Color(0xFF2E7D32),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTile({
    required String filter,
    required String label,
    required int value,
    required IconData icon,
    required Color color,
  }) {
    final selected = _filter == filter;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _selectFilter(filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.12)
              : color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.22),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(
              '$value',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: const Column(
        children: [
          Icon(Icons.check_circle_outline, size: 42, color: Color(0xFF2E7D32)),
          SizedBox(height: 12),
          Text(
            'Aucune anomalie dans ce statut.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterventionCard(Map<String, dynamic> row) {
    final ref = _resolveObjectRef(row);
    final statusColor = _statusColor(row);
    final isReturn = _requiresTerrainReturn(row);
    final isDone = _isTerrainDone(row);
    final title = ref?.title ?? _cleanObjectLabel(row);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: 0.35)),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.report_problem_outlined, color: statusColor, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF222222),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _objectIdentifier(row),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusChip(row),
            ],
          ),
          const SizedBox(height: 10),
          _buildMetaLine(
            Icons.person_outline,
            'Responsable',
            _text(row['responsable_actuel'], fallback: 'Non défini'),
          ),
          _buildMetaLine(
            Icons.calendar_today_outlined,
            'Dernière mise à jour',
            _formatDate(
              row['updated_at'] ??
                  row['date_exploitant'] ??
                  row['date_bureau'] ??
                  row['date_creation'],
            ),
          ),
          if (_text(row['commentaire_exploitant']).isNotEmpty)
            _buildComment('Exploitant', row['commentaire_exploitant']),
          if (_text(row['commentaire_bureau']).isNotEmpty)
            _buildComment('Bureau', row['commentaire_bureau']),
          if (_text(row['commentaire_terrain']).isNotEmpty)
            _buildComment('Terrain', row['commentaire_terrain']),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _goToLinkedObjectOnMap(row),
                  icon: const Icon(Icons.center_focus_strong, size: 18),
                  label: const Text('Voir sur carte'),
                ),
              ),
              if (!isDone) const SizedBox(width: 8),
              if (!isDone)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openLinkedObject(row),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label:
                        Text(isReturn ? 'Compléter l’objet' : 'Voir l’objet'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(Map<String, dynamic> row) {
    final color = _statusColor(row);
    final label = _isTerrainDone(row)
        ? 'Retour effectué'
        : _requiresTerrainReturn(row)
            ? 'Retour terrain'
            : 'En attente';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildMetaLine(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 15, color: const Color(0xFF666666)),
          const SizedBox(width: 6),
          Text(
            '$label : ',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF555555),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, color: Color(0xFF555555)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComment(String source, dynamic value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$source : ${_text(value)}',
        style: const TextStyle(fontSize: 12, color: Color(0xFF444444)),
      ),
    );
  }

  Future<void> _openLinkedObject(Map<String, dynamic> intervention) async {
    final ref = _resolveObjectRef(intervention);
    if (ref == null) {
      _showMessage('Objet lié non reconnu sur ce téléphone.');
      return;
    }

    final item = await _dbHelper.getEntitySrmByIdOrUuid(
      ref.tableName,
      idObjet: _toInt(intervention['id_objet']),
      uuidObjet: intervention['uuid_objet']?.toString(),
    );
    if (item == null) {
      _showMessage(
        'Objet lié non disponible localement. Téléchargez les données puis réessayez.',
      );
      return;
    }

    final editable = Map<String, dynamic>.from(item)
      ..['source_table'] = ref.tableName
      ..['source_metier'] = ref.metier
      ..['source_entity'] = ref.entity
      ..['source_title'] = ref.title
      ..['geometry_type'] = ref.geometryType;

    final saved = await _openFormForItem(editable, ref);
    if (saved == true) {
      final refreshedItem = await _dbHelper.getEntitySrmByIdOrUuid(
        ref.tableName,
        idObjet: _toInt(intervention['id_objet']),
        uuidObjet: intervention['uuid_objet']?.toString(),
      );
      if (refreshedItem != null && !SrmStatusFlags.hasAnomalie(refreshedItem)) {
        final localId = _toInt(intervention['id']);
        if (localId != null && !_isTerrainDone(intervention)) {
          await _dbHelper.updateInterventionAnomalieTerrainLocal(
            localId: localId,
            etatTerrain: 'traite',
            commentaireTerrain: intervention['commentaire_terrain']?.toString(),
          );
          _showMessage('Anomalie marquee comme completee cote terrain.');
        }
        await _load();
        return;
      }

      if (!_requiresTerrainReturn(intervention)) {
        await _load();
        return;
      }

      if (refreshedItem != null && SrmStatusFlags.hasIncomplet(refreshedItem)) {
        _showMessage(
          'Objet encore incomplet : le retour terrain reste à faire.',
        );
        await _load();
        return;
      }
      await _load();
    }
  }

  Future<void> _goToLinkedObjectOnMap(Map<String, dynamic> intervention) async {
    final ref = _resolveObjectRef(intervention);
    if (ref == null) {
      _showMessage('Objet lie non reconnu sur ce telephone.');
      return;
    }

    final item = await _dbHelper.getEntitySrmByIdOrUuid(
      ref.tableName,
      idObjet: _toInt(intervention['id_objet']),
      uuidObjet: intervention['uuid_objet']?.toString(),
    );
    if (item == null) {
      _showMessage(
        'Objet lie non disponible localement. Telechargez les donnees puis reessayez.',
      );
      return;
    }

    final editable = Map<String, dynamic>.from(item)
      ..['source_table'] = ref.tableName
      ..['source_metier'] = ref.metier
      ..['source_entity'] = ref.entity
      ..['source_title'] = ref.title
      ..['geometry_type'] = ref.geometryType;
    final target = _buildMapFocusTarget(editable, ref);
    if (target == null) {
      _showMessage('Aucune geometrie exploitable pour cet objet.');
      return;
    }

    HomePage.pendingFocusTarget = target;
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<bool?> _openFormForItem(
    Map<String, dynamic> item,
    _LinkedObjectRef ref,
  ) async {
    if (ref.geometryType == 'LineString') {
      final points = _decodeGeometryPoints(item['points_json']);
      if (points.length < 2) {
        _showMessage('Ligne liée invalide.');
        return false;
      }
      return Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => SrmLigneFormPage(
            metier: ref.metier,
            entityType: ref.entity,
            displayTitle: ref.title,
            linePoints: points,
            agentName: widget.agentName,
            existingData: item,
          ),
        ),
      );
    }

    if (ref.geometryType == 'Polygon') {
      final points = _decodeGeometryPoints(
        item['points_json'] ?? item['geometry_geojson'] ?? item['geom'],
      );
      if (points.length < 3) {
        _showMessage('Polygone lié invalide.');
        return false;
      }
      return Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PolygonFormPage(
            polygonPoints: points,
            startTime: _dateFromItem(item) ?? DateTime.now(),
            endTime: DateTime.now(),
            agentName: widget.agentName,
            existingData: item,
            metier: ref.metier,
            entityType: ref.entity,
            displayTitle: ref.title,
          ),
        ),
      );
    }

    final latLng = _resolvePointLatLng(item: item, ref: ref);
    return Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          body: SrmPointFormWidget(
            metier: ref.metier,
            entityType: ref.entity,
            displayTitle: ref.title,
            latitude: latLng?.latitude ?? 0.0,
            longitude: latLng?.longitude ?? 0.0,
            altitude: (item['altitude_gps'] as num?)?.toDouble(),
            agentName: widget.agentName,
            existingData: item,
            onSaved: () => Navigator.pop(context, true),
            onCancel: () => Navigator.pop(context, false),
          ),
        ),
      ),
    );
  }

  _LinkedObjectRef? _resolveObjectRef(Map<String, dynamic> intervention) {
    final rawTable = _text(
      intervention['nom_table'] ?? intervention['nom_classe'],
    );
    if (rawTable.isEmpty) return null;

    final parts = rawTable.split('.');
    final schema = parts.length > 1 ? parts.first.trim().toLowerCase() : '';
    final configTable = parts.length > 1 ? parts.last.trim() : rawTable.trim();
    final metierCode = schema == 'asst' || schema == 'ass' ? 'asst' : 'ep';
    final localTable = AttributConfigMobileService.mobileTableForConfigTable(
      metierCode,
      configTable,
    );

    for (final metier in SrmConfig.getMetiers()) {
      for (final entity in SrmConfig.getEntitiesForMetier(metier)) {
        final tableName = SrmConfig.getTableName(metier, entity);
        if (tableName != localTable) continue;
        final config = SrmConfig.getEntityConfig(metier, entity) ?? const {};
        return _LinkedObjectRef(
          metier: metier,
          entity: entity,
          tableName: tableName!,
          title: entity,
          geometryType: config['geometryType']?.toString() ?? 'Point',
        );
      }
    }
    return null;
  }

  LatLng? _resolvePointLatLng({
    required Map<String, dynamic> item,
    required _LinkedObjectRef ref,
  }) {
    final latitude = _toDouble(item['latitude_gps'] ?? item['lat']);
    final longitude = _toDouble(item['longitude_gps'] ?? item['lon']);
    if (latitude != null && longitude != null) {
      return LatLng(latitude, longitude);
    }

    final schema = SrmConfig.getSchema(ref.metier, ref.entity);
    if (schema != null && schema.isNotEmpty) {
      final x = _toDouble(item['${schema}_coor_x']);
      final y = _toDouble(item['${schema}_coor_y']);
      if (x != null && y != null) return _toWgs84LatLng(x: x, y: y);
    }

    for (final key in ['points_json', 'geometry_geojson', 'geometry', 'geom']) {
      final points = _decodeGeometryPoints(item[key]);
      if (points.isNotEmpty) return points.first;
    }
    return null;
  }

  MapFocusTarget? _buildMapFocusTarget(
    Map<String, dynamic> item,
    _LinkedObjectRef ref,
  ) {
    final label = _focusLabel(item, ref);
    final id = _text(item['uuid'] ?? item['uuid_objet'] ?? item['id']);

    if (ref.geometryType == 'LineString') {
      var points = _decodeGeometryPoints(
        item['points_json'] ?? item['geometry_geojson'] ?? item['geom'],
      );
      if (points.length < 2) {
        points = _resolveLineEndpointPoints(item);
      }
      if (points.length < 2) return null;
      return MapFocusTarget.polyline(
        polyline: points,
        label: label,
        id: id.isEmpty ? null : id,
      );
    }

    if (ref.geometryType == 'Polygon') {
      final points = [
        ..._decodeGeometryPoints(
          item['points_json'] ?? item['geometry_geojson'] ?? item['geom'],
        ),
      ];
      if (points.length < 3) return null;
      if (points.first.latitude != points.last.latitude ||
          points.first.longitude != points.last.longitude) {
        points.add(points.first);
      }
      return MapFocusTarget.polyline(
        polyline: points,
        label: label,
        id: id.isEmpty ? null : id,
      );
    }

    final point = _resolvePointLatLng(item: item, ref: ref);
    if (point == null) return null;
    return MapFocusTarget.point(
      point: point,
      label: label,
      id: id.isEmpty ? null : id,
    );
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

  String _focusLabel(Map<String, dynamic> item, _LinkedObjectRef ref) {
    final display = _text(item['display_title']);
    if (display.isNotEmpty) return display;
    final title = ref.title.trim();
    if (title.isNotEmpty) return title;
    return _cleanObjectLabel(item);
  }

  List<LatLng> _decodeGeometryPoints(dynamic rawPoints) {
    if (rawPoints == null) return const [];
    try {
      final decoded = rawPoints is String ? jsonDecode(rawPoints) : rawPoints;
      final points = _latLngsFromDecodedGeometry(decoded);
      if (points.isNotEmpty) return points;
    } catch (_) {}
    if (rawPoints is! String) return const [];
    return RegExp(r'(-?\d+(?:\.\d+)?)\s+(-?\d+(?:\.\d+)?)')
        .allMatches(rawPoints)
        .map((match) {
          final x = double.tryParse(match.group(1) ?? '');
          final y = double.tryParse(match.group(2) ?? '');
          if (x == null || y == null) return null;
          return _toWgs84LatLng(x: x, y: y);
        })
        .whereType<LatLng>()
        .toList();
  }

  List<LatLng> _latLngsFromDecodedGeometry(dynamic decoded) {
    if (decoded is Map) {
      final geometry = decoded['geometry'];
      if (geometry is Map) return _latLngsFromDecodedGeometry(geometry);
      final type = decoded['type']?.toString().toLowerCase();
      final coordinates = decoded['coordinates'];
      if (type == 'point') {
        final point = _latLngFromCoordinate(coordinates);
        return point == null ? const [] : [point];
      }
      if (type == 'linestring' || type == 'multipoint') {
        return _latLngsFromDecodedGeometry(coordinates);
      }
      if (type == 'polygon' && coordinates is List && coordinates.isNotEmpty) {
        return _latLngsFromDecodedGeometry(coordinates.first);
      }
      final direct = _latLngFromCoordinate(decoded);
      return direct == null ? const [] : [direct];
    }
    if (decoded is List) {
      return decoded.map(_latLngFromCoordinate).whereType<LatLng>().toList();
    }
    return const [];
  }

  LatLng? _latLngFromCoordinate(dynamic coord) {
    if (coord is Map) {
      final lat = _toDouble(coord['lat'] ?? coord['latitude']);
      final lon = _toDouble(coord['lon'] ?? coord['lng'] ?? coord['longitude']);
      if (lat != null && lon != null) return LatLng(lat, lon);
      final x = _toDouble(coord['x']);
      final y = _toDouble(coord['y']);
      if (x != null && y != null) return _toWgs84LatLng(x: x, y: y);
    }
    if (coord is List && coord.length >= 2) {
      final x = _toDouble(coord[0]);
      final y = _toDouble(coord[1]);
      if (x != null && y != null) return _toWgs84LatLng(x: x, y: y);
    }
    return null;
  }

  LatLng _toWgs84LatLng({required double x, required double y}) {
    if (x.abs() <= 180 && y.abs() <= 90) return LatLng(y, x);
    final projected = ProjectionService().merchichToWgs84(x: x, y: y);
    return LatLng(projected.latitude, projected.longitude);
  }

  bool _requiresTerrainReturn(Map<String, dynamic> row) {
    final retour = _truthy(row['retour_terrain']);
    final responsable = _normalized(row['responsable_actuel']);
    final etatExploitant = _normalized(row['etat_exploitant']);
    final etatTerrain = _normalized(row['etat_terrain']);
    return (retour || responsable == 'terrain' || etatExploitant == 'traite') &&
        etatTerrain != 'traite';
  }

  bool _isTerrainDone(Map<String, dynamic> row) {
    return _normalized(row['etat_terrain']) == 'traite';
  }

  Color _statusColor(Map<String, dynamic> row) {
    if (_isTerrainDone(row)) return const Color(0xFF2E7D32);
    if (_requiresTerrainReturn(row)) return const Color(0xFF1976D2);
    return const Color(0xFFFF9800);
  }

  bool _truthy(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value.toInt() == 1;
    return {'1', 'true', 't', 'oui', 'yes'}
        .contains(value?.toString().trim().toLowerCase());
  }

  String _normalized(dynamic value) {
    return _text(value)
        .toLowerCase()
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('à', 'a')
        .replaceAll(' ', '_');
  }

  String _text(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return fallback;
    return text;
  }

  String _cleanObjectLabel(Map<String, dynamic> row) {
    final raw = _text(row['nom_table'] ?? row['nom_classe']);
    if (raw.isEmpty) return 'Objet anomalie';
    return raw.split('.').last.replaceAll('_', ' ');
  }

  String _objectIdentifier(Map<String, dynamic> row) {
    final id = _text(row['id_objet']);
    final uuid = _text(row['uuid_objet']);
    if (id.isNotEmpty && uuid.isNotEmpty) return 'Objet #$id • $uuid';
    if (id.isNotEmpty) return 'Objet #$id';
    if (uuid.isNotEmpty) return uuid;
    return 'Objet lié non identifié';
  }

  String _formatDate(dynamic value) {
    final text = _text(value);
    final date = DateTime.tryParse(text);
    if (date == null) return text.isEmpty ? 'Non renseignée' : text;
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/${date.year} $hour:$minute';
  }

  DateTime? _dateFromItem(Map<String, dynamic> item) {
    for (final key in ['date_collecte', 'date_creation', 'created_at']) {
      final date = DateTime.tryParse(_text(item[key]));
      if (date != null) return date;
    }
    return null;
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().trim());
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim());
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _LinkedObjectRef {
  final String metier;
  final String entity;
  final String tableName;
  final String title;
  final String geometryType;

  const _LinkedObjectRef({
    required this.metier,
    required this.entity,
    required this.tableName,
    required this.title,
    required this.geometryType,
  });
}
