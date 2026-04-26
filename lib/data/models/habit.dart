import '../../core/theme/habit_icon_registry.dart';

class Habit {
  final String id;
  final String title;
  final String description;
  final String category;
  final String emoji;
  final String timeOfDay;
  final bool reminderEnabled;
  final String? reminderTime;
  final DateTime createdAt;

  // Scheduling
  // scheduleType:
  // - daily
  // - weekdays (specific days of week)
  // - times_per_week (goal-based)
  // - interval (every N days)
  final String scheduleType;
  final List<int> scheduleDaysOfWeek;
  final int scheduleTimesPerWeek;
  final int scheduleIntervalDays;
  final DateTime? scheduleAnchorDate;

  Habit({
    String? id,
    required this.title,
    this.description = '',
    required this.category,
    required this.emoji,
    required this.timeOfDay,
    this.reminderEnabled = false,
    this.reminderTime,
    DateTime? createdAt,

    // Scheduling
    this.scheduleType = 'daily',
    List<int>? scheduleDaysOfWeek,
    this.scheduleTimesPerWeek = 3,
    this.scheduleIntervalDays = 1,
    this.scheduleAnchorDate,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        scheduleDaysOfWeek = List<int>.unmodifiable(
          (scheduleDaysOfWeek ?? const <int>[]).where((d) => d >= 1 && d <= 7),
        ),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'emoji': emoji,
      'timeOfDay': timeOfDay,
      'reminderEnabled': reminderEnabled,
      'reminderTime': reminderTime,
      'createdAt': createdAt.toIso8601String(),
      'scheduleType': scheduleType,
      'scheduleDaysOfWeek': scheduleDaysOfWeek,
      'scheduleTimesPerWeek': scheduleTimesPerWeek,
      'scheduleIntervalDays': scheduleIntervalDays,
      'scheduleAnchorDate': scheduleAnchorDate?.toIso8601String(),
    };
  }

  factory Habit.fromJson(Map<String, dynamic> json) {
    final daysRaw = json['scheduleDaysOfWeek'];
    final days = <int>[];
    if (daysRaw is List) {
      for (final v in daysRaw) {
        final i = v is int ? v : int.tryParse(v.toString());
        if (i == null) continue;
        if (i < 1 || i > 7) continue;
        days.add(i);
      }
    }

    DateTime? anchor;
    final anchorRaw = json['scheduleAnchorDate'];
    if (anchorRaw is String && anchorRaw.trim().isNotEmpty) {
      try {
        anchor = DateTime.parse(anchorRaw);
      } catch (_) {
        anchor = null;
      }
    }

    return Habit(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? '',
      category: json['category'],
      emoji: HabitIconRegistry.normalizeStored(json['emoji']),
      timeOfDay: json['timeOfDay'],
      reminderEnabled: json['reminderEnabled'] ?? false,
      reminderTime: (json['reminderTime'] ?? '').toString().trim().isEmpty
          ? null
          : (json['reminderTime'] ?? '').toString(),
      createdAt: DateTime.parse(json['createdAt']),
      scheduleType: (json['scheduleType'] ?? 'daily').toString(),
      scheduleDaysOfWeek: days,
      scheduleTimesPerWeek: (json['scheduleTimesPerWeek'] is int)
          ? (json['scheduleTimesPerWeek'] as int)
          : int.tryParse((json['scheduleTimesPerWeek'] ?? '3').toString()) ?? 3,
      scheduleIntervalDays: (json['scheduleIntervalDays'] is int)
          ? (json['scheduleIntervalDays'] as int)
          : int.tryParse((json['scheduleIntervalDays'] ?? '1').toString()) ?? 1,
      scheduleAnchorDate: anchor,
    );
  }

  Habit copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? emoji,
    String? timeOfDay,
    bool? reminderEnabled,
    String? reminderTime,
    DateTime? createdAt,
    String? scheduleType,
    List<int>? scheduleDaysOfWeek,
    int? scheduleTimesPerWeek,
    int? scheduleIntervalDays,
    DateTime? scheduleAnchorDate,
  }) {
    return Habit(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      emoji: emoji ?? this.emoji,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
      createdAt: createdAt ?? this.createdAt,
      scheduleType: scheduleType ?? this.scheduleType,
      scheduleDaysOfWeek: scheduleDaysOfWeek ?? this.scheduleDaysOfWeek,
      scheduleTimesPerWeek: scheduleTimesPerWeek ?? this.scheduleTimesPerWeek,
      scheduleIntervalDays: scheduleIntervalDays ?? this.scheduleIntervalDays,
      scheduleAnchorDate: scheduleAnchorDate ?? this.scheduleAnchorDate,
    );
  }
}
