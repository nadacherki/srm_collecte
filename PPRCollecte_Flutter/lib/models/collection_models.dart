// lib/collection_models.dart - VERSION CORRIGEE
import 'package:latlong2/latlong.dart';

enum CollectionType { ligne, special }

enum CollectionStatus { inactive, active, paused }

class CollectionBase {
  final int id;
  final String? lineCode;
  final CollectionType type;
  final CollectionStatus status;
  final List<LatLng> points;
  final DateTime startTime;
  final DateTime? lastPointTime;
  final double totalDistance;

  CollectionBase({
    required this.id,
    this.lineCode,
    required this.type,
    required this.status,
    required this.points,
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
    DateTime? startTime,
    DateTime? lastPointTime,
    double? totalDistance,
  }) {
    return LigneCollection(
      id: id ?? this.id,
      lineCode: lineCode ?? this.lineCode!,
      status: status ?? this.status,
      points: points ?? this.points,
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
      startTime: DateTime.parse(json['startTime']),
      lastPointTime: json['lastPointTime'] != null
          ? DateTime.parse(json['lastPointTime'])
          : null,
      totalDistance: json['totalDistance']?.toDouble() ?? 0.0,
    );
  }
}

class SpecialCollection extends CollectionBase {
  final String specialType;

  SpecialCollection({
    required super.id,
    required this.specialType,
    required super.status,
    required super.points,
    required super.startTime,
    super.lastPointTime,
    super.totalDistance,
  }) : super(
          lineCode: null,
          type: CollectionType.special,
        );

  @override
  SpecialCollection copyWith({
    int? id,
    String? lineCode,
    String? specialType,
    CollectionType? type,
    CollectionStatus? status,
    List<LatLng>? points,
    DateTime? startTime,
    DateTime? lastPointTime,
    double? totalDistance,
  }) {
    return SpecialCollection(
      id: id ?? this.id,
      specialType: specialType ?? this.specialType,
      status: status ?? this.status,
      points: points ?? this.points,
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
  final double totalDistance;
  final DateTime startTime;
  final DateTime endTime;

  CollectionResult({
    required this.id,
    this.lineCode,
    required this.type,
    required this.points,
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
      'totalDistance': totalDistance,
      'startTime': startTime,
      'endTime': endTime,
    };
  }
}

class CollectionPointEdit {
  final LatLng point;
  final double? altitude;

  const CollectionPointEdit({
    required this.point,
    this.altitude,
  });
}
