import '../core/config/srm_config.dart';
import '../data/local/database_helper.dart';
import '../data/remote/api_service.dart';

class AttributConfigMobileField {
  final int id;
  final String nomMetier;
  final String nomTable;
  final String nomChamp;
  final String typeChamp;
  final bool primaryKey;
  final bool foreignKey;
  final int ordre;
  final String titreApp;
  final bool visible;
  final String contraintes;
  final bool nullable;
  final String valeurParDefaut;
  final String valeurMin;
  final String valeurMax;
  final String referenceFk;

  const AttributConfigMobileField({
    required this.id,
    required this.nomMetier,
    required this.nomTable,
    required this.nomChamp,
    required this.typeChamp,
    required this.primaryKey,
    required this.foreignKey,
    required this.ordre,
    required this.titreApp,
    required this.visible,
    required this.contraintes,
    required this.nullable,
    required this.valeurParDefaut,
    required this.valeurMin,
    required this.valeurMax,
    required this.referenceFk,
  });

  factory AttributConfigMobileField.fromMap(Map<String, dynamic> row) {
    return AttributConfigMobileField(
      id: _toInt(row['id']) ?? 0,
      nomMetier: row['nom_metier']?.toString().trim() ?? '',
      nomTable: row['nom_table']?.toString().trim() ?? '',
      nomChamp: row['nom_champ']?.toString().trim().toLowerCase() ?? '',
      typeChamp: row['type_champ']?.toString().trim() ?? '',
      primaryKey: _toBool(row['primary_key']),
      foreignKey: _toBool(row['foreign_key']),
      ordre: _toInt(row['ordre']) ?? 0,
      titreApp: row['titre_app']?.toString().trim() ?? '',
      visible: _toBool(row['visible']),
      contraintes: row['contraintes']?.toString().trim() ?? '',
      nullable: _toBool(row['nullable'], defaultValue: true),
      valeurParDefaut: row['valeur_par_defaut']?.toString().trim() ?? '',
      valeurMin: row['valeur_min']?.toString().trim() ?? '',
      valeurMax: row['valeur_max']?.toString().trim() ?? '',
      referenceFk: row['reference_fk']?.toString().trim() ?? '',
    );
  }

  String get label =>
      titreApp.isNotEmpty ? titreApp : nomChamp.replaceAll('_', ' ');

  bool get isRequired {
    if (primaryKey) return false;
    if (nomChamp.toLowerCase() == 'geom') return false;
    if (isAutoVisibleCoordinate) return false;
    // Source de verite: nullable=false signifie champ requis dans le payload.
    // Un champ invisible reste donc obligatoire cote sync; le formulaire le
    // remplit avec sa valeur par defaut ou une sentinelle typee si necessaire.
    return !nullable;
  }

  double? get numericMin => _toDouble(valeurMin);
  double? get numericMax => _toDouble(valeurMax);
  DateTime? get dateMin => _toDate(valeurMin);
  DateTime? get dateMax => _toDate(valeurMax);

  /// Valeur sentinelle minimale pour un champ invisible NOT NULL sans
  /// valeur_par_defaut configurée. Le but est d'éviter un rejet serveur
  /// (NOT NULL violation) tout en restant typé selon la colonne SQL.
  dynamic get fallbackValueForInvisibleNotNull {
    final type = typeChamp.toLowerCase();
    if (type.contains('serial') || type.contains('int')) return 0;
    if (type.contains('numeric') ||
        type.contains('decimal') ||
        type.contains('real') ||
        type.contains('double') ||
        type.contains('float')) {
      return 0.0;
    }
    if (type.contains('bool')) return 0;
    if (type.contains('date') || type.contains('timestamp')) {
      return DateTime.now().toIso8601String();
    }
    if (type.contains('uuid')) {
      return '00000000-0000-0000-0000-000000000000';
    }
    return 'NON_RENSEIGNE';
  }

