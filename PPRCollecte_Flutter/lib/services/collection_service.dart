import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import '../models/collection_models.dart';
import '../data/remote/api_service.dart';

class CollectionService {
  Timer? _captureTimer;
  StreamSubscription<LocationData>? _locationSubscription;

  // Stockage de la position GPS la plus récente
  LocationData? _currentLocation;
  final List<DateTime> _captureTimestamps = [];

  // ── SPRINT 5 : stockage altitude Z pour chaque point capturé ──
  // Parallèle à collection.points : _altitudesZ[i] = altitude du point i
  final List<double?> _altitudesZ = [];

  // Configuration GPS
  final Duration _captureInterval = const Duration(seconds: 20);
  static const double _minimumAccuracy = 12.0;
  static const double _minimumDistance = 5.0;
  static const double _lowDistanceThreshold = 15.0;
  static const double _maxSpeed = 50.0;

  int _consecutiveLowDistances = 0;
  DateTime? _lastNotificationTime;
  BuildContext? _context;

  void setContext(BuildContext context) {
    _context = context;
  }

  int _countdown = 20;

  // ── SPRINT 5 : Altitude Z courante (depuis GNSS externe via Mock Location) ──
  double? get currentAltitude => _currentLocation?.altitude;

  // ── SPRINT 5 : Récupérer les altitudes Z capturées ──
  List<double?> get capturedAltitudes => List.unmodifiable(_altitudesZ);

  /// Démarre la collecte GPS avec capture toutes les 20s
  void startCollection({
    required CollectionBase collection,
    required Stream<LocationData> locationStream,
    required Function(LatLng point, double distance) onPointAdded,
    Function(int seconds)? onCountdownChanged,
  }) {
    stopCollection();
    _captureTimestamps.clear();
    _altitudesZ.clear(); // Sprint 5 : reset altitudes
    _consecutiveLowDistances = 0;
    _countdown = 20;

    print('🚀 Démarrage collecte GPS SRM - capture toutes les 20s');

    _locationSubscription = locationStream.listen(
      (locationData) {
        _currentLocation = locationData;
        _logGPSQuality(locationData);
      },
      onError: (error) {
        print('❌ Erreur stream GPS: $error');
      },
    );

    // ✅ 2. CAPTURE immédiate du premier point
    _captureFirstPoint(collection, onPointAdded);

    // ✅ 3. TIMER de 1 seconde pour le compte à rebours
    _captureTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!collection.isActive) {
        stopCollection();
        return;
      }

      _countdown--;

      // Notifier le changement de countdown
      if (onCountdownChanged != null) {
        onCountdownChanged(_countdown);
      }

      // ✅ BEEP sonore quand il reste 4 secondes ou moins (4, 3, 2, 1)
      if (_countdown > 0 && _countdown <= 4) {
        _playBeep();
      }

