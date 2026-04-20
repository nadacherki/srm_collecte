class PolylineTapData {
  final String type;
  final Map<String, dynamic> data;

  PolylineTapData({
    required this.type,
    required this.data,
  });
}

class PolygonTapData {
  final String nom;
  final String lineCode;
  final double superficie;
  final int nbSommets;
  final String enqueteur;
  final String dateCreation;
  final bool synced;
  final bool downloaded;
  final String regionName;
  final String prefectureName;
  final String communeName;

  PolygonTapData({
    required this.nom,
    required this.lineCode,
    required this.superficie,
    required this.nbSommets,
    required this.enqueteur,
    required this.dateCreation,
    required this.synced,
    this.downloaded = false,
    this.regionName = '',
    this.prefectureName = '',
    this.communeName = '',
  });

  String get statut {
    if (downloaded) return 'Sauvegardee (downloaded)';
    if (synced) return 'Synchronisee';
    return 'Enregistree localement';
  }
}
