// lib/models/line_model.dart
import 'dart:convert';

int generateTimestampId() {
  final now = DateTime.now();
  final idString =
      '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
      '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}'
      '${now.second.toString().padLeft(2, '0')}${now.millisecond.toString().padLeft(3, '0')}';

  return int.parse(idString);
}

String generateLineCode() {
  final now = DateTime.now();
  final timestamp =
      '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
      '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}'
      '${now.second.toString().padLeft(2, '0')}${now.millisecond.toString().padLeft(3, '0')}';

  return 'Ligne_$timestamp';
}

class LineModel {
  final int? id;
  final String lineCode;
  final String userLogin;
  final String startTime;
  final String endTime;
  final String originName;
  final double originX;
  final double originY;
  final String destinationName;
  final double destinationX;
  final double destinationY;
  final String? completedWorks;
  final String? workDate;
  final String? company;
  final String pointsJson;
  final String createdAt;
  final String? updatedAt;
  final bool hasIntersection;
  final int intersectionCount;
  final String intersectionsJson;
  final int? loginId;
  final String? platform;
  final String? relief;
  final String? vegetation;
  final String? workStart;
  final String? workEnd;
  final String? funding;
  final String? project;
  final double? serviceLevel;
  final double? functionality;
  final double? socioAdministrativeInterest;
  final double? servedPopulation;
  final double? agriculturalPotential;
  final double? investmentCost;
  final double? environmentalProtection;
  final double? globalScore;

  LineModel({
    int? id,
    String? lineCode,
    required this.userLogin,
    required this.startTime,
    required this.endTime,
    required this.originName,
    required this.originX,
    required this.originY,
    required this.destinationName,
    required this.destinationX,
    required this.destinationY,
    this.completedWorks,
    this.workDate,
    this.company,
    required this.pointsJson,
    required this.createdAt,
    required this.updatedAt,
    this.hasIntersection = false,
    this.intersectionCount = 0,
    this.intersectionsJson = '[]',
    this.loginId,
    this.platform,
    this.relief,
    this.vegetation,
    this.workStart,
    this.workEnd,
    this.funding,
    this.project,
    this.serviceLevel,
    this.functionality,
    this.socioAdministrativeInterest,
    this.servedPopulation,
    this.agriculturalPotential,
    this.investmentCost,
    this.environmentalProtection,
    this.globalScore,
  }) : id = id ?? generateTimestampId(),
       lineCode = lineCode ?? generateLineCode();

