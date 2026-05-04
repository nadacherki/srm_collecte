import '../data/local/database_helper.dart';
import '../data/remote/api_service.dart';
import 'offline_basemap_service.dart';

class BasemapCatalogService {
  final DatabaseHelper _db;
  static const String _networkInterruptedMessage =
      'Connexion interrompue pendant le telechargement des cartes offline.';

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

  Future<Map<String, dynamic>> ensureGlobalCoverageDownloaded({
    String? citySlug,
    String? style,
    bool activeOnly = true,
    bool force = false,
  }) async {
    final payload = await prepareAssignedCatalog(
      citySlug: citySlug,
      style: style,
      activeOnly: activeOnly,
      force: force,
    );
    final packages = await _db.getOfflineBasemapPackages(
      citySlug: citySlug,
      style: style,
      activeOnly: activeOnly,
    );
    final selectedPackages = _selectAutomaticPackagePerZone(packages);

    var downloadedCount = 0;
    var alreadyAvailableCount = 0;
    var failedCount = 0;
    final errors = <String>[];
    final offlineService = OfflineBasemapService();

    for (final packageRow in selectedPackages) {
      final result = await offlineService.downloadCatalogPackage(packageRow);
      if (result.success && result.alreadyAvailable) {
        alreadyAvailableCount++;
      } else if (result.success) {
        downloadedCount++;
      } else {
        failedCount++;
        final zoneId = packageRow['zone_id']?.toString() ?? 'zone inconnue';
        final error =
            result.errorMessage ?? result.userMessage ?? 'échec inconnu';
        if (_isNetworkFailure(error)) {
          throw Exception(_networkInterruptedMessage);
        }
        errors.add('$zoneId: $error');
      }
    }

    return {
      ...payload,
      'mobile_selected_count': selectedPackages.length,
      'mobile_downloaded_count': downloadedCount,
      'mobile_already_available_count': alreadyAvailableCount,
      'mobile_failed_count': failedCount,
      'mobile_errors': errors,
    };
  }

  List<Map<String, dynamic>> _selectAutomaticPackagePerZone(
    List<Map<String, dynamic>> packages,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final packageRow in packages) {
      final zoneId = packageRow['zone_id']?.toString().trim();
      if (zoneId == null || zoneId.isEmpty) continue;
      grouped
          .putIfAbsent(zoneId, () => <Map<String, dynamic>>[])
          .add(packageRow);
    }

    final selected = <Map<String, dynamic>>[];
    for (final zonePackages in grouped.values) {
      zonePackages.sort(_compareAutomaticPackagePriority);
      selected.add(zonePackages.first);
    }
    return selected;
  }

  int _compareAutomaticPackagePriority(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final styleRankCompare =
        _automaticStyleRank(a).compareTo(_automaticStyleRank(b));
    if (styleRankCompare != 0) return styleRankCompare;

    final formatRankCompare =
        _automaticFormatRank(a).compareTo(_automaticFormatRank(b));
    if (formatRankCompare != 0) return formatRankCompare;

    final generatedAtA =
        DateTime.tryParse(a['generated_at']?.toString().trim() ?? '');
    final generatedAtB =
        DateTime.tryParse(b['generated_at']?.toString().trim() ?? '');
    if (generatedAtA != null && generatedAtB != null) {
      final generatedCompare = generatedAtB.compareTo(generatedAtA);
      if (generatedCompare != 0) return generatedCompare;
    } else if (generatedAtA != null) {
      return -1;
    } else if (generatedAtB != null) {
      return 1;
    }

    final versionA = a['version']?.toString().trim() ?? '';
    final versionB = b['version']?.toString().trim() ?? '';
    return versionB.compareTo(versionA);
  }

  int _automaticStyleRank(Map<String, dynamic> packageRow) {
    final style = packageRow['style']?.toString().trim().toLowerCase() ?? '';
    if (style == 'standard') return 0;
    return 1;
  }

  int _automaticFormatRank(Map<String, dynamic> packageRow) {
    final format = packageRow['format']?.toString().trim().toLowerCase() ?? '';
    if (format == 'pmtiles') return 0;
    if (format == 'mbtiles') return 1;
    return 2;
  }

  bool _isNetworkFailure(Object error) {
    final value = error.toString().toLowerCase();
    return value.contains('connexion interrompue') ||
        value.contains('erreur reseau') ||
        value.contains('erreur réseau') ||
        value.contains('erreur rã') ||
        value.contains('timeout') ||
        value.contains('socketexception') ||
        value.contains('clientexception') ||
        value.contains('failed host lookup') ||
        value.contains('connection refused') ||
        value.contains('connection reset') ||
        value.contains('connection closed') ||
        value.contains('network is unreachable') ||
        value.contains('no route to host') ||
        value.contains('software caused connection abort') ||
        value.contains('broken pipe');
  }
}
