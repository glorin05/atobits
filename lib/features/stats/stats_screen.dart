import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/habit_icon_registry.dart';
import '../../data/providers/habit_provider.dart';
import '../../data/models/habit.dart';

enum _ExportType { csv, pdf }

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  String _selectedPeriod = 'weekly';
  String? _selectedHabitId;

  Rect? _shareOrigin(BuildContext context) {
    final obj = context.findRenderObject();
    if (obj is RenderBox) {
      return obj.localToGlobal(Offset.zero) & obj.size;
    }
    return null;
  }

  String _csvEscape(String value) {
    final v = value;
    final needsQuotes = v.contains(',') ||
        v.contains('"') ||
        v.contains('\n') ||
        v.contains('\r');
    final escaped = v.replaceAll('"', '""');
    return needsQuotes ? '"$escaped"' : escaped;
  }

  String _buildHabitsCsv(HabitProvider provider) {
    final sb = StringBuffer();
    sb.writeln(
        'id,title,category,timeOfDay,reminderEnabled,reminderTime,createdAt,scheduleType,scheduleDaysOfWeek,scheduleTimesPerWeek,scheduleIntervalDays,scheduleAnchorDate');

    for (final h in provider.habits) {
      sb.writeln([
        _csvEscape(h.id),
        _csvEscape(h.title),
        _csvEscape(h.category),
        _csvEscape(h.timeOfDay),
        h.reminderEnabled ? 'true' : 'false',
        _csvEscape(h.reminderTime ?? ''),
        _csvEscape(h.createdAt.toIso8601String()),
        _csvEscape(h.scheduleType),
        _csvEscape(h.scheduleDaysOfWeek.join(';')),
        '${h.scheduleTimesPerWeek}',
        '${h.scheduleIntervalDays}',
        _csvEscape(h.scheduleAnchorDate?.toIso8601String() ?? ''),
      ].join(','));
    }

    return sb.toString();
  }

  String _buildLogsCsv(HabitProvider provider) {
    final sb = StringBuffer();
    sb.writeln('habitId,habitTitle,date,status,completedAt');

    final logs = [...provider.logs]..sort((a, b) => a.date.compareTo(b.date));
    for (final l in logs) {
      final habitTitle = provider.habitById(l.habitId)?.title ?? '';
      sb.writeln([
        _csvEscape(l.habitId),
        _csvEscape(habitTitle),
        _csvEscape(l.date.toIso8601String()),
        _csvEscape(l.status),
        _csvEscape(l.completedAt?.toIso8601String() ?? ''),
      ].join(','));
    }

    return sb.toString();
  }

  String _stampYmd(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  Future<void> _exportCsv(BuildContext context, HabitProvider provider) async {
    final origin = _shareOrigin(context);
    final now = DateTime.now();
    final stamp = _stampYmd(now);

    final habitsCsv = _buildHabitsCsv(provider);
    final logsCsv = _buildLogsCsv(provider);

    final files = <XFile>[
      XFile.fromData(
        Uint8List.fromList(utf8.encode(habitsCsv)),
        mimeType: 'text/csv',
        name: 'atobits_habits_$stamp.csv',
      ),
      XFile.fromData(
        Uint8List.fromList(utf8.encode(logsCsv)),
        mimeType: 'text/csv',
        name: 'atobits_logs_$stamp.csv',
      ),
    ];

    await Share.shareXFiles(
      files,
      subject: 'Atobits CSV export',
      text: 'Your Atobits data export (CSV).',
      sharePositionOrigin: origin,
    );
  }

  Future<void> _exportPdf(BuildContext context, HabitProvider provider) async {
    final origin = _shareOrigin(context);
    final now = DateTime.now();
    final stamp = _stampYmd(now);
    final weekly = _buildWeeklyTrend(provider);

    final totalHabits = provider.habits.length;
    final totalCompletions = provider.logs.where((l) => l.completed).length;

    final doc = pw.Document();

    final titleStyle = pw.TextStyle(
      fontSize: 22,
      fontWeight: pw.FontWeight.bold,
    );
    final h2Style = pw.TextStyle(
      fontSize: 14,
      fontWeight: pw.FontWeight.bold,
    );
    const mutedStyle = pw.TextStyle(
      fontSize: 10,
      color: PdfColors.grey700,
    );

    final tableData = provider.habits.map((h) {
      final streak = provider.getStreak(h.id);
      final comps = provider.getTotalCompletions(h.id);
      return [
        h.title,
        h.category,
        '$streak',
        '$comps',
      ];
    }).toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context pdfContext) {
          return [
            pw.Text('Atobits Recap', style: titleStyle),
            pw.SizedBox(height: 4),
            pw.Text('Generated: ${now.toIso8601String()}', style: mutedStyle),
            pw.SizedBox(height: 16),
            pw.Text('Summary', style: h2Style),
            pw.SizedBox(height: 8),
            pw.Text('• Total habits: $totalHabits'),
            pw.Text('• Completions logged: $totalCompletions'),
            pw.SizedBox(height: 8),
            pw.Text(
                '• Last 7 days completion: ${weekly.current.percent}% (${weekly.current.completed}/${weekly.current.possible})'),
            pw.SizedBox(height: 16),
            pw.Text('Habits', style: h2Style),
            pw.SizedBox(height: 8),
            if (tableData.isEmpty)
              pw.Text('No habits yet.')
            else
              pw.TableHelper.fromTextArray(
                headers: const ['Habit', 'Category', 'Streak', 'Completions'],
                data: tableData,
                headerStyle: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
                cellStyle: const pw.TextStyle(fontSize: 10),
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColors.grey200),
                cellAlignment: pw.Alignment.centerLeft,
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(1.2),
                  3: const pw.FlexColumnWidth(1.4),
                },
              ),
          ];
        },
      ),
    );

    final bytes = await doc.save();
    final file = XFile.fromData(
      bytes,
      mimeType: 'application/pdf',
      name: 'atobits_recap_$stamp.pdf',
    );

    await Share.shareXFiles(
      [file],
      subject: 'Atobits PDF recap',
      text: 'Your Atobits recap (PDF).',
      sharePositionOrigin: origin,
    );
  }

  Future<void> _handleExport(
    BuildContext context,
    HabitProvider provider,
    _ExportType type,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Preparing export...'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ),
    );

    try {
      if (type == _ExportType.csv) {
        await _exportCsv(context, provider);
      } else {
        await _exportPdf(context, provider);
      }
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Export failed on this device.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  int _heatmapDaysForPeriod(String period) {
    switch (period) {
      case 'weekly':
        return 14; // 2 weeks
      case 'monthly':
        return 35; // 5 weeks
      case 'yearly':
        return 84; // 12 weeks
      default:
        return 28; // 4 weeks
    }
  }

  List<_HeatmapDay> _buildHeatmapDays(HabitProvider provider, int days) {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day);
    final start = end.subtract(Duration(days: days - 1));

    final completedByDay = <int, Set<String>>{};

    int dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

    for (final log in provider.logs) {
      final d = DateTime(log.date.year, log.date.month, log.date.day);
      final key = dayKey(d);
      if (log.completed) {
        (completedByDay[key] ??= <String>{}).add(log.habitId);
      }
    }

    final result = <_HeatmapDay>[];
    for (var i = 0; i < days; i++) {
      final date = start.add(Duration(days: i));
      final key = dayKey(date);
      final completed = completedByDay[key] ?? const <String>{};

      var scheduled = 0;
      var doneOrSkipped = 0;
      for (final habit in provider.habits) {
        if (!provider.isScheduledOnDate(habit, date)) continue;
        scheduled++;
        if (completed.contains(habit.id)) {
          doneOrSkipped++;
        }
      }

      result.add(_HeatmapDay(
        date: date,
        scheduled: scheduled,
        doneOrSkipped: doneOrSkipped,
      ));
    }

    return result;
  }

  _WeeklyTrend _buildWeeklyTrend(HabitProvider provider) {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day);
    final currentStart = end.subtract(const Duration(days: 6));
    final previousEnd = currentStart.subtract(const Duration(days: 1));
    final previousStart = previousEnd.subtract(const Duration(days: 6));

    final completionsByDay = <DateTime, int>{};
    for (final log in provider.logs) {
      if (!log.completed) continue;
      final day = _dateOnly(log.date);
      completionsByDay[day] = (completionsByDay[day] ?? 0) + 1;
    }

    _TrendWindowStats window(DateTime start, DateTime end) {
      var possible = 0;
      var completed = 0;
      final days = end.difference(start).inDays + 1;
      for (var i = 0; i < days; i++) {
        final day = start.add(Duration(days: i));
        final activeHabits = provider.habits.where((habit) {
          final created = _dateOnly(habit.createdAt);
          return !created.isAfter(day);
        }).length;

        possible += activeHabits;
        completed += completionsByDay[day] ?? 0;
      }

      final percent = possible <= 0
          ? 0
          : ((completed / possible) * 100).round().clamp(0, 100);

      return _TrendWindowStats(
        start: start,
        end: end,
        completed: completed,
        possible: possible,
        percent: percent,
      );
    }

    final current = window(currentStart, end);
    final previous = window(previousStart, previousEnd);
    return _WeeklyTrend(current: current, previous: previous);
  }

  @override
  Widget build(BuildContext context) {
    return _selectedHabitId == null
        ? _buildOverview(context)
        : _buildHabitDetail(context);
  }

  Widget _buildOverview(BuildContext context) {
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
    final activeBlue = isDark ? AppThemeDark.activeBlue : AppTheme.activeBlue;
    final border = isDark ? AppThemeDark.whisperBorder : AppTheme.whisperBorder;
    final cardShadow =
        isDark ? AppThemeDark.softCardShadow : AppTheme.softCardShadow;

    final stats = _calculateOverallStats(habitProvider, _selectedPeriod);
    final overallSeries = _buildOverallSeries(habitProvider, _selectedPeriod);
    final heatmapDays = _buildHeatmapDays(
        habitProvider, _heatmapDaysForPeriod(_selectedPeriod));
    final weeklyTrend = _buildWeeklyTrend(habitProvider);

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
                'Analytics',
                style: GoogleFonts.urbanist(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.2,
                  color: primaryText,
                ),
              ),
              actions: [
                PopupMenuButton<_ExportType>(
                  icon: Icon(Icons.ios_share_rounded, color: primaryText),
                  onSelected: (value) =>
                      _handleExport(context, habitProvider, value),
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: _ExportType.csv,
                      child: Text('Export CSV'),
                    ),
                    PopupMenuItem(
                      value: _ExportType.pdf,
                      child: Text('Export PDF recap'),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 140),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PeriodSelector(
                      selected: _selectedPeriod,
                      onSelect: (period) {
                        if (period == _selectedPeriod) return;
                        HapticFeedback.lightImpact();
                        setState(() => _selectedPeriod = period);
                      },
                      accent: primaryBlue,
                      surface: surface,
                      border: border,
                      secondaryText: secondaryText,
                    ),
                    const SizedBox(height: 18),
                    _AnalyticsChartCard(
                      title: 'Overall completion',
                      subtitle: _periodSubtitle(_selectedPeriod),
                      percent: stats['completionRate'] as int,
                      points: overallSeries,
                      accent: primaryBlue,
                      surface: surface,
                      border: border,
                      primaryText: primaryText,
                      secondaryText: secondaryText,
                      shadow: cardShadow,
                    ),
                    const SizedBox(height: 18),
                    _CalendarHeatmapCard(
                      title: 'Calendar heatmap',
                      subtitle:
                          'Last ${(heatmapDays.length / 7).round()} weeks',
                      days: heatmapDays,
                      accent: primaryBlue,
                      surface: surface,
                      border: border,
                      primaryText: primaryText,
                      secondaryText: secondaryText,
                      shadow: cardShadow,
                    ),
                    const SizedBox(height: 18),
                    _WeeklyTrendCard(
                      title: 'Weekly trend',
                      subtitle: 'Last 7 days',
                      current: weeklyTrend.current,
                      previous: weeklyTrend.previous,
                      accent: activeBlue,
                      surface: surface,
                      border: border,
                      primaryText: primaryText,
                      secondaryText: secondaryText,
                      shadow: cardShadow,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Total Habits',
                            value: '${stats['totalHabits']}',
                            icon: Icons.track_changes_rounded,
                            accent: primaryBlue,
                            surface: surface,
                            border: border,
                            primaryText: primaryText,
                            secondaryText: secondaryText,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: 'Completion',
                            value: '${stats['completionRate']}%',
                            icon: Icons.check_circle_outlined,
                            accent: activeBlue,
                            surface: surface,
                            border: border,
                            primaryText: primaryText,
                            secondaryText: secondaryText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Best Streak',
                            value: '${stats['bestStreak']}',
                            icon: Icons.local_fire_department,
                            accent: primaryBlue,
                            surface: surface,
                            border: border,
                            primaryText: primaryText,
                            secondaryText: secondaryText,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: 'On Track',
                            value: '${stats['habitsOnTrack']}',
                            icon: Icons.trending_up,
                            accent: activeBlue,
                            surface: surface,
                            border: border,
                            primaryText: primaryText,
                            secondaryText: secondaryText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Habit Breakdown',
                      style: GoogleFonts.urbanist(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (habitProvider.habits.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(Icons.add_task_outlined,
                                  size: 48,
                                  color: primaryBlue.withValues(alpha: 0.3)),
                              const SizedBox(height: 16),
                              Text(
                                'No habits yet',
                                style: GoogleFonts.urbanist(
                                  color: secondaryText,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Column(
                        children: habitProvider.habits.map((habit) {
                          final habitStats = _calculateHabitStats(
                              habit, habitProvider, _selectedPeriod);
                          final consistency =
                              (habitStats['consistency'] as int).clamp(0, 100);
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              setState(() => _selectedHabitId = habit.id);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: border, width: 1.5),
                                boxShadow: cardShadow,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        HabitIconRegistry.iconFromStored(
                                            habit.emoji),
                                        size: 26,
                                        color: primaryBlue,
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              habit.title,
                                              style: GoogleFonts.urbanist(
                                                color: primaryText,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 16,
                                                letterSpacing: -0.6,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${habitStats['completions']} completions · ${habitStats['currentStreak']}d streak',
                                              style: GoogleFonts.urbanist(
                                                color: secondaryText,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        '$consistency%',
                                        style: GoogleFonts.urbanist(
                                          color: primaryBlue,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.6,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Icon(
                                        Icons.chevron_right,
                                        color:
                                            primaryBlue.withValues(alpha: 0.5),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _MiniProgressBar(
                                    value: consistency / 100.0,
                                    accent: primaryBlue,
                                    trackColor:
                                        primaryBlue.withValues(alpha: 0.10),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHabitDetail(BuildContext context) {
    final habitProvider = context.watch<HabitProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    final habit = habitProvider.habits.firstWhere(
      (h) => h.id == _selectedHabitId,
      orElse: () => Habit(
        title: 'Unknown',
        category: '',
        emoji: HabitIconRegistry.defaultKey,
        timeOfDay: 'Morning',
      ),
    );

    final bg = isDark ? AppThemeDark.background : AppTheme.background;
    final surface = isDark ? AppThemeDark.surface : AppTheme.surface;
    final primaryText =
        isDark ? AppThemeDark.primaryText : AppTheme.primaryText;
    final secondaryText =
        isDark ? AppThemeDark.secondaryText : AppTheme.secondaryText;
    final primaryBlue =
        isDark ? AppThemeDark.primaryBlue : AppTheme.primaryBlue;
    final activeBlue = isDark ? AppThemeDark.activeBlue : AppTheme.activeBlue;
    final border = isDark ? AppThemeDark.whisperBorder : AppTheme.whisperBorder;
    final cardShadow =
        isDark ? AppThemeDark.softCardShadow : AppTheme.softCardShadow;

    final stats = _calculateHabitStats(habit, habitProvider, _selectedPeriod);
    final habitSeries =
        _buildHabitSeries(habit, habitProvider, _selectedPeriod);

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
              leading: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _selectedHabitId = null);
                },
                child: Icon(Icons.arrow_back, color: primaryText),
              ),
              title: Row(
                children: [
                  Icon(
                    HabitIconRegistry.iconFromStored(habit.emoji),
                    size: 32,
                    color: primaryBlue,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      habit.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.urbanist(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                        color: primaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 140),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PeriodSelector(
                      selected: _selectedPeriod,
                      onSelect: (period) {
                        if (period == _selectedPeriod) return;
                        HapticFeedback.lightImpact();
                        setState(() => _selectedPeriod = period);
                      },
                      accent: primaryBlue,
                      surface: surface,
                      border: border,
                      secondaryText: secondaryText,
                    ),
                    const SizedBox(height: 18),
                    _AnalyticsChartCard(
                      title: 'Progress',
                      subtitle: _periodSubtitle(_selectedPeriod),
                      percent: stats['consistency'] as int,
                      points: habitSeries,
                      accent: primaryBlue,
                      surface: surface,
                      border: border,
                      primaryText: primaryText,
                      secondaryText: secondaryText,
                      shadow: cardShadow,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Completions',
                            value: '${stats['completions']}',
                            icon: Icons.check_circle,
                            accent: primaryBlue,
                            surface: surface,
                            border: border,
                            primaryText: primaryText,
                            secondaryText: secondaryText,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: 'Consistency',
                            value: '${stats['consistency']}%',
                            icon: Icons.insights_rounded,
                            accent: activeBlue,
                            surface: surface,
                            border: border,
                            primaryText: primaryText,
                            secondaryText: secondaryText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Current Streak',
                            value: '${stats['currentStreak']}',
                            icon: Icons.local_fire_department,
                            accent: primaryBlue,
                            surface: surface,
                            border: border,
                            primaryText: primaryText,
                            secondaryText: secondaryText,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: 'Best Streak',
                            value: '${stats['longestStreak']}',
                            icon: Icons.trending_up_rounded,
                            accent: activeBlue,
                            surface: surface,
                            border: border,
                            primaryText: primaryText,
                            secondaryText: secondaryText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: border,
                        ),
                        boxShadow: cardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.local_fire_department,
                                  color: primaryBlue, size: 24),
                              const SizedBox(width: 12),
                              Text(
                                'Streak Details',
                                style: GoogleFonts.urbanist(
                                  color: primaryText,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.6,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildStreakRow('Current Streak',
                              '${stats['currentStreak']} days',
                              labelColor: secondaryText,
                              valueColor: primaryText),
                          const SizedBox(height: 12),
                          _buildStreakRow('Longest Streak',
                              '${stats['longestStreak']} days',
                              labelColor: secondaryText,
                              valueColor: primaryText),
                          const SizedBox(height: 12),
                          _buildStreakRow('Last Lost Streak',
                              stats['lastLostDate'] ?? 'Never',
                              labelColor: secondaryText,
                              valueColor: primaryText),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _calculateOverallStats(
      HabitProvider provider, String period) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final periodStart = _getPeriodStart(today, period);
    int totalHabits = provider.habits.length;
    int bestStreak = 0;
    int habitsOnTrack = 0;
    int totalCompletions = 0;
    int totalPossible = 0;

    for (var habit in provider.habits) {
      final logs = provider.logs.where((l) => l.habitId == habit.id).toList();
      final habitCreated = _dateOnly(habit.createdAt);
      final effectiveStart =
          habitCreated.isAfter(periodStart) ? habitCreated : periodStart;
      if (effectiveStart.isAfter(today)) continue;

      final periodCompletions = logs.where((l) {
        if (!l.completed) return false;
        final logDate = _dateOnly(l.date);
        return !logDate.isBefore(effectiveStart) && !logDate.isAfter(today);
      }).length;
      totalCompletions += periodCompletions;

      int daysInPeriod = today.difference(effectiveStart).inDays + 1;
      totalPossible += daysInPeriod;

      final recentLog = logs.where((l) {
        final logDate = DateTime(l.date.year, l.date.month, l.date.day);
        return l.completed &&
            (logDate == today ||
                logDate == today.subtract(const Duration(days: 1)));
      }).isNotEmpty;
      if (recentLog) habitsOnTrack++;

      if (logs.isNotEmpty) {
        final completedLogs = logs.where((l) => l.completed).toList();
        completedLogs.sort((a, b) => b.date.compareTo(a.date));
        int streak = 0;
        DateTime checkDate = today;
        for (var log in completedLogs) {
          final logDate = DateTime(log.date.year, log.date.month, log.date.day);
          if (logDate == checkDate ||
              logDate == checkDate.subtract(const Duration(days: 1))) {
            streak++;
            checkDate = logDate.subtract(const Duration(days: 1));
          } else {
            break;
          }
        }
        if (streak > bestStreak) bestStreak = streak;
      }
    }

    final completionRate = totalPossible > 0
        ? ((totalCompletions / totalPossible) * 100).round()
        : 0;

    return {
      'totalHabits': totalHabits,
      'completionRate': completionRate,
      'bestStreak': bestStreak,
      'habitsOnTrack': habitsOnTrack,
    };
  }

  Map<String, dynamic> _calculateHabitStats(
      Habit habit, HabitProvider provider, String period) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final logs = provider.logs.where((l) => l.habitId == habit.id).toList();

    int currentStreak = 0;
    if (logs.isNotEmpty) {
      final completedLogs = logs.where((l) => l.completed).toList();
      if (completedLogs.isNotEmpty) {
        completedLogs.sort((a, b) => b.date.compareTo(a.date));
        DateTime checkDate = today;
        for (var log in completedLogs) {
          final logDate = DateTime(log.date.year, log.date.month, log.date.day);
          if (logDate == checkDate ||
              logDate == checkDate.subtract(const Duration(days: 1))) {
            currentStreak++;
            checkDate = logDate.subtract(const Duration(days: 1));
          } else {
            break;
          }
        }
      }
    }

    int longestStreak = 0;
    String? lastLostDate;
    if (logs.isNotEmpty) {
      final completedLogs = logs.where((l) => l.completed).toList();
      completedLogs.sort((a, b) => b.date.compareTo(a.date));
      DateTime checkDate = today;
      int tempStreak = 0;
      for (var log in completedLogs) {
        final logDate = DateTime(log.date.year, log.date.month, log.date.day);
        if (logDate == checkDate ||
            logDate == checkDate.subtract(const Duration(days: 1))) {
          tempStreak++;
          checkDate = logDate.subtract(const Duration(days: 1));
        } else {
          if (tempStreak > longestStreak) longestStreak = tempStreak;
          lastLostDate ??= '${logDate.month}/${logDate.day}/${logDate.year}';
          tempStreak = 0;
          checkDate = logDate;
        }
      }
      if (tempStreak > longestStreak) longestStreak = tempStreak;
    }

    final periodStart = _getPeriodStart(today, period);
    final habitCreated = _dateOnly(habit.createdAt);
    final effectiveStart =
        habitCreated.isAfter(periodStart) ? habitCreated : periodStart;
    final completions = logs.where((l) {
      if (!l.completed) return false;
      final logDate = _dateOnly(l.date);
      return !logDate.isBefore(effectiveStart) && !logDate.isAfter(today);
    }).length;

    int daysInPeriod = effectiveStart.isAfter(today)
        ? 0
        : today.difference(effectiveStart).inDays + 1;
    final consistency =
        daysInPeriod > 0 ? ((completions / daysInPeriod) * 100).round() : 0;

    return {
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'completions': completions,
      'consistency': consistency,
      'lastLostDate': lastLostDate,
    };
  }

  DateTime _getPeriodStart(DateTime today, String period) {
    switch (period) {
      case 'daily':
        return today;
      case 'weekly':
        return today.subtract(Duration(days: today.weekday - 1));
      case 'monthly':
        return DateTime(today.year, today.month, 1);
      case 'yearly':
        return DateTime(today.year, 1, 1);
      default:
        return today.subtract(const Duration(days: 7));
    }
  }

  String _periodSubtitle(String period) {
    switch (period) {
      case 'daily':
        return 'Today';
      case 'weekly':
        return 'This week';
      case 'monthly':
        return 'This month';
      case 'yearly':
        return 'This year';
      default:
        return '';
    }
  }

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  String _monthLabel(int month) {
    const months = [
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
      'Dec',
    ];
    return months[(month - 1).clamp(0, 11)];
  }

  List<_ChartPoint> _buildOverallSeries(HabitProvider provider, String period) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (provider.habits.isEmpty) return const [];

    final completionsByDay = <DateTime, int>{};
    for (final log in provider.logs) {
      if (!log.completed) continue;
      final day = _dateOnly(log.date);
      completionsByDay[day] = (completionsByDay[day] ?? 0) + 1;
    }

    if (period == 'yearly') {
      final points = <_ChartPoint>[];
      for (int month = 1; month <= today.month; month++) {
        final monthStart = DateTime(today.year, month, 1);
        final monthEnd =
            month == today.month ? today : DateTime(today.year, month + 1, 0);

        int possible = 0;
        int completed = 0;
        final days = monthEnd.difference(monthStart).inDays + 1;
        for (int i = 0; i < days; i++) {
          final day = monthStart.add(Duration(days: i));
          final activeHabits = provider.habits.where((habit) {
            final created = _dateOnly(habit.createdAt);
            return !created.isAfter(day);
          }).length;
          possible += activeHabits;
          completed += completionsByDay[day] ?? 0;
        }

        final value = possible == 0 ? 0.0 : (completed / possible);
        points.add(_ChartPoint(
          label: _monthLabel(month),
          value: value,
          completed: completed,
          total: possible,
        ));
      }
      return points;
    }

    final periodStart = _getPeriodStart(today, period);
    final days = today.difference(periodStart).inDays + 1;
    if (days <= 0) return const [];

    const weekday = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final points = <_ChartPoint>[];
    for (int i = 0; i < days; i++) {
      final day = periodStart.add(Duration(days: i));
      final activeHabits = provider.habits.where((habit) {
        final created = _dateOnly(habit.createdAt);
        return !created.isAfter(day);
      }).length;
      final completed = completionsByDay[day] ?? 0;
      final value = activeHabits == 0 ? 0.0 : (completed / activeHabits);
      final label = period == 'daily'
          ? 'Today'
          : period == 'weekly'
              ? weekday[day.weekday - 1]
              : '${day.day}';
      points.add(_ChartPoint(
        label: label,
        value: value,
        completed: completed,
        total: activeHabits,
      ));
    }
    return points;
  }

  List<_ChartPoint> _buildHabitSeries(
      Habit habit, HabitProvider provider, String period) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final created = _dateOnly(habit.createdAt);
    final completedDays = provider.logs
        .where((l) => l.habitId == habit.id && l.completed)
        .map((l) => _dateOnly(l.date))
        .toSet();

    if (period == 'yearly') {
      final points = <_ChartPoint>[];
      for (int month = 1; month <= today.month; month++) {
        final monthStart = DateTime(today.year, month, 1);
        final monthEnd =
            month == today.month ? today : DateTime(today.year, month + 1, 0);

        final effectiveStart =
            created.isAfter(monthStart) ? created : monthStart;
        if (effectiveStart.isAfter(monthEnd)) {
          points.add(_ChartPoint(
            label: _monthLabel(month),
            value: 0,
            completed: 0,
            total: 0,
          ));
          continue;
        }

        final days = monthEnd.difference(effectiveStart).inDays + 1;
        int completed = 0;
        for (int i = 0; i < days; i++) {
          final day = effectiveStart.add(Duration(days: i));
          if (completedDays.contains(day)) completed++;
        }

        final value = days == 0 ? 0.0 : (completed / days);
        points.add(_ChartPoint(
          label: _monthLabel(month),
          value: value,
          completed: completed,
          total: days,
        ));
      }
      return points;
    }

    final periodStart = _getPeriodStart(today, period);
    final days = today.difference(periodStart).inDays + 1;
    if (days <= 0) return const [];

    const weekday = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final points = <_ChartPoint>[];
    for (int i = 0; i < days; i++) {
      final day = periodStart.add(Duration(days: i));
      final possible = created.isAfter(day) ? 0 : 1;
      final completed = possible == 1 && completedDays.contains(day) ? 1 : 0;
      final value = possible == 0 ? 0.0 : completed.toDouble();
      final label = period == 'daily'
          ? 'Today'
          : period == 'weekly'
              ? weekday[day.weekday - 1]
              : '${day.day}';
      points.add(_ChartPoint(
        label: label,
        value: value,
        completed: completed,
        total: possible,
      ));
    }
    return points;
  }

  Widget _buildStreakRow(
    String label,
    String value, {
    required Color labelColor,
    required Color valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: labelColor, fontSize: 14),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: valueColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final Color surface;
  final Color border;
  final Color primaryText;
  final Color secondaryText;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    required this.surface,
    required this.border,
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
        border: Border.all(color: accent.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: accent.withValues(alpha: 0.12)),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(height: 12),
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

class _MiniProgressBar extends StatelessWidget {
  final double value;
  final Color accent;
  final Color trackColor;

  const _MiniProgressBar({
    required this.value,
    required this.accent,
    required this.trackColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: BorderRadius.circular(99),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: value.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accent, accent.withValues(alpha: 0.7)],
            ),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  final Color accent;
  final Color surface;
  final Color border;
  final Color secondaryText;

  const _PeriodSelector({
    required this.selected,
    required this.onSelect,
    required this.accent,
    required this.surface,
    required this.border,
    required this.secondaryText,
  });

  String _label(String period) {
    switch (period) {
      case 'daily':
        return 'Daily';
      case 'weekly':
        return 'Weekly';
      case 'monthly':
        return 'Monthly';
      case 'yearly':
        return 'Yearly';
      default:
        return period;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: ['daily', 'weekly', 'monthly', 'yearly'].map((period) {
        final isSelected = selected == period;
        return GestureDetector(
          onTap: () => onSelect(period),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? accent : surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? accent : border,
                width: 1.5,
              ),
            ),
            child: Text(
              _label(period),
              style: GoogleFonts.urbanist(
                color: isSelected ? Colors.white : secondaryText,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ChartPoint {
  final String label;
  final double value;
  final int completed;
  final int total;

  const _ChartPoint({
    required this.label,
    required this.value,
    required this.completed,
    required this.total,
  });
}

class _HeatmapDay {
  final DateTime date;
  final int scheduled;
  final int doneOrSkipped;

  const _HeatmapDay({
    required this.date,
    required this.scheduled,
    required this.doneOrSkipped,
  });

  double get ratio {
    if (scheduled <= 0) return 0;
    return doneOrSkipped / scheduled;
  }
}

class _TrendWindowStats {
  final DateTime start;
  final DateTime end;
  final int completed;
  final int possible;
  final int percent;

  const _TrendWindowStats({
    required this.start,
    required this.end,
    required this.completed,
    required this.possible,
    required this.percent,
  });
}

class _WeeklyTrend {
  final _TrendWindowStats current;
  final _TrendWindowStats previous;

  const _WeeklyTrend({
    required this.current,
    required this.previous,
  });
}

class _CalendarHeatmapCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<_HeatmapDay> days;
  final Color accent;
  final Color surface;
  final Color border;
  final Color primaryText;
  final Color secondaryText;
  final List<BoxShadow> shadow;

  const _CalendarHeatmapCard({
    required this.title,
    required this.subtitle,
    required this.days,
    required this.accent,
    required this.surface,
    required this.border,
    required this.primaryText,
    required this.secondaryText,
    required this.shadow,
  });

  Color _cellFill(_HeatmapDay day) {
    if (day.scheduled <= 0) return Colors.transparent;

    final r = day.ratio;
    if (r <= 0) return accent.withValues(alpha: 0.08);
    if (r < 0.34) return accent.withValues(alpha: 0.22);
    if (r < 0.67) return accent.withValues(alpha: 0.45);
    return accent.withValues(alpha: 0.75);
  }

  Color _cellBorder(_HeatmapDay day) {
    if (day.scheduled <= 0) return border.withValues(alpha: 0.8);
    return accent.withValues(alpha: 0.22);
  }

  int _overallPercent() {
    var scheduled = 0;
    var done = 0;
    for (final d in days) {
      scheduled += d.scheduled;
      done += d.doneOrSkipped;
    }
    if (scheduled <= 0) return 0;
    return ((done / scheduled) * 100).round().clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    const cell = 14.0;
    const gap = 6.0;
    final percent = _overallPercent();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
        boxShadow: shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.urbanist(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.urbanist(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$percent%',
                style: GoogleFonts.urbanist(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: days.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: gap,
              crossAxisSpacing: gap,
              mainAxisExtent: cell,
            ),
            itemBuilder: (context, index) {
              final day = days[index];
              return Center(
                child: Container(
                  width: cell,
                  height: cell,
                  decoration: BoxDecoration(
                    color: _cellFill(day),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: _cellBorder(day), width: 1),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Less',
                style: GoogleFonts.urbanist(
                  color: secondaryText,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              ...[0.08, 0.22, 0.45, 0.75].map((a) {
                return Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: a),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.22),
                      width: 1,
                    ),
                  ),
                );
              }),
              const SizedBox(width: 2),
              Text(
                'More',
                style: GoogleFonts.urbanist(
                  color: secondaryText,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeeklyTrendCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final _TrendWindowStats current;
  final _TrendWindowStats previous;
  final Color accent;
  final Color surface;
  final Color border;
  final Color primaryText;
  final Color secondaryText;
  final List<BoxShadow> shadow;

  const _WeeklyTrendCard({
    required this.title,
    required this.subtitle,
    required this.current,
    required this.previous,
    required this.accent,
    required this.surface,
    required this.border,
    required this.primaryText,
    required this.secondaryText,
    required this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    final delta =
        (current.percent - previous.percent).clamp(-100, 100).toInt();
    final deltaLabel = '${delta >= 0 ? '+' : ''}$delta%';

    String percentLabel(_TrendWindowStats stats) {
      if (stats.possible <= 0) return '—';
      return '${stats.percent}%';
    }

    String countLabel(_TrendWindowStats stats) {
      if (stats.possible <= 0) return 'No data';
      return '${stats.completed}/${stats.possible}';
    }

    double ratio(_TrendWindowStats stats) {
      if (stats.possible <= 0) return 0.0;
      return (stats.completed / stats.possible).clamp(0.0, 1.0);
    }

    Widget metric(String label, _TrendWindowStats stats) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withValues(alpha: 0.10)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.urbanist(
                color: secondaryText,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              percentLabel(stats),
              style: GoogleFonts.urbanist(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 10),
            _MiniProgressBar(
              value: ratio(stats),
              accent: accent,
              trackColor: accent.withValues(alpha: 0.10),
            ),
            const SizedBox(height: 8),
            Text(
              countLabel(stats),
              style: GoogleFonts.urbanist(
                color: secondaryText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
        boxShadow: shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.urbanist(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.urbanist(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: accent.withValues(alpha: 0.18)),
                ),
                child: Text(
                  deltaLabel,
                  style: GoogleFonts.urbanist(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: metric('Current', current)),
              const SizedBox(width: 12),
              Expanded(child: metric('Previous', previous)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnalyticsChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final int percent;
  final List<_ChartPoint> points;
  final Color accent;
  final Color surface;
  final Color border;
  final Color primaryText;
  final Color secondaryText;
  final List<BoxShadow> shadow;

  const _AnalyticsChartCard({
    required this.title,
    required this.subtitle,
    required this.percent,
    required this.points,
    required this.accent,
    required this.surface,
    required this.border,
    required this.primaryText,
    required this.secondaryText,
    required this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
        boxShadow: shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.urbanist(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.urbanist(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$percent%',
                style: GoogleFonts.urbanist(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _InteractiveLineChart(
            points: points,
            accent: accent,
            surface: surface,
            border: border,
            primaryText: primaryText,
            secondaryText: secondaryText,
          ),
        ],
      ),
    );
  }
}

class _InteractiveLineChart extends StatefulWidget {
  final List<_ChartPoint> points;
  final Color accent;
  final Color surface;
  final Color border;
  final Color primaryText;
  final Color secondaryText;

  const _InteractiveLineChart({
    required this.points,
    required this.accent,
    required this.surface,
    required this.border,
    required this.primaryText,
    required this.secondaryText,
  });

  @override
  State<_InteractiveLineChart> createState() => _InteractiveLineChartState();
}

class _InteractiveLineChartState extends State<_InteractiveLineChart> {
  int _selectedIndex = 0;

  @override
  void didUpdateWidget(covariant _InteractiveLineChart oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.points.isEmpty) {
      _selectedIndex = 0;
      return;
    }

    if (oldWidget.points.length != widget.points.length) {
      _selectedIndex = widget.points.length - 1;
      return;
    }

    if (_selectedIndex >= widget.points.length) {
      _selectedIndex = widget.points.length - 1;
    }
  }

  int _indexForDx(double dx, double width, int count) {
    if (count <= 1) return 0;

    const padX = 12.0;
    final usable = (width - padX * 2).clamp(1.0, double.infinity);
    final step = usable / (count - 1);

    return ((dx - padX) / step).round().clamp(0, count - 1);
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.points;

    if (points.isEmpty) {
      return Container(
        height: 164,
        alignment: Alignment.center,
        child: Text(
          'No data yet',
          style: GoogleFonts.urbanist(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: widget.secondaryText,
          ),
        ),
      );
    }

    final shouldScroll = points.length > 12;
    final selected = points[_selectedIndex.clamp(0, points.length - 1)];
    final selectedPercent = selected.total == 0
        ? 0
        : ((selected.completed / selected.total) * 100).round();

    Widget buildChart(double width) {
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapDown: (details) {
          final next =
              _indexForDx(details.localPosition.dx, width, points.length);
          if (next == _selectedIndex) return;
          setState(() => _selectedIndex = next);
        },
        child: SizedBox(
          width: width,
          height: 140,
          child: CustomPaint(
            painter: _LineChartPainter(
              points: points,
              accent: widget.accent,
              secondaryText: widget.secondaryText,
              selectedIndex: _selectedIndex,
            ),
          ),
        ),
      );
    }

    Widget chart;
    if (shouldScroll) {
      final width = (points.length - 1) * 28.0 + 24.0;
      chart = SizedBox(
        height: 140,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: buildChart(width),
        ),
      );
    } else {
      chart = LayoutBuilder(
        builder: (context, constraints) {
          return buildChart(constraints.maxWidth);
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        chart,
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: widget.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: widget.border),
          ),
          child: Row(
            children: [
              Text(
                selected.label,
                style: GoogleFonts.urbanist(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: widget.secondaryText,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${selected.completed}/${selected.total} completed',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.urbanist(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: widget.primaryText,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$selectedPercent%',
                style: GoogleFonts.urbanist(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                  color: widget.accent,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<_ChartPoint> points;
  final Color accent;
  final Color secondaryText;
  final int selectedIndex;

  const _LineChartPainter({
    required this.points,
    required this.accent,
    required this.secondaryText,
    required this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const padX = 12.0;
    const padTop = 10.0;
    const padBottom = 26.0; // room for labels

    final chartHeight =
        (size.height - padTop - padBottom).clamp(1.0, double.infinity);
    final bottomY = padTop + chartHeight;

    final gridPaint = Paint()
      ..color = accent.withValues(alpha: 0.08)
      ..strokeWidth = 1;

    for (final frac in [0.25, 0.5, 0.75]) {
      final y = padTop + chartHeight * (1 - frac);
      canvas.drawLine(Offset(padX, y), Offset(size.width - padX, y), gridPaint);
    }

    if (points.isEmpty) return;

    final count = points.length;
    final usableW = (size.width - padX * 2).clamp(1.0, double.infinity);
    final step = count <= 1 ? 0.0 : usableW / (count - 1);

    final offsets = List.generate(count, (i) {
      final x = count <= 1 ? size.width / 2 : padX + step * i;
      final v = points[i].value.clamp(0.0, 1.0);
      final y = padTop + chartHeight * (1 - v);
      return Offset(x, y);
    });

    final sel = selectedIndex.clamp(0, count - 1);

    final guidePaint = Paint()
      ..color = accent.withValues(alpha: 0.12)
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(offsets[sel].dx, padTop),
      Offset(offsets[sel].dx, bottomY),
      guidePaint,
    );

    final areaPath = Path()..moveTo(offsets.first.dx, bottomY);
    for (final o in offsets) {
      areaPath.lineTo(o.dx, o.dy);
    }
    areaPath.lineTo(offsets.last.dx, bottomY);
    areaPath.close();

    canvas.drawPath(
      areaPath,
      Paint()
        ..color = accent.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill,
    );

    final linePath = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (int i = 1; i < offsets.length; i++) {
      linePath.lineTo(offsets[i].dx, offsets[i].dy);
    }

    canvas.drawPath(
      linePath,
      Paint()
        ..color = accent
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final dimDotPaint = Paint()..color = accent.withValues(alpha: 0.45);
    final selDotPaint = Paint()..color = accent;

    for (int i = 0; i < offsets.length; i++) {
      if (i == sel) continue;
      canvas.drawCircle(offsets[i], 2.4, dimDotPaint);
    }

    canvas.drawCircle(offsets[sel], 4.4, selDotPaint);
    canvas.drawCircle(
      offsets[sel],
      2.0,
      Paint()..color = Colors.white,
    );

    final labelStep = count <= 12 ? 1 : (count / 8).ceil();

    for (int i = 0; i < count; i++) {
      final showLabel = i == count - 1 || i % labelStep == 0;
      if (!showLabel) continue;

      final painter = TextPainter(
        text: TextSpan(
          text: points[i].label,
          style: GoogleFonts.urbanist(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: secondaryText,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: step == 0 ? 40 : step * 1.3);

      final x = (offsets[i].dx - painter.width / 2)
          .clamp(0.0, size.width - painter.width);
      final y = size.height - 16;

      painter.paint(canvas, Offset(x, y));
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.accent != accent ||
        oldDelegate.secondaryText != secondaryText ||
        oldDelegate.selectedIndex != selectedIndex;
  }
}
