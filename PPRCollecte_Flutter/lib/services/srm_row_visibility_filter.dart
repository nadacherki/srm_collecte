class SrmRowVisibilityFilter {
  final String? where;
  final List<Object?>? whereArgs;

  const SrmRowVisibilityFilter._({this.where, this.whereArgs});

  static const none = SrmRowVisibilityFilter._();

  static const List<String> defaultUserColumns = <String>[
    'id_agent_crea',
    'id_user_creat',
    'saved_by_user_id',
    'login_id',
  ];

  static SrmRowVisibilityFilter build({
    required Set<String> availableColumns,
    required int? loginId,
    Iterable<String> userColumns = defaultUserColumns,
  }) {
    final filters = <String>[];
    final args = <Object?>[];

    for (final column in const ['downloaded', 'synced']) {
      if (availableColumns.contains(column)) {
        filters.add(_truthySql(column));
      }
    }

    if (loginId != null) {
      for (final column in userColumns) {
        if (availableColumns.contains(column)) {
          filters.add('$column = ?');
          args.add(loginId);
        }
      }
    }

    if (filters.isEmpty) {
      return none;
    }

    return SrmRowVisibilityFilter._(
      where: filters.join(' OR '),
      whereArgs: args.isEmpty ? null : args,
    );
  }

  String get rawWhereClause => where == null ? '' : ' WHERE $where';

  List<Object?> get rawArgs => whereArgs ?? const <Object?>[];

  static String _truthySql(String column) {
    return "LOWER(CAST(COALESCE($column, 0) AS TEXT)) IN ('1', 'true', 't')";
  }
}
