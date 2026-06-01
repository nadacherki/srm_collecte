import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:srm_collecte/data/local/database_helper.dart';

// Gap C - gate retour_terrain='oui' :
// Le doc bureau (INTERVENTION_TRIGGER_NOTES_MOBILE.md) exige que la
// creation d'une intervention soit conditionnee par `anomalie=oui` ET
// `retour_terrain='oui'` sur la ligne metier. Le code mobile gate ce
// declenchement dans `upsertLocalInterventionAnomalieSignalement`.
//
// Backward compat : si la colonne `retour_terrain` n'est pas presente
// dans rowData (table metier non encore migree), on retombe sur le
// comportement historique (workflow declenche des qu'anomalie=oui).

Future<int> _countShadows(
  DatabaseHelper helper, {
  required String nomTable,
  required int idObjet,
}) async {
  final db = await helper.database;
  final rows = await db.query(
    'intervention_anomalie',
    where: 'nom_table = ? AND id_objet = ?',
    whereArgs: [nomTable, idObjet],
  );
  return rows.length;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    await DatabaseHelper.resetForTest();
  });

  group('Gap C — gate retour_terrain', () {
    test('retour_terrain="oui" : shadow local cree', () async {
      await DatabaseHelper.openInMemoryDatabaseForTest();
      final helper = DatabaseHelper();
      await helper.upsertLocalInterventionAnomalieSignalement(
        schemaName: 'ep',
        tableName: 'ep_regard_point',
        idObjet: 101,
        uuidObjet: 'uuid-101',
        rowData: {
          'anomalie': 1,
          'retour_terrain': 'oui',
          'ep_observation': 'tampon scelle',
        },
      );
      expect(
        await _countShadows(
          helper,
          nomTable: 'ep.ep_regard_point',
          idObjet: 101,
        ),
        1,
      );
    });

    test('retour_terrain="non" : pas de shadow', () async {
      await DatabaseHelper.openInMemoryDatabaseForTest();
      final helper = DatabaseHelper();
      await helper.upsertLocalInterventionAnomalieSignalement(
        schemaName: 'ep',
        tableName: 'ep_regard_point',
        idObjet: 102,
        uuidObjet: 'uuid-102',
        rowData: {
          'anomalie': 1,
          'retour_terrain': 'non',
        },
      );
      expect(
        await _countShadows(
          helper,
          nomTable: 'ep.ep_regard_point',
          idObjet: 102,
        ),
        0,
      );
    });

    test('retour_terrain absent : backward compat (shadow cree)', () async {
      await DatabaseHelper.openInMemoryDatabaseForTest();
      final helper = DatabaseHelper();
      await helper.upsertLocalInterventionAnomalieSignalement(
        schemaName: 'ep',
        tableName: 'ep_compteur',
        idObjet: 103,
        uuidObjet: 'uuid-103',
        rowData: {
          'anomalie': 1,
          // pas de retour_terrain : table pas encore migree
        },
      );
      expect(
        await _countShadows(
          helper,
          nomTable: 'ep.ep_compteur',
          idObjet: 103,
        ),
        1,
      );
    });

    test('retour_terrain="oui" puis "non" : placeholder local efface',
        () async {
      await DatabaseHelper.openInMemoryDatabaseForTest();
      final helper = DatabaseHelper();

      // 1er enregistrement : retour_terrain=oui -> shadow cree
      await helper.upsertLocalInterventionAnomalieSignalement(
        schemaName: 'ep',
        tableName: 'ep_regard_point',
        idObjet: 104,
        uuidObjet: 'uuid-104',
        rowData: {
          'anomalie': 1,
          'retour_terrain': 'oui',
        },
      );
      expect(
        await _countShadows(
          helper,
          nomTable: 'ep.ep_regard_point',
          idObjet: 104,
        ),
        1,
      );

      // L'agent rebascule retour_terrain=non avant la 1ere sync : le
      // placeholder local doit etre efface (id_intervention <= 0).
      await helper.upsertLocalInterventionAnomalieSignalement(
        schemaName: 'ep',
        tableName: 'ep_regard_point',
        idObjet: 104,
        uuidObjet: 'uuid-104',
        rowData: {
          'anomalie': 1,
          'retour_terrain': 'non',
        },
      );
      expect(
        await _countShadows(
          helper,
          nomTable: 'ep.ep_regard_point',
          idObjet: 104,
        ),
        0,
      );
    });

    test('valeurs truthy variees acceptees (oui, true, 1, yes, t)',
        () async {
      await DatabaseHelper.openInMemoryDatabaseForTest();
      final helper = DatabaseHelper();
      const truthyValues = ['oui', 'OUI', 'true', '1', 'yes', 't'];
      for (var i = 0; i < truthyValues.length; i++) {
        final idObjet = 200 + i;
        await helper.upsertLocalInterventionAnomalieSignalement(
          schemaName: 'ep',
          tableName: 'ep_regard_point',
          idObjet: idObjet,
          uuidObjet: 'uuid-$idObjet',
          rowData: {
            'anomalie': 1,
            'retour_terrain': truthyValues[i],
          },
        );
        expect(
          await _countShadows(
            helper,
            nomTable: 'ep.ep_regard_point',
            idObjet: idObjet,
          ),
          1,
          reason: 'truthy value "${truthyValues[i]}" doit creer un shadow',
        );
      }
    });
  });
}
