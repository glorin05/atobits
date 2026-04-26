import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/notifications/notification_service.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    // Pick a good default immediately so the very first frame matches the
    // device theme (reduces perceived "black screen" / theme flash on launch).
    _isDarkMode =
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getBool('dark_mode');
    if (stored == null) return;
    if (stored == _isDarkMode) return;
    _isDarkMode = stored;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', _isDarkMode);
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', value);
    notifyListeners();
  }
}

class HabitProvider extends ChangeNotifier {
  List<Habit> _habits = [];
  List<HabitLog> _logs = [];

  List<Habit> get habits => _habits;
  List<HabitLog> get logs => _logs;

  HabitProvider() {
    // Defer loading until after the first frame so the Flutter splash can show ASAP.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    final habitsString = prefs.getString('habits');
    if (habitsString != null) {
      final List<dynamic> decoded = json.decode(habitsString);
      _habits = decoded.map((h) => Habit.fromJson(h)).toList();
    }

    final logsString = prefs.getString('logs');
    if (logsString != null) {
      final List<dynamic> decoded = json.decode(logsString);
      _logs = decoded
          .whereType<Map>()
          .map((l) => HabitLog.fromJson(Map<String, dynamic>.from(l)))
          .toList();

      // Migration: historically the app stored "not completed" rows.
      // In the new model we avoid persisting that state.
      _logs.removeWhere((l) => l.status == 'not_completed');

      // Migration: the app no longer supports skipping habits.
      _logs.removeWhere((l) => l.status == 'skipped');
    }

    notifyListeners();

    // Defer notification work so app can draw its first frame ASAP.
    final hasAnyReminder = _habits.any((h) => h.reminderEnabled);
    if (hasAnyReminder) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        NotificationService.rescheduleAllHabits(_habits);
      });
    }
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'habits', json.encode(_habits.map((h) => h.toJson()).toList()));
    await prefs.setString(
        'logs', json.encode(_logs.map((l) => l.toJson()).toList()));
  }

  Future<void> addHabit(Habit habit) async {
    _habits.add(habit);
    await saveData();
    await NotificationService.upsertHabitReminder(
      habit,
      requestPermission: true,
    );
    notifyListeners();
  }

  Future<void> deleteHabit(String habitId) async {
    _habits.removeWhere((h) => h.id == habitId);
    _logs.removeWhere((l) => l.habitId == habitId);
    await saveData();
    await NotificationService.cancelHabitReminder(habitId);
    notifyListeners();
  }

  Future<void> updateHabit(Habit habit) async {
    final index = _habits.indexWhere((h) => h.id == habit.id);
    if (index >= 0) {
      _habits[index] = habit;
      await saveData();
      await NotificationService.upsertHabitReminder(
        habit,
        requestPermission: true,
      );
      notifyListeners();
    }
  }

  void toggleHabitCompletion(String habitId, DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final existingLogIndex = _logs.indexWhere((l) =>
        l.habitId == habitId &&
        l.date.year == dateOnly.year &&
        l.date.month == dateOnly.month &&
        l.date.day == dateOnly.day);

    if (existingLogIndex >= 0) {
      final current = _logs[existingLogIndex];
      if (current.status == 'completed') {
        _logs.removeAt(existingLogIndex);
      } else {
        _logs[existingLogIndex] = HabitLog(
          habitId: habitId,
          date: dateOnly,
          status: 'completed',
          completedAt: DateTime.now(),
        );
      }
    } else {
      _logs.add(
        HabitLog(
          habitId: habitId,
          date: dateOnly,
          status: 'completed',
          completedAt: DateTime.now(),
        ),
      );
    }

    saveData();
    notifyListeners();
  }

  bool isCompletedOnDate(String habitId, DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return _logs.any((l) =>
        l.habitId == habitId &&
        l.date.year == d.year &&
        l.date.month == d.month &&
        l.date.day == d.day &&
        l.completed);
  }

  Habit? habitById(String habitId) {
    try {
      return _habits.firstWhere((h) => h.id == habitId);
    } catch (_) {
      return null;
    }
  }

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  DateTime _startOfWeek(DateTime d) {
    final date = _dateOnly(d);
    return date.subtract(Duration(days: date.weekday - 1));
  }

  bool isScheduledOnDate(Habit habit, DateTime date) {
    final d = _dateOnly(date);
    final type = habit.scheduleType.trim().toLowerCase();
    switch (type) {
      case 'weekdays':
        // If no days stored, assume Mon-Fri.
        final days = habit.scheduleDaysOfWeek.isEmpty
            ? const <int>[1, 2, 3, 4, 5]
            : habit.scheduleDaysOfWeek;
        return days.contains(d.weekday);
      case 'interval':
        final interval = habit.scheduleIntervalDays <= 0
            ? 1
            : habit.scheduleIntervalDays;
        final anchor = _dateOnly(habit.scheduleAnchorDate ?? habit.createdAt);
        final diff = d.difference(anchor).inDays;
        if (diff < 0) return false;
        return diff % interval == 0;
      case 'times_per_week':
        // Goal-based; any day counts.
        return true;
      case 'daily':
      default:
        return true;
    }
  }

  bool isDueOnDate(String habitId, DateTime date) {
    final habit = habitById(habitId);
    if (habit == null) return true;
    if (!isScheduledOnDate(habit, date)) return false;
    if (isCompletedOnDate(habitId, date)) return false;
    return true;
  }

  int getStreak(String habitId) {
    final habit = habitById(habitId);
    if (habit == null) return 0;

    final type = habit.scheduleType.trim().toLowerCase();
    final now = _dateOnly(DateTime.now());

    final habitLogs = _logs.where((l) => l.habitId == habitId).toList();
    final byDate = <DateTime, HabitLog>{
      for (final l in habitLogs) _dateOnly(l.date): l,
    };

    if (type == 'times_per_week') {
      final goal = habit.scheduleTimesPerWeek <= 0 ? 1 : habit.scheduleTimesPerWeek;
      var streakWeeks = 0;

      var weekStart = _startOfWeek(now);
      var guard = 0;
      while (guard++ < 520) {
        final weekEnd = weekStart.add(const Duration(days: 6));
        final completedThisWeek = habitLogs.where((l) {
          if (!l.completed) return false;
          final d = _dateOnly(l.date);
          return !d.isBefore(weekStart) && !d.isAfter(weekEnd);
        }).length;

        if (completedThisWeek >= goal) {
          streakWeeks++;
        } else {
          break;
        }

        weekStart = weekStart.subtract(const Duration(days: 7));
      }

      return streakWeeks;
    }

    var streak = 0;
    var day = now;
    var guard = 0;
    while (guard++ < 2500) {
      if (!isScheduledOnDate(habit, day)) {
        day = day.subtract(const Duration(days: 1));
        continue;
      }

      final log = byDate[day];
      if (log != null && log.completed) {
        streak++;
        day = day.subtract(const Duration(days: 1));
        continue;
      }

      break;
    }

    return streak;
  }

  int getTotalCompletions(String habitId) {
    return _logs.where((l) => l.habitId == habitId && l.completed).length;
  }
}
