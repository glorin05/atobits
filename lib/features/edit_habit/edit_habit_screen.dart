import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/habit_icon_registry.dart';
import '../../data/models/habit.dart';
import '../../data/providers/habit_provider.dart';

class EditHabitScreen extends StatefulWidget {
  final Habit habit;
  const EditHabitScreen({super.key, required this.habit});

  @override
  State<EditHabitScreen> createState() => _EditHabitScreenState();
}

class _EditHabitScreenState extends State<EditHabitScreen> {
  late TextEditingController titleController;
  late TextEditingController descriptionController;
  late String selectedCategory;
  late String selectedEmoji;
  late String selectedTime;

  late String scheduleType;
  late List<int> scheduleDaysOfWeek;
  late int scheduleTimesPerWeek;
  late int scheduleIntervalDays;

  static const List<String> _categories = [
    'Health',
    'Fitness',
    'Mindfulness',
    'Learning',
    'Productivity',
    'Self-Care',
    'Other',
  ];

  static const List<String> _times = [
    'Morning',
    'Afternoon',
    'Evening',
    'Night',
    'Anytime',
  ];

  late bool reminderEnabled;
  late TimeOfDay reminderTime;
  bool _reminderTimePickedThisSession = false;

  static const List<String> _scheduleOptions = [
    'daily',
    'weekdays',
    'times_per_week',
    'interval',
  ];

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.habit.title);
    descriptionController =
        TextEditingController(text: widget.habit.description);
    selectedCategory = _categories.contains(widget.habit.category)
        ? widget.habit.category
        : 'Other';
    selectedEmoji = HabitIconRegistry.keyFromStored(widget.habit.emoji);
    selectedTime = _times.contains(widget.habit.timeOfDay)
        ? widget.habit.timeOfDay
        : 'Anytime';

    reminderEnabled = widget.habit.reminderEnabled;
    reminderTime = _parseReminderTime(widget.habit.reminderTime) ??
        _defaultReminderTimeFor(selectedTime);

    scheduleType = widget.habit.scheduleType.trim().isEmpty
        ? 'daily'
        : widget.habit.scheduleType.trim();
    scheduleDaysOfWeek = widget.habit.scheduleDaysOfWeek.toList();
    scheduleTimesPerWeek = widget.habit.scheduleTimesPerWeek;
    scheduleIntervalDays = widget.habit.scheduleIntervalDays;
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

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

  TimeOfDay? _parseReminderTime(String? hm) {
    if (hm == null) return null;
    final parts = hm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    if (h < 0 || h > 23) return null;
    if (m < 0 || m > 59) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _toHm(TimeOfDay t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Future<void> _pickReminderTime(Color primaryBlue) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: reminderTime,
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
    setState(() {
      _reminderTimePickedThisSession = true;
      reminderTime = picked;
    });
  }

  void _openIconPicker(
    Color surface,
    Color border,
    Color primaryBlue,
    Color primaryText,
    Color secondaryText,
  ) {
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
                        final selected = selectedEmoji == item.key;

                        return GestureDetector(
                          onTap: () {
                            setState(() => selectedEmoji = item.key);
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
                              child: Icon(
                                item.icon,
                                size: 24,
                                color: selected ? primaryBlue : primaryText,
                              ),
                            ),
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
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
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
                  'Edit Habit',
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
              controller: titleController,
              style: GoogleFonts.urbanist(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: primaryText,
              ),
              decoration: InputDecoration(
                hintText: 'e.g. Morning jog',
                hintStyle: GoogleFonts.urbanist(
                  color: secondaryText,
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
                      HabitIconRegistry.iconFromStored(selectedEmoji),
                      size: 26,
                      color: primaryBlue,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openIconPicker(
                      surface,
                      border,
                      primaryBlue,
                      primaryText,
                      secondaryText,
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: Icon(
                      Icons.emoji_emotions_outlined,
                      color: primaryBlue,
                      size: 20,
                    ),
                    label: Text(
                      'Change icon',
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
              'Description',
              style: GoogleFonts.urbanist(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: secondaryText,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descriptionController,
              style: GoogleFonts.urbanist(
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: primaryText,
              ),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'What is this habit about?',
                hintStyle: GoogleFonts.urbanist(
                  color: secondaryText,
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
              'Category',
              style: GoogleFonts.urbanist(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: secondaryText,
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: selectedCategory,
              style: GoogleFonts.urbanist(
                color: primaryText,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: surface,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: border, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: primaryBlue, width: 2),
                ),
              ),
              items: _categories
                  .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => selectedCategory = value);
                }
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Time of day',
              style: GoogleFonts.urbanist(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: secondaryText,
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: selectedTime,
              style: GoogleFonts.urbanist(
                color: primaryText,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: surface,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: border, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: primaryBlue, width: 2),
                ),
              ),
              items: _times
                  .map((time) =>
                      DropdownMenuItem(value: time, child: Text(time)))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    selectedTime = value;
                    if (reminderEnabled &&
                        !_reminderTimePickedThisSession &&
                        widget.habit.reminderTime == null) {
                      reminderTime = _defaultReminderTimeFor(selectedTime);
                    }
                  });
                }
              },
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
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _scheduleOptions.map((opt) {
                final isSelected = scheduleType == opt;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      scheduleType = opt;
                      if (scheduleType == 'weekdays' &&
                          scheduleDaysOfWeek.isEmpty) {
                        scheduleDaysOfWeek = <int>[1, 2, 3, 4, 5];
                      }
                      if (scheduleType == 'interval' &&
                          scheduleIntervalDays < 1) {
                        scheduleIntervalDays = 2;
                      }
                      if (scheduleType == 'times_per_week' &&
                          scheduleTimesPerWeek < 1) {
                        scheduleTimesPerWeek = 3;
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
            if (scheduleType == 'weekdays') ...[
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
                    final selected = scheduleDaysOfWeek.contains(day);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          final next = List<int>.from(scheduleDaysOfWeek);
                          if (selected) {
                            next.remove(day);
                          } else {
                            next.add(day);
                          }
                          next.sort();
                          if (next.isEmpty) return;
                          scheduleDaysOfWeek = next;
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
            if (scheduleType == 'times_per_week') ...[
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
                        '$scheduleTimesPerWeek times per week',
                        style: GoogleFonts.urbanist(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          color: primaryText,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: scheduleTimesPerWeek <= 1
                          ? null
                          : () => setState(() => scheduleTimesPerWeek--),
                      icon:
                          Icon(Icons.remove_circle_outline, color: primaryBlue),
                    ),
                    IconButton(
                      onPressed: scheduleTimesPerWeek >= 7
                          ? null
                          : () => setState(() => scheduleTimesPerWeek++),
                      icon: Icon(Icons.add_circle_outline, color: primaryBlue),
                    ),
                  ],
                ),
              ),
            ],
            if (scheduleType == 'interval') ...[
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
                        'Every $scheduleIntervalDays days',
                        style: GoogleFonts.urbanist(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          color: primaryText,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: scheduleIntervalDays <= 1
                          ? null
                          : () => setState(() => scheduleIntervalDays--),
                      icon:
                          Icon(Icons.remove_circle_outline, color: primaryBlue),
                    ),
                    IconButton(
                      onPressed: scheduleIntervalDays >= 30
                          ? null
                          : () => setState(() => scheduleIntervalDays++),
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
                    value: reminderEnabled,
                    activeThumbColor: primaryBlue,
                    onChanged: (v) {
                      setState(() {
                        reminderEnabled = v;
                        if (reminderEnabled &&
                            widget.habit.reminderTime == null) {
                          reminderTime = _defaultReminderTimeFor(selectedTime);
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (reminderEnabled) ...[
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
                        'Daily at ${reminderTime.format(context)}',
                        style: GoogleFonts.urbanist(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          color: primaryText,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _pickReminderTime(primaryBlue),
                      child: Text(
                        'Change',
                        style: GoogleFonts.urbanist(
                          color: primaryBlue,
                          fontWeight: FontWeight.w900,
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _saveChanges,
                child: Text(
                  'Save Changes',
                  style: GoogleFonts.urbanist(
                    color: Colors.white,
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

  Future<void> _saveChanges() async {
    HapticFeedback.mediumImpact();
    final habitProvider = Provider.of<HabitProvider>(context, listen: false);

    final updatedHabit = Habit(
      id: widget.habit.id,
      title: titleController.text,
      description: descriptionController.text,
      category: selectedCategory,
      emoji: selectedEmoji,
      timeOfDay: selectedTime,
      reminderEnabled: reminderEnabled,
      reminderTime: reminderEnabled ? _toHm(reminderTime) : null,
      createdAt: widget.habit.createdAt,
      scheduleType: scheduleType,
      scheduleDaysOfWeek:
          scheduleType == 'weekdays' ? scheduleDaysOfWeek : const <int>[],
      scheduleTimesPerWeek: scheduleTimesPerWeek,
      scheduleIntervalDays: scheduleIntervalDays,
      scheduleAnchorDate: scheduleType == 'interval'
          ? (widget.habit.scheduleAnchorDate ?? _dateOnly(DateTime.now()))
          : null,
    );

    await habitProvider.updateHabit(updatedHabit);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Habit updated successfully!')),
    );
    Navigator.pop(context);
  }
}
