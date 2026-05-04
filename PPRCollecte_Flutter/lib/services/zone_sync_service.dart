import '../data/local/database_helper.dart';
import '../data/remote/api_service.dart';

class ZoneSyncService {
  ZoneSyncService({DatabaseHelper? databaseHelper})
      : _db = databaseHelper ?? DatabaseHelper();

  final DatabaseHelper _db;

  Future<Map<String, dynamic>> refreshZonesForCurrentUser() async {
    final zones = await ApiService.fetchZones();
    final affectations = await ApiService.fetchZoneUtilisateurs(
      idUser: ApiService.userId,
      activeOnly: true,
    );

    await _db.replaceZones(zones: zones);
    await _db.replaceZoneUtilisateurs(
      affectations: affectations,
      idUser: ApiService.userId,
    );

    return {
      'zones_count': zones.length,
      'affectations_count': affectations.length,
      'id_user': ApiService.userId,
    };
  }
}
