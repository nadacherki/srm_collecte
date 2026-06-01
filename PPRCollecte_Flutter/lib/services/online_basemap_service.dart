import 'dart:io';

import '../core/constants/basemap_constants.dart';

typedef BasemapSocketProbe = Future<bool> Function(String host, int port);

class OnlineBasemapService {
  OnlineBasemapService({BasemapSocketProbe? socketProbe})
      : _socketProbe = socketProbe ?? _defaultSocketProbe;

  final BasemapSocketProbe _socketProbe;

  Future<bool> isReachable() {
    return _socketProbe(
      BasemapConstants.onlineReachabilityHost,
      BasemapConstants.onlineReachabilityPort,
    );
  }

  static Future<bool> _defaultSocketProbe(String host, int port) async {
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 1),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }
}
