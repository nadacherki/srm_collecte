// lib/core/constants/projection_constants.dart
// Constantes pour la projection Merchich Nord (EPSG:26191)
// Utilisé par projection_service.dart pour transformer WGS84 <-> Merchich Nord

class ProjectionConstants {
  /// EPSG:26191 - Merchich / Nord Maroc
  /// Projection conique conforme de Lambert
  static const String merchichNordProj4 =
      '+proj=lcc +lat_1=33.3 +lat_0=33.3 +lon_0=-5.4 '
      '+k_0=0.999625769 +x_0=500000 +y_0=300000 '
      '+a=6378249.2 +b=6356515 '
      '+towgs84=31,146,47,0,0,0,0 +units=m +no_defs';

  /// EPSG:4326 - WGS84 (système GPS natif)
  static const String wgs84Proj4 = '+proj=longlat +datum=WGS84 +no_defs';

  /// SRID utilisé dans la base PostGIS SRM
  static const int sridMerchich = 26191;

  /// SRID WGS84 (coordonnées GPS)
  static const int sridWgs84 = 4326;

  /// Centre par défaut de la carte (Maroc - Casablanca approximatif)
  static const double defaultLatitude = 33.5731;
  static const double defaultLongitude = -7.5898;
  static const double defaultZoom = 12.0;

  /// Centre de la carte pour vue générale Maroc
  static const double moroccoLatitude = 31.7917;
  static const double moroccoLongitude = -7.0926;
  static const double moroccoZoom = 6.0;
}
// SRM metadata refresh.
