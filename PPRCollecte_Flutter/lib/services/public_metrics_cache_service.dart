import 'dart:convert';

import '../data/local/database_helper.dart';
import '../data/remote/api_service.dart';

abstract class PublicMetricsApiClient {
  Future<Map<String, dynamic>?> fetchResume({required int idAgent});

  Future<Map<String, dynamic>?> fetchJour({
    required int idAgent,
    required DateTime jour,
  });

  Future<Map<String, dynamic>?> fetchSemaine({
    required int idAgent,
    required int anneeIso,
    required int semaineIso,
  });

  Future<Map<String, dynamic>?> fetchMois({
    required int idAgent,
    required int annee,
    required int moisNumero,
  });
}

class ApiServicePublicMetricsClient implements PublicMetricsApiClient {
  const ApiServicePublicMetricsClient();

  @override
  Future<Map<String, dynamic>?> fetchResume({required int idAgent}) {
    return ApiService.fetchAgentPublicResume(idAgent: idAgent);
  }

  @override
  Future<Map<String, dynamic>?> fetchJour({
    required int idAgent,
    required DateTime jour,
  }) {
    return ApiService.fetchAgentPublicJour(idAgent: idAgent, jour: jour);
  }

  @override
  Future<Map<String, dynamic>?> fetchSemaine({
    required int idAgent,
    required int anneeIso,
    required int semaineIso,
  }) {
    return ApiService.fetchAgentPublicSemaine(
      idAgent: idAgent,
      anneeIso: anneeIso,
      semaineIso: semaineIso,
    );
  }

  @override
  Future<Map<String, dynamic>?> fetchMois({
    required int idAgent,
    required int annee,
    required int moisNumero,
  }) {
    return ApiService.fetchAgentPublicMois(
      idAgent: idAgent,
      annee: annee,
      moisNumero: moisNumero,
    );
  }
}

abstract class PublicMetricsMetadataStore {
  Future<String?> getValue(String key);

  Future<void> saveValue(String key, String value);

  Future<Map<String, dynamic>?> getCurrentUser();
}

class DatabasePublicMetricsMetadataStore implements PublicMetricsMetadataStore {
  final DatabaseHelper _db;

  DatabasePublicMetricsMetadataStore(this._db);

  @override
  Future<String?> getValue(String key) => _db.getAppMetadataValue(key);

  @override
  Future<void> saveValue(String key, String value) {
    return _db.saveAppMetadataValue(key, value);
  }

  @override
  Future<Map<String, dynamic>?> getCurrentUser() => _db.getCurrentUserSrm();
}

class PublicMetricsCacheService {
  static const String _cacheKeyPrefix = 'public_metrics_cache_v1';

  final PublicMetricsApiClient _apiClient;
  final PublicMetricsMetadataStore _metadataStore;

  PublicMetricsCacheService({
    DatabaseHelper? databaseHelper,
    PublicMetricsApiClient? apiClient,
    PublicMetricsMetadataStore? metadataStore,
  })  : _apiClient = apiClient ?? const ApiServicePublicMetricsClient(),
        _metadataStore = metadataStore ??
            DatabasePublicMetricsMetadataStore(
              databaseHelper ?? DatabaseHelper(),
            );