  bool get isAutoVisibleCoordinate {
    final prefix = _coordinatePrefixForMetier(nomMetier);
    if (prefix.isEmpty) return false;
    final normalizedChamp = nomChamp.trim().toLowerCase();
    return normalizedChamp == '${prefix}_coor_x' ||
        normalizedChamp == '${prefix}_coor_y' ||
        normalizedChamp == '${prefix}_coor_z';
  }

  static String _coordinatePrefixForMetier(String nomMetier) {
    final normalized = nomMetier.trim().toLowerCase();
    if (normalized == 'ep' || normalized == 'eau potable') return 'ep';
    if (normalized == 'asst' ||
        normalized == 'ass' ||
        normalized == 'assainissement') {
      return 'ass';
    }
    return '';
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().trim());
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    final text = value.toString().trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  static DateTime? _toDate(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  static bool _toBool(dynamic value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value.toString().trim().toLowerCase();
    if (text.isEmpty) return defaultValue;
    return ['1', 'true', 't', 'yes', 'oui'].contains(text);
  }
}

class AttributConfigMobileService {
  final DatabaseHelper _db;

  AttributConfigMobileService({DatabaseHelper? databaseHelper})
      : _db = databaseHelper ?? DatabaseHelper();

  Future<Map<String, dynamic>> refreshConfig({
    String? nomMetier,
    String? nomTable,
  }) async {
    final rows = await ApiService.fetchAttributConfigMobile(
      nomMetier: nomMetier,
      nomTable: nomTable,
    );
    await _db.replaceAttributConfigMobile(
      rows: rows,
      nomMetier: nomMetier,
      nomTable: nomTable,
    );
    return {
      'nom_metier': nomMetier,
      'nom_table': nomTable,
      'rows_count': rows.length,
    };
  }

  Future<List<AttributConfigMobileField>> getFormFields({
    required String metier,
    required String entityType,
    bool refreshIfEmpty = true,
    bool forceRefresh = false,
  }) async {
    final nomMetier = nomMetierForMobileMetier(metier);
    final mobileTable = SrmConfig.getTableName(metier, entityType) ?? '';
    final nomTable = configTableForMobileTable(nomMetier, mobileTable);
    if (nomMetier.isEmpty || nomTable.isEmpty) return const [];

    if (forceRefresh) {
      try {
        await refreshConfig(nomMetier: nomMetier, nomTable: nomTable);
      } catch (_) {
        // Hors ligne ou erreur reseau : on retombe sur le cache SQLite.
      }
    }

    var rows = await _db.getAttributConfigMobile(
      nomMetier: nomMetier,
      nomTable: nomTable,
    );
    if (rows.isEmpty && refreshIfEmpty) {
      await refreshConfig(nomMetier: nomMetier, nomTable: nomTable);
      rows = await _db.getAttributConfigMobile(
        nomMetier: nomMetier,
        nomTable: nomTable,
      );
    }

    return rows.map(AttributConfigMobileField.fromMap).toList();
  }

  /// Liste des nom_champ marques `nullable = false` dans la config serveur
  /// (= colonnes physiques NOT NULL exposees au mobile). Sert au sync_service
  /// pour bloquer le POST d'une ligne ou un de ces champs serait null/vide :
  /// l'INSERT serveur planterait sur la contrainte NOT NULL et l'audit
  /// trigger ferait apparaitre un "ghost event" sans donnee persistee.
  Future<List<String>> getRequiredFieldNamesForTable({
    required String nomMetier,
    required String nomTable,
  }) async {
    final fields = await getFieldsForConfigTable(
      nomMetier: nomMetier,
      nomTable: nomTable,
      refreshIfEmpty: true,
    );
    final required = <String>[];
    for (final f in fields) {
      if (f.primaryKey) continue;
      if (f.nomChamp.toLowerCase() == 'geom') continue;
      if (f.isAutoVisibleCoordinate) continue;
      if (!f.nullable) required.add(f.nomChamp);
    }
    return required;
  }

