import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/habit.dart';
import '../../data/providers/habit_provider.dart';

class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    final bg = isDark ? AppThemeDark.background : AppTheme.background;
    final surface = isDark ? AppThemeDark.surface : AppTheme.surface;
    final primaryText =
      isDark ? AppThemeDark.primaryText : AppTheme.primaryText;
    final secondaryText =
      isDark ? AppThemeDark.secondaryText : AppTheme.secondaryText;
    final mutedText = isDark ? AppThemeDark.mutedText : AppTheme.mutedText;
    final primaryBlue =
      isDark ? AppThemeDark.primaryBlue : AppTheme.primaryBlue;
    final border = isDark ? AppThemeDark.whisperBorder : AppTheme.whisperBorder;

    final habitProvider = context.watch<HabitProvider>();
    final logs = habitProvider.logs.where((l) => l.completed).toList();
    logs.sort((a, b) => b.date.compareTo(a.date));

    final Map<String, List<Habit>> groupedLogs = <String, List<Habit>>{};
    for (var log in logs) {
      final habitIndex =
          habitProvider.habits.indexWhere((h) => h.id == log.habitId);
      if (habitIndex >= 0) {
        final habit = habitProvider.habits[habitIndex];
        final dateKey = _formatDate(log.date);
        groupedLogs[dateKey] = (groupedLogs[dateKey] ?? [])..add(habit);
      }
    }

    final sortedDates = groupedLogs.keys.toList();

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverAppBar(
              floating: true,
              backgroundColor: bg,
              elevation: 0,
              title: Text(
                'history.',
                style: GoogleFonts.urbanist(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.0,
                  color: primaryText,
                ),
              ),
            ),
            if (sortedDates.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history, size: 48, color: mutedText),
                      const SizedBox(height: 16),
                      Text(
                        'No completions yet',
                        style: GoogleFonts.urbanist(
                          color: primaryText,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start tracking your habits!',
                        style: GoogleFonts.urbanist(
                          color: secondaryText,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final dateKey = sortedDates[index];
                      final habitsOnDate = groupedLogs[dateKey]!;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(dateKey,
                                    style: GoogleFonts.urbanist(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.2,
                                      color: primaryText,
                                    )),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color:
                                        primaryBlue.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${habitsOnDate.length}',
                                    style: GoogleFonts.urbanist(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.2,
                                      color: primaryBlue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                color: surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: border),
                              ),
                              child: Column(
                                children:
                                    habitsOnDate.asMap().entries.map((entry) {
                                  return Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 36,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                color: primaryBlue
                                                    .withValues(alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Center(
                                                child: Icon(
                                                  Icons.check,
                                                  size: 18,
                                                  color: primaryBlue,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(entry.value.title,
                                                      style:
                                                          GoogleFonts.urbanist(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        letterSpacing: -0.2,
                                                        color: primaryText,
                                                      )),
                                                  Text(entry.value.category,
                                                      style:
                                                          GoogleFonts.urbanist(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: secondaryText,
                                                      )),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (entry.key != habitsOnDate.length - 1)
                                        Container(
                                            height: 1,
                                            color: border,
                                            margin: const EdgeInsets.only(
                                                left: 64)),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    childCount: sortedDates.length,
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: SizedBox(height: MediaQuery.of(context).padding.bottom),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return 'Yesterday';
    }
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}
