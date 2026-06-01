import 'package:flutter_test/flutter_test.dart';
import 'package:srm_collecte/services/form_lock_service.dart';
import 'package:srm_collecte/services/map_preview_service.dart';
import 'package:srm_collecte/services/srm_row_visibility_filter.dart';
import 'package:srm_collecte/services/srm_status_flags.dart';

void main() {
  group('SrmStatusFlags', () {
    test('normalizes common false and true values', () {
      expect(SrmStatusFlags.isTruthy(null), isFalse);
      expect(SrmStatusFlags.isTruthy(''), isFalse);
      expect(SrmStatusFlags.isTruthy('Non'), isFalse);
      expect(SrmStatusFlags.isTruthy('RAS'), isFalse);
      expect(SrmStatusFlags.isTruthy('0'), isFalse);
      expect(SrmStatusFlags.isTruthy(0), isFalse);

      expect(SrmStatusFlags.isTruthy('Oui'), isTrue);
      expect(SrmStatusFlags.isTruthy('Fuite'), isTrue);
      expect(SrmStatusFlags.isTruthy('1'), isTrue);
      expect(SrmStatusFlags.isTruthy(2), isTrue);
    });

    test('detects anomalies and incomplete objects from SRM rows', () {
      expect(
        SrmStatusFlags.hasAnomalie({'type_anomalie': 'Non'}),
        isFalse,
      );
      expect(
        SrmStatusFlags.hasAnomalie({'type_anomalie': 'Fuite'}),
        isTrue,
      );
      expect(
        SrmStatusFlags.hasAnomalie({'ep_anomalie': 'Non'}),
        isFalse,
      );
      expect(
        SrmStatusFlags.hasAnomalie({'ep_anomalie': 'Fraude compteur'}),
        isTrue,
      );
      expect(
        SrmStatusFlags.hasIncomplet({'objet_incomplet': 1}),
        isTrue,
      );
      expect(
        SrmStatusFlags.hasIncomplet({'raison_incomplet': ''}),
        isFalse,
      );
      expect(
        SrmStatusFlags.hasIncomplet({'raison_incomplet': 'Photo manquante'}),
        isTrue,
      );
    });
  });

  group('FormLockService', () {
    test('locks synced/downloaded clean rows and keeps special cases editable',
        () {
      expect(FormLockService.isLocked({'synced': 1}), isTrue);
      expect(FormLockService.isLocked({'downloaded': 1}), isTrue);
      expect(FormLockService.isEditable({'synced': 0}), isTrue);
      expect(
        FormLockService.isEditable({'synced': 1, 'type_anomalie': 'Fuite'}),
        isTrue,
      );
      expect(
        FormLockService.isEditable({
          'synced': 1,
          'objet_incomplet': 1,
        }),
        isTrue,
      );
    });

    test('direct map/list edition is only for local drafts', () {
      expect(FormLockService.isDraftEditable({'synced': 0}), isTrue);
      expect(FormLockService.isDraftEditable({'synced': 1}), isFalse);
      expect(FormLockService.isDraftEditable({'downloaded': 1}), isFalse);
      expect(
        FormLockService.isDraftEditable({
          'synced': 1,
          'type_anomalie': 'Fuite',
        }),
        isFalse,
      );
    });

    test('translates intervention status labels', () {
      expect(FormLockService.statutLabel('A_COMPLETER'), 'À compléter');
      expect(FormLockService.statutLabel('PLANIFIE'), 'Planifié');
      expect(FormLockService.statutLabel('EN_COURS'), 'En cours');
      expect(FormLockService.statutLabel('COMPLETE'), 'Complété');
      expect(FormLockService.statutLabel('AUTRE'), 'AUTRE');
    });
  });

  group('MapPreviewService', () {
    test('uses business labels instead of technical identifiers', () {
      expect(
        MapPreviewService.displayName({
          'uuid': '123e4567-e89b-12d3-a456-426614174000',
        }, fallback: 'Regard'),
        'Regard',
      );
      expect(
        MapPreviewService.displayName({
          'uuid': '123e4567-e89b-12d3-a456-426614174000',
          'ep_num': 'EP-42',
        }, fallback: 'Regard'),
        'EP-42',
      );
      expect(
        MapPreviewService.titleWithOptionalName(
          type: 'Regard',
          name: '123e4567-e89b-12d3-a456-426614174000',
        ),
        'Regard',
      );
    });

    test('filters empty and technical preview fields', () {
      expect(MapPreviewService.isTechnicalField('uuid'), isTrue);
      expect(MapPreviewService.isTechnicalField('source_table'), isTrue);
      expect(MapPreviewService.isTechnicalField('commune_id'), isTrue);
      expect(MapPreviewService.isUsefulValue(''), isFalse);
      expect(MapPreviewService.isUsefulValue('----'), isFalse);
      expect(MapPreviewService.isUsefulValue('Valeur terrain'), isTrue);
    });
  });

  group('SrmRowVisibilityFilter', () {
    test('builds no filter when no usable columns exist', () {
      final filter = SrmRowVisibilityFilter.build(
        availableColumns: const {'uuid', 'nom'},
        loginId: 19,
      );

      expect(filter.where, isNull);
      expect(filter.rawWhereClause, '');
      expect(filter.rawArgs, isEmpty);
    });

    test('keeps downloaded, synced and current-user rows visible', () {
      final filter = SrmRowVisibilityFilter.build(
        availableColumns: const {
          'uuid',
          'downloaded',
          'synced',
          'login_id',
          'id_agent_crea',
        },
        loginId: 19,
      );

      // Phase B : comparaison directe `= 1` au lieu de l'ancien
      // LOWER(CAST(COALESCE(...) AS TEXT)) qui empechait l'usage d'index.
      expect(filter.where, contains('downloaded = 1'));
      expect(filter.where, contains('synced = 1'));
      expect(filter.where, isNot(contains('LOWER(')));
      expect(filter.where, contains('login_id = ?'));
      expect(filter.where, contains('id_agent_crea = ?'));
      expect(filter.rawArgs, [19, 19]);
      expect(filter.rawWhereClause, startsWith(' WHERE '));
    });
  });
}
