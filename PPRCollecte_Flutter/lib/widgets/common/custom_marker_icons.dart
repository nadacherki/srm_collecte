// custom_marker_icons.dart - VERSION FLUTTER_MAP
import 'package:flutter/material.dart';

class CustomMarkerIcons {
  // Configuration des icônes par table
  static final Map<String, MarkerIconConfig> iconConfig = {
    'localites': const MarkerIconConfig(
      icon: Icons.home,
      color: Color(0xFFE67E22), // Orange
    ),
    'ecoles': const MarkerIconConfig(
      icon: Icons.school,
      color: Color(0xFF27AE60), // Vert
    ),
    'marches': const MarkerIconConfig(
      icon: Icons.shopping_cart,
      color: Color(0xFFF1C40F), // Jaune
    ),
    'services_santes': const MarkerIconConfig(
      icon: Icons.local_hospital,
      color: Color(0xFFE74C3C), // Rouge
    ),
    'batiments_administratifs': const MarkerIconConfig(
      icon: Icons.business,
      color: Color(0xFF34495E), // Gris foncé
    ),
    'infrastructures_hydrauliques': const MarkerIconConfig(
      icon: Icons.water_drop,
      color: Color(0xFF3498DB), // Bleu
    ),
    'autres_infrastructures': const MarkerIconConfig(
      icon: Icons.location_pin,
      color: Color(0xFF95A5A6), // Gris
    ),
    'ponts': const MarkerIconConfig(
      icon: Icons.account_balance,
      color: Color(0xFF9B59B6), // Violet
    ),
    'buses': const MarkerIconConfig(
      icon: Icons.circle,
      color: Color(0xFF7F8C8D), // Gris moyen
    ),
    'dalots': const MarkerIconConfig(
      icon: Icons.water,
      color: Color(0xFF3498DB), // Bleu
    ),
    'points_critiques': const MarkerIconConfig(
      icon: Icons.warning,
      color: Color(0xFFD35400), // Orange foncé
    ),
    'points_coupures': const MarkerIconConfig(
      icon: Icons.close,
      color: Color(0xFFC0392B), // Rouge foncé
    ),
    'site_enquete': const MarkerIconConfig(
      icon: Icons.adjust,
      color: Color(0xFF212121), // Noir (comme le web)
    ),
    'enquete_polygone': const MarkerIconConfig(
      icon: Icons.pentagon,
      color: Color(0xFF1B5E20),
    ),
    // SRM Eau Potable
    'vanne': const MarkerIconConfig(
      icon: Icons.settings_input_component,
      color: Color(0xFF1E88E5),
    ),
    'vanne_de_vidange': const MarkerIconConfig(
      icon: Icons.settings,
      color: Color(0xFF1565C0),
    ),
    'ventouse': const MarkerIconConfig(
      icon: Icons.air,
      color: Color(0xFF42A5F5),
    ),
    'hydrant': const MarkerIconConfig(
      icon: Icons.local_fire_department,
      color: Color(0xFFE53935),
    ),
    'borne_fontaine': const MarkerIconConfig(
      icon: Icons.water_drop,
      color: Color(0xFF00ACC1),
    ),
    'borne_onep': const MarkerIconConfig(
      icon: Icons.water,
      color: Color(0xFF26C6DA),
    ),
    'regard_ep': const MarkerIconConfig(
      icon: Icons.crop_square,
      color: Color(0xFF2E7D32),
    ),
    'regard': const MarkerIconConfig(
      icon: Icons.crop_square,
      color: Color(0xFF2E7D32),
    ),
    'ep_regard_point': const MarkerIconConfig(
      icon: Icons.crop_square,
      color: Color(0xFF2E7D32),
    ),
    'bouche_a_cles': const MarkerIconConfig(
      icon: Icons.vpn_key,
      color: Color(0xFF0288D1),
    ),
    'bouche_cles': const MarkerIconConfig(
      icon: Icons.vpn_key,
      color: Color(0xFF0288D1),
    ),
    'bouche_darrosage': const MarkerIconConfig(
      icon: Icons.yard,
      color: Color(0xFF00897B),
    ),
    'compteur_reseau': const MarkerIconConfig(
      icon: Icons.speed,
      color: Color(0xFF5C6BC0),
    ),
    'compteur_abonne': const MarkerIconConfig(
      icon: Icons.person_pin,
      color: Color(0xFF7E57C2),
    ),
    'cone_de_reduction': const MarkerIconConfig(
      icon: Icons.change_circle,
      color: Color(0xFF039BE5),
    ),
    'centre_tampon': const MarkerIconConfig(
      icon: Icons.adjust,
      color: Color(0xFF26A69A),
    ),
    'obturateur': const MarkerIconConfig(
      icon: Icons.block,
      color: Color(0xFF1976D2),
    ),
    'reducteur_de_pression': const MarkerIconConfig(
      icon: Icons.compress,
      color: Color(0xFF0097A7),
    ),
    'noeud': const MarkerIconConfig(
      icon: Icons.scatter_plot,
      color: Color(0xFF29B6F6),
    ),
    'reservoir': const MarkerIconConfig(
      icon: Icons.water_damage,
      color: Color(0xFF1565C0),
    ),
    'station_de_pompage': const MarkerIconConfig(
      icon: Icons.sync,
      color: Color(0xFF283593),
    ),
    'forage': const MarkerIconConfig(
      icon: Icons.arrow_downward,
      color: Color(0xFF0277BD),
    ),
    'puit': const MarkerIconConfig(
      icon: Icons.circle_outlined,
      color: Color(0xFF01579B),
    ),
    'pompe': const MarkerIconConfig(
      icon: Icons.rotate_right,
      color: Color(0xFF006064),
    ),
    'autre_objet': const MarkerIconConfig(
      icon: Icons.place,
      color: Color(0xFF78909C),
    ),
    // SRM Eau Potable - lignes
    'conduite_terrain': const MarkerIconConfig(
      icon: Icons.linear_scale,
      color: Color(0xFF1976D2),
    ),
    'ep_conduite': const MarkerIconConfig(
      icon: Icons.timeline,
      color: Color(0xFF0D47A1),
    ),
    'branchement': const MarkerIconConfig(
      icon: Icons.call_split,
      color: Color(0xFF1E88E5),
    ),
    'traverse': const MarkerIconConfig(
      icon: Icons.swap_horiz,
      color: Color(0xFF42A5F5),
    ),
    // SRM Assainissement
    'asst_regard': const MarkerIconConfig(
      icon: Icons.radio_button_checked,
      color: Color(0xFF2E7D32),
    ),
    'asst_regard_branchement': const MarkerIconConfig(
      icon: Icons.adjust,
      color: Color(0xFF388E3C),
    ),
    'asst_bassin': const MarkerIconConfig(
      icon: Icons.water,
      color: Color(0xFF43A047),
    ),
    'asst_ouvrage': const MarkerIconConfig(
      icon: Icons.account_balance,
      color: Color(0xFF4CAF50),
    ),
    'asst_equipement': const MarkerIconConfig(
      icon: Icons.precision_manufacturing,
      color: Color(0xFF66BB6A),
    ),
    'asst_station': const MarkerIconConfig(
      icon: Icons.factory,
      color: Color(0xFF1B5E20),
    ),
    // SRM Assainissement - lignes
    'asst_canalisation': const MarkerIconConfig(
      icon: Icons.linear_scale,
      color: Color(0xFF388E3C),
    ),
    'asst_canalisation_reutilisation': const MarkerIconConfig(
      icon: Icons.recycling,
      color: Color(0xFF2E7D32),
    ),
    'asst_branchement': const MarkerIconConfig(
      icon: Icons.call_split,
      color: Color(0xFF43A047),
    ),
    // SRM Assainissement - tables physiques (noms en MAJUSCULES dans Postgres
    // mais lookupConfig() est case-insensitive donc on les met en lowercase).
    'ass_regard': const MarkerIconConfig(
      icon: Icons.radio_button_checked,
      color: Color(0xFF2E7D32),
    ),
    'ass_regard_facade': const MarkerIconConfig(
      icon: Icons.tab,
      color: Color(0xFF388E3C),
    ),
    'ass_borgne': const MarkerIconConfig(
      icon: Icons.lens_blur,
      color: Color(0xFF1B5E20),
    ),
    'ass_bouche': const MarkerIconConfig(
      icon: Icons.vertical_align_bottom,
      color: Color(0xFF43A047),
    ),
    'ass_deversoir': const MarkerIconConfig(
      icon: Icons.waves,
      color: Color(0xFF388E3C),
    ),
    'ass__exutoire': const MarkerIconConfig(
      icon: Icons.output,
      color: Color(0xFF1B5E20),
    ),
    'ass_sta_pomp': const MarkerIconConfig(
      icon: Icons.factory,
      color: Color(0xFF1B5E20),
    ),
    'ass_sta_pomp_s': const MarkerIconConfig(
      icon: Icons.precision_manufacturing,
      color: Color(0xFF2E7D32),
    ),
    'ass_sta_epur': const MarkerIconConfig(
      icon: Icons.science,
      color: Color(0xFF388E3C),
    ),
    'ass_sta_epur_l': const MarkerIconConfig(
      icon: Icons.timeline,
      color: Color(0xFF388E3C),
    ),
    'ass_pompe': const MarkerIconConfig(
      icon: Icons.rotate_right,
      color: Color(0xFF2E7D32),
    ),
    'ass_fosse_sept': const MarkerIconConfig(
      icon: Icons.water_damage,
      color: Color(0xFF1B5E20),
    ),
    'ass_bassin_versant': const MarkerIconConfig(
      icon: Icons.water,
      color: Color(0xFF43A047),
    ),
    'ass_bassin_ret': const MarkerIconConfig(
      icon: Icons.water,
      color: Color(0xFF388E3C),
    ),
    'ass_bassin_ret_l': const MarkerIconConfig(
      icon: Icons.timeline,
      color: Color(0xFF388E3C),
    ),
    'ass_ouv_traversee': const MarkerIconConfig(
      icon: Icons.swap_horiz,
      color: Color(0xFF388E3C),
    ),
    'ass_oued': const MarkerIconConfig(
      icon: Icons.waves,
      color: Color(0xFF43A047),
    ),
    'ass_secteur_ass': const MarkerIconConfig(
      icon: Icons.crop_free,
      color: Color(0xFF2E7D32),
    ),
    'ass_ecoulement': const MarkerIconConfig(
      icon: Icons.water,
      color: Color(0xFF43A047),
    ),
    'ass_points-noirs': const MarkerIconConfig(
      icon: Icons.warning,
      color: Color(0xFFD32F2F),
    ),
    // SRM Assainissement - lignes (variantes Postgres)
    'ass_collecteur': const MarkerIconConfig(
      icon: Icons.linear_scale,
      color: Color(0xFF388E3C),
    ),
    'ass_branchement': const MarkerIconConfig(
      icon: Icons.call_split,
      color: Color(0xFF43A047),
    ),
    'ass_caniveau': const MarkerIconConfig(
      icon: Icons.format_align_justify,
      color: Color(0xFF388E3C),
    ),
    'ass_caniv_branche': const MarkerIconConfig(
      icon: Icons.merge_type,
      color: Color(0xFF43A047),
    ),
    'ass_col_bouche': const MarkerIconConfig(
      icon: Icons.vertical_align_top,
      color: Color(0xFF388E3C),
    ),
    'ass_refoulementr': const MarkerIconConfig(
      icon: Icons.recycling,
      color: Color(0xFF2E7D32),
    ),
  };

