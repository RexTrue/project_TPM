import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (kIsWeb) {
      return;
    }
    if (_initialized) {
      return;
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);
    try {
      await _plugin.initialize(settings: settings);
      _initialized = true;
    } catch (e) {
      debugPrint('[NotificationService] Notification init skipped: $e');
    }
  }

  Future<bool> showDailyReminderNow() async {
    return showAppNotification(
      id: 101,
      title: 'EduFun',
      body: 'Ayo belajar hari ini!',
      channelId: 'edufun_daily',
      channelName: 'Daily Reminder',
      channelDescription: 'Pengingat belajar harian EduFun',
    );
  }

  Future<bool> requestPermission() async {
    if (kIsWeb) {
      return false;
    }
    if (!_initialized) {
      await initialize();
    }
    return _requestPermission();
  }

  Future<bool> showAppNotification({
    required int id,
    required String title,
    required String body,
    String channelId = 'edufun_updates',
    String channelName = 'EduFun Updates',
    String channelDescription = 'Update terbaru dari EduFun',
  }) async {
    if (kIsWeb) {
      return false;
    }

    if (!_initialized) {
      await initialize();
    }

    final allowed = await _requestPermission();
    if (!allowed) {
      return false;
    }

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
    return true;
  }

  Future<bool> _requestPermission() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      final enabled = await androidPlugin.areNotificationsEnabled();
      if (enabled ?? false) {
        return true;
      }

      final granted = await androidPlugin.requestNotificationsPermission();
      return granted ?? false;
    }

    final iosPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (iosPlugin != null) {
      final granted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return true;
  }
}
