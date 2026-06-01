import 'package:flutter_test/flutter_test.dart';
import 'package:srm_collecte/core/constants/basemap_constants.dart';
import 'package:srm_collecte/services/online_basemap_service.dart';

void main() {
  group('OnlineBasemapService', () {
    test('probes only the OSM endpoint used by the online basemap', () async {
      final calls = <({String host, int port})>[];
      final service = OnlineBasemapService(
        socketProbe: (host, port) async {
          calls.add((host: host, port: port));
          return true;
        },
      );

      expect(await service.isReachable(), isTrue);
      expect(
        calls,
        equals([
          (
            host: BasemapConstants.onlineReachabilityHost,
            port: BasemapConstants.onlineReachabilityPort,
          ),
        ]),
      );
      expect(calls.single.host, equals('tile.openstreetmap.org'));
      expect(calls.single.host, isNot(contains('google')));
    });

    test('falls back when the OSM endpoint is unreachable', () async {
      final service = OnlineBasemapService(
        socketProbe: (_, __) async => false,
      );

      expect(await service.isReachable(), isFalse);
    });

    test('keeps the reachability endpoint aligned with the map tile URL', () {
      expect(
        BasemapConstants.onlineUrlTemplate,
        contains(BasemapConstants.onlineReachabilityHost),
      );
    });
  });
}