  Future<List<AttributConfigMobileField>> getFieldsForConfigTable({
    required String nomMetier,
    required String nomTable,
    bool refreshIfEmpty = true,
  }) async {
    final schema = nomMetier.trim();
    final table = nomTable.trim();
    if (schema.isEmpty || table.isEmpty) return const [];

    var rows = await _db.getAttributConfigMobile(
      nomMetier: schema,
      nomTable: table,
    );
    if (rows.isEmpty && refreshIfEmpty) {
      await refreshConfig(nomMetier: schema, nomTable: table);
      rows = await _db.getAttributConfigMobile(
        nomMetier: schema,
        nomTable: table,
      );
    }

    return rows.map(AttributConfigMobileField.fromMap).toList();
  }

  static String nomMetierForMobileMetier(String metier) {
    final normalized = metier.trim().toLowerCase();
    if (normalized == 'eau potable' || normalized == 'ep') return 'ep';
    if (normalized == 'assainissement' ||
        normalized == 'ass' ||
        normalized == 'asst') {
      return 'asst';
    }
    return normalized;
  }

  static String configTableForMobileTable(String nomMetier, String tableName) {
    final table = tableName.trim();
    if (nomMetier == 'ep') {
      return _epConfigTableByMobileTable[table] ?? table;
    }
    if (nomMetier == 'asst') {
      return _asstConfigTableByMobileTable[table] ?? table;
    }
    return table;
  }

  static String mobileTableForConfigTable(String nomMetier, String nomTable) {
    final table = nomTable.trim();
    if (nomMetier == 'ep') {
      return _epMobileTableByConfigTable[table] ?? table;
    }
    if (nomMetier == 'asst') {
      return _asstMobileTableByConfigTable[table] ?? table;
    }
    return table;
  }

  static const Map<String, String> _epConfigTableByMobileTable = {
    'vanne': 'ep_vanne',
    'vanne_de_vidange': 'ep_vidange',
    'ventouse': 'ep_ventouse',
    'hydrant': 'ep_hydrant',
    'borne_fontaine': 'ep_bf',
    'borne_onep': 'borne_onep',
    'bouche_a_cles': 'bouche_a_cles',
    'bouche_cles': 'bouche_a_cles',
    'bouche_darrosage': 'ep_bouche_arro',
    'compteur_reseau': 'ep_compteur_i',
    'compteur_abonne': 'ep_brc_pt',
    'cone_de_reduction': 'ep_cone_reduc',
    'centre_tampon': 'centre_tampon',
    'noeud': 'ep_noeud',
    'obturateur': 'ep_obturateur',
    'reducteur_de_pression': 'ep_reduc_pres',
    'forage': 'ep_forage',
    'puit': 'ep_puit',
    'pompe': 'ep_pompe',
    'reservoir': 'ep_reservoir',
    'ep_bache': 'ep_bache',
    'station_de_pompage': 'ep_station_pompage',
    'regard': 'ep_regard_point',
    'regard_ep': 'ep_regard_point',
    'autre_objet': 'autre_objet',
    'anomalie_conduite': 'anomalie_conduite',
    'conduite_terrain': 'conduite_terrain',
    'branchement': 'ep_branchement',
    'traverse': 'ep_traversee',
    'tn': 'tn',
    'voie': 'voie',
  };

