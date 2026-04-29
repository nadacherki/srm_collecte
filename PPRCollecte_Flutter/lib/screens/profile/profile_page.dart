import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/config/srm_config.dart';
import '../../core/constants/basemap_constants.dart';
import '../../data/local/database_helper.dart';
import '../../data/remote/api_service.dart';
import '../../services/basemap_catalog_service.dart';
import '../../services/offline_basemap_service.dart';
import '../../services/public_metrics_cache_service.dart';

class ProfilePage extends StatefulWidget {
  static const String startConduiteDrawingResult = 'start_conduite_drawing';

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

  String _projetNom = '';
  String _projetCode = '';
  String _projetRegion = '';

  int? _activeAgentId;
  int? _activeProjetId;

  int _totalEP = 0;
  int _totalASS = 0;
  int _totalELEC = 0;
  int _totalSynced = 0;
  int _totalUnsynced = 0;
  int _totalPoints = 0;
  int _totalLignes = 0;
  int _totalPolygones = 0;
  bool _hasOfflineBasemap = false;
  String _offlineBasemapStatus = '';
  String _offlineBasemapLocalPath = '';
  String _offlineBasemapDownloadedAt = '';
  String _offlineBasemapServerUpdatedAt = '';
  String _activeBasemapPackageKey = '';
  String _activeBasemapZoneId = '';
  String _activeBasemapStyle = '';
  String _activeBasemapFormat = '';
  List<Map<String, dynamic>> _basemapZones = const [];
  List<Map<String, dynamic>> _basemapPackages = const [];
  String? _basemapCatalogError;
  final Set<String> _downloadingBasemapPackageKeys = <String>{};
  final Set<String> _activatingBasemapPackageKeys = <String>{};
  bool _isPreparingBasemapPackages = false;
  Set<String> _assignedBasemapZoneIds = <String>{};

  Map<String, dynamic>? _resumeMetrics;
  Map<String, dynamic>? _dayMetrics;
  Map<String, dynamic>? _weekMetrics;
  Map<String, dynamic>? _monthMetrics;
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
      final currentProjetId =
          ApiService.currentProjetId ?? _asIntOrNull(currentUser?['id_projet_actif']);
      final currentProjet = currentProjetId != null
          ? await _db.getProjetLocal(currentProjetId)
          : null;
      final results = await Future.wait<dynamic>([
        _refreshBasemapCatalogIfPossible(),
        _loadLocalInventorySnapshot(),
        _loadOfflineBasemapSnapshot(),
        _loadOfflineBasemapCatalogSnapshot(),
        _metricsCache.loadSnapshot(
          agentId: activeAgentId,
          projetId: currentProjetId,
        ),
      ]);
      final basemapCatalogError = results[0] as String?;
      final inventory = results[1] as _LocalInventorySnapshot;
      final basemap = results[2] as _OfflineBasemapSnapshot;
      final basemapCatalog = results[3] as _OfflineBasemapCatalogSnapshot;
      final cachedMetrics = results[4] as PublicMetricsCacheSnapshot;
      final assignedZoneIds = basemapCatalog.zones
          .map((zone) => zone['zone_id']?.toString().trim() ?? '')
          .where((zoneId) => zoneId.isNotEmpty)
          .toSet();

      if (!mounted) return;

