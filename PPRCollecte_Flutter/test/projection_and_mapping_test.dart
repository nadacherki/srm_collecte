import 'package:flutter_test/flutter_test.dart';
import 'package:srm_collecte/services/attribut_config_mobile_service.dart';
import 'package:srm_collecte/services/projection_service.dart';

void main() {
  group('ProjectionService', () {
    test('round-trips Oujda WGS84 coordinates through Merchich Nord', () {
      final service = ProjectionService();
      const longitude = -1.9086;
      const latitude = 34.6814;

      final merchich = service.wgs84ToMerchich(
        longitude: longitude,
        latitude: latitude,
      );
      final wgs84 = service.merchichToWgs84(
        x: merchich.x,
        y: merchich.y,
      );

      expect(merchich.x, greaterThan(700000));
      expect(merchich.y, greaterThan(400000));
      expect(wgs84.longitude, closeTo(longitude, 0.000001));
      expect(wgs84.latitude, closeTo(latitude, 0.000001));
    });

    test('projects coordinate lists without changing order or shape', () {
      final service = ProjectionService();
      final source = [
        [-1.90, 34.68],
        [-1.91, 34.69],
      ];

      final merchich = service.wgs84ListToMerchich(source);
      final back = service.merchichListToWgs84(merchich);

      expect(merchich, hasLength(2));
      expect(merchich.first, hasLength(2));
      expect(back.first[0], closeTo(source.first[0], 0.000001));
      expect(back.first[1], closeTo(source.first[1], 0.000001));
      expect(back.last[0], closeTo(source.last[0], 0.000001));
      expect(back.last[1], closeTo(source.last[1], 0.000001));
    });
  });

  group('AttributConfigMobileService table mapping', () {
    test('keeps compteur réseau and compteur abonné mapped distinctly', () {
      expect(
        AttributConfigMobileService.mobileTableForConfigTable(
          'ep',
          'ep_compteur_i',
        ),
        'compteur_reseau',
      );
      expect(
        AttributConfigMobileService.mobileTableForConfigTable(
          'ep',
          'ep_brc_pt',
        ),
        'compteur_abonne',
      );
      expect(
        AttributConfigMobileService.configTableForMobileTable(
          'ep',
          'compteur_reseau',
        ),
        'ep_compteur_i',
      );
      expect(
        AttributConfigMobileService.configTableForMobileTable(
          'ep',
          'compteur_abonne',
        ),
        'ep_brc_pt',
      );
    });

    test('maps ASST database tables to mobile runtime names', () {
      expect(
        AttributConfigMobileService.mobileTableForConfigTable(
          'asst',
          'ASS_REGARD',
        ),
        'asst_regard',
      );
      expect(
        AttributConfigMobileService.configTableForMobileTable(
          'asst',
          'asst_canalisation',
        ),
        'ASS_COLLECTEUR',
      );
    });
  });
}
