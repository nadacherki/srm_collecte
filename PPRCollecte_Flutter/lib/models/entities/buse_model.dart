class Buse {
  final int? id;
  final double xBuse;
  final double yBuse;
  final String enqueteur;
  final String dateCreation;
  final String? dateModification;
  final String? lineCode;
  final String? codeGps;
  final int? communeId;

  Buse({
    this.id,
    required this.xBuse,
    required this.yBuse,
    required this.enqueteur,
    required this.dateCreation,
    this.dateModification,
    this.lineCode,
    this.codeGps,
    this.communeId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'x_buse': xBuse,
      'y_buse': yBuse,
      'enqueteur': enqueteur,
      'date_creation': dateCreation,
      'date_modification': dateModification,
      'line_code': lineCode,
      'code_gps': codeGps,
      'commune_id': communeId,
    };
  }

  factory Buse.fromMap(Map<String, dynamic> map) {
    return Buse(
      id: map['id'],
      xBuse: map['x_buse'],
      yBuse: map['y_buse'],
      enqueteur: map['enqueteur'],
      dateCreation: map['date_creation'],
      dateModification: map['date_modification'],
      lineCode: map['line_code'],
      codeGps: map['code_gps'],
      communeId: map['commune_id'],
    );
  }
}