      setState(() {
        _nomPrenom = _coalesceText(
          ApiService.nomPrenom,
          currentUser?['nom_prenom'],
          widget.agentName,
        );
        _login = _coalesceText(ApiService.userLogin, currentUser?['login']);
        _role = _coalesceText(ApiService.userRole, currentUser?['role']);

        _projetNom = _coalesceText(
          ApiService.currentProjetNom,
          currentProjet?['nom'],
        );
        _projetCode = _coalesceText(
          ApiService.currentProjetCode,
          currentProjet?['code_affaire'],
        );
        _projetRegion = _coalesceText(
          ApiService.currentProjetRegion,
          currentProjet?['region'],
        );

        _activeAgentId = activeAgentId;
        _activeProjetId = currentProjetId;

        _totalEP = inventory.totalEP;
        _totalASS = inventory.totalASS;
        _totalELEC = inventory.totalELEC;
        _totalSynced = inventory.totalSynced;
        _totalUnsynced = inventory.totalUnsynced;
        _totalPoints = inventory.totalPoints;
        _totalLignes = inventory.totalLignes;
        _totalPolygones = inventory.totalPolygones;
        _hasOfflineBasemap = basemap.isReady;
        _offlineBasemapStatus = basemap.statusLabel;
        _offlineBasemapLocalPath = basemap.localPath;
        _offlineBasemapDownloadedAt = basemap.downloadedAt;
        _offlineBasemapServerUpdatedAt = basemap.serverUpdatedAt;
        _activeBasemapPackageKey = basemap.packageKey;
        _activeBasemapZoneId = basemap.zoneId;
        _activeBasemapStyle = basemap.style;
        _activeBasemapFormat = basemap.format;
        _basemapZones = basemapCatalog.zones;
        _basemapPackages = basemapCatalog.packages;
        _basemapCatalogError = basemapCatalogError;
        _assignedBasemapZoneIds = assignedZoneIds;

        if (cachedMetrics.hasAnyData) {
          _resumeMetrics = cachedMetrics.resume;
          _dayMetrics = cachedMetrics.day;
          _weekMetrics = cachedMetrics.week;
          _monthMetrics = cachedMetrics.month;
        }
        _metricsError = cachedMetrics.error;

        _isLoading = false;
      });