  /// Lookup tolerant : essaie la cle telle quelle, puis lowercase, puis les
  /// variantes connues (asst_X <-> ass_X). Utilise par le selector metier
  /// pour matcher les tableNames Postgres en MAJUSCULES (ASS_REGARD, ...).
  static MarkerIconConfig? lookupConfig(String? tableName) {
    if (tableName == null) return null;
    final raw = tableName.trim();
    if (raw.isEmpty) return null;
    if (iconConfig.containsKey(raw)) return iconConfig[raw];
    final lower = raw.toLowerCase();
    if (iconConfig.containsKey(lower)) return iconConfig[lower];
    if (lower.startsWith('asst_')) {
      final assVariant = 'ass_${lower.substring(5)}';
      if (iconConfig.containsKey(assVariant)) return iconConfig[assVariant];
    }
    if (lower.startsWith('ass_')) {
      final asstVariant = 'asst_${lower.substring(4)}';
      if (iconConfig.containsKey(asstVariant)) return iconConfig[asstVariant];
    }
    return null;
  }

  /// Retourne un Widget pour le marqueur (utilisé dans flutter_map)
  static Widget getMarkerWidget(String tableName,
      {double size = 36.0, VoidCallback? onTap}) {
    final config = iconConfig[tableName];

    if (tableName == 'regard' || tableName == 'regard_ep') {
      return _buildRegardMarker(
        size,
        onTap,
        color: config?.color ?? const Color(0xFF2E7D32),
      );
    }

    if (config == null) {
      return _buildDefaultMarker(size, onTap);
    }

    return _buildCustomMarker(config, size, onTap);
  }

