import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../data/providers/habit_provider.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _intentionsController = TextEditingController();
  final TextEditingController _happeningsController = TextEditingController();
  final TextEditingController _gratefulForController = TextEditingController();
  final TextEditingController _tomorrowBetterController =
      TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  int _mood = 0; // 0 = unset, 1..5 = very low .. very high

  final List<JournalEntry> _entries = [];

  static const _storageKey = 'journal_entries_v1';

  @override
  void initState() {
    super.initState();
    _loadEntries();

    void onDraftChanged() {
      if (!mounted) return;
      setState(() {});
    }

    _categoryController.addListener(onDraftChanged);
    _intentionsController.addListener(onDraftChanged);
    _happeningsController.addListener(onDraftChanged);
    _gratefulForController.addListener(onDraftChanged);
    _tomorrowBetterController.addListener(onDraftChanged);
    _notesController.addListener(onDraftChanged);
  }

  Future<void> _loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) return;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;

      final loaded = decoded
          .whereType<Map<String, dynamic>>()
          .map(JournalEntry.fromJson)
          .toList();

      if (!mounted) return;
      setState(() {
        _entries
          ..clear()
          ..addAll(loaded);
      });
    } catch (_) {
      // Ignore bad local data; don't crash the app.
    }
  }

  Future<void> _saveEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(_entries.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, payload);
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _intentionsController.dispose();
    _happeningsController.dispose();
    _gratefulForController.dispose();
    _tomorrowBetterController.dispose();
    _notesController.dispose();
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
    final cardShadow =
        isDark ? AppThemeDark.softCardShadow : AppTheme.softCardShadow;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          'Journal',
          style: GoogleFonts.urbanist(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
            color: primaryText,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                children: [
                  const SizedBox(height: 6),
                  Text(
                    'Today’s entry',
                    style: GoogleFonts.urbanist(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: primaryText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildMoodCard(
                    primaryBlue: primaryBlue,
                    surface: surface,
                    border: border,
                    shadow: cardShadow,
                    primaryText: primaryText,
                    secondaryText: secondaryText,
                  ),
                  const SizedBox(height: 12),
                  _buildPromptCard(
                    icon: Icons.category_outlined,
                    title: 'Category',
                    hint: 'Work, Relationships, Health…',
                    controller: _categoryController,
                    bg: bg,
                    primaryBlue: primaryBlue,
                    surface: surface,
                    border: border,
                    shadow: cardShadow,
                    primaryText: primaryText,
                    secondaryText: secondaryText,
                    minLines: 1,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 12),
                  _buildPromptCard(
                    icon: Icons.center_focus_strong,
                    title: 'Intentions',
                    hint: 'What do you want to focus on today?',
                    controller: _intentionsController,
                    bg: bg,
                    primaryBlue: primaryBlue,
                    surface: surface,
                    border: border,
                    shadow: cardShadow,
                    primaryText: primaryText,
                    secondaryText: secondaryText,
                  ),
                  const SizedBox(height: 12),
                  _buildPromptCard(
                    icon: Icons.directions_run,
                    title: 'Happenings',
                    hint: 'What happened today?',
                    controller: _happeningsController,
                    bg: bg,
                    primaryBlue: primaryBlue,
                    surface: surface,
                    border: border,
                    shadow: cardShadow,
                    primaryText: primaryText,
                    secondaryText: secondaryText,
                  ),
                  const SizedBox(height: 12),
                  _buildPromptCard(
                    icon: Icons.volunteer_activism_outlined,
                    title: 'Grateful for',
                    hint: '3 small things you’re grateful for…',
                    controller: _gratefulForController,
                    bg: bg,
                    primaryBlue: primaryBlue,
                    surface: surface,
                    border: border,
                    shadow: cardShadow,
                    primaryText: primaryText,
                    secondaryText: secondaryText,
                  ),
                  const SizedBox(height: 12),
                  _buildPromptCard(
                    icon: Icons.auto_awesome_outlined,
                    title: 'How can I make tomorrow better?',
                    hint: 'One small change for tomorrow…',
                    controller: _tomorrowBetterController,
                    bg: bg,
                    primaryBlue: primaryBlue,
                    surface: surface,
                    border: border,
                    shadow: cardShadow,
                    primaryText: primaryText,
                    secondaryText: secondaryText,
                  ),
                  const SizedBox(height: 12),
                  _buildPromptCard(
                    icon: Icons.edit_note_outlined,
                    title: 'Notes',
                    hint: 'Anything else on your mind?',
                    controller: _notesController,
                    bg: bg,
                    primaryBlue: primaryBlue,
                    surface: surface,
                    border: border,
                    shadow: cardShadow,
                    primaryText: primaryText,
                    secondaryText: secondaryText,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _hasDraftContent ? _addEntry : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Save Entry',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'My Journey',
                    style: GoogleFonts.urbanist(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                      color: primaryText,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_entries.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.note_outlined,
                              size: 48,
                              color: primaryBlue.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No journal entries yet',
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
                    ...List.generate(_entries.length, (index) {
                      final entryIndex = _entries.length - 1 - index;
                      final entry = _entries[entryIndex];
                      return _buildEntryCard(
                        entry,
                        surface: surface,
                        primaryText: primaryText,
                        secondaryText: secondaryText,
                        primaryBlue: primaryBlue,
                        border: border,
                        shadow: cardShadow,
                        onDelete: () => _deleteEntry(entryIndex),
                      );
                    }),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _hasDraftContent {
    return _mood != 0 ||
        _categoryController.text.trim().isNotEmpty ||
        _intentionsController.text.trim().isNotEmpty ||
        _happeningsController.text.trim().isNotEmpty ||
        _gratefulForController.text.trim().isNotEmpty ||
        _tomorrowBetterController.text.trim().isNotEmpty ||
        _notesController.text.trim().isNotEmpty;
  }

  void _clearDraft() {
    setState(() {
      _mood = 0;
      _categoryController.clear();
      _intentionsController.clear();
      _happeningsController.clear();
      _gratefulForController.clear();
      _tomorrowBetterController.clear();
      _notesController.clear();
    });
  }

  Widget _buildMoodCard({
    required Color primaryBlue,
    required Color surface,
    required Color border,
    required List<BoxShadow> shadow,
    required Color primaryText,
    required Color secondaryText,
  }) {
    const moodIcons = <IconData>[
      Icons.sentiment_very_dissatisfied_rounded,
      Icons.sentiment_dissatisfied_rounded,
      Icons.sentiment_neutral_rounded,
      Icons.sentiment_satisfied_rounded,
      Icons.sentiment_very_satisfied_rounded,
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.emoji_emotions_outlined,
                color: primaryBlue,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                'Mood',
                style: GoogleFonts.urbanist(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                  color: primaryText,
                ),
              ),
              const Spacer(),
              Text(
                _mood == 0 ? 'Unset' : 'Set',
                style: GoogleFonts.urbanist(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: secondaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(moodIcons.length, (index) {
              final value = index + 1;
              final isSelected = _mood == value;
              return ChoiceChip(
                label: Icon(
                  moodIcons[index],
                  size: 22,
                  color: isSelected ? primaryBlue : secondaryText,
                ),
                selected: isSelected,
                onSelected: (_) {
                  setState(() {
                    _mood = isSelected ? 0 : value;
                  });
                },
                selectedColor: primaryBlue.withValues(alpha: 0.18),
                backgroundColor: surface,
                side: BorderSide(color: isSelected ? primaryBlue : border),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildPromptCard({
    required IconData icon,
    required String title,
    required String hint,
    required TextEditingController controller,
    required Color bg,
    required Color primaryBlue,
    required Color surface,
    required Color border,
    required List<BoxShadow> shadow,
    required Color primaryText,
    required Color secondaryText,
    int minLines = 2,
    int maxLines = 6,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: primaryBlue, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.urbanist(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                    color: primaryText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            minLines: minLines,
            maxLines: maxLines,
            style: GoogleFonts.urbanist(
              color: primaryText,
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.urbanist(
                color: secondaryText,
                fontWeight: FontWeight.w600,
              ),
              filled: true,
              fillColor: bg,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: border, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: primaryBlue, width: 1.8),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryCard(
    JournalEntry entry, {
    required Color surface,
    required Color primaryText,
    required Color secondaryText,
    required Color primaryBlue,
    required Color border,
    required List<BoxShadow> shadow,
    required VoidCallback onDelete,
  }) {
    final chips = <Widget>[];

    if (entry.mood != 0) {
      chips.add(_entryChip(
        entry.moodEmoji,
        primaryBlue: primaryBlue,
        border: border,
      ));
    }

    if (entry.category.trim().isNotEmpty) {
      chips.add(_entryChip(
        entry.category.trim(),
        primaryBlue: primaryBlue,
        border: border,
      ));
    }

    final preview = entry.previewText;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.formattedDate,
                  style: GoogleFonts.urbanist(
                    fontSize: 12,
                    color: secondaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: onDelete,
                tooltip: 'Delete',
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: secondaryText,
                  size: 20,
                ),
              ),
            ],
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chips,
            ),
          ],
          if (preview.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              preview,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.urbanist(
                fontSize: 14,
                color: primaryText,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            Text(
              'Empty entry',
              style: GoogleFonts.urbanist(
                fontSize: 14,
                color: secondaryText,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ]
        ],
      ),
    );
  }

  void _deleteEntry(int index) {
    if (index < 0 || index >= _entries.length) return;
    HapticFeedback.mediumImpact();
    final removed = _entries[index];
    setState(() => _entries.removeAt(index));
    _saveEntries();

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Entry deleted'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            if (!mounted) return;
            setState(() => _entries.insert(index, removed));
            _saveEntries();
          },
        ),
      ),
    );
  }

  Widget _entryChip(
    String text, {
    required Color primaryBlue,
    required Color border,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: primaryBlue.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        style: GoogleFonts.urbanist(
          color: primaryBlue,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  void _addEntry() {
    final entry = JournalEntry(
      mood: _mood,
      category: _categoryController.text.trim(),
      intentions: _intentionsController.text.trim(),
      happenings: _happeningsController.text.trim(),
      gratefulFor: _gratefulForController.text.trim(),
      tomorrowBetter: _tomorrowBetterController.text.trim(),
      notes: _notesController.text.trim(),
      timestamp: DateTime.now(),
    );

    if (entry.isEmpty) return;

    HapticFeedback.mediumImpact();

    FocusScope.of(context).unfocus();

    setState(() {
      _entries.add(entry);
    });

    _clearDraft();
    _saveEntries();

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Entry saved'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class JournalEntry {
  final int mood; // 0 unset, 1..5
  final String category;
  final String intentions;
  final String happenings;
  final String gratefulFor;
  final String tomorrowBetter;
  final String notes;
  final DateTime timestamp;

  JournalEntry({
    required this.mood,
    required this.category,
    required this.intentions,
    required this.happenings,
    required this.gratefulFor,
    required this.tomorrowBetter,
    required this.notes,
    required this.timestamp,
  });

  bool get isEmpty {
    return mood == 0 &&
        category.trim().isEmpty &&
        intentions.trim().isEmpty &&
        happenings.trim().isEmpty &&
        gratefulFor.trim().isEmpty &&
        tomorrowBetter.trim().isEmpty &&
        notes.trim().isEmpty;
  }

  String get moodEmoji {
    switch (mood) {
      case 1:
        return '😞';
      case 2:
        return '😕';
      case 3:
        return '😐';
      case 4:
        return '🙂';
      case 5:
        return '😄';
      default:
        return '';
    }
  }

  String get previewText {
    final parts = <String>[];

    if (intentions.trim().isNotEmpty) {
      parts.add('Intentions: ${intentions.trim()}');
    }
    if (happenings.trim().isNotEmpty) {
      parts.add('Happenings: ${happenings.trim()}');
    }
    if (gratefulFor.trim().isNotEmpty) {
      parts.add('Grateful: ${gratefulFor.trim()}');
    }
    if (tomorrowBetter.trim().isNotEmpty) {
      parts.add('Tomorrow: ${tomorrowBetter.trim()}');
    }
    if (notes.trim().isNotEmpty) {
      parts.add(notes.trim());
    }

    return parts.join('\n');
  }

  Map<String, dynamic> toJson() {
    return {
      'mood': mood,
      'category': category,
      'intentions': intentions,
      'happenings': happenings,
      'gratefulFor': gratefulFor,
      'tomorrowBetter': tomorrowBetter,
      'notes': notes,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    final legacyContent = (json['content'] ?? '').toString();

    final rawMood = json['mood'];
    final mood = rawMood is num
        ? rawMood.toInt()
        : int.tryParse((rawMood ?? '').toString()) ?? 0;

    final notes = (json['notes'] ?? '').toString().trim().isNotEmpty
        ? (json['notes'] ?? '').toString()
        : legacyContent;

    return JournalEntry(
      mood: mood.clamp(0, 5).toInt(),
      category: (json['category'] ?? '').toString(),
      intentions: (json['intentions'] ?? '').toString(),
      happenings: (json['happenings'] ?? '').toString(),
      gratefulFor: (json['gratefulFor'] ?? '').toString(),
      tomorrowBetter: (json['tomorrowBetter'] ?? '').toString(),
      notes: notes,
      timestamp: DateTime.tryParse((json['timestamp'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  String get formattedDate =>
      '${timestamp.day} ${_monthName(timestamp.month)} ${timestamp.year}';

  static String _monthName(int month) {
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
      'Dec'
    ];
    return months[(month - 1).clamp(0, 11).toInt()];
  }
}
