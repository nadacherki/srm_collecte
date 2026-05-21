// lib/widgets/forms/srm_metier_selector.dart

import 'package:flutter/material.dart';
import '../../core/config/srm_config.dart';
import '../../services/formulaire_config_mobile_service.dart';
import '../common/custom_marker_icons.dart';

class SrmSelection {
  final String metier;
  final String entityType;
  final String tableName;
  final String schema;
  final String titleApp;
  final bool isLine;
  final bool isPolygon;

  const SrmSelection({
    required this.metier,
    required this.entityType,
    required this.tableName,
    required this.schema,
    this.titleApp = '',
    this.isLine = false,
    this.isPolygon = false,
  });
}

Future<SrmSelection?> showSrmPointSelector(BuildContext context) {
  return _showSrmSelector(context, geometryFilter: 'point');
}

Future<SrmSelection?> showSrmLigneSelector(BuildContext context) {
  return _showSrmSelector(context, geometryFilter: 'line');
}

Future<SrmSelection?> showSrmPolygoneSelector(BuildContext context) {
  return _showSrmSelector(context, geometryFilter: 'polygon');
}

/// TableNames (cf. srm_config.dart) des 9 types pouvant etre "piece de
/// regard" : vanne, vidange, ventouse, cone reduc, compteur reseau,
/// reducteur pression, obturateur, pompe, conduite terrain.
const Set<String> regardPieceTableNames = <String>{
  'vanne',
  'vanne_de_vidange',
  'ventouse',
  'cone_de_reduction',
  'compteur_reseau',
  'reducteur_de_pression',
  'obturateur',
  'pompe',
  'conduite_terrain',
};

/// Selecteur restreint aux 9 types "piece de regard". Pas d'etape "metier"
/// (tout est EP) : on ouvre directement la liste des entites cibles.
Future<SrmSelection?> showSrmRegardPieceSelector(BuildContext context) async {
  final geometry = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => const _RegardPieceGeometrySheet(),
  );
  if (geometry == null) return null;
  if (!context.mounted) return null;

  final entity = await showModalBottomSheet<FormulaireConfigMobileEntity>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _RegardPieceEntitySheet(geometryFilter: geometry),
  );
  if (entity == null) return null;
  return SrmSelection(
    metier: 'Eau Potable',
    entityType: entity.entityType,
    tableName: entity.tableName,
    schema: entity.schema,
    titleApp: entity.titleApp,
    isLine: entity.isLine,
    isPolygon: entity.isPolygon,
  );
}

class _RegardPieceGeometrySheet extends StatelessWidget {
  const _RegardPieceGeometrySheet();

  @override
  Widget build(BuildContext context) {
    final color = Color(SrmConfig.getMetierColor('Eau Potable'));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(Icons.settings_input_component, color: color),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pièce du regard',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Choisir le type de géométrie',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(Icons.place, color: color),
              ),
              title: const Text('Point'),
              subtitle: const Text(
                'Vanne, vidange, ventouse, compteur, pompe...',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(context, 'point'),
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFF00897B).withValues(alpha: 0.15),
                child: const Icon(Icons.timeline, color: Color(0xFF00897B)),
              ),
              title: const Text('Ligne'),
              subtitle: const Text('Conduite terrain'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(context, 'line'),
            ),
          ],
        ),
      ),
    );
  }
}

Future<SrmSelection?> _showSrmSelector(
  BuildContext context, {
  required String geometryFilter,
}) async {
  final metier = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _MetierSheet(geometryFilter: geometryFilter),
  );
  if (metier == null) return null;

  if (!context.mounted) return null;
  final entity = await showModalBottomSheet<FormulaireConfigMobileEntity>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _EntitySheet(
      metier: metier,
      geometryFilter: geometryFilter,
    ),
  );
  if (entity == null) return null;

  return SrmSelection(
    metier: metier,
    entityType: entity.entityType,
    tableName: entity.tableName,
    schema: entity.schema,
    titleApp: entity.titleApp,
    isLine: entity.isLine,
    isPolygon: entity.isPolygon,
  );
}

class _MetierSheet extends StatelessWidget {
  final String geometryFilter;
  const _MetierSheet({required this.geometryFilter});

  bool _metierHasGeometry(String metier) {
    final entities = SrmConfig.getEntitiesForMetier(metier);
    for (final e in entities) {
      final c = SrmConfig.getEntityConfig(metier, e);
      if (c == null) continue;
      final tableName = c['tableName']?.toString() ?? '';
      if (!FormulaireConfigMobileService.isSelectableFormTable(tableName)) {
        continue;
      }
      if (geometryFilter == 'point' &&
          c['isLine'] != true &&
          c['isPolygon'] != true) {
        return true;
      }
      if (geometryFilter == 'line' && c['isLine'] == true) return true;
      if (geometryFilter == 'polygon' && c['isPolygon'] == true) return true;
    }
    return false;
  }