      // ✅ CAPTURE quand le compteur arrive à 0
      if (_countdown <= 0) {
        _captureScheduledPoint(collection, onPointAdded);
        _countdown = 20; // Reset
        if (onCountdownChanged != null) {
          onCountdownChanged(_countdown);
        }
      }
    });
  }

  /// ✅ Joue un petit son système
  void _playBeep() {
    SystemSound.play(SystemSoundType.click);
  }

  /// ✅ CAPTURE immédiate du premier point
  void _captureFirstPoint(CollectionBase collection, Function(LatLng point, double distance) onPointAdded) {
    Timer(const Duration(seconds: 2), () {
      if (_currentLocation != null && collection.isActive) {
        final now = DateTime.now();
        _captureTimestamps.add(now);

        _processLocationForCollection(
          _currentLocation!,
          collection,
          onPointAdded,
          isFirstPoint: true,
        );

        print('📍 Premier point capturé: ${now.toString().substring(11, 19)}');
      }
    });
  }

  /// ✅ CAPTURE programmée toutes les 20 secondes
  void _captureScheduledPoint(
    CollectionBase collection,
    Function(LatLng point, double distance) onPointAdded,
  ) {
    if (_currentLocation == null) {
      print('⚠️ Pas de position GPS disponible pour capture programmée');
      return;
    }

    final now = DateTime.now();
    _captureTimestamps.add(now);

    _processLocationForCollection(_currentLocation!, collection, onPointAdded);

    final captureNumber = _captureTimestamps.length;
    print('📍 Capture #$captureNumber: ${now.toString().substring(11, 19)}');
    // print('⏱️ Prochaine capture dans 20s'); // Géré par le countdown maintenant

    // Validation périodique des intervalles
    if (captureNumber % 5 == 0) {
      _validateCaptureIntervals();
    }
  }

  /// Traite une position GPS pour la collecte
  Future<void> _processLocationForCollection(LocationData locationData, CollectionBase collection, Function(LatLng point, double distance) onPointAdded, {bool isFirstPoint = false}) async {
    if (locationData.latitude == null || locationData.longitude == null) {
      print('❌ Coordonnées GPS invalides');
      return;
    }

    final lat = locationData.latitude!;
    final lon = locationData.longitude!;
    final accuracy = locationData.accuracy ?? 999.0;
    // Sprint 5 : altitude Z depuis le GNSS (Mock Location ou GPS natif)
    final double? altitudeZ = locationData.altitude;

    // Filtre précision
    if (accuracy > _minimumAccuracy) {
      print('❌ Point rejeté: précision insuffisante (${accuracy.toStringAsFixed(1)}m > ${_minimumAccuracy}m)');
      return;
    }

    if (lat.abs() > 90 || lon.abs() > 180) {
      print('❌ Point rejeté: coordonnées invalides');
      return;
    }

    final newPoint = LatLng(lat, lon);

    // Premier point : toujours accepté
    if (collection.points.isEmpty || isFirstPoint) {
      _altitudesZ.add(altitudeZ); // Sprint 5 : stocker Z
      onPointAdded(newPoint, 0.0);
      print('✅ Premier point SRM: précision ${accuracy.toStringAsFixed(1)}m'
          '${altitudeZ != null ? " Z=${altitudeZ.toStringAsFixed(3)}m" : ""}');
      return;
    }

    final lastPoint = collection.points.last;
    final distanceFromLast = _haversineDistance(
      lastPoint.latitude, lastPoint.longitude, lat, lon,
    );

    // Filtre vitesse
    if (_captureTimestamps.length >= 2) {
      final timeDiff = _captureTimestamps.last
          .difference(_captureTimestamps[_captureTimestamps.length - 2])
          .inSeconds;
      if (timeDiff > 0) {
        final speed = distanceFromLast / timeDiff;
        if (speed > _maxSpeed) {
          print('❌ Point rejeté: vitesse irréaliste (${speed.toStringAsFixed(1)} m/s)');
          return;
        }
      }
    }

    // Analyse distance — passe le Z pour le stocker si accepté
    await _analyzeDistanceAndPrompt(
        distanceFromLast, accuracy, collection, newPoint, onPointAdded,
        altitudeZ: altitudeZ);
  }

  /// Analyse distance avec dialogue utilisateur
  Future<void> _analyzeDistanceAndPrompt(
    double distance,
    double accuracy,
    CollectionBase collection,
    LatLng newPoint,
    Function(LatLng point, double distance) onPointAdded, {
    double? altitudeZ, // Sprint 5 : altitude Z du point
  }) async {
    if (distance < _minimumDistance) {
      print('❌ Point rejeté: distance trop faible (${distance.toStringAsFixed(1)}m)');
      _consecutiveLowDistances++;
      await _checkForMovementAdvice();
    } else if (distance < _lowDistanceThreshold) {
      _consecutiveLowDistances++;

      if (await _shouldPromptUser()) {
        final userDecision =
            await _promptUserForLowDistance(distance, accuracy, collection);
        if (userDecision) {
          _altitudesZ.add(altitudeZ); // Sprint 5
          onPointAdded(newPoint, distance);
          print('✅ Point accepté (utilisateur): ${distance.toStringAsFixed(1)}m'
              '${altitudeZ != null ? " Z=${altitudeZ.toStringAsFixed(2)}m" : ""}');
          _resetLowDistanceTracking();
        } else {
          print('❌ Point rejeté (utilisateur)');
        }
      } else {
        _altitudesZ.add(altitudeZ); // Sprint 5
        onPointAdded(newPoint, distance);
        print('✅ Point accepté automatiquement: ${distance.toStringAsFixed(1)}m');
      }
    } else {
      _altitudesZ.add(altitudeZ); // Sprint 5
      onPointAdded(newPoint, distance);
      print('✅ Point SRM accepté: ${distance.toStringAsFixed(1)}m'
          '${altitudeZ != null ? " Z=${altitudeZ.toStringAsFixed(2)}m" : ""}');
      _resetLowDistanceTracking();
    }
  }

  /// 🤔 DÉCIDER si demander à l'utilisateur
  Future<bool> _shouldPromptUser() async {
    final now = DateTime.now();

    // Ne pas notifier si déjà fait récemment (< 1 minute)
    if (_lastNotificationTime != null && now.difference(_lastNotificationTime!).inMinutes < 1) {
      return false;
    }

    // Notifier seulement après plusieurs distances faibles consécutives
    return _consecutiveLowDistances >= 2;
  }

  /// 💬 DIALOGUE utilisateur pour distance faible
  Future<bool> _promptUserForLowDistance(double distance, double accuracy, CollectionBase collection) async {
    if (_context == null) {
      print('⚠️ Context non disponible, acceptation automatique');
      return true;
    }

    _lastNotificationTime = DateTime.now();

    return await showDialog<bool>(
          context: _context!,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

              // 🎨 TITRE avec icône
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.slow_motion_video,
                      color: Colors.orange,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Distance faible détectée',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),

              // 📝 CONTENU du dialogue
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Informations de distance
                  _buildInfoRow('Distance mesurée:', '${distance.toStringAsFixed(1)} m'),
                  _buildInfoRow('Précision GPS:', '±${accuracy.toStringAsFixed(1)} m'),
                  _buildInfoRow('Points collectés:', '${collection.points.length}'),

                  const SizedBox(height: 16),

                  // Message contextuel
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, size: 18, color: Colors.blue[700]),
                            const SizedBox(width: 6),
                            Text(
                              'Mouvement lent détecté',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Pour une collecte optimale, déplacez-vous d\'au moins 10-15 mètres entre les points.',
                          style: TextStyle(fontSize: 13, height: 1.3),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Question principale
                  const Text(
                    'Voulez-vous continuer la collecte avec ce point ?',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              // 🔘 BOUTONS d'action
              actions: [
                // Bouton Ignorer
                TextButton.icon(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Ignorer ce point'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                  ),
                ),

                // Bouton Continuer
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Continuer collecte'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            );
          },
        ).timeout(
          const Duration(seconds: 20),
          onTimeout: () => true, // Par défaut: continuer après 20 secondes
        ) ??
        true;
  }

  /// 📊 WIDGET info row
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  /// 💡 CONSEILS après plusieurs rejets
  Future<void> _checkForMovementAdvice() async {
    if (_consecutiveLowDistances >= 3) {
      await _showMovementAdvice();
    }
  }

  Future<void> _showMovementAdvice() async {
    if (_context == null) return;

    ScaffoldMessenger.of(_context!).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.directions_walk,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Conseil de collecte',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Déplacez-vous plus rapidement pour collecter des points',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue[600],
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  /// 🔄 RESET du tracking
  void _resetLowDistanceTracking() {
    _consecutiveLowDistances = 0;
  }

  /// ✅ VALIDATION des intervalles de capture
  void _validateCaptureIntervals() {
    if (_captureTimestamps.length < 2) return;

    print('=== 📊 VALIDATION CAPTURE 20s ===');

    final intervals = <int>[];
    for (int i = 1; i < _captureTimestamps.length; i++) {
      final interval = _captureTimestamps[i].difference(_captureTimestamps[i - 1]).inSeconds;
      intervals.add(interval);

      final status = interval >= 18 && interval <= 22 ? '✅' : '❌';
      print('$status Intervalle $i: ${interval}s');
    }

    if (intervals.isNotEmpty) {
      final avgInterval = intervals.reduce((a, b) => a + b) / intervals.length;
      final accuracy = (avgInterval - 20.0).abs();

      print('📊 Intervalle moyen: ${avgInterval.toStringAsFixed(1)}s');
      print('🎯 Précision: ±${accuracy.toStringAsFixed(1)}s');
      print('📈 Total captures: ${_captureTimestamps.length}');
    }

    print('================================');
  }

  /// ✅ LOG de la qualité GPS (simplifié)
  void _logGPSQuality(LocationData location) {
    final accuracy = location.accuracy ?? 999;

    // Log simplifié toutes les 10 secondes pour éviter spam
    if (DateTime.now().second % 10 == 0) {
      String quality;
      if (accuracy <= 5) {
        quality = "EXCELLENT";
      } else if (accuracy <= 10)
        quality = "BON";
      else if (accuracy <= 20)
        quality = "MOYEN";
      else
        quality = "MAUVAIS";

      print('📡 GPS: ${accuracy.toStringAsFixed(1)}m ($quality)');
    }
  }

  /// Arrête la collecte
  void stopCollection() {
    _captureTimer?.cancel();
    _captureTimer = null;
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _currentLocation = null;

    if (_captureTimestamps.isNotEmpty) {
      print('🏁 Collecte SRM terminée: ${_captureTimestamps.length} points capturés');
      final zCount = _altitudesZ.where((z) => z != null).length;
      print('   Altitudes Z disponibles: $zCount / ${_altitudesZ.length}');
    }
  }

  // ── SPRINT 5 : Données enrichies SRM pour sauvegarde ──
  /// Retourne la map des données FK SRM à injecter dans chaque entité
  Map<String, dynamic> getSrmFkData() {
    return {
      'id_projet': ApiService.currentProjetId,
      'id_mission': ApiService.currentMissionId,
      'id_agent_crea': ApiService.userId,
      'synced': 0,
      'date_collecte': DateTime.now().toIso8601String(),
    };
  }

  /// Retourne l'altitude Z moyenne des points capturés (pour entités ayant hasZ=true)
  double? getAverageAltitude() {
    final valid = _altitudesZ.whereType<double>().toList();
    if (valid.isEmpty) return null;
    return valid.reduce((a, b) => a + b) / valid.length;
  }

  /// Retourne l'altitude Z du dernier point capturé
  double? getLastAltitude() {
    for (int i = _altitudesZ.length - 1; i >= 0; i--) {
      if (_altitudesZ[i] != null) return _altitudesZ[i];
    }
    return null;
  }

  /// Calcule la distance entre deux points (Haversine)
  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000.0; // Rayon de la Terre en mètres

    final double dLat = _degToRad(lat2 - lat1);
    final double dLon = _degToRad(lon2 - lon1);

    final double a = sin(dLat / 2) * sin(dLat / 2) + cos(_degToRad(lat1)) * cos(_degToRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _degToRad(double degrees) {
    return degrees * (pi / 180.0);
  }

  /// Calcule la distance totale d'une liste de points
  double calculateTotalDistance(List<LatLng> points) {
    if (points.length < 2) return 0.0;

    double totalDistance = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      totalDistance += _haversineDistance(
        points[i].latitude,
        points[i].longitude,
        points[i + 1].latitude,
        points[i + 1].longitude,
      );
    }
    return totalDistance;
  }

  /// Valide qu'une collecte peut se terminer
  bool canFinishCollection(CollectionBase collection) {
    final canFinish = collection.points.length >= 2;

    if (!canFinish) {
      print('❌ Impossible de terminer: seulement ${collection.points.length} point(s)');
    } else {
      print('✅ Collecte peut être terminée: ${collection.points.length} points');
    }

    return canFinish;
  }

  /// Génère un ID unique pour une collecte
  String generateCollectionId(CollectionType type) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (Random().nextDouble() * 9999).round();
    final prefix = type == CollectionType.ligne ? 'LIGNE' : 'CHAUSSEE';
    return '${prefix}_${timestamp}_$random';
  }

  /// 🔍 DEBUG de l'état de la collecte
  void debugCollectionStatus() {
    print('=== 🔍 DEBUG COLLECTION ===');
    print('Timer actif: ${_captureTimer?.isActive ?? false}');
    print('Stream GPS actif: ${_locationSubscription != null}');
    print('Position actuelle: ${_currentLocation != null ? "Disponible" : "Indisponible"}');
    print('Captures effectuées: ${_captureTimestamps.length}');
    print('Distances faibles consécutives: $_consecutiveLowDistances');

    if (_currentLocation != null) {
      print('Dernière position: ${_currentLocation!.latitude?.toStringAsFixed(6)}, ${_currentLocation!.longitude?.toStringAsFixed(6)}');
      print('Précision: ${_currentLocation!.accuracy?.toStringAsFixed(1)}m');
    }

    if (_captureTimestamps.isNotEmpty) {
      final lastCapture = _captureTimestamps.last;
      final timeSinceLastCapture = DateTime.now().difference(lastCapture).inSeconds;
      print('Dernière capture: il y a ${timeSinceLastCapture}s');
      print('Prochaine capture: dans ${20 - (timeSinceLastCapture % 20)}s');
    }

    print('============================');
  }

  /// Dispose des ressources
  void dispose() {
    stopCollection();
  }
}
