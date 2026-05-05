// custom_marker_icons.dart - VERSION FLUTTER_MAP
import 'package:flutter/material.dart';

class CustomMarkerIcons {
  // Configuration des icônes par table
  static final Map<String, MarkerIconConfig> iconConfig = {
    'localites': MarkerIconConfig(
      icon: Icons.home,
      color: const Color(0xFFE67E22), // Orange
    ),
    'ecoles': MarkerIconConfig(
      icon: Icons.school,
      color: const Color(0xFF27AE60), // Vert
    ),
    'marches': MarkerIconConfig(
      icon: Icons.shopping_cart,
      color: const Color(0xFFF1C40F), // Jaune
    ),
    'services_santes': MarkerIconConfig(
      icon: Icons.local_hospital,
      color: const Color(0xFFE74C3C), // Rouge
    ),
    'batiments_administratifs': MarkerIconConfig(
      icon: Icons.business,
      color: const Color(0xFF34495E), // Gris foncé
    ),
    'infrastructures_hydrauliques': MarkerIconConfig(
      icon: Icons.water_drop,
      color: const Color(0xFF3498DB), // Bleu
    ),
    'autres_infrastructures': MarkerIconConfig(
      icon: Icons.location_pin,
      color: const Color(0xFF95A5A6), // Gris
    ),
    'ponts': MarkerIconConfig(
      icon: Icons.account_balance,
      color: const Color(0xFF9B59B6), // Violet
    ),
    'buses': MarkerIconConfig(
      icon: Icons.circle,
      color: const Color(0xFF7F8C8D), // Gris moyen
    ),
    'dalots': MarkerIconConfig(
      icon: Icons.water,
      color: const Color(0xFF3498DB), // Bleu
    ),
    'points_critiques': MarkerIconConfig(
      icon: Icons.warning,
      color: const Color(0xFFD35400), // Orange foncé
    ),
    'points_coupures': MarkerIconConfig(
      icon: Icons.close,
      color: const Color(0xFFC0392B), // Rouge foncé
    ),
    'site_enquete': MarkerIconConfig(
      icon: Icons.adjust,
      color: const Color(0xFF212121), // Noir (comme le web)
    ),
    'enquete_polygone': MarkerIconConfig(
      icon: Icons.pentagon,
      color: const Color(0xFF1B5E20),
    ),
    // SRM Eau Potable
    'vanne': MarkerIconConfig(
      icon: Icons.settings_input_component,
      color: const Color(0xFF1E88E5),
    ),
    'vanne_de_vidange': MarkerIconConfig(
      icon: Icons.settings,
      color: const Color(0xFF1565C0),
    ),
    'ventouse': MarkerIconConfig(
      icon: Icons.air,
      color: const Color(0xFF42A5F5),
    ),
    'hydrant': MarkerIconConfig(
      icon: Icons.local_fire_department,
      color: const Color(0xFFE53935),
    ),
    'borne_fontaine': MarkerIconConfig(
      icon: Icons.water_drop,
      color: const Color(0xFF00ACC1),
    ),
    'borne_onep': MarkerIconConfig(
      icon: Icons.water,
      color: const Color(0xFF26C6DA),
    ),
    'regard_ep': MarkerIconConfig(
      icon: Icons.crop_square,
      color: const Color(0xFF2E7D32),
    ),
    'regard': MarkerIconConfig(
      icon: Icons.crop_square,
      color: const Color(0xFF2E7D32),
    ),
    'bouche_cles': MarkerIconConfig(
      icon: Icons.vpn_key,
      color: const Color(0xFF0288D1),
    ),
    'bouche_darrosage': MarkerIconConfig(
      icon: Icons.yard,
      color: const Color(0xFF00897B),
    ),
    'compteur_reseau': MarkerIconConfig(
      icon: Icons.speed,
      color: const Color(0xFF5C6BC0),
    ),
    'compteur_abonne': MarkerIconConfig(
      icon: Icons.person_pin,
      color: const Color(0xFF7E57C2),
    ),
    'cone_de_reduction': MarkerIconConfig(
      icon: Icons.change_circle,
      color: const Color(0xFF039BE5),
    ),
    'centre_tampon': MarkerIconConfig(
      icon: Icons.adjust,
      color: const Color(0xFF26A69A),
    ),
    'obturateur': MarkerIconConfig(
      icon: Icons.block,
      color: const Color(0xFF1976D2),
    ),
    'reducteur_de_pression': MarkerIconConfig(
      icon: Icons.compress,
      color: const Color(0xFF0097A7),
    ),
    'noeud': MarkerIconConfig(
      icon: Icons.scatter_plot,
      color: const Color(0xFF29B6F6),
    ),
    'reservoir': MarkerIconConfig(
      icon: Icons.water_damage,
      color: const Color(0xFF1565C0),
    ),
    'station_de_pompage': MarkerIconConfig(
      icon: Icons.sync,
      color: const Color(0xFF283593),
    ),
    'forage': MarkerIconConfig(
      icon: Icons.arrow_downward,
      color: const Color(0xFF0277BD),
    ),
    'puit': MarkerIconConfig(
      icon: Icons.circle_outlined,
      color: const Color(0xFF01579B),
    ),
    'pompe': MarkerIconConfig(
      icon: Icons.rotate_right,
      color: const Color(0xFF006064),
    ),
    'autre_objet': MarkerIconConfig(
      icon: Icons.place,
      color: const Color(0xFF78909C),
    ),
    // SRM Assainissement
    'asst_regard': MarkerIconConfig(
      icon: Icons.radio_button_checked,
      color: const Color(0xFF2E7D32),
    ),
    'asst_regard_branchement': MarkerIconConfig(
      icon: Icons.adjust,
      color: const Color(0xFF388E3C),
    ),
    'asst_bassin': MarkerIconConfig(
      icon: Icons.water,
      color: const Color(0xFF43A047),
    ),
    'asst_ouvrage': MarkerIconConfig(
      icon: Icons.account_balance,
      color: const Color(0xFF4CAF50),
    ),
    'asst_equipement': MarkerIconConfig(
      icon: Icons.precision_manufacturing,
      color: const Color(0xFF66BB6A),
    ),
    'asst_station': MarkerIconConfig(
      icon: Icons.factory,
      color: const Color(0xFF1B5E20),
    ),
  };

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

  MarkerIconConfig({
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