  factory LineModel.fromFormData(Map<String, dynamic> formData) {
    final pointsData = formData['points'] as List<dynamic>? ?? [];

    return LineModel(
      id: formData['id'] ?? generateTimestampId(),
      lineCode: formData['line_code'] ?? generateLineCode(),
      userLogin: formData['user_login'] ?? '',
      startTime: formData['start_time'] ?? '',
      endTime: formData['end_time'] ?? '',
      originName: formData['origin_name'] ?? '',
      originX: _parseDouble(formData['origin_x']),
      originY: _parseDouble(formData['origin_y']),
      destinationName: formData['destination_name'] ?? '',
      destinationX: _parseDouble(formData['destination_x']),
      destinationY: _parseDouble(formData['destination_y']),
      completedWorks: formData['completed_works'],
      workDate: formData['work_date'],
      company: formData['company'],
      pointsJson: jsonEncode(pointsData),
      createdAt: formData['created_at'] ?? DateTime.now().toIso8601String(),
      updatedAt: formData['updated_at'],
      hasIntersection: _parseBool(formData['has_intersection']),
      intersectionCount: _parseInt(formData['intersection_count']),
      intersectionsJson: formData['intersections_json'] is String
          ? formData['intersections_json']
          : jsonEncode(formData['intersections_json'] ?? []),
      loginId: formData['login_id'],
      platform: formData['platform'],
      relief: formData['relief'],
      vegetation: formData['vegetation'],
      workStart: formData['work_start'],
      workEnd: formData['work_end'],
      funding: formData['funding'],
      project: formData['project'],
      serviceLevel: _parseNullableDouble(formData['service_level']),
      functionality: _parseNullableDouble(formData['functionality']),
      socioAdministrativeInterest:
          _parseNullableDouble(formData['socio_administrative_interest']),
      servedPopulation: _parseNullableDouble(formData['served_population']),
      agriculturalPotential:
          _parseNullableDouble(formData['agricultural_potential']),
      investmentCost: _parseNullableDouble(formData['investment_cost']),
      environmentalProtection:
          _parseNullableDouble(formData['environmental_protection']),
      globalScore: _parseNullableDouble(formData['global_score']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'line_code': lineCode,
      'user_login': userLogin,
      'start_time': startTime,
      'end_time': endTime,
      'origin_name': originName,
      'origin_x': originX,
      'origin_y': originY,
      'destination_name': destinationName,
      'destination_x': destinationX,
      'destination_y': destinationY,
      'completed_works': completedWorks,
      'work_date': workDate,
      'company': company,
      'points_json': pointsJson,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'has_intersection': hasIntersection ? 1 : 0,
      'intersection_count': intersectionCount,
      'intersections_json': intersectionsJson,
      'login_id': loginId,
      'platform': platform,
      'relief': relief,
      'vegetation': vegetation,
      'work_start': workStart,
      'work_end': workEnd,
      'funding': funding,
      'project': project,
      'service_level': serviceLevel,
      'functionality': functionality,
      'socio_administrative_interest': socioAdministrativeInterest,
      'served_population': servedPopulation,
      'agricultural_potential': agriculturalPotential,
      'investment_cost': investmentCost,
      'environmental_protection': environmentalProtection,
      'global_score': globalScore,
    };
  }

  factory LineModel.fromMap(Map<String, dynamic> map) {
    return LineModel(
      id: map['id'],
      lineCode: map['line_code'] ?? '',
      userLogin: map['user_login'] ?? '',
      startTime: map['start_time'] ?? '',
      endTime: map['end_time'] ?? '',
      originName: map['origin_name'] ?? '',
      originX: _parseDouble(map['origin_x']),
      originY: _parseDouble(map['origin_y']),
      destinationName: map['destination_name'] ?? '',
      destinationX: _parseDouble(map['destination_x']),
      destinationY: _parseDouble(map['destination_y']),
      completedWorks: map['completed_works'],
      workDate: map['work_date'],
      company: map['company'],
      pointsJson: map['points_json'] ?? '[]',
      createdAt: map['created_at'] ?? DateTime.now().toIso8601String(),
      updatedAt: map['updated_at'] ?? DateTime.now().toIso8601String(),
      hasIntersection: _parseBool(map['has_intersection']),
      intersectionCount: _parseInt(map['intersection_count']),
      intersectionsJson: map['intersections_json']?.toString() ?? '[]',
      loginId: map['login_id'],
      platform: map['platform'],
      relief: map['relief'],
      vegetation: map['vegetation'],
      workStart: map['work_start'],
      workEnd: map['work_end'],
      funding: map['funding'],
      project: map['project'],
      serviceLevel: _parseNullableDouble(map['service_level']),
      functionality: _parseNullableDouble(map['functionality']),
      socioAdministrativeInterest:
          _parseNullableDouble(map['socio_administrative_interest']),
      servedPopulation: _parseNullableDouble(map['served_population']),
      agriculturalPotential:
          _parseNullableDouble(map['agricultural_potential']),
      investmentCost: _parseNullableDouble(map['investment_cost']),
      environmentalProtection:
          _parseNullableDouble(map['environmental_protection']),
      globalScore: _parseNullableDouble(map['global_score']),
    );
  }

  static bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value == '1' || value.toLowerCase() == 'true';
    return false;
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static double? _parseNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  List<Map<String, dynamic>> get intersections {
    try {
      final decoded = jsonDecode(intersectionsJson);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