      final refreshFuture = _refreshMetricsInBackground(
        agentId: activeAgentId,
        projetId: currentProjetId,
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
    required int? projetId,
  }) async {
    final freshMetrics = await _metricsCache.refreshAndSave(
      agentId: agentId,
      projetId: projetId,
    );
    if (!mounted) return;

    setState(() {
      if (freshMetrics.hasAnyData) {
        _resumeMetrics = freshMetrics.resume;
        _dayMetrics = freshMetrics.day;
        _weekMetrics = freshMetrics.week;
        _monthMetrics = freshMetrics.month;
      }
      _metricsError = freshMetrics.error;
    });
  }

  Future<_OfflineBasemapSnapshot> _loadOfflineBasemapSnapshot() async {
    final activePackage = await OfflineBasemapService().getActivePackage();
    final readyPackages = await OfflineBasemapService().getReadyPackages(
      citySlug: BasemapConstants.catalogCitySlug,
    );
    final localPath =
        activePackage?['local_path']?.toString().trim() ??
        await OfflineBasemapService().getActiveBasemapPath() ??
        '';
    final packageKey =
        activePackage?['package_key']?.toString().trim() ?? '';
    final zoneId = activePackage?['zone_id']?.toString().trim() ?? '';
    final style = activePackage?['style']?.toString().trim() ?? '';
    final format = activePackage?['format']?.toString().trim() ?? '';
    final downloadedAt =
        activePackage?['downloaded_at']?.toString().trim() ?? '';
    final serverUpdatedAt =
        activePackage?['generated_at']?.toString().trim() ?? '';

    final isReady = localPath.isNotEmpty;
    final statusLabel = isReady
        ? (packageKey.isNotEmpty ? 'Package actif' : 'Téléchargée')
        : (readyPackages.isNotEmpty
              ? 'Aucun package actif'
              : 'Aucun package téléchargé');

    return _OfflineBasemapSnapshot(
      isReady: isReady,
      statusLabel: statusLabel,
      localPath: localPath,
      downloadedAt: downloadedAt,
      serverUpdatedAt: serverUpdatedAt,
      packageKey: packageKey,
      zoneId: zoneId,
      style: style,
      format: format,
    );
  }

  Future<String?> _refreshBasemapCatalogIfPossible() async {
    final isReachable = await _isApiReachableQuickly();
    if (!isReachable) {
      return null;
    }

    try {
      await BasemapCatalogService(databaseHelper: _db).refreshCatalog(
        citySlug: BasemapConstants.catalogCitySlug,
      );
      return null;
    } catch (e) {
      return _cleanErrorMessage(e);
    }
  }

  Future<bool> _isApiReachableQuickly() async {
    try {
      final uri = Uri.parse(ApiService.baseUrl);
      final host = uri.host;
      final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(milliseconds: 800),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<_OfflineBasemapCatalogSnapshot> _loadOfflineBasemapCatalogSnapshot() async {
    final zones = await _db.getOfflineBasemapZones(
      citySlug: BasemapConstants.catalogCitySlug,
    );
    final packages = await _db.getOfflineBasemapPackages(
      citySlug: BasemapConstants.catalogCitySlug,
    );

    return _OfflineBasemapCatalogSnapshot(
      zones: zones,
      packages: packages,
    );
  }

  Future<_LocalInventorySnapshot> _loadLocalInventorySnapshot() async {
    var epCount = 0;
    var assCount = 0;
    var elecCount = 0;
    var synced = 0;
    var unsynced = 0;
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
          if (metier == 'Électricité') elecCount += count;

          for (final row in rows) {
            final isSynced = row['synced']?.toString() == '1';
            if (isSynced) {
              synced++;
            } else {
              unsynced++;
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

    return _LocalInventorySnapshot(
      totalEP: epCount,
      totalASS: assCount,
      totalELEC: elecCount,
      totalSynced: synced,
      totalUnsynced: unsynced,
      totalPoints: points,
      totalLignes: lignes,
      totalPolygones: polygones,
    );
  }

  // ignore: unused_element
  Future<_MetricsSnapshot> _loadMetricsSnapshot({
    required int? agentId,
    required int? projetId,
  }) async {
    if (agentId == null || projetId == null) {
      return const _MetricsSnapshot(
        error: 'Agent ou projet actif introuvable pour les métriques serveur.',
      );
    }

    final now = DateTime.now();
    final isoWeek = _computeIsoWeek(now);

    try {
      final responses = await Future.wait<Map<String, dynamic>?>([
        ApiService.fetchAgentPublicResume(
          idAgent: agentId,
          idProjet: projetId,
        ),
        ApiService.fetchAgentPublicJour(
          idAgent: agentId,
          idProjet: projetId,
          jour: now,
        ),
        ApiService.fetchAgentPublicSemaine(
          idAgent: agentId,
          idProjet: projetId,
          anneeIso: isoWeek.year,
          semaineIso: isoWeek.week,
        ),
        ApiService.fetchAgentPublicMois(
          idAgent: agentId,
          idProjet: projetId,
          annee: now.year,
          moisNumero: now.month,
        ),
      ]);

      return _MetricsSnapshot(
        resume: responses[0],
        day: responses[1],
        week: responses[2],
        month: responses[3],
      );
    } catch (e) {
      return _MetricsSnapshot(error: _cleanErrorMessage(e));
    }
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
                  _buildProjetCard(),
                  const SizedBox(height: 16),
                  _buildOfflineBasemapSection(),
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
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _startConduiteDrawingMode,
                    icon: const Icon(Icons.alt_route),
                    label: const Text('Dessiner une conduite'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1B4F72),
                      side: const BorderSide(color: Color(0xFF1B4F72)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjetCard() {
    return _buildSection(
      title: 'Projet',
      color: const Color(0xFF1976D2),
      children: [
        _buildInfoRow(Icons.work_outline, 'Projet', _projetNom),
        _buildInfoRow(Icons.tag, 'Code affaire', _projetCode),
        _buildInfoRow(Icons.map_outlined, 'Région', _projetRegion),
        _buildInfoRow(
          Icons.folder_shared_outlined,
          'Projet actif',
          _activeProjetId != null ? '#$_activeProjetId' : '—',
        ),
      ],
    );
  }

  Widget _buildOfflineBasemapSection() {
    final statusColor = _hasOfflineBasemap
        ? const Color(0xFF27AE60)
        : const Color(0xFFF39C12);
    final activeFileName = _offlineBasemapLocalPath.isNotEmpty
        ? _offlineBasemapLocalPath.split(Platform.pathSeparator).last
        : 'Aucun package actif';
    final downloadedPackages = _basemapPackages
        .where(
          (row) => (row['status']?.toString().trim().toLowerCase() ?? '') == 'ready',
        )
        .length;
    final basemapNotice = _hasOfflineBasemap
        ? "Un package de carte offline est actif sur ce mobile."
        : _basemapPackages.isNotEmpty
            ? "Le catalogue de zones est disponible, mais aucun package n'est encore actif sur ce mobile."
            : "Aucune zone de carte offline n'est encore disponible dans le catalogue local.";

    return _buildSection(
      title: 'Cartes hors ligne',
      color: const Color(0xFF16A085),
      children: [
        _buildNoticeCard(
          icon: _hasOfflineBasemap
              ? Icons.map_outlined
              : Icons.cloud_download_outlined,
          color: statusColor,
          text: basemapNotice,
        ),
        const SizedBox(height: 12),
          _buildInfoRow(
            Icons.location_city_outlined,
            'Ville',
            BasemapConstants.catalogCityLabel,
          ),
        _buildInfoRow(
          Icons.check_circle_outline,
          'Statut',
          _offlineBasemapStatus,
        ),
        _buildInfoRow(
          Icons.map_outlined,
          'Zone active',
          _activeBasemapZoneId.isNotEmpty ? _activeBasemapZoneId : 'Aucune',
        ),
        _buildInfoRow(
          Icons.layers_outlined,
          'Style actif',
          _activeBasemapStyle.isNotEmpty
              ? _activeBasemapStyle.toUpperCase()
              : 'Aucun',
        ),
        _buildInfoRow(
          Icons.dataset_outlined,
          'Format actif',
          _activeBasemapFormat.isNotEmpty
              ? _activeBasemapFormat.toUpperCase()
              : 'Inconnu',
        ),
        _buildInfoRow(
          Icons.inventory_2_outlined,
          'Package actif',
          activeFileName,
        ),
        _buildInfoRow(
          Icons.schedule_outlined,
          'Téléchargée le',
          _formatDateLabel(_offlineBasemapDownloadedAt),
        ),
        _buildInfoRow(
          Icons.update_outlined,
          'Version serveur',
          _formatDateLabel(_offlineBasemapServerUpdatedAt),
        ),
        _buildInfoRow(
          Icons.grid_view_outlined,
          'Communes couvertes',
          '${_basemapZones.length}',
        ),
        _buildInfoRow(
          Icons.person_pin_circle_outlined,
          'Communes catalogue',
          '${_assignedBasemapZoneIds.length}',
        ),
        _buildInfoRow(
          Icons.layers_outlined,
          'Packages catalogue',
          '${_basemapPackages.length}',
        ),
        _buildInfoRow(
          Icons.download_done_outlined,
          'Packages téléchargés',
          '$downloadedPackages',
        ),
        if (_offlineBasemapLocalPath.isNotEmpty)
          _buildInfoRow(
            Icons.folder_open_outlined,
            'Chemin local',
            _offlineBasemapLocalPath,
          ),
        if (_basemapCatalogError != null) ...[
          const SizedBox(height: 8),
          _buildNoticeCard(
            icon: Icons.info_outline,
            color: const Color(0xFFF39C12),
            text: 'Catalogue des zones : $_basemapCatalogError',
          ),
        ],
        if (_basemapZones.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _downloadingBasemapPackageKeys.isNotEmpty ||
                      _isPreparingBasemapPackages
                  ? null
                  : _downloadAssignedBasemapPackages,
              icon: _downloadingBasemapPackageKeys.isNotEmpty ||
                      _isPreparingBasemapPackages
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.cloud_download_outlined),
              label: Text(
                _isPreparingBasemapPackages
                    ? 'Vérification des cartes en cours...'
                    : _downloadingBasemapPackageKeys.isNotEmpty
                    ? 'Téléchargement des cartes en cours...'
                    : 'Télécharger toutes les cartes communales',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
        if (_basemapZones.isNotEmpty) ...[
          const SizedBox(height: 12),
          ..._basemapZones.map(_buildBasemapZoneCard),
        ],
      ],
    );
  }

  Widget _buildBasemapZoneCard(Map<String, dynamic> zone) {
    final zoneId = zone['zone_id']?.toString() ?? '';
    final zoneName = _coalesceText(zone['nom'], zoneId);
    final minZoom = _asIntOrNull(zone['min_zoom']);
    final maxZoom = _asIntOrNull(zone['max_zoom']);
    final zonePackages = _basemapPackages
        .where((row) => row['zone_id']?.toString() == zoneId)
        .toList();
    final selectedPackage = _selectAutomaticPackageForZone(zonePackages);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF16A085).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF16A085).withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.map_outlined,
                size: 18,
                color: Color(0xFF16A085),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  zoneName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF154360),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            zoneId,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF666666),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildBadge(
                label: 'Zoom ${minZoom ?? '?'}-${maxZoom ?? '?'}',
                color: const Color(0xFF1976D2),
              ),
              _buildBadge(
                label:
                    '${zonePackages.length} package${zonePackages.length > 1 ? 's' : ''}',
                color: const Color(0xFF16A085),
              ),
              if (_activeBasemapZoneId == zoneId)
                _buildBadge(
                  label: 'Zone active',
                  color: const Color(0xFF27AE60),
                ),
              _buildBadge(
                label: 'Zone communale',
                color: const Color(0xFF8E44AD),
              ),
            ],
          ),
          if (zonePackages.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildBasemapPackageDownloadRow(selectedPackage!),
          ],
        ],
      ),
    );
  }

  void _startConduiteDrawingMode() {
    Navigator.of(context).pop(ProfilePage.startConduiteDrawingResult);
  }

  Widget _buildBasemapPackageDownloadRow(Map<String, dynamic> packageRow) {
    final packageKey = packageRow['package_key']?.toString().trim() ??
        '${packageRow['zone_id']}:${packageRow['style']}:${packageRow['version']}';
    final style = packageRow['style']?.toString() ?? 'standard';
    final format = packageRow['format']?.toString().toUpperCase() ?? 'MBTILES';
    final version = packageRow['version']?.toString() ?? 'v?';
    final statusRaw = packageRow['status'];
    final statusLabel = _basemapPackageStatusLabel(statusRaw);
    final statusColor = _basemapPackageStatusColor(statusRaw);
    final sizeLabel = _formatFileSize(_asIntOrNull(packageRow['size_bytes']));
    final isDownloading = _downloadingBasemapPackageKeys.contains(packageKey);
    final isActivating = _activatingBasemapPackageKeys.contains(packageKey);
    final isActivePackage = _activeBasemapPackageKey == packageKey;
    final isReady =
        (statusRaw ?? '').toString().trim().toLowerCase() == 'ready';
    final canActivate = !isActivating && isReady && !isActivePackage;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.inventory_2_outlined, size: 16, color: statusColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${style.toUpperCase()} | $format | $version'
              '${sizeLabel.isNotEmpty ? ' | $sizeLabel' : ''}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF444444),
              ),
            ),
          ),
          if (isActivePackage) ...[
            const SizedBox(width: 8),
            _buildBadge(
              label: 'Actif',
              color: const Color(0xFF27AE60),
            ),
          ],
          if (canActivate) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: () => _activateBasemapPackage(packageRow),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF27AE60).withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  size: 18,
                  color: Color(0xFF27AE60),
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
          Text(
            isDownloading
                ? 'Téléchargement...'
                : (isActivating ? 'Activation...' : statusLabel),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadAssignedBasemapPackages() async {
    if (_downloadingBasemapPackageKeys.isNotEmpty || _isPreparingBasemapPackages) {
      return;
    }

    try {
      setState(() {
        _isPreparingBasemapPackages = true;
      });

      final summary =
          await BasemapCatalogService(databaseHelper: _db).ensureGlobalCoverageDownloaded(
        citySlug: BasemapConstants.catalogCitySlug,
      );

      if (!mounted) return;
      await _loadData();
      if (!mounted) return;

      final parts = <String>[];
      final selectedCount = _asIntOrNull(summary['mobile_selected_count']) ?? 0;
      final downloadedCount =
          _asIntOrNull(summary['mobile_downloaded_count']) ?? 0;
      final alreadyAvailableCount =
          _asIntOrNull(summary['mobile_already_available_count']) ?? 0;
      final failedCount = _asIntOrNull(summary['mobile_failed_count']) ?? 0;
      final generatedCount = _asIntOrNull(summary['generated_count']) ?? 0;
      final reusedCount = _asIntOrNull(summary['reused_count']) ?? 0;

      if (generatedCount > 0) {
        parts.add('$generatedCount préparée(s)');
      } else if (reusedCount > 0) {
        parts.add('$reusedCount déjà disponible(s) serveur');
      }
      if (downloadedCount > 0) {
        parts.add('$downloadedCount téléchargée(s)');
      }
      if (alreadyAvailableCount > 0) {
        parts.add('$alreadyAvailableCount déjà présente(s)');
      }
      if (failedCount > 0) {
        parts.add('$failedCount en échec');
      }

      final backendMessage = (summary['message'] ?? '').toString().trim();
      final message = selectedCount == 0
          ? (backendMessage.isNotEmpty
              ? backendMessage
              : 'Aucune carte communale disponible.')
          : (parts.isEmpty
              ? 'Toutes les cartes communales sont déjà présentes.'
              : 'Cartes communales : ${parts.join(', ')}.');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_cleanErrorMessage(e))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPreparingBasemapPackages = false;
        });
      }
    }
  }

  Future<void> _activateBasemapPackage(Map<String, dynamic> packageRow) async {
    final packageKey = packageRow['package_key']?.toString().trim() ??
        '${packageRow['zone_id']}:${packageRow['style']}:${packageRow['version']}';

    if (_activatingBasemapPackageKeys.contains(packageKey)) {
      return;
    }

    setState(() {
      _activatingBasemapPackageKeys.add(packageKey);
    });

    try {
      await OfflineBasemapService().setActivePackage(packageKey);
      if (!mounted) return;

      await _loadData();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le package de zone est maintenant actif sur ce mobile.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_cleanErrorMessage(e))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _activatingBasemapPackageKeys.remove(packageKey);
        });
      }
    }
  }

  Map<String, dynamic>? _selectAutomaticPackageForZone(
    List<Map<String, dynamic>> zonePackages,
  ) {
    if (zonePackages.isEmpty) return null;
    final sorted = List<Map<String, dynamic>>.from(zonePackages)
      ..sort(_compareAutomaticPackagePriority);
    return sorted.first;
  }

  int _compareAutomaticPackagePriority(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final styleRankCompare =
        _automaticStyleRank(a).compareTo(_automaticStyleRank(b));
    if (styleRankCompare != 0) return styleRankCompare;

    final formatRankCompare =
        _automaticFormatRank(a).compareTo(_automaticFormatRank(b));
    if (formatRankCompare != 0) return formatRankCompare;

    final generatedAtA =
        DateTime.tryParse(a['generated_at']?.toString().trim() ?? '');
    final generatedAtB =
        DateTime.tryParse(b['generated_at']?.toString().trim() ?? '');
    if (generatedAtA != null && generatedAtB != null) {
      final generatedCompare = generatedAtB.compareTo(generatedAtA);
      if (generatedCompare != 0) return generatedCompare;
    } else if (generatedAtA != null) {
      return -1;
    } else if (generatedAtB != null) {
      return 1;
    }

    final versionA = a['version']?.toString().trim() ?? '';
    final versionB = b['version']?.toString().trim() ?? '';
    return versionB.compareTo(versionA);
  }

  int _automaticStyleRank(Map<String, dynamic> packageRow) {
    final style = packageRow['style']?.toString().trim().toLowerCase() ?? '';
    if (style == 'standard') return 0;
    return 1;
  }

  int _automaticFormatRank(Map<String, dynamic> packageRow) {
    final format = packageRow['format']?.toString().trim().toLowerCase() ?? '';
    if (format == 'pmtiles') return 0;
    if (format == 'mbtiles') return 1;
    return 2;
  }

  Widget _buildPublicOverviewSection() {
    final total = _metricInt(_resumeMetrics, 'nb_objets_crees_total');
    final currentWeek = _metricInt(_resumeMetrics, 'nb_objets_semaine_courante');
    final recentWeek = _metricInt(_resumeMetrics, 'nb_objets_7j');
    final activeDays = _metricInt(_resumeMetrics, 'nb_jours_actifs');

    return _buildSection(
      title: 'Performance terrain',
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
              label: 'Total collecté',
              value: '$total',
              color: const Color(0xFF1B4F72),
              helper: 'objets tracés',
            ),
            _buildStatCard(
              icon: Icons.insights_outlined,
              label: '7 derniers jours',
              value: '$recentWeek',
              color: const Color(0xFF1976D2),
              helper: 'rythme récent',
            ),
            _buildStatCard(
              icon: Icons.calendar_view_week_outlined,
              label: 'Semaine courante',
              value: '$currentWeek',
              color: const Color(0xFF27AE60),
              helper: 'depuis lundi',
            ),
            _buildStatCard(
              icon: Icons.event_available_outlined,
              label: 'Jours actifs',
              value: '$activeDays',
              color: const Color(0xFF8E44AD),
              helper: 'avec activité',
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
    final total = _totalEP + _totalASS + _totalELEC;

    return _buildSection(
      title: 'Stock local par métier',
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
        const SizedBox(height: 8),
        _buildMetierBar(
          'Électricité',
          _totalELEC,
          total,
          const Color(0xFFF39C12),
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
                'Total local : $total objet${total > 1 ? 's' : ''}',
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
      title: 'Stock local par géométrie',
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

    return _buildSection(
      title: 'État de synchronisation locale',
      color: const Color(0xFF2196F3),
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSyncCard(
                'En attente',
                _totalUnsynced,
                const Color(0xFFF39C12),
                Icons.schedule,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSyncCard(
                'Synchronisés',
                _totalSynced,
                const Color(0xFF27AE60),
                Icons.cloud_done_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Progression sync locale',
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

    final missions = _metricInt(_resumeMetrics, 'nb_missions_total');
    final modifications =
        _metricInt(_resumeMetrics, 'nb_modifications_terrain_total');
    final syncs = _metricInt(_resumeMetrics, 'nb_evenements_sync_total');
    final last30Days = _metricInt(_resumeMetrics, 'nb_objets_30j');

    if (missions > 0) {
      badges.add(
        _buildBadge(
          label: 'Missions : $missions',
          color: const Color(0xFF1976D2),
        ),
      );
    }
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

  String _basemapPackageStatusLabel(dynamic rawStatus) {
    switch ((rawStatus ?? '').toString().trim().toLowerCase()) {
      case 'ready':
        return 'Téléchargé';
      case 'downloading':
        return 'Téléchargement';
      case 'update_available':
        return 'Mise à jour dispo';
      case 'failed':
        return 'Échec';
      case 'not_downloaded':
      default:
        return 'Non téléchargé';
    }
  }

  Color _basemapPackageStatusColor(dynamic rawStatus) {
    switch ((rawStatus ?? '').toString().trim().toLowerCase()) {
      case 'ready':
        return const Color(0xFF27AE60);
      case 'downloading':
        return const Color(0xFF1976D2);
      case 'update_available':
        return const Color(0xFFF39C12);
      case 'failed':
        return const Color(0xFFE74C3C);
      case 'not_downloaded':
      default:
        return const Color(0xFF7F8C8D);
    }
  }

  String _formatFileSize(int? sizeBytes) {
    if (sizeBytes == null || sizeBytes <= 0) return '';
    if (sizeBytes >= 1024 * 1024) {
      final value = sizeBytes / (1024 * 1024);
      return '${value.toStringAsFixed(value >= 10 ? 0 : 1)} Mo';
    }
    if (sizeBytes >= 1024) {
      final value = sizeBytes / 1024;
      return '${value.toStringAsFixed(value >= 10 ? 0 : 1)} Ko';
    }
    return '$sizeBytes o';
  }

  // ignore: unused_element
  _IsoWeek _computeIsoWeek(DateTime date) {
    final localDate = DateTime(date.year, date.month, date.day);
    final currentWeekStart =
        localDate.subtract(Duration(days: localDate.weekday - 1));
    final thursday = localDate.add(Duration(days: 4 - localDate.weekday));
    final isoYear = thursday.year;
    final firstThursday = DateTime(isoYear, 1, 4);
    final firstWeekStart =
        firstThursday.subtract(Duration(days: firstThursday.weekday - 1));
    final week =
        1 + currentWeekStart.difference(firstWeekStart).inDays ~/ 7;

    return _IsoWeek(year: isoYear, week: week);
  }
}

class _LocalInventorySnapshot {
  final int totalEP;
  final int totalASS;
  final int totalELEC;
  final int totalSynced;
  final int totalUnsynced;
  final int totalPoints;
  final int totalLignes;
  final int totalPolygones;

  const _LocalInventorySnapshot({
    required this.totalEP,
    required this.totalASS,
    required this.totalELEC,
    required this.totalSynced,
    required this.totalUnsynced,
    required this.totalPoints,
    required this.totalLignes,
    required this.totalPolygones,
  });
}

// ignore: unused_element
class _MetricsSnapshot {
  final Map<String, dynamic>? resume;
  final Map<String, dynamic>? day;
  final Map<String, dynamic>? week;
  final Map<String, dynamic>? month;
  final String? error;

  const _MetricsSnapshot({
    this.resume,
    this.day,
    this.week,
    this.month,
    this.error,
  });
}

class _OfflineBasemapSnapshot {
  final bool isReady;
  final String statusLabel;
  final String localPath;
  final String downloadedAt;
  final String serverUpdatedAt;
  final String packageKey;
  final String zoneId;
  final String style;
  final String format;

  const _OfflineBasemapSnapshot({
    required this.isReady,
    required this.statusLabel,
    required this.localPath,
    required this.downloadedAt,
    required this.serverUpdatedAt,
    required this.packageKey,
    required this.zoneId,
    required this.style,
    required this.format,
  });
}

class _OfflineBasemapCatalogSnapshot {
  final List<Map<String, dynamic>> zones;
  final List<Map<String, dynamic>> packages;

  const _OfflineBasemapCatalogSnapshot({
    required this.zones,
    required this.packages,
  });
}

// ignore: unused_element
class _IsoWeek {
  final int year;
  final int week;

  const _IsoWeek({
    required this.year,
    required this.week,
  });
}
