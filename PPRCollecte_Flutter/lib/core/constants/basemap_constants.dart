import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class BasemapConstants {
  static const String catalogCitySlug = 'oujda';
  static const String catalogCityLabel = 'Oujda';

  static const double fallbackCenterLatitude = 34.683100;
  static const double fallbackCenterLongitude = -1.909800;
  static const double fallbackDefaultZoom = 13.0;
  static const double fallbackMinZoom = 11.0;
  static const double fallbackMaxZoom = 19.0;

  static final LatLng fallbackCenter = const LatLng(
    fallbackCenterLatitude,
    fallbackCenterLongitude,
  );

  static final LatLngBounds fallbackBounds = LatLngBounds(
    const LatLng(34.7380, -1.9800),
    const LatLng(34.6220, -1.8400),
  );

  static const String unavailableMessage =
      "Aucune carte hors ligne active n'est encore disponible sur ce mobile.";
}
