import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Thin wrapper around local notifications for scan progress + completion.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String channelId = 'pixelproof_scan';
  static const String channelName = 'Scan progress';
  static const int progressId = 1001;
  static const int completeId = 1002;

  bool _ready = false;

  /// Initializes the plugin and requests the Android 13+ notification permission.
  Future<void> init() async {
    if (_ready) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
    );

    final androidImpl =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        channelId,
        channelName,
        description: 'Shows progress while PixelProof scans your library',
        importance: Importance.low,
      ),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: false);

    _ready = true;
  }

  /// Shows / updates an ongoing progress notification with a determinate bar.
  Future<void> showProgress({
    required int processed,
    required int total,
  }) async {
    final details = AndroidNotificationDetails(
      channelId,
      channelName,
      channelShowBadge: false,
      importance: Importance.low,
      priority: Priority.low,
      onlyAlertOnce: true,
      ongoing: true,
      showProgress: true,
      maxProgress: total,
      progress: processed,
      indeterminate: total == 0,
    );
    await _plugin.show(
      id: progressId,
      title: 'Scanning your library',
      body: total == 0 ? 'Preparing…' : 'Analyzed $processed of $total',
      notificationDetails: NotificationDetails(android: details),
    );
  }

  /// Dismisses the progress notification.
  Future<void> cancelProgress() => _plugin.cancel(id: progressId);

  /// Shows the final summary notification.
  Future<void> showComplete({
    required int ai,
    required int real,
    required int uncertain,
  }) async {
    await cancelProgress();
    const details = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    await _plugin.show(
      id: completeId,
      title: 'Scan complete',
      body: '$ai AI · $real real · $uncertain uncertain',
      notificationDetails: const NotificationDetails(android: details),
    );
  }
}
