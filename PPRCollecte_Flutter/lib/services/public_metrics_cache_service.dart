import 'dart:convert';

import '../data/local/database_helper.dart';
import '../data/remote/api_service.dart';

class PublicMetricsCacheService {
  static const String _cacheKeyPrefix = 'public_metrics_cache_v1';

  final DatabaseHelper _db;

  PublicMetricsCacheService({DatabaseHelper? databaseHelper})
      : _db = databaseHelper ?? DatabaseHelper();

  Future<PublicMetricsCacheSnapshot> loadSnapshot({
    required int? agentId,
    required int? projetId,
  }) async {
    if (agentId == null || projetId == null) {
      return const PublicMetricsCacheSnapshot();
    }

    final raw = await _db.getAppMetadataValue(_cacheKey(agentId, projetId));
    if (raw == null || raw.trim().isEmpty) {
      return const PublicMetricsCacheSnapshot();
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const PublicMetricsCacheSnapshot();
      }

      return PublicMetricsCacheSnapshot(
        resume: _mapValue(decoded['resume']),
        day: _mapValue(decoded['day']),
        week: _mapValue(decoded['week']),
        month: _mapValue(decoded['month']),
        fetchedAt: _parseDateTime(decoded['fetched_at']),
      );
    } catch (_) {
      return const PublicMetricsCacheSnapshot();
    }
  }

  Future<PublicMetricsCacheSnapshot> refreshAndSave({
    required int? agentId,
    required int? projetId,
  }) async {
    if (agentId == null || projetId == null) {
      return const PublicMetricsCacheSnapshot(
        error: 'Agent ou projet actif introuvable pour les metriques serveur.',
      );
    }

    final now = DateTime.now();
    final isoWeek = _computeIsoWeek(now);

    try {
      final responses = await Future.wait<Map<String, dynamic>?>([
        ApiService.fetchAgentPublicResume(
          idAgent: agentId,
          idProjet: projetId,
        ),
        ApiService.fetchAgentPublicJour(
          idAgent: agentId,
          idProjet: projetId,
          jour: now,
        ),
        ApiService.fetchAgentPublicSemaine(
          idAgent: agentId,
          idProjet: projetId,
          anneeIso: isoWeek.year,
          semaineIso: isoWeek.week,
        ),
        ApiService.fetchAgentPublicMois(
          idAgent: agentId,
          idProjet: projetId,
          annee: now.year,
          moisNumero: now.month,
        ),
      ]);

      final snapshot = PublicMetricsCacheSnapshot(
        resume: responses[0],
        day: responses[1],
        week: responses[2],
        month: responses[3],
        fetchedAt: now,
      );

      if (snapshot.hasAnyData) {
        await _db.saveAppMetadataValue(
          _cacheKey(agentId, projetId),
          jsonEncode({
            'agent_id': agentId,
            'projet_id': projetId,
            'fetched_at': now.toIso8601String(),
            'resume': snapshot.resume,
            'day': snapshot.day,
            'week': snapshot.week,
            'month': snapshot.month,
          }),
        );
      }

      return snapshot;
    } catch (e) {
      return PublicMetricsCacheSnapshot(error: _cleanErrorMessage(e));
    }
  }

  Future<void> prefetchForCurrentSession() async {
    final currentUser = await _db.getCurrentUserSrm();
    final agentId = ApiService.userId ?? _asIntOrNull(currentUser?['id_user']);
    final projetId = ApiService.currentProjetId ??
        _asIntOrNull(currentUser?['id_projet_actif']);

    await refreshAndSave(
      agentId: agentId,
      projetId: projetId,
    );
  }

  String _cacheKey(int agentId, int projetId) =>
      '$_cacheKeyPrefix:${agentId}_$projetId';

  Map<String, dynamic>? _mapValue(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (key, dynamic nestedValue) => MapEntry(key.toString(), nestedValue),
      );
    }
    return null;
  }

  DateTime? _parseDateTime(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }

  int? _asIntOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  String _cleanErrorMessage(Object error) {
    final raw = error.toString().trim();
    if (raw.startsWith('Exception: ')) {
      return raw.substring('Exception: '.length).trim();
    }
    return raw;
  }

  _IsoWeek _computeIsoWeek(DateTime value) {
    final normalized = DateTime(value.year, value.month, value.day);
    final weekday = normalized.weekday;
    final thursday = normalized.add(Duration(days: 4 - weekday));
    final yearStart = DateTime(thursday.year, 1, 1);
    final week = ((thursday.difference(yearStart).inDays) / 7).floor() + 1;
    return _IsoWeek(year: thursday.year, week: week);
  }
}

class PublicMetricsCacheSnapshot {
  final Map<String, dynamic>? resume;
  final Map<String, dynamic>? day;
  final Map<String, dynamic>? week;
  final Map<String, dynamic>? month;
  final DateTime? fetchedAt;
  final String? error;

  const PublicMetricsCacheSnapshot({
    this.resume,
    this.day,
    this.week,
    this.month,
    this.fetchedAt,
    this.error,
  });

  bool get hasAnyData =>
      resume != null || day != null || week != null || month != null;
}

class _IsoWeek {
  final int year;
  final int week;

  const _IsoWeek({
    required this.year,
    required this.week,
  });
}
