import 'package:flutter_test/flutter_test.dart';
import 'package:srm_collecte/services/capture_location_guard.dart';
import 'package:srm_collecte/services/draft_service.dart';
import 'package:srm_collecte/services/line_form_payload_service.dart';
import 'package:srm_collecte/services/mobile_job_guard.dart';
import 'package:srm_collecte/services/mobile_readiness_service.dart';

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
          'mode_localisation': 'Leve topographique',
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
    test('points and lines require external RTK GNSS for agents', () {
      const goodRtk = (
        fixQuality: 4,
        satellites: 12,
        hdop: 0.7,
      );

      expect(
        CaptureLocationGuard.canCapture(gpsEnabled: false, altitude: null),
        isFalse,
      );
      expect(
        CaptureLocationGuard.canCapture(gpsEnabled: true, altitude: null),
        isFalse,
      );

      expect(
        CaptureLocationGuard.canCapture(
          gpsEnabled: true,
          altitude: 42.3,
          accuracyMeters: 0.05,
          sourceLabel: 'GNSS XYZ',
          fixQuality: goodRtk.fixQuality,
          satellites: goodRtk.satellites,
          hdop: goodRtk.hdop,
          allowInternalSources: false,
        ),
        isTrue,
      );
      expect(
        CaptureLocationGuard.canCapture(
          gpsEnabled: true,
          altitude: 42.3,
          accuracyMeters: 0.05,
          sourceLabel: 'GNSS lat/lon converti',
          fixQuality: goodRtk.fixQuality,
          satellites: goodRtk.satellites,
          hdop: goodRtk.hdop,
          allowInternalSources: false,
        ),
        isTrue,
      );
      expect(
        CaptureLocationGuard.canCapture(
          gpsEnabled: true,
          altitude: 42.3,
          accuracyMeters: 0.02,
          sourceLabel: 'GNSS lat/lon converti',
          fixQuality: 5,
          satellites: 10,
          hdop: 0.9,
          allowInternalSources: false,
        ),
        isTrue,
      );

      expect(
        CaptureLocationGuard.canCapture(
          gpsEnabled: true,
          altitude: 42.3,
          accuracyMeters: 0.5,
          sourceLabel: 'GNSS lat/lon converti',
          fixQuality: goodRtk.fixQuality,
          satellites: goodRtk.satellites,
          hdop: goodRtk.hdop,
          allowInternalSources: false,
        ),
        isTrue,
      );
      expect(
        CaptureLocationGuard.canCapture(
          gpsEnabled: true,
          altitude: 42.3,
          accuracyMeters: 0.51,
          sourceLabel: 'GNSS lat/lon converti',
          fixQuality: goodRtk.fixQuality,
          satellites: goodRtk.satellites,
          hdop: goodRtk.hdop,
          allowInternalSources: false,
        ),
        isFalse,
      );

      expect(
        CaptureLocationGuard.canCapture(
          gpsEnabled: true,
          altitude: 42.3,
          accuracyMeters: 0.05,
          sourceLabel: 'GNSS lat/lon converti',
          fixQuality: 2,
          satellites: goodRtk.satellites,
          hdop: goodRtk.hdop,
          allowInternalSources: false,
        ),
        isFalse,
      );
      expect(
        CaptureLocationGuard.canCapture(
          gpsEnabled: true,
          altitude: 42.3,
          accuracyMeters: 0.05,
          sourceLabel: 'GNSS lat/lon converti',
          fixQuality: goodRtk.fixQuality,
          satellites: 6,
          hdop: goodRtk.hdop,
          allowInternalSources: false,
        ),
        isFalse,
      );
      expect(
        CaptureLocationGuard.canCapture(
          gpsEnabled: true,
          altitude: 42.3,
          accuracyMeters: 0.05,
          sourceLabel: 'GNSS lat/lon converti',
          fixQuality: goodRtk.fixQuality,
          satellites: goodRtk.satellites,
          hdop: 1.4,
          allowInternalSources: false,
        ),
        isFalse,
      );

      expect(
        CaptureLocationGuard.canCapture(
          gpsEnabled: true,
          altitude: 42.3,
          accuracyMeters: 1.5,
          sourceLabel: 'GNSS XYZ',
          fixQuality: goodRtk.fixQuality,
          satellites: goodRtk.satellites,
          hdop: goodRtk.hdop,
          allowInternalSources: false,
        ),
        isFalse,
      );
      expect(
        CaptureLocationGuard.canCapture(
          gpsEnabled: true,
          altitude: 42.3,
          accuracyMeters: 1.5,
          sourceLabel: 'GNSS XYZ',
          allowInternalSources: true,
        ),
        isTrue,
      );

      expect(
        CaptureLocationGuard.canCapture(
          gpsEnabled: true,
          altitude: 42.3,
          accuracyMeters: 8.0,
          sourceLabel: 'GNSS XYZ',
          allowInternalSources: true,
        ),
        isFalse,
      );
      expect(
        CaptureLocationGuard.canCapture(
          gpsEnabled: true,
          altitude: 42.3,
          accuracyMeters: 0.05,
          sourceLabel: 'telephone',
          allowInternalSources: false,
        ),
        isFalse,
      );

      expect(CaptureLocationGuard.missingGpsMessage, 'Veuillez activer le GPS');
      expect(CaptureLocationGuard.agentMaxAccuracyMeters, 0.5);
      expect(CaptureLocationGuard.adminMaxAccuracyMeters, 5.0);
      expect(CaptureLocationGuard.agentAllowedFixQualities, {4, 5});
      expect(CaptureLocationGuard.agentMinSatellites, 8);
      expect(CaptureLocationGuard.agentMaxHdop, 1.0);
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

  group('mobile job guard', () {
    test('allows a single download or sync job at a time', () {
      final guard = MobileJobGuard();

      expect(guard.tryStart(MobileJobType.download), isTrue);
      expect(guard.activeJob, MobileJobType.download);
      expect(guard.tryStart(MobileJobType.sync), isFalse);
      expect(guard.activeJob, MobileJobType.download);

      guard.finish(MobileJobType.sync);
      expect(guard.activeJob, MobileJobType.download);

      guard.finish(MobileJobType.download);
      expect(guard.activeJob, isNull);
      expect(guard.tryStart(MobileJobType.sync), isTrue);
      expect(guard.activeJob, MobileJobType.sync);
    });
  });

  group('mobile readiness result', () {
    test('uses explicit blocking messages by priority', () {
      const expired = MobileReadinessResult(
        issues: [MobileReadinessIssue.sessionExpired],
        userId: null,
        formulaireConfigCount: 0,
        attributConfigCount: 0,
        zoneAssignmentCount: 0,
        assignedZoneCount: 0,
      );
      expect(expired.isReady, isFalse);
      expect(
        expired.blockingMessage,
        'Session expirée. Veuillez vous reconnecter.',
      );

      const missingConfig = MobileReadinessResult(
        issues: [MobileReadinessIssue.mobileConfigMissing],
        userId: 19,
        formulaireConfigCount: 0,
        attributConfigCount: 0,
        zoneAssignmentCount: 1,
        assignedZoneCount: 1,
      );
      expect(
        missingConfig.blockingMessage,
        contains('Configuration mobile absente'),
      );

      const missingZone = MobileReadinessResult(
        issues: [MobileReadinessIssue.zoneAssignmentMissing],
        userId: 19,
        formulaireConfigCount: 20,
        attributConfigCount: 100,
        zoneAssignmentCount: 0,
        assignedZoneCount: 0,
      );
      expect(missingZone.blockingMessage, contains('Aucune zone affectée'));
    });
  });
}
