import '../data/local/database_helper.dart';
import '../data/remote/api_service.dart';
import 'zone_sync_service.dart';

class ReferenceOverlaySyncService {
  ReferenceOverlaySyncService({DatabaseHelper? databaseHelper})
      : _db = databaseHelper ?? DatabaseHelper();

  final DatabaseHelper _db;

  Future<Map<String, dynamic>> refreshLightOverlays() {
    return refreshOverlays(includeFondPlan: false);
  }

  Future<Map<String, dynamic>> refreshOverlays({
    bool includeFondPlan = false,
  }) async {
    final zonesResult =
        await ZoneSyncService(databaseHelper: _db).refreshZonesForCurrentUser();

    final planches = await ApiService.fetchPlancheOverlay();
    await _db.replacePlancheOverlay(planches: planches);

    var fondPlanCount = 0;
    if (includeFondPlan) {
      final fondPlan = await ApiService.fetchFondPlanOverlay();
      await _db.replaceFondPlanOverlay(features: fondPlan);
      fondPlanCount = fondPlan.length;
    }

    return {
      ...zonesResult,
      'planches_count': planches.length,
      'fond_plan_count': fondPlanCount,
    };
  }
}
