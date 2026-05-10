part of 'home_page.dart';

extension _HomePageAppActions on _HomePageState {
  Future<void> _performDownload() async {
    if (isDownloading) return;

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

    _setStateFromPart(() {
      isDownloading = true;
      _progressValue = 0.0;
      _processedItems = 0;
      _totalItems = 1;
    });

    try {
      final result = await SyncService().downloadAllData(
        onProgress: (progress, currentOperation, processed, total) {
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
      await _loadReferenceOverlays();
      await _refreshAllPoints();
      await _loadDisplayedLines();
      await _loadDisplayedSrmLines();
      await _loadPointCountsByTable();

      if (!mounted) return;

      final downloadedLocalCount =
          await DatabaseHelper().countDownloadedSrmRows();

      if (!mounted) return;

      final bool alreadyDownloaded = result.successCount == 0 &&
          result.failedCount == 0 &&
          downloadedLocalCount > 0;
      final bool nothingAvailable = result.successCount == 0 &&
          result.failedCount == 0 &&
          downloadedLocalCount == 0 &&
          result.skippedCount == 0;
      final bool fullFailure = result.failedCount > 0 &&
          result.successCount == 0 &&
          result.skippedCount == 0;
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

      final snackBarMessage = alreadyDownloaded
          ? 'Aucune nouvelle donnée à télécharger'
          : nothingAvailable
              ? 'Aucune donnée disponible pour votre compte'
              : result.interrupted
                  ? (result.interruptionMessage ??
                      'Connexion interrompue. Téléchargement arrêté.')
                  : fullFailure
                      ? networkFailure
                          ? 'Serveur SRM injoignable. Vérifiez la connexion.'
                          : 'Téléchargement impossible (${result.failedCount} erreurs)'
                      : partialFailure
                          ? 'Téléchargement partiel : ${result.successCount} nouvelles, ${result.failedCount} erreurs'
                          : result.successCount > 0
                              ? 'Téléchargement : ${result.successCount} nouvelles, ${result.skippedCount} déjà à jour'
                              : 'Toutes les données sont déjà à jour (${result.skippedCount})';

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
                          : result.successCount > 0
                              ? Colors.green
                              : Colors.blue;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(snackBarMessage),
          backgroundColor: snackBarColor,
        ),
      );
    } on DownloadInterruptedException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_downloadErrorMessage(e)),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
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
    if (isSyncing) return;

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

      if (result.successCount > 0) {
        final now = DateTime.now();
        await DatabaseHelper().saveLastSyncTime(now);
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
      if (mounted) {
        _setStateFromPart(() => isSyncing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de synchronisation : $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _showMockLocationDialogSafe() {
    if (!_canUseAdminGpsTools) return Future.value();
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
                'Sauvegarde en cours',
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
}
