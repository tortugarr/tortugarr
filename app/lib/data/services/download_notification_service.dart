import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../util/platform_detection.dart';
import 'local_notification_bootstrap.dart';

class DownloadNotificationService {
  static const _channelId = 'moonfin_downloads';
  static const _channelName = 'Downloads';
  static const _channelDesc = 'Shows download progress for offline media';
  static const _progressNotificationId = 1000;
  static const _completionNotificationId = 1001;
  static const _remoteMessageNotificationId = 1002;

  FlutterLocalNotificationsPlugin get _plugin =>
      LocalNotificationBootstrap.instance.plugin;

  bool _initialized = false;
  DateTime _lastUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  bool _foregroundServiceRunning = false;
  String? _lastProgressSignature;

  Future<void>? _pendingNotification;

  Future<void> initialize() async {
    if (_initialized) return;

    await LocalNotificationBootstrap.instance.initialize();
    _initialized = true;

    if (PlatformDetection.isAndroid) {
      try {
        await _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      } catch (_) {}
    }
  }

  Future<void> showProgress({
    required String itemName,
    required double progress,
    int batchTotal = 0,
    int batchCompleted = 0,
  }) async {
    if (!_initialized) return;

    final percent = progress >= 0 ? (progress * 100).round() : -1;
    final batchInfo =
        batchTotal > 1 ? ' (${batchCompleted + 1}/$batchTotal)' : '';
    final title = 'Downloading$batchInfo';
    final body = percent >= 0 ? '$itemName - $percent%' : '$itemName...';
    final signature = '$title\n$body\n$percent';

    if (signature == _lastProgressSignature) {
      return;
    }

    final now = DateTime.now();
    if (now.difference(_lastUpdate).inMilliseconds < 1500) return;
    _lastUpdate = now;
    _lastProgressSignature = signature;

    final previous = _pendingNotification;
    final completer = Completer<void>();
    _pendingNotification = completer.future;

    try {
      if (previous != null) await previous;

      if (PlatformDetection.isAndroid) {
        await _showAndroidForegroundProgress(title, body, percent);
      } else {
        await _showStandardProgress(title, body, percent);
      }
    } catch (_) {
    } finally {
      completer.complete();
    }
  }

  Future<void> showComplete({
    required String itemName,
    int batchTotal = 0,
  }) async {
    if (!_initialized) return;
    _lastProgressSignature = null;
    await _stopForegroundService();

    final title = batchTotal > 1 ? 'Downloads complete' : 'Download complete';
    final body = batchTotal > 1
        ? '$batchTotal items saved for offline'
        : '$itemName saved for offline';
    await _showSimple(_completionNotificationId, title, body);
  }

  Future<void> showError({
    required String itemName,
    required String error,
  }) async {
    if (!_initialized) return;
    _lastProgressSignature = null;
    await _stopForegroundService();
    await _showSimple(_completionNotificationId, 'Download failed', '$itemName: $error');
  }

  Future<void> showRemoteMessage({
    required String text,
    String? header,
  }) async {
    if (!_initialized) return;
    final title = (header != null && header.trim().isNotEmpty)
        ? header.trim()
        : 'Remote message';
    final body = text.trim().isNotEmpty ? text.trim() : 'Message received';
    await _showSimple(_remoteMessageNotificationId, title, body);
  }

  Future<void> dismiss() async {
    if (!_initialized) return;
    _lastProgressSignature = null;
    await _stopForegroundService();
    await _plugin.cancel(id: _progressNotificationId);
  }

  Future<void> _showAndroidForegroundProgress(
      String title, String body, int percent) async {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showProgress: true,
      maxProgress: 100,
      progress: percent >= 0 ? percent : 0,
      indeterminate: percent < 0,
      category: AndroidNotificationCategory.progress,
    );

    final details = NotificationDetails(android: androidDetails);

    if (!_foregroundServiceRunning) {
      try {
        final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        await androidPlugin?.startForegroundService(
          id: _progressNotificationId,
          title: title,
          body: body,
          notificationDetails: androidDetails,
          foregroundServiceTypes: {
            AndroidServiceForegroundType.foregroundServiceTypeDataSync,
          },
        );
        _foregroundServiceRunning = true;
      } catch (_) {
        await _plugin.show(id: _progressNotificationId, title: title, body: body, notificationDetails: details);
      }
    } else {
      await _plugin.show(id: _progressNotificationId, title: title, body: body, notificationDetails: details);
    }
  }

  Future<void> _showStandardProgress(
      String title, String body, int percent) async {
    await _plugin.show(
      id: _progressNotificationId,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
        linux: LinuxNotificationDetails(),
      ),
    );
  }

  Future<void> _showSimple(int id, String title, String body) async {
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          autoCancel: true,
        ),
        iOS: const DarwinNotificationDetails(),
        macOS: const DarwinNotificationDetails(),
        linux: const LinuxNotificationDetails(),
      ),
    );
  }

  Future<void> _stopForegroundService() async {
    if (!_foregroundServiceRunning) return;
    try {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin
          ?.stopForegroundService()
          .timeout(const Duration(seconds: 5));
    } catch (_) {
    }
    _foregroundServiceRunning = false;
    try {
      await _plugin.cancel(id: _progressNotificationId)
          .timeout(const Duration(seconds: 5));
    } catch (_) {
    }
  }
}
