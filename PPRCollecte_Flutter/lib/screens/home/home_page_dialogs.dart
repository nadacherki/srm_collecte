part of 'home_page.dart';

void _showSyncConfirmationDialogImpl(_HomePageState state) {
  showDialog(
    context: state.context,
    builder: (ctx) => AlertDialog(
      title: const Text('Confirmation de synchronisation'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Etes-vous sur de vouloir synchroniser vos donnees locales vers le serveur ?',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Non'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(ctx);
            state._performSync();
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
      final errorsToShow = result.errors.take(10).toList();
      final remaining = result.errors.length - errorsToShow.length;
      final warningsToShow = result.warnings.take(10).toList();
      final remainingWarnings = result.warnings.length - warningsToShow.length;

      final hasConnectionErrors = result.errors.any(
        (error) =>
            error.contains('connexion perdue') ||
            error.contains('serveur injoignable') ||
            error.contains('Timeout') ||
            error.contains('reseau'),
      );

      final String title;
      final IconData titleIcon;
      final Color titleColor;

      if (result.failedCount == 0 &&
          result.warningCount == 0 &&
          result.successCount > 0) {
        title = 'Synchronisation reussie';
        titleIcon = Icons.check_circle;
        titleColor = Colors.green;
      } else if (result.failedCount == 0 && result.warningCount > 0) {
        title = 'Synchronisation terminee avec avertissements';
        titleIcon = Icons.info_outline;
        titleColor = Colors.orange;
      } else if (result.successCount > 0 && result.failedCount > 0) {
        title = 'Synchronisation partielle';
        titleIcon = Icons.warning_amber;
        titleColor = Colors.orange;
      } else if (result.successCount == 0 && result.failedCount > 0) {
        title = 'Synchronisation echouee';
        titleIcon = Icons.error;
        titleColor = Colors.red;
      } else {
        title = 'Aucune donnee a synchroniser';
        titleIcon = Icons.info;
        titleColor = Colors.blue;
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
              if (result.successCount > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${result.successCount} donnee(s) synchronisee(s)',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (result.failedCount > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${result.failedCount} donnee(s) non synchronisee(s)',
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
                    '${result.warningCount} avertissement(s) sur le journal local',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
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
                    'La connexion a ete interrompue pendant la synchronisation. Les donnees deja envoyees ont ete sauvegardees. Relancez la synchronisation pour envoyer le reste.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ] else if (result.failedCount > 0) ...[
                const SizedBox(height: 8),
                const Text(
                  'Verifiez votre connexion internet et reessayez.',
                ),
              ],
              if (errorsToShow.isNotEmpty && !hasConnectionErrors) ...[
                const SizedBox(height: 10),
                const Text(
                  'Details des erreurs :',
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
              state._loadDownloadedPoints();
              state._loadDownloadedLineOverlays();
              state._loadDownloadedSpecialLines();
            },
            child: const Text('OK'),
          ),
        ],
      );
    },
  );
}

void _showSaveConfirmationDialogImpl(_HomePageState state) {
  showDialog(
    context: state.context,
    builder: (ctx) => AlertDialog(
      title: const Text('Confirmation de telechargement'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Etes-vous sur de vouloir telecharger les donnees SRM depuis le serveur ?',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Non'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(ctx);
            state._performDownload();
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

      return AlertDialog(
        title: Text(
          alreadyDownloaded
              ? 'Aucune nouvelle donnee a telecharger'
              : nothingAvailable
                  ? 'Aucune donnee disponible'
                  : 'Telechargement termine',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (alreadyDownloaded) ...[
                const Text(
                  'Les donnees du serveur pour ce projet et cette mission sont deja telechargees ou deja a jour sur cet appareil.',
                ),
                const SizedBox(height: 8),
                const Text('Toutes les donnees etaient deja a jour.'),
              ],
              if (nothingAvailable) ...[
                const Text(
                  'Aucune donnee n a ete trouvee sur le serveur pour votre compte.',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Causes possibles :\n- Aucune donnee n est encore associee a votre zone\n- Vos permissions ne sont pas encore configurees\n- Les donnees n ont pas encore ete collectees dans votre zone',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
              if (!nothingAvailable &&
                  !alreadyDownloaded &&
                  result.successCount > 0)
                Text('${result.successCount} nouvelles donnees telechargees'),
              if (!nothingAvailable && result.skippedCount > 0)
                Text('${result.skippedCount} donnees deja a jour'),
              if (result.failedCount > 0)
                Text(
                  '${result.failedCount} types de donnees n ont pas pu etre mis a jour',
                ),
              if (result.failedCount > 0) ...[
                const SizedBox(height: 8),
                const Text(
                  'Verifiez votre connexion internet ou reessayez plus tard.',
                ),
              ],
              if (errorsToShow.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text('Details des erreurs :'),
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
                    '- ... et $remaining autres problemes.',
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
              state._loadDownloadedPoints();
              state._loadDownloadedLineOverlays();
              state._loadDownloadedSpecialLines();
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
      title: const Text('Confirmation de deconnexion'),
      content: const Text(
        'Etes-vous sur de vouloir vous deconnecter ?',
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
  final latitudeController = TextEditingController(
    text: initialPosition.latitude.toStringAsFixed(6),
  );
  final longitudeController = TextEditingController(
    text: initialPosition.longitude.toStringAsFixed(6),
  );

  try {
    final result = await showDialog<Map<String, dynamic>>(
      context: hostContext,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Position GPS mock'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: latitudeController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Latitude',
                  hintText: 'Ex: 33.573110',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: longitudeController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Longitude',
                  hintText: 'Ex: -7.589843',
                ),
              ),
            ],
          ),
          actions: [
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
                  'lat': double.tryParse(
                    latitudeController.text.trim().replaceAll(',', '.'),
                  ),
                  'lon': double.tryParse(
                    longitudeController.text.trim().replaceAll(',', '.'),
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

    if (action == 'clear') {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!state.mounted) return;

        await state.homeController.clearMockPosition();
        if (!state.mounted) return;
        final restoredPosition = state.homeController.userPosition;
        if (state._mapController != null) {
          state._mapController!.move(restoredPosition, 17);
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

    final lat = result['lat'] as double?;
    final lon = result['lon'] as double?;

    if (lat == null || lon == null) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Latitude ou longitude invalide'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!state.mounted) return;

        state.homeController.setMockPosition(
          latitude: lat,
          longitude: lon,
        );
        final mockPosition = LatLng(lat, lon);
        if (state._mapController != null) {
          state._mapController!.move(mockPosition, 17);
          state._lastCameraPosition = mockPosition;
        }
        messenger?.showSnackBar(
          SnackBar(
            content: Text(
              'Mock GPS applique: ${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}',
            ),
            backgroundColor: Colors.teal,
          ),
        );
      });
    } catch (e) {
      if (!state.mounted) return;
      messenger?.showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    latitudeController.dispose();
    longitudeController.dispose();
  }
}
