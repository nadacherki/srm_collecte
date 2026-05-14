import '../data/local/database_helper.dart';
import '../data/remote/api_service.dart';

class SrmFieldChoice {
  final String fieldName;
  final String code;
  final String label;
  final int displayOrder;

  const SrmFieldChoice({
    required this.fieldName,
    required this.code,
    required this.label,
    required this.displayOrder,
  });

  factory SrmFieldChoice.fromRow(Map<String, dynamic> row) {
    final code = (row['code_value'] ?? '').toString().trim();
    final label = (row['label_value'] ?? '').toString().trim();
    return SrmFieldChoice(
      fieldName: (row['field_name'] ?? '').toString().trim(),
      code: code,
      label: label.isNotEmpty ? label : code,
      displayOrder: _toInt(row['display_order']) ?? 0,
    );
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().trim());
  }
}

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

  Future<Map<String, List<SrmFieldChoice>>> getOptionsByField({
    required String tableSchema,
    required String tableName,
    Iterable<String>? fieldNames,
    bool refreshIfEmpty = true,
  }) async {
    final allowedFields = fieldNames
        ?.map((field) => field.trim())
        .where((field) => field.isNotEmpty)
        .toSet();

    var rows = await _db.getSrmFieldOptions(
      tableSchema: tableSchema,
      tableName: tableName,
    );

    if (rows.isEmpty && refreshIfEmpty) {
      await refreshOptions(tableSchema: tableSchema, tableName: tableName);
      rows = await _db.getSrmFieldOptions(
        tableSchema: tableSchema,
        tableName: tableName,
      );
    }

    final grouped = <String, List<SrmFieldChoice>>{};
    final seenCodesByField = <String, Set<String>>{};
    for (final row in rows) {
      final choice = SrmFieldChoice.fromRow(row);
      if (choice.fieldName.isEmpty || choice.code.isEmpty) continue;
      if (allowedFields != null && !allowedFields.contains(choice.fieldName)) {
        continue;
      }

      final seenCodes =
          seenCodesByField.putIfAbsent(choice.fieldName, () => <String>{});
      if (!seenCodes.add(choice.code)) continue;

      grouped.putIfAbsent(choice.fieldName, () => <SrmFieldChoice>[]);
      grouped[choice.fieldName]!.add(choice);
    }

    for (final choices in grouped.values) {
      choices.sort((a, b) {
        final byOrder = a.displayOrder.compareTo(b.displayOrder);
        if (byOrder != 0) return byOrder;
        return a.label.compareTo(b.label);
      });
    }

    return grouped;
  }
}
