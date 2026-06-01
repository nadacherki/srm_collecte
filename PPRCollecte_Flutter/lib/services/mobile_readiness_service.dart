import '../data/local/database_helper.dart';
import '../data/remote/api_service.dart';
import 'package:sqflite/sqflite.dart';

enum MobileReadinessIssue {
  sessionExpired,
  mobileConfigMissing,
  zoneAssignmentMissing,
}

class MobileReadinessResult {
  final List<MobileReadinessIssue> issues;
  final int? userId;
  final int formulaireConfigCount;
  final int attributConfigCount;
  final int zoneAssignmentCount;
  final int assignedZoneCount;

  const MobileReadinessResult({
    required this.issues,
    required this.userId,
    required this.formulaireConfigCount,
    required this.attributConfigCount,
    required this.zoneAssignmentCount,
    required this.assignedZoneCount,
  });

  bool get isReady => issues.isEmpty;

  String get blockingMessage {
    if (issues.contains(MobileReadinessIssue.sessionExpired)) {
      return 'Session expirée. Veuillez vous reconnecter.';
    }
    if (issues.contains(MobileReadinessIssue.mobileConfigMissing)) {
      return 'Configuration mobile absente. Connectez-vous au serveur puis relancez le rafraîchissement.';
    }
    if (issues.contains(MobileReadinessIssue.zoneAssignmentMissing)) {
      return "Aucune zone affectée à votre compte. Contactez l'administrateur.";
    }
    return 'Action impossible pour le moment. Vérifiez votre session puis réessayez.';
  }
}

class MobileReadinessService {
  MobileReadinessService({DatabaseHelper? databaseHelper})
      : _db = databaseHelper ?? DatabaseHelper();

  final DatabaseHelper _db;

  Future<MobileReadinessResult> checkForDownload() async {
    return _check(requireZones: true);
  }

  Future<MobileReadinessResult> checkForSync() async {
    return _check(requireZones: false);
  }

  Future<MobileReadinessResult> _check({required bool requireZones}) async {
    final issues = <MobileReadinessIssue>[];
    final login = await _db.getSessionLogin();
    final userId = await _db.resolveLoginId();
    if ((login ?? '').trim().isEmpty || userId == null || userId <= 0) {
      issues.add(MobileReadinessIssue.sessionExpired);
    }

    final db = await _db.database;
    final formulaireCount =
        await _countRows(db, 'formulaire_config_mobile_local');
    final attributCount = await _countRows(db, 'attribut_config_mobile_local');
    if (formulaireCount == 0 || attributCount == 0) {
      issues.add(MobileReadinessIssue.mobileConfigMissing);
    }

    var affectationCount = 0;
    var assignedZoneCount = 0;
    if (requireZones && userId != null && userId > 0) {
      affectationCount = (await _db.getZoneUtilisateursLocal(
        idUser: userId,
        activeOnly: true,
      ))
          .length;
      assignedZoneCount = (await _db.getZonesLocal(
        idUser: userId,
        activeOnly: true,
      ))
          .length;
      if (affectationCount == 0 || assignedZoneCount == 0) {
        issues.add(MobileReadinessIssue.zoneAssignmentMissing);
      }
    }

    if (ApiService.userId == null && userId != null && userId > 0) {
      ApiService.userId = userId;
    }

    return MobileReadinessResult(
      issues: issues,
      userId: userId,
      formulaireConfigCount: formulaireCount,
      attributConfigCount: attributCount,
      zoneAssignmentCount: affectationCount,
      assignedZoneCount: assignedZoneCount,
    );
  }

  Future<int> _countRows(Database db, String tableName) async {
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM $tableName');
    final value = rows.first['c'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
