import 'dart:convert';

import '../data/local/database_helper.dart';
import '../data/remote/api_service.dart';
import 'projection_service.dart';

/// Verifie si une position GPS tombe dans une zone d'affectation active de
/// l'agent connecte. Charge `zone_local` joined avec `zone_utilisateur_local`,
/// reprojette la position WGS84 vers EPSG:26191 (Merchich) et fait un test
/// point-in-polygon par ray casting.
///
/// Comportement attendu cote home_page : si la fonction retourne `false`, on
/// affiche un dialog de confirmation "vous etes hors de vos zones" SANS
/// bloquer la collecte. Si aucune zone n'est affectee (cas atypique), on
/// retourne `true` (pas de warning intempestif).
class ZoneAffectationCheckService {
  ZoneAffectationCheckService({DatabaseHelper? databaseHelper})
      : _db = databaseHelper ?? DatabaseHelper();

  final DatabaseHelper _db;

  // Cache des contours en EPSG:26191. Une zone = liste de rings, chaque ring
  // = liste de [x, y]. Rebuild lors du premier check ou apres invalidation.
  List<List<List<List<double>>>>? _cachedPolygons;
  int? _cachedUserId;

  void invalidateCache() {
    _cachedPolygons = null;
    _cachedUserId = null;
  }

  Future<bool> isLatLngInsideAssignedZones(double lat, double lng) async {
    final userId = ApiService.userId;
    if (userId == null) return true; // pas d'agent identifie -> on laisse passer

    if (_cachedUserId != userId) {
      _cachedPolygons = null;
      _cachedUserId = userId;
    }

    final polygons = _cachedPolygons ?? await _loadPolygonsForUser(userId);
    _cachedPolygons = polygons;

    if (polygons.isEmpty) {
      // Aucune zone affectee localement -> on ne genere pas de warning,
      // le pre-check du bouton Telecharger gere deja ce cas.
      return true;
    }

    final merchich = ProjectionService()
        .wgs84ToMerchich(longitude: lng, latitude: lat);
    return _isPointInAnyPolygon(merchich.x, merchich.y, polygons);
  }

  Future<List<List<List<List<double>>>>> _loadPolygonsForUser(int userId) async {
    final zones = await _db.getZonesLocal(idUser: userId, activeOnly: true);
    final polygons = <List<List<List<double>>>>[];
    for (final z in zones) {
      final rawGeom = z['geometry_geojson']?.toString();
      if (rawGeom == null || rawGeom.isEmpty) continue;
      final parsed = _parseGeoJsonPolygon(rawGeom);
      if (parsed.isNotEmpty) {
        polygons.add(parsed);
      }
    }
    return polygons;
  }

  /// Renvoie la liste des rings (outer + holes) en coordonnees [x, y].
  /// Supporte les types GeoJSON `Polygon` et `MultiPolygon`. Les coordonnees
  /// sont supposees etre deja en EPSG:26191 (c'est le stockage cote serveur).
  List<List<List<double>>> _parseGeoJsonPolygon(String rawGeom) {
    try {
      final decoded = jsonDecode(rawGeom);
      if (decoded is! Map) return const [];
      final type = decoded['type']?.toString().toLowerCase();
      final coords = decoded['coordinates'];
      if (type == 'polygon' && coords is List) {
        return _ringsFromCoords(coords);
      }
      if (type == 'multipolygon' && coords is List) {
        final all = <List<List<double>>>[];
        for (final poly in coords) {
          if (poly is List) all.addAll(_ringsFromCoords(poly));
        }
        return all;
      }
    } catch (_) {
      // GeoJSON malforme : on ignore silencieusement, l'agent verra juste
      // un warning si la position est en dehors d'une autre zone valide.
    }
    return const [];
  }

  List<List<List<double>>> _ringsFromCoords(List<dynamic> rings) {
    final out = <List<List<double>>>[];
    for (final ring in rings) {
      if (ring is! List) continue;
      final pts = <List<double>>[];
      for (final pt in ring) {
        if (pt is! List || pt.length < 2) continue;
        final x = (pt[0] as num).toDouble();
        final y = (pt[1] as num).toDouble();
        pts.add([x, y]);
      }
      if (pts.length >= 3) out.add(pts);
    }
    return out;
  }

  bool _isPointInAnyPolygon(
    double x,
    double y,
    List<List<List<List<double>>>> polygons,
  ) {
    for (final rings in polygons) {
      if (rings.isEmpty) continue;
      final outer = rings.first;
      if (!_isPointInRing(x, y, outer)) continue;
      // Sur Polygon : verifie qu'on n'est pas dans un trou.
      var insideHole = false;
      for (var i = 1; i < rings.length; i++) {
        if (_isPointInRing(x, y, rings[i])) {
          insideHole = true;
          break;
        }
      }
      if (!insideHole) return true;
    }
    return false;
  }

  /// Ray casting : compte les intersections entre une demi-droite horizontale
  /// partant de (x,y) vers +x et chaque segment du ring. Impair = dedans.
  bool _isPointInRing(double x, double y, List<List<double>> ring) {
    var inside = false;
    final n = ring.length;
    var j = n - 1;
    for (var i = 0; i < n; i++) {
      final xi = ring[i][0];
      final yi = ring[i][1];
      final xj = ring[j][0];
      final yj = ring[j][1];
      final intersects = ((yi > y) != (yj > y)) &&
          (x < (xj - xi) * (y - yi) / ((yj - yi) == 0 ? 1e-12 : (yj - yi)) + xi);
      if (intersects) inside = !inside;
      j = i;
    }
    return inside;
  }
}
