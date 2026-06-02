class CaptureLocationGuard {
  static const String missingGpsMessage = 'Veuillez activer le GPS';
  static const String externalGnssRequiredMessage =
      'Connexion GNSS externe obligatoire pour les agents.';
  static const String missingAccuracyMessage =
      'Precision GNSS indisponible. Attendez un fix fiable.';

  // Seuil dual : mode agent terrain (allowInternalSources=false) exige une
  // precision RTK-grade (50 cm) pour garantir la qualite topo des leves.
  // Mode admin / debug accepte jusqu'a 5 m. Garde 'maxCaptureAccuracyMeters'
  // comme alias compatible (consomme par home_page_collection_actions).
  static const double agentMaxAccuracyMeters = 0.5;
  static const double adminMaxAccuracyMeters = 5.0;
  static const double maxCaptureAccuracyMeters = adminMaxAccuracyMeters;
  static const Set<int> agentAllowedFixQualities = {4, 5};
  static const int agentMinSatellites = 8;
  static const double agentMaxHdop = 1.0;

  static bool canCapture({
    required bool gpsEnabled,
    required double? altitude,
    double? accuracyMeters,
    String? sourceLabel,
    int? fixQuality,
    int? satellites,
    double? hdop,
    bool allowInternalSources = true,
  }) {
    return blockReason(
          gpsEnabled: gpsEnabled,
          altitude: altitude,
          accuracyMeters: accuracyMeters,
          sourceLabel: sourceLabel,
          fixQuality: fixQuality,
          satellites: satellites,
          hdop: hdop,
          allowInternalSources: allowInternalSources,
        ) ==
        null;
  }

  static String? blockReason({
    required bool gpsEnabled,
    required double? altitude,
    double? accuracyMeters,
    String? sourceLabel,
    int? fixQuality,
    int? satellites,
    double? hdop,
    bool allowInternalSources = true,
  }) {
    final normalizedSource = _normalizeSourceLabel(sourceLabel ?? '');
    if (normalizedSource.contains('deconnect')) {
      return 'Connexion GNSS externe perdue. Reconnectez le récepteur.';
    }
    if (normalizedSource.contains('expir')) {
      return 'Fix GNSS expiré. Attendez un nouveau fix du récepteur.';
    }
    if (normalizedSource.contains('attente fix')) {
      return 'GNSS externe connecte, en attente de fix.';
    }

    if (!gpsEnabled || altitude == null) {
      return missingGpsMessage;
    }

    if (!allowInternalSources) {
      final isExternalGnss = normalizedSource == 'gnss xyz' ||
          normalizedSource == 'gnss lat/lon converti';
      if (!isExternalGnss) {
        if (normalizedSource.startsWith('gnss')) {
          return 'Source GNSS externe non reconnue pour la capture terrain.';
        }
        return externalGnssRequiredMessage;
      }

      final qualityReason = _agentRtkQualityBlockReason(
        fixQuality: fixQuality,
        satellites: satellites,
        hdop: hdop,
      );
      if (qualityReason != null) {
        return qualityReason;
      }
    }

    if (accuracyMeters == null ||
        accuracyMeters.isNaN ||
        accuracyMeters.isInfinite) {
      return missingAccuracyMessage;
    }

    final maxAccuracy =
        allowInternalSources ? adminMaxAccuracyMeters : agentMaxAccuracyMeters;
    if (accuracyMeters > maxAccuracy) {
      return 'Precision GNSS insuffisante '
          '(${accuracyMeters.toStringAsFixed(2)} m > '
          '${maxAccuracy.toStringAsFixed(2)} m).';
    }

    return null;
  }

  static String? _agentRtkQualityBlockReason({
    required int? fixQuality,
    required int? satellites,
    required double? hdop,
  }) {
    if (fixQuality == null || !agentAllowedFixQualities.contains(fixQuality)) {
      return 'Fix RTK requis pour enregistrer ce leve.';
    }

    if (satellites == null || satellites < agentMinSatellites) {
      return 'Nombre de satellites insuffisant pour enregistrer ce leve.';
    }

    if (hdop == null || hdop.isNaN || hdop.isInfinite || hdop > agentMaxHdop) {
      return 'Qualite GNSS insuffisante pour enregistrer ce leve.';
    }

    return null;
  }

  static String _normalizeSourceLabel(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('\u00e9', 'e')
        .replaceAll('\u00e8', 'e')
        .replaceAll('\u00ea', 'e')
        .replaceAll('\u00eb', 'e');
  }
}
