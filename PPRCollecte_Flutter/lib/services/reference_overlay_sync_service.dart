import '../data/local/database_helper.dart';
import '../data/remote/api_service.dart';
import 'zone_sync_service.dart';

class ReferenceOverlaySyncService {
  ReferenceOverlaySyncService({DatabaseHelper? databaseHelper})
      : _db = databaseHelper ?? DatabaseHelper();

  final DatabaseHelper _db;

  Future<Map<String, dynamic>> refreshLightOverlays() {
    return refreshOverlays();
  }

  Future<Map<String, dynamic>> refreshOverlays() async {
    final zonesResult =
        await ZoneSyncService(databaseHelper: _db).refreshZonesForCurrentUser();

    final planches = await ApiService.fetchPlancheOverlay();
    await _db.replacePlancheOverlay(planches: planches);

    return {
      ...zonesResult,
      'planches_count': planches.length,
    };
  }
}
