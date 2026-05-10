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
  final String code;
  final String entityType;
  final String metier;
  final double superficie;
  final int nbSommets;
  final String enqueteur;
  final String dateCreation;
  final bool synced;
  final bool downloaded;
  final bool hasAnomalie;
  final bool hasIncomplet;
  final String? typeAnomalie;
  final String regionName;
  final String prefectureName;
  final String communeName;
  final Map<String, dynamic>? editableItem;
  final String? statusOverride;
  final Map<String, String> extraDetails;

  PolygonTapData({
    required this.nom,
    required this.code,
    required this.entityType,
    this.metier = '',
    required this.superficie,
    required this.nbSommets,
    required this.enqueteur,
    required this.dateCreation,
    required this.synced,
    this.downloaded = false,
    this.hasAnomalie = false,
    this.hasIncomplet = false,
    this.typeAnomalie,
    this.regionName = '',
    this.prefectureName = '',
    this.communeName = '',
    this.editableItem,
    this.statusOverride,
    this.extraDetails = const {},
  });

  String get statut {
    final customStatus = statusOverride?.trim() ?? '';
    if (customStatus.isNotEmpty) return customStatus;
    if (downloaded) return 'Sauvegardée (téléchargée)';
    if (synced) return 'Synchronisée';
    return 'Enregistrée localement';
  }
}
