// lib/core/constants/app_constants.dart
// Constantes globales de l'application SRM Collecte

class AppConstants {
  /// Nom de l'application
  static const String appName = 'SRM Collecte';

  /// Version
  static const String appVersion = '1.0.0';

  /// Paramètres de collecte GPS
  /// Intervalle de capture en secondes
  static const int gpsIntervalSeconds = 20;

  /// Précision minimale acceptable en mètres
  /// (plus strict que GeoDNGR car GNSS RTK centimétrique via mock location)
  static const double gpsMinAccuracyMeters = 5.0;

  /// Distance minimale entre deux points en mètres (anti-bruit)
  static const double gpsMinDistanceMeters = 2.0;

  /// Vitesse maximale acceptable en m/s (rejet des sauts GPS)
  static const double gpsMaxSpeedMs = 50.0;

  /// Rayon de la Terre pour le calcul Haversine (en mètres)
  static const double earthRadiusMeters = 6371000.0;

  /// Timeout de connexion au serveur API
  static const int connectionTimeoutSeconds = 10;

  /// Timeout de probe réseau (ms)
  static const int probeTimeoutMs = 900;

  /// Modes de localisation disponibles dans la base SRM
  static const List<String> modesLocalisation = ['gnss', 'dessin', 'georadar'];

  /// États possibles d'un objet
  static const List<String> etatsObjet = [
    'EN_SERVICE', 'HORS_SERVICE', 'EN_TRAVAUX', 'ABANDONNE', 'PROJETE',
  ];

  /// Rôles utilisateur SRM
  static const List<String> rolesUtilisateur = [
    'admin', 'project_manager', 'editeur_terrain', 'editeur_bureau', 'viewer',
  ];

  /// Statuts de mission
  static const List<String> statutsMission = [
    'EN_COURS', 'CLOTURE', 'PROVISOIRE',
  ];
}
