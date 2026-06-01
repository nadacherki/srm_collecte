import 'package:flutter_test/flutter_test.dart';
import 'package:srm_collecte/services/nmea_bridge_service.dart';

void main() {
  group('NmeaBridgeDevice', () {
    test('recognizes common GNSS receiver names for first auto-connect', () {
      expect(
        const NmeaBridgeDevice(
          name: 'Tersus OSCAR',
          address: '00:11:22:33:44:55',
        ).looksLikeGnssReceiver,
        isTrue,
      );
      expect(
        const NmeaBridgeDevice(
          name: 'Oscar RTK Rover',
          address: '00:11:22:33:44:55',
        ).looksLikeGnssReceiver,
        isTrue,
      );
      expect(
        const NmeaBridgeDevice(
          name: 'CHCNAV i89',
          address: '00:11:22:33:44:55',
        ).looksLikeGnssReceiver,
        isTrue,
      );
      expect(
        const NmeaBridgeDevice(
          name: 'Bluetooth Keyboard',
          address: '00:11:22:33:44:55',
        ).looksLikeGnssReceiver,
        isFalse,
      );
    });
  });
}
