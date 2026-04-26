import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/habit_icon_registry.dart';
import '../../data/models/habit.dart';
import '../../data/providers/habit_provider.dart';
import '../edit_habit/edit_habit_screen.dart';

class HabitDetailScreen extends StatelessWidget {
  final Habit habit;
  const HabitDetailScreen({super.key, required this.habit});

  @override
  Widget build(BuildContext context) {
    final habitProvider = context.watch<HabitProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    final currentHabit = habitProvider.habitById(habit.id) ?? habit;
    final today = DateTime.now();
    final isCompletedToday = habitProvider.isCompletedOnDate(habit.id, today);
    final isScheduledToday = habitProvider.isScheduledOnDate(currentHabit, today);

    final bg = isDark ? AppThemeDark.background : AppTheme.background;
    final surface = isDark ? AppThemeDark.surface : AppTheme.surface;
    final primaryText =
        isDark ? AppThemeDark.primaryText : AppTheme.primaryText;
    final primaryBlue =
        isDark ? AppThemeDark.primaryBlue : AppTheme.primaryBlue;
    final border = isDark ? AppThemeDark.whisperBorder : AppTheme.whisperBorder;

    final streak = habitProvider.getStreak(habit.id);
    final total = habitProvider.getTotalCompletions(habit.id);
    final streakUnit =
      currentHabit.scheduleType.trim().toLowerCase() == 'times_per_week'
        ? 'weeks'
        : 'days';

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
            icon: Icon(Icons.arrow_back, color: primaryText),
            onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined, color: primaryBlue),
            onPressed: () {
              HapticFeedback.lightImpact();
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => EditHabitScreen(habit: habit),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Habit'),
                  content: Text('Delete "${currentHabit.title}"?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel')),
                    TextButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        habitProvider.deleteHabit(habit.id).then((_) {
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) Navigator.pop(context);
                        });
                      },
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                HabitIconRegistry.iconFromStored(currentHabit.emoji),
                size: 48,
                color: primaryBlue,
              ),
              const SizedBox(height: 16),
              Text(currentHabit.title,
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: primaryText)),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(currentHabit.category,
                    style: TextStyle(
                        color: primaryBlue, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        habitProvider.toggleHabitCompletion(habit.id, today);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(isCompletedToday ? 'Undo' : 'Mark done'),
                    ),
                  ),
                ],
              ),
              if (!isScheduledToday) ...[
                const SizedBox(height: 10),
                Text(
                  'Not scheduled today',
                  style: TextStyle(
                    color: primaryText.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                              child: _buildStatCard(
                                  'Best Streak',
                                '$streak $streakUnit',
                                  Icons.local_fire_department,
                                  Colors.orange,
                                  surface)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: _buildStatCard(
                                  'Total Done',
                                  '$total',
                                  Icons.check_circle_outline,
                                  primaryBlue,
                                  surface)),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Text('Activity',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: primaryText)),
                      const SizedBox(height: 16),
                      _buildWeekView(
                          habitProvider, currentHabit, primaryBlue, surface, border),
                      const SizedBox(height: 120), // Extra space for bottom nav
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color, Color surface) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(value,
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildWeekView(HabitProvider provider, Habit habitForSchedule,
      Color primaryBlue, Color surface, Color border) {
    final now = DateTime.now();
    final weekDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(7, (index) {
                final date = now.subtract(Duration(days: 6 - index));
                final isCompleted = provider.isCompletedOnDate(habit.id, date);
                final isScheduled = provider.isScheduledOnDate(habitForSchedule, date);

                final bgColor = isCompleted
                  ? primaryBlue
                    : !isScheduled
                      ? Colors.grey.shade100
                      : Colors.grey.shade200;

                final child = isCompleted
                  ? const Icon(Icons.check, size: 7, color: Colors.white)
                    : !isScheduled
                      ? const Icon(Icons.remove_rounded,
                        size: 10, color: Colors.grey)
                      : Text('${date.day}',
                        style: const TextStyle(
                          fontSize: 7, color: Colors.grey));

                return SizedBox(
                  width: 50,
                  height: 70,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(weekDays[date.weekday - 1],
                          style:
                              const TextStyle(fontSize: 9, color: Colors.grey)),
                      const SizedBox(height: 6),
                      CircleAvatar(
                        radius: 11,
                        backgroundColor: bgColor,
                        child: child,
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}