  /// Construit un marqueur personnalisé
  static Widget _buildCustomMarker(
      MarkerIconConfig config, double size, VoidCallback? onTap) {
    final borderWidth = size <= 18 ? 1.0 : (size <= 32 ? 1.5 : 2.0);
    final iconSize = size * 0.54;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: config.color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: borderWidth),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.24),
              blurRadius: 3,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
        child: Icon(
          config.icon,
          color: Colors.white,
          size: iconSize,
        ),
      ),
    );
  }

  /// Marqueur par défaut (rouge)
  static Widget _buildDefaultMarker(double size, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(
        Icons.location_pin,
        color: Colors.red,
        size: size,
      ),
    );
  }

  /// Regard EP : meme taille de rendu que les autres points, avec un
  /// pictogramme carre. Le polygone miroir porte l'emprise autour.
  static Widget _buildRegardMarker(
    double size,
    VoidCallback? onTap, {
    required Color color,
  }) {
    final borderWidth = size <= 18 ? 1.0 : (size <= 32 ? 1.5 : 2.0);
    final iconSize = size * 0.56;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: borderWidth),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.24),
              blurRadius: 3,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            Icons.crop_square,
            color: Colors.white,
            size: iconSize,
          ),
        ),
      ),
    );
  }

  /// Retourne la couleur pour une table donnée
  static Color getColorForTable(String tableName) {
    return iconConfig[tableName]?.color ?? Colors.red;
  }

  /// Retourne l'icône pour une table donnée
  static IconData getIconForTable(String tableName) {
    return iconConfig[tableName]?.icon ?? Icons.location_pin;
  }

  // Méthodes de compatibilité (pour ne pas casser le code existant)
  static int getCacheSize() => 0;
  static void clearCache() {}

  // ── Marqueur Anomalie ────────────────────────────────────────────────────
  // Panneau danger terrain : triangle rouge comme un vrai panneau de signalisation.
  // Immédiatement reconnaissable sur le terrain sans ambiguïté.
  static Widget getAnomalieMarkerWidget(String tableName,
      {double size = 40.0, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _WarningSignPainter(),
        ),
      ),
    );
  }

  // ── Marqueur Objet Incomplet ─────────────────────────────────────────────
  // Cercle orange avec icône de l'entité + badge ✏ en haut à droite.
  // Signal clair : objet collecté mais données incomplètes.
  static Widget getIncompletMarkerWidget(String tableName,
      {double size = 40.0, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _IncompletSignPainter(),
        ),
      ),
    );
  }
}

