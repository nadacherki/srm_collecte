import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class BasemapConstants {
  static const String catalogCitySlug = 'tamansourt_loudaya';
  static const String catalogCityLabel = 'Tamansourt - Loudaya';
  static const int requiredSrid = 26191;
  static const String onlineUrlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String onlineReachabilityHost = 'tile.openstreetmap.org';
  static const int onlineReachabilityPort = 443;

  // FlutterMap technical coordinates for the default view:
  // latitude = Y/Northing, longitude = X/Easting in EPSG:26191 meters.
  static const double fallbackCenterX = 228580.0;
  static const double fallbackCenterY = 118670.0;

  static const double fallbackCenterLatitude = 31.626071;
  static const double fallbackCenterLongitude = -8.256851;
  static const double fallbackDefaultZoom = 15.0;
  static const double fallbackMinZoom = 11.0;
  static const double fallbackMaxZoom = 19.0;
  static const double offlineOverzoomLevels = 4.0;

  static const double defaultMerchichOriginX = 0.0;
  static const double defaultMerchichOriginY = 1200000.0;
  static const List<double> defaultMerchichResolutions = [
    4096,
    2048,
    1024,
    512,
    256,
    128,
    64,
    32,
    16,
    8,
    4,
    2,
    1,
    0.5,
    0.25,
    0.125,
    0.0625,
    0.03125,
    0.015625,
    0.0078125,
  ];

  static const LatLng fallbackCenter = LatLng(
    fallbackCenterY,
    fallbackCenterX,
  );

  static final LatLngBounds fallbackBounds = LatLngBounds(
    const LatLng(31.7550, -8.1100),
    const LatLng(31.6260, -8.2570),
  );

  static const String unavailableMessage =
      "Aucune carte offline disponible pour votre zone pour le moment.";
  static const String invalidCrsMessage =
      "La carte offline active n'est pas en EPSG:26191 Merchich.";
}
