import 'package:flutter_test/flutter_test.dart';
import 'package:srm_collecte/services/capture_location_guard.dart';
import 'package:srm_collecte/services/draft_service.dart';

void main() {
  group('draft rules', () {
    test('automatic coordinates and neutral defaults do not create drafts', () {
      final meaningful = DraftService.hasMeaningfulDraftContent(
        formData: {
          'ep_coor_x': '819605.686',
          'ep_coor_y': '459013.134',
          'ep_coor_z': '41.250',
          'altitude_gps': '41.250',
          'ep_conf_plan': 'Objet decouvert',
          'anomalie': 'Non',
        },
        extraState: {
          'type_anomalie': 'Non',
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
}