  int _staticCount(String metier) {
    bool isSelectableEntity(String entity) {
      final config = SrmConfig.getEntityConfig(metier, entity);
      final tableName = config?['tableName']?.toString() ?? '';
      return FormulaireConfigMobileService.isSelectableFormTable(tableName);
    }

    if (geometryFilter == 'line') {
      return SrmConfig.getLineEntities(metier).where(isSelectableEntity).length;
    }
    if (geometryFilter == 'polygon') {
      return SrmConfig.getPolygonEntities(metier)
          .where(isSelectableEntity)
          .length;
    }
    return SrmConfig.getPointEntities(metier).where(isSelectableEntity).length;
  }

  String get _geoLabel {
    switch (geometryFilter) {
      case 'line':
        return 'linéaire';
      case 'polygon':
        return 'polygone';
      default:
        return 'ponctuel';
    }
  }

  @override
  Widget build(BuildContext context) {
    final metiers = SrmConfig.getMetiers().where(_metierHasGeometry).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Sélectionner le métier',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          Text(
            'Objet $_geoLabel',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 16),
          if (metiers.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Aucun métier disponible pour ce type de géométrie'),
            )
          else
            ...metiers.map((m) {
              final color = Color(SrmConfig.getMetierColor(m));
              final iconName = SrmConfig.getMetierIcon(m);

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(_iconData(iconName), color: color),
                ),
                title: Text(
                  m,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: FutureBuilder<List<FormulaireConfigMobileEntity>>(
                  future: FormulaireConfigMobileService().getMobileEntities(
                    mobileMetier: m,
                    geometryFilter: geometryFilter,
                  ),
                  builder: (context, snapshot) {
                    final count = snapshot.data?.length ?? _staticCount(m);
                    return Text('$count type${count > 1 ? "s" : ""}');
                  },
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(context, m),
              );
            }),
        ],
      ),
    );
  }

  IconData _iconData(String name) {
    switch (name) {
      case 'water_drop':
        return Icons.water_drop;
      case 'plumbing':
        return Icons.plumbing;
      case 'bolt':
        return Icons.bolt;
      default:
        return Icons.category;
    }
  }
}

class _EntitySheet extends StatefulWidget {
  final String metier;
  final String geometryFilter;
  const _EntitySheet({required this.metier, required this.geometryFilter});

  @override
  State<_EntitySheet> createState() => _EntitySheetState();
}

class _EntitySheetState extends State<_EntitySheet> {
  late final Future<List<FormulaireConfigMobileEntity>> _entitiesFuture;

