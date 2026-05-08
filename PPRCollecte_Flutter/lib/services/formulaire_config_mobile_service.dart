import '../data/local/database_helper.dart';
import '../data/remote/api_service.dart';
import '../core/config/srm_config.dart';
import 'attribut_config_mobile_service.dart';

class FormulaireConfigMobileItem {
  final int id;
  final String nomMetier;
  final String nomTable;
  final String titreApp;
  final int ordre;
  final bool visible;
  final String createdAt;
  final String updatedAt;

  const FormulaireConfigMobileItem({
    required this.id,
    required this.nomMetier,
    required this.nomTable,
    required this.titreApp,
    required this.ordre,
    required this.visible,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FormulaireConfigMobileItem.fromMap(Map<String, dynamic> row) {
    return FormulaireConfigMobileItem(
      id: _toInt(row['id']) ?? 0,
      nomMetier: row['nom_metier']?.toString().trim() ?? '',
      nomTable: row['nom_table']?.toString().trim() ?? '',
      titreApp: row['titre_app']?.toString().trim() ?? '',
      ordre: _toInt(row['ordre']) ?? 0,
      visible: _toBool(row['visible'], defaultValue: true),
      createdAt: row['created_at']?.toString().trim() ?? '',
      updatedAt: row['updated_at']?.toString().trim() ?? '',
    );
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().trim());
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

class FormulaireConfigMobileEntity {
  final String entityType;
  final String tableName;
  final String schema;
  final String titleApp;
  final int ordre;
  final bool isLine;
  final bool isPolygon;
  final bool hasZ;
  final int maxPhotos;
  final FormulaireConfigMobileItem? source;

  const FormulaireConfigMobileEntity({
    required this.entityType,
    required this.tableName,
    required this.schema,
    required this.titleApp,
    required this.ordre,
    required this.isLine,
    required this.isPolygon,
    required this.hasZ,
    required this.maxPhotos,
    this.source,
  });

  FormulaireConfigMobileEntity copyWith({
    String? titleApp,
    int? ordre,
    FormulaireConfigMobileItem? source,
  }) {
    return FormulaireConfigMobileEntity(
      entityType: entityType,
      tableName: tableName,
      schema: schema,
      titleApp: titleApp ?? this.titleApp,
      ordre: ordre ?? this.ordre,
      isLine: isLine,
      isPolygon: isPolygon,
      hasZ: hasZ,
      maxPhotos: maxPhotos,
      source: source ?? this.source,
    );
  }
}

class FormulaireConfigMobileService {
  final DatabaseHelper _db;

  FormulaireConfigMobileService({DatabaseHelper? databaseHelper})
      : _db = databaseHelper ?? DatabaseHelper();

  Future<Map<String, dynamic>> refreshConfig({
    String? nomMetier,
    String? nomTable,
  }) async {
    final rows = await ApiService.fetchFormulaireConfigMobile(
      nomMetier: nomMetier,
      nomTable: nomTable,
    );
    await _db.replaceFormulaireConfigMobile(
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

  Future<List<FormulaireConfigMobileItem>> getFormulaires({
    String? nomMetier,
    String? nomTable,
    bool visibleOnly = false,
    bool refreshIfEmpty = true,
  }) async {
    var rows = await _db.getFormulaireConfigMobile(
      nomMetier: nomMetier,
      nomTable: nomTable,
      visibleOnly: visibleOnly,
    );
    if (rows.isEmpty && refreshIfEmpty) {
      try {
        await refreshConfig(nomMetier: nomMetier, nomTable: nomTable);
        rows = await _db.getFormulaireConfigMobile(
          nomMetier: nomMetier,
          nomTable: nomTable,
          visibleOnly: visibleOnly,
        );
      } catch (_) {
        final fallback = _fallbackFormulaires(
          nomMetier: nomMetier,
          nomTable: nomTable,
          visibleOnly: visibleOnly,
        );
        if (fallback.isNotEmpty) {
          return fallback;
        }
        rethrow;
      }
    }
    final items = rows.map(FormulaireConfigMobileItem.fromMap).toList();
    if (items.isNotEmpty) {
      return items;
    }
    return _fallbackFormulaires(
      nomMetier: nomMetier,
      nomTable: nomTable,
      visibleOnly: visibleOnly,
    );
  }

  Future<List<FormulaireConfigMobileEntity>> getMobileEntities({
    required String mobileMetier,
    required String geometryFilter,
    bool refreshIfEmpty = true,
  }) async {
    final fallback = _fallbackMobileEntities(
      mobileMetier,
      geometryFilter,
    );
    final nomMetier =
        AttributConfigMobileService.nomMetierForMobileMetier(mobileMetier);
    if (nomMetier.isEmpty) {
      return fallback;
    }

    try {
      final rows = await getFormulaires(
        nomMetier: nomMetier,
        visibleOnly: true,
        refreshIfEmpty: refreshIfEmpty,
      );
      if (rows.isEmpty) {
        return fallback;
      }

      final fallbackByTable = {
        for (final entity in fallback) entity.tableName: entity,
      };
      final configured = <FormulaireConfigMobileEntity>[];
      for (final row in rows) {
        final mobileTable =
            AttributConfigMobileService.mobileTableForConfigTable(
          nomMetier,
          row.nomTable,
        );
        final entity = fallbackByTable[mobileTable];
        if (entity == null) {
          continue;
        }
        configured.add(
          entity.copyWith(
            titleApp: row.titreApp.isNotEmpty ? row.titreApp : entity.titleApp,
            ordre: row.ordre,
            source: row,
          ),
        );
      }
      if (configured.isEmpty) {
        return fallback;
      }
      configured.sort((a, b) {
        final order = a.ordre.compareTo(b.ordre);
        if (order != 0) return order;
        return a.titleApp.compareTo(b.titleApp);
      });
      return configured;
    } catch (_) {
      return fallback;
    }
  }

  Future<Map<String, String>> getTitleByMobileTable({
    required String mobileMetier,
    bool refreshIfEmpty = true,
  }) async {
    final nomMetier =
        AttributConfigMobileService.nomMetierForMobileMetier(mobileMetier);
    if (nomMetier.isEmpty) return const {};

    final rows = await getFormulaires(
      nomMetier: nomMetier,
      visibleOnly: false,
      refreshIfEmpty: refreshIfEmpty,
    );
    final titles = <String, String>{};
    for (final row in rows) {
      final mobileTable = AttributConfigMobileService.mobileTableForConfigTable(
        nomMetier,
        row.nomTable,
      );
      final title = row.titreApp.trim();
      if (mobileTable.isEmpty || title.isEmpty) continue;
      titles[mobileTable] = title;
    }
    return titles;
  }

  List<FormulaireConfigMobileEntity> _fallbackMobileEntities(
    String mobileMetier,
    String geometryFilter,
  ) {
    final entities = _fallbackEntityNames(mobileMetier, geometryFilter);
    final nomMetier =
        AttributConfigMobileService.nomMetierForMobileMetier(mobileMetier);
    final visibleRows = _fallbackFormulaires(
      nomMetier: nomMetier,
      visibleOnly: true,
    );
    final visibleByMobileTable = {
      for (final row in visibleRows)
        AttributConfigMobileService.mobileTableForConfigTable(
          nomMetier,
          row.nomTable,
        ): row,
    };
    final result = <FormulaireConfigMobileEntity>[];
    for (var i = 0; i < entities.length; i++) {
      final entity = entities[i];
      final config = SrmConfig.getEntityConfig(mobileMetier, entity);
      if (config == null) continue;
      final tableName = config['tableName']?.toString() ?? '';
      final visibleRow = visibleByMobileTable[tableName];
      if (nomMetier.isNotEmpty && visibleRow == null) {
        continue;
      }
      result.add(
        FormulaireConfigMobileEntity(
          entityType: entity,
          tableName: tableName,
          schema: config['schema']?.toString() ?? 'ep',
          titleApp: visibleRow?.titreApp ?? entity,
          ordre: visibleRow?.ordre ?? i,
          isLine: config['isLine'] == true,
          isPolygon: config['isPolygon'] == true,
          hasZ: config['hasZ'] == true,
          maxPhotos: _asInt(config['maxPhotos']) ?? 0,
        ),
      );
    }

    final epRegardPolygonVisible = _fallbackFormulaires(
      nomMetier: 'ep',
      nomTable: 'ep_regard',
      visibleOnly: true,
    ).isNotEmpty;
    if (mobileMetier == 'Eau Potable' &&
        geometryFilter == 'polygon' &&
        epRegardPolygonVisible) {
      result.add(
        const FormulaireConfigMobileEntity(
          entityType: 'Regard EP',
          tableName: 'ep_regard',
          schema: 'ep',
          titleApp: 'Regard EP',
          ordre: 100000,
          isLine: false,
          isPolygon: true,
          hasZ: true,
          maxPhotos: 4,
        ),
      );
    }
    return result
        .where((entity) => entity.tableName.trim().isNotEmpty)
        .toList();
  }

  List<String> _fallbackEntityNames(
      String mobileMetier, String geometryFilter) {
    if (geometryFilter == 'line') {
      return SrmConfig.getLineEntities(mobileMetier);
    }
    if (geometryFilter == 'polygon') {
      return SrmConfig.getPolygonEntities(mobileMetier);
    }
    return SrmConfig.getPointEntities(mobileMetier);
  }

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().trim());
  }

  List<FormulaireConfigMobileItem> _fallbackFormulaires({
    String? nomMetier,
    String? nomTable,
    bool visibleOnly = false,
  }) {
    final metier = (nomMetier ?? '').trim().toLowerCase();
    final source = metier == 'asst' || metier == 'ass'
        ? _fallbackAsstFormulaires
        : metier == 'ep'
            ? _fallbackEpFormulaires
            : [..._fallbackEpFormulaires, ..._fallbackAsstFormulaires];
    final table = (nomTable ?? '').trim().toLowerCase();
    final rows = source.where((row) {
      if (table.isNotEmpty && row.nomTable.toLowerCase() != table) {
        return false;
      }
      if (visibleOnly && !row.visible) {
        return false;
      }
      return true;
    }).toList();
    rows.sort((a, b) {
      final order = a.ordre.compareTo(b.ordre);
      if (order != 0) return order;
      return a.id.compareTo(b.id);
    });
    return rows;
  }

  static const List<FormulaireConfigMobileItem> _fallbackEpFormulaires = [
    FormulaireConfigMobileItem(
      id: 1,
      nomMetier: 'ep',
      nomTable: 'ep_vanne',
      titreApp: 'Vanne',
      ordre: 10,
      visible: true,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 2,
      nomMetier: 'ep',
      nomTable: 'ep_vidange',
      titreApp: 'Vanne de vidange',
      ordre: 15,
      visible: true,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 3,
      nomMetier: 'ep',
      nomTable: 'ep_ventouse',
      titreApp: 'Ventouse',
      ordre: 16,
      visible: true,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 4,
      nomMetier: 'ep',
      nomTable: 'ep_hydrant',
      titreApp: 'Hydrant',
      ordre: 9,
      visible: true,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 5,
      nomMetier: 'ep',
      nomTable: 'ep_bf',
      titreApp: 'Borne fontaine',
      ordre: 5,
      visible: true,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 6,
      nomMetier: 'ep',
      nomTable: 'borne_onep',
      titreApp: 'Borne ONEP',
      ordre: 30,
      visible: true,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 7,
      nomMetier: 'ep',
      nomTable: 'bouche_a_cles',
      titreApp: 'Bouche à clé',
      ordre: 31,
      visible: true,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 8,
      nomMetier: 'ep',
      nomTable: 'ep_bouche_arro',
      titreApp: "Bouche d'arrosage",
      ordre: 14,
      visible: false,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 9,
      nomMetier: 'ep',
      nomTable: 'ep_compteur_i',
      titreApp: 'Compteur réseau',
      ordre: 8,
      visible: true,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 10,
      nomMetier: 'ep',
      nomTable: 'ep_brc_pt',
      titreApp: 'Compteur abonné',
      ordre: 4,
      visible: true,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 11,
      nomMetier: 'ep',
      nomTable: 'ep_cone_reduc',
      titreApp: 'Cône de réduction',
      ordre: 7,
      visible: true,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 12,
      nomMetier: 'ep',
      nomTable: 'centre_tampon',
      titreApp: 'Centre tampon',
      ordre: 19,
      visible: false,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 13,
      nomMetier: 'ep',
      nomTable: 'ep_obturateur',
      titreApp: 'Obturateur',
      ordre: 11,
      visible: true,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 14,
      nomMetier: 'ep',
      nomTable: 'ep_reduc_pres',
      titreApp: 'Réducteur de pression',
      ordre: 17,
      visible: true,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 15,
      nomMetier: 'ep',
      nomTable: 'ep_noeud',
      titreApp: 'Noeud',
      ordre: 22,
      visible: false,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 16,
      nomMetier: 'ep',
      nomTable: 'ep_reservoir',
      titreApp: 'Réservoir',
      ordre: 20,
      visible: true,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 17,
      nomMetier: 'ep',
      nomTable: 'ep_bache',
      titreApp: 'Bâche',
      ordre: 13,
      visible: true,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 18,
      nomMetier: 'ep',
      nomTable: 'ep_station_pompage',
      titreApp: 'Station de pompage',
      ordre: 24,
      visible: true,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 19,
      nomMetier: 'ep',
      nomTable: 'ep_st_demineralisation',
      titreApp: 'Station de déminéralisation',
      ordre: 26,
      visible: false,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 20,
      nomMetier: 'ep',
      nomTable: 'ep_forage',
      titreApp: 'Forage',
      ordre: 21,
      visible: true,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 21,
      nomMetier: 'ep',
      nomTable: 'ep_puit',
      titreApp: 'Puits',
      ordre: 25,
      visible: false,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 22,
      nomMetier: 'ep',
      nomTable: 'ep_pompe',
      titreApp: 'Pompe',
      ordre: 23,
      visible: true,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 23,
      nomMetier: 'ep',
      nomTable: 'ep_regard_point',
      titreApp: 'Regard',
      ordre: 1,
      visible: true,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 24,
      nomMetier: 'ep',
      nomTable: 'conduite_terrain',
      titreApp: 'Conduite terrain',
      ordre: 2,
      visible: true,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 25,
      nomMetier: 'ep',
      nomTable: 'ep_branchement',
      titreApp: 'Branchement',
      ordre: 12,
      visible: false,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 26,
      nomMetier: 'ep',
      nomTable: 'ep_traversee',
      titreApp: 'Traversée',
      ordre: 6,
      visible: true,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 27,
      nomMetier: 'ep',
      nomTable: 'autre_objet',
      titreApp: 'Autre objet EP',
      ordre: 33,
      visible: true,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 28,
      nomMetier: 'ep',
      nomTable: 'ep_conduite',
      titreApp: 'Conduite bureau',
      ordre: 3,
      visible: false,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 29,
      nomMetier: 'ep',
      nomTable: 'ep_regard',
      titreApp: 'Regard (polygone)',
      ordre: 29,
      visible: true,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 30,
      nomMetier: 'ep',
      nomTable: 'anomalie_conduite',
      titreApp: 'Anomalie conduite',
      ordre: 28,
      visible: true,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 31,
      nomMetier: 'ep',
      nomTable: 'voie',
      titreApp: 'Voie',
      ordre: 18,
      visible: true,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 32,
      nomMetier: 'ep',
      nomTable: 'tn',
      titreApp: 'TN',
      ordre: 27,
      visible: true,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 33,
      nomMetier: 'ep',
      nomTable: 'onep_db',
      titreApp: 'ONEP DB',
      ordre: 32,
      visible: false,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 34,
      nomMetier: 'ep',
      nomTable: 'statistique_conduite',
      titreApp: 'Statistique conduite',
      ordre: 34,
      visible: false,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 35,
      nomMetier: 'ep',
      nomTable: 'statistique_conduite_segment',
      titreApp: 'Segment statistique conduite',
      ordre: 35,
      visible: false,
      createdAt: '',
      updatedAt: '',
    ),
  ];

  static const List<FormulaireConfigMobileItem> _fallbackAsstFormulaires = [
    FormulaireConfigMobileItem(
      id: 1001,
      nomMetier: 'asst',
      nomTable: 'ASS_REGARD',
      titreApp: 'Regards de visite',
      ordre: 1,
      visible: true,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 1002,
      nomMetier: 'asst',
      nomTable: 'ASS_REGARD_FACADE',
      titreApp: 'Regards Fa\u00e7ade',
      ordre: 2,
      visible: true,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 1003,
      nomMetier: 'asst',
      nomTable: 'ASS_BORGNE',
      titreApp: 'Regards Borgnes',
      ordre: 3,
      visible: true,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 1004,
      nomMetier: 'asst',
      nomTable: 'ASS_BOUCHE',
      titreApp: "Bouches d'\u00e9gout",
      ordre: 4,
      visible: true,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 1005,
      nomMetier: 'asst',
      nomTable: 'ASS_DEVERSOIR',
      titreApp: "D\u00e9versoirs d'orage",
      ordre: 5,
      visible: true,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 1006,
      nomMetier: 'asst',
      nomTable: 'ASS__EXUTOIRE',
      titreApp: 'Exutoires',
      ordre: 6,
      visible: true,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 1007,
      nomMetier: 'asst',
      nomTable: 'ASS_STA_POMP',
      titreApp: 'Stations de pompage',
      ordre: 7,
      visible: true,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 1008,
      nomMetier: 'asst',
      nomTable: 'ASS_COLLECTEUR',
      titreApp: 'Collecteurs',
      ordre: 8,
      visible: true,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 1009,
      nomMetier: 'asst',
      nomTable: 'ASS_BRANCHEMENT',
      titreApp: 'Branchements collecteur',
      ordre: 9,
      visible: true,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 1010,
      nomMetier: 'asst',
      nomTable: 'ASS_CANIVEAU',
      titreApp: 'Caniveaux',
      ordre: 10,
      visible: true,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 1011,
      nomMetier: 'asst',
      nomTable: 'ASS_CANIV_BRANCHE',
      titreApp: 'Caniveau branchement',
      ordre: 11,
      visible: true,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 1012,
      nomMetier: 'asst',
      nomTable: 'ASS_COL_BOUCHE',
      titreApp: "Collecteur bouche d'\u00e9gout",
      ordre: 12,
      visible: true,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 1013,
      nomMetier: 'asst',
      nomTable: 'ASS_BASSIN_VERSANT',
      titreApp: 'Bassins versants',
      ordre: 13,
      visible: false,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 1014,
      nomMetier: 'asst',
      nomTable: 'ASS_STA_EPUR',
      titreApp: "Stations d'\u00e9puration",
      ordre: 14,
      visible: true,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 1015,
      nomMetier: 'asst',
      nomTable: 'ASS_BASSIN_RET',
      titreApp: 'Bassins de r\u00e9tention',
      ordre: 15,
      visible: false,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 1016,
      nomMetier: 'asst',
      nomTable: 'ASS_BASSIN_RET_L',
      titreApp: 'Bassins de r\u00e9tention (ligne)',
      ordre: 16,
      visible: false,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 1017,
      nomMetier: 'asst',
      nomTable: 'ASS_ECOULEMENT',
      titreApp: '\u00c9coulement',
      ordre: 17,
      visible: false,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 1018,
      nomMetier: 'asst',
      nomTable: 'ASS_FOSSE_SEPT',
      titreApp: 'Fosses septiques',
      ordre: 18,
      visible: false,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 1019,
      nomMetier: 'asst',
      nomTable: 'ASS_OUED',
      titreApp: 'Oued',
      ordre: 19,
      visible: false,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 1020,
      nomMetier: 'asst',
      nomTable: 'ASS_OUV_TRAVERSEE',
      titreApp: 'Ouvrages de travers\u00e9e',
      ordre: 20,
      visible: false,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 1021,
      nomMetier: 'asst',
      nomTable: 'ASS_POINTS-NOIRS',
      titreApp: 'Points noirs',
      ordre: 21,
      visible: false,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 1022,
      nomMetier: 'asst',
      nomTable: 'ASS_POMPE',
      titreApp: 'Pompes',
      ordre: 22,
      visible: false,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 1023,
      nomMetier: 'asst',
      nomTable: 'ASS_REFOULEMENTR',
      titreApp: 'Refoulement r\u00e9utilisation',
      ordre: 23,
      visible: false,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 1024,
      nomMetier: 'asst',
      nomTable: 'ASS_SECTEUR_ASS',
      titreApp: 'Secteurs assainissement',
      ordre: 24,
      visible: false,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 1025,
      nomMetier: 'asst',
      nomTable: 'ASS_STA_EPUR_L',
      titreApp: "Stations d'\u00e9puration (ligne)",
      ordre: 25,
      visible: false,
      createdAt: '',
      updatedAt: '',
    ),
    FormulaireConfigMobileItem(
      id: 1026,
      nomMetier: 'asst',
      nomTable: 'ASS_STA_POMP_S',
      titreApp: 'Stations de pompage (surface)',
      ordre: 26,
      visible: false,
      createdAt: '',
      updatedAt: '',
    ),
  ];
}
