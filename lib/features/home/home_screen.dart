import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/habit_icon_registry.dart';
import '../../data/providers/habit_provider.dart';
import '../chat/ai_coach_screen.dart';
import '../habit_detail/habit_detail_screen.dart';
import '../edit_habit/edit_habit_screen.dart';
import '../journal/journal_screen.dart';
import '../meditation/meditation_screen.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback? onOpenAnalytics;

  const HomeScreen({super.key, this.onOpenAnalytics});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    final days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }

  @override
  Widget build(BuildContext context) {
    final habitProvider = context.watch<HabitProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final today = DateTime.now();

    final bg = isDark ? AppThemeDark.background : AppTheme.background;
    final surface = isDark ? AppThemeDark.surface : AppTheme.surface;
    final primaryText =
        isDark ? AppThemeDark.primaryText : AppTheme.primaryText;
    final secondaryText =
        isDark ? AppThemeDark.secondaryText : AppTheme.secondaryText;
    final primaryBlue =
        isDark ? AppThemeDark.primaryBlue : AppTheme.primaryBlue;
    final border = isDark ? AppThemeDark.whisperBorder : AppTheme.whisperBorder;

    final scheduledTodayHabits = habitProvider.habits
        .where((h) => habitProvider.isScheduledOnDate(h, today))
        .toList();
    final totalHabits = scheduledTodayHabits.length;
    final completedToday = scheduledTodayHabits
        .where((h) => habitProvider.isCompletedOnDate(h.id, today))
        .length;
    final remainingToday = scheduledTodayHabits
        .where((h) => habitProvider.isDueOnDate(h.id, today))
        .length;
    final progress = totalHabits > 0 ? completedToday / totalHabits : 0.0;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -40,
              right: -50,
              child: _GlowBlob(color: primaryBlue.withValues(alpha: 0.12)),
            ),
            Positioned(
              top: 110,
              left: -40,
              child: _GlowBlob(color: primaryBlue.withValues(alpha: 0.08)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        _buildHeader(
                          context,
                          primaryText,
                          secondaryText,
                          isDark,
                          border,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _getFormattedDate(),
                          style: GoogleFonts.urbanist(
                            fontSize: 14,
                            color: secondaryText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: onOpenAnalytics == null
                              ? null
                              : () {
                                  HapticFeedback.selectionClick();
                                  onOpenAnalytics?.call();
                                },
                          child: _buildHeroSection(
                            progress,
                            completedToday,
                            totalHabits,
                            habitProvider.habits.isNotEmpty,
                            primaryBlue,
                            surface,
                            primaryText,
                            secondaryText,
                            isDark
                                ? AppThemeDark.softCardShadow
                                : AppTheme.softCardShadow,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildInsightBanner(
                          progress,
                          completedToday,
                          totalHabits,
                          habitProvider.habits.isNotEmpty,
                          primaryBlue,
                          surface,
                          primaryText,
                          secondaryText,
                        ),
                        const SizedBox(height: 16),
                        _buildQuickStats(
                          completedToday,
                          remainingToday,
                          totalHabits,
                          primaryBlue,
                          surface,
                          primaryText,
                          secondaryText,
                          isDark,
                        ),
                        const SizedBox(height: 16),
                        _buildHomeShortcuts(
                          context,
                          surface,
                          primaryText,
                          secondaryText,
                          primaryBlue,
                          isDark,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Your Day',
                              style: GoogleFonts.urbanist(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1,
                                color: primaryText,
                              ),
                            ),
                            Text(
                              '${habitProvider.habits.length} habits',
                              style: GoogleFonts.urbanist(
                                fontSize: 13,
                                color: secondaryText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                  if (habitProvider.habits.isEmpty)
                    SliverToBoxAdapter(
                      child: _buildEmptyState(
                        primaryBlue,
                        surface,
                        primaryText,
                        secondaryText,
                      ),
                    )
                  else
                    _buildHabitsSliver(
                      habitProvider,
                      today,
                      primaryText,
                      secondaryText,
                      primaryBlue,
                      surface,
                      border,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    Color primaryText,
    Color secondaryText,
    bool isDark,
    Color border,
  ) {
    final surface = isDark ? AppThemeDark.surface : AppTheme.surface;
    final primaryBlue =
        isDark ? AppThemeDark.primaryBlue : AppTheme.primaryBlue;

    Widget actionButton({
      required IconData icon,
      required VoidCallback? onTap,
      required String tooltip,
    }) {
      final enabled = onTap != null;
      return Opacity(
        opacity: enabled ? 1.0 : 0.45,
        child: Tooltip(
          message: tooltip,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border),
              ),
              child: Icon(icon, color: primaryBlue, size: 22),
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getGreeting(),
              style: GoogleFonts.urbanist(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Let\'s make today count.',
              style: GoogleFonts.urbanist(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: secondaryText,
              ),
            ),
          ],
        ),
        Row(
          children: [
            actionButton(
              icon: Icons.smart_toy_rounded,
              tooltip: 'AI Chat',
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AICoachScreen()),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroSection(
    double progress,
    int completed,
    int total,
    bool hasAnyHabits,
    Color primaryBlue,
    Color surface,
    Color primaryText,
    Color secondaryText,
    List<BoxShadow> shadow,
  ) {
    final pct = (progress * 100).clamp(0.0, 100.0).round();
    final title = total == 0
        ? (hasAnyHabits
            ? 'No habits scheduled today'
            : 'Start your first habit')
        : 'Today\'s progress';
    final subtitle = total == 0
        ? (hasAnyHabits
            ? 'Check your schedule in Habits.'
            : 'Tap + to add one.')
        : '$completed of $total completed';

    final barValue = total == 0 ? 0.0 : progress.clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: shadow,
        border: Border.all(color: primaryBlue.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.urbanist(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                    color: primaryText,
                  ),
                ),
              ),
              Text(
                total == 0 ? '—' : '$pct%',
                style: GoogleFonts.urbanist(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                  color: primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.urbanist(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: secondaryText,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: barValue,
              minHeight: 7,
              backgroundColor: primaryBlue.withValues(alpha: 0.10),
              valueColor: AlwaysStoppedAnimation(primaryBlue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightBanner(
      double progress,
      int completed,
      int total,
      bool hasAnyHabits,
      Color primaryBlue,
      Color surface,
      Color primaryText,
      Color secondaryText) {
    final label = total == 0
        ? (hasAnyHabits
            ? 'No habits scheduled today.'
            : 'Start your first habit today.')
        : progress >= 0.75
            ? 'You are on a strong streak.'
            : progress >= 0.4
                ? 'Momentum is building. Keep going.'
                : 'A small win today changes the week.';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: primaryBlue.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: primaryBlue.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child:
                Icon(Icons.auto_awesome_rounded, color: primaryBlue, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Focus for today',
                  style: GoogleFonts.urbanist(
                    fontSize: 12,
                    color: secondaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: GoogleFonts.urbanist(
                    fontSize: 15,
                    color: primaryText,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            total == 0 ? '—' : '$completed/$total',
            style: GoogleFonts.urbanist(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
              color: primaryBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(
      int completed,
      int remaining,
      int total,
      Color primaryBlue,
      Color surface,
      Color primaryText,
      Color secondaryText,
      bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _MiniStatCard(
            label: 'Completed',
            value: '$completed',
            icon: Icons.check_circle_outline,
            color: primaryBlue,
            surface: surface,
            primaryText: primaryText,
            secondaryText: secondaryText,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MiniStatCard(
            label: 'Remaining',
            value: '${remaining.clamp(0, total)}',
            icon: Icons.circle_outlined,
            color: isDark ? AppThemeDark.activeBlue : AppTheme.activeBlue,
            surface: surface,
            primaryText: primaryText,
            secondaryText: secondaryText,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(Color primaryBlue, Color surface, Color primaryText,
      Color secondaryText) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 36),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: primaryBlue.withValues(alpha: 0.10)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline,
                size: 52, color: primaryBlue.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'No habits yet',
              style: GoogleFonts.urbanist(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create one from the add button to start tracking.',
              textAlign: TextAlign.center,
              style: GoogleFonts.urbanist(
                color: secondaryText,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHabitsSliver(
      HabitProvider provider,
      DateTime today,
      Color primaryText,
      Color secondaryText,
      Color primaryBlue,
      Color surface,
      Color border) {
    return SliverPadding(
      padding: const EdgeInsets.only(bottom: 100),
      sliver: SliverList.builder(
        itemCount: provider.habits.length,
        itemBuilder: (context, index) {
          final habit = provider.habits[index];
          final isCompleted = provider.isCompletedOnDate(habit.id, today);
          final isScheduled = provider.isScheduledOnDate(habit, today);

          final subtitle = isCompleted
              ? 'Completed today'
              : !isScheduled
                  ? 'Not scheduled today'
                  : 'Tap to complete';

          return GestureDetector(
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => HabitDetailScreen(habit: habit)));
            },
            onLongPress: () {
              HapticFeedback.mediumImpact();
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => EditHabitScreen(habit: habit),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          primaryBlue.withValues(alpha: 0.14),
                          primaryBlue.withValues(alpha: 0.06),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Icon(
                            HabitIconRegistry.iconFromStored(habit.emoji),
                            color: primaryBlue,
                            size: 22,
                          ),
                        ),
                        Positioned(
                          right: 6,
                          top: 6,
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              provider.toggleHabitCompletion(habit.id, today);
                            },
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: isCompleted
                                    ? primaryBlue
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isCompleted
                                      ? primaryBlue
                                      : primaryBlue.withValues(alpha: 0.45),
                                  width: 1.5,
                                ),
                              ),
                              child: isCompleted
                                  ? const Icon(Icons.check,
                                      size: 11, color: Colors.white)
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          habit.title,
                          style: GoogleFonts.urbanist(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: primaryText,
                            decoration:
                                isCompleted ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: primaryBlue.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                habit.category,
                                style: GoogleFonts.urbanist(
                                  fontSize: 12,
                                  color: primaryBlue,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              subtitle,
                              style: GoogleFonts.urbanist(
                                fontSize: 12,
                                color: secondaryText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: secondaryText, size: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHomeShortcuts(
    BuildContext context,
    Color surface,
    Color primaryText,
    Color secondaryText,
    Color primaryBlue,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mind Space',
          style: GoogleFonts.urbanist(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
            color: primaryText,
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _HomeShortcutCard(
                  title: 'Journal',
                  subtitle: 'Write and reflect',
                  icon: Icons.edit_note,
                  surface: surface,
                  primaryText: primaryText,
                  secondaryText: secondaryText,
                  accent: primaryBlue,
                  isDark: isDark,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const JournalScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HomeShortcutCard(
                  title: 'Meditate',
                  subtitle: 'Guided voice sessions',
                  icon: Icons.spa,
                  surface: surface,
                  primaryText: primaryText,
                  secondaryText: secondaryText,
                  accent: primaryBlue,
                  isDark: isDark,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const MeditationScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HomeShortcutCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color surface;
  final Color primaryText;
  final Color secondaryText;
  final Color accent;
  final bool isDark;
  final VoidCallback onTap;

  const _HomeShortcutCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.surface,
    required this.primaryText,
    required this.secondaryText,
    required this.accent,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final glowA = accent.withValues(alpha: isDark ? 0.18 : 0.10);
    final glowB = accent.withValues(alpha: isDark ? 0.12 : 0.08);
    final topTint = accent.withValues(alpha: isDark ? 0.22 : 0.14);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: glowA,
              blurRadius: isDark ? 34 : 42,
              offset: Offset(0, isDark ? 16 : 20),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.04 : 0.02),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: surface,
                    gradient: RadialGradient(
                      center: const Alignment(-0.92, -0.92),
                      radius: 1.35,
                      colors: [topTint, surface],
                      stops: const [0.0, 0.92],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: -90,
                top: -90,
                child: _GlowBlob(color: glowB),
              ),
              Positioned(
                right: -72,
                bottom: -86,
                child: _GlowBlob(color: glowA),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: isDark ? 0.14 : 0.10),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color:
                                accent.withValues(alpha: isDark ? 0.28 : 0.20),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(icon, color: accent, size: 24),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: GoogleFonts.urbanist(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.urbanist(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: secondaryText,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final Color color;

  const _GlowBlob({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
        ),
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color surface;
  final Color primaryText;
  final Color secondaryText;

  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.surface,
    required this.primaryText,
    required this.secondaryText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.urbanist(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
              color: primaryText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.urbanist(
              fontSize: 12,
              color: secondaryText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
