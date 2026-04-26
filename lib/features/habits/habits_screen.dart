import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/habit_icon_registry.dart';
import '../../data/providers/habit_provider.dart';
import '../habit_detail/habit_detail_screen.dart';

class HabitsScreen extends StatelessWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final habitProvider = context.watch<HabitProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    final bg = isDark ? AppThemeDark.background : AppTheme.background;
    final surface = isDark ? AppThemeDark.surface : AppTheme.surface;
    final primaryText =
        isDark ? AppThemeDark.primaryText : AppTheme.primaryText;
    final secondaryText =
        isDark ? AppThemeDark.secondaryText : AppTheme.secondaryText;
    final primaryBlue =
        isDark ? AppThemeDark.primaryBlue : AppTheme.primaryBlue;
    final border = isDark ? AppThemeDark.whisperBorder : AppTheme.whisperBorder;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                'Your Habits',
                style: GoogleFonts.urbanist(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                  color: primaryText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${habitProvider.habits.length} habits',
                style: GoogleFonts.urbanist(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: secondaryText,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: habitProvider.habits.isEmpty
                    ? Center(
                        child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline,
                              size: 48, color: secondaryText),
                          const SizedBox(height: 16),
                          Text(
                            'No habits yet',
                            style: GoogleFonts.urbanist(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.6,
                              color: primaryText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap + to add your first habit',
                            style: GoogleFonts.urbanist(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: secondaryText,
                            ),
                          ),
                        ],
                      ))
                    : ListView.builder(
                        itemCount: habitProvider.habits.length,
                        itemBuilder: (context, index) {
                          final habit = habitProvider.habits[index];
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          HabitDetailScreen(habit: habit)));
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                  color: surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: border)),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                        color:
                                            primaryBlue.withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    child: Center(
                                        child: Icon(
                                      HabitIconRegistry.iconFromStored(
                                          habit.emoji),
                                      size: 22,
                                      color: primaryBlue,
                                    )),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          habit.title,
                                          style: GoogleFonts.urbanist(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.2,
                                            color: primaryText,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          habit.category,
                                          style: GoogleFonts.urbanist(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: secondaryText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_right,
                                      color: secondaryText, size: 20),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
