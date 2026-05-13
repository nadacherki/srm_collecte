import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:srm_collecte/data/local/database_helper.dart';
import 'package:srm_collecte/services/attribut_config_mobile_service.dart';
import 'package:srm_collecte/services/formulaire_config_mobile_service.dart';
import 'package:srm_collecte/services/srm_field_option_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    await DatabaseHelper.resetForTest();
  });

  group('mobile config services', () {
    test('profile entities use formulaire_config_mobile visibility/order',
        () async {
      await DatabaseHelper.openInMemoryDatabaseForTest(
        includeSrmEntityTables: false,
      );
      final helper = DatabaseHelper();
      await helper.replaceFormulaireConfigMobile(rows: [
        {
          'id': 1,
          'nom_metier': 'ep',
          'nom_table': 'ep_conduite',
          'titre_app': 'Conduite bureau',
          'ordre': 1,
          'visible': false,
          'download_mobile': false,
        },
        {
          'id': 2,
          'nom_metier': 'ep',
          'nom_table': 'ep_vanne',
          'titre_app': 'Vanne terrain',
          'ordre': 2,
          'visible': true,
          'download_mobile': true,
        },
        {
          'id': 3,
          'nom_metier': 'ep',
          'nom_table': 'onep_db',
          'titre_app': 'ONEP DB',
          'ordre': 99,
          'visible': false,
          'download_mobile': true,
        },
        {
          'id': 4,
          'nom_metier': 'ep',
          'nom_table': 'ep_regard',
          'titre_app': 'Regard miroir',
          'ordre': 3,
          'visible': true,
          'download_mobile': true,
        },
      ]);

      final service = FormulaireConfigMobileService(databaseHelper: helper);
      final entities = await service.getMobileEntities(
        mobileMetier: 'Eau Potable',
        geometryFilter: 'point',
        refreshIfEmpty: false,
      );
      final downloadable = await service.getFormulaires(
        nomMetier: 'ep',
        downloadOnly: true,
        refreshIfEmpty: false,
      );

      expect(entities.map((entity) => entity.tableName), contains('vanne'));
      expect(
        entities.map((entity) => entity.tableName),
        isNot(contains('ep_conduite')),
      );
      expect(
        entities.map((entity) => entity.tableName),
        isNot(contains('ep_regard')),
      );
      expect(entities.single.titleApp, 'Vanne terrain');
      expect(
        downloadable.map((item) => item.nomTable),
        containsAll({'ep_vanne', 'onep_db'}),
      );
      expect(
        FormulaireConfigMobileService.isSelectableFormTable('ep_regard'),
        isFalse,
      );
      expect(
        FormulaireConfigMobileService.isSelectableFormTable('ep_regard_point'),
        isTrue,
      );
    });

    test('attribut config exposes defaults, required flag and numeric bounds',
        () {
      final field = AttributConfigMobileField.fromMap({
        'id': 10,
        'nom_metier': 'ep',
        'nom_table': 'ep_brc_pt',
        'nom_champ': 'diametre',
        'type_champ': 'integer',
        'primary_key': false,
        'foreign_key': false,
        'ordre': 3,
        'titre_app': 'Diametre',
        'visible': true,
        'contraintes': '',
        'nullable': false,
        'valeur_par_defaut': '20',
        'valeur_min': '15',
        'valeur_max': '400',
        'reference_fk': '',
      });

      expect(field.isRequired, isTrue);
      expect(field.valeurParDefaut, '20');
      expect(field.numericMin, 15);
      expect(field.numericMax, 400);

      final optionalField = AttributConfigMobileField.fromMap({
        'id': 11,
        'nom_metier': 'ep',
        'nom_table': 'ep_brc_pt',
        'nom_champ': 'observation',
        'type_champ': 'text',
        'primary_key': false,
        'foreign_key': false,
        'ordre': 4,
        'titre_app': 'Observation',
        'visible': true,
        'contraintes': '',
        'nullable': true,
      });
      expect(optionalField.isRequired, isFalse);
    });

    test('nullable false remains required even when field is hidden', () {
      final hiddenRequired = AttributConfigMobileField.fromMap({
        'id': 12,
        'nom_metier': 'ep',
        'nom_table': 'ep_brc_pt',
        'nom_champ': 'legacy_code',
        'type_champ': 'varchar(400)',
        'primary_key': false,
        'foreign_key': false,
        'ordre': 99,
        'titre_app': 'Legacy code',
        'visible': false,
        'contraintes': '',
        'nullable': false,
      });

      expect(hiddenRequired.isRequired, isTrue);
      expect(hiddenRequired.fallbackValueForInvisibleNotNull, 'NON_RENSEIGNE');
    });

    test('liste_choix code is stored value, label is mobile alias, ordered',
        () async {
      await DatabaseHelper.openInMemoryDatabaseForTest(
        includeSrmEntityTables: false,
      );
      final helper = DatabaseHelper();
      await helper.replaceSrmFieldOptions(options: [
        {
          'id_option': 1,
          'table_schema': 'ep',
          'table_name': 'ep_brc_pt',
          'field_name': 'ep_conf_plan',
          'code_value': 'OBJET_DECOUVERT',
          'label_value': 'Objet decouvert',
          'display_order': 2,
          'actif': true,
        },
        {
          'id_option': 2,
          'table_schema': 'ep',
          'table_name': 'ep_brc_pt',
          'field_name': 'ep_conf_plan',
          'code_value': 'CONFORME',
          'label_value': 'Conforme',
          'display_order': 1,
          'actif': true,
        },
        {
          'id_option': 3,
          'table_schema': 'ep',
          'table_name': 'ep_brc_pt',
          'field_name': 'ep_conf_plan',
          'code_value': 'LEGACY',
          'label_value': 'Legacy cache',
          'display_order': 0,
          'actif': false,
        },
      ]);

      final grouped =
          await SrmFieldOptionService(databaseHelper: helper).getOptionsByField(
        tableSchema: 'ep',
        tableName: 'ep_brc_pt',
        fieldNames: {'ep_conf_plan'},
        refreshIfEmpty: false,
      );

      final choices = grouped['ep_conf_plan']!;
      expect(choices.map((choice) => choice.code), [
        'CONFORME',
        'OBJET_DECOUVERT',
      ]);
      expect(choices.first.label, 'Conforme');
    });
  });
}
