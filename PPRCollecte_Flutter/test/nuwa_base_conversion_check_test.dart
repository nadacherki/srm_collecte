import 'package:flutter_test/flutter_test.dart';
import 'package:srm_collecte/services/gnss_config_service.dart';
import 'package:srm_collecte/services/projection_service.dart';

// Reference terrain : ecran Nuwa "Edit Base Config", systeme Merchich corrige.
// BLH(WGS84) <-> NEH(Local Merchich) du meme point de base.
void main() {
  const lat = 33.5797232972; // BLH Lat
  const lon = -7.6767671923; // BLH Lon
  const hWgs84 = 96.5629; // BLH Height (hauteur ellipsoidale WGS84)
  const nuwaN = 333608.5789; // NEH Northing
  const nuwaE = 288574.7976; // NEH Easting
  const nuwaElev = 55.6999; // NEH Elevation (au centre de phase antenne)

  group('Nuwa Merchich — conversion WGS84 -> EPSG:26191', () {
    test('X/Y : ProjectionService matche le NEH Nuwa au cm pres', () {
      final r =
          ProjectionService().wgs84ToMerchich(longitude: lon, latitude: lat);
      expect(r.x, closeTo(nuwaE, 0.05));
      expect(r.y, closeTo(nuwaN, 0.05));
    });

    test('Z : wgs84HeightToMerchich matche le NEH Elevation Nuwa au cm pres',
        () {
      final z = ProjectionService().wgs84HeightToMerchich(
        longitude: lon,
        latitude: lat,
        ellipsoidalHeight: hWgs84,
      );
      // Transformation de datum pure (~40.863 m ici), sans modele de geoide.
      expect(z, closeTo(nuwaElev, 0.05));
    });

    test('Z sol = elevation Merchich antenne - hauteur canne rover', () {
      final zAntenne = ProjectionService().wgs84HeightToMerchich(
        longitude: lon,
        latitude: lat,
        ellipsoidalHeight: hWgs84,
      );
      // Setup terrain : canne rover 1.00 m (default GnssRoverConfig =
      // Tersus OSCAR Vertical). En Vertical Tersus l'offset = H brut = 1.00,
      // donc le Z sol reste nuwaElev - 1.00 (l'AntCenter n'est PAS ajoute
      // en methode Vertical).
      final hRover = GnssRoverConfig.fallback;
      final zSol = zAntenne - hRover.apcToGroundVerticalOffset;
      expect(zSol, closeTo(nuwaElev - 1.00, 0.05));
    });
  });
}