  Future<PublicMetricsCacheSnapshot> loadSnapshot({
    required int? agentId,
  }) async {
    if (agentId == null) {
      return const PublicMetricsCacheSnapshot();
    }

    final raw = await _metadataStore.getValue(_cacheKey(agentId));
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
        error: decoded['error']?.toString(),
      );
    } catch (_) {
      return const PublicMetricsCacheSnapshot();
    }
  }

  Future<PublicMetricsCacheSnapshot> refreshAndSave({
    required int? agentId,
    Duration? requestTimeout,
  }) async {
    if (agentId == null) {
      return const PublicMetricsCacheSnapshot(
        error: 'Agent introuvable pour les metriques serveur.',
      );
    }

    final now = DateTime.now();
    final isoWeek = _computeIsoWeek(now);

    final errors = <String, String>{};
    final failedLabels = <String>{};

    Future<Map<String, dynamic>?> fetchMetric(
      String label,
      Future<Map<String, dynamic>?> future,
    ) async {
      try {
        if (requestTimeout == null) {
          return await future;
        }
        return await future.timeout(requestTimeout);
      } catch (e) {
        failedLabels.add(label);
        errors[label] = _cleanErrorMessage(e);
        return null;
      }
    }

    try {
      final responses = await Future.wait<Map<String, dynamic>?>([
        fetchMetric(
          'resume',
          _apiClient.fetchResume(
            idAgent: agentId,
          ),
        ),
        fetchMetric(
          'jour',
          _apiClient.fetchJour(
            idAgent: agentId,
            jour: now,
          ),
        ),
        fetchMetric(
          'semaine',
          _apiClient.fetchSemaine(
            idAgent: agentId,
            anneeIso: isoWeek.year,
            semaineIso: isoWeek.week,
          ),
        ),
        fetchMetric(
          'mois',
          _apiClient.fetchMois(
            idAgent: agentId,
            annee: now.year,
            moisNumero: now.month,
          ),
        ),
      ]);

      final resume = responses[0] ??
          (failedLabels.contains('resume') ? null : _zeroResume(agentId));
      final day = responses[1] ??
          (failedLabels.contains('jour') ? null : _zeroDay(agentId, now));
      final week = responses[2] ??
          (failedLabels.contains('semaine')
              ? null
              : _zeroWeek(agentId, now, isoWeek));
      final month = responses[3] ??
          (failedLabels.contains('mois') ? null : _zeroMonth(agentId, now));

      final snapshot = PublicMetricsCacheSnapshot(
        resume: resume,
        day: day,
        week: week,
        month: month,
        fetchedAt: now,
        error: errors.isEmpty ? null : _formatMetricsFetchError(errors),
      );

      if (snapshot.hasAnyData) {
        await _metadataStore.saveValue(
          _cacheKey(agentId),
          jsonEncode({
            'agent_id': agentId,
            'fetched_at': now.toIso8601String(),
            'resume': snapshot.resume,
            'day': snapshot.day,
            'week': snapshot.week,
            'month': snapshot.month,
            'error': snapshot.error,
          }),
        );
      }

      return snapshot;
    } catch (e) {
      return PublicMetricsCacheSnapshot(error: _cleanErrorMessage(e));
    }
  }

  Future<PublicMetricsCacheSnapshot> prefetchForCurrentSession({
    Duration? requestTimeout,
  }) async {
    final currentUser = await _metadataStore.getCurrentUser();
    final agentId = ApiService.userId ?? _asIntOrNull(currentUser?['id_user']);

    return refreshAndSave(
      agentId: agentId,
      requestTimeout: requestTimeout,
    );
  }

  String _cacheKey(int agentId) => '$_cacheKeyPrefix:$agentId';

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

  String _formatMetricsFetchError(Map<String, String> errorsByLabel) {
    final failedScopes = errorsByLabel.keys.map(_metricScopeLabel).toList();
    final reason = _summarizeMetricsErrorReason(errorsByLabel.values);
    final prefix = errorsByLabel.length >= 4
        ? 'Métriques serveur indisponibles'
        : 'Rafraîchissement partiel des métriques serveur';

    return '$prefix : impossible de charger ${_joinFrench(failedScopes)}. '
        'Cause probable : $reason.';
  }

  String _metricScopeLabel(String label) {
    switch (label) {
      case 'resume':
        return 'le résumé';
      case 'jour':
        return 'la journée';
      case 'semaine':
        return 'la semaine';
      case 'mois':
        return 'le mois';
      default:
        return label;
    }
  }

  String _summarizeMetricsErrorReason(Iterable<String> rawReasons) {
    final normalized = rawReasons.map(_simplifyMetricsErrorReason).toSet();
    if (normalized.length == 1) {
      return normalized.first;
    }
    return normalized.join(' / ');
  }

  String _simplifyMetricsErrorReason(String rawReason) {
    final lower = rawReason.toLowerCase();
    if (lower.contains('erreur réseau') ||
        lower.contains('network') ||
        lower.contains('socket') ||
        lower.contains('connection') ||
        lower.contains('host') ||
        lower.contains('timeout')) {
      return 'connexion serveur indisponible';
    }
    if (lower.contains('404')) {
      return 'endpoint métriques introuvable';
    }
    if (lower.contains('500')) {
      return 'erreur interne du serveur';
    }
    return rawReason;
  }

  String _joinFrench(List<String> values) {
    if (values.isEmpty) return '';
    if (values.length == 1) return values.first;
    if (values.length == 2) return '${values.first} et ${values.last}';
    return '${values.take(values.length - 1).join(', ')} et ${values.last}';
  }

  Map<String, dynamic> _zeroResume(int agentId) {
    return {
      'metric_uid': 'mobile_zero_resume_$agentId',
      'id_agent': agentId,
      'premiere_activite': null,
      'derniere_activite': null,
      'nb_jours_actifs': 0,
      'nb_objets_crees_total': 0,
      'nb_points_total': 0,
      'nb_lignes_total': 0,
      'nb_surfaces_total': 0,
      'nb_objets_anomalie_total': 0,
      'taux_anomalie_global_pct': 0.0,
      'nb_objets_avec_photo_total': 0,
      'nb_photos_renseignees_total': 0,
      'nb_photos_uploadees_total': 0,
      'nb_objets_incomplets_signales_total': 0,
      'nb_objets_incomplets_completes_total': 0,
      'nb_modifications_terrain_total': 0,
      'nb_validations_terrain_total': 0,
      'nb_corrections_backoffice_total': 0,
      'nb_corrections_superviseur_total': 0,
      'nb_reouvertures_total': 0,
      'nb_evenements_sync_total': 0,
      'objets_par_heure_global': 0.0,
      'nb_objets_7j': 0,
      'nb_objets_30j': 0,
      'nb_objets_mois_courant': 0,
      'nb_objets_semaine_courante': 0,
    };
  }

  Map<String, dynamic> _zeroDay(int agentId, DateTime day) {
    return {
      ..._zeroPeriod(agentId),
      'metric_uid': 'mobile_zero_day_${agentId}_${_formatDate(day)}',
      'jour': _formatDate(day),
    };
  }

  Map<String, dynamic> _zeroWeek(
    int agentId,
    DateTime day,
    _IsoWeek isoWeek,
  ) {
    final start = DateTime(day.year, day.month, day.day)
        .subtract(Duration(days: day.weekday - 1));
    final end = start.add(const Duration(days: 6));
    return {
      ..._zeroPeriod(agentId),
      'metric_uid':
          'mobile_zero_week_${agentId}_${isoWeek.year}_${isoWeek.week}',
      'semaine_debut': _formatDate(start),
      'semaine_fin': _formatDate(end),
      'annee_iso': isoWeek.year,
      'semaine_iso': isoWeek.week,
    };
  }

  Map<String, dynamic> _zeroMonth(int agentId, DateTime day) {
    final month = DateTime(day.year, day.month, 1);
    return {
      ..._zeroPeriod(agentId),
      'metric_uid': 'mobile_zero_month_${agentId}_${day.year}_${day.month}',
      'mois': _formatDate(month),
      'annee': day.year,
      'mois_numero': day.month,
    };
  }

  Map<String, dynamic> _zeroPeriod(int agentId) {
    return {
      'id_agent': agentId,
      'nb_objets_crees': 0,
      'nb_points': 0,
      'nb_lignes': 0,
      'nb_surfaces': 0,
      'nb_objets_anomalie': 0,
      'taux_anomalie_pct': 0.0,
      'nb_objets_avec_photo': 0,
      'taux_objets_avec_photo_pct': 0.0,
      'nb_photos_renseignees': 0,
      'nb_photos_uploadees': 0,
      'moyenne_photos_par_objet': 0.0,
      'nb_objets_incomplets_signales': 0,
      'nb_objets_incomplets_completes': 0,
      'solde_incomplets': 0,
      'nb_modifications_terrain': 0,
      'nb_validations_terrain': 0,
      'nb_corrections_backoffice': 0,
      'nb_corrections_superviseur': 0,
      'nb_reouvertures': 0,
      'nb_evenements_mobiles': 0,
      'nb_attributs_mobiles': 0,
      'nb_sessions_login': 0,
      'nb_sessions_logout': 0,
      'nb_evenements_sync': 0,
      'objets_par_heure': 0.0,
      'actif': false,
      'nb_jours_actifs': 0,
    };
  }

  String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
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
