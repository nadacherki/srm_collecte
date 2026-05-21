// lib/collection_models.dart - VERSION CORRIGEE
import 'package:latlong2/latlong.dart';

enum CollectionType { ligne, polygon }

enum CollectionStatus { inactive, active, paused }

class CapturedGnssPoint {
  final double latitude;
  final double longitude;
  final double? projectedX;
  final double? projectedY;
  final double? projectedZ;

  const CapturedGnssPoint({
    required this.latitude,
    required this.longitude,
    this.projectedX,
    this.projectedY,
    this.projectedZ,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  Map<String, dynamic> toJson() {
    return {
      'lat': latitude,
      'lng': longitude,
      'x': projectedX,
      'y': projectedY,
      'z': projectedZ,
    };
  }

  factory CapturedGnssPoint.fromJson(Map<String, dynamic> json) {
    double? asDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '');
    }

    return CapturedGnssPoint(
      latitude: asDouble(json['lat'] ?? json['latitude']) ?? 0.0,
      longitude: asDouble(json['lng'] ?? json['lon'] ?? json['longitude']) ??
          0.0,
      projectedX: asDouble(json['x'] ?? json['projected_x']),
      projectedY: asDouble(json['y'] ?? json['projected_y']),
      projectedZ: asDouble(json['z'] ?? json['projected_z']),
    );
  }
}

class CollectionBase {
  final int id;
  final String? lineCode;
  final CollectionType type;
  final CollectionStatus status;
  final List<LatLng> points;
  final List<CapturedGnssPoint> gnssPoints;
  final DateTime startTime;
  final DateTime? lastPointTime;
  final double totalDistance;

  CollectionBase({
    required this.id,
    this.lineCode,
    required this.type,
    required this.status,
    required this.points,
    this.gnssPoints = const [],
    required this.startTime,
    this.lastPointTime,
    this.totalDistance = 0.0,
  });

  CollectionBase copyWith({
    int? id,
    String? lineCode,
    CollectionType? type,
    CollectionStatus? status,
    List<LatLng>? points,
    List<CapturedGnssPoint>? gnssPoints,
    DateTime? startTime,
    DateTime? lastPointTime,
    double? totalDistance,
  }) {
    return CollectionBase(
      id: id ?? this.id,
      lineCode: lineCode ?? this.lineCode,
      type: type ?? this.type,
      status: status ?? this.status,
      points: points ?? this.points,
      gnssPoints: gnssPoints ?? this.gnssPoints,
      startTime: startTime ?? this.startTime,
      lastPointTime: lastPointTime ?? this.lastPointTime,
      totalDistance: totalDistance ?? this.totalDistance,
    );
  }

  bool get isActive => status == CollectionStatus.active;
  bool get isPaused => status == CollectionStatus.paused;
  bool get isInactive => status == CollectionStatus.inactive;
}

class LigneCollection extends CollectionBase {
  LigneCollection({
    required super.id,
    required String super.lineCode,
    required super.status,
    required super.points,
    super.gnssPoints = const [],
    required super.startTime,
    super.lastPointTime,
    super.totalDistance,
  }) : super(
          type: CollectionType.ligne,
        );

  @override
  LigneCollection copyWith({
    int? id,
    String? lineCode,
    CollectionType? type,
    CollectionStatus? status,
    List<LatLng>? points,
    List<CapturedGnssPoint>? gnssPoints,
    DateTime? startTime,
    DateTime? lastPointTime,
    double? totalDistance,
  }) {
    return LigneCollection(
      id: id ?? this.id,
      lineCode: lineCode ?? this.lineCode!,
      status: status ?? this.status,
      points: points ?? this.points,
      gnssPoints: gnssPoints ?? this.gnssPoints,
      startTime: startTime ?? this.startTime,
      lastPointTime: lastPointTime ?? this.lastPointTime,
      totalDistance: totalDistance ?? this.totalDistance,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lineCode': lineCode,
      'type': 'ligne',
      'status': status.toString(),
      'points':
          points.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
      'gnssPoints': gnssPoints.map((p) => p.toJson()).toList(),
      'startTime': startTime.toIso8601String(),
      'lastPointTime': lastPointTime?.toIso8601String(),
      'totalDistance': totalDistance,
    };
  }

  factory LigneCollection.fromJson(Map<String, dynamic> json) {
    return LigneCollection(
      id: json['id'],
      lineCode: json['lineCode'],
      status: CollectionStatus.values.firstWhere(
        (e) => e.toString() == json['status'],
      ),
      points: (json['points'] as List)
          .map((p) => LatLng(p['lat'], p['lng']))
          .toList(),
      gnssPoints: ((json['gnssPoints'] as List?) ?? const [])
          .whereType<Map>()
          .map((p) => CapturedGnssPoint.fromJson(Map<String, dynamic>.from(p)))
          .toList(),
      startTime: DateTime.parse(json['startTime']),
      lastPointTime: json['lastPointTime'] != null
          ? DateTime.parse(json['lastPointTime'])
          : null,
      totalDistance: json['totalDistance']?.toDouble() ?? 0.0,
    );
  }
}

class PolygonCollection extends CollectionBase {
  final String entityType;

  PolygonCollection({
    required super.id,
    required this.entityType,
    required super.status,
    required super.points,
    super.gnssPoints = const [],
    required super.startTime,
    super.lastPointTime,
    super.totalDistance,
  }) : super(
          lineCode: null,
          type: CollectionType.polygon,
        );

  @override
  PolygonCollection copyWith({
    int? id,
    String? lineCode,
    String? entityType,
    CollectionType? type,
    CollectionStatus? status,
    List<LatLng>? points,
    List<CapturedGnssPoint>? gnssPoints,
    DateTime? startTime,
    DateTime? lastPointTime,
    double? totalDistance,
  }) {
    return PolygonCollection(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      status: status ?? this.status,
      points: points ?? this.points,
      gnssPoints: gnssPoints ?? this.gnssPoints,
      startTime: startTime ?? this.startTime,
      lastPointTime: lastPointTime ?? this.lastPointTime,
      totalDistance: totalDistance ?? this.totalDistance,
    );
  }
}

class CollectionResult {
  final int id;
  final String? lineCode;
  final CollectionType type;
  final List<LatLng> points;
  final List<CapturedGnssPoint> gnssPoints;
  final double totalDistance;
  final DateTime startTime;
  final DateTime endTime;

  CollectionResult({
    required this.id,
    this.lineCode,
    required this.type,
    required this.points,
    this.gnssPoints = const [],
    required this.totalDistance,
    required this.startTime,
    required this.endTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'lineCode': lineCode,
      'type': type.toString(),
      'points': points,
      'gnssPoints': gnssPoints.map((p) => p.toJson()).toList(),
      'totalDistance': totalDistance,
      'startTime': startTime,
      'endTime': endTime,
    };
  }
}

class CollectionPointEdit {
  final LatLng point;
  final double? altitude;
  final CapturedGnssPoint? gnssPoint;

  const CollectionPointEdit({
    required this.point,
    this.altitude,
    this.gnssPoint,
  });
}
