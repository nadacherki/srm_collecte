import '../data/local/database_helper.dart';
import '../data/remote/api_service.dart';

class BasemapCatalogService {
  final DatabaseHelper _db;

  BasemapCatalogService({DatabaseHelper? databaseHelper})
      : _db = databaseHelper ?? DatabaseHelper();

  Future<Map<String, dynamic>> _persistCatalogPayload(
    Map<String, dynamic> payload,
  ) async {
    final zonesRaw = payload['zones'] as List? ?? const [];
    final packagesRaw = payload['packages'] as List? ?? const [];

    final zones = zonesRaw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final packages = packagesRaw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    await _db.replaceOfflineBasemapCatalog(
      zones: zones,
      packages: packages,
    );

    return {
      ...payload,
      'zones_count': zones.length,
      'packages_count': packages.length,
    };
  }

  Future<Map<String, dynamic>> refreshCatalog({
    String? citySlug,
    String? style,
    bool activeOnly = true,
  }) async {
    final payload = await ApiService.fetchBasemapCatalog(
      citySlug: citySlug,
      style: style,
      activeOnly: activeOnly,
    );
    return _persistCatalogPayload(payload);
  }

  Future<Map<String, dynamic>> prepareAssignedCatalog({
    String? citySlug,
    String? style,
    bool activeOnly = true,
    bool force = false,
  }) async {
    final payload = await ApiService.prepareAssignedBasemapCatalog(
      citySlug: citySlug,
      style: style,
      activeOnly: activeOnly,
      force: force,
    );
    return _persistCatalogPayload(payload);
  }
}
