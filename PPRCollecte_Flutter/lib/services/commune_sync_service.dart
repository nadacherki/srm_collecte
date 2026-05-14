import '../data/local/database_helper.dart';
import '../data/remote/api_service.dart';

class CommuneSyncService {
  final DatabaseHelper _db;

  CommuneSyncService({DatabaseHelper? databaseHelper})
      : _db = databaseHelper ?? DatabaseHelper();

  Future<Map<String, dynamic>> refreshCommunes() async {
    final communes = await ApiService.fetchCommunesOriental();
    await _db.replaceCommunes(communes: communes);
    return {
      'communes_count': communes.length,
    };
  }
}
