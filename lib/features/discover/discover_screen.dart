import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/habit.dart';
import '../../data/providers/habit_provider.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

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
    final primaryBlue =
      isDark ? AppThemeDark.primaryBlue : AppTheme.primaryBlue;
    final warmWhite = isDark ? AppThemeDark.warmWhite : AppTheme.warmWhite;
    final border = isDark ? AppThemeDark.whisperBorder : AppTheme.whisperBorder;

    final List<Map<String, String>> ideas = [
      {'title': 'Morning Journal', 'category': 'Mindfulness', 'icon': '📝'},
      {'title': 'Read 10 Pages', 'category': 'Learning', 'icon': '📚'},
      {'title': 'Drink 2L Water', 'category': 'Health', 'icon': '💧'},
      {'title': 'Digital Detox', 'category': 'Focus', 'icon': '📵'},
      {'title': 'Stretch 15m', 'category': 'Fitness', 'icon': '🧘'},
      {'title': 'Meditate 10m', 'category': 'Mindfulness', 'icon': '🧘'},
      {'title': 'Daily Walk', 'category': 'Fitness', 'icon': '🚶'},
      {'title': 'No Sugar', 'category': 'Health', 'icon': '🍎'},
    ];

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
                'ideas.',
                style: GoogleFonts.urbanist(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.0,
                  color: primaryText,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inspiration',
                      style: GoogleFonts.urbanist(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap + to add any habit to your list',
                      style: GoogleFonts.urbanist(
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: secondaryText,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ...ideas.map((idea) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: warmWhite,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(idea['icon']!,
                                      style: const TextStyle(fontSize: 24)),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(idea['title']!,
                                        style: GoogleFonts.urbanist(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.3,
                                          color: primaryText,
                                        )),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: primaryBlue.withValues(
                                          alpha: isDark ? 0.14 : 0.10,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        idea['category']!,
                                        style: GoogleFonts.urbanist(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.2,
                                          color: primaryBlue,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () async {
                                  final habit = Habit(
                                    title: idea['title']!,
                                    category: idea['category']!,
                                    emoji: idea['icon']!,
                                    timeOfDay: 'Anytime',
                                  );
                                  await context
                                      .read<HabitProvider>()
                                      .addHabit(habit);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('${idea['title']} added'),
                                      backgroundColor: primaryBlue,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: primaryBlue,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.add,
                                      color: Colors.white, size: 20),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
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
}
