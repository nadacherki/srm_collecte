import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:srm_collecte/services/public_metrics_cache_service.dart';

void main() {
  group('PublicMetricsCacheService', () {
    test('empty API responses are stored as valid zero metrics', () async {
      final store = _FakeMetricsStore();
      final service = PublicMetricsCacheService(
        apiClient: const _EmptyMetricsApiClient(),
        metadataStore: store,
      );

      final snapshot = await service.refreshAndSave(agentId: 19);

      expect(snapshot.error, isNull);
      expect(snapshot.resume, isNotNull);
      expect(snapshot.day, isNotNull);
      expect(snapshot.week, isNotNull);
      expect(snapshot.month, isNotNull);
      expect(snapshot.resume!['id_agent'], 19);
      expect(snapshot.resume!['nb_objets_crees_total'], 0);
      expect(store.savedKeys, contains('public_metrics_cache_v1:19'));

      final loaded = await service.loadSnapshot(agentId: 19);
      expect(loaded.resume!['id_agent'], 19);
      expect(loaded.resume!['nb_objets_crees_total'], 0);
      expect(loaded.error, isNull);
    });

    test('network errors are not converted to fake zero metrics', () async {
      final store = _FakeMetricsStore();
      final service = PublicMetricsCacheService(
        apiClient: const _FailingMetricsApiClient(),
        metadataStore: store,
      );

      final snapshot = await service.refreshAndSave(agentId: 19);

      expect(snapshot.hasAnyData, isFalse);
      expect(snapshot.error, contains('serveur indisponible'));
      expect(store.savedKeys, isEmpty);
    });

    test('loadSnapshot restores cached metrics and cached error', () async {
      final store = _FakeMetricsStore()
        ..values['public_metrics_cache_v1:7'] = jsonEncode({
          'agent_id': 7,
          'fetched_at': '2026-05-10T21:20:00.000',
          'resume': {
            'id_agent': 7,
            'nb_objets_crees_total': 12,
          },
          'day': null,
          'week': null,
          'month': null,
          'error': 'jour: timeout',
        });
      final service = PublicMetricsCacheService(
        apiClient: const _EmptyMetricsApiClient(),
        metadataStore: store,
      );

      final snapshot = await service.loadSnapshot(agentId: 7);

      expect(snapshot.resume!['nb_objets_crees_total'], 12);
      expect(snapshot.fetchedAt, DateTime(2026, 5, 10, 21, 20));
      expect(snapshot.error, 'jour: timeout');
    });
  });
}

class _FakeMetricsStore implements PublicMetricsMetadataStore {
  final values = <String, String>{};
  final savedKeys = <String>[];

  @override
  Future<String?> getValue(String key) async => values[key];

  @override
  Future<void> saveValue(String key, String value) async {
    savedKeys.add(key);
    values[key] = value;
  }

  @override
  Future<Map<String, dynamic>?> getCurrentUser() async => {'id_user': 19};
}

class _EmptyMetricsApiClient implements PublicMetricsApiClient {
  const _EmptyMetricsApiClient();

  @override
  Future<Map<String, dynamic>?> fetchResume({required int idAgent}) async {
    return null;
  }

  @override
  Future<Map<String, dynamic>?> fetchJour({
    required int idAgent,
    required DateTime jour,
  }) async {
    return null;
  }

  @override
  Future<Map<String, dynamic>?> fetchSemaine({
    required int idAgent,
    required int anneeIso,
    required int semaineIso,
  }) async {
    return null;
  }

  @override
  Future<Map<String, dynamic>?> fetchMois({
    required int idAgent,
    required int annee,
    required int moisNumero,
  }) async {
    return null;
  }
}

class _FailingMetricsApiClient implements PublicMetricsApiClient {
  const _FailingMetricsApiClient();

  Exception get _error => Exception('serveur indisponible');

  @override
  Future<Map<String, dynamic>?> fetchResume({required int idAgent}) async {
    throw _error;
  }

  @override
  Future<Map<String, dynamic>?> fetchJour({
    required int idAgent,
    required DateTime jour,
  }) async {
    throw _error;
  }

  @override
  Future<Map<String, dynamic>?> fetchSemaine({
    required int idAgent,
    required int anneeIso,
    required int semaineIso,
  }) async {
    throw _error;
  }

  @override
  Future<Map<String, dynamic>?> fetchMois({
    required int idAgent,
    required int annee,
    required int moisNumero,
  }) async {
    throw _error;
  }
}