  static const Map<String, String> _epMobileTableByConfigTable = {
    'ep_vanne': 'vanne',
    'ep_vidange': 'vanne_de_vidange',
    'ep_ventouse': 'ventouse',
    'ep_hydrant': 'hydrant',
    'ep_bf': 'borne_fontaine',
    'borne_onep': 'borne_onep',
    'bouche_a_cles': 'bouche_a_cles',
    'ep_bouche_arro': 'bouche_darrosage',
    'ep_compteur_i': 'compteur_reseau',
    'ep_brc_pt': 'compteur_abonne',
    'ep_cone_reduc': 'cone_de_reduction',
    'centre_tampon': 'centre_tampon',
    'ep_obturateur': 'obturateur',
    'ep_reduc_pres': 'reducteur_de_pression',
    'ep_noeud': 'noeud',
    'ep_reservoir': 'reservoir',
    'ep_station_pompage': 'station_de_pompage',
    'ep_forage': 'forage',
    'ep_puit': 'puit',
    'ep_pompe': 'pompe',
    'ep_bache': 'ep_bache',
    'ep_regard_point': 'ep_regard_point',
    'ep_regard': 'ep_regard',
    'anomalie_conduite': 'anomalie_conduite',
    'conduite_terrain': 'conduite_terrain',
    'ep_branchement': 'branchement',
    'ep_traversee': 'traverse',
    'tn': 'tn',
    'voie': 'voie',
    'autre_objet': 'autre_objet',
  };

  static const Map<String, String> _asstConfigTableByMobileTable = {
    'asst_regard': 'ASS_REGARD',
    'asst_regard_branchement': 'ASS_REGARD_FACADE',
    'asst_canalisation': 'ASS_COLLECTEUR',
    'asst_canalisation_reutilisation': 'ASS_REFOULEMENTR',
    'asst_branchement': 'ASS_BRANCHEMENT',
    'asst_bassin': 'ASS_BASSIN_VERSANT',
    'asst_ouvrage': 'ASS_OUV_TRAVERSEE',
    'asst_equipement': 'ASS_POMPE',
    'asst_station': 'ASS_STA_POMP',
    'ASS_BORGNE': 'ASS_BORGNE',
    'ASS_BOUCHE': 'ASS_BOUCHE',
    'ASS_DEVERSOIR': 'ASS_DEVERSOIR',
    'ASS__EXUTOIRE': 'ASS__EXUTOIRE',
    'ASS_STA_POMP': 'ASS_STA_POMP',
    'ASS_CANIVEAU': 'ASS_CANIVEAU',
    'ASS_CANIV_BRANCHE': 'ASS_CANIV_BRANCHE',
    'ASS_COL_BOUCHE': 'ASS_COL_BOUCHE',
    'ASS_STA_EPUR': 'ASS_STA_EPUR',
    'ASS_REGARD': 'ASS_REGARD',
    'ASS_REGARD_FACADE': 'ASS_REGARD_FACADE',
    'ASS_COLLECTEUR': 'ASS_COLLECTEUR',
    'ASS_BRANCHEMENT': 'ASS_BRANCHEMENT',
  };

  static const Map<String, String> _asstMobileTableByConfigTable = {
    'ASS_REGARD': 'asst_regard',
    'ASS_REGARD_FACADE': 'asst_regard_branchement',
    'ASS_BORGNE': 'ASS_BORGNE',
    'ASS_BOUCHE': 'ASS_BOUCHE',
    'ASS_DEVERSOIR': 'ASS_DEVERSOIR',
    'ASS__EXUTOIRE': 'ASS__EXUTOIRE',
    'ASS_STA_POMP': 'asst_station',
    'ASS_COLLECTEUR': 'asst_canalisation',
    'ASS_REFOULEMENTR': 'asst_canalisation_reutilisation',
    'ASS_BRANCHEMENT': 'asst_branchement',
    'ASS_CANIVEAU': 'ASS_CANIVEAU',
    'ASS_CANIV_BRANCHE': 'ASS_CANIV_BRANCHE',
    'ASS_COL_BOUCHE': 'ASS_COL_BOUCHE',
    'ASS_BASSIN_VERSANT': 'asst_bassin',
    'ASS_OUV_TRAVERSEE': 'asst_ouvrage',
    'ASS_POMPE': 'asst_equipement',
    'ASS_STA_EPUR': 'ASS_STA_EPUR',
  };
}
