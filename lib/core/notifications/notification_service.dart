import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/habit.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'habit_reminders';
  static const String _channelName = 'Habit Reminders';
  static const String _channelDescription =
      'Daily reminders for the habits you choose.';

  static const int _testNotificationId = 2000000000;

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    _channelId,
    _channelName,
    channelDescription: _channelDescription,
    importance: Importance.high,
    priority: Priority.high,
    enableVibration: true,
  );

  static const NotificationDetails _notificationDetails = NotificationDetails(
    android: _androidDetails,
    iOS: DarwinNotificationDetails(),
  );

  static bool _initialized = false;
  static bool _available = true;
  static Future<void>? _initFuture;

  static bool _timeZonesInitialized = false;
  static Future<void>? _timeZonesInitFuture;

  static Future<void> initialize() async {
    if (_initialized) return;
    final existing = _initFuture;
    if (existing != null) return existing;

    final future = _initializeInternal();
    _initFuture = future;
    return future;
  }

  static Future<void> _initializeInternal() async {
    try {
      const initializationSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );

      await _plugin.initialize(settings: initializationSettings);

      // Ensure the Android notification channel exists.
      final android = _androidPlugin();
      if (android != null) {
        const channel = AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.high,
        );
        await android.createNotificationChannel(channel);
      }

      _available = true;
    } catch (e) {
      _available = false;
      if (kDebugMode) {
        debugPrint('NotificationService init failed: $e');
      }
    } finally {
      _initialized = true;
      _initFuture = null;
    }
  }

  static AndroidFlutterLocalNotificationsPlugin? _androidPlugin() {
    try {
      return _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
    } catch (_) {
      return null;
    }
  }

  static Future<void> _ensureTimeZonesInitialized() async {
    if (_timeZonesInitialized) return;
    final existing = _timeZonesInitFuture;
    if (existing != null) return existing;

    final future = _initializeTimeZonesInternal();
    _timeZonesInitFuture = future;
    return future;
  }

  static Future<void> _initializeTimeZonesInternal() async {
    try {
      tzdata.initializeTimeZones();
      try {
        final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
        final timeZoneId = timeZoneInfo.identifier;
        tz.setLocalLocation(tz.getLocation(timeZoneId));
      } catch (_) {
        tz.setLocalLocation(tz.UTC);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Timezone init failed: $e');
      }
      try {
        tz.setLocalLocation(tz.UTC);
      } catch (_) {}
    } finally {
      _timeZonesInitialized = true;
      _timeZonesInitFuture = null;
    }
  }

  static Future<String> currentTimeZoneName() async {
    await _ensureTimeZonesInitialized();
    return tz.local.name;
  }

  static Future<bool> requestNotificationsPermission() async {
    await initialize();
    if (!_available) return false;

    final android = _androidPlugin();
    if (android == null) return true;

    try {
      final alreadyEnabled = await android.areNotificationsEnabled();
      if (alreadyEnabled == true) return true;
    } catch (_) {
      // Continue to request permission.
    }

    try {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool?> areNotificationsEnabled() async {
    await initialize();
    if (!_available) return null;
    final android = _androidPlugin();
    if (android == null) return true;

    try {
      return await android.areNotificationsEnabled();
    } catch (_) {
      return null;
    }
  }

  static Future<bool?> canScheduleExactNotifications() async {
    await initialize();
    if (!_available) return null;
    final android = _androidPlugin();
    if (android == null) return null;
    try {
      return await android.canScheduleExactNotifications();
    } catch (_) {
      return null;
    }
  }

  static Future<bool?> requestExactAlarmsPermission() async {
    await initialize();
    if (!_available) return null;
    final android = _androidPlugin();
    if (android == null) return null;
    try {
      return await android.requestExactAlarmsPermission();
    } catch (_) {
      return null;
    }
  }

  static Future<void> showTestNotification() async {
    await initialize();
    if (!_available) return;
    try {
      await _plugin.show(
        id: _testNotificationId,
        title: 'Atobits reminder test',
        body: 'If you see this, notifications are working on this device.',
        notificationDetails: _notificationDetails,
        payload: jsonEncode({'type': 'test'}),
      );
    } catch (_) {
      // Ignore.
    }
  }

  static Future<void> scheduleTestNotification({
    Duration delay = const Duration(seconds: 15),
  }) async {
    await initialize();
    if (!_available) return;
    await _ensureTimeZonesInitialized();

    final scheduled = tz.TZDateTime.now(tz.local).add(delay);

    final preferredMode = await _preferredAndroidScheduleMode();
    try {
      await _plugin.zonedSchedule(
        id: _testNotificationId,
        title: 'Atobits reminder test',
        body: 'This was scheduled ${delay.inSeconds}s ago.',
        scheduledDate: scheduled,
        notificationDetails: _notificationDetails,
        androidScheduleMode: preferredMode,
        payload: jsonEncode({'type': 'test'}),
      );
    } catch (_) {
      await _plugin.zonedSchedule(
        id: _testNotificationId,
        title: 'Atobits reminder test',
        body: 'This was scheduled ${delay.inSeconds}s ago.',
        scheduledDate: scheduled,
        notificationDetails: _notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: jsonEncode({'type': 'test'}),
      );
    }
  }

  static int _snoozeNotificationIdForHabit(String habitId) {
    // Derive a stable, unique ID without colliding with the main reminder.
    return _notificationIdForHabit('snooze_$habitId');
  }

  /// Schedule a one-off nudge for this habit after a short delay ("snooze").
  ///
  /// This does NOT replace the daily reminder schedule; it's an extra reminder
  /// used for "remind me in 30 min".
  static Future<void> scheduleSnoozeForHabit(
    Habit habit, {
    Duration delay = const Duration(minutes: 30),
  }) async {
    await initialize();
    if (!_available) return;
    await _ensureTimeZonesInitialized();

    final id = _snoozeNotificationIdForHabit(habit.id);
    try {
      await _plugin.cancel(id: id);
    } catch (_) {}

    final scheduled = tz.TZDateTime.now(tz.local).add(delay);
    final preferredMode = await _preferredAndroidScheduleMode();

    final title = habit.title;
    final body = _buildBody(habit);

    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: _notificationDetails,
        androidScheduleMode: preferredMode,
        payload: jsonEncode({
          'type': 'habit_snooze',
          'habitId': habit.id,
          'delaySeconds': delay.inSeconds,
        }),
      );
    } catch (_) {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: _notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: jsonEncode({
          'type': 'habit_snooze',
          'habitId': habit.id,
          'delaySeconds': delay.inSeconds,
        }),
      );
    }
  }

  static Future<void> cancelTestNotification() async {
    await initialize();
    if (!_available) return;
    try {
      await _plugin.cancel(id: _testNotificationId);
    } catch (_) {
      // Ignore.
    }
  }

  static Future<int> pendingNotificationsCount() async {
    await initialize();
    if (!_available) return 0;
    try {
      final pending = await _plugin.pendingNotificationRequests();
      return pending.length;
    } catch (_) {
      return 0;
    }
  }

  static Future<List<PendingNotificationRequest>>
      pendingNotificationRequests() async {
    await initialize();
    if (!_available) return <PendingNotificationRequest>[];
    try {
      return _plugin.pendingNotificationRequests();
    } catch (_) {
      return <PendingNotificationRequest>[];
    }
  }

  static Future<String> preferredScheduleModeLabel() async {
    await initialize();
    if (!_available) return 'unavailable';

    final android = _androidPlugin();
    if (android == null) return 'n/a';

    try {
      final canExact = await android.canScheduleExactNotifications();
      if (canExact == false) return 'alarmClock (fallback)';
      return 'exactAllowWhileIdle';
    } catch (_) {
      return 'unknown';
    }
  }

  static Future<DateTime?> nextTriggerForHabit(Habit habit) async {
    await initialize();
    if (!habit.reminderEnabled) return null;

    await _ensureTimeZonesInitialized();

    final (hour, minute) = _resolveReminderTime(habit);
    return _nextInstanceOfTime(hour, minute);
  }

  static Future<void> upsertHabitReminder(
    Habit habit, {
    bool requestPermission = false,
  }) async {
    await initialize();
    if (!_available) return;

    if (!habit.reminderEnabled) {
      await cancelHabitReminder(habit.id);
      return;
    }

    if (requestPermission) {
      await requestNotificationsPermission();
      // Android 14+ may require explicit user permission for exact alarms.
      final canExact = await canScheduleExactNotifications();
      if (canExact == false) {
        await requestExactAlarmsPermission();
      }
    }

    await _ensureTimeZonesInitialized();
    await _scheduleDailyHabitReminder(habit);
  }

  static Future<void> cancelHabitReminder(String habitId) async {
    await initialize();
    if (!_available) return;
    try {
      await _plugin.cancel(id: _notificationIdForHabit(habitId));
    } catch (_) {
      // Ignore.
    }
  }

  static Future<void> rescheduleAllHabits(List<Habit> habits) async {
    await initialize();
    if (!_available) return;
    await _ensureTimeZonesInitialized();

    for (final habit in habits) {
      if (habit.reminderEnabled) {
        await _scheduleDailyHabitReminder(habit);
      } else {
        await cancelHabitReminder(habit.id);
      }
    }
  }

  static Future<void> _scheduleDailyHabitReminder(Habit habit) async {
    await _ensureTimeZonesInitialized();
    final (hour, minute) = _resolveReminderTime(habit);

    final scheduled = _nextInstanceOfTime(hour, minute);

    final preferredMode = await _preferredAndroidScheduleMode();

    final title = habit.title;
    final body = _buildBody(habit);

    final id = _notificationIdForHabit(habit.id);

    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: _notificationDetails,
        androidScheduleMode: preferredMode,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: jsonEncode({
          'type': 'habit',
          'habitId': habit.id,
          'hm': habit.reminderTime,
          'timeOfDay': habit.timeOfDay,
        }),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Exact schedule failed ($e). Falling back to inexact.');
      }

      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: _notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: jsonEncode({
          'type': 'habit',
          'habitId': habit.id,
          'hm': habit.reminderTime,
          'timeOfDay': habit.timeOfDay,
        }),
      );
    }
  }

  static Future<AndroidScheduleMode> _preferredAndroidScheduleMode() async {
    final android = _androidPlugin();
    if (android == null) return AndroidScheduleMode.exactAllowWhileIdle;

    bool? canExact;
    try {
      canExact = await android.canScheduleExactNotifications();
    } catch (_) {
      canExact = null;
    }
    // When exact alarms are blocked, try alarmClock scheduling (more reliable on
    // many devices) and fall back to inexact if it throws.
    if (canExact == false) return AndroidScheduleMode.alarmClock;

    return AndroidScheduleMode.exactAllowWhileIdle;
  }

  static String _buildBody(Habit habit) {
    final time = habit.timeOfDay.trim().toLowerCase();
    if (time.isEmpty || time == 'anytime') {
      return 'A gentle reminder: ${habit.title}.';
    }

    return 'It\'s time for your $time habit: ${habit.title}.';
  }

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  static (int, int) _resolveReminderTime(Habit habit) {
    final parsed = _parseHm(habit.reminderTime);
    if (parsed != null) return parsed;

    switch (habit.timeOfDay.trim().toLowerCase()) {
      case 'morning':
        return (8, 0);
      case 'afternoon':
        return (13, 0);
      case 'evening':
        return (19, 0);
      case 'night':
        return (21, 0);
      default:
        return (9, 0);
    }
  }

  static (int, int)? _parseHm(String? value) {
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23) return null;
    if (minute < 0 || minute > 59) return null;

    return (hour, minute);
  }

  static int _notificationIdForHabit(String habitId) {
    final parsed = int.tryParse(habitId);
    if (parsed != null) {
      return (parsed % 2147483647).abs();
    }

    // Stable FNV-1a hash to map string ids into a 31-bit int.
    const int fnvOffset = 0x811C9DC5;
    const int fnvPrime = 0x01000193;

    var hash = fnvOffset;
    for (final b in utf8.encode(habitId)) {
      hash ^= b;
      hash = (hash * fnvPrime) & 0x7fffffff;
    }

    return hash.abs();
  }
}
