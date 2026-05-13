class CaptureLocationGuard {
  static const String missingGpsMessage = 'Veuillez activer le GPS';
  static const String externalGnssRequiredMessage =
      'Connexion GNSS externe obligatoire pour les agents.';
  static const String missingAccuracyMessage =
      'Précision GNSS indisponible. Attendez un fix fiable.';
  static const double maxCaptureAccuracyMeters = 5.0;

  static bool canCapture({
    required bool gpsEnabled,
    required double? altitude,
    double? accuracyMeters,
    String? sourceLabel,
    bool allowInternalSources = true,
  }) {
    return blockReason(
          gpsEnabled: gpsEnabled,
          altitude: altitude,
          accuracyMeters: accuracyMeters,
          sourceLabel: sourceLabel,
          allowInternalSources: allowInternalSources,
        ) ==
        null;
  }

  static String? blockReason({
    required bool gpsEnabled,
    required double? altitude,
    double? accuracyMeters,
    String? sourceLabel,
    bool allowInternalSources = true,
  }) {
    if (!gpsEnabled || altitude == null) {
      return missingGpsMessage;
    }

    final normalizedSource = (sourceLabel ?? '').trim().toLowerCase();
    if (!allowInternalSources && !normalizedSource.startsWith('gnss externe')) {
      return externalGnssRequiredMessage;
    }

    if (accuracyMeters == null ||
        accuracyMeters.isNaN ||
        accuracyMeters.isInfinite) {
      return missingAccuracyMessage;
    }

    if (accuracyMeters > maxCaptureAccuracyMeters) {
      return 'Précision GNSS insuffisante '
          '(${accuracyMeters.toStringAsFixed(1)} m > '
          '${maxCaptureAccuracyMeters.toStringAsFixed(1)} m).';
    }

    return null;
  }
}
