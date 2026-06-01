part of 'home_page.dart';

extension _HomePageAppActions on _HomePageState {
  Future<void> _performDownload() async {
    if (!_tryStartMobileJob(MobileJobType.download)) return;
    try {
      await _performDownloadLocked();
    } finally {
      _finishMobileJob(MobileJobType.download);
      if (mounted) {
        _setStateFromPart(() => isDownloading = false);
      }
    }
  }

  Future<void> _performDownloadLocked() async {
    final preflightReadiness = await MobileReadinessService().checkForSync();
    if (!mounted) return;
    if (!preflightReadiness.isReady) {
      await _showMobileReadinessFailure(preflightReadiness);
      return;
    }

    final reachable = await _refreshOnlineStatusForNetworkAction();
    if (!mounted) return;

    if (!reachable) {
      _setStateFromPart(() {
        isDownloading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Téléchargement impossible en mode hors ligne.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    // Pre-check : refresh des affectations depuis le serveur puis verification
    // qu'au moins une zone est affectee a l'agent. Sans cette garantie le
    // serveur renverrait 0 objet (filtre _user_zone_geom_filter_sql) et l'UI
    // afficherait un message ambigu.
    try {
      await ZoneSyncService().refreshZonesForCurrentUser();
    } catch (e) {
      debugPrint('[_performDownload] zone refresh failed: $e');
    }
    if (!mounted) return;

    final readiness = await MobileReadinessService().checkForDownload();
    if (!mounted) return;
    if (!readiness.isReady) {
      await _showMobileReadinessFailure(readiness);
      return;
    }

    final affectations = await DatabaseHelper().getZoneUtilisateursLocal(
      idUser: ApiService.userId,
      activeOnly: true,
    );
    if (!mounted) return;

    if (affectations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Aucune zone affectée à votre compte. Contactez l\'administrateur.',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
        ),
      );
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Aucune zone affectée'),
          content: const Text(
            "Votre compte n'a aucune zone d'affectation active.\n\n"
            "Aucune donnée terrain ne peut être téléchargée tant qu'un administrateur "
            "ne vous a pas attribué au moins une zone via l'interface back-office.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    _setStateFromPart(() {
      isDownloading = true;
      _progressValue = 0.0;
      _processedItems = 0;
      _totalItems = 1;
    });
    await DownloadNotificationService.start();

    var notificationResolved = false;
    var downloadFailureMessage =
        'Téléchargement interrompu. Relancez pour reprendre.';

    try {
      final result = await SyncService().downloadAllData(
        onProgress: (progress, currentOperation, processed, total) {
          DownloadNotificationService.update(
            progress: progress,
            operation: currentOperation,
            processed: processed,
            total: total,
          );
          if (!mounted) return;
          _setStateFromPart(() {
            _progressValue = progress;
            _currentOperation = currentOperation;
            _processedItems = processed;
            _totalItems = total;
          });
        },
      );

      if (!mounted) return;

      _setStateFromPart(() => lastSyncResult = result);

      await _hydrateOfflineBasemapState();
      await _loadAffleurants();
      await _loadReferenceOverlays();
      await _refreshAllPoints();
      await _loadDisplayedLines();
      await _loadDisplayedSrmLines();
      await _loadPointCountsByTable();

      if (!mounted) return;

      final downloadedLocalCount =
          await DatabaseHelper().countDownloadedSrmRows();
      result.localDownloadedDataCount = downloadedLocalCount;

      if (!mounted) return;

      final bool hasOfflinePackageResult =
          result.orthoTileCount > 0 || result.affleurantCount > 0;
      final bool offlinePackageChanged =
          result.orthoDownloaded || result.affleurantsDownloaded;
      final bool alreadyDownloaded = result.successCount == 0 &&
          result.failedCount == 0 &&
          downloadedLocalCount > 0 &&
          !offlinePackageChanged;
      final bool nothingAvailable = result.successCount == 0 &&
          result.failedCount == 0 &&
          downloadedLocalCount == 0 &&
          result.skippedCount == 0 &&
          !hasOfflinePackageResult;
      final bool fullFailure = result.failedCount > 0 &&
          result.successCount == 0 &&
          result.skippedCount == 0 &&
          !hasOfflinePackageResult;
      final bool partialFailure = result.failedCount > 0 && !fullFailure;
      final bool networkFailure = result.interrupted ||
          fullFailure &&
              result.errors.isNotEmpty &&
              result.errors.every((error) {
                final lower = error.toLowerCase();
                return lower.contains('erreur reseau') ||
                    lower.contains('erreur réseau') ||
                    lower.contains('connexion interrompue') ||
                    lower.contains('timeout') ||
                    lower.contains('socketexception') ||
                    lower.contains('connection refused') ||
                    lower.contains('failed host lookup');
              });

      _showDownloadResult(
        result,
        alreadyDownloaded: alreadyDownloaded,
        nothingAvailable: nothingAvailable,
      );

      String buildDownloadSnackbarSuccess() {
        final parts = <String>[
          'Téléchargement terminé',
          '${result.localDownloadedDataCount} données',
        ];
        if (result.orthoTileCount > 0) {
          parts.add('${result.orthoTileCount} tuiles ortho');
        }
        if (result.affleurantCount > 0) {
          parts.add('${result.affleurantCount} affleurants');
        }
        if (result.skippedCount > 0) {
          parts.add('${result.skippedCount} ignorées (format invalide)');
        }
        return parts.join(', ');
      }

      final snackBarMessage = alreadyDownloaded
          ? 'Données des zones affectées déjà téléchargées'
          : nothingAvailable
              ? 'Aucune donnée dans les zones affectées à votre compte'
              : result.interrupted
                  ? (result.interruptionMessage ??
                      'Connexion interrompue. Téléchargement arrêté.')
                  : fullFailure
                      ? networkFailure
                          ? 'Serveur SRM injoignable. Vérifiez la connexion.'
                          : 'Téléchargement impossible (${result.failedCount} erreurs)'
                      : partialFailure
                          ? 'Téléchargement partiel : ${result.successCount} nouvelles, ${result.failedCount} erreurs'
                          : result.successCount > 0 || hasOfflinePackageResult
                              ? buildDownloadSnackbarSuccess()
                              : 'Toutes les données reçues sont ignorées (format invalide) (${result.skippedCount})';

      final snackBarColor = alreadyDownloaded
          ? Colors.blue
          : nothingAvailable
              ? Colors.orange
              : result.interrupted
                  ? Colors.red
                  : fullFailure
                      ? Colors.red
                      : partialFailure
                          ? Colors.orange
                          : result.successCount > 0 || hasOfflinePackageResult
                              ? Colors.green
                              : Colors.blue;

      if (result.interrupted || fullFailure || partialFailure) {
        downloadFailureMessage = snackBarMessage;
        await DownloadNotificationService.fail(text: snackBarMessage);
        notificationResolved = true;
      } else {
        await DownloadNotificationService.complete(text: snackBarMessage);
        notificationResolved = true;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(snackBarMessage),
          backgroundColor: snackBarColor,
        ),
      );
    } on DownloadInterruptedException catch (e) {
      downloadFailureMessage = e.message;
      await DownloadNotificationService.fail(text: e.message);
      notificationResolved = true;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      downloadFailureMessage = _downloadErrorMessage(e);
      await DownloadNotificationService.fail(text: downloadFailureMessage);
      notificationResolved = true;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(downloadFailureMessage),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (!notificationResolved) {
        await DownloadNotificationService.fail(text: downloadFailureMessage);
      }
      if (mounted) {
        _setStateFromPart(() => isDownloading = false);
      }
    }
  }

