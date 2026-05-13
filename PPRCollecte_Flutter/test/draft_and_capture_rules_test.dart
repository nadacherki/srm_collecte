import 'package:flutter_test/flutter_test.dart';
import 'package:srm_collecte/services/capture_location_guard.dart';
import 'package:srm_collecte/services/draft_service.dart';
import 'package:srm_collecte/services/line_form_payload_service.dart';

void main() {
  group('draft rules', () {
    test('automatic coordinates and neutral defaults do not create drafts', () {
      final meaningful = DraftService.hasMeaningfulDraftContent(
        formData: {
          'ep_coor_x': '819605.686',
          'ep_coor_y': '459013.134',
          'ep_coor_z': '41.250',
          'altitude_gps': '41.250',
          'ep_agent': 'ETAFAT',
          'ep_agent_crea': 'ETAFAT',
          'ep_date_insertion': '2026-05-11',
          'ep_conf_plan': 'Objet decouvert',
          'mode_localisation': 'Levé topographique',
          'anomalie': 'Non',
          'ep_anomalie': '0',
        },
        extraState: {
          'regardEpUuid': '1b6f3b3a-0c55-4f0d-a6a8-0d2f302ca317',
          'type_anomalie': 'Non',
        },
      );

      expect(meaningful, isFalse);
    });

    test('regard technical state alone does not create a draft', () {
      final meaningful = DraftService.hasMeaningfulDraftContent(
        formData: const {},
        extraState: const {
          'regardEpUuid': '1b6f3b3a-0c55-4f0d-a6a8-0d2f302ca317',
          'polygonPoints': <Map<String, double>>[],
          'hasAnomalie': false,
          'isObjetIncomplet': false,
        },
      );

      expect(meaningful, isFalse);
    });

    test('business attributes or photos keep a draft meaningful', () {
      expect(
        DraftService.hasMeaningfulDraftContent(
          formData: {'ep_observation': 'Compteur inaccessible'},
        ),
        isTrue,
      );
      expect(
        DraftService.hasMeaningfulDraftContent(
          formData: const {},
          photoPaths: {1: 'C:/tmp/photo.jpg'},
        ),
        isTrue,
      );
    });
  });

  group('capture location guard', () {
    test('points and lines require GPS/mock plus Z before capture', () {
      expect(
        CaptureLocationGuard.canCapture(gpsEnabled: false, altitude: null),
        isFalse,
      );
      expect(
        CaptureLocationGuard.canCapture(gpsEnabled: true, altitude: null),
        isFalse,
      );
      expect(
        CaptureLocationGuard.canCapture(gpsEnabled: true, altitude: 42.3),
        isTrue,
      );
      expect(CaptureLocationGuard.missingGpsMessage, 'Veuillez activer le GPS');
    });
  });

  group('line form payload', () {
    test('average altitude does not write point coordinate Z fields', () {
      final payload = <String, dynamic>{};

      LineFormPayloadService.applyAverageAltitude(payload, 42.75);

      expect(payload['altitude_z_moy'], 42.75);
      expect(payload.containsKey('ep_coor_z'), isFalse);
      expect(payload.containsKey('ass_coor_z'), isFalse);
    });
  });
}
