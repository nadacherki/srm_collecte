part of 'home_page.dart';

void _showSyncConfirmationDialogImpl(_HomePageState state) async {
  // S'il n'y a rien a envoyer, on lance quand meme la verification serveur :
  // le bouton Synchroniser est maintenant bidirectionnel.
  final db = DatabaseHelper();
  final pending = await db.countPendingSync();
  if (!state.mounted) return;
  if (pending == 0) {
    await state._performSync();
    return;
  }

  final reachable = await state._refreshOnlineStatusForNetworkAction();
  if (!state.mounted) return;

  if (!reachable) {
    ScaffoldMessenger.of(state.context).showSnackBar(
      const SnackBar(
        content: Text(
          'Synchronisation impossible en mode hors ligne.',
        ),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  showDialog(
    context: state.context,
    builder: (ctx) => AlertDialog(
      title: const Text('Confirmation de synchronisation'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$pending donnée(s) locale(s) en attente d\'envoi.',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Êtes-vous sûr de vouloir synchroniser vos données locales vers le serveur ?',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Non'),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(ctx);
            await state._performSync();
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          child: const Text(
            'Oui',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    ),
  );
}

void _showSyncResultImpl(_HomePageState state, SyncResult result) {
  showDialog(
    context: state.context,
    builder: (ctx) {
      final displaySuccessCount =
          result.displaySuccessCount < 0 ? 0 : result.displaySuccessCount;
      final errorsToShow = result.errors.take(10).toList();
      final remaining = result.errors.length - errorsToShow.length;
      final warningsToShow = result.warnings.take(10).toList();
      final remainingWarnings = result.warnings.length - warningsToShow.length;
      final syncLog = result.syncSessionLog;
      final syncSessionUuid = result.syncSessionUuid;
      String? syncJournalText;
      if (syncLog != null) {
        final status = syncLog['statut']?.toString().trim();
        final receivedItems = syncLog['received_items'] ?? 0;
        final totalItems = syncLog['total_items'] ?? 0;
        final receivedAttachments = syncLog['received_attachments'] ?? 0;
        final totalAttachments = syncLog['total_attachments'] ?? 0;
        final failedItems = syncLog['failed_items'] ?? 0;
        syncJournalText =
            'Journal serveur : ${status?.isNotEmpty == true ? status : "statut inconnu"} '
            '· données $receivedItems/$totalItems '
            '· photos $receivedAttachments/$totalAttachments'
            '${failedItems == 0 ? "" : " · erreurs $failedItems"}';
      } else if (syncSessionUuid != null && syncSessionUuid.isNotEmpty) {
        syncJournalText =
            'Journal serveur : ${result.syncSessionStatus ?? "vérification indisponible"} '
            '· session $syncSessionUuid';
      }

      bool isConnectionError(String error) {
        final lower = error.toLowerCase();
        return lower.contains('connexion perdue') ||
            lower.contains('serveur injoignable') ||
            lower.contains('timeout') ||
            lower.contains('reseau') ||
            lower.contains('réseau') ||
            lower.contains('socketexception') ||
            lower.contains('connection refused') ||
            lower.contains('failed host lookup');
      }

      bool isSessionExpiredError(String error) {
        final lower = error.toLowerCase();
        return lower.contains('session expir') ||
            lower.contains('token expire') ||
            lower.contains('token expiré') ||
            lower.contains('jwt expired') ||
            lower.contains('401 unauthorized') ||
            lower.contains('401');
      }

      final hasConnectionErrors = result.errors.any(isConnectionError);
      final hasSessionExpiredErrors = result.errors.any(isSessionExpiredError);

      final String title;
      final IconData titleIcon;
      final Color titleColor;

      if (result.failedCount == 0 &&
          result.warningCount == 0 &&
          result.successCount > 0) {
        title = 'Synchronisation réussie';
        titleIcon = Icons.check_circle;
        titleColor = Colors.green;
      } else if (result.failedCount == 0 && result.warningCount > 0) {
        title = 'Synchronisation terminée avec avertissements';
        titleIcon = Icons.info_outline;
        titleColor = Colors.orange;
      } else if (result.successCount > 0 && result.failedCount > 0) {
        title = 'Synchronisation partielle';
        titleIcon = Icons.warning_amber;
        titleColor = Colors.orange;
      } else if (result.successCount == 0 &&
          result.failedCount > 0 &&
          hasSessionExpiredErrors) {
        title = 'Session expirée';
        titleIcon = Icons.lock_clock;
        titleColor = Colors.red;
      } else if (result.successCount == 0 &&
          result.failedCount > 0 &&
          hasConnectionErrors) {
        title = 'Connexion au serveur indisponible';
        titleIcon = Icons.cloud_off;
        titleColor = Colors.red;
      } else if (result.successCount == 0 && result.failedCount > 0) {
        title = 'Synchronisation échouée';
        titleIcon = Icons.error;
        titleColor = Colors.red;
      } else {
        title = 'Aucune donnée à synchroniser';
        titleIcon = Icons.info;
        titleColor = Colors.blue;
      }

      final isNoDataResult = result.successCount == 0 &&
          result.failedCount == 0 &&
          result.warningCount == 0 &&
          errorsToShow.isEmpty &&
          warningsToShow.isEmpty;

      if (isNoDataResult) {
        return AlertDialog(
          contentPadding: const EdgeInsets.fromLTRB(24, 22, 24, 6),
          content: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: titleColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(titleIcon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aucune donnée à synchroniser',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Tout est déjà à jour sur ce téléphone.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 20, 12),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
              },
              child: const Text('OK'),
            ),
          ],
        );
      }

      return AlertDialog(
        title: Row(
          children: [
            Icon(titleIcon, color: titleColor, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(title, style: const TextStyle(fontSize: 18)),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (displaySuccessCount > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    _syncSyncedDataText(displaySuccessCount),
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (result.photoSuccessCount > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    _syncSentPhotoText(result.photoSuccessCount),
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (result.postSyncReceivedCount > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    _syncReceivedDataText(result.postSyncReceivedCount),
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (result.postSyncProtectedLocalCount > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    result.postSyncProtectedLocalCount == 1
                        ? '1 donnee locale conservee en attente d envoi'
                        : '${result.postSyncProtectedLocalCount} donnees locales conservees en attente d envoi',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (result.failedCount > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    _syncUnsyncedDataText(result.failedCount),
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (result.warningCount > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${_syncWarningCountText(result.warningCount)} sur le journal local',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (syncJournalText != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Text(
                    syncJournalText,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
              if (hasConnectionErrors && result.successCount > 0) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: const Text(
                    'La connexion a été interrompue pendant la synchronisation. Les données déjà envoyées ont été sauvegardées. Relancez la synchronisation pour envoyer le reste.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ] else if (hasConnectionErrors && result.failedCount > 0) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: const Text(
                    "La synchronisation n'a pas pu joindre le serveur SRM. Cela peut venir d'une connexion Internet absente, d'un réseau instable, ou d'un backend Django arrêté ou inaccessible.",
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Vérifiez le réseau de l'appareil, puis assurez-vous que le serveur Django est démarré et joignable avant de réessayer.",
                ),
                const SizedBox(height: 8),
                Text(
                  'Détails techniques : ${_syncUnableToSendDataText(result.failedCount)}.',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ] else if (hasSessionExpiredErrors) ...[
                const SizedBox(height: 8),
                const Text(
                  'Session expirée. Veuillez vous reconnecter.',
                ),
              ] else if (result.failedCount > 0) ...[
                const SizedBox(height: 8),
                const Text(
                  'Vérifiez votre connexion internet et réessayez.',
                ),
              ],
              if (errorsToShow.isNotEmpty && !hasConnectionErrors) ...[
                const SizedBox(height: 10),
                const Text(
                  'Détails des erreurs :',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 5),
                ...errorsToShow.map(
                  (error) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '- $error',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                if (remaining > 0)
                  Text(
                    '- ... et $remaining autres erreurs.',
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
              if (warningsToShow.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text(
                  'Remarques non bloquantes :',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 5),
                ...warningsToShow.map(
                  (warning) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '- $warning',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                if (remainingWarnings > 0)
                  Text(
                    '- ... et $remainingWarnings autres remarques.',
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
            },
            child: const Text('OK'),
          ),
        ],
      );
    },
  ).then((_) async {
    await state._refreshAfterNavigation();
  });
}

void _showSaveConfirmationDialogImpl(_HomePageState state) async {
  final reachable = await state._refreshOnlineStatusForNetworkAction();
  if (!state.mounted) return;

  if (!reachable) {
    ScaffoldMessenger.of(state.context).showSnackBar(
      const SnackBar(
        content: Text(
          'Téléchargement impossible en mode hors ligne.',
        ),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  showDialog(
    context: state.context,
    builder: (ctx) => AlertDialog(
      title: const Text('Confirmation de téléchargement'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Êtes-vous sûr de vouloir télécharger les données SRM depuis le serveur ?',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Non'),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(ctx);
            await state._performDownload();
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
          child: const Text(
            'Oui',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    ),
  );
}

void _showDownloadResultImpl(
  _HomePageState state,
  SyncResult result, {
  required bool alreadyDownloaded,
  required bool nothingAvailable,
}) {
  showDialog(
    context: state.context,
    builder: (ctx) {
      final errorsToShow = result.errors.take(10).toList();
      final remaining = result.errors.length - errorsToShow.length;
      bool isLikelyNetworkFailure(String error) {
        final lower = error.toLowerCase();
        return lower.contains('connexion interrompue') ||
            lower.contains('erreur reseau') ||
            lower.contains('erreur réseau') ||
            lower.contains('timeout') ||
            lower.contains('socketexception') ||
            lower.contains('connection refused') ||
            lower.contains('failed host lookup');
      }

      final hasFailures = result.failedCount > 0;
      final hasOfflinePackageResult =
          result.orthoTileCount > 0 || result.affleurantCount > 0;
      final fullFailure = hasFailures &&
          result.successCount == 0 &&
          result.skippedCount == 0 &&
          !hasOfflinePackageResult;
      final partialFailure = hasFailures &&
          !fullFailure &&
          !alreadyDownloaded &&
          !nothingAvailable;
      final networkOnlyFailure = result.interrupted ||
          (hasFailures &&
              result.errors.isNotEmpty &&
              result.errors.every(isLikelyNetworkFailure));

      return AlertDialog(
        title: Text(
          alreadyDownloaded
              ? 'Données déjà téléchargées'
              : nothingAvailable
                  ? 'Aucune donnée disponible'
                  : result.interrupted
                      ? 'Téléchargement interrompu'
                      : fullFailure
                          ? networkOnlyFailure
                              ? 'Connexion au serveur indisponible'
                              : 'Téléchargement impossible'
                          : partialFailure
                              ? 'Téléchargement partiel'
                              : 'Téléchargement terminé',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (alreadyDownloaded) ...[
                const Text(
                  'Toutes les données des zones affectées à votre compte sont déjà téléchargées.',
                ),
                if (result.updatedCount > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                      '${result.updatedCount} objet(s) rafraîchi(s) (modifications serveur)'),
                ],
              ],
              if (nothingAvailable) ...[
                const Text(
                  "Aucune donnée n'a été trouvée dans les zones affectées à votre compte.",
                ),
              ],
              if (result.interrupted) ...[
                const Text(
                  'Connexion interrompue. Vérifiez Internet puis relancez pour reprendre.',
                ),
                const SizedBox(height: 8),
              ],
              if (fullFailure && !result.interrupted) ...[
                Text(
                  networkOnlyFailure
                      ? "Aucune donnée n'a pu être téléchargée pour le moment."
                      : "Aucune donnée n'a pu être téléchargée.",
                ),
                const SizedBox(height: 8),
              ],
              if (!fullFailure || hasOfflinePackageResult) ...[
                const SizedBox(height: 10),
                const Text(
                  'Bilan du téléchargement',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Données disponibles sur ce mobile : ${result.localDownloadedDataCount}',
                ),
                Text('Nouvelles données reçues : ${result.successCount}'),
                if (result.updatedCount > 0)
                  Text(
                      'Données déjà présentes mises à jour : ${result.updatedCount}'),
                if (result.zoneFeatureCount > 0)
                  Text(
                      'Données des zones affectées : ${result.zoneFeatureCount}'),
                if (result.referentielCount > 0)
                  Text('Référentiel ONEP : ${result.referentielCount}'),
                if (result.anomalieCount > 0)
                  Text('Anomalies terrain : ${result.anomalieCount}'),
                if (result.incompletCount > 0)
                  Text('Objets incomplets : ${result.incompletCount}'),
                if (result.orthoTileCount > 0)
                  Text(
                    result.orthoAlreadyUpToDate
                        ? 'Ortho / fond offline : ${result.orthoTileCount} tuiles déjà présentes'
                        : 'Ortho / fond offline : ${result.orthoTileCount} tuiles téléchargées',
                  ),
                if (result.affleurantCount > 0)
                  Text(
                    result.affleurantsAlreadyUpToDate
                        ? 'Affleurants : ${result.affleurantCount} déjà présents'
                        : 'Affleurants : ${result.affleurantCount} téléchargés',
                  ),
              ],
              if (!nothingAvailable && result.skippedCount > 0)
                Text(
                    '${result.skippedCount} données ignorées (format invalide)'),
              if (result.failedCount > 0)
                Text(
                  networkOnlyFailure
                      ? '${result.failedCount} type(s) de données en attente.'
                      : "${result.failedCount} type(s) de données n'ont pas pu être mis à jour.",
                ),
              if (errorsToShow.isNotEmpty && !networkOnlyFailure) ...[
                const SizedBox(height: 10),
                const Text('Détails des erreurs :'),
                const SizedBox(height: 5),
                ...errorsToShow.map(
                  (error) => Text(
                    '- $error',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                if (remaining > 0) ...[
                  const SizedBox(height: 5),
                  Text(
                    '- ... et $remaining autres problèmes.',
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              state._loadDisplayedPolygons();
              state._loadDownloadedLineOverlays();
            },
            child: const Text('OK'),
          ),
        ],
      );
    },
  );
}

void _showLogoutConfirmationImpl(_HomePageState state) {
  showDialog(
    context: state.context,
    builder: (ctx) => AlertDialog(
      title: const Text('Confirmation de déconnexion'),
      content: const Text(
        'Êtes-vous sûr de vouloir vous déconnecter ?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Non'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(ctx);
            state._performLogout();
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text(
            'Oui',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    ),
  );
}

Future<void> _showMockLocationDialogSafeImpl(_HomePageState state) async {
  final hostContext = state.context;
  final messenger = ScaffoldMessenger.maybeOf(hostContext);
  final initialPosition =
      state.homeController.mockPosition ?? state.homeController.userPosition;
  final xController = TextEditingController(
    text: initialPosition.longitude.toStringAsFixed(3),
  );
  final yController = TextEditingController(
    text: initialPosition.latitude.toStringAsFixed(3),
  );
  final initialAltitude =
      state.homeController.mockAltitude ?? state.homeController.currentAltitude;
  final altitudeController = TextEditingController(
    text: (initialAltitude ?? 0.0).toStringAsFixed(3),
  );

  try {
    final result = await showDialog<Map<String, dynamic>>(
      context: hostContext,
      builder: (dialogContext) {
        final media = MediaQuery.of(dialogContext);
        final availableHeight = media.size.height -
            media.viewInsets.vertical -
            media.padding.vertical;
        final maxContentHeight =
            (availableHeight * 0.48).clamp(170.0, 320.0).toDouble();

        return AlertDialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          title: const Text('Position mock Merchich'),
          content: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxContentHeight),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: xController,
                    scrollPadding: const EdgeInsets.only(bottom: 96),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'X Merchich (m)',
                      hintText: 'Ex: 228580.000',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: yController,
                    scrollPadding: const EdgeInsets.only(bottom: 96),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Y Merchich (m)',
                      hintText: 'Ex: 118670.000',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: altitudeController,
                    scrollPadding: const EdgeInsets.only(bottom: 120),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Z / altitude (m)',
                      hintText: 'Ex: 500.000',
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop({
                'action': 'read_gnss',
              }),
              icon: const Icon(Icons.gps_fixed, size: 18),
              label: const Text('Lire GPS/GNSS'),
            ),
            TextButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop({
                'action': 'nmea_bridge',
              }),
              icon: const Icon(Icons.settings_input_antenna, size: 18),
              label: const Text('Pont NMEA'),
            ),
            if (state.homeController.isMockLocationEnabled)
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop({
                  'action': 'clear',
                }),
                child: const Text('Revenir au GPS reel'),
              ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop({
                  'action': 'apply',
                  'x': double.tryParse(
                    xController.text.trim().replaceAll(',', '.'),
                  ),
                  'y': double.tryParse(
                    yController.text.trim().replaceAll(',', '.'),
                  ),
                  'altitude': double.tryParse(
                    altitudeController.text.trim().replaceAll(',', '.'),
                  ),
                });
              },
              child: const Text('Appliquer'),
            ),
          ],
        );
      },
    );

    if (!state.mounted || result == null) return;

    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!state.mounted) return;

    final action = (result['action'] ?? '').toString();

    if (action == 'nmea_bridge') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!state.mounted) return;
        unawaited(_showNmeaBridgeDialog(state, messenger));
      });
      return;
    }

    if (action == 'read_gnss') {
      try {
        final bridge = NmeaBridgeService();
        final bridgeStatus = await bridge.getStatus();
        final appliedExternal = _applyNmeaBridgeFixToMapImpl(
          state,
          bridgeStatus,
        );
        if (appliedExternal) {
          final position = state.homeController.userPosition;
          messenger?.showSnackBar(
            SnackBar(
              content: Text(
                'GNSS externe lu: X=${position.longitude.toStringAsFixed(3)}, '
                'Y=${position.latitude.toStringAsFixed(3)}',
              ),
              backgroundColor: Colors.teal,
            ),
          );
          return;
        }

        final expectingExternal =
            state.homeController.gpsSourceLabel.startsWith('GNSS') ||
                bridgeStatus.status.toLowerCase().contains('bluetooth') ||
                bridgeStatus.status.toLowerCase().contains('nmea');
        if (expectingExternal) {
          messenger?.showSnackBar(
            SnackBar(
              content: const Text(
                'Pont NMEA actif mais aucun fix GNSS externe recu. '
                'Aucune position telephone utilisee.',
              ),
              backgroundColor: Colors.orange.shade800,
            ),
          );
          return;
        }
      } catch (_) {
        // Fallback to phone GNSS when the NMEA bridge is unavailable.
      }

      final enriched = await state.homeController.refreshFromDeviceGps();
      if (!state.mounted) return;

      final lat = enriched?.raw.latitude;
      final lon = enriched?.raw.longitude;
      if (enriched == null || lat == null || lon == null) {
        messenger?.showSnackBar(
          const SnackBar(
            content: Text('Position GPS/GNSS indisponible.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final gnssPosition = LatLng(lat, lon);
      if (state._mapController != null) {
        state._mapController!.move(
          state._mapPointForActiveMap(gnssPosition),
          17,
        );
        state._lastCameraPosition = gnssPosition;
      }

      final altitude = enriched.raw.altitude;
      final zText = altitude == null
          ? 'Z non disponible'
          : 'Z=${altitude.toStringAsFixed(2)} m';
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            'GNSS lu: X=${enriched.merchichX.toStringAsFixed(2)}, '
            'Y=${enriched.merchichY.toStringAsFixed(2)}, $zText',
          ),
          backgroundColor: Colors.teal,
        ),
      );
      return;
    }

    if (action == 'clear') {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!state.mounted) return;

        await state.homeController.clearMockPosition();
        if (!state.mounted) return;
        final restoredPosition = state.homeController.userPosition;
        if (state._mapController != null) {
          state._mapController!.move(
            state._mapPointForActiveMap(restoredPosition),
            17,
          );
          state._lastCameraPosition = restoredPosition;
        }
        messenger?.showSnackBar(
          const SnackBar(
            content: Text('Mock GPS desactive'),
            backgroundColor: Colors.blueGrey,
          ),
        );
      });
      return;
    }

    final x = result['x'] as double?;
    final y = result['y'] as double?;
    final altitude = result['altitude'] as double?;

    if (x == null || y == null || altitude == null) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('X, Y ou Z invalide'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!state.mounted) return;
      try {
        state.homeController.setMockMerchichPosition(
          x: x,
          y: y,
          altitude: altitude,
        );
        final wgs84 = ProjectionService().merchichToWgs84(x: x, y: y);
        final mockPosition = state._shouldUseOnlineBasemap
            ? LatLng(wgs84.latitude, wgs84.longitude)
            : LatLng(y, x);
        if (state._mapController != null) {
          state._mapController!.move(
            state._mapPointForActiveMap(mockPosition),
            17,
          );
          state._lastCameraPosition = mockPosition;
        }
        messenger?.showSnackBar(
          SnackBar(
            content: Text(
              'Mock GPS applique: X=${x.toStringAsFixed(3)}, Y=${y.toStringAsFixed(3)}, Z=${altitude.toStringAsFixed(3)} m',
            ),
            backgroundColor: Colors.teal,
          ),
        );
      } catch (e) {
        messenger?.showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  } finally {
    xController.dispose();
    yController.dispose();
    altitudeController.dispose();
  }
}

Future<void> _showNmeaBridgeDialog(
  _HomePageState state,
  ScaffoldMessengerState? messenger,
) async {
  final bridge = NmeaBridgeService();
  final nmeaController = TextEditingController(
    text:
        r'$GPGGA,120000.00,3441.0000,N,00154.0000,W,4,12,0.8,500.0,M,0.0,M,,*00',
  );

  var status = const NmeaBridgeStatus(
    status: 'chargement',
    mockLocationSelected: false,
  );
  var devices = <NmeaBridgeDevice>[];
  String? loadError;
  var isLoadingDevices = false;
  var didScheduleInitialLoad = false;

  try {
    status = await bridge.getStatus();
    final preferred = await bridge.getPreferredBluetoothDevice();
    if (preferred != null) {
      devices = [preferred];
    }
  } catch (e) {
    loadError = _friendlyNmeaBridgeError(e);
  }

  try {
    if (!state.mounted) return;
    await showDialog<void>(
      context: state.context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> loadBluetoothDevices() async {
              setDialogState(() {
                isLoadingDevices = true;
                loadError = null;
              });
              try {
                if (Platform.isAndroid) {
                  await Permission.bluetoothConnect.request();
                  await Permission.bluetoothScan.request();
                }
                final loadedStatus = await bridge.getStatus();
                final loadedDevices = await bridge.listBondedBluetoothDevices();
                if (!dialogContext.mounted) return;
                setDialogState(() {
                  status = loadedStatus;
                  devices = loadedDevices;
                  isLoadingDevices = false;
                });
              } catch (e) {
                if (!dialogContext.mounted) return;
                setDialogState(() {
                  loadError = _friendlyNmeaBridgeError(e);
                  isLoadingDevices = false;
                });
              }
            }

            if (!didScheduleInitialLoad) {
              didScheduleInitialLoad = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!dialogContext.mounted) return;
                unawaited(loadBluetoothDevices());
              });
            }

            return AlertDialog(
              title: const Text('Pont NMEA GNSS'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.settings_input_antenna,
                          color: Colors.indigo,
                        ),
                        title: const Text('Configurer antenne rover'),
                        subtitle: Builder(
                          builder: (_) {
                            final c = state.homeController.currentRoverConfig;
                            final method = switch (c.surveyType) {
                              AntennaSurveyType.vertical => 'Vertical',
                              AntennaSurveyType.slant => 'Slant',
                              AntennaSurveyType.phaseCenter => 'Phase Ctr',
                            };
                            return Text(
                              '${c.antenna.displayName} : '
                              '${c.heightMeters.toStringAsFixed(3)} m '
                              '($method) / ${c.verticalAdjustment.displayName}',
                              style: const TextStyle(fontSize: 11.5),
                            );
                          },
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () async {
                          await GnssRoverSetupDialog.show(
                            dialogContext,
                            homeController: state.homeController,
                          );
                          setDialogState(() {});
                        },
                      ),
                      const Divider(height: 16),
                      Text(
                        state._canUseAdminGpsTools
                            ? (status.mockLocationSelected
                                ? 'SRM Collecte est selectionnee comme app de position fictive.'
                                : 'Selectionnez SRM Collecte comme app de position fictive Android.')
                            : 'Lecture directe du recepteur GNSS. La position fictive Android est reservee aux administrateurs.',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: state._canUseAdminGpsTools
                              ? (status.mockLocationSelected
                                  ? Colors.green.shade700
                                  : Colors.orange.shade800)
                              : Colors.indigo.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Etat du pont : ${status.status}'),
                      if (isLoadingDevices) ...[
                        const SizedBox(height: 8),
                        const LinearProgressIndicator(),
                      ],
                      if (loadError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          loadError ?? '',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                      const SizedBox(height: 12),
                      const Text(
                        'Appareils Bluetooth appaires',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      if (devices.isEmpty)
                        const Text(
                          'Chargement automatique des appareils appaires en cours.',
                        )
                      else
                        ...devices.map(
                          (device) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.bluetooth),
                            title: Text(_nmeaDeviceTitle(device)),
                            subtitle: Text(device.address),
                            onTap: () async {
                              try {
                                await bridge
                                    .savePreferredBluetoothDevice(device);
                                await bridge.connectBluetooth(device.address);
                                state.homeController.markNmeaBridgePending(
                                  deviceLabel: device.label,
                                );
                                _startNmeaBridgeWatchImpl(state);
                                unawaited(
                                  _centerOnNmeaFirstFixImpl(state, bridge),
                                );
                                if (dialogContext.mounted) {
                                  Navigator.of(dialogContext).pop();
                                }
                                messenger?.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Connexion pont NMEA lancee vers ${device.label}',
                                    ),
                                    backgroundColor: Colors.teal,
                                  ),
                                );
                              } catch (e) {
                                messenger?.showSnackBar(
                                  SnackBar(
                                    content: Text(_friendlyNmeaBridgeError(e)),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      if (state._canUseAdminGpsTools) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: nmeaController,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Test manuel NMEA GGA/RMC',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                if (state._canUseAdminGpsTools)
                  TextButton(
                    onPressed: () => bridge.openMockLocationSettings(),
                    child: const Text('Options mock'),
                  ),
                TextButton(
                  onPressed: () => bridge.openBluetoothSettings(),
                  child: const Text('Bluetooth'),
                ),
                TextButton(
                  onPressed: isLoadingDevices
                      ? null
                      : () => unawaited(loadBluetoothDevices()),
                  child: const Text('Verifier'),
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      await bridge.disconnectBluetooth();
                      messenger?.showSnackBar(
                        const SnackBar(
                          content: Text('Pont NMEA deconnecte.'),
                          backgroundColor: Colors.blueGrey,
                        ),
                      );
                    } catch (_) {
                      // Ignore disconnect errors.
                    }
                  },
                  child: const Text('Deconnecter'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Fermer'),
                ),
                if (state._canUseAdminGpsTools)
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        final pushed =
                            await bridge.pushNmea(nmeaController.text);
                        final currentStatus = await bridge.getStatus();
                        _applyNmeaBridgeFixToMapImpl(state, currentStatus);
                        final lat = pushed['latitude'];
                        final lon = pushed['longitude'];
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                        messenger?.showSnackBar(
                          SnackBar(
                            content: Text('NMEA injecte: $lat, $lon'),
                            backgroundColor: Colors.teal,
                          ),
                        );
                      } catch (e) {
                        messenger?.showSnackBar(
                          SnackBar(
                            content: Text(_friendlyNmeaBridgeError(e)),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    child: const Text('Injecter'),
                  ),
              ],
            );
          },
        );
      },
    );
  } finally {
    nmeaController.dispose();
  }
}

String _nmeaDeviceTitle(NmeaBridgeDevice device) {
  final name = device.name?.trim();
  return name != null && name.isNotEmpty ? name : device.address;
}

String _friendlyNmeaBridgeError(Object error) {
  final message = error is PlatformException
      ? (error.message ?? error.code)
      : error.toString();
  if (message.contains('position fictive') ||
      message.contains('MOCK') ||
      message.contains('mock')) {
    return 'Sélectionnez SRM Collecte dans Options développeur > Application de position fictive.';
  }
  if (message.contains('BLUETOOTH') || message.contains('Bluetooth')) {
    return 'Autorisez Bluetooth et appairez le recepteur GNSS dans les paramètres Android.';
  }
  return message;
}
