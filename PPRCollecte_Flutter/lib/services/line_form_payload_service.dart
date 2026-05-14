class LineFormPayloadService {
  const LineFormPayloadService._();

  static void applyAverageAltitude(
    Map<String, dynamic> payload,
    double? averageAltitude,
  ) {
    if (averageAltitude == null) return;
    payload['altitude_z_moy'] = averageAltitude;
  }
}
