import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/habit_icon_registry.dart';
import '../../data/models/habit.dart';
import '../../data/providers/habit_provider.dart';

class AddHabitScreen extends StatefulWidget {
  const AddHabitScreen({super.key});

  @override
  State<AddHabitScreen> createState() => _AddHabitScreenState();
}

class _AddHabitScreenState extends State<AddHabitScreen> {
  final _titleController = TextEditingController();
  String _selectedIconKey = HabitIconRegistry.defaultKey;
  String _selectedCategory = 'Health';
  String _selectedTime = 'Morning';

  String _scheduleType = 'daily';
  List<int> _scheduleDaysOfWeek = <int>[1, 2, 3, 4, 5];
  int _scheduleTimesPerWeek = 3;
  int _scheduleIntervalDays = 2;

  bool _reminderEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 8, minute: 0);

  final List<String> _categories = [
    'Health',
    'Fitness',
    'Mindfulness',
    'Learning',
    'Productivity',
    'Self-Care'
  ];
  final List<String> _times = ['Morning', 'Afternoon', 'Evening', 'Anytime'];

  static const List<String> _scheduleOptions = [
    'daily',
    'weekdays',
    'times_per_week',
    'interval',
  ];

  String _scheduleLabel(String key) {
    switch (key) {
      case 'weekdays':
        return 'Days';
      case 'times_per_week':
        return 'x/Week';
      case 'interval':
        return 'Interval';
      case 'daily':
      default:
        return 'Daily';
    }
  }

  List<String> _weekdayLabels() => const ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  TimeOfDay _defaultReminderTimeFor(String bestTime) {
    switch (bestTime.trim().toLowerCase()) {
      case 'morning':
        return const TimeOfDay(hour: 8, minute: 0);
      case 'afternoon':
        return const TimeOfDay(hour: 13, minute: 0);
      case 'evening':
        return const TimeOfDay(hour: 19, minute: 0);
      case 'night':
        return const TimeOfDay(hour: 21, minute: 0);
      default:
        return const TimeOfDay(hour: 9, minute: 0);
    }
  }

  String _toHm(TimeOfDay t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _pickReminderTime(Color primaryBlue, Color primaryText) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      helpText: 'Select reminder time',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme:
                Theme.of(context).colorScheme.copyWith(primary: primaryBlue),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked == null) return;
    setState(() => _reminderTime = picked);
  }

  void _openIconPicker(Color surface, Color border, Color primaryBlue,
      Color primaryText, Color secondaryText) {
    final searchController = TextEditingController();
    var filtered = List<HabitIconOption>.from(HabitIconRegistry.options);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.72,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              decoration: BoxDecoration(
                color: surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose icon',
                    style: GoogleFonts.urbanist(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                      color: primaryText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: searchController,
                    style: GoogleFonts.urbanist(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: primaryText,
                    ),
                    onChanged: (query) {
                      setModalState(() {
                        final q = query.toLowerCase().trim();
                        filtered = HabitIconRegistry.search(q);
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search icon (water, run, sleep...)',
                      hintStyle: GoogleFonts.urbanist(
                        color: secondaryText,
                        fontWeight: FontWeight.w600,
                      ),
                      prefixIcon: Icon(Icons.search, color: secondaryText),
                      filled: true,
                      fillColor: primaryBlue.withValues(alpha: 0.06),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primaryBlue, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: GridView.builder(
                      itemCount: filtered.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1,
                      ),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final selected = _selectedIconKey == item.key;

                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedIconKey = item.key);
                            Navigator.pop(context);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: selected
                                  ? primaryBlue.withValues(alpha: 0.14)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: selected ? primaryBlue : border),
                            ),
                            child: Center(
                                child: Icon(item.icon,
                                    size: 24,
                                    color:
                                        selected ? primaryBlue : primaryText)),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

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
    final warmWhite = isDark ? AppThemeDark.warmWhite : AppTheme.warmWhite;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 20,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: secondaryText.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'New Habit',
                  style: GoogleFonts.urbanist(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.0,
                    color: primaryText,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: warmWhite,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: border),
                    ),
                    child: Icon(Icons.close, size: 20, color: primaryText),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Habit name',
              style: GoogleFonts.urbanist(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: secondaryText,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _titleController,
              style: GoogleFonts.urbanist(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: primaryText,
              ),
              decoration: InputDecoration(
                hintText: 'e.g. drink 2L water',
                hintStyle: GoogleFonts.urbanist(
                  color: mutedText,
                  fontWeight: FontWeight.w600,
                ),
                filled: true,
                fillColor: surface,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: border, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: primaryBlue, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Icon',
              style: GoogleFonts.urbanist(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: secondaryText,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: primaryBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primaryBlue),
                    boxShadow: [
                      BoxShadow(
                        color: primaryBlue.withValues(alpha: 0.22),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      HabitIconRegistry.iconFromStored(_selectedIconKey),
                      size: 26,
                      color: primaryBlue,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openIconPicker(surface, border,
                        primaryBlue, primaryText, secondaryText),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: Icon(Icons.emoji_emotions_outlined,
                        color: primaryBlue, size: 20),
                    label: Text(
                      'Choose icon',
                      style: GoogleFonts.urbanist(
                        color: primaryText,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Category',
              style: GoogleFonts.urbanist(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: secondaryText,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((category) {
                final isSelected = _selectedCategory == category;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = category),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? primaryBlue : surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isSelected ? primaryBlue : border,
                      ),
                    ),
                    child: Text(
                      category,
                      style: GoogleFonts.urbanist(
                        color: isSelected ? Colors.white : primaryText,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Text(
              'Best time',
              style: GoogleFonts.urbanist(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: secondaryText,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _times.map((time) {
                final isSelected = _selectedTime == time;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTime = time),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? primaryBlue : surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isSelected ? primaryBlue : border,
                      ),
                    ),
                    child: Text(
                      time,
                      style: GoogleFonts.urbanist(
                        color: isSelected ? Colors.white : primaryText,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Text(
              'Schedule',
              style: GoogleFonts.urbanist(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: secondaryText,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _scheduleOptions.map((opt) {
                final isSelected = _scheduleType == opt;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _scheduleType = opt;
                      if (_scheduleType == 'weekdays' &&
                          _scheduleDaysOfWeek.isEmpty) {
                        _scheduleDaysOfWeek = <int>[1, 2, 3, 4, 5];
                      }
                      if (_scheduleType == 'interval' &&
                          _scheduleIntervalDays < 1) {
                        _scheduleIntervalDays = 2;
                      }
                      if (_scheduleType == 'times_per_week' &&
                          _scheduleTimesPerWeek < 1) {
                        _scheduleTimesPerWeek = 3;
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? primaryBlue : surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isSelected ? primaryBlue : border,
                      ),
                    ),
                    child: Text(
                      _scheduleLabel(opt),
                      style: GoogleFonts.urbanist(
                        color: isSelected ? Colors.white : primaryText,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (_scheduleType == 'weekdays') ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (i) {
                    final day = i + 1;
                    final selected = _scheduleDaysOfWeek.contains(day);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          final next = List<int>.from(_scheduleDaysOfWeek);
                          if (selected) {
                            next.remove(day);
                          } else {
                            next.add(day);
                          }
                          next.sort();
                          if (next.isEmpty) return;
                          _scheduleDaysOfWeek = next;
                        });
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: selected
                              ? primaryBlue.withValues(alpha: 0.18)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected ? primaryBlue : border,
                            width: 1.2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _weekdayLabels()[i],
                            style: GoogleFonts.urbanist(
                              color: selected ? primaryBlue : primaryText,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
            if (_scheduleType == 'times_per_week') ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month_rounded,
                        color: primaryBlue, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$_scheduleTimesPerWeek times per week',
                        style: GoogleFonts.urbanist(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          color: primaryText,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _scheduleTimesPerWeek <= 1
                          ? null
                          : () => setState(() => _scheduleTimesPerWeek--),
                      icon:
                          Icon(Icons.remove_circle_outline, color: primaryBlue),
                    ),
                    IconButton(
                      onPressed: _scheduleTimesPerWeek >= 7
                          ? null
                          : () => setState(() => _scheduleTimesPerWeek++),
                      icon: Icon(Icons.add_circle_outline, color: primaryBlue),
                    ),
                  ],
                ),
              ),
            ],
            if (_scheduleType == 'interval') ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.repeat_rounded, color: primaryBlue, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Every $_scheduleIntervalDays days',
                        style: GoogleFonts.urbanist(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          color: primaryText,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _scheduleIntervalDays <= 1
                          ? null
                          : () => setState(() => _scheduleIntervalDays--),
                      icon:
                          Icon(Icons.remove_circle_outline, color: primaryBlue),
                    ),
                    IconButton(
                      onPressed: _scheduleIntervalDays >= 30
                          ? null
                          : () => setState(() => _scheduleIntervalDays++),
                      icon: Icon(Icons.add_circle_outline, color: primaryBlue),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
              ),
              child: Row(
                children: [
                  Icon(Icons.notifications_none_rounded,
                      color: primaryBlue, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Reminder',
                      style: GoogleFonts.urbanist(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: primaryText,
                      ),
                    ),
                  ),
                  Switch(
                    value: _reminderEnabled,
                    activeThumbColor: primaryBlue,
                    onChanged: (v) {
                      setState(() {
                        _reminderEnabled = v;
                        if (_reminderEnabled) {
                          _reminderTime =
                              _defaultReminderTimeFor(_selectedTime);
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_reminderEnabled) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.notifications_active_outlined,
                        color: primaryBlue, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Daily at ${_reminderTime.format(context)}',
                        style: GoogleFonts.urbanist(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: primaryText,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          _pickReminderTime(primaryBlue, primaryText),
                      child: Text(
                        'Change',
                        style: GoogleFonts.urbanist(
                          color: primaryBlue,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final title = _titleController.text.trim();
                  if (title.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Enter a habit name'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }

                  final habit = Habit(
                    title: title,
                    category: _selectedCategory,
                    emoji: _selectedIconKey,
                    timeOfDay: _selectedTime,
                    reminderEnabled: _reminderEnabled,
                    reminderTime:
                        _reminderEnabled ? _toHm(_reminderTime) : null,
                    scheduleType: _scheduleType,
                    scheduleDaysOfWeek: _scheduleType == 'weekdays'
                        ? _scheduleDaysOfWeek
                        : const <int>[],
                    scheduleTimesPerWeek: _scheduleTimesPerWeek,
                    scheduleIntervalDays: _scheduleIntervalDays,
                    scheduleAnchorDate: _scheduleType == 'interval'
                        ? _dateOnly(DateTime.now())
                        : null,
                  );

                  await context.read<HabitProvider>().addHabit(habit);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Save Habit',
                  style: GoogleFonts.urbanist(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
