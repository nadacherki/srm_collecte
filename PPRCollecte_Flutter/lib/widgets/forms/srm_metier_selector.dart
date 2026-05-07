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
    if (geometryFilter == 'line') {
      return SrmConfig.getLineEntities(metier).length;
    }
    if (geometryFilter == 'polygon') {
      return SrmConfig.getPolygonEntities(metier).length;
    }
    return SrmConfig.getPointEntities(metier).length;
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
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 6),
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
