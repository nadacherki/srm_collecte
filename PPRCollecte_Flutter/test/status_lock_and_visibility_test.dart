import 'package:flutter_test/flutter_test.dart';
import 'package:srm_collecte/services/form_lock_service.dart';
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
    test('locks synced clean rows and keeps special cases editable', () {
      expect(FormLockService.isLocked({'synced': 1}), isTrue);
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

    test('translates intervention status labels', () {
      expect(FormLockService.statutLabel('A_COMPLETER'), 'À compléter');
      expect(FormLockService.statutLabel('PLANIFIE'), 'Planifié');
      expect(FormLockService.statutLabel('EN_COURS'), 'En cours');
      expect(FormLockService.statutLabel('COMPLETE'), 'Complété');
      expect(FormLockService.statutLabel('AUTRE'), 'AUTRE');
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

      expect(filter.where, contains('downloaded'));
      expect(filter.where, contains('synced'));
      expect(filter.where, contains('login_id = ?'));
      expect(filter.where, contains('id_agent_crea = ?'));
      expect(filter.rawArgs, [19, 19]);
      expect(filter.rawWhereClause, startsWith(' WHERE '));
    });
  });
}
