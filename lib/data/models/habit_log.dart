class HabitLog {
  final String habitId;
  final DateTime date;
  final String status;
  final DateTime? completedAt;

  HabitLog({
    required this.habitId,
    required this.date,
    this.status = 'completed',
    this.completedAt,
  });

  bool get completed => status == 'completed';
  bool get skipped => status == 'skipped';

  Map<String, dynamic> toJson() {
    return {
      'habitId': habitId,
      'date': date.toIso8601String(),
      'status': status,
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory HabitLog.fromJson(Map<String, dynamic> json) {
    final statusRaw = (json['status'] ?? '').toString().trim();
    final legacyCompleted = json['completed'];
    final resolvedStatus = statusRaw.isNotEmpty
      ? statusRaw
      : (legacyCompleted == true
        ? 'completed'
        : (legacyCompleted == false ? 'not_completed' : 'completed'));

    DateTime? completedAt;
    final completedAtRaw = json['completedAt'];
    if (completedAtRaw is String && completedAtRaw.trim().isNotEmpty) {
      try {
        completedAt = DateTime.parse(completedAtRaw);
      } catch (_) {
        completedAt = null;
      }
    }

    return HabitLog(
      habitId: json['habitId'],
      date: DateTime.parse(json['date']),
      status: resolvedStatus,
      completedAt: completedAt,
    );
  }
}