  String _downloadErrorMessage(Object error) {
    final value = error.toString().toLowerCase();
    if (value.contains('connexion interrompue') ||
        value.contains('erreur reseau') ||
        value.contains('erreur réseau') ||
        value.contains('timeout') ||
        value.contains('socketexception') ||
        value.contains('clientexception') ||
        value.contains('failed host lookup') ||
        value.contains('connection refused') ||
        value.contains('connection reset') ||
        value.contains('network is unreachable')) {
      return 'Connexion interrompue. Vérifiez Internet puis relancez pour reprendre.';
    }

    var message = error.toString().trim();
    message = message
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .replaceFirst(RegExp(r'^FlutterError:\s*'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (message.isEmpty || message.toLowerCase().contains('flutter')) {
      return 'Téléchargement impossible. Vérifiez la connexion puis réessayez.';
    }
    return 'Téléchargement impossible : $message';
  }

  void handleMenuPress() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DataCategoriesPage(
          isOnline: _isOnlineDynamic,
          agentName: widget.agentName,
        ),
      ),
    ).then((_) {
      if (!mounted) return;

      _refreshAllPoints();
      _loadDisplayedPoints();
      _loadDisplayedLines();
      _loadDisplayedSrmLines();
      _loadDisplayedPolygons();
      _loadPointCountsByTable();

      if (HomePage.pendingFocusTarget != null) {
        final target = HomePage.pendingFocusTarget!;
        HomePage.pendingFocusTarget = null;
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _suspendAutoCenterFor(const Duration(seconds: 10));
            _focusOnTarget(target);
          }
        });
      }
    });
  }

  void _showLogoutConfirmation() => _showLogoutConfirmationImpl(this);

  Future<void> _performLogout() async {
    await DatabaseHelper().clearSrmSession();
    ApiService.resetSession();

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  Future<void> _performSync() async {
    if (!_tryStartMobileJob(MobileJobType.sync)) return;
    try {
      await _performSyncLocked();
    } finally {
      _finishMobileJob(MobileJobType.sync);
      if (mounted) {
        _setStateFromPart(() => isSyncing = false);
      }
    }
  }

  Future<void> _performSyncLocked() async {
    // Meme si rien n'est en attente d'envoi, on continue : la synchronisation
    // verifie aussi les nouveautes serveur de la zone agent.

    final reachable = await _refreshOnlineStatusForNetworkAction();
    if (!mounted) return;

    if (!reachable) {
      _setStateFromPart(() {
        isSyncing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Synchronisation impossible en mode hors ligne.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    _setStateFromPart(() {
      isSyncing = true;
      _syncProgressValue = 0.0;
      _syncProcessedItems = 0;
      _syncTotalItems = 1;
    });
    await DownloadNotificationService.start(
      title: 'Synchronisation SRM',
      text: 'Préparation de la synchronisation...',
    );

    var notificationResolved = false;
    var syncFailureMessage =
        'Synchronisation interrompue. Relancez pour reprendre.';

    try {
      final syncService = SyncService();
      final result = await syncService.syncAllDataSequential(
        onProgress: (progress, currentOperation, processed, total) {
          final safeProgress = progress.isNaN || progress.isInfinite
              ? 0.0
              : progress.clamp(0.0, 1.0);
          final safeProcessed =
              processed.isNaN || processed.isInfinite ? 0 : processed;
          final safeTotal = total.isNaN || total.isInfinite ? 1 : total;

          DownloadNotificationService.update(
            title: 'Synchronisation en cours',
            progress: safeProgress,
            operation: currentOperation,
            processed: safeProcessed,
            total: safeTotal,
          );

          if (mounted) {
            _setStateFromPart(() {
              _syncProgressValue = safeProgress;
              _currentSyncOperation = currentOperation;
              _syncProcessedItems = safeProcessed;
              _syncTotalItems = safeTotal;
            });
          }
        },
      );

      final notificationMessage = _syncNotificationMessage(result);
      if (result.failedCount > 0) {
        syncFailureMessage = notificationMessage;
        await DownloadNotificationService.fail(
          title: result.successCount > 0
              ? 'Synchronisation partielle'
              : 'Synchronisation échouée',
          text: notificationMessage,
        );
      } else {
        await DownloadNotificationService.complete(
          title: 'Synchronisation terminée',
          text: notificationMessage,
        );
      }
      notificationResolved = true;

      final completedCleanly = !result.interrupted &&
          result.failedCount == 0 &&
          result.warningCount == 0;
      if (result.successCount > 0 || completedCleanly) {
        final now = DateTime.now();
        await DatabaseHelper().saveLastSyncTime(now);
        if (completedCleanly) {
          // Marque la synchro comme COMPLETE seulement si aucune row n'a
          // echoue : permet au court-circuit du bouton Synchroniser de
          // distinguer un succes total d'un succes partiel.
          await DatabaseHelper().saveLastFullSyncTime(now);
        }
        homeController.markSyncSuccess();
        if (mounted) {
          _setStateFromPart(() {
            _lastSyncTimeText = _formatTimeHHmm(now);
          });
        }

        await syncService.refreshEpRegardMiroirCache(result: result);
        try {
          await PublicMetricsCacheService(
            databaseHelper: DatabaseHelper(),
          ).prefetchForCurrentSession();
        } catch (e) {
          debugPrint('[METRICS] Refresh apres sync ignore: $e');
        }
      }

      if (mounted) {
        _setStateFromPart(() {
          lastSyncResult = result;
          isSyncing = false;
        });
      }

      _showSyncResult(result);
    } catch (e) {
      syncFailureMessage = _syncErrorMessage(e);
      await DownloadNotificationService.fail(
        title: 'Synchronisation interrompue',
        text: syncFailureMessage,
      );
      notificationResolved = true;
      if (mounted) {
        _setStateFromPart(() => isSyncing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(syncFailureMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (!notificationResolved) {
        await DownloadNotificationService.fail(
          title: 'Synchronisation interrompue',
          text: syncFailureMessage,
        );
      }
    }
  }

  String _syncNotificationMessage(SyncResult result) {
    final displaySuccess =
        result.displaySuccessCount < 0 ? 0 : result.displaySuccessCount;
    final received = result.postSyncReceivedCount;
    final successParts = <String>[
      if (displaySuccess > 0) _syncSyncedDataText(displaySuccess),
      if (result.photoSuccessCount > 0)
        _syncSentPhotoText(result.photoSuccessCount),
      if (received > 0) _syncReceivedDataText(received),
    ];
    final successSummary = successParts.join(', ');
    if (displaySuccess == 0 &&
        result.photoSuccessCount == 0 &&
        received == 0 &&
        result.failedCount == 0 &&
        result.warningCount == 0) {
      return 'Aucune donnée à synchroniser';
    }
    if (result.failedCount > 0 && successSummary.isNotEmpty) {
      return 'Synchronisation partielle : $successSummary, ${_syncErrorCountText(result.failedCount)}';
    }
    if (result.failedCount > 0) {
      return 'Synchronisation échouée : ${_syncErrorCountText(result.failedCount)}';
    }
    if (result.warningCount > 0 && successSummary.isNotEmpty) {
      return 'Synchronisation terminee : $successSummary, avec ${_syncWarningCountText(result.warningCount)}';
    }
    if (result.warningCount == 0 && successSummary.isNotEmpty) {
      return 'Synchronisation terminee : $successSummary';
    }
    if (result.warningCount > 0) {
      return 'Synchronisation terminée avec ${_syncWarningCountText(result.warningCount)}';
    }
    return 'Synchronisation terminée : ${_syncSyncedDataText(displaySuccess)}';
  }

  String _syncErrorMessage(Object error) {
    var message = error.toString().trim();
    message = message
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .replaceFirst(RegExp(r'^FlutterError:\s*'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (message.isEmpty) {
      return 'Synchronisation interrompue. Relancez pour reprendre.';
    }
    return 'Erreur de synchronisation : $message';
  }

  Future<void> _showMockLocationDialogSafe() {
    // Admin : dialog "Position GPS mock" complet (saisie manuelle + acces NMEA).
    // Non-admin : on saute la saisie manuelle et on ouvre directement la dialog
    // "Pont NMEA" qui est leur seule source autorisee.
    if (!_canUseAdminGpsTools) {
      return _showNmeaBridgeDialog(this, ScaffoldMessenger.maybeOf(context));
    }
    return _showMockLocationDialogSafeImpl(this);
  }

  Widget _buildStepIndicator() {
    final lowerOperation = _currentSyncOperation.toLowerCase();
    var currentStep = 'Points';

    if (lowerOperation.contains('ligne') ||
        lowerOperation.contains('canalisation') ||
        lowerOperation.contains('troncon') ||
        lowerOperation.contains('conduite')) {
      currentStep = 'Lignes';
    } else if (lowerOperation.contains('polyg') ||
        lowerOperation.contains('planche')) {
      currentStep = 'Polygones';
    }

    Color stepColor(String step) {
      if (currentStep == step) return Colors.orange;
      if (step == 'Points') return Colors.green;
      if (step == 'Lignes' && currentStep == 'Polygones') return Colors.green;
      return Colors.grey;
    }

    FontWeight stepWeight(String step) {
      return currentStep == step ? FontWeight.bold : FontWeight.normal;
    }

    return Row(
      children: [
        Icon(
          Icons.check_circle,
          color: stepColor('Points'),
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          'Points',
          style: TextStyle(
            color: stepColor('Points'),
            fontWeight: stepWeight('Points'),
          ),
        ),
        const SizedBox(width: 12),
        Icon(
          Icons.check_circle,
          color: stepColor('Lignes'),
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          'Lignes',
          style: TextStyle(
            color: stepColor('Lignes'),
            fontWeight: stepWeight('Lignes'),
          ),
        ),
        const SizedBox(width: 12),
        Icon(
          Icons.check_circle,
          color: stepColor('Polygones'),
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          'Polygones',
          style: TextStyle(
            color: stepColor('Polygones'),
            fontWeight: stepWeight('Polygones'),
          ),
        ),
      ],
    );
  }

  Widget _buildSyncProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[100]!),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.cloud_upload,
                color: Colors.orange,
              ),
              SizedBox(width: 10),
              Text(
                'Synchronisation en cours',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: _syncProgressValue,
            backgroundColor: Colors.grey[300],
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${(_syncProgressValue * 100).toStringAsFixed(0)}%'),
              Text('$_syncProcessedItems/$_syncTotalItems'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _currentSyncOperation,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          _buildStepIndicator(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[100]!),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.cloud_download,
                color: Colors.blue,
              ),
              SizedBox(width: 10),
              Text(
                'Téléchargement en cours',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: _progressValue,
            backgroundColor: Colors.grey[300],
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(_progressValue * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '$_processedItems/$_totalItems',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _currentOperation,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  bool _tryStartMobileJob(MobileJobType requestedJob) {
    if (_mobileJobGuard.tryStart(requestedJob)) {
      return true;
    }

    if (!mounted) return false;
    final activeJob = _mobileJobGuard.activeJob;
    final activeLabel = _mobileJobLabel(activeJob);
    final requestedLabel = _mobileJobLabel(requestedJob);
    final message = activeJob == requestedJob
        ? '$activeLabel déjà en cours.'
        : '$activeLabel en cours. Attendez la fin avant de lancer $requestedLabel.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
      ),
    );
    return false;
  }

  void _finishMobileJob(MobileJobType job) {
    _mobileJobGuard.finish(job);
  }

  Future<void> _showMobileReadinessFailure(
    MobileReadinessResult readiness,
  ) async {
    if (!mounted) return;
    final message = readiness.blockingMessage;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 5),
      ),
    );

    final title = readiness.issues.contains(
      MobileReadinessIssue.sessionExpired,
    )
        ? 'Session expirée'
        : readiness.issues.contains(MobileReadinessIssue.mobileConfigMissing)
            ? 'Configuration mobile absente'
            : readiness.issues.contains(
                MobileReadinessIssue.zoneAssignmentMissing,
              )
                ? 'Aucune zone affectée'
                : 'Action impossible';
    final details = readiness.issues.contains(
      MobileReadinessIssue.zoneAssignmentMissing,
    )
        ? "Votre compte n'a aucune zone d'affectation active.\n\n"
            "Aucune donnée terrain ne peut être téléchargée tant qu'un administrateur "
            "ne vous a pas attribué au moins une zone via l'interface back-office."
        : message;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(details),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _mobileJobLabel(MobileJobType? job) {
    switch (job) {
      case MobileJobType.download:
        return 'Téléchargement';
      case MobileJobType.sync:
        return 'Synchronisation';
      case null:
        return 'Action';
    }
  }
}

String _syncSyncedDataText(int count) {
  return count == 1 ? '1 donnée synchronisée' : '$count données synchronisées';
}

String _syncSentPhotoText(int count) {
  return count == 1 ? '1 photo envoyee' : '$count photos envoyees';
}

String _syncReceivedDataText(int count) {
  return count == 1 ? '1 nouveaute recue' : '$count nouveautes recues';
}

String _syncUnsyncedDataText(int count) {
  return count == 1
      ? '1 donnée non synchronisée'
      : '$count données non synchronisées';
}

String _syncUnableToSendDataText(int count) {
  return count == 1
      ? "1 donnée n'a pas pu être envoyée"
      : "$count données n'ont pas pu être envoyées";
}

String _syncErrorCountText(int count) {
  return count == 1 ? '1 erreur' : '$count erreurs';
}

String _syncWarningCountText(int count) {
  return count == 1 ? 'un avertissement' : '$count avertissements';
}