  @override
  void initState() {
    super.initState();
    _entitiesFuture = FormulaireConfigMobileService().getMobileEntities(
      mobileMetier: widget.metier,
      geometryFilter: widget.geometryFilter,
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(SrmConfig.getMetierColor(widget.metier));

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scroll) {
        return FutureBuilder<List<FormulaireConfigMobileEntity>>(
          future: _entitiesFuture,
          builder: (context, snapshot) {
            final entities =
                snapshot.data ?? const <FormulaireConfigMobileEntity>[];
            final isLoading =
                snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: color.withValues(alpha: 0.15),
                        child: Icon(Icons.list, color: color),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.metier,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '${entities.length} type${entities.length > 1 ? "s" : ""}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(),
                if (isLoading)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (entities.isEmpty)
                  const Expanded(
                    child: Center(child: Text('Aucun type disponible')),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      controller: scroll,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: entities.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, i) {
                        final entity = entities[i];

                        // L'icone et la couleur viennent de la meme source que
                        // les marqueurs cartes (CustomMarkerIcons.iconConfig),
                        // afin que la selection metier reflete visuellement
                        // l'objet une fois pose sur la carte. lookupConfig() est
                        // case-insensitive et tolere les variantes asst_/ass_,
                        // les tableNames Postgres etant en MAJUSCULES.
                        final markerConfig = CustomMarkerIcons.lookupConfig(
                          entity.tableName,
                        );
                        final entityIcon = markerConfig?.icon ??
                            _geometryIcon(widget.geometryFilter);
                        final entityColor = markerConfig?.color ?? color;

                        return ListTile(
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor:
                                entityColor.withValues(alpha: 0.15),
                            child: Icon(
                              entityIcon,
                              color: entityColor,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            entity.titleApp,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right, size: 18),
                          onTap: () => Navigator.pop(ctx, entity),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  IconData _geometryIcon(String filter) {
    switch (filter) {
      case 'line':
        return Icons.timeline;
      case 'polygon':
        return Icons.pentagon_outlined;
      default:
        return Icons.place;
    }
  }
}

/// Sheet d'entites filtre aux 9 types "piece de regard" (cf.
/// [regardPieceTableNames]). Pas de fallback statique : si la config
/// formulaire mobile n'est pas chargee, on affiche les 9 entrees minimales
/// quand meme pour ne pas bloquer l'agent terrain.
class _RegardPieceEntitySheet extends StatefulWidget {
  final String geometryFilter;
  const _RegardPieceEntitySheet({required this.geometryFilter});

  @override
  State<_RegardPieceEntitySheet> createState() =>
      _RegardPieceEntitySheetState();
}

class _RegardPieceEntitySheetState extends State<_RegardPieceEntitySheet> {
  late final Future<List<FormulaireConfigMobileEntity>> _entitiesFuture;

  @override
  void initState() {
    super.initState();
    _entitiesFuture = _loadEntities();
  }

  Future<List<FormulaireConfigMobileEntity>> _loadEntities() async {
    final service = FormulaireConfigMobileService();
    final entities = await service.getMobileEntities(
      mobileMetier: 'Eau Potable',
      geometryFilter: widget.geometryFilter,
    );
    final filtered = entities.where(_matchesGeometry).toList();
    if (filtered.isNotEmpty) return filtered;
    // Fallback statique si la config mobile n'est pas encore en cache local.
    return _staticFallbackEntities().where(_matchesGeometry).toList();
  }

  bool _matchesGeometry(FormulaireConfigMobileEntity e) {
    if (!regardPieceTableNames.contains(e.tableName)) return false;
    if (widget.geometryFilter == 'line') {
      return e.tableName == 'conduite_terrain' || e.isLine;
    }
    return e.tableName != 'conduite_terrain' && !e.isLine;
  }

  List<FormulaireConfigMobileEntity> _staticFallbackEntities() {
    // Construit a partir des entityType/tableName figes dans srm_config.dart
    // pour les 9 cibles. L'ordre est celui du brief utilisateur.
    const order = <List<String>>[
      ['Vanne', 'vanne', 'Vanne'],
      ['Vanne de Vidange', 'vanne_de_vidange', 'Vidange'],
      ['Ventouse', 'ventouse', 'Ventouse'],
      ['Cône de Réduction', 'cone_de_reduction', 'Cône réduc.'],
      ['Compteur Réseau', 'compteur_reseau', 'Compteur'],
      ['Réducteur de Pression', 'reducteur_de_pression', 'Réducteur'],
      ['Obturateur', 'obturateur', 'Obturateur'],
      ['Pompe', 'pompe', 'Pompe'],
      ['Conduite Terrain', 'conduite_terrain', 'Conduite'],
    ];
    var ordre = 0;
    return order
        .map(
          (e) => FormulaireConfigMobileEntity(
            entityType: e[0],
            tableName: e[1],
            schema: 'ep',
            titleApp: e[2],
            ordre: ordre++,
            isLine: e[1] == 'conduite_terrain',
            isPolygon: false,
            hasZ: false,
            maxPhotos: 4,
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(SrmConfig.getMetierColor('Eau Potable'));
    final geometryLabel =
        widget.geometryFilter == 'line' ? 'ligne' : 'point';
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scroll) {
        return FutureBuilder<List<FormulaireConfigMobileEntity>>(
          future: _entitiesFuture,
          builder: (context, snapshot) {
            final entities =
                snapshot.data ?? const <FormulaireConfigMobileEntity>[];
            final isLoading =
                snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: color.withValues(alpha: 0.15),
                        child: Icon(Icons.settings_input_component,
                            color: color),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pièce du regard',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '$geometryLabel - ${entities.length} type${entities.length > 1 ? "s" : ""}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(),
                if (isLoading)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (entities.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text('Aucun type de pièce disponible'),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      controller: scroll,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: entities.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, i) {
                        final entity = entities[i];
                        final markerConfig = CustomMarkerIcons.lookupConfig(
                          entity.tableName,
                        );
                        final entityIcon = markerConfig?.icon ??
                            (entity.isLine ? Icons.timeline : Icons.place);
                        final entityColor = markerConfig?.color ?? color;
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor:
                                entityColor.withValues(alpha: 0.15),
                            child: Icon(
                              entityIcon,
                              color: entityColor,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            entity.titleApp,
                            style:
                                const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: entity.isLine
                              ? const Text('À dessiner')
                              : null,
                          trailing:
                              const Icon(Icons.chevron_right, size: 18),
                          onTap: () => Navigator.pop(ctx, entity),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
