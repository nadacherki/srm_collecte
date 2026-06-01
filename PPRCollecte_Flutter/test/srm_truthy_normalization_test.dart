import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:srm_collecte/data/local/database_helper.dart';

// Phase B indexation : verifie que la migration normalise les valeurs legacy
// des colonnes `synced` et `downloaded` (texte 'true'/'t'/'1', NULL) en
// INTEGER 0/1 strict, pour que la comparaison directe `= 1` du filtre
// SrmRowVisibilityFilter trouve toutes les lignes et utilise les indexes.

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    await DatabaseHelper.resetForTest();
  });

  group('Phase B : normalisation synced / downloaded', () {
    test(
        'valeurs legacy texte (true/t/1) et NULL converties en INTEGER 0/1 '
        'au boot', () async {
      final db = await DatabaseHelper.openInMemoryDatabaseForTest();

      // On retire le drapeau pose par le 1er boot pour pouvoir injecter des
      // valeurs legacy et rejouer la normalisation.
      await db.delete(
        'app_metadata',
        where: 'key = ?',
        whereArgs: ['srm_truthy_normalized_v1'],
      );

      // Inject valeurs legacy. On utilise insert direct pour bypasser
      // _sanitizeSrmPayload qui forcerait deja en int.
      await db.execute(
        "INSERT INTO ep_regard_point (uuid, synced, downloaded) "
        "VALUES ('uuid-true', 'true', 't')",
      );
      await db.execute(
        "INSERT INTO ep_regard_point (uuid, synced, downloaded) "
        "VALUES ('uuid-text-1', '1', '0')",
      );
      await db.execute(
        "INSERT INTO ep_regard_point (uuid, synced, downloaded) "
        "VALUES ('uuid-null', NULL, NULL)",
      );
      await db.execute(
        "INSERT INTO ep_regard_point (uuid, synced, downloaded) "
        "VALUES ('uuid-false', 'false', 'f')",
      );

      // Force la migration en fermant et reouvrant. La reouverture passera
      // par onOpen -> _migrateExistingSrmTables -> _normalizeSrmTruthyColumns.
      // En test in-memory, on appelle simplement le helper qui re-trigger
      // la normalisation via une seconde ouverture.
      final helper = DatabaseHelper();
      // resetForTest fermerait la DB ; on prefere appliquer la normalisation
      // manuellement en relisant les valeurs apres avoir efface le drapeau.
      await helper.ensureSrmTruthyNormalizedForTest();

      final rows = await db.query(
        'ep_regard_point',
        columns: ['uuid', 'synced', 'downloaded'],
        orderBy: 'uuid',
      );
      final byUuid = <String, Map<String, dynamic>>{
        for (final row in rows) row['uuid'] as String: row,
      };

      expect(byUuid['uuid-true']!['synced'], 1);
      expect(byUuid['uuid-true']!['downloaded'], 1);

      expect(byUuid['uuid-text-1']!['synced'], 1);
      expect(byUuid['uuid-text-1']!['downloaded'], 0);

      expect(byUuid['uuid-null']!['synced'], 0);
      expect(byUuid['uuid-null']!['downloaded'], 0);

      expect(byUuid['uuid-false']!['synced'], 0);
      expect(byUuid['uuid-false']!['downloaded'], 0);
    });

    test('migration idempotente : 2e passage ne change rien', () async {
      final db = await DatabaseHelper.openInMemoryDatabaseForTest();
      final helper = DatabaseHelper();

      await db.execute(
        "INSERT INTO ep_regard_point (uuid, synced, downloaded) "
        "VALUES ('a', 1, 0)",
      );

      // Drapeau pose au 1er boot : on l'efface pour relancer.
      await db.delete(
        'app_metadata',
        where: 'key = ?',
        whereArgs: ['srm_truthy_normalized_v1'],
      );
      await helper.ensureSrmTruthyNormalizedForTest();

      final after1 = await db.query('ep_regard_point', where: "uuid = 'a'");

      // 2e passage : le drapeau a ete repose, donc skip immediat.
      await helper.ensureSrmTruthyNormalizedForTest();
      final after2 = await db.query('ep_regard_point', where: "uuid = 'a'");

      expect(after1, equals(after2));
      expect(after1.first['synced'], 1);
      expect(after1.first['downloaded'], 0);
    });

    test(
        'EXPLAIN QUERY PLAN du filtre visibilite utilise idx_*_synced '
        'apres normalisation', () async {
      final db = await DatabaseHelper.openInMemoryDatabaseForTest();

      final plan = await db.rawQuery(
        'EXPLAIN QUERY PLAN SELECT * FROM ep_regard_point '
        'WHERE downloaded = 1 OR synced = 1',
      );
      final planText = plan
          .map((row) => row.values.join(' '))
          .join('\n')
          .toLowerCase();

      // L'optimisation OR doit emprunter les 2 indexes.
      expect(planText, contains('idx_ep_regard_point_synced'));
      expect(planText, contains('idx_ep_regard_point_downloaded'));
    });
  });
}
