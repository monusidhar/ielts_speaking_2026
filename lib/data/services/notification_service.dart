import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../repositories/prefs_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FILE LOCATION: lib/data/services/notification_service.dart
//
// Local push notifications for daily practice reminders.
// No server needed — uses flutter_local_notifications package.
// ─────────────────────────────────────────────────────────────────────────────

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Call once in main() after PrefsRepository.init()
  static Future<void> init() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _plugin.initialize(settings);
    _initialized = true;

    // Schedule daily reminder if enabled
    if (PrefsRepository.isNotificationsEnabled()) {
      await scheduleDailyReminder();
    }
  }

  /// Request notification permission (call from settings UI)
  static Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted =
          await ios.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }
    return false;
  }

  /// Schedule a daily reminder at 9:00 AM
  static Future<void> scheduleDailyReminder() async {
    await _plugin.cancelAll();

    final streak = PrefsRepository.getStreakCount();
    final hasPracticed = PrefsRepository.hasPracticedToday();

    String title;
    String body;
    if (streak > 0 && !hasPracticed) {
      title = 'Don\'t lose your $streak-day streak! 🔥';
      body = 'Practice now to keep your streak alive.';
    } else if (streak > 0) {
      title = 'Keep your $streak-day streak going! 🔥';
      body = 'New daily AI question is ready for you.';
    } else {
      title = 'Time to practice speaking! 🎯';
      body = 'Spend 5 minutes today and start a streak.';
    }

    const androidDetails = AndroidNotificationDetails(
      'daily_reminder',
      'Daily Practice Reminder',
      channelDescription: 'Reminds you to practice IELTS speaking daily',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );
    const details = NotificationDetails(android: androidDetails);

    // Schedule for next 9 AM
    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, 9, 0);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    // Use a periodic approach: show notification now if after 9 AM & not practiced
    // Then use daily repeat
    await _plugin.periodicallyShow(
      0,
      title,
      body,
      RepeatInterval.daily,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Cancel all notifications
  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// Enable or disable notifications
  static Future<void> setEnabled(bool enabled) async {
    await PrefsRepository.setNotificationsEnabled(enabled);
    if (enabled) {
      await requestPermission();
      await scheduleDailyReminder();
    } else {
      await cancelAll();
    }
  }

  /// Call after any practice to update notification content
  static Future<void> onPracticeCompleted() async {
    if (!PrefsRepository.isNotificationsEnabled()) return;
    await scheduleDailyReminder(); // Reschedule with updated streak info
  }
}
