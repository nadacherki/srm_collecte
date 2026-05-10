class CaptureLocationGuard {
  static const String missingGpsMessage = 'Veuillez activer le GPS';

  static bool canCapture({
    required bool gpsEnabled,
    required double? altitude,
  }) {
    return gpsEnabled && altitude != null;
  }
}