class MarkerIconConfig {
  final IconData icon;
  final Color color;

  const MarkerIconConfig({
    required this.icon,
    required this.color,
  });
}

// ── Panneau danger terrain (triangle rouge) ──────────────────────────────
// Dessiné avec CustomPainter pour ressembler exactement à un panneau
// de signalisation routière : triangle blanc bordé rouge + point d'exclamation.
class _WarningSignPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Ombre portée
    final shadowPath = Path()
      ..moveTo(w * 0.50, h * 0.04)
      ..lineTo(w * 0.97, h * 0.94)
      ..lineTo(w * 0.03, h * 0.94)
      ..close();
    canvas.drawPath(
      shadowPath.shift(const Offset(1.5, 2)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Triangle blanc (fond)
    final bgPath = Path()
      ..moveTo(w * 0.50, h * 0.04)
      ..lineTo(w * 0.97, h * 0.94)
      ..lineTo(w * 0.03, h * 0.94)
      ..close();
    canvas.drawPath(bgPath, Paint()..color = Colors.white);

    // Bordure rouge épaisse
    canvas.drawPath(
      bgPath,
      Paint()
        ..color = const Color(0xFFE53935)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.10
        ..strokeJoin = StrokeJoin.round,
    );

    // Point d'exclamation — trait
    final excPaint = Paint()
      ..color = Colors.black
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.fill;

    // Corps du !
    final excRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.52),
        width: w * 0.115,
        height: h * 0.30,
      ),
      Radius.circular(w * 0.06),
    );
    canvas.drawRRect(excRect, excPaint);

    // Point du !
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.80),
      w * 0.072,
      excPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Panneau objet incomplet (cercle orange + ?) ───────────────────────────
// Cercle orange avec point d'interrogation — évoque un objet à compléter.
class _IncompletSignPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = w * 0.46;

    // Ombre
    canvas.drawCircle(
      center.translate(1.5, 2),
      radius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Cercle orange fond
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = const Color(0xFFF57C00),
    );

    // Bordure blanche
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.09,
    );

    // Point d'interrogation — corps
    final textPainter = TextPainter(
      text: const TextSpan(
        text: '?',
        style: TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2 - 1,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
