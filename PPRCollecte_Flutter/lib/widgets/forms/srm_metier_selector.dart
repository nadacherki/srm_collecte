// lib/widgets/forms/srm_metier_selector.dart
// ── SPRINT 5 : Sélecteur de Métier + Type pour collecte SRM ──
// Utilisé par home_page pour Point, Ligne et Polygone

import 'package:flutter/material.dart';
import '../../core/config/srm_config.dart';

/// Résultat de la sélection
class SrmSelection {
  final String metier;
  final String entityType;
  final String tableName;
  final String schema;
  final bool isLine;
  final bool isPolygon;

  const SrmSelection({
    required this.metier,
    required this.entityType,
    required this.tableName,
    required this.schema,
    this.isLine = false,
    this.isPolygon = false,
  });
}

/// Ouvre le sélecteur métier → type pour collecte de POINT
/// Retourne null si annulé
Future<SrmSelection?> showSrmPointSelector(BuildContext context) {
  return _showSrmSelector(context, geometryFilter: 'point');
}

/// Ouvre le sélecteur métier → type pour collecte de LIGNE
Future<SrmSelection?> showSrmLigneSelector(BuildContext context) {
  return _showSrmSelector(context, geometryFilter: 'line');
}

/// Ouvre le sélecteur métier → type pour collecte de POLYGONE
Future<SrmSelection?> showSrmPolygoneSelector(BuildContext context) {
  return _showSrmSelector(context, geometryFilter: 'polygon');
}

Future<SrmSelection?> _showSrmSelector(
  BuildContext context, {
  required String geometryFilter, // 'point' | 'line' | 'polygon'
}) async {
  // Étape 1 : choisir le métier
  final metier = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => _MetierSheet(geometryFilter: geometryFilter),
  );
  if (metier == null) return null;

  // Étape 2 : choisir le type d'entité
  if (!context.mounted) return null;
  final entityType = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) =>
        _EntitySheet(metier: metier, geometryFilter: geometryFilter),
  );
  if (entityType == null) return null;

  final tableName =
      SrmConfig.getTableName(metier, entityType) ?? entityType.toLowerCase();
  final schema = SrmConfig.getSchema(metier, entityType) ?? 'ep';
  final isLine = SrmConfig.isLineEntity(metier, entityType);
  final isPolygon = SrmConfig.isPolygonEntity(metier, entityType);

  return SrmSelection(
    metier: metier,
    entityType: entityType,
    tableName: tableName,
    schema: schema,
    isLine: isLine,
    isPolygon: isPolygon,
  );
}

// ────────────────────────────────────────────────────────────
// Widget feuille — sélection du métier
// ────────────────────────────────────────────────────────────
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
    final metiers = SrmConfig.getMetiers()
        .where(_metierHasGeometry)
        .toList();

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
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text(
            'Sélectionner le métier',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text('Objet $_geoLabel',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
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
              final count = geometryFilter == 'point'
                  ? SrmConfig.getPointEntities(m).length
                  : geometryFilter == 'line'
                      ? SrmConfig.getLineEntities(m).length
                      : SrmConfig.getPolygonEntities(m).length;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withOpacity(0.15),
                  child: Icon(_iconData(iconName), color: color),
                ),
                title: Text(m,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('$count type${count > 1 ? "s" : ""}'),
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

// ────────────────────────────────────────────────────────────
// Widget feuille — sélection du type d'entité
// ────────────────────────────────────────────────────────────
class _EntitySheet extends StatelessWidget {
  final String metier;
  final String geometryFilter;
  const _EntitySheet(
      {required this.metier, required this.geometryFilter});

  @override
  Widget build(BuildContext context) {
    final color = Color(SrmConfig.getMetierColor(metier));

    final entities = geometryFilter == 'point'
        ? SrmConfig.getPointEntities(metier)
        : geometryFilter == 'line'
            ? SrmConfig.getLineEntities(metier)
            : SrmConfig.getPolygonEntities(metier);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scroll) => Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2))),
          ),
          // Titre
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                CircleAvatar(
                    backgroundColor: color.withOpacity(0.15),
                    child: Icon(Icons.list, color: color)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(metier,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('${entities.length} type${entities.length > 1 ? "s" : ""}',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
          // Liste
          Expanded(
            child: ListView.builder(
              controller: scroll,
              itemCount: entities.length,
              itemBuilder: (_, i) {
                final entity = entities[i];
                final config =
                    SrmConfig.getEntityConfig(metier, entity);
                final table = config?['tableName'] ?? '';
                final maxPhotos = config?['maxPhotos'] ?? 0;
                final hasZ = config?['hasZ'] == true;

                return ListTile(
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: color.withOpacity(0.1),
                    child: Icon(_geometryIcon(geometryFilter),
                        color: color, size: 18),
                  ),
                  title: Text(entity,
                      style:
                          const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(
                    'Table: $table'
                    '${hasZ ? "  •  Z" : ""}'
                    '${maxPhotos > 0 ? "  •  📷$maxPhotos" : ""}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () => Navigator.pop(ctx, entity),
                );
              },
            ),
          ),
        ],
      ),
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
