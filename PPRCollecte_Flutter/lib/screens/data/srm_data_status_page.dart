import 'package:flutter/material.dart';

import '../../core/config/srm_config.dart';
import '../../data/local/database_helper.dart';
import '../../data/remote/api_service.dart';
import '../../widgets/lists/data_list_view.dart';

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
  List<Map<String, dynamic>> _data = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

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
    final currentMissionId = ApiService.currentMissionId;

    final rowProjetId = _toInt(item['id_projet']);
    final rowMissionId = _toInt(item['id_mission']);

    if (currentProjetId != null && rowProjetId != currentProjetId) return false;
    if (currentMissionId != null && rowMissionId != currentMissionId) return false;
    return true;
  }

  bool _matchesFilter(Map<String, dynamic> item, int? loginId) {
    final synced = _toInt(item['synced']) == 1;
    final downloaded = _toInt(item['downloaded']) == 1;
    final creatorId = _toInt(item['id_agent_crea']);
    final isCurrentUserItem = loginId == null || creatorId == loginId;

    if (!_matchesCurrentContext(item)) return false;

    switch (widget.dataFilter) {
      case 'unsynced':
        return !synced && !downloaded && isCurrentUserItem;
      case 'synced':
        return synced && !downloaded && isCurrentUserItem;
      case 'saved':
        return downloaded;
      default:
        return true;
    }
  }

  String _buildDisplayTitle(String entity, Map<String, dynamic> row) {
    const preferredKeys = [
      'nom',
      'code',
      'ep_num',
      'ep_numero',
      'reference',
      'type',
      'type_objet',
      'type_regard',
      'type_conduite',
      'type_station',
      'type_poste',
      'type_support',
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
            final item = Map<String, dynamic>.from(row);
            item['source_table'] = tableName;
            item['source_metier'] = metier;
            item['source_entity'] = entity;
            item['nom'] = (item['nom']?.toString().trim().isNotEmpty ?? false)
                ? item['nom']
                : entity;
            item['type'] = metier;
            item['display_title'] = _buildDisplayTitle(entity, item);

            if (_matchesFilter(item, loginId)) {
              items.add(item);
            }
          }
        }
      }

      items.sort((a, b) {
        final da = _sortDateFor(a);
        final db = _sortDateFor(b);
        if (da != null && db != null) return db.compareTo(da);
        if (da != null) return -1;
        if (db != null) return 1;
        return _toInt(b['id']).compareTo(_toInt(a['id']));
      });

      if (!mounted) return;
      setState(() => _data = items);
    } catch (e) {
      if (!mounted) return;
      setState(() => _data = []);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de chargement des données: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

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
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : DataListView(
              data: _data,
              entityType: widget.title,
              dataFilter: widget.dataFilter,
              onEdit: null,
              onDelete: null,
              onView: null,
              tableName: null,
            ),
    );
  }
}
