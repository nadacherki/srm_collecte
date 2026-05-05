import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/config/srm_config.dart';
import '../../data/local/database_helper.dart';
import '../../data/remote/api_service.dart';
import '../../services/public_metrics_cache_service.dart';

class ProfilePage extends StatefulWidget {
  static const String startConduiteDrawingEpResult =
      'start_conduite_drawing_ep';
  static const String startConduiteDrawingAsstResult =
      'start_conduite_drawing_asst';
  static const String startConduiteDrawingResult = startConduiteDrawingEpResult;

  final String agentName;
  final VoidCallback onLogout;

  const ProfilePage({
    super.key,
    required this.agentName,
    required this.onLogout,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final DatabaseHelper _db = DatabaseHelper();
  late final PublicMetricsCacheService _metricsCache;

  bool _isLoading = true;

  String _nomPrenom = '';
  String _login = '';
  String _role = '';

  int? _activeAgentId;

  int _totalEP = 0;
  int _totalASS = 0;
  int _totalSynced = 0;
  int _totalUnsynced = 0;
  int _localPendingNew = 0;
  int _localPendingUpdates = 0;
  int _localPendingPhotos = 0;
  int _localFailedPhotos = 0;
  int _localPendingHistory = 0;
  int _totalPoints = 0;
  int _totalLignes = 0;
  int _totalPolygones = 0;

  Map<String, dynamic>? _resumeMetrics;
  Map<String, dynamic>? _dayMetrics;
  Map<String, dynamic>? _weekMetrics;
  Map<String, dynamic>? _monthMetrics;
  DateTime? _metricsFetchedAt;
  String? _metricsError;

  bool get _hasServerMetrics =>
      _resumeMetrics != null ||
      _dayMetrics != null ||
      _weekMetrics != null ||
      _monthMetrics != null;

  @override
  void initState() {
    super.initState();
    _metricsCache = PublicMetricsCacheService(databaseHelper: _db);
    _loadData();
  }

  Future<void> _loadData({bool waitForMetricsRefresh = false}) async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final currentUser = await _db.getCurrentUserSrm();
      final activeAgentId =
          ApiService.userId ?? _asIntOrNull(currentUser?['id_user']);
      final results = await Future.wait<dynamic>([
        _loadLocalInventorySnapshot(),
        _metricsCache.loadSnapshot(
          agentId: activeAgentId,
        ),
      ]);
      final inventory = results[0] as _LocalInventorySnapshot;
      final cachedMetrics = results[1] as PublicMetricsCacheSnapshot;

      if (!mounted) return;

      setState(() {
        _nomPrenom = _coalesceText(
          ApiService.nomPrenom,
          DatabaseHelper.fullNameFromUserRow(currentUser),
          widget.agentName,
        );
        _login = _coalesceText(ApiService.userLogin, currentUser?['login']);
        _role = _coalesceText(ApiService.userRole, currentUser?['role']);

        _activeAgentId = activeAgentId;

        _totalEP = inventory.totalEP;
        _totalASS = inventory.totalASS;
        _totalSynced = inventory.totalSynced;
        _totalUnsynced = inventory.totalUnsynced;
        _localPendingNew = inventory.pendingNewObjects;
        _localPendingUpdates = inventory.pendingUpdatedObjects;
        _localPendingPhotos = inventory.pendingPhotos;
        _localFailedPhotos = inventory.failedPhotos;
        _localPendingHistory = inventory.pendingHistoryItems;
        _totalPoints = inventory.totalPoints;
        _totalLignes = inventory.totalLignes;
        _totalPolygones = inventory.totalPolygones;

        if (cachedMetrics.hasAnyData) {
          _resumeMetrics = cachedMetrics.resume;
          _dayMetrics = cachedMetrics.day;
          _weekMetrics = cachedMetrics.week;
          _monthMetrics = cachedMetrics.month;
          _metricsFetchedAt = cachedMetrics.fetchedAt;
        }
        _metricsError = cachedMetrics.error;

        _isLoading = false;
      });

      final refreshFuture = _refreshMetricsInBackground(
        agentId: activeAgentId,
      );
      if (waitForMetricsRefresh) {
        await refreshFuture;
      } else {
        unawaited(refreshFuture);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _metricsError = _cleanErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshMetricsInBackground({
    required int? agentId,
  }) async {
    final freshMetrics = await _metricsCache.refreshAndSave(
      agentId: agentId,
    );
    if (!mounted) return;

    setState(() {
      if (freshMetrics.hasAnyData) {
        _resumeMetrics = freshMetrics.resume;
        _dayMetrics = freshMetrics.day;
        _weekMetrics = freshMetrics.week;
        _monthMetrics = freshMetrics.month;
        _metricsFetchedAt = freshMetrics.fetchedAt;
      }
      _metricsError = freshMetrics.error;
    });
  }

  Future<_LocalInventorySnapshot> _loadLocalInventorySnapshot() async {
    var epCount = 0;
    var assCount = 0;
    var synced = 0;
    var unsynced = 0;
    var pendingNewObjects = 0;
    var pendingUpdatedObjects = 0;
    var points = 0;
    var lignes = 0;
    var polygones = 0;

    for (final metier in SrmConfig.getMetiers()) {
      for (final entity in SrmConfig.getEntitiesForMetier(metier)) {
        final tableName = SrmConfig.getTableName(metier, entity);
        if (tableName == null || tableName.isEmpty) {
          continue;
        }

        try {
          final rows = await _db.getEntitiesSrm(tableName);
          final count = rows.length;

          if (metier == 'Eau Potable') epCount += count;
          if (metier == 'Assainissement') assCount += count;

          for (final row in rows) {
            final isSynced = _isLocalFlagEnabled(row['synced']);
            final isDownloaded = _isLocalFlagEnabled(row['downloaded']);
            if (isSynced) {
              synced++;
            } else {
              unsynced++;
              if (isDownloaded) {
                pendingUpdatedObjects++;
              } else {
                pendingNewObjects++;
              }
            }
          }

          final config = SrmConfig.getEntityConfig(metier, entity);
          final geometryType = config?['geometryType'] as String? ?? 'Point';
          if (geometryType == 'Point') points += count;
          if (geometryType == 'LineString') lignes += count;
          if (geometryType == 'Polygon') polygones += count;
        } catch (_) {
          // Table absente localement.
        }
      }
    }

    final pendingPhotos = await _db.getPendingPhotoSyncItems(limit: 10000);
    final failedPhotos = pendingPhotos.where((row) {
      final error = row['last_error']?.toString().trim() ?? '';
      return error.isNotEmpty;
    }).length;
    final pendingHistoryItems = await _db.countPendingLocalHistoryItems();

    return _LocalInventorySnapshot(
      totalEP: epCount,
      totalASS: assCount,
      totalSynced: synced,
      totalUnsynced: unsynced,
      pendingNewObjects: pendingNewObjects,
      pendingUpdatedObjects: pendingUpdatedObjects,
      pendingPhotos: pendingPhotos.length,
      failedPhotos: failedPhotos,
      pendingHistoryItems: pendingHistoryItems,
      totalPoints: points,
      totalLignes: lignes,
      totalPolygones: polygones,
    );
  }

  bool _isLocalFlagEnabled(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    final text = value.toString().trim().toLowerCase();
    return text == '1' || text == 'true' || text == 't' || text == 'yes';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F8FF),
      appBar: AppBar(
        title: const Text(
          'Profil & Dashboard',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFF1B4F72),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => _loadData(waitForMetricsRefresh: true),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadData(waitForMetricsRefresh: true),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildProfileCard(),
                  const SizedBox(height: 16),
                  if (_hasServerMetrics || _metricsError == null) ...[
                    _buildPublicOverviewSection(),
                    const SizedBox(height: 16),
                    _buildPublicQualitySection(),
                    const SizedBox(height: 16),
                    _buildPublicPeriodsSection(),
                    const SizedBox(height: 16),
                  ] else ...[
                    _buildMetricsUnavailableSection(),
                    const SizedBox(height: 16),
                  ],
                  _buildLocalMetierSection(),
                  const SizedBox(height: 16),
                  _buildLocalGeometrySection(),
                  const SizedBox(height: 16),
                  _buildLocalSyncSection(),
                  const SizedBox(height: 24),
                  _buildLogoutButton(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileCard() {
    final initials = _nomPrenom.isNotEmpty
        ? _nomPrenom
            .split(' ')
            .take(2)
            .map((word) => word.isNotEmpty ? word[0].toUpperCase() : '')
            .join()
        : '?';

    final roleColor = _role == 'admin'
        ? const Color(0xFF1B4F72)
        : _role == 'editeur_terrain'
            ? const Color(0xFF27AE60)
            : const Color(0xFF8E44AD);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF1B4F72),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1B4F72).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nomPrenom.isNotEmpty ? _nomPrenom : widget.agentName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B4F72),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _login.isNotEmpty ? '@$_login' : '@agent',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildBadge(
                      label: _role.isNotEmpty ? _role : 'agent',
                      color: roleColor,
                    ),
                    if (_activeAgentId != null)
                      _buildBadge(
                        label: 'Agent #$_activeAgentId',
                        color: const Color(0xFF1976D2),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _startConduiteDrawingMode('ep'),
                        icon: const Icon(Icons.water_drop_outlined),
                        label: const Text('Conduite EP'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1B4F72),
                          side: const BorderSide(color: Color(0xFF1B4F72)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _startConduiteDrawingMode('asst'),
                        icon: const Icon(Icons.plumbing_outlined),
                        label: const Text('Conduite ASS'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2E7D32),
                          side: const BorderSide(color: Color(0xFF2E7D32)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _startConduiteDrawingMode(String metier) {
    Navigator.of(context).pop(
      metier == 'asst'
          ? ProfilePage.startConduiteDrawingAsstResult
          : ProfilePage.startConduiteDrawingEpResult,
    );
  }

  Widget _buildPublicOverviewSection() {
    final serverTotal = _metricInt(_resumeMetrics, 'nb_objets_crees_total');
    final estimatedTotal = serverTotal + _localPendingNew;
    final recentWeek = _metricInt(_resumeMetrics, 'nb_objets_7j');
    final activeDays = _metricInt(_resumeMetrics, 'nb_jours_actifs');

    return _buildSection(
      title: 'Travail terrain',
      color: const Color(0xFF1B4F72),
      headerTrailing: const Icon(
        Icons.cloud_done_outlined,
        size: 18,
        color: Color(0xFF1B4F72),
      ),
      children: [
        if (_metricsError != null) ...[
          _buildNoticeCard(
            icon: Icons.info_outline,
            color: const Color(0xFFF39C12),
            text: _metricsError!,
          ),
          const SizedBox(height: 12),
        ],
        _buildStatsGrid(
          childAspectRatio: 1.45,
          children: [
            _buildStatCard(
              icon: Icons.layers_outlined,
              label: 'Total terrain',
              value: '$estimatedTotal',
              color: const Color(0xFF1B4F72),
              helper: _localPendingNew > 0
                  ? 'serveur + $_localPendingNew en attente'
                  : 'cumul serveur',
            ),
            _buildStatCard(
              icon: Icons.cloud_done_outlined,
              label: 'Reçu serveur',
              value: '$serverTotal',
              color: const Color(0xFF1976D2),
              helper: 'historique agent',
            ),
            _buildStatCard(
              icon: Icons.outbox_outlined,
              label: 'Attente locale',
              value: '$_localPendingNew',
              color: const Color(0xFF27AE60),
              helper: _localPendingUpdates > 0
                  ? '+ $_localPendingUpdates modification(s)'
                  : 'nouveaux objets',
            ),
            _buildStatCard(
              icon: Icons.insights_outlined,
              label: '7 derniers jours',
              value: '$recentWeek',
              color: const Color(0xFF8E44AD),
              helper: 'serveur cumulé',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildInfoRow(
          Icons.flag_outlined,
          'Première activité',
          _formatDateLabel(_resumeMetrics?['premiere_activite']),
        ),
        _buildInfoRow(
          Icons.update_outlined,
          'Dernière activité',
          _formatDateLabel(_resumeMetrics?['derniere_activite']),
        ),
        _buildInfoRow(
          Icons.event_available_outlined,
          'Jours actifs',
          '$activeDays',
        ),
        _buildInfoRow(
          Icons.sync_outlined,
          'Métriques mises à jour',
          _formatDateTimeLabel(_metricsFetchedAt),
        ),
        if (_buildOverviewBadges().isNotEmpty) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _buildOverviewBadges(),
          ),
        ],
      ],
    );
  }

  Widget _buildPublicQualitySection() {
    final total = _metricInt(_resumeMetrics, 'nb_objets_crees_total');
    final anomalies = _metricInt(_resumeMetrics, 'nb_objets_anomalie_total');
    final anomalyRate =
        _metricDouble(_resumeMetrics, 'taux_anomalie_global_pct');
    final objectsWithPhoto =
        _metricInt(_resumeMetrics, 'nb_objets_avec_photo_total');
    final photosUploaded =
        _metricInt(_resumeMetrics, 'nb_photos_uploadees_total');
    final photoCoverage = total > 0 ? (objectsWithPhoto * 100 / total) : 0.0;

    return _buildSection(
      title: 'Qualité et complétude',
      color: const Color(0xFF8E44AD),
      children: [
        _buildStatsGrid(
          childAspectRatio: 1.45,
          children: [
            _buildStatCard(
              icon: Icons.report_problem_outlined,
              label: 'Objets anomalie',
              value: '$anomalies',
              color: const Color(0xFFE74C3C),
              helper: _formatPercent(anomalyRate),
            ),
            _buildStatCard(
              icon: Icons.photo_library_outlined,
              label: 'Objets avec photo',
              value: '$objectsWithPhoto',
              color: const Color(0xFF1976D2),
              helper: _formatPercent(photoCoverage),
            ),
            _buildStatCard(
              icon: Icons.cloud_upload_outlined,
              label: 'Photos uploadées',
              value: '$photosUploaded',
              color: const Color(0xFF27AE60),
              helper:
                  '${_metricInt(_resumeMetrics, 'nb_photos_renseignees_total')} renseignées',
            ),
            _buildStatCard(
              icon: Icons.rule_folder_outlined,
              label: 'Incomplets en solde',
              value:
                  '${_metricInt(_resumeMetrics, 'nb_objets_incomplets_signales_total') - _metricInt(_resumeMetrics, 'nb_objets_incomplets_completes_total')}',
              color: const Color(0xFFF39C12),
              helper:
                  '${_metricInt(_resumeMetrics, 'nb_objets_incomplets_completes_total')} complétés',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPublicPeriodsSection() {
    return _buildSection(
      title: 'Périodes en cours',
      color: const Color(0xFF16A085),
      children: [
        _buildPeriodCard(
          title: 'Aujourd\'hui',
          subtitle: _formatDateLabel(
            _dayMetrics?['jour'] ?? DateTime.now().toIso8601String(),
          ),
          metrics: _dayMetrics,
          color: const Color(0xFF1976D2),
        ),
        const SizedBox(height: 12),
        _buildPeriodCard(
          title: 'Semaine',
          subtitle: _weekPeriodLabel(),
          metrics: _weekMetrics,
          color: const Color(0xFF27AE60),
        ),
        const SizedBox(height: 12),
        _buildPeriodCard(
          title: 'Mois',
          subtitle: _monthPeriodLabel(),
          metrics: _monthMetrics,
          color: const Color(0xFFF39C12),
        ),
      ],
    );
  }

  Widget _buildMetricsUnavailableSection() {
    return _buildSection(
      title: 'Métriques publiques',
      color: const Color(0xFFF39C12),
      children: [
        _buildNoticeCard(
          icon: Icons.cloud_off_outlined,
          color: const Color(0xFFF39C12),
          text: _metricsError ??
              'Les métriques serveur ne sont pas disponibles pour le moment.',
        ),
      ],
    );
  }

  Widget _buildLocalMetierSection() {
    final total = _totalEP + _totalASS;

    return _buildSection(
      title: 'Stock présent sur ce téléphone par métier',
      color: const Color(0xFF1B4F72),
      children: [
        _buildMetierBar(
          'Eau Potable',
          _totalEP,
          total,
          const Color(0xFF1976D2),
        ),
        const SizedBox(height: 8),
        _buildMetierBar(
          'Assainissement',
          _totalASS,
          total,
          const Color(0xFF27AE60),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1B4F72).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.smartphone_outlined,
                size: 20,
                color: Color(0xFF1B4F72),
              ),
              const SizedBox(width: 8),
              Text(
                'Présents sur ce téléphone : $total objet${total > 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B4F72),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocalGeometrySection() {
    return _buildSection(
      title: 'Stock présent sur ce téléphone par géométrie',
      color: const Color(0xFF8E44AD),
      children: [
        Row(
          children: [
            Expanded(
              child: _buildGeoCard(
                Icons.place_outlined,
                'Points',
                _totalPoints,
                const Color(0xFF1976D2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildGeoCard(
                Icons.show_chart,
                'Lignes',
                _totalLignes,
                const Color(0xFF27AE60),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildGeoCard(
                Icons.pentagon_outlined,
                'Polygones',
                _totalPolygones,
                const Color(0xFFF39C12),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocalSyncSection() {
    final total = _totalSynced + _totalUnsynced;
    final pct = total > 0 ? _totalSynced / total : 0.0;
    final pendingTransport =
        _localPendingNew + _localPendingUpdates + _localPendingPhotos;

    return _buildSection(
      title: 'File d’attente locale',
      color: const Color(0xFF2196F3),
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSyncCard(
                'Nouveaux objets',
                _localPendingNew,
                const Color(0xFFF39C12),
                Icons.add_location_alt_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSyncCard(
                'Objets modifiés',
                _localPendingUpdates,
                const Color(0xFF8E44AD),
                Icons.edit_location_alt_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildSyncCard(
                'Photos à envoyer',
                _localPendingPhotos,
                const Color(0xFF1976D2),
                Icons.photo_library_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSyncCard(
                'Erreurs photo',
                _localFailedPhotos,
                const Color(0xFFE74C3C),
                Icons.error_outline,
              ),
            ),
          ],
        ),
        if (_localPendingHistory > 0) ...[
          const SizedBox(height: 12),
          _buildNoticeCard(
            icon: Icons.history_outlined,
            color: const Color(0xFF8E44AD),
            text:
                'Historique local en attente : $_localPendingHistory événement(s).',
          ),
        ],
        if (pendingTransport == 0 && _localPendingHistory == 0) ...[
          const SizedBox(height: 12),
          _buildNoticeCard(
            icon: Icons.verified_outlined,
            color: const Color(0xFF27AE60),
            text: 'Aucune donnée locale en attente sur ce téléphone.',
          ),
        ],
        const SizedBox(height: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Objets locaux déjà reçus serveur',
                  style: TextStyle(fontSize: 13),
                ),
                Text(
                  '${(pct * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: const Color(
                  0xFF27AE60,
                ).withValues(alpha: 0.15),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF27AE60),
                ),
                minHeight: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Déconnexion'),
              content: const Text('Voulez-vous vous déconnecter ?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                    widget.onLogout();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  child: const Text(
                    'Déconnecter',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          );
        },
        icon: const Icon(Icons.logout, color: Colors.white),
        label: const Text(
          'Se déconnecter',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade700,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required Color color,
    required List<Widget> children,
    Widget? headerTrailing,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              border: Border(
                bottom: BorderSide(color: color.withValues(alpha: 0.2)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
                if (headerTrailing != null) headerTrailing,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid({
    required List<Widget> children,
    double childAspectRatio = 1.5,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final resolvedAspectRatio = availableWidth < 360
            ? 1.08
            : availableWidth < 430
                ? 1.18
                : childAspectRatio;

        return GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: resolvedAspectRatio,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: children,
        );
      },
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    String? helper,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 4),
          if (helper != null && helper.isNotEmpty)
            Text(
              helper,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF666666),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPeriodCard({
    required String title,
    required String subtitle,
    required Map<String, dynamic>? metrics,
    required Color color,
  }) {
    final total = _metricInt(metrics, 'nb_objets_crees');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(
                      '$total',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const Text(
                      'objets',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildMiniMetric('Points', _metricInt(metrics, 'nb_points')),
              _buildMiniMetric('Lignes', _metricInt(metrics, 'nb_lignes')),
              _buildMiniMetric('Surfaces', _metricInt(metrics, 'nb_surfaces')),
              _buildMiniMetric(
                'Anomalies',
                _metricInt(metrics, 'nb_objets_anomalie'),
              ),
              _buildMiniMetric(
                'Photos',
                _metricInt(metrics, 'nb_photos_uploadees'),
              ),
              _buildMiniMetric(
                'Syncs',
                _metricInt(metrics, 'nb_evenements_sync'),
              ),
            ],
          ),
          if (total == 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Aucune activité tracée sur cette période pour le moment.',
                style: TextStyle(
                  fontSize: 12,
                  color: color.withValues(alpha: 0.85),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String label, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label : $value',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF333333),
        ),
      ),
    );
  }

  Widget _buildNoticeCard({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF333333),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge({
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  List<Widget> _buildOverviewBadges() {
    final badges = <Widget>[];

    final modifications =
        _metricInt(_resumeMetrics, 'nb_modifications_terrain_total');
    final syncs = _metricInt(_resumeMetrics, 'nb_evenements_sync_total');
    final last30Days = _metricInt(_resumeMetrics, 'nb_objets_30j');

    if (modifications > 0) {
      badges.add(
        _buildBadge(
          label: 'Modifs terrain : $modifications',
          color: const Color(0xFF8E44AD),
        ),
      );
    }
    if (syncs > 0) {
      badges.add(
        _buildBadge(
          label: 'Syncs : $syncs',
          color: const Color(0xFF27AE60),
        ),
      );
    }
    if (last30Days > 0) {
      badges.add(
        _buildBadge(
          label: '30 jours : $last30Days',
          color: const Color(0xFFF39C12),
        ),
      );
    }

    return badges;
  }

  Widget _buildMetierBar(String label, int count, int total, Color color) {
    final pct = total > 0 ? count / total : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildGeoCard(IconData icon, String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 4),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF666666),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncCard(
    String label,
    int count,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF666666),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF1976D2)),
          const SizedBox(width: 10),
          Text(
            '$label : ',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF666666),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : '—',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  int _metricInt(Map<String, dynamic>? row, String key) {
    return _asIntOrNull(row?[key]) ?? 0;
  }

  double _metricDouble(Map<String, dynamic>? row, String key) {
    return _asDoubleOrNull(row?[key]) ?? 0.0;
  }

  int? _asIntOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value.toString());
  }

  double? _asDoubleOrNull(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }

  String _coalesceText(dynamic first, [dynamic second, dynamic third]) {
    for (final candidate in [first, second, third]) {
      final text = candidate?.toString().trim() ?? '';
      if (text.isNotEmpty) {
        return text;
      }
    }
    return '';
  }

  String _cleanErrorMessage(Object error) {
    return error.toString().replaceFirst('Exception: ', '').trim();
  }

  String _formatPercent(double value) {
    final safeValue = value.isFinite ? value : 0.0;
    final digits = safeValue >= 10 ? 0 : 1;
    return '${safeValue.toStringAsFixed(digits)}%';
  }

  String _formatDateLabel(dynamic rawValue) {
    final text = rawValue?.toString().trim() ?? '';
    if (text.isEmpty) return '—';

    final parsed = DateTime.tryParse(text);
    if (parsed == null) return text;

    const months = <String>[
      'janv.',
      'févr.',
      'mars',
      'avr.',
      'mai',
      'juin',
      'juil.',
      'août',
      'sept.',
      'oct.',
      'nov.',
      'déc.',
    ];

    return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
  }

  String _formatDateTimeLabel(DateTime? value) {
    if (value == null) return '—';
    final local = value.toLocal();
    final date = _formatDateLabel(local.toIso8601String());
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$date à $hour:$minute';
  }

  String _weekPeriodLabel() {
    if (_weekMetrics != null) {
      final start = _formatShortDate(_weekMetrics?['semaine_debut']);
      final end = _formatShortDate(_weekMetrics?['semaine_fin']);
      if (start != '—' && end != '—') {
        return '$start - $end';
      }
    }

    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    return '${_formatShortDate(monday.toIso8601String())} - ${_formatShortDate(sunday.toIso8601String())}';
  }

  String _monthPeriodLabel() {
    if (_monthMetrics != null) {
      return _formatMonthYear(_monthMetrics?['mois']);
    }
    return _formatMonthYear(DateTime.now().toIso8601String());
  }

  String _formatShortDate(dynamic rawValue) {
    final text = rawValue?.toString().trim() ?? '';
    if (text.isEmpty) return '—';

    final parsed = DateTime.tryParse(text);
    if (parsed == null) return text;
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    return '$day/$month';
  }

  String _formatMonthYear(dynamic rawValue) {
    final text = rawValue?.toString().trim() ?? '';
    if (text.isEmpty) return '—';

    final parsed = DateTime.tryParse(text);
    if (parsed == null) return text;

    const months = <String>[
      'janvier',
      'février',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'août',
      'septembre',
      'octobre',
      'novembre',
      'décembre',
    ];

    return '${months[parsed.month - 1]} ${parsed.year}';
  }
}

class _LocalInventorySnapshot {
  final int totalEP;
  final int totalASS;
  final int totalSynced;
  final int totalUnsynced;
  final int pendingNewObjects;
  final int pendingUpdatedObjects;
  final int pendingPhotos;
  final int failedPhotos;
  final int pendingHistoryItems;
  final int totalPoints;
  final int totalLignes;
  final int totalPolygones;

  const _LocalInventorySnapshot({
    required this.totalEP,
    required this.totalASS,
    required this.totalSynced,
    required this.totalUnsynced,
    required this.pendingNewObjects,
    required this.pendingUpdatedObjects,
    required this.pendingPhotos,
    required this.failedPhotos,
    required this.pendingHistoryItems,
    required this.totalPoints,
    required this.totalLignes,
    required this.totalPolygones,
  });
}
