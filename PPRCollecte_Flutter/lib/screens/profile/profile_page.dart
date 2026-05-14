import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/config/srm_config.dart';
import '../../data/local/database_helper.dart';
import '../../data/remote/api_service.dart';
import '../../services/formulaire_config_mobile_service.dart';
import '../../services/public_metrics_cache_service.dart';
import '../../services/sync_service.dart';

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
  late final FormulaireConfigMobileService _formulaireConfigService;
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

  /// Lignes locales que le sync a refuse de pousser car un champ
  /// nullable=false etait vide. Cf. SyncService._missingRequiredFields.
  /// Chaque entree : {metier, entity, schema, table, endpoint, uuid, missing, ts}.
  List<Map<String, dynamic>> _preflightSkips = const [];

  bool get _hasServerMetrics =>
      _resumeMetrics != null ||
      _dayMetrics != null ||
      _weekMetrics != null ||
      _monthMetrics != null;

  bool get _usesCachedMetricsAfterRefreshError =>
      _metricsError != null && _hasServerMetrics;

  /// Activite locale = file d'attente > 0 OU skips preflight > 0 OU erreurs
  /// photo > 0. Conditionne l'affichage de la section [6] : on cache la
  /// section si rien n'est en attente (UI moins charge en regime normal).
  bool get _hasLocalSyncActivity =>
      _localPendingNew > 0 ||
      _localPendingUpdates > 0 ||
      _localPendingPhotos > 0 ||
      _localFailedPhotos > 0 ||
      _localPendingHistory > 0 ||
      _preflightSkips.isNotEmpty;

  /// Vrai quand tout est strictement vide : aucune donnee terrain cote serveur,
  /// rien d'enregistre localement et aucune file d'attente. Permet d'afficher
  /// un message explicite plutot que des cartes de 0 muettes (qui font croire
  /// que le dashboard est casse).
  bool get _shouldShowEmptyDashboardBanner {
    if (!_hasServerMetrics) return false;
    final serverTotal = _metricInt(_resumeMetrics, 'nb_objets_crees_total');
    final hasLocalStock = (_totalEP + _totalASS) > 0;
    final hasQueued = _localPendingNew > 0 ||
        _localPendingUpdates > 0 ||
        _localPendingPhotos > 0 ||
        _localFailedPhotos > 0 ||
        _localPendingHistory > 0;
    return serverTotal == 0 && !hasLocalStock && !hasQueued;
  }

  @override
  void initState() {
    super.initState();
    _formulaireConfigService =
        FormulaireConfigMobileService(databaseHelper: _db);
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
        _loadPreflightSkips(),
      ]);
      final inventory = results[0] as _LocalInventorySnapshot;
      final cachedMetrics = results[1] as PublicMetricsCacheSnapshot;
      final preflightSkips = results[2] as List<Map<String, dynamic>>;

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
        _preflightSkips = preflightSkips;

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

  /// Lit l'app_metadata `sync_preflight_skips_v1` ecrit par SyncService a la
  /// fin de chaque cycle. Renvoie [] si pas de cache, json invalide ou
  /// structure inattendue (jamais d'exception remontee a l'UI).
  Future<List<Map<String, dynamic>>> _loadPreflightSkips() async {
    try {
      final raw = await _db.getAppMetadataValue(SyncService.preflightSkipsKey);
      if (raw == null || raw.trim().isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const [];
      final items = decoded['items'];
      if (items is! List) return const [];
      return items
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return const [];
    }
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
      final entities = await _profileEntitiesForMetier(metier);
      for (final entity in entities) {
        final tableName = entity.tableName;
        if (tableName.isEmpty) {
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

          if (entity.isPolygon) {
            polygones += count;
          } else if (entity.isLine) {
            lignes += count;
          } else {
            points += count;
          }
        } catch (_) {
          // Table absente localement.
        }
      }
    }

    final pendingPhotos = await _db.getPendingPhotoSyncItems(limit: 10000);
    final failedPhotos = await _db.countFailedPhotoSyncItems();
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

  Future<List<FormulaireConfigMobileEntity>> _profileEntitiesForMetier(
    String metier,
  ) async {
    final entities = <FormulaireConfigMobileEntity>[];
    final seenTables = <String>{};

    for (final geometryFilter in const ['point', 'line', 'polygon']) {
      final configured = await _formulaireConfigService.getMobileEntities(
        mobileMetier: metier,
        geometryFilter: geometryFilter,
        refreshIfEmpty: false,
      );
      for (final entity in configured) {
        final tableName = entity.tableName.trim();
        if (tableName.isEmpty) {
          continue;
        }
        final key = '${entity.schema}.$tableName'.toLowerCase();
        if (seenTables.add(key)) {
          entities.add(entity);
        }
      }
    }

    return entities;
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
                  // [1] Identite
                  _buildProfileCard(),
                  const SizedBox(height: 16),
                  // Empty state global si rien a montrer
                  if (_shouldShowEmptyDashboardBanner) ...[
                    _buildEmptyDashboardBanner(),
                    const SizedBox(height: 16),
                  ],
                  // [2] Aujourd'hui (jour courant + cumul du jour, CTA sync)
                  if (_hasServerMetrics) ...[
                    _buildTodaySection(),
                    const SizedBox(height: 16),
                  ],
                  // [3] Ma collecte cumulee (totaux + qualite + dates)
                  if (_resumeMetrics != null) ...[
                    _buildCumulativeSection(),
                    const SizedBox(height: 16),
                  ],
                  // [4] Tendance recente : 7j et 30j
                  if (_resumeMetrics != null) ...[
                    _buildTrendSection(),
                    const SizedBox(height: 16),
                  ],
                  // Cas metriques indisponibles : on signale au lieu de
                  // sauter silencieusement.
                  if (!_hasServerMetrics) ...[
                    _buildMetricsUnavailableSection(),
                    const SizedBox(height: 16),
                  ],
                  // [5] Donnees sur ce telephone (stock par metier + geom)
                  _buildLocalDataSection(),
                  const SizedBox(height: 16),
                  // [6] File d'attente sync (uniquement si activite)
                  if (_hasLocalSyncActivity) ...[
                    _buildLocalSyncSection(),
                    const SizedBox(height: 16),
                  ],
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
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
                        height: 1.18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B4F72),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _login.isNotEmpty ? _login : 'agent',
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.2,
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
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _startConduiteDrawingMode('ep'),
                  icon: const Icon(Icons.water_drop_outlined),
                  label: const Text(
                    'Conduite EP',
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1B4F72),
                    side: const BorderSide(color: Color(0xFF1B4F72)),
                    minimumSize: const Size(0, 52),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _startConduiteDrawingMode('asst'),
                  icon: const Icon(Icons.plumbing_outlined),
                  label: const Text(
                    'Conduite ASS',
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2E7D32),
                    side: const BorderSide(color: Color(0xFF2E7D32)),
                    minimumSize: const Size(0, 52),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
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

  /// [2] AUJOURD'HUI : focus sur le jour courant. Cards "crees aujourd'hui"
  /// (serveur) + "a synchroniser maintenant" (local). Sub-line dernière sync.
  Widget _buildTodaySection() {
    final createdToday = _metricInt(_dayMetrics, 'nb_objets_crees');
    final pendingNow = _localPendingNew + _localPendingUpdates;
    return _buildSection(
      title: "Aujourd'hui",
      color: const Color(0xFF1976D2),
      headerTrailing: Text(
        _formatDateLabel(
          _dayMetrics?['jour'] ?? DateTime.now().toIso8601String(),
        ),
        style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
      ),
      children: [
        _buildStatsGrid(
          childAspectRatio: 1.45,
          children: [
            _buildStatCard(
              icon: Icons.add_location_alt_outlined,
              label: "Créés aujourd'hui",
              value: '$createdToday',
              color: const Color(0xFF1976D2),
              helper: 'serveur (id_user_creat)',
            ),
            _buildStatCard(
              icon: Icons.outbox_outlined,
              label: 'À synchroniser',
              value: '$pendingNow',
              color: const Color(0xFF27AE60),
              helper: _localPendingUpdates > 0
                  ? '$_localPendingNew nouv. + $_localPendingUpdates modif.'
                  : 'nouveaux objets locaux',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildInfoRow(
          Icons.sync_outlined,
          'Dernière synchro métriques',
          _formatDateTimeLabel(_metricsFetchedAt),
        ),
        if (_usesCachedMetricsAfterRefreshError)
          _buildInfoRow(
            Icons.cloud_off_outlined,
            'Source métriques',
            'Cache local (serveur indisponible)',
          ),
      ],
    );
  }

  /// [3] MA COLLECTE CUMULÉE : totaux serveur depuis l'arrivée de l'agent +
  /// qualité (anomalies, photos) + dates d'activite. Fusion de l'ancien
  /// "Travail terrain" + "Qualite et completude".
  Widget _buildCumulativeSection() {
    final total = _metricInt(_resumeMetrics, 'nb_objets_crees_total');
    final anomalies = _metricInt(_resumeMetrics, 'nb_objets_anomalie_total');
    final anomalyRate =
        _metricDouble(_resumeMetrics, 'taux_anomalie_global_pct');
    final photosUploaded =
        _metricInt(_resumeMetrics, 'nb_photos_uploadees_total');
    final objectsWithPhoto =
        _metricInt(_resumeMetrics, 'nb_objets_avec_photo_total');
    final activeDays = _metricInt(_resumeMetrics, 'nb_jours_actifs');
    final photoCoverage = total > 0 ? (objectsWithPhoto * 100 / total) : 0.0;
    return _buildSection(
      title: 'Ma collecte cumulée',
      color: const Color(0xFF1B4F72),
      headerTrailing: const Icon(
        Icons.cloud_done_outlined,
        size: 18,
        color: Color(0xFF1B4F72),
      ),
      children: [
        _buildStatsGrid(
          childAspectRatio: 1.45,
          children: [
            _buildStatCard(
              icon: Icons.layers_outlined,
              label: 'Total créés',
              value: '$total',
              color: const Color(0xFF1B4F72),
              helper: 'cumul serveur',
            ),
            _buildStatCard(
              icon: Icons.report_problem_outlined,
              label: 'Anomalies',
              value: '$anomalies',
              color: const Color(0xFFE74C3C),
              helper: _formatPercent(anomalyRate),
            ),
            _buildStatCard(
              icon: Icons.cloud_upload_outlined,
              label: 'Photos uploadées',
              value: '$photosUploaded',
              color: const Color(0xFF27AE60),
              helper: objectsWithPhoto > 0
                  ? '$objectsWithPhoto objet${objectsWithPhoto > 1 ? 's' : ''} avec photo (${_formatPercent(photoCoverage)})'
                  : 'aucun objet avec photo',
            ),
            _buildStatCard(
              icon: Icons.event_available_outlined,
              label: 'Jours avec activité',
              value: '$activeDays',
              color: const Color(0xFF8E44AD),
              helper: 'création + sync + modif.',
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
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _buildOverviewBadges(),
          ),
        ],
      ],
    );
  }

  /// [4] TENDANCE RÉCENTE : 7j vs 30j (focus court terme). Remplace la
  /// section "Periodes en cours" qui dupliquait deja "Aujourd'hui" et
  /// presentait semaine/mois en double avec 7j/30j.
  Widget _buildTrendSection() {
    final recentWeek = _metricInt(_resumeMetrics, 'nb_objets_7j');
    final recentMonth = _metricInt(_resumeMetrics, 'nb_objets_30j');
    return _buildSection(
      title: 'Tendance récente',
      color: const Color(0xFF16A085),
      children: [
        _buildStatsGrid(
          childAspectRatio: 1.45,
          children: [
            _buildStatCard(
              icon: Icons.insights_outlined,
              label: '7 derniers jours',
              value: '$recentWeek',
              color: const Color(0xFF8E44AD),
              helper: 'objets créés',
            ),
            _buildStatCard(
              icon: Icons.calendar_month_outlined,
              label: '30 derniers jours',
              value: '$recentMonth',
              color: const Color(0xFFF39C12),
              helper: 'objets créés',
            ),
          ],
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
          text: _metricsUnavailableMessage(),
        ),
      ],
    );
  }

  String _metricsUnavailableMessage() {
    if (_metricsError == null || _metricsError!.trim().isEmpty) {
      return 'Aucune métrique serveur chargée pour cet agent. Rafraîchissez pour vérifier.';
    }

    return '${_metricsError!} Aucun cache serveur n’est disponible sur ce téléphone pour cet agent.';
  }

  Widget _buildEmptyDashboardBanner() {
    final role = _role.trim().toLowerCase();
    final isFieldAgent =
        role.isEmpty || role == 'editeur_terrain' || role == 'agent';
    final message = isFieldAgent
        ? "Vous n'avez encore collecte aucun objet terrain. "
            'Ouvrez la carte et placez votre premier point pour demarrer.'
        : "Aucune collecte enregistree sur ce compte. Les compteurs serveur "
            'restent a zero tant que vous ne creez pas d\'objets.';
    return _buildSection(
      title: 'Aucune activite terrain pour le moment',
      color: const Color(0xFF1B4F72),
      headerTrailing: const Icon(
        Icons.info_outline,
        size: 18,
        color: Color(0xFF1B4F72),
      ),
      children: [
        Text(
          message,
          style: const TextStyle(fontSize: 14, color: Color(0xFF333333)),
        ),
        const SizedBox(height: 8),
        const Text(
          'Les cartes ci-dessous afficheront vos statistiques des '
          'que la premiere donnee sera synchronisee.',
          style: TextStyle(fontSize: 12, color: Color(0xFF666666)),
        ),
      ],
    );
  }

  /// [5] DONNÉES SUR CE TÉLÉPHONE : tout ce qui est dans la SQLite locale,
  /// independamment du workflow de sync. Fusion de l'ancien
  /// "Stock par metier" + "Stock par geometrie".
  Widget _buildLocalDataSection() {
    final total = _totalEP + _totalASS;
    return _buildSection(
      title: 'Données sur ce téléphone',
      color: const Color(0xFF1B4F72),
      headerTrailing: Text(
        '$total objet${total > 1 ? 's' : ''}',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1B4F72),
        ),
      ),
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
        const SizedBox(height: 16),
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
        if (pendingTransport == 0 &&
            _localPendingHistory == 0 &&
            _preflightSkips.isEmpty) ...[
          const SizedBox(height: 12),
          _buildNoticeCard(
            icon: Icons.verified_outlined,
            color: const Color(0xFF27AE60),
            text: 'Aucune donnée locale en attente sur ce téléphone.',
          ),
        ],
        if (_preflightSkips.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildPreflightSkipsTile(),
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

  /// Tile expandable listant les lignes locales que le sync a refuse de
  /// pousser (champ NOT NULL vide). L'agent doit revenir les completer puis
  /// relancer la sync. Source : SyncService.preflightSkipsKey persiste en fin
  /// de chaque cycle de sync.
  Widget _buildPreflightSkipsTile() {
    const accent = Color(0xFFE74C3C);
    return Container(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: const Icon(Icons.warning_amber_outlined, color: accent),
          title: Text(
            'À compléter avant sync (${_preflightSkips.length})',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          subtitle: const Text(
            'Champ obligatoire vide → le serveur a refusé l\'enregistrement.',
            style: TextStyle(fontSize: 11, color: Color(0xFF666666)),
          ),
          children: _preflightSkips
              .map((item) => _buildPreflightSkipEntry(item, accent))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildPreflightSkipEntry(Map<String, dynamic> item, Color accent) {
    final entity = (item['entity'] ?? item['table'] ?? '?').toString();
    final uuid = (item['uuid'] ?? '').toString();
    final shortUuid = uuid.length > 8 ? uuid.substring(0, 8) : (uuid.isEmpty ? '?' : uuid);
    final missingRaw = item['missing'];
    final missing = missingRaw is List
        ? missingRaw.map((e) => e.toString()).join(', ')
        : missingRaw?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.fiber_manual_record, size: 8, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$entity · uuid $shortUuid…',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),
                if (missing.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Manque : $missing',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF666666),
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
    // Note : "30 derniers jours" est deja affiche en stat card depuis la
    // refonte profil ; on garde ici uniquement les badges complementaires
    // (modifs terrain, sessions sync) pour eviter la redondance visuelle.
    final badges = <Widget>[];

    final modifications =
        _metricInt(_resumeMetrics, 'nb_modifications_terrain_total');
    final syncs = _metricInt(_resumeMetrics, 'nb_evenements_sync_total');

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
