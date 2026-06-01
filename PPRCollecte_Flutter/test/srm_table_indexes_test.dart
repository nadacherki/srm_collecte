import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:srm_collecte/data/local/database_helper.dart';

// Phase A indexation : verifie que les tables SRM dynamiques recoivent bien
// les indexes recurrents (sync, uuid, visibilite agent, identifiants metier,
// bbox spatial) a la creation, via `_createSrmTableIndexes`.

Future<Set<String>> _indexesFor(Database db, String table) async {
  final rows = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name=?",
    [table],
  );
  return rows
      .map((row) => (row['name'] ?? '').toString())
      .where((name) => name.isNotEmpty && !name.startsWith('sqlite_autoindex'))
      .toSet();
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    await DatabaseHelper.resetForTest();
  });

  group('SRM dynamic tables : indexes Phase A', () {
    test('ep_regard_point recoit les indexes de sync, uuid, et metier',
        () async {
      final db = await DatabaseHelper.openInMemoryDatabaseForTest();

      final indexes = await _indexesFor(db, 'ep_regard_point');

      // Au minimum : sync pipeline + visibilite agent + spatial.
      // `uuid TEXT UNIQUE` est couvert par l'auto-index SQLite, on ne le
      // duplique pas explicitement.
      expect(indexes, contains('idx_ep_regard_point_synced'));
      expect(indexes, contains('idx_ep_regard_point_downloaded'));
      expect(indexes, contains('idx_ep_regard_point_fid'));
      expect(indexes, contains('idx_ep_regard_point_id_planche'));
      expect(indexes, contains('idx_ep_regard_point_id_commune'));
      expect(indexes, contains('idx_ep_regard_point_date_collecte'));
      expect(indexes, contains('idx_ep_regard_point_lat_lng'));
    });

    test('CREATE INDEX IF NOT EXISTS est idempotent (rebuild sans erreur)',
        () async {
      final db = await DatabaseHelper.openInMemoryDatabaseForTest();
      final before = await _indexesFor(db, 'ep_regard_point');
      // Tableau metier non vide a la 1ere ouverture.
      expect(before, isNotEmpty);

      // Re-jouer un CREATE INDEX IF NOT EXISTS sur un index deja pose
      // (simule un re-boot) ne doit ni lever ni dupliquer.
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_ep_regard_point_synced '
        'ON ep_regard_point(synced)',
      );
      final after = await _indexesFor(db, 'ep_regard_point');
      expect(after, equals(before));
    });

    test('EXPLAIN QUERY PLAN sur synced utilise l index', () async {
      final db = await DatabaseHelper.openInMemoryDatabaseForTest();

      final plan = await db.rawQuery(
        'EXPLAIN QUERY PLAN SELECT * FROM ep_regard_point WHERE synced = 0',
      );
      final planText = plan
          .map((row) => row.values.join(' '))
          .join('\n')
          .toLowerCase();
      expect(planText, contains('idx_ep_regard_point_synced'));
    });

    test('EXPLAIN QUERY PLAN sur uuid utilise l auto-index UNIQUE', () async {
      final db = await DatabaseHelper.openInMemoryDatabaseForTest();

      final plan = await db.rawQuery(
        'EXPLAIN QUERY PLAN SELECT * FROM ep_regard_point WHERE uuid = ?',
        ['some-uuid'],
      );
      final planText = plan
          .map((row) => row.values.join(' '))
          .join('\n')
          .toLowerCase();
      // L'auto-index UNIQUE (sqlite_autoindex_*) couvre le lookup uuid.
      expect(planText, contains('using index'));
      expect(planText, contains('ep_regard_point'));
    });
  });
}
