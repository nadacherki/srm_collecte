import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class DownloadNotificationService {
  const DownloadNotificationService._();

  static const MethodChannel _channel =
      MethodChannel('com.srm.collecte/download_notification');

  static DateTime? _lastUpdateAt;
  static int? _lastProgress;
  static String? _lastOperation;

  static Future<void> start({
    String title = 'Téléchargement SRM',
    String text = 'Préparation du téléchargement...',
  }) async {
    if (!Platform.isAndroid) return;
    await _ensureNotificationPermission();
    await _invokeSafely('startDownloadNotification', {
      'title': title,
      'text': text,
      'progress': 0,
      'indeterminate': false,
    });
    _lastUpdateAt = null;
    _lastProgress = null;
    _lastOperation = null;
  }

  static void update({
    required double progress,
    required String operation,
    required int processed,
    required int total,
    String title = 'Téléchargement en cours',
  }) {
    if (!Platform.isAndroid) return;

    final safeProgress =
        progress.isNaN || progress.isInfinite ? 0.0 : progress.clamp(0.0, 1.0);
    final percent = (safeProgress * 100).round();
    final now = DateTime.now();
    final operationChanged = operation != _lastOperation;
    final progressChanged = percent != _lastProgress;
    final enoughTimePassed = _lastUpdateAt == null ||
        now.difference(_lastUpdateAt!) >= const Duration(milliseconds: 700);

    if (!operationChanged && !progressChanged && !enoughTimePassed) return;

    _lastUpdateAt = now;
    _lastProgress = percent;
    _lastOperation = operation;

    unawaited(_invokeSafely('updateDownloadNotification', {
      'title': title,
      'text': '$operation ($processed/$total)',
      'progress': percent,
      'indeterminate': total <= 0,
    }));
  }

  static Future<void> complete({
    String title = 'Téléchargement terminé',
    String text = 'Téléchargement terminé',
  }) async {
    if (!Platform.isAndroid) return;
    await _invokeSafely('finishDownloadNotification', {
      'title': title,
      'text': text,
      'progress': 100,
      'indeterminate': false,
    });
  }

  static Future<void> fail({
    String title = 'Téléchargement interrompu',
    String text = 'Téléchargement interrompu',
  }) async {
    if (!Platform.isAndroid) return;
    await _invokeSafely('failDownloadNotification', {
      'title': title,
      'text': text,
      'progress': _lastProgress ?? 0,
      'indeterminate': false,
    });
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    await _invokeSafely('stopDownloadNotification');
  }

  static Future<void> _ensureNotificationPermission() async {
    final status = await Permission.notification.status;
    if (status.isDenied || status.isRestricted) {
      await Permission.notification.request();
    }
  }

  static Future<void> _invokeSafely(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } catch (e) {
      debugPrint('[DOWNLOAD-NOTIF] $method ignoré: $e');
    }
  }
}
