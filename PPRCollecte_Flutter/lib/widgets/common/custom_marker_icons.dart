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
    // SRM Électricité
    'support': MarkerIconConfig(
      icon: Icons.bolt,
      color: const Color(0xFFF57C00),
    ),
    'poste': MarkerIconConfig(
      icon: Icons.electrical_services,
      color: const Color(0xFFFB8C00),
    ),
    'coffret_bt': MarkerIconConfig(
      icon: Icons.inventory_2,
      color: const Color(0xFFFF9800),
    ),
    'noeud_raccord': MarkerIconConfig(
      icon: Icons.hub,
      color: const Color(0xFFFFB300),
    ),
    'point_desserte': MarkerIconConfig(
      icon: Icons.flash_on,
      color: const Color(0xFFFFA000),
    ),
  };

  /// Retourne un Widget pour le marqueur (utilisé dans flutter_map)
  static Widget getMarkerWidget(String tableName, {double size = 40.0, VoidCallback? onTap}) {
    final config = iconConfig[tableName];

    if (config == null) {
      return _buildDefaultMarker(size, onTap);
    }

    return _buildCustomMarker(config, size, onTap);
  }

  /// Construit un marqueur personnalisé
  static Widget _buildCustomMarker(MarkerIconConfig config, double size, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: config.color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          config.icon,
          color: Colors.white,
          size: size * 0.6,
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

  /// Retourne la couleur pour une table donnée
  static Color getColorForTable(String tableName) {
    return iconConfig[tableName]?.color ?? Colors.red;
  }

  /// Retourne l'icône pour une table donnée
  static IconData getIconForTable(String tableName) {
    return iconConfig[tableName]?.icon ?? Icons.location_pin;
  }

  // Méthodes de compatibilité (pour ne pas casser le code existant)
  static int getCacheSize() => 0; // Plus de cache nécessaire
  static void clearCache() {} // Plus de cache nécessaire
}

class MarkerIconConfig {
  final IconData icon;
  final Color color;

  MarkerIconConfig({
    required this.icon,
    required this.color,
  });
}
