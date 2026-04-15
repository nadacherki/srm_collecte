import '../data/local/database_helper.dart';
import '../data/remote/api_service.dart';

class SrmFieldOptionService {
  final DatabaseHelper _db;

  SrmFieldOptionService({DatabaseHelper? databaseHelper})
      : _db = databaseHelper ?? DatabaseHelper();

  Future<Map<String, dynamic>> refreshOptions({
    String? tableSchema,
    String? tableName,
    String? fieldName,
    bool activeOnly = true,
  }) async {
    final options = await ApiService.fetchSrmFieldOptions(
      tableSchema: tableSchema,
      tableName: tableName,
      fieldName: fieldName,
      activeOnly: activeOnly,
    );

    await _db.replaceSrmFieldOptions(
      options: options,
      tableSchema: tableSchema,
      tableName: tableName,
    );

    return {
      'table_schema': tableSchema,
      'table_name': tableName,
      'field_name': fieldName,
      'active_only': activeOnly,
      'options_count': options.length,
    };
  }
}
