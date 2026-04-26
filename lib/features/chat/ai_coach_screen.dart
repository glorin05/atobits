import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/theme/app_theme.dart';
import '../../core/theme/habit_icon_registry.dart';
import '../../core/utils/habit_fuzzy_matcher.dart';
import '../../core/utils/habit_title_sanitizer.dart';
import '../../core/utils/voice_transcript_cleaner.dart';
import '../../core/services/llm_service.dart';
import '../../data/models/habit.dart';
import '../../data/providers/habit_provider.dart';
import '../stats/stats_screen.dart';

class AICoachScreen extends StatefulWidget {
  final bool autoStartListening;
  final bool voiceOnly;

  const AICoachScreen({
    super.key,
    this.autoStartListening = false,
    this.voiceOnly = false,
  });

  @override
  State<AICoachScreen> createState() => _AICoachScreenState();
}

class _AICoachScreenState extends State<AICoachScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _voiceTranscriptScrollController = ScrollController();
  final LlmService _llmService = LlmService();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _speechReady = false;
  String? _speechLocaleId;
  bool _isListening = false;
  HabitProvider? _speechProvider;
  bool _speechSubmitted = false;
  String _voiceDraft = '';
  String _voiceUserSubtitle = '';
  String _voiceAssistantSubtitle = '';
  String _ttsSpokenText = '';
  int _ttsSpokenOffset = 0;
  int _ttsWordStart = 0;
  int _ttsWordEnd = 0;
  bool _autoListenStarted = false;
  int _autoListenToken = 0;

  bool _quickRepliesExpanded = true;

  String _journalContextLine = '';
  String _meditationContextLine = '';

  bool _ttsReady = false;
  bool _isSpeaking = false;
  bool _voiceMode = false;
  late final AnimationController _flowController;

  int _lastTranscriptAutoScrollMs = 0;
  String _lastTranscriptAutoScrollText = '';
  int _lastTranscriptAutoScrollOffset = -1;

  String _inlineIconCacheText = '';
  List<_InlineIconInsert> _inlineIconCache = const [];

  _PendingDeleteRequest? _pendingDelete;

  @override
  void initState() {
    super.initState();

    _voiceMode = widget.voiceOnly;

    _flowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    _initTts();

    const greeting = 'How can I assist you today?';
    _messages.add(const _ChatMessage(role: _Role.bot, text: greeting));

    _loadWellnessContext();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!widget.voiceOnly) return;
      if (!widget.autoStartListening) return;
      if (_autoListenStarted) return;
      _autoListenStarted = true;

      final provider = context.read<HabitProvider>();
      _toggleListening(provider);
    });
  }

  @override
  void dispose() {
    _autoListenToken++;
    unawaited(_speech.stop());
    unawaited(_tts.stop());
    _controller.dispose();
    _scrollController.dispose();
    _voiceTranscriptScrollController.dispose();
    _flowController.dispose();
    super.dispose();
  }

  void _resetVoiceTranscriptScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_voiceTranscriptScrollController.hasClients) return;
      try {
        _voiceTranscriptScrollController.jumpTo(0);
      } catch (_) {}
    });
  }

  void _maybeAutoScrollVoiceTranscript({
    required String fullText,
    required int spokenOffset,
    required TextStyle style,
    required double maxWidth,
    required double viewHeight,
    required double topPadding,
    required TextDirection textDirection,
    InlineSpan? measureText,
    int? measureCaretOffset,
  }) {
    if (!_isSpeaking) return;
    if (fullText.trim().isEmpty) return;

    final safe = spokenOffset.clamp(0, fullText.length);
    final now = DateTime.now().millisecondsSinceEpoch;

    // Throttle to avoid fighting the user or causing jank.
    if (now - _lastTranscriptAutoScrollMs < 90) return;
    if (_lastTranscriptAutoScrollText == fullText &&
        safe <= _lastTranscriptAutoScrollOffset) {
      return;
    }

    _lastTranscriptAutoScrollMs = now;
    _lastTranscriptAutoScrollText = fullText;
    _lastTranscriptAutoScrollOffset = safe;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_voiceTranscriptScrollController.hasClients) return;

      try {
        final measure = measureText ?? TextSpan(text: fullText, style: style);
        final plain = measure.toPlainText();
        var caretOffset = measureCaretOffset ?? safe;
        if (caretOffset < 0) caretOffset = 0;
        if (caretOffset > plain.length) caretOffset = plain.length;

        final painter = TextPainter(
          text: measure,
          textAlign: TextAlign.center,
          textDirection: textDirection,
          maxLines: null,
        )..layout(maxWidth: maxWidth);

        final caret = painter.getOffsetForCaret(
          TextPosition(offset: caretOffset),
          Rect.zero,
        );

        // Keep the "current" word area around ~30% from the top.
        final desired = topPadding + caret.dy - viewHeight * 0.30;
        final position = _voiceTranscriptScrollController.position;
        final clamped = desired.clamp(0.0, position.maxScrollExtent);

        if ((clamped - position.pixels).abs() < 10) return;

        _voiceTranscriptScrollController.animateTo(
          clamped,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
        );
      } catch (_) {
        // If layout isn't ready yet, ignore.
      }
    });
  }

  int _stableHash32(String input) {
    // FNV-1a 32-bit (stable across runs; avoids String.hashCode randomness).
    var hash = 0x811c9dc5;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash & 0xffffffff;
  }

  int _xorshift32(int x) {
    x &= 0xffffffff;
    x ^= (x << 13) & 0xffffffff;
    x ^= (x >> 17) & 0xffffffff;
    x ^= (x << 5) & 0xffffffff;
    return x & 0xffffffff;
  }

  bool _isWhitespaceUnit(int unit) {
    return unit == 0x20 || unit == 0x0a || unit == 0x09 || unit == 0x0d;
  }

  bool _isPunctuationUnit(int unit) {
    switch (unit) {
      case 0x2e: // .
      case 0x2c: // ,
      case 0x21: // !
      case 0x3f: // ?
      case 0x3a: // :
      case 0x3b: // ;
      case 0x29: // )
      case 0x5d: // ]
      case 0x7d: // }
      case 0x22: // "
      case 0x27: // '
      case 0x2019: // ’
        return true;
      default:
        return false;
    }
  }

  IconData _assistantMoodIcon(String text) {
    final t = text.toLowerCase();

    if (t.contains('sorry') || t.contains('apolog')) {
      return Icons.sentiment_dissatisfied_rounded;
    }
    if (t.contains('great') ||
        t.contains('awesome') ||
        t.contains('proud') ||
        t.contains('love') ||
        t.contains('amazing') ||
        t.contains('nice') ||
        t.contains('well done') ||
        t.contains('good job')) {
      return Icons.sentiment_very_satisfied_rounded;
    }
    if (t.contains('breathe') ||
        t.contains('calm') ||
        t.contains('relax') ||
        t.contains('meditat') ||
        t.contains('mindful')) {
      return Icons.self_improvement_rounded;
    }
    if (t.contains('?') ||
        t.contains('think') ||
        t.contains('consider') ||
        t.contains('plan') ||
        t.contains('goal')) {
      return Icons.psychology_alt_rounded;
    }

    return Icons.auto_awesome_rounded;
  }

  ({bool leadingSpace, bool trailingSpace}) _spacesForInsert(
    String text,
    int index,
  ) {
    final leadingSpace =
        index > 0 && !_isWhitespaceUnit(text.codeUnitAt(index - 1));
    final trailingSpace = index < text.length &&
        !_isWhitespaceUnit(text.codeUnitAt(index)) &&
        !_isPunctuationUnit(text.codeUnitAt(index));
    return (leadingSpace: leadingSpace, trailingSpace: trailingSpace);
  }

  List<_InlineIconInsert> _buildInlineIconInserts(String text) {
    if (text.trim().isEmpty) return const [];

    final inserts = <_InlineIconInsert>[];
    final seenKeys = <String>{};

    var rng = _stableHash32(text) ^ 0x9e3779b9;
    double nextDouble() {
      rng = _xorshift32(rng);
      return (rng & 0xffffffff) / 0xffffffff;
    }

    void addInsert(
      int index,
      IconData icon, {
      bool? leadingSpace,
      bool? trailingSpace,
    }) {
      if (index < 0) index = 0;
      if (index > text.length) index = text.length;

      final key =
          '$index:${icon.codePoint}:${icon.fontFamily}:${icon.fontPackage}';
      if (!seenKeys.add(key)) return;

      final s = _spacesForInsert(text, index);
      inserts.add(
        _InlineIconInsert(
          index: index,
          icon: icon,
          leadingSpace: leadingSpace ?? s.leadingSpace,
          trailingSpace: trailingSpace ?? s.trailingSpace,
        ),
      );
    }

    // Always lead with a single mood icon. (User asked for a few icons; this
    // keeps it expressive without clutter.)
    addInsert(
      0,
      _assistantMoodIcon(text),
      leadingSpace: false,
      trailingSpace: true,
    );

    // Keyword-based inline icons (placed at the end of relevant words).
    final candidates = <({int index, IconData icon, int priority})>[];

    void addCandidate(RegExp re, IconData icon, int priority) {
      final match = re.firstMatch(text);
      if (match == null) return;
      candidates.add((index: match.end, icon: icon, priority: priority));
    }

    addCandidate(
      RegExp(r'\b(breathe|breathing|inhale|exhale)\b', caseSensitive: false),
      Icons.self_improvement_rounded,
      3,
    );
    addCandidate(
      RegExp(r'\b(calm|relax|relaxed|peace|peaceful|mindful|mindfulness)\b',
          caseSensitive: false),
      Icons.spa_rounded,
      3,
    );
    addCandidate(
      RegExp(r'\b(plan|routine|schedule|today|tomorrow|goal|goals)\b',
          caseSensitive: false),
      Icons.checklist_rounded,
      2,
    );
    addCandidate(
      RegExp(r'\b(streak|consistent|consistency|daily)\b',
          caseSensitive: false),
      Icons.local_fire_department_rounded,
      2,
    );
    addCandidate(
      RegExp(r'\b(drink|water|hydrate|hydration)\b', caseSensitive: false),
      Icons.water_drop_rounded,
      2,
    );
    addCandidate(
      RegExp(r'\b(sleep|rest|nap)\b', caseSensitive: false),
      Icons.bedtime_rounded,
      2,
    );
    addCandidate(
      RegExp(r'\b(focus|focused|distraction|distracted)\b',
          caseSensitive: false),
      Icons.center_focus_strong_rounded,
      1,
    );
    addCandidate(
      RegExp(r'\b(remember|tip|hint)\b', caseSensitive: false),
      Icons.tips_and_updates_rounded,
      1,
    );
    addCandidate(
      RegExp(r'\b(great|awesome|amazing|proud|nice|well done|good job)\b',
          caseSensitive: false),
      Icons.sentiment_very_satisfied_rounded,
      1,
    );

    // Deterministically shuffle within priority so the placement feels "alive"
    // but never flickers between rebuilds.
    candidates.sort((a, b) {
      if (a.priority != b.priority) return b.priority - a.priority;
      final ka = (rng ^ (a.index * 31) ^ a.icon.codePoint) & 0xffffffff;
      final kb = (rng ^ (b.index * 31) ^ b.icon.codePoint) & 0xffffffff;
      return ka - kb;
    });

    const maxInline = 2;
    const minDistance = 18;
    final pickedIndices = <int>[];

    for (final c in candidates) {
      if (pickedIndices.length >= maxInline) break;
      if (c.index <= 0 || c.index > text.length) continue;
      if (pickedIndices.any((p) => (p - c.index).abs() < minDistance)) continue;

      final p = switch (c.priority) {
        3 => 0.92,
        2 => 0.78,
        _ => 0.55,
      };
      if (nextDouble() > p) continue;

      addInsert(c.index, c.icon);
      pickedIndices.add(c.index);
    }

    // If we found a keyword match but randomness skipped everything, force the
    // strongest match so icons show up when words are apt.
    if (pickedIndices.isEmpty && candidates.isNotEmpty) {
      final c = candidates.first;
      if (c.index > 0 && c.index <= text.length) {
        addInsert(c.index, c.icon);
        pickedIndices.add(c.index);
      }
    }

    // If we didn't find any good keyword spots, sprinkle one deterministic
    // "random" icon to keep the transcript expressive.
    if (inserts.length <= 1 && text.length >= 14) {
      final breakRe = RegExp(r'[.!?]+\s+', multiLine: true);
      final breaks = breakRe.allMatches(text).toList(growable: false);

      var insertIndex = (text.length * 0.55).floor();
      if (breaks.isNotEmpty) {
        insertIndex = breaks[(rng % breaks.length).abs()].end;
      } else {
        // Move to a word boundary near the middle.
        var i = insertIndex;
        while (i < text.length && !_isWhitespaceUnit(text.codeUnitAt(i))) {
          i++;
        }
        if (i > 0 && i < text.length) {
          while (i < text.length && _isWhitespaceUnit(text.codeUnitAt(i))) {
            i++;
          }
          insertIndex = i.clamp(0, text.length);
        }
      }

      final fun = <IconData>[
        Icons.auto_awesome_rounded,
        Icons.favorite_rounded,
        Icons.waving_hand_rounded,
      ];
      final picked = fun[(rng % fun.length).abs()];
      addInsert(insertIndex, picked);
    }

    inserts.sort((a, b) {
      if (a.index != b.index) return a.index - b.index;
      return a.icon.codePoint - b.icon.codePoint;
    });
    return inserts;
  }

  List<_InlineIconInsert> _getInlineIconInserts(String text) {
    if (text == _inlineIconCacheText) return _inlineIconCache;
    final built = _buildInlineIconInserts(text);
    _inlineIconCacheText = text;
    _inlineIconCache = built;
    return built;
  }

  int _decoratedCaretOffsetForOriginalOffset({
    required int originalOffset,
    required List<_InlineIconInsert> inserts,
  }) {
    var caret = originalOffset;
    for (final ins in inserts) {
      if (ins.index <= originalOffset) caret += ins.plainLength;
    }
    return caret;
  }

  Future<void> _initTts() async {
    try {
      await _tts.awaitSpeakCompletion(true);
      // Slightly warmer/friendlier delivery.
      await _tts.setSpeechRate(0.47);
      await _tts.setPitch(1.03);
      await _tts.setVolume(1.0);
      await _tts.setLanguage('en-US');

      try {
        final voices = await _tts.getVoices;
        if (voices is List) {
          int? toInt(dynamic value) {
            if (value == null) return null;
            if (value is int) return value;
            if (value is double) return value.round();
            return int.tryParse(value.toString());
          }

          Map<dynamic, dynamic>? picked;
          var bestScore = -999999;

          for (final v in voices) {
            if (v is! Map) continue;
            final notInstalled =
                v['notInstalled'] == true || v['installed'] == false;
            if (notInstalled) continue;

            final name =
                (v['name'] ?? v['identifier'] ?? v['id'] ?? '').toString();
            final localeRaw =
                (v['locale'] ?? v['language'] ?? v['lang'] ?? '').toString();
            final locale = localeRaw.toLowerCase().replaceAll('_', '-');
            if (!locale.startsWith('en')) continue;

            var score = 0;
            if (locale == 'en-us') {
              score += 100;
            } else if (locale.startsWith('en-')) {
              score += 60;
            }

            final n = name.toLowerCase();
            final qualityRaw = v['quality'];
            final quality = (qualityRaw ?? '').toString().toLowerCase();
            final latencyRaw = v['latency'];
            final latency = (latencyRaw ?? '').toString().toLowerCase();
            final gender = (v['gender'] ?? '').toString().toLowerCase();

            final requiresNetworkRaw =
                v['networkRequired'] ?? v['requiresNetwork'] ?? v['network'];
            final requiresNetwork = requiresNetworkRaw == true ||
                requiresNetworkRaw.toString().toLowerCase() == 'true';

            // Prefer higher quality voices (when present on-device).
            final qNum = toInt(qualityRaw);
            if (qNum != null) score += (qNum.clamp(0, 500) / 20).round();
            final lNum = toInt(latencyRaw);
            if (lNum != null) score += (lNum.clamp(0, 500) / 200).round();

            if (n.contains('neural') || quality.contains('neural')) score += 80;
            if (n.contains('natural') || quality.contains('natural')) {
              score += 70;
            }
            if (n.contains('wavenet')) score += 70;
            if (n.contains('premium')) score += 60;
            if (n.contains('enhanced') ||
                quality.contains('enhanced') ||
                quality.contains('high')) {
              score += 50;
            }
            if (n.contains('google')) score += 20;
            if (n.contains('microsoft')) score += 10;
            if (n.contains('network') ||
                n.contains('online') ||
                n.contains('cloud') ||
                requiresNetwork) {
              score += 30;
            }

            // De-prioritize basic/compact/local voices if better options exist.
            if (n.contains('compact')) score -= 80;
            if (n.contains('local')) score -= 20;
            if (n.contains('espeak')) score -= 120;

            // Small preference for commonly-good US voice families.
            if (n.contains('en-us-x-')) score += 10;
            if (n.contains('en-us-x-sfg')) score += 4;

            if (gender == 'female' || n.contains('female')) score += 2;
            if (latency.contains('high')) score += 1;

            if (score > bestScore) {
              bestScore = score;
              picked = v;
            }
          }

          final pickedName = (picked?['name'] ?? '').toString();
          final pickedLocale =
              (picked?['locale'] ?? picked?['language'] ?? '').toString();
          if (pickedName.isNotEmpty && pickedLocale.isNotEmpty) {
            await _tts.setVoice({'name': pickedName, 'locale': pickedLocale});
          }
        }
      } catch (_) {}

      _tts.setStartHandler(() {
        if (!mounted) return;
        setState(() {
          _isSpeaking = true;
          if (_ttsSpokenText.isEmpty && _voiceAssistantSubtitle.isNotEmpty) {
            _ttsSpokenText = _voiceAssistantSubtitle;
            _ttsSpokenOffset = 0;
            _ttsWordStart = 0;
            _ttsWordEnd = 0;
          }
        });
        if (_voiceMode) {
          _scrollToBottom(immediate: true);
        }
      });
      _tts.setCompletionHandler(() {
        if (!mounted) return;
        setState(() {
          _isSpeaking = false;
          // Hide subtitles once Atom finishes speaking.
          _voiceAssistantSubtitle = '';
          _ttsSpokenText = '';
          _ttsSpokenOffset = 0;
          _ttsWordStart = 0;
          _ttsWordEnd = 0;
        });
        _scheduleAutoListenAfterTts();
      });
      _tts.setCancelHandler(() {
        if (!mounted) return;
        setState(() {
          _isSpeaking = false;
          _voiceAssistantSubtitle = '';
          _ttsSpokenText = '';
          _ttsSpokenOffset = 0;
          _ttsWordStart = 0;
          _ttsWordEnd = 0;
        });
        _scheduleAutoListenAfterTts();
      });
      _tts.setErrorHandler((message) {
        debugPrint('TTS error: $message');
        if (!mounted) return;
        setState(() {
          _isSpeaking = false;
          _voiceAssistantSubtitle = '';
          _ttsSpokenText = '';
          _ttsSpokenOffset = 0;
          _ttsWordStart = 0;
          _ttsWordEnd = 0;
        });
        _scheduleAutoListenAfterTts();
      });

      // Used for the voice-mode subtitle effect (words disappear as spoken).
      try {
        _tts.setProgressHandler((text, startOffset, endOffset, word) {
          if (!mounted) return;
          if (!_voiceMode) return;

          final source = _ttsSpokenText.isNotEmpty ? _ttsSpokenText : text;
          if (source.isEmpty) return;

          var safeEnd = endOffset;
          if (safeEnd < 0) safeEnd = 0;
          if (safeEnd > source.length) safeEnd = source.length;
          if (safeEnd <= _ttsSpokenOffset) return;

          var safeStart = startOffset;
          if (safeStart < 0) safeStart = 0;
          if (safeStart > source.length) safeStart = source.length;
          if (safeStart > safeEnd) safeStart = safeEnd;

          setState(() {
            if (_ttsSpokenText.isEmpty) {
              _ttsSpokenText = source;
              _ttsSpokenOffset = 0;
            }
            _ttsSpokenOffset = safeEnd;
            _ttsWordStart = safeStart;
            _ttsWordEnd = safeEnd;
          });
        });
      } catch (_) {
        // Optional on some platforms.
      }

      if (!mounted) return;
      setState(() => _ttsReady = true);
    } catch (e) {
      debugPrint('TTS initialization error: $e');
    }
  }

  Future<void> _stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {}
    if (!mounted) return;
    if (_isSpeaking || _voiceAssistantSubtitle.isNotEmpty) {
      setState(() {
        _isSpeaking = false;
        _voiceAssistantSubtitle = '';
        _ttsSpokenText = '';
        _ttsSpokenOffset = 0;
        _ttsWordStart = 0;
        _ttsWordEnd = 0;
      });
    }
  }

  void _scheduleAutoListenAfterTts() {
    if (!mounted) return;
    if (!_voiceMode) return;

    final token = ++_autoListenToken;
    Future.delayed(const Duration(milliseconds: 420), () async {
      if (!mounted) return;
      if (!_voiceMode) return;
      if (token != _autoListenToken) return;
      if (_isListening || _isLoading || _isSpeaking) return;

      final provider = context.read<HabitProvider>();
      await _toggleListening(provider);
    });
  }

  Future<void> _setVoiceMode(bool value, HabitProvider provider) async {
    if (_voiceMode == value) return;

    // Any manual mode switch cancels pending auto-resume.
    _autoListenToken++;

    if (value) {
      await _stopSpeaking();
      await _speech.stop();

      if (!mounted) return;
      setState(() {
        _voiceMode = true;
        _isListening = false;
        _voiceDraft = '';
        _voiceUserSubtitle = '';
        _voiceAssistantSubtitle = '';
        _ttsSpokenText = '';
        _ttsSpokenOffset = 0;
        _ttsWordStart = 0;
        _ttsWordEnd = 0;
      });
      _scrollToBottom(immediate: true);

      // Start listening shortly after entering voice mode.
      await Future.delayed(const Duration(milliseconds: 220));
      if (!mounted) return;
      if (!_voiceMode) return;
      if (_isListening || _isLoading || _isSpeaking) return;

      await _toggleListening(provider);
      return;
    }

    await _speech.stop();
    await _stopSpeaking();

    if (!mounted) return;
    setState(() {
      _voiceMode = false;
      _isListening = false;
      _voiceDraft = '';
      _voiceUserSubtitle = '';
      _voiceAssistantSubtitle = '';
      _ttsSpokenText = '';
      _ttsSpokenOffset = 0;
    });
  }

  Future<void> _loadWellnessContext() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final journalRaw = prefs.getString('journal_entries_v1');
      final meditationRaw = prefs.getString('meditation_sessions_v1');

      final journalLine = _buildJournalContextLine(journalRaw);
      final meditationLine = _buildMeditationContextLine(meditationRaw);

      if (!mounted) return;
      setState(() {
        _journalContextLine = journalLine;
        _meditationContextLine = meditationLine;
      });
    } catch (_) {
      // Ignore local persistence issues.
    }
  }

  String _clip(String input, int maxChars) {
    final t = input.replaceAll(RegExp(r'\\s+'), ' ').trim();
    if (t.length <= maxChars) return t;
    return '${t.substring(0, maxChars).trimRight()}…';
  }

  String _shortDate(DateTime dt) {
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
    final m = months[(dt.month - 1).clamp(0, 11).toInt()];
    return '${dt.day} $m';
  }

  String _moodEmoji(dynamic rawMood) {
    final mood = rawMood is num
        ? rawMood.toInt()
        : int.tryParse((rawMood ?? '').toString()) ?? 0;

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

  String _buildJournalContextLine(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'none yet';

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return 'none yet';
      if (decoded.isEmpty) return 'none yet';

      Map? last;
      for (int i = decoded.length - 1; i >= 0; i--) {
        final v = decoded[i];
        if (v is Map) {
          last = v;
          break;
        }
      }
      if (last == null) return 'none yet';

      final count = decoded.whereType<Map>().length;
      final ts = DateTime.tryParse((last['timestamp'] ?? '').toString());
      final dateLabel = ts == null ? '' : _shortDate(ts);

      final emoji = _moodEmoji(last['mood']);
      final category = (last['category'] ?? '').toString().trim();

      final tomorrow = (last['tomorrowBetter'] ?? '').toString().trim();
      final intentions = (last['intentions'] ?? '').toString().trim();
      final notes = ((last['notes'] ?? '').toString().trim().isNotEmpty
              ? last['notes']
              : last['content'])
          .toString()
          .trim();

      final preview = tomorrow.isNotEmpty
          ? 'Tomorrow: ${_clip(tomorrow, 90)}'
          : intentions.isNotEmpty
              ? 'Intentions: ${_clip(intentions, 90)}'
              : notes.isNotEmpty
                  ? _clip(notes, 90)
                  : '';

      final pieces = <String>['$count entries'];
      if (dateLabel.isNotEmpty || emoji.isNotEmpty || category.isNotEmpty) {
        final meta = <String>[];
        if (dateLabel.isNotEmpty) meta.add(dateLabel);
        if (emoji.isNotEmpty) meta.add(emoji);
        if (category.isNotEmpty) meta.add(category);
        pieces.add('latest: ${meta.join(" · ")}');
      }
      if (preview.isNotEmpty) pieces.add(preview);

      return pieces.join(' — ');
    } catch (_) {
      return 'none yet';
    }
  }

  String _buildMeditationContextLine(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'none yet';

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return 'none yet';
      if (decoded.isEmpty) return 'none yet';

      final sessions = decoded.whereType<Map>().toList();
      if (sessions.isEmpty) return 'none yet';

      DateTime? lastAt;
      Map? last;
      int totalMinutes = 0;

      for (final s in sessions) {
        final mins = s['minutes'];
        if (mins is num) totalMinutes += mins.toInt();

        final dt = DateTime.tryParse((s['timestamp'] ?? '').toString());
        if (dt == null) continue;
        if (lastAt == null || dt.isAfter(lastAt)) {
          lastAt = dt;
          last = s;
        }
      }

      final since = DateTime.now().subtract(const Duration(days: 7));
      final last7 = sessions.where((s) {
        final dt = DateTime.tryParse((s['timestamp'] ?? '').toString());
        if (dt == null) return false;
        return dt.isAfter(since);
      }).length;

      final lastTitle = (last?['title'] ?? '').toString().trim();
      final lastMins = last?['minutes'];
      final lastMinsLabel = lastMins is num ? '${lastMins.toInt()}m' : '';
      final lastDate = lastAt == null ? '' : _shortDate(lastAt);

      final pieces = <String>[
        '${sessions.length} sessions',
        if (last7 > 0) '$last7 in last 7 days',
        if (totalMinutes > 0) '$totalMinutes min total',
      ];

      if (lastTitle.isNotEmpty) {
        final meta = <String>[];
        meta.add(_clip(lastTitle, 28));
        if (lastMinsLabel.isNotEmpty) meta.add(lastMinsLabel);
        if (lastDate.isNotEmpty) meta.add(lastDate);
        pieces.add('last: ${meta.join(" · ")}');
      }

      return pieces.join(' — ');
    } catch (_) {
      return 'none yet';
    }
  }

  Future<void> _speakReply(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    if (!_ttsReady) {
      // Try anyway; some platforms don't need explicit init.
      // If it fails, we still show the text reply in chat.
    }

    String spoken = t;
    if (_voiceMode && _shouldSummarizeForSpeech(t)) {
      spoken = _summarizeForSpeech(t);
    }

    try {
      await _tts.stop();

      _ttsSpokenText = spoken;
      _ttsSpokenOffset = 0;
      _ttsWordStart = 0;
      _ttsWordEnd = 0;

      if (mounted && _voiceMode) {
        setState(() {
          _voiceAssistantSubtitle = spoken;
          _ttsSpokenText = spoken;
          _ttsSpokenOffset = 0;
        });
        _resetVoiceTranscriptScroll();
        _scrollToBottom(immediate: true);
      }

      await _tts.speak(spoken);
    } catch (e) {
      debugPrint('TTS speak error: $e');
      if (!mounted) return;
      if (_voiceMode) {
        setState(() {
          _isSpeaking = false;
          _voiceAssistantSubtitle = '';
          _ttsSpokenText = '';
          _ttsSpokenOffset = 0;
        });
        _scheduleAutoListenAfterTts();
      }
    }
  }

  bool _shouldSummarizeForSpeech(String full) {
    final cleaned = full.trim();
    if (cleaned.length < 520) return false;
    if (cleaned.length >= 650) return true;
    // Avoid over-summarizing short but line-broken messages.
    final wordCount =
        cleaned.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    return wordCount >= 90;
  }

  String _summarizeForSpeech(String full) {
    final cleaned = full.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty) return '';

    final sentences = cleaned.split(RegExp(r'(?<=[.!?])\s+'));
    var summary = sentences.take(2).join(' ').trim();
    if (summary.isEmpty) summary = cleaned;

    const maxLen = 240;
    if (summary.length > maxLen) {
      summary = summary.substring(0, maxLen - 3).trimRight();
      summary = '$summary...';
    }

    return 'Quick summary. $summary';
  }

  Future<bool> _ensureSpeechReady() async {
    if (_speechReady) return true;

    try {
      final permission = await Permission.microphone.request();
      if (!permission.isGranted) {
        if (!mounted) return false;
        setState(() => _speechReady = false);
        return false;
      }

      final available = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'done' || status == 'notListening') {
            if (_isListening) {
              setState(() => _isListening = false);
            }
          }
        },
        onError: (err) {
          // Only handle errors that occur during actual listening, not initialization
          if (!mounted || !_isListening) return;

          final shouldSubmit = _isListening && !_speechSubmitted && !_isLoading;
          final captured = _voiceDraft.trim();

          setState(() {
            _isListening = false;
            if (shouldSubmit && captured.isNotEmpty) {
              _voiceUserSubtitle = captured;
            }
            _messages.add(const _ChatMessage(
              role: _Role.bot,
              text: 'Voice input failed. Please try again.',
            ));
          });
          _scrollToBottom();

          if (shouldSubmit && captured.isNotEmpty && _speechProvider != null) {
            _voiceDraft = '';
            _speechSubmitted = true;
            _sendMessage(
              _speechProvider!,
              captured,
              speakReply: true,
              clearComposer: false,
            );
          }

          debugPrint('Speech error: ${err.errorMsg}');
        },
      );

      String? localeId;
      if (available) {
        try {
          final locales = await _speech.locales();
          final stt.LocaleName? systemLocale = await _speech.systemLocale();
          final systemId = systemLocale?.localeId.trim();

          if (systemId != null && systemId.isNotEmpty) {
            for (final l in locales) {
              if (l.localeId == systemId) {
                localeId = l.localeId;
                break;
              }
            }

            if (localeId == null) {
              final sysLang = systemId.split(RegExp('[_-]')).first;
              for (final l in locales) {
                final lang = l.localeId.split(RegExp('[_-]')).first;
                if (lang == sysLang) {
                  localeId = l.localeId;
                  break;
                }
              }
            }
          }
        } catch (_) {}
      }

      if (!mounted) return false;
      setState(() {
        _speechReady = available;
        _speechLocaleId = localeId;
      });
      return available;
    } catch (e) {
      if (!mounted) return false;
      setState(() => _speechReady = false);
      debugPrint('Speech initialization error: $e');
      return false;
    }
  }

  Future<void> _toggleListening(HabitProvider provider) async {
    // Any manual mic action cancels pending auto-resume.
    _autoListenToken++;

    if (_isLoading) return;

    if (_isListening) {
      final captured = _voiceDraft.trim();
      await _speech.stop();
      if (!mounted) return;
      setState(() {
        _isListening = false;
        if (captured.isNotEmpty) {
          _voiceUserSubtitle = captured;
        }
      });

      _voiceDraft = '';

      if (!_speechSubmitted && captured.isNotEmpty && !_isLoading) {
        _speechSubmitted = true;
        _sendMessage(
          provider,
          captured,
          speakReply: true,
          clearComposer: false,
        );
      }
      return;
    }

    // If Atom is currently speaking, stop before listening.
    await _stopSpeaking();

    final ok = await _ensureSpeechReady();
    if (!ok) {
      if (!mounted) return;
      setState(() {
        _messages.add(const _ChatMessage(
          role: _Role.bot,
          text:
              'Voice input isn\'t available right now. You can still type to Atom.',
        ));
      });
      _scrollToBottom();
      return;
    }

    if (!mounted) return;
    setState(() {
      _isListening = true;
      _voiceDraft = '';
      _voiceUserSubtitle = '';
      _voiceAssistantSubtitle = '';
      _ttsSpokenText = '';
      _ttsSpokenOffset = 0;
    });
    _scrollToBottom(immediate: true);
    _speechProvider = provider;
    _speechSubmitted = false;

    try {
      await _speech.listen(
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 8),
        localeId: _speechLocaleId,
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: stt.ListenMode.confirmation,
        ),
        onResult: (result) {
          final words =
              VoiceTranscriptCleaner.clean(result.recognizedWords).trim();
          final wasEmpty = _voiceDraft.isEmpty;
          _voiceDraft = words;
          if (mounted && _voiceMode) {
            setState(() {});
          }
          if (wasEmpty && words.isNotEmpty) {
            _scrollToBottom(immediate: true);
          }

          if (!result.finalResult) return;
          _speech.stop();
          if (!mounted) return;
          setState(() => _isListening = false);
          if (_speechSubmitted) return;
          if (words.isNotEmpty &&
              !VoiceTranscriptCleaner.isNoise(words) &&
              !_isLoading) {
            _voiceUserSubtitle = words;
            _voiceDraft = '';
            _speechSubmitted = true;
            _sendMessage(
              provider,
              words,
              speakReply: true,
              clearComposer: false,
            );
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isListening = false;
        _messages.add(const _ChatMessage(
          role: _Role.bot,
          text:
              'I couldn\'t start voice input. Check microphone permission and try again.',
        ));
      });
      _scrollToBottom();
      debugPrint('Speech listen failed: $e');
    }
  }

  Future<_OfflineAssistantResult?> _tryHandlePendingDeleteConfirmation(
    HabitProvider provider,
    String input,
  ) async {
    final pending = _pendingDelete;
    if (pending == null) return null;

    final lower = input.trim().toLowerCase();
    final isYes = RegExp(
      r'^(?:y|yes|yeah|yep|ok|okay|confirm|do it|delete|delete it|sure)$',
      caseSensitive: false,
    ).hasMatch(lower);
    final isNo = RegExp(
      r"^(?:n|no|nope|cancel|stop|keep|keep it|don't|do not)$",
      caseSensitive: false,
    ).hasMatch(lower);

    if (isYes) {
      await provider.deleteHabit(pending.habitId);
      _pendingDelete = null;
      return _OfflineAssistantResult(
        replyText: 'Deleted “${pending.habitTitle}”.',
        actionSummary: '✓ Deleted habit: ${pending.habitTitle}',
      );
    }

    if (isNo) {
      _pendingDelete = null;
      return const _OfflineAssistantResult(
        replyText: 'Okay — I won\'t delete it.',
      );
    }

    return _OfflineAssistantResult(
      replyText:
          'Do you want me to delete “${pending.habitTitle}”? Reply “yes” to confirm or “no” to cancel.',
    );
  }

  Future<_OfflineAssistantResult?> _tryLocalAction(
      HabitProvider provider, String input) async {
    final text = input.trim();
    final lower = text.toLowerCase();

    String queryFromArg(String value) {
      final raw = _stripQuotes(value).trim();
      final sanitized = trySanitizeHabitTitle(raw);
      return (sanitized ?? raw).trim();
    }

    final wantsHelp = lower == 'help' ||
        lower.contains('what can you do') ||
        lower.contains('what can u do') ||
        lower.contains('commands') ||
        lower.contains('how do i');
    if (wantsHelp) {
      return const _OfflineAssistantResult(
        replyText:
            'Try: “add journaling”, “list habits”, “show reminder for journaling”, “set reminder for journaling at 9am”, “mark journaling done”, “undo journaling”, “rename journaling to gratitude”, “delete journaling”.',
      );
    }

    final wantsListHabits = lower == 'habits' ||
        RegExp(r'^(?:list|show|view)\s+(?:my\s+)?habits\b',
                caseSensitive: false)
            .hasMatch(text) ||
        RegExp(r'^(?:what|which)\s+habits\s+do\s+i\s+have\b',
                caseSensitive: false)
            .hasMatch(text);
    if (wantsListHabits) {
      if (provider.habits.isEmpty) {
        return const _OfflineAssistantResult(
          replyText: 'You don\'t have any habits yet. Try: “add journaling”.',
        );
      }

      final titles = provider.habits.map((h) => h.title).toList();
      final list = titles.map((t) => '- $t').join('\n');
      return _OfflineAssistantResult(
        replyText: 'Your habits:\n$list',
      );
    }

    final showReminderMatch = RegExp(
          r'^(?:show|view)\s+(?:the\s+)?reminder\s+(?:for|on)\s+(.+)$',
          caseSensitive: false,
        ).firstMatch(text) ??
        RegExp(
          r'^(?:when|what\s+time)\s+is\s+(?:the\s+)?reminder\s+(?:for|on)\s+(.+)$',
          caseSensitive: false,
        ).firstMatch(text);
    if (showReminderMatch != null) {
      final habitQuery = queryFromArg(showReminderMatch.group(1) ?? '');
      if (habitQuery.isEmpty) {
        return const _OfflineAssistantResult(
          replyText: 'Tell me: “show reminder for <habit>”.',
        );
      }

      final habit = _findHabitByTitleQuery(provider, habitQuery);
      if (habit == null) {
        return _OfflineAssistantResult(
          replyText: 'I couldn\'t find a habit named “$habitQuery”.',
        );
      }

      if (habit.reminderEnabled != true) {
        return _OfflineAssistantResult(
          replyText: 'No reminder is set for “${habit.title}”.',
        );
      }

      final time = (habit.reminderTime ?? '').trim();
      if (time.isEmpty) {
        return _OfflineAssistantResult(
          replyText: 'Reminder is on for “${habit.title}”, but no time is set.',
        );
      }

      return _OfflineAssistantResult(
        replyText: 'Reminder for “${habit.title}” is set to $time.',
      );
    }

    final wantsAnalytics = lower == 'analytics' ||
        lower == 'stats' ||
        ((lower.contains('analytics') || lower.contains('stats')) &&
            (lower.contains('open') ||
                lower.contains('show') ||
                lower.contains('view') ||
                lower.contains('go to')));
    if (wantsAnalytics) {
      await _actionOpenAnalytics();
      return const _OfflineAssistantResult(replyText: 'Opening Analytics.');
    }

    final deleteMatch = RegExp(
      r'(?:delete|remove)\s+(?:my\s+)?(?:habit\s+)?(.+)$',
      caseSensitive: false,
    ).firstMatch(text);
    if (deleteMatch != null) {
      final habitQuery = queryFromArg(deleteMatch.group(1) ?? '');
      if (habitQuery.isEmpty) {
        return const _OfflineAssistantResult(
          replyText: 'Tell me: “delete <habit name>”.',
        );
      }
      final habit = _findHabitByTitleQuery(provider, habitQuery);
      if (habit == null) {
        return _OfflineAssistantResult(
          replyText: 'I couldn\'t find a habit named “$habitQuery”.',
        );
      }

      _pendingDelete = _PendingDeleteRequest(
        habitId: habit.id,
        habitTitle: habit.title,
      );
      return _OfflineAssistantResult(
        replyText:
            'Are you sure you want to delete “${habit.title}”? Reply “yes” to confirm or “no” to cancel.',
      );
    }

    final renameMatch = RegExp(
      r'(?:rename|change|edit|update)\s+(?:my\s+)?(?:habit\s+)?(.+?)\s+(?:to|into)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(text);
    if (renameMatch != null) {
      final fromQuery = queryFromArg(renameMatch.group(1) ?? '');
      final toRaw = _stripQuotes(renameMatch.group(2) ?? '').trim();
      final to = trySanitizeHabitTitle(toRaw);
      if (fromQuery.isEmpty || to == null) {
        return const _OfflineAssistantResult(
          replyText: 'Tell me: “rename <old> to <new>”.',
        );
      }
      final habit = _findHabitByTitleQuery(provider, fromQuery);
      if (habit == null) {
        return _OfflineAssistantResult(
          replyText: 'I couldn\'t find a habit named “$fromQuery”.',
        );
      }

      final exists = provider.habits
          .any((h) => h.title.trim().toLowerCase() == to.toLowerCase());
      if (exists) {
        return _OfflineAssistantResult(
          replyText: 'You already have a habit named “$to”.',
        );
      }

      final updated = habit.copyWith(title: to);
      await provider.updateHabit(updated);
      return _OfflineAssistantResult(
        replyText: 'Done — renamed “${habit.title}” to “$to”.',
        actionSummary: '✓ Updated habit: $to',
      );
    }

    final disableReminderMatch = RegExp(
      r'(?:disable|turn\s+off|remove|stop)\s+(?:the\s+)?reminder\s+(?:for|on)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(text);
    if (disableReminderMatch != null) {
      final habitQuery = queryFromArg(disableReminderMatch.group(1) ?? '');
      if (habitQuery.isEmpty) {
        return const _OfflineAssistantResult(
          replyText: 'Tell me: “turn off reminder for <habit>”.',
        );
      }
      final habit = _findHabitByTitleQuery(provider, habitQuery);
      if (habit == null) {
        return _OfflineAssistantResult(
          replyText: 'I couldn\'t find a habit named “$habitQuery”.',
        );
      }

      final updated = habit.copyWith(reminderEnabled: false);
      await provider.updateHabit(updated);
      return _OfflineAssistantResult(
        replyText: 'Done — reminder is off for “${habit.title}”.',
        actionSummary: '✓ Updated habit: ${habit.title}',
      );
    }

    final reminderMatch = RegExp(
          r'(?:set|change|update|add|enable|turn\s+on)\s+(?:the\s+)?reminder\s+(?:for|on)\s+(.+?)\s+(?:to|at)\s+([0-2]?\d(?:[:\.][0-5]\d)?\s*(?:a\.?\s*m|p\.?\s*m|am|pm)?(?:\s+(?:in\s+the\s+)?(?:morning|afternoon|evening|night))?)\b',
          caseSensitive: false,
        ).firstMatch(text) ??
        RegExp(
          r'remind\s+me\s+(?:to|about)\s+(.+?)\s+at\s+([0-2]?\d(?:[:\.][0-5]\d)?\s*(?:a\.?\s*m|p\.?\s*m|am|pm)?(?:\s+(?:in\s+the\s+)?(?:morning|afternoon|evening|night))?)\b',
          caseSensitive: false,
        ).firstMatch(text) ??
        RegExp(
          r'reminder\s+(?:for|on)\s+(.+?)\s+at\s+([0-2]?\d(?:[:\.][0-5]\d)?\s*(?:a\.?\s*m|p\.?\s*m|am|pm)?(?:\s+(?:in\s+the\s+)?(?:morning|afternoon|evening|night))?)\b',
          caseSensitive: false,
        ).firstMatch(text);

    final reminderTimeFirstMatch = reminderMatch != null
        ? null
        : (RegExp(
              r'(?:set|change|update|add|enable|turn\s+on)\s+(?:the\s+)?reminder\s+(?:to|at)\s+([0-2]?\d(?:[:\.][0-5]\d)?\s*(?:a\.?\s*m|p\.?\s*m|am|pm)?(?:\s+(?:in\s+the\s+)?(?:morning|afternoon|evening|night))?)\s+(?:for|on)\s+(.+)$',
              caseSensitive: false,
            ).firstMatch(text) ??
            RegExp(
              r'remind\s+me\s+at\s+([0-2]?\d(?:[:\.][0-5]\d)?\s*(?:a\.?\s*m|p\.?\s*m|am|pm)?(?:\s+(?:in\s+the\s+)?(?:morning|afternoon|evening|night))?)\s+(?:to|about)\s+(.+)$',
              caseSensitive: false,
            ).firstMatch(text) ??
            RegExp(
              r'reminder\s+at\s+([0-2]?\d(?:[:\.][0-5]\d)?\s*(?:a\.?\s*m|p\.?\s*m|am|pm)?(?:\s+(?:in\s+the\s+)?(?:morning|afternoon|evening|night))?)\s+(?:for|on)\s+(.+)$',
              caseSensitive: false,
            ).firstMatch(text));

    if (reminderMatch != null || reminderTimeFirstMatch != null) {
      final habitName = reminderMatch != null
          ? queryFromArg(reminderMatch.group(1) ?? '')
          : queryFromArg(reminderTimeFirstMatch!.group(2) ?? '');
      final hm = reminderMatch != null
          ? _normalizeReminderTime(reminderMatch.group(2))
          : _normalizeReminderTime(reminderTimeFirstMatch!.group(1));
      if (habitName.isEmpty || hm == null) {
        return const _OfflineAssistantResult(
          replyText:
              'Tell me: “set reminder for <habit> at 9am”, or “set reminder at 7pm for <habit>” (also: 21:00, 09:30, 6.30, “7 in the evening”).',
        );
      }
      final habit = _findHabitByTitleQuery(provider, habitName);
      if (habit == null) {
        return _OfflineAssistantResult(
          replyText: 'I couldn\'t find a habit named “$habitName”.',
        );
      }

      final updated = habit.copyWith(reminderEnabled: true, reminderTime: hm);
      await provider.updateHabit(updated);
      return _OfflineAssistantResult(
        replyText: 'Got it — I\'ll remind you at $hm for “${habit.title}”.',
        actionSummary: '✓ Updated habit: ${habit.title}',
      );
    }

    final undoMatch = RegExp(
      r'(?:undo|uncomplete|uncheck|mark\s+undone|mark\s+not\s+done)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(text);
    if (undoMatch != null) {
      final habitName = queryFromArg(undoMatch.group(1) ?? '');
      if (habitName.isEmpty) {
        return const _OfflineAssistantResult(
          replyText: 'Tell me: “undo <habit name>”.',
        );
      }
      final habit = _findHabitByTitleQuery(provider, habitName);
      if (habit == null) {
        return _OfflineAssistantResult(
          replyText: 'I couldn\'t find a habit named “$habitName”.',
        );
      }

      final now = DateTime.now();
      if (!provider.isCompletedOnDate(habit.id, now)) {
        return _OfflineAssistantResult(
          replyText: '“${habit.title}” is already not completed today.',
        );
      }

      provider.toggleHabitCompletion(habit.id, now);
      return _OfflineAssistantResult(
        replyText: 'Done — marked “${habit.title}” as not done for today.',
        actionSummary: '✓ Marked "${habit.title}" as not done for today',
      );
    }

    final completeMatch = RegExp(
      r'(?:mark|complete|check\s+off|done)\s+(.+?)(?:\s+(?:done|today))?$',
      caseSensitive: false,
    ).firstMatch(text);
    if (completeMatch != null) {
      final habitName = queryFromArg(completeMatch.group(1) ?? '');
      final habit = _findHabitByTitleQuery(provider, habitName);
      if (habit == null) {
        return _OfflineAssistantResult(
          replyText: 'I couldn\'t find a habit named “$habitName”.',
        );
      }

      final now = DateTime.now();
      if (provider.isCompletedOnDate(habit.id, now)) {
        return _OfflineAssistantResult(
          replyText: '“${habit.title}” is already marked complete for today.',
        );
      }

      provider.toggleHabitCompletion(habit.id, now);
      return _OfflineAssistantResult(
        replyText: 'Done — marked “${habit.title}” as complete for today.',
        actionSummary: '✓ Marked "${habit.title}" as complete for today',
      );
    }

    final addMatch = RegExp(
          r'(?:add|create|start|track|set\s+up)\s+(?:(?:a|an)\s+)?(?:habit\s+)?(?:(?:called|named)\s+)?(.+)$',
          caseSensitive: false,
        ).firstMatch(text) ??
        RegExp(
          r'^(?:new\s+habit|habit)\s*[:\-]\s*(.+)$',
          caseSensitive: false,
        ).firstMatch(text) ??
        RegExp(
          r'^(?:please\s+)?remind\s+me\s+to\s+(.+)$',
          caseSensitive: false,
        ).firstMatch(text);
    if (addMatch != null) {
      var titleInput = _stripQuotes(addMatch.group(1) ?? '').trim();
      if (titleInput.isEmpty) {
        return const _OfflineAssistantResult(
            replyText: 'Tell me: “add <habit name>”.');
      }

      String? reminderTime;
      final atTimeMatch = RegExp(
        r'^(.+?)\s+at\s+([0-2]?\d(?:[:\.][0-5]\d)?\s*(?:a\.?\s*m|p\.?\s*m|am|pm)?(?:\s+(?:in\s+the\s+)?(?:morning|afternoon|evening|night))?)$',
        caseSensitive: false,
      ).firstMatch(titleInput);
      if (atTimeMatch != null) {
        final hm = _normalizeReminderTime(atTimeMatch.group(2));
        if (hm != null) {
          titleInput = atTimeMatch.group(1)!.trim();
          reminderTime = hm;
        }
      }

      final title = trySanitizeHabitTitle(titleInput);
      if (title == null) {
        return const _OfflineAssistantResult(
          replyText:
              'What should the habit be called? Reply with just the habit name (e.g., “Journaling”).',
        );
      }

      final exists = provider.habits
          .any((h) => h.title.trim().toLowerCase() == title.toLowerCase());
      if (exists) {
        return _OfflineAssistantResult(
          replyText: 'You already have a habit named “$title”.',
        );
      }

      await provider.addHabit(Habit(
        title: title,
        description: '',
        category: 'General',
        emoji: HabitIconRegistry.defaultKey,
        timeOfDay: 'anytime',
        reminderEnabled: reminderTime != null,
        reminderTime: reminderTime,
      ));

      return _OfflineAssistantResult(
        replyText: reminderTime == null
            ? 'Added “$title”. Want a reminder time for it?'
            : 'Added “$title” with a reminder at $reminderTime.',
        actionSummary: '✓ Added habit: $title',
      );
    }

    return null;
  }

  Future<void> _sendMessage(
    HabitProvider provider,
    String text, {
    bool speakReply = false,
    bool clearComposer = true,
  }) async {
    final input = text.trim();
    if (input.isEmpty || _isLoading) return;

    // If Atom is talking and the user sends a new message, interrupt.
    await _stopSpeaking();

    setState(() {
      _messages.add(_ChatMessage(role: _Role.user, text: input));
      _isLoading = true;
    });
    if (clearComposer) {
      _controller.clear();
    }
    _scrollToBottom(immediate: true);

    final pendingDelete =
        await _tryHandlePendingDeleteConfirmation(provider, input);
    if (pendingDelete != null) {
      if (!mounted) return;
      setState(() {
        _messages
            .add(_ChatMessage(role: _Role.bot, text: pendingDelete.replyText));
        if (pendingDelete.actionSummary != null) {
          _messages.add(_ChatMessage(
              role: _Role.bot, text: pendingDelete.actionSummary!));
        }

        // Clear loading before any TTS so the mic stays usable.
        _isLoading = false;
      });
      _scrollToBottom(immediate: true);

      if (speakReply) {
        await _speakReply(pendingDelete.replyText);
      }
      _scrollToBottom(immediate: true);
      return;
    }

    final localAction = await _tryLocalAction(provider, input);
    if (localAction != null) {
      if (!mounted) return;
      setState(() {
        _messages
            .add(_ChatMessage(role: _Role.bot, text: localAction.replyText));
        if (localAction.actionSummary != null) {
          _messages.add(
              _ChatMessage(role: _Role.bot, text: localAction.actionSummary!));
        }

        // Clear loading before any TTS so the mic stays usable.
        _isLoading = false;
      });
      _scrollToBottom(immediate: true);

      if (speakReply) {
        await _speakReply(localAction.replyText);
      }
      _scrollToBottom(immediate: true);
      return;
    }

    if (!_llmService.isConfigured) {
      try {
        final offline = await _offlineAssistantReply(provider, input);
        if (!mounted) return;
        setState(() {
          _messages.add(_ChatMessage(role: _Role.bot, text: offline.replyText));
          if (offline.actionSummary != null) {
            _messages.add(
                _ChatMessage(role: _Role.bot, text: offline.actionSummary!));
          }

          // Clear loading before any TTS so the mic stays usable.
          _isLoading = false;
        });
        _scrollToBottom(immediate: true);

        if (speakReply) {
          await _speakReply(offline.replyText);
        }
      } finally {
        if (mounted && _isLoading) {
          setState(() => _isLoading = false);
        }
        _scrollToBottom();
      }
      return;
    }

    try {
      final systemPrompt = _buildSystemPrompt(provider);
      final conversationAll = _messages
          .where((m) => m.role == _Role.user || m.role == _Role.bot)
          // Skip app-generated action summaries from the LLM context.
          .where(
              (m) => m.role != _Role.bot || !m.text.trimLeft().startsWith('✓'))
          .map((m) => {
                'role': m.role == _Role.user ? 'user' : 'assistant',
                'content': m.text,
              })
          .toList();

      // Keep the most recent context to speed up responses.
      final conversation = conversationAll.length > 16
          ? conversationAll.sublist(conversationAll.length - 16)
          : conversationAll;

      final reply = await _llmService.generateCoachReply(
        systemPrompt: systemPrompt,
        conversation: conversation,
      );

      final parsed = _parseCoachResponse(reply);
      final applied = await _applyCoachActions(provider, parsed.actions);
      final actionSummary = applied.summary;
      var followup = applied.followup;

      final hasAutomationMarker = RegExp(
        r'ACTIONS_JSON\s*:',
        caseSensitive: false,
      ).hasMatch(reply);
      final hadActions = parsed.actions.isNotEmpty;

      var displayReply = parsed.visibleText.isNotEmpty
          ? parsed.visibleText
          : hadActions
              ? (actionSummary == null
                  ? 'I couldn\'t apply that. Try rephrasing with the habit name.'
                  : 'Done. I applied your requested changes.')
              : hasAutomationMarker
                  ? 'I couldn\'t read the requested actions. Try again.'
                  : reply.trim();

      if (parsed.visibleText.isEmpty &&
          followup != null &&
          followup.trim().isNotEmpty) {
        displayReply = followup;
        followup = null;
      }

      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(role: _Role.bot, text: displayReply));
        if (actionSummary != null) {
          _messages.add(_ChatMessage(role: _Role.bot, text: actionSummary));
        }
        if (followup != null && followup.trim().isNotEmpty) {
          _messages.add(_ChatMessage(role: _Role.bot, text: followup));
        }

        // Clear loading before any TTS so the mic stays usable.
        _isLoading = false;
      });
      _scrollToBottom(immediate: true);

      if (speakReply) {
        await _speakReply(displayReply);
      }
    } catch (e) {
      debugPrint('AI coach request failed: $e');
      if (!mounted) return;
      final fallback = _fallbackReply(provider, input, error: e.toString());
      setState(() {
        _messages.add(
          _ChatMessage(
            role: _Role.bot,
            text: fallback,
          ),
        );

        // Clear loading before any TTS so the mic stays usable.
        _isLoading = false;
      });
      _scrollToBottom(immediate: true);

      if (speakReply) {
        await _speakReply(fallback);
      }
    } finally {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
      _scrollToBottom();
    }
  }

  void _scrollToBottom({bool immediate = false}) {
    void doScroll() {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (immediate) {
        _scrollController.jumpTo(target);
        return;
      }
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      doScroll();
    });

    // In voice mode the transcript panel animates its height, so scroll again
    // once the layout settles to keep the latest turn visible.
    if (_voiceMode) {
      Future.delayed(const Duration(milliseconds: 320), () {
        if (!mounted) return;
        doScroll();
      });
    }
  }

  String _buildSystemPrompt(HabitProvider provider) {
    final now = DateTime.now();
    final todayDone = provider.habits
        .where((h) => provider.isCompletedOnDate(h.id, now))
        .length;
    final totalHabits = provider.habits.length;

    final weeklyRate = _overallCompletionRate(provider, 'weekly');
    final monthlyRate = _overallCompletionRate(provider, 'monthly');
    final yearlyRate = _overallCompletionRate(provider, 'yearly');

    int bestStreak = 0;
    for (final habit in provider.habits) {
      final streak = provider.getStreak(habit.id);
      if (streak > bestStreak) bestStreak = streak;
    }

    final habitLines = provider.habits.take(12).map((h) {
      final streak = provider.getStreak(h.id);
      final doneToday = provider.isCompletedOnDate(h.id, now);
      final reminder = h.reminderEnabled
          ? (h.reminderTime == null || h.reminderTime!.trim().isEmpty
              ? 'on'
              : h.reminderTime!)
          : 'off';
      return '- ${h.title} (cat:${h.category}, time:${h.timeOfDay}, streak:$streak, today:${doneToday ? 'done' : 'pending'}, reminder:$reminder)';
    }).join('\n');

    final habitTitlesJson =
        jsonEncode(provider.habits.map((h) => h.title).take(30).toList());
    final todayIso =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    return '''You are Atom, the user's AI head coach in a mental wellness + habit app.

Style: charming, calm confidence, warm, practical, emotionally intelligent.
Power dynamics: respect autonomy; no guilt/shame/pressure/manipulation. Ask consent before destructive actions.
Safety: not a therapist; no diagnosis. If self-harm/danger is mentioned, urge immediate local help.

Context:
- Today: $todayIso
- Total habits: $totalHabits
- Completed today: $todayDone/$totalHabits
- Best current streak: $bestStreak days
- Completion rate (weekly/monthly/yearly): $weeklyRate% / $monthlyRate% / $yearlyRate%
- Habits:\n${habitLines.isEmpty ? 'none yet - start tiny' : habitLines}
- Habit titles (JSON array): $habitTitlesJson
- Journal: ${_journalContextLine.isEmpty ? 'none yet' : _journalContextLine}
- Meditation: ${_meditationContextLine.isEmpty ? 'none yet' : _meditationContextLine}

Reply rules:
- 2–5 sentences, direct and human.
- Validate feelings first when needed.
- When relevant, reference the user's Journal/Meditation context above (briefly, without over-quoting).
- Offer 1–2 concrete next steps or a simple system.
- Avoid generic clichés.

Automation:
- Output actions when the user explicitly asks to change app data/navigation OR clearly reports they completed a specific habit today.
- Use habit titles exactly as shown in the Habits list to avoid mismatches.
- For delete_habit: ask for confirmation first. Do NOT output delete_habit until the user clearly confirms.
- For add_habit.title and update_habit.newTitle, output only the habit name (short noun phrase, ideally 1–4 words). Never include command text ("add a habit called ...", "remind me to ...") or schedules ("every day", "at 7am").
- If you output actions, the LAST line must be exactly: ACTIONS_JSON:<pure JSON>. No backticks, no extra text after the JSON.
- Schema: {"actions":[{...},{...}]}
Valid actions: add_habit, complete_habit, uncomplete_habit, delete_habit, update_habit, plan_day, open_analytics
Examples:
ACTIONS_JSON:{"actions":[{"type":"complete_habit","title":"Drink water"}]}
ACTIONS_JSON:{"actions":[{"type":"uncomplete_habit","title":"Drink water"}]}
ACTIONS_JSON:{"actions":[{"type":"add_habit","title":"Drink water","timeOfDay":"morning","iconKey":"mi:water_drop"}]}
ACTIONS_JSON:{"actions":[{"type":"delete_habit","title":"Drink water"}]}
ACTIONS_JSON:{"actions":[{"type":"update_habit","title":"Drink water","newTitle":"Hydrate","reminderEnabled":true,"reminderTime":"09:00"}]}
ACTIONS_JSON:{"actions":[{"type":"open_analytics"}]}
update_habit fields: title, newTitle, description, category, timeOfDay, iconKey, reminderEnabled, reminderTime(HH:mm)
''';
  }

  String _stripQuotes(String value) {
    final v = value.trim();
    if ((v.startsWith('"') && v.endsWith('"')) ||
        (v.startsWith("'") && v.endsWith("'"))) {
      return v.substring(1, v.length - 1).trim();
    }
    return v;
  }

  Habit? _findHabitByTitleQuery(HabitProvider provider, String query) {
    String normalize(String value) {
      var v = value.toLowerCase().trim();
      v = v.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
      v = v.replaceAll(RegExp(r'\s+'), ' ').trim();
      return v;
    }

    final qNorm = normalize(query);
    if (qNorm.isEmpty) return null;
    if (qNorm.length < 2) return null;

    final qTokens = qNorm
        .split(' ')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (qTokens.isEmpty) return null;

    Habit? best;
    var bestScore = -1000000;

    for (final habit in provider.habits) {
      final tNorm = normalize(habit.title);
      if (tNorm.isEmpty) continue;

      int score;
      if (tNorm == qNorm) {
        score = 1000;
      } else if (tNorm.startsWith(qNorm) || qNorm.startsWith(tNorm)) {
        score = 900;
      } else if (tNorm.contains(qNorm)) {
        score = 800;
      } else {
        final tTokens = tNorm.split(' ');
        var overlap = 0;
        for (final token in qTokens) {
          if (tTokens.contains(token)) overlap++;
        }

        if (overlap == 0) continue;
        final ratio = overlap / qTokens.length;
        score = (500 * ratio).round();
      }

      // Prefer closer length matches.
      score -= (tNorm.length - qNorm.length).abs();

      if (score > bestScore) {
        bestScore = score;
        best = habit;
      }
    }

    if (best != null && bestScore >= 200) return best;

    // Fuzzy fallback (typos / partial phrases).
    if (qNorm.length < 4) return null;
    final titles = provider.habits.map((h) => h.title).toList();
    final matchTitle =
        HabitFuzzyMatcher.findBestMatch(query, titles, maxDistance: 2);
    if (matchTitle == null) return null;
    final mNorm = normalize(matchTitle);
    for (final habit in provider.habits) {
      if (normalize(habit.title) == mNorm) return habit;
    }
    return null;
  }

  String _offlineCoachReply(HabitProvider provider, String input) {
    final q = input.toLowerCase().trim();

    final now = DateTime.now();
    final todayDone = provider.habits
        .where((h) => provider.isCompletedOnDate(h.id, now))
        .length;
    final totalHabits = provider.habits.length;
    final pending = (totalHabits - todayDone).clamp(0, totalHabits);

    if (q.contains('journal') || q.contains('diary') || q.contains('entry')) {
      final line =
          _journalContextLine.isEmpty ? 'none yet' : _journalContextLine;
      return 'Journal summary: $line. Want to add a quick entry for today?';
    }

    if (q.contains('meditat') || q.contains('breath')) {
      final line =
          _meditationContextLine.isEmpty ? 'none yet' : _meditationContextLine;
      return 'Meditation summary: $line. Want a 3‑minute reset or a longer session?';
    }

    if (q.contains('weekly reflection') ||
        q.contains('week reflection') ||
        q.contains('weekly recap') ||
        q.contains('week recap') ||
        q.contains('micro plan') ||
        q.contains('micro-plan')) {
      return _buildWeeklyReflection(provider);
    }

    if (q.contains('sad') ||
        q.contains('stress') ||
        q.contains('anx') ||
        q.contains('overwhelm') ||
        q.contains('tired') ||
        q.contains('feel')) {
      return 'I hear you. Let\'s make today lighter: pick 1 tiny habit (2–5 minutes), finish it, then reassess. You\'re at $todayDone/$totalHabits today — small wins first.';
    }

    if (q.contains('productivity') ||
        q.contains('focus') ||
        q.contains('plan') ||
        q.contains('schedule')) {
      return 'Simple system for today: 1) Do one hard habit first. 2) Do one 25‑minute focus block. 3) End with one easy habit for momentum. You have $pending habit(s) pending today.';
    }

    if (q.contains('suggest') ||
        q.contains('habit') ||
        q.contains('recommend')) {
      return 'Here\'s a tiny, high‑impact idea: ${_buildHabitSuggestion(provider)}';
    }

    return 'I\'m here. If you want, tell me what you\'re trying to change (habits, reminders, focus, stress) and I\'ll help you choose one small next step.';
  }

  String _buildWeeklyReflection(HabitProvider provider) {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day);
    final start = end.subtract(const Duration(days: 6));
    final days = List<DateTime>.generate(
      7,
      (i) => start.add(Duration(days: i)),
      growable: false,
    );

    if (provider.habits.isEmpty) {
      return 'Weekly reflection: you don\'t have any habits yet. Add 1 tiny habit (2 minutes) and I\'ll help you build a simple plan for next week.';
    }

    final byHabitTitle = <String, String>{
      for (final h in provider.habits)
        h.id: h.title.trim().isEmpty ? 'Untitled' : h.title.trim(),
    };
    final byHabitScheduled = <String, int>{
      for (final h in provider.habits) h.id: 0,
    };
    final byHabitDone = <String, int>{
      for (final h in provider.habits) h.id: 0,
    };

    int scheduledTotal = 0;
    int doneTotal = 0;

    // Track daily habit completion totals across all habits (includes goal-based habits).
    DateTime? bestDay;
    int bestDayDone = -1;

    for (final d in days) {
      final doneOnDay = provider.logs.where((l) {
        if (!l.completed) return false;
        return l.date.year == d.year &&
            l.date.month == d.month &&
            l.date.day == d.day;
      }).length;
      if (doneOnDay > bestDayDone) {
        bestDayDone = doneOnDay;
        bestDay = d;
      }

      for (final h in provider.habits) {
        if (h.scheduleType.trim().toLowerCase() == 'times_per_week') {
          // Avoid over-counting goal-based habits as "scheduled" every day.
          continue;
        }

        if (!provider.isScheduledOnDate(h, d)) continue;
        scheduledTotal++;
        byHabitScheduled[h.id] = (byHabitScheduled[h.id] ?? 0) + 1;

        if (provider.isCompletedOnDate(h.id, d)) {
          doneTotal++;
          byHabitDone[h.id] = (byHabitDone[h.id] ?? 0) + 1;
        }
      }
    }

    // Goal-based habits summary (times_per_week).
    final goalHabits = provider.habits
        .where((h) => h.scheduleType.trim().toLowerCase() == 'times_per_week')
        .toList();
    final goalLines = <String>[];
    for (final h in goalHabits) {
      final goal = h.scheduleTimesPerWeek <= 0 ? 1 : h.scheduleTimesPerWeek;
      final done = provider.logs.where((l) {
        if (!l.completed) return false;
        if (l.habitId != h.id) return false;
        if (l.date.isBefore(start)) return false;
        if (l.date.isAfter(end)) return false;
        return true;
      }).length;
      goalLines.add('${byHabitTitle[h.id] ?? h.title}: $done/$goal');
    }

    String? strongest;
    int strongestDone = -1;
    for (final h in provider.habits) {
      final done = byHabitDone[h.id] ?? 0;
      if (done > strongestDone) {
        strongestDone = done;
        strongest = h.id;
      }
    }

    String? mostFragile;
    double mostFragileRate = 2.0;
    for (final h in provider.habits) {
      if (h.scheduleType.trim().toLowerCase() == 'times_per_week') continue;
      final scheduled = byHabitScheduled[h.id] ?? 0;
      if (scheduled < 2) continue;
      final done = byHabitDone[h.id] ?? 0;
      final rate = scheduled == 0 ? 0.0 : done / scheduled;
      if (rate < mostFragileRate) {
        mostFragileRate = rate;
        mostFragile = h.id;
      }
    }

    String dayLabel(DateTime? d) {
      if (d == null) return '—';
      const names = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return names[(d.weekday - 1).clamp(0, 6)];
    }

    final sb = StringBuffer();
    sb.writeln('Weekly reflection (last 7 days):');

    final doneAll = provider.logs.where((l) {
      if (!l.completed) return false;
      if (l.date.isBefore(start)) return false;
      if (l.date.isAfter(end)) return false;
      return true;
    }).length;

    if (scheduledTotal > 0) {
      sb.writeln('- Scheduled habits: $doneTotal/$scheduledTotal completed');
    }
    sb.writeln('- Total completions: $doneAll');
    sb.writeln('- Best day: ${dayLabel(bestDay)} ($bestDayDone done)');

    if (strongest != null) {
      final sTitle = byHabitTitle[strongest] ?? '';
      final sDone = byHabitDone[strongest] ?? 0;
      final sSched = byHabitScheduled[strongest] ?? 0;
      final extra = sSched > 0 ? ' ($sDone/$sSched)' : '';
      sb.writeln('- Strongest habit: $sTitle$extra');
    }

    if (mostFragile != null) {
      final fTitle = byHabitTitle[mostFragile] ?? '';
      final fDone = byHabitDone[mostFragile] ?? 0;
      final fSched = byHabitScheduled[mostFragile] ?? 0;
      sb.writeln('- Most fragile habit: $fTitle ($fDone/$fSched)');
    }

    if (goalLines.isNotEmpty) {
      sb.writeln('- Goal habits: ${goalLines.join(' · ')}');
    }

    final focusHabitId = mostFragile ?? strongest;
    final focusHabitTitle =
        focusHabitId == null ? null : (byHabitTitle[focusHabitId] ?? '').trim();

    sb.writeln('');
    sb.writeln('Micro-plan for next week:');
    if (focusHabitTitle == null || focusHabitTitle.isEmpty) {
      sb.writeln('1) Pick 1 habit to anchor (keep it tiny).');
    } else {
      sb.writeln(
          '1) Anchor habit: “$focusHabitTitle” (2-minute version counts).');
    }
    sb.writeln(
        '2) Choose one cue + time: after an existing routine (wake up, lunch, shower).');
    sb.writeln(
        '3) Protect the streak: if you miss, do the smallest “save” version the next day.');

    return sb.toString().trim();
  }

  Future<_OfflineAssistantResult> _offlineAssistantReply(
      HabitProvider provider, String input) async {
    final text = input.trim();
    final lower = text.toLowerCase();

    if (lower == 'analytics' ||
        lower.contains('open analytics') ||
        lower.contains('show analytics') ||
        lower.contains('open stats') ||
        lower.contains('show stats')) {
      await _actionOpenAnalytics();
      return const _OfflineAssistantResult(replyText: 'Opening Analytics.');
    }

    if (lower.contains('explain') &&
        (lower.contains('analytics') ||
            lower.contains('stats') ||
            lower.contains('progress'))) {
      final weeklyRate = _overallCompletionRate(provider, 'weekly');
      final monthlyRate = _overallCompletionRate(provider, 'monthly');
      final yearlyRate = _overallCompletionRate(provider, 'yearly');
      return _OfflineAssistantResult(
        replyText:
            'Here\'s the snapshot: weekly $weeklyRate%, monthly $monthlyRate%, yearly $yearlyRate%. If you want, tell me which habit feels hardest and I\'ll design a simpler system around it.',
      );
    }

    final renameMatch = RegExp(
      r'(?:rename|change|edit)\s+(?:my\s+)?habit\s+(.+?)\s+(?:to|into)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(text);
    if (renameMatch != null) {
      final fromRaw = _stripQuotes(renameMatch.group(1) ?? '').trim();
      final toRaw = _stripQuotes(renameMatch.group(2) ?? '').trim();
      final fromQuery = (trySanitizeHabitTitle(fromRaw) ?? fromRaw).trim();
      final to = trySanitizeHabitTitle(toRaw);
      if (fromQuery.isEmpty || to == null) {
        return const _OfflineAssistantResult(
          replyText: 'Tell me: “rename habit <old> to <new>”.',
        );
      }
      final habit = _findHabitByTitleQuery(provider, fromQuery);
      if (habit == null) {
        return _OfflineAssistantResult(
          replyText: 'I couldn\'t find a habit named “$fromQuery”.',
        );
      }

      final exists = provider.habits
          .any((h) => h.title.trim().toLowerCase() == to.toLowerCase());
      if (exists) {
        return _OfflineAssistantResult(
          replyText: 'You already have a habit named “$to”.',
        );
      }

      final updated = habit.copyWith(title: to);
      await provider.updateHabit(updated);
      return _OfflineAssistantResult(
        replyText: 'Done — renamed “${habit.title}” to “$to”.',
        actionSummary: '✓ Updated habit: $to',
      );
    }

    final reminderMatch = RegExp(
          r'(?:set|change|update|add|enable|turn\s+on)\s+(?:the\s+)?reminder\s+(?:for|on)\s+(.+?)\s+(?:to|at)\s+([0-2]?\d(?:[:\.][0-5]\d)?\s*(?:a\.?\s*m|p\.?\s*m|am|pm)?(?:\s+(?:in\s+the\s+)?(?:morning|afternoon|evening|night))?)\b',
          caseSensitive: false,
        ).firstMatch(text) ??
        RegExp(
          r'remind\s+me\s+(?:to|about)\s+(.+?)\s+at\s+([0-2]?\d(?:[:\.][0-5]\d)?\s*(?:a\.?\s*m|p\.?\s*m|am|pm)?(?:\s+(?:in\s+the\s+)?(?:morning|afternoon|evening|night))?)\b',
          caseSensitive: false,
        ).firstMatch(text);

    final reminderTimeFirstMatch = reminderMatch != null
        ? null
        : (RegExp(
              r'(?:set|change|update|add|enable|turn\s+on)\s+(?:the\s+)?reminder\s+(?:to|at)\s+([0-2]?\d(?:[:\.][0-5]\d)?\s*(?:a\.?\s*m|p\.?\s*m|am|pm)?(?:\s+(?:in\s+the\s+)?(?:morning|afternoon|evening|night))?)\s+(?:for|on)\s+(.+)$',
              caseSensitive: false,
            ).firstMatch(text) ??
            RegExp(
              r'remind\s+me\s+at\s+([0-2]?\d(?:[:\.][0-5]\d)?\s*(?:a\.?\s*m|p\.?\s*m|am|pm)?(?:\s+(?:in\s+the\s+)?(?:morning|afternoon|evening|night))?)\s+(?:to|about)\s+(.+)$',
              caseSensitive: false,
            ).firstMatch(text));

    if (reminderMatch != null || reminderTimeFirstMatch != null) {
      final rawTitle = _stripQuotes(reminderMatch != null
              ? (reminderMatch.group(1) ?? '')
              : (reminderTimeFirstMatch!.group(2) ?? ''))
          .trim();
      final habitName = (trySanitizeHabitTitle(rawTitle) ?? rawTitle).trim();
      final hm = reminderMatch != null
          ? _normalizeReminderTime(reminderMatch.group(2))
          : _normalizeReminderTime(reminderTimeFirstMatch!.group(1));
      if (habitName.isEmpty || hm == null) {
        return const _OfflineAssistantResult(
          replyText:
              'Tell me: “set reminder for <habit> at 9am”, or “set reminder at 7pm for <habit>” (also: 21:00, 09:30, 6.30).',
        );
      }
      final habit = _findHabitByTitleQuery(provider, habitName);
      if (habit == null) {
        return _OfflineAssistantResult(
          replyText: 'I couldn\'t find a habit named “$habitName”.',
        );
      }

      final updated = habit.copyWith(reminderEnabled: true, reminderTime: hm);
      await provider.updateHabit(updated);
      return _OfflineAssistantResult(
        replyText: 'Got it — I\'ll remind you at $hm for “${habit.title}”.',
        actionSummary: '✓ Updated habit: ${habit.title}',
      );
    }

    final completeMatch = RegExp(
      r'(?:mark|complete|check\s+off)\s+(.+?)(?:\s+(?:done|today))?$',
      caseSensitive: false,
    ).firstMatch(text);
    if (completeMatch != null) {
      final rawTitle = _stripQuotes(completeMatch.group(1) ?? '').trim();
      final habitName = (trySanitizeHabitTitle(rawTitle) ?? rawTitle).trim();
      final habit = _findHabitByTitleQuery(provider, habitName);
      if (habit == null) {
        return _OfflineAssistantResult(
          replyText: 'I couldn\'t find a habit named “$habitName”.',
        );
      }

      final now = DateTime.now();
      if (provider.isCompletedOnDate(habit.id, now)) {
        return _OfflineAssistantResult(
          replyText: '“${habit.title}” is already marked complete for today.',
        );
      }

      provider.toggleHabitCompletion(habit.id, now);
      return _OfflineAssistantResult(
        replyText: 'Done — marked “${habit.title}” as complete for today.',
        actionSummary: '✓ Marked "${habit.title}" as complete for today',
      );
    }

    final addMatch = RegExp(
      r'(?:add|create)\s+(?:a\s+)?habit\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(text);
    if (addMatch != null) {
      final rawTitle = _stripQuotes(addMatch.group(1) ?? '').trim();
      final title = trySanitizeHabitTitle(rawTitle);
      if (title == null) {
        return const _OfflineAssistantResult(
          replyText: 'Tell me: “add habit <name>”.',
        );
      }
      final exists = provider.habits
          .any((h) => h.title.trim().toLowerCase() == title.toLowerCase());
      if (exists) {
        return _OfflineAssistantResult(
          replyText: 'You already have a habit named “$title”.',
        );
      }

      await provider.addHabit(Habit(
        title: title,
        description: '',
        category: 'General',
        emoji: HabitIconRegistry.defaultKey,
        timeOfDay: 'anytime',
      ));
      return _OfflineAssistantResult(
        replyText: 'Added “$title”. Want a reminder time for it?',
        actionSummary: '✓ Added habit: $title',
      );
    }

    return _OfflineAssistantResult(
        replyText: _offlineCoachReply(provider, input));
  }

  int _overallCompletionRate(HabitProvider provider, String period) {
    if (provider.habits.isEmpty) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final periodStart = _getPeriodStart(today, period);

    var totalCompletions = 0;
    var totalPossible = 0;

    for (final habit in provider.habits) {
      final habitCreated = _dateOnly(habit.createdAt);
      final effectiveStart =
          habitCreated.isAfter(periodStart) ? habitCreated : periodStart;
      if (effectiveStart.isAfter(today)) continue;

      final completions = provider.logs.where((l) {
        if (!l.completed) return false;
        if (l.habitId != habit.id) return false;
        final logDate = _dateOnly(l.date);
        return !logDate.isBefore(effectiveStart);
      }).length;
      totalCompletions += completions;

      final daysInPeriod = today.difference(effectiveStart).inDays + 1;
      totalPossible += daysInPeriod;
    }

    if (totalPossible <= 0) return 0;
    return ((totalCompletions / totalPossible) * 100).round().clamp(0, 100);
  }

  DateTime _getPeriodStart(DateTime today, String period) {
    switch (period) {
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

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  _ParsedCoachResponse _parseCoachResponse(String rawReply) {
    final markerMatches = RegExp(
      r'ACTIONS_JSON\s*:\s*',
      caseSensitive: false,
    ).allMatches(rawReply).toList();
    if (markerMatches.isEmpty) {
      return _ParsedCoachResponse(
          visibleText: rawReply.trim(), actions: const []);
    }

    final last = markerMatches.last;
    final visibleText = rawReply.substring(0, last.start).trim();
    var jsonPart = rawReply.substring(last.end).trim();

    if (jsonPart.startsWith('```')) {
      final lines = jsonPart.split('\n').toList();
      if (lines.isNotEmpty && lines.first.trim().startsWith('```')) {
        lines.removeAt(0);
      }
      if (lines.isNotEmpty && lines.last.trim().startsWith('```')) {
        lines.removeLast();
      }
      jsonPart = lines.join('\n').trim();
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(jsonPart);
    } catch (_) {
      final objStart = jsonPart.indexOf('{');
      final objEnd = jsonPart.lastIndexOf('}');
      if (objStart >= 0 && objEnd > objStart) {
        final candidate = jsonPart.substring(objStart, objEnd + 1);
        try {
          decoded = jsonDecode(candidate);
        } catch (_) {}
      }

      if (decoded == null) {
        final arrStart = jsonPart.indexOf('[');
        final arrEnd = jsonPart.lastIndexOf(']');
        if (arrStart >= 0 && arrEnd > arrStart) {
          final candidate = jsonPart.substring(arrStart, arrEnd + 1);
          try {
            decoded = jsonDecode(candidate);
          } catch (_) {}
        }
      }
    }

    if (decoded is Map<String, dynamic>) {
      final actionsRaw = decoded['actions'];
      if (actionsRaw is List) {
        final actions = actionsRaw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        return _ParsedCoachResponse(visibleText: visibleText, actions: actions);
      }
    }

    if (decoded is List) {
      final actions = decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      return _ParsedCoachResponse(visibleText: visibleText, actions: actions);
    }

    return _ParsedCoachResponse(visibleText: visibleText, actions: const []);
  }

  Future<_AppliedActions> _applyCoachActions(
      HabitProvider provider, List<Map<String, dynamic>> actions) async {
    if (actions.isEmpty) return const _AppliedActions();

    final summaries = <String>[];
    final followups = <String>[];

    for (final action in actions) {
      final typeRaw = (action['type'] ??
              action['action'] ??
              action['name'] ??
              action['command'] ??
              '')
          .toString()
          .trim();

      final type = typeRaw
          .replaceAll(RegExp(r'([a-z])([A-Z])'), r'$1_$2')
          .replaceAll(RegExp(r'[\s\-]+'), '_')
          .toLowerCase()
          .trim();

      if (type.isEmpty) continue;

      switch (type) {
        case 'add_habit':
          try {
            final addResult = await _actionAddHabit(provider, action);
            if (addResult != null) summaries.add(addResult);
          } on HabitTitleParseException {
            followups.add(
                'What should I call that habit? Reply with just the habit name (e.g., “Journaling”).');
          } catch (_) {
            // Ignore
          }
          break;

        case 'complete_habit':
          try {
            final completeResult = await _actionCompleteHabit(provider, action);
            if (completeResult != null) summaries.add(completeResult);
          } catch (_) {
            // Ignore
          }
          break;

        case 'uncomplete_habit':
        case 'uncheck_habit':
        case 'undo_completion':
        case 'undo_habit':
          try {
            final undoResult = await _actionUncompleteHabit(provider, action);
            if (undoResult != null) summaries.add(undoResult);
          } catch (_) {
            // Ignore
          }
          break;

        case 'delete_habit':
          final rawTitle = (action['title'] ?? '').toString();
          final query = (trySanitizeHabitTitle(rawTitle) ?? rawTitle).trim();
          if (query.isEmpty) break;

          final habit = _findHabitByTitleQuery(provider, query);
          if (habit == null) break;

          _pendingDelete = _PendingDeleteRequest(
            habitId: habit.id,
            habitTitle: habit.title,
          );
          followups.add(
              'Are you sure you want to delete “${habit.title}”? Reply “yes” to confirm or “no” to cancel.');
          break;

        case 'update_habit':
          try {
            final updateResult = await _actionUpdateHabit(provider, action);
            if (updateResult != null) summaries.add(updateResult);
          } on HabitTitleParseException {
            followups.add(
                'What should the new habit name be? Reply with just the name.');
          } catch (_) {
            // Ignore
          }
          break;

        case 'plan_day':
          try {
            final planResult = await _actionPlanDay(provider, action);
            if (planResult != null) summaries.add(planResult);
          } catch (_) {
            // Ignore
          }
          break;

        case 'open_analytics':
          try {
            final openResult = await _actionOpenAnalytics();
            if (openResult != null) summaries.add(openResult);
          } catch (_) {
            // Ignore
          }
          break;

        default:
          // Unknown action type, skip
          break;
      }
    }

    return _AppliedActions(
      summary: summaries.isEmpty ? null : summaries.join('\n'),
      followup: followups.isEmpty ? null : followups.join('\n'),
    );
  }

  Future<String?> _actionAddHabit(
      HabitProvider provider, Map<String, dynamic> action) async {
    final title = sanitizeHabitTitle((action['title'] ?? '').toString());

    final exists = provider.habits
        .any((h) => h.title.trim().toLowerCase() == title.toLowerCase());
    if (exists) return null;

    final description = (action['description'] ?? '').toString().trim();
    final category = (action['category'] ?? 'General').toString().trim();
    final time = (action['timeOfDay'] ?? 'anytime').toString().trim();

    final iconAny = action['iconKey'] ?? action['emoji'] ?? action['icon'];
    final iconKey = HabitIconRegistry.normalizeStored(iconAny);

    final reminderTime = _normalizeReminderTime(action['reminderTime']);
    final reminderEnabledRaw = action['reminderEnabled'];
    final reminderEnabled = reminderEnabledRaw is bool
        ? reminderEnabledRaw
        : (reminderTime != null);
    final effectiveReminderTime = reminderEnabled ? reminderTime : null;

    await provider.addHabit(Habit(
      title: title,
      description: description,
      category: category.isEmpty ? 'General' : category,
      emoji: iconKey,
      timeOfDay: time.isEmpty ? 'anytime' : time,
      reminderEnabled: reminderEnabled,
      reminderTime: effectiveReminderTime,
    ));

    return '✓ Added habit: $title';
  }

  Future<String?> _actionCompleteHabit(
      HabitProvider provider, Map<String, dynamic> action) async {
    final rawTitle = (action['title'] ?? '').toString();
    final title = (trySanitizeHabitTitle(rawTitle) ?? rawTitle).trim();
    if (title.isEmpty) return null;

    final habit = _findHabitByTitleQuery(provider, title);
    if (habit == null) return null;

    try {
      final now = DateTime.now();
      if (provider.isCompletedOnDate(habit.id, now)) {
        return '✓ "${habit.title}" is already complete for today';
      }
      provider.toggleHabitCompletion(habit.id, now);
      return '✓ Marked "${habit.title}" as complete for today';
    } catch (_) {
      return null;
    }
  }

  Future<String?> _actionUncompleteHabit(
      HabitProvider provider, Map<String, dynamic> action) async {
    final rawTitle = (action['title'] ?? '').toString();
    final title = (trySanitizeHabitTitle(rawTitle) ?? rawTitle).trim();
    if (title.isEmpty) return null;

    final habit = _findHabitByTitleQuery(provider, title);
    if (habit == null) return null;

    try {
      final now = DateTime.now();
      if (!provider.isCompletedOnDate(habit.id, now)) {
        return '✓ "${habit.title}" is already not completed today';
      }
      provider.toggleHabitCompletion(habit.id, now);
      return '✓ Marked "${habit.title}" as not done for today';
    } catch (_) {
      return null;
    }
  }

  Future<String?> _actionUpdateHabit(
      HabitProvider provider, Map<String, dynamic> action) async {
    final rawTitle = (action['title'] ?? '').toString();
    final title = (trySanitizeHabitTitle(rawTitle) ?? rawTitle).trim();
    if (title.isEmpty) return null;

    final habit = _findHabitByTitleQuery(provider, title);
    if (habit == null) return null;

    try {
      final newTitleRaw = (action['newTitle'] ?? '').toString().trim();
      final newTitle =
          newTitleRaw.isEmpty ? '' : sanitizeHabitTitle(newTitleRaw);
      final newDescription = (action['description'] ?? '').toString().trim();
      final newCategory = (action['category'] ?? '').toString().trim();
      final newTime = (action['timeOfDay'] ?? '').toString().trim();
      final newIconKey = action['iconKey'];
      final reminderEnabledRaw = action['reminderEnabled'];
      final reminderTimeRaw = action['reminderTime'];

      final reminderEnabled = reminderEnabledRaw is bool
          ? reminderEnabledRaw
          : reminderEnabledRaw == null
              ? habit.reminderEnabled
              : reminderEnabledRaw.toString().toLowerCase().trim() == 'true';

      final rawReminderTime = (reminderTimeRaw ?? '').toString().trim();
      String? reminderTime;
      if (reminderTimeRaw == null) {
        reminderTime = habit.reminderTime;
      } else if (rawReminderTime.isEmpty) {
        reminderTime = null;
      } else {
        reminderTime =
            _normalizeReminderTime(rawReminderTime) ?? habit.reminderTime;
      }

      final updated = habit.copyWith(
        title: newTitle.isEmpty ? habit.title : newTitle,
        description:
            newDescription.isEmpty ? habit.description : newDescription,
        category: newCategory.isEmpty ? habit.category : newCategory,
        emoji: newIconKey != null
            ? HabitIconRegistry.normalizeStored(newIconKey)
            : habit.emoji,
        timeOfDay: newTime.isEmpty ? habit.timeOfDay : newTime,
        reminderEnabled: reminderEnabled,
        reminderTime: reminderTime,
      );

      await provider.updateHabit(updated);
      return '✓ Updated habit: ${updated.title}';
    } catch (_) {
      return null;
    }
  }

  String? _normalizeReminderTime(dynamic value) {
    var raw = (value ?? '').toString().trim().toLowerCase();
    if (raw.isEmpty) return null;

    raw = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    raw = raw.replaceFirst(RegExp(r'^(?:at|around|about)\s+'), '').trim();

    if (raw == 'noon') return '12:00';
    if (raw == 'midnight') return '00:00';

    // Convert dot-separated times like 6.30 -> 6:30 (do this before removing '.')
    raw = raw.replaceAllMapped(
      RegExp(r'(\d)\.(\d)'),
      (m) => '${m.group(1)}:${m.group(2)}',
    );

    // Remove remaining dots (mostly from a.m./p.m. forms).
    raw = raw.replaceAll('.', '').trim();

    // Normalise "a m" / "p m" into "am" / "pm".
    raw = raw.replaceAll(RegExp(r'\b([ap])\s+m\b'), r'$1m');

    // Allow "7 30" as "7:30".
    final spaced =
        RegExp(r'^([0-2]?\d)\s+([0-5]\d)\s*(am|pm)?$').firstMatch(raw);
    if (spaced != null) {
      final h = spaced.group(1);
      final m = spaced.group(2);
      final suffix = spaced.group(3);
      raw = '${h ?? ''}:${m ?? ''}${suffix ?? ''}';
    }

    final dayPart = RegExp(
            r'^([0-1]?\d)(?::([0-5]\d))?\s*(am|pm)?\s*(?:in\s+the\s+)?(morning|afternoon|evening|night)$')
        .firstMatch(raw);
    if (dayPart != null) {
      var hour = int.tryParse(dayPart.group(1)!);
      final minute = int.tryParse(dayPart.group(2) ?? '0');
      final explicitSuffix = (dayPart.group(3) ?? '').trim();
      final part = dayPart.group(4)!;
      if (hour == null || minute == null) return null;
      if (hour < 1 || hour > 12) return null;
      if (minute < 0 || minute > 59) return null;

      final suffix = explicitSuffix.isNotEmpty
          ? explicitSuffix
          : (part == 'morning' ? 'am' : 'pm');

      if (suffix == 'am') {
        if (hour == 12) hour = 0;
      } else {
        if (hour != 12) hour += 12;
      }

      final hh = hour.toString().padLeft(2, '0');
      final mm = minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }

    final hhmm = RegExp(r'^([0-2]?\d):([0-5]\d)$').firstMatch(raw);
    if (hhmm != null) {
      final hour = int.tryParse(hhmm.group(1)!);
      final minute = int.tryParse(hhmm.group(2)!);
      if (hour == null || minute == null) return null;
      if (hour < 0 || hour > 23) return null;
      if (minute < 0 || minute > 59) return null;

      final hh = hour.toString().padLeft(2, '0');
      final mm = minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }

    final ampm =
        RegExp(r'^([0-1]?\d)(?::([0-5]\d))?\s*(am|pm)$').firstMatch(raw);
    if (ampm != null) {
      var hour = int.tryParse(ampm.group(1)!);
      final minute = int.tryParse(ampm.group(2) ?? '0');
      final suffix = ampm.group(3)!;
      if (hour == null || minute == null) return null;
      if (hour < 1 || hour > 12) return null;
      if (minute < 0 || minute > 59) return null;

      if (suffix == 'am') {
        if (hour == 12) hour = 0;
      } else {
        if (hour != 12) hour += 12;
      }

      final hh = hour.toString().padLeft(2, '0');
      final mm = minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }

    final hourOnly = RegExp(r'^([0-2]?\d)$').firstMatch(raw);
    if (hourOnly != null) {
      final hour = int.tryParse(hourOnly.group(1)!);
      if (hour == null) return null;
      if (hour < 0 || hour > 23) return null;
      final hh = hour.toString().padLeft(2, '0');
      return '$hh:00';
    }

    return null;
  }

  Future<String?> _actionOpenAnalytics() async {
    if (!mounted) return null;
    try {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const StatsScreen()));
      return '✓ Opened Analytics';
    } catch (_) {
      return 'I couldn\'t open Analytics on this device.';
    }
  }

  Future<String?> _actionPlanDay(
      HabitProvider provider, Map<String, dynamic> action) async {
    final habitsRaw = action['habits'];
    if (habitsRaw is! List || habitsRaw.isEmpty) return null;

    final newHabitTitles = <String>[];
    for (final h in habitsRaw) {
      if (h is! Map) continue;
      final rawTitle = (h['title'] ?? '').toString();
      String title;
      try {
        title = sanitizeHabitTitle(rawTitle);
      } catch (_) {
        continue;
      }

      final exists = provider.habits.any(
          (habit) => habit.title.trim().toLowerCase() == title.toLowerCase());
      if (exists) continue;

      final description = (h['description'] ?? '').toString().trim();
      final category = (h['category'] ?? 'Daily').toString().trim();
      final time = (h['timeOfDay'] ?? 'morning').toString().trim();
      final iconAny = h['iconKey'] ?? h['emoji'] ?? h['icon'];
      final iconKey = HabitIconRegistry.normalizeStored(iconAny);

      await provider.addHabit(Habit(
        title: title,
        description: description,
        category: category.isEmpty ? 'Daily' : category,
        emoji: iconKey,
        timeOfDay: time.isEmpty ? 'morning' : time,
      ));
      newHabitTitles.add(title);
    }

    if (newHabitTitles.isEmpty) return null;
    return '✓ Created today plan: ${newHabitTitles.join(', ')}';
  }

  String _fallbackReply(HabitProvider provider, String input, {String? error}) {
    final q = input.toLowerCase();
    final err = (error ?? '').toLowerCase();

    final now = DateTime.now();
    final todayDone = provider.habits
        .where((h) => provider.isCompletedOnDate(h.id, now))
        .length;
    final totalHabits = provider.habits.length;
    final pending = (totalHabits - todayDone).clamp(0, totalHabits);

    int bestStreak = 0;
    for (final habit in provider.habits) {
      final s = provider.getStreak(habit.id);
      if (s > bestStreak) bestStreak = s;
    }

    if (q.contains('sad') ||
        q.contains('stress') ||
        q.contains('anx') ||
        q.contains('overwhelm') ||
        q.contains('tired') ||
        q.contains('feel')) {
      return 'Thanks for sharing that. Let us make today lighter: pick 1 tiny habit (2-5 minutes), finish it, then we reassess. Right now you are at $todayDone/$totalHabits completed. Small wins first.';
    }

    if (q.contains('productivity') ||
        q.contains('focus') ||
        q.contains('plan') ||
        q.contains('schedule')) {
      return 'Productivity plan: 1) Do the hardest pending habit first. 2) Run 2 focus blocks of 25 minutes. 3) Close the day with one easy habit for momentum. You have $pending pending habit(s) today.';
    }

    if (q.contains('suggest') ||
        q.contains('habit') ||
        q.contains('recommend')) {
      final suggestion = _buildHabitSuggestion(provider);
      return 'Custom suggestion: $suggestion';
    }

    if (q.contains('streak')) {
      return bestStreak == 0
          ? 'You are in streak-building mode. Complete one habit now, then repeat tomorrow at the same time to start your first streak.'
          : 'Your best current streak is $bestStreak day(s). Protect it by completing one anchor habit in the next hour.';
    }

    if (q.contains('motivate') || q.contains('motivation')) {
      return 'You do not need maximum motivation, just minimum action. Finish one tiny habit now, then let progress create motivation.';
    }

    if (!_llmService.isConfigured) {
      return 'I\'m not able to reach the assistant service right now. '
          'Try again in a moment — I can still help with habit actions and simple coaching.';
    }

    if (err.contains('402') ||
        err.contains('insufficient') ||
        err.contains('quota') ||
        err.contains('credits')) {
      return 'Your AI provider key is valid, but there are no credits/quota available for this model right now. Add credits or switch model, then send again.';
    }

    if (err.contains('404') ||
        err.contains('model not found') ||
        err.contains('no endpoints found')) {
      return 'The selected Groq model is unavailable for your key. Try another Groq model and send again.';
    }

    if (err.contains('401') ||
        err.contains('authentication') ||
        err.contains('unauthorized') ||
        err.contains('api key')) {
      return 'I could not authenticate with the AI provider. Check your API key in your run configuration, then send again. I can still coach you here while that is fixed.';
    }

    if (err.contains('429') || err.contains('rate limit')) {
      return 'The AI provider is rate-limiting requests right now. Wait a bit and try again. Meanwhile, complete one tiny habit to keep momentum.';
    }

    if (err.contains('timeout') ||
        err.contains('socket') ||
        err.contains('network')) {
      return 'Network issue while contacting the AI provider. Check connection and try again in a moment.';
    }

    return 'I had trouble reaching the model just now. Try again in a moment. Meanwhile: pick one tiny habit and complete it now to keep momentum.';
  }

  String _buildHabitSuggestion(HabitProvider provider) {
    if (provider.habits.isEmpty) {
      return 'Start with a 2-minute habit: drink water after waking up. Keep it so small you cannot fail.';
    }

    final hydrationHabit = provider.habits
        .where((h) => h.title.toLowerCase().contains('water'))
        .toList();
    if (hydrationHabit.isNotEmpty) {
      return 'Stack your water habit with an existing trigger: drink one glass right after brushing your teeth.';
    }

    final hasNightHabit = provider.habits
        .where((h) => h.timeOfDay.toLowerCase().contains('evening'))
        .isNotEmpty;

    if (!hasNightHabit) {
      return 'Add one evening shutdown habit: 5-minute desk reset before sleep. It improves tomorrow focus.';
    }

    return 'Add a "minimum version" rule to one hard habit. Example: 20-min workout becomes 5-min fallback on busy days.';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HabitProvider>();
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    final bg = isDark ? AppThemeDark.background : AppTheme.background;
    final surface = isDark ? AppThemeDark.surface : AppTheme.surface;
    final primaryText =
        isDark ? AppThemeDark.primaryText : AppTheme.primaryText;
    final secondaryText =
        isDark ? AppThemeDark.secondaryText : AppTheme.secondaryText;
    final border = isDark ? AppThemeDark.whisperBorder : AppTheme.whisperBorder;
    final accent = isDark ? AppThemeDark.primaryBlue : AppTheme.primaryBlue;
    final cardShadow =
        isDark ? AppThemeDark.softCardShadow : AppTheme.softCardShadow;

    final hasUserMessage = _messages.any((m) => m.role == _Role.user);
    final showHome = !_voiceMode && !hasUserMessage;

    return Scaffold(
      backgroundColor: bg,
      appBar: _voiceMode
          ? null
          : showHome
              ? null
              : _buildChatpodiaAppBar(
                  context,
                  title: 'Atom',
                  bg: bg,
                  surface: surface,
                  border: border,
                  primaryText: primaryText,
                  accent: accent,
                  isDark: isDark,
                  onBack: () => Navigator.of(context).pop(),
                  showMore: true,
                ),
      body: _voiceMode
          ? _buildVoiceModeBody(
              context,
              provider,
              bg: bg,
              surface: surface,
              primaryText: primaryText,
              secondaryText: secondaryText,
              border: border,
              accent: accent,
              cardShadow: cardShadow,
              isDark: isDark,
            )
          : showHome
              ? _buildAssistantHomeBody(
                  context,
                  provider,
                  bg: bg,
                  surface: surface,
                  primaryText: primaryText,
                  secondaryText: secondaryText,
                  border: border,
                  accent: accent,
                  cardShadow: cardShadow,
                  isDark: isDark,
                )
              : _buildChatBody(
                  context,
                  provider,
                  bg: bg,
                  surface: surface,
                  primaryText: primaryText,
                  secondaryText: secondaryText,
                  border: border,
                  accent: accent,
                  cardShadow: cardShadow,
                  isDark: isDark,
                ),
    );
  }

  Widget _buildVoiceModeBody(
    BuildContext context,
    HabitProvider provider, {
    required Color bg,
    required Color surface,
    required Color primaryText,
    required Color secondaryText,
    required Color border,
    required Color accent,
    required List<BoxShadow> cardShadow,
    required bool isDark,
  }) {
    final status = _isLoading
        ? 'Thinking…'
        : _isSpeaking
            ? 'Atom is speaking… you’ve got this.'
            : _isListening
                ? 'Atom is listening…'
                : 'Tap the mic to talk';

    final hasUserTurn = _messages.any((m) => m.role == _Role.user);
    final transcript = () {
      if (_isSpeaking) {
        final full = _ttsSpokenText.isNotEmpty
            ? _ttsSpokenText
            : _voiceAssistantSubtitle;
        if (full.trim().isNotEmpty) return full;

        for (var i = _messages.length - 1; i >= 0; i--) {
          final m = _messages[i];
          if (m.role != _Role.bot) continue;
          if (m.text.trimLeft().startsWith('✓')) continue;
          return m.text;
        }
        return '';
      }

      final draft = _voiceDraft.trim();
      if (draft.isNotEmpty) return draft;

      if (_isListening || _isLoading) {
        final pinned = _voiceUserSubtitle.trim();
        if (pinned.isNotEmpty) return pinned;

        for (var i = _messages.length - 1; i >= 0; i--) {
          final m = _messages[i];
          if (m.role == _Role.user) return m.text;
        }
      }

      if (!hasUserTurn) {
        return 'Say something like “Help me plan my day.”';
      }

      return '';
    }();

    final showTranscript = transcript.trim().isNotEmpty;

    final bottomFade =
        Color.lerp(accent, Colors.white, isDark ? 0.70 : 0.78) ?? accent;
    final midFade = Color.lerp(bg, accent, isDark ? 0.22 : 0.22) ?? bg;

    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  bg,
                  midFade,
                  bottomFade,
                ],
                stops: const [0.0, 0.62, 1.0],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Container(
            color: (isDark ? Colors.black : Colors.white)
                .withValues(alpha: isDark ? 0.26 : 0.06),
          ),
        ),
        SafeArea(
          child: AnimatedBuilder(
            animation: _flowController,
            builder: (context, _) {
              final t = _flowController.value;
              final isActive = _isListening || _isSpeaking || _isLoading;
              // Keep transcript stable (no bobbing) while speaking.
              final floatY = isActive ? 0.0 : 0.0;

              Widget subtitleBlock() {
                if (!showTranscript) return const SizedBox.shrink();

                final baseStyle = GoogleFonts.urbanist(
                  fontSize: 40,
                  height: 1.16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                  color: primaryText,
                );

                final talkPulse = (math.sin(t * 2 * math.pi * 5) + 1) / 2;

                Widget transcriptWidget() {
                  // Karaoke-style highlight while TTS is speaking: spoken words
                  // remain in place and turn bright; upcoming words are faded.
                  if (_isSpeaking && transcript.trim().isNotEmpty) {
                    final full = transcript;
                    final inserts = _getInlineIconInserts(full);
                    var safe = _ttsSpokenOffset;
                    if (safe < 0) safe = 0;
                    if (safe > full.length) safe = full.length;

                    var wStart = _ttsWordStart;
                    var wEnd = _ttsWordEnd;
                    if (wStart < 0) wStart = 0;
                    if (wEnd < 0) wEnd = 0;
                    if (wStart > full.length) wStart = full.length;
                    if (wEnd > full.length) wEnd = full.length;
                    if (wStart > wEnd) wStart = wEnd;

                    final fadedColor =
                        primaryText.withValues(alpha: isDark ? 0.22 : 0.28);
                    final glowAlpha = (isDark ? 0.34 : 0.26) +
                        talkPulse * (isDark ? 0.30 : 0.24);
                    final glowBlur = 18 + talkPulse * 14;

                    final highlightStyle = baseStyle.copyWith(
                      color: accent,
                      decoration: TextDecoration.underline,
                      decorationColor: accent.withValues(
                        alpha: 0.45 + talkPulse * 0.45,
                      ),
                      decorationThickness: 2.4,
                      shadows: [
                        Shadow(
                          color: accent.withValues(alpha: glowAlpha),
                          blurRadius: glowBlur,
                          offset: const Offset(0, 0),
                        ),
                      ],
                    );

                    final iconFontSize = ((baseStyle.fontSize ?? 40) * 0.72)
                        .clamp(24.0, 32.0)
                        .toDouble();
                    final iconColor =
                        Color.lerp(primaryText, accent, 0.72) ?? accent;
                    final iconGlowAlpha = (isDark ? 0.18 : 0.14) +
                        talkPulse * (isDark ? 0.28 : 0.22);
                    final iconGlowBlur = 14 + talkPulse * 10;

                    final spans = <InlineSpan>[];

                    final hasWord = (wEnd - wStart) > 0;

                    final insertMap = <int, List<_InlineIconInsert>>{};
                    for (final ins in inserts) {
                      final idx = ins.index.clamp(0, full.length);
                      insertMap
                          .putIfAbsent(idx, () => <_InlineIconInsert>[])
                          .add(
                            ins,
                          );
                    }

                    void addInsertsAt(int index) {
                      final list = insertMap[index];
                      if (list == null || list.isEmpty) return;

                      for (final ins in list) {
                        final ahead = ins.index > safe;
                        final a = ahead
                            ? (0.30 + talkPulse * 0.12)
                            : (0.90 + talkPulse * 0.10);

                        if (ins.leadingSpace) {
                          spans.add(TextSpan(text: ' ', style: baseStyle));
                        }

                        spans.add(
                          TextSpan(
                            text: String.fromCharCode(ins.icon.codePoint),
                            style: baseStyle.copyWith(
                              fontFamily: ins.icon.fontFamily,
                              package: ins.icon.fontPackage,
                              fontSize: iconFontSize,
                              height: 1.0,
                              color: iconColor.withValues(alpha: a),
                              shadows: [
                                Shadow(
                                  color:
                                      accent.withValues(alpha: iconGlowAlpha),
                                  blurRadius: iconGlowBlur,
                                  offset: const Offset(0, 0),
                                ),
                              ],
                            ),
                          ),
                        );

                        if (ins.trailingSpace) {
                          spans.add(TextSpan(text: ' ', style: baseStyle));
                        }
                      }
                    }

                    TextStyle styleForIndex(int idx) {
                      if (!hasWord) {
                        return idx < safe
                            ? baseStyle
                            : baseStyle.copyWith(color: fadedColor);
                      }
                      if (idx < wStart) return baseStyle;
                      if (idx < wEnd) return highlightStyle;
                      if (idx < safe) return baseStyle;
                      return baseStyle.copyWith(color: fadedColor);
                    }

                    final breakpointsSet = <int>{
                      0,
                      full.length,
                      safe,
                      for (final ins in inserts)
                        ins.index.clamp(0, full.length),
                      if (hasWord) wStart,
                      if (hasWord) wEnd,
                    };
                    final breakpoints = breakpointsSet.toList(growable: false)
                      ..sort();

                    addInsertsAt(0);

                    for (var i = 0; i < breakpoints.length - 1; i++) {
                      final start = breakpoints[i];
                      final end = breakpoints[i + 1];
                      if (end > start) {
                        spans.add(
                          TextSpan(
                            text: full.substring(start, end),
                            style: styleForIndex(start),
                          ),
                        );
                      }
                      addInsertsAt(end);
                    }

                    return Text.rich(
                      TextSpan(children: spans),
                      textAlign: TextAlign.center,
                    );
                  }

                  return Text(
                    transcript,
                    textAlign: TextAlign.center,
                    style: baseStyle,
                  );
                }

                return Transform.translate(
                  offset: Offset(0, floatY),
                  child: ClipRect(
                    child: ShaderMask(
                      blendMode: BlendMode.modulate,
                      shaderCallback: (rect) => LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white,
                          Colors.white,
                          Colors.white.withValues(alpha: 0.14),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                        stops: const [0.0, 0.58, 0.86, 1.0],
                      ).createShader(rect),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: KeyedSubtree(
                          key: ValueKey(transcript),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final viewHeight = constraints.maxHeight;
                              final viewWidth = constraints.maxWidth;
                              final topPad = viewHeight * 0.22;
                              final bottomPad = viewHeight * 0.30;

                              if (_isSpeaking) {
                                final inserts =
                                    _getInlineIconInserts(transcript);
                                final iconFontSize =
                                    ((baseStyle.fontSize ?? 40) * 0.72)
                                        .clamp(24.0, 32.0)
                                        .toDouble();

                                final measureSpans = <InlineSpan>[];

                                var cursor = 0;
                                for (final ins in inserts) {
                                  final idx =
                                      ins.index.clamp(0, transcript.length);
                                  if (idx > cursor) {
                                    measureSpans.add(
                                      TextSpan(
                                        text: transcript.substring(cursor, idx),
                                        style: baseStyle,
                                      ),
                                    );
                                  }

                                  if (ins.leadingSpace) {
                                    measureSpans.add(
                                      TextSpan(text: ' ', style: baseStyle),
                                    );
                                  }
                                  measureSpans.add(
                                    TextSpan(
                                      text: String.fromCharCode(
                                          ins.icon.codePoint),
                                      style: baseStyle.copyWith(
                                        fontFamily: ins.icon.fontFamily,
                                        package: ins.icon.fontPackage,
                                        fontSize: iconFontSize,
                                        height: 1.0,
                                      ),
                                    ),
                                  );
                                  if (ins.trailingSpace) {
                                    measureSpans.add(
                                      TextSpan(text: ' ', style: baseStyle),
                                    );
                                  }

                                  cursor = idx;
                                }

                                if (cursor < transcript.length) {
                                  measureSpans.add(
                                    TextSpan(
                                      text: transcript.substring(cursor),
                                      style: baseStyle,
                                    ),
                                  );
                                }

                                final measureText = TextSpan(
                                    style: baseStyle, children: measureSpans);

                                final safeOffset = _ttsSpokenOffset.clamp(
                                    0, transcript.length);
                                final caretOffset =
                                    _decoratedCaretOffsetForOriginalOffset(
                                  originalOffset: safeOffset,
                                  inserts: inserts,
                                );

                                _maybeAutoScrollVoiceTranscript(
                                  fullText: transcript,
                                  spokenOffset: _ttsSpokenOffset,
                                  style: baseStyle,
                                  maxWidth: viewWidth,
                                  viewHeight: viewHeight,
                                  topPadding: topPad,
                                  textDirection: Directionality.of(context),
                                  measureText: measureText,
                                  measureCaretOffset: caretOffset,
                                );
                              }

                              return SizedBox.expand(
                                child: SingleChildScrollView(
                                  controller: _voiceTranscriptScrollController,
                                  padding: EdgeInsets.only(
                                    top: topPad,
                                    bottom: bottomPad,
                                  ),
                                  physics: const BouncingScrollPhysics(),
                                  child: transcriptWidget(),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  const SizedBox(height: 14),
                  Text(
                    status,
                    style: GoogleFonts.urbanist(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                      color: primaryText.withValues(alpha: 0.92),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 58,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _VoiceWavePainter(
                        accent: accent,
                        surface: surface,
                        t: t,
                        isDark: isDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 26),
                        child: subtitleBlock(),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
                    child: AnimatedBuilder(
                      animation: _flowController,
                      builder: (context, _) {
                        final pulse = (math.sin(t * 2 * math.pi) + 1) / 2;
                        final ringAlpha =
                            _isListening ? 0.18 + pulse * 0.22 : 0.10;
                        final ringScale =
                            _isListening ? 1.0 + pulse * 0.18 : 1.0;

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _roundIconButton(
                              icon: Icons.chat_bubble_outline_rounded,
                              onTap: () => _setVoiceMode(false, provider),
                              surface: surface,
                              border: border,
                              iconColor: primaryText,
                              size: 54,
                            ),
                            const SizedBox(width: 16),
                            InkWell(
                              enableFeedback: false,
                              onTap: _isLoading
                                  ? null
                                  : () async => _toggleListening(provider),
                              borderRadius: BorderRadius.circular(999),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Transform.scale(
                                    scale: ringScale,
                                    child: Container(
                                      width: 92,
                                      height: 92,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: accent.withValues(
                                            alpha: ringAlpha,
                                          ),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 76,
                                    height: 76,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _isLoading
                                          ? accent.withValues(alpha: 0.65)
                                          : accent,
                                      boxShadow: cardShadow,
                                    ),
                                    child: Icon(
                                      _isListening
                                          ? Icons.pause_rounded
                                          : Icons.mic_rounded,
                                      color: Colors.white,
                                      size: 34,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            _roundIconButton(
                              icon: Icons.close_rounded,
                              onTap: () async {
                                _autoListenToken++;
                                final nav = Navigator.of(context);
                                await _speech.stop();
                                await _stopSpeaking();
                                if (!mounted) return;
                                if (nav.canPop()) {
                                  nav.pop();
                                  return;
                                }
                                await _setVoiceMode(false, provider);
                              },
                              surface: surface,
                              border: border,
                              iconColor: primaryText,
                              size: 54,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  AppBar _buildChatpodiaAppBar(
    BuildContext context, {
    required String title,
    required Color bg,
    required Color surface,
    required Color border,
    required Color primaryText,
    required Color accent,
    required bool isDark,
    required VoidCallback onBack,
    required bool showMore,
  }) {
    return AppBar(
      backgroundColor: bg,
      elevation: 0,
      centerTitle: true,
      leadingWidth: 58,
      leading: Padding(
        padding: const EdgeInsets.only(left: 14),
        child: _roundIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: onBack,
          surface: surface,
          border: border,
          iconColor: primaryText,
        ),
      ),
      title: Text(
        title,
        style: GoogleFonts.urbanist(
          fontWeight: FontWeight.w900,
          letterSpacing: -0.6,
          color: primaryText,
        ),
      ),
      actions: [
        if (showMore)
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: _roundIconButton(
              icon: Icons.more_horiz,
              onTap: () => _showChatMoreSheet(
                surface: surface,
                border: border,
                primaryText: primaryText,
                accent: accent,
                isDark: isDark,
              ),
              surface: surface,
              border: border,
              iconColor: primaryText,
            ),
          ),
      ],
    );
  }

  Future<void> _showChatMoreSheet({
    required Color surface,
    required Color border,
    required Color primaryText,
    required Color accent,
    required bool isDark,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        final tileBg = Color.lerp(
              surface,
              accent,
              isDark ? 0.04 : 0.03,
            ) ??
            surface;

        Widget actionTile({
          required IconData icon,
          required String title,
          required VoidCallback onTap,
        }) {
          return InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: tileBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: border),
              ),
              child: Row(
                children: [
                  Icon(icon, color: primaryText, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.urbanist(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                        color: primaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 10),
                  child: Row(
                    children: [
                      Text(
                        'Options',
                        style: GoogleFonts.urbanist(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                          color: primaryText,
                        ),
                      ),
                      const Spacer(),
                      _roundIconButton(
                        icon: Icons.close_rounded,
                        onTap: () => Navigator.of(sheetContext).pop(),
                        surface: surface,
                        border: border,
                        iconColor: primaryText,
                        size: 46,
                      ),
                    ],
                  ),
                ),
                actionTile(
                  icon: Icons.stop_circle_outlined,
                  title: 'Stop speaking',
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _stopSpeaking();
                  },
                ),
                const SizedBox(height: 10),
                actionTile(
                  icon: Icons.delete_outline_rounded,
                  title: 'Clear chat',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    setState(() {
                      _messages.clear();
                      _quickRepliesExpanded = false;
                      _voiceAssistantSubtitle = '';
                      _ttsSpokenText = '';
                      _ttsSpokenOffset = 0;
                    });
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAssistantHomeBody(
    BuildContext context,
    HabitProvider provider, {
    required Color bg,
    required Color surface,
    required Color primaryText,
    required Color secondaryText,
    required Color border,
    required Color accent,
    required List<BoxShadow> cardShadow,
    required bool isDark,
  }) {
    final actions = <({IconData icon, String label, String prompt})>[
      (
        icon: Icons.auto_awesome_outlined,
        label: 'Habit ideas',
        prompt: 'Suggest one tiny habit I can do today.',
      ),
      (
        icon: Icons.calendar_month_outlined,
        label: 'Weekly reflection',
        prompt:
            'Weekly reflection: recap my last 7 days and give me a micro-plan for next week.',
      ),
      (
        icon: Icons.edit_note_rounded,
        label: 'Journal prompt',
        prompt: 'Give me a gentle journal prompt for today.',
      ),
      (
        icon: Icons.air_rounded,
        label: 'Breathing reset',
        prompt: 'Guide me through a 60-second breathing reset.',
      ),
      (
        icon: Icons.spa_outlined,
        label: 'Meditation',
        prompt: 'Recommend a short meditation session from my library.',
      ),
      (
        icon: Icons.track_changes_rounded,
        label: 'Focus',
        prompt: 'Help me focus for the next 25 minutes.',
      ),
    ];

    return Stack(
      children: [
        Positioned.fill(
          child: _assistantBackdrop(bg: bg, accent: accent, isDark: isDark),
        ),
        SafeArea(
          top: true,
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                  children: [
                    Text(
                      'Hi, how can I help you?',
                      style: GoogleFonts.urbanist(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.1,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your smart habit coach is ready',
                      style: GoogleFonts.urbanist(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: secondaryText,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final a in actions)
                          _quickChip(
                            icon: a.icon,
                            label: a.label,
                            onTap: () => _sendMessage(provider, a.prompt),
                            surface: surface,
                            border: border,
                            textColor: primaryText,
                            iconColor: primaryText,
                          ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Text(
                          'Popular topics',
                          style: GoogleFonts.urbanist(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                            color: primaryText,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () => _showAllTopicsSheet(
                            provider,
                            surface: surface,
                            border: border,
                            primaryText: primaryText,
                            secondaryText: secondaryText,
                            accent: accent,
                            isDark: isDark,
                          ),
                          borderRadius: BorderRadius.circular(999),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            child: Text(
                              'See all',
                              style: GoogleFonts.urbanist(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: secondaryText,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _topicCard(
                            icon: Icons.wb_sunny_outlined,
                            title: 'Morning routine',
                            subtitle: 'Build an easy start',
                            onTap: () => _sendMessage(
                              provider,
                              'Help me build a simple morning routine for the next 7 days.',
                            ),
                            surface: surface,
                            border: border,
                            primaryText: primaryText,
                            secondaryText: secondaryText,
                            accent: accent,
                            cardShadow: cardShadow,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _topicCard(
                            icon: Icons.hotel_outlined,
                            title: 'Better sleep',
                            subtitle: 'Wind down gently',
                            onTap: () => _sendMessage(
                              provider,
                              'Help me create a calming sleep routine for tonight.',
                            ),
                            surface: surface,
                            border: border,
                            primaryText: primaryText,
                            secondaryText: secondaryText,
                            accent: accent,
                            cardShadow: cardShadow,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _buildComposer(
                provider,
                bg: bg,
                surface: surface,
                primaryText: primaryText,
                secondaryText: secondaryText,
                border: border,
                accent: accent,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showAllTopicsSheet(
    HabitProvider provider, {
    required Color surface,
    required Color border,
    required Color primaryText,
    required Color secondaryText,
    required Color accent,
    required bool isDark,
  }) async {
    final topics =
        <({IconData icon, String title, String subtitle, String prompt})>[
      (
        icon: Icons.wb_sunny_outlined,
        title: 'Morning routine',
        subtitle: 'Build an easy start',
        prompt: 'Help me build a simple morning routine for the next 7 days.',
      ),
      (
        icon: Icons.hotel_outlined,
        title: 'Better sleep',
        subtitle: 'Wind down gently',
        prompt: 'Help me create a calming sleep routine for tonight.',
      ),
      (
        icon: Icons.water_drop_outlined,
        title: 'Hydration',
        subtitle: 'Make it effortless',
        prompt: 'Help me build a simple water habit for this week.',
      ),
      (
        icon: Icons.directions_walk_rounded,
        title: 'Daily movement',
        subtitle: 'Small wins daily',
        prompt: 'Help me add a simple daily movement habit.',
      ),
      (
        icon: Icons.self_improvement_rounded,
        title: 'Stress reset',
        subtitle: 'Calm your nervous system',
        prompt: 'Guide me through a quick stress reset I can do today.',
      ),
      (
        icon: Icons.nightlight_round,
        title: 'Evening routine',
        subtitle: 'End the day well',
        prompt: 'Help me build a simple evening routine for tonight.',
      ),
    ];

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        final h = MediaQuery.of(sheetContext).size.height;
        final sheetHeight = math.min(h * 0.72, 520.0);

        return SafeArea(
          top: false,
          child: SizedBox(
            height: sheetHeight,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                  child: Row(
                    children: [
                      Text(
                        'Popular topics',
                        style: GoogleFonts.urbanist(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                          color: primaryText,
                        ),
                      ),
                      const Spacer(),
                      _roundIconButton(
                        icon: Icons.close_rounded,
                        onTap: () => Navigator.of(sheetContext).pop(),
                        surface: surface,
                        border: border,
                        iconColor: primaryText,
                        size: 46,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: topics.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final t = topics[index];
                      final tileBg = Color.lerp(
                            surface,
                            accent,
                            isDark ? 0.04 : 0.03,
                          ) ??
                          surface;

                      return InkWell(
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          _sendMessage(provider, t.prompt);
                        },
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: tileBg,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: accent.withValues(
                                    alpha: isDark ? 0.16 : 0.14,
                                  ),
                                ),
                                child: Icon(
                                  t.icon,
                                  color: primaryText,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t.title,
                                      style: GoogleFonts.urbanist(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.2,
                                        color: primaryText,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      t.subtitle,
                                      style: GoogleFonts.urbanist(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: secondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
        );
      },
    );
  }

  Widget _buildChatBody(
    BuildContext context,
    HabitProvider provider, {
    required Color bg,
    required Color surface,
    required Color primaryText,
    required Color secondaryText,
    required Color border,
    required Color accent,
    required List<BoxShadow> cardShadow,
    required bool isDark,
  }) {
    final showQuickReplies =
        !_isLoading && _messages.any((m) => m.role == _Role.user);
    final extraCount = (_isLoading ? 1 : 0) + (showQuickReplies ? 1 : 0);

    return Stack(
      children: [
        Positioned.fill(
          child: _assistantBackdrop(bg: bg, accent: accent, isDark: isDark),
        ),
        SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  itemCount: _messages.length + extraCount,
                  itemBuilder: (context, index) {
                    if (index < _messages.length) {
                      final m = _messages[index];
                      final isUser = m.role == _Role.user;

                      if (isUser) {
                        final bubbleColor = isDark ? Colors.white : accent;
                        final textColor = isDark ? Colors.black : Colors.white;

                        return Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.78,
                            ),
                            decoration: BoxDecoration(
                              color: bubbleColor,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              m.text,
                              style: GoogleFonts.urbanist(
                                color: textColor,
                                height: 1.35,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        );
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _assistantAvatar(
                              accent: accent,
                              surface: surface,
                              border: border,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: surface,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(color: border),
                                    ),
                                    child: Text(
                                      m.text,
                                      style: GoogleFonts.urbanist(
                                        color: primaryText,
                                        height: 1.35,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final extraIndex = index - _messages.length;
                    if (_isLoading && extraIndex == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 2, bottom: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Atom is thinking…',
                              style: GoogleFonts.urbanist(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: secondaryText,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return _quickRepliesCard(
                      provider,
                      surface: surface,
                      border: border,
                      primaryText: primaryText,
                      secondaryText: secondaryText,
                      onSend: (prompt) => _sendMessage(provider, prompt),
                    );
                  },
                ),
              ),
              _buildComposer(
                provider,
                bg: bg,
                surface: surface,
                primaryText: primaryText,
                secondaryText: secondaryText,
                border: border,
                accent: accent,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _assistantBackdrop({
    required Color bg,
    required Color accent,
    required bool isDark,
  }) {
    final topGlow = accent.withValues(alpha: isDark ? 0.28 : 0.14);
    final sideGlow = accent.withValues(alpha: isDark ? 0.10 : 0.07);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [topGlow, bg],
          stops: const [0.0, 0.72],
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.92, 0.82),
            radius: 1.15,
            colors: [sideGlow, Colors.transparent],
            stops: const [0.0, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildComposer(
    HabitProvider provider, {
    required Color bg,
    required Color surface,
    required Color primaryText,
    required Color secondaryText,
    required Color border,
    required Color accent,
  }) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                style: GoogleFonts.urbanist(
                  color: primaryText,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  hintText: 'Type a message…',
                  hintStyle: GoogleFonts.urbanist(
                    color: secondaryText,
                    fontWeight: FontWeight.w700,
                  ),
                  filled: true,
                  fillColor: surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide(color: border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide(color: border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide(color: accent, width: 1.6),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  suffixIcon: IconButton(
                    onPressed: _isLoading
                        ? null
                        : () async => _setVoiceMode(true, provider),
                    icon: Icon(
                      Icons.graphic_eq_rounded,
                      color: secondaryText,
                    ),
                  ),
                ),
                onSubmitted: (value) async => _sendMessage(provider, value),
              ),
            ),
            const SizedBox(width: 10),
            InkWell(
              onTap: _isLoading
                  ? null
                  : () async => _sendMessage(provider, _controller.text),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isLoading ? accent.withValues(alpha: 0.6) : accent,
                ),
                child: const Icon(
                  Icons.arrow_upward_rounded,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roundIconButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color surface,
    required Color border,
    required Color iconColor,
    double size = 42,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: surface,
            border: Border.all(color: border),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
      ),
    );
  }

  Widget _assistantAvatar({
    required Color accent,
    required Color surface,
    required Color border,
  }) {
    final top = Color.lerp(accent, Colors.white, 0.42) ?? accent;
    final bottom = Color.lerp(accent, surface, 0.55) ?? accent;

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [top, bottom],
        ),
        border: Border.all(color: border),
      ),
    );
  }

  Widget _quickChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color surface,
    required Color border,
    required Color textColor,
    required Color iconColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: iconColor.withValues(alpha: 0.9)),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.urbanist(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topicCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color surface,
    required Color border,
    required Color primaryText,
    required Color secondaryText,
    required Color accent,
    required List<BoxShadow> cardShadow,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
          boxShadow: cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accent, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.urbanist(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.urbanist(
                fontSize: 11,
                height: 1.25,
                fontWeight: FontWeight.w700,
                color: secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickRepliesCard(
    HabitProvider provider, {
    required Color surface,
    required Color border,
    required Color primaryText,
    required Color secondaryText,
    required ValueChanged<String> onSend,
  }) {
    final items = <({IconData icon, String label, String prompt})>[
      (
        icon: Icons.lightbulb_outline_rounded,
        label: 'Habit ideas',
        prompt: 'Give me 3 small habit ideas for today.',
      ),
      (
        icon: Icons.edit_note_rounded,
        label: 'Journal prompt',
        prompt:
            'Give me one journal prompt for today and a 2-minute plan to answer it.',
      ),
      (
        icon: Icons.air_rounded,
        label: 'Breathing reset',
        prompt: 'Guide me through a 60-second breathing reset right now.',
      ),
    ];

    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() => _quickRepliesExpanded = !_quickRepliesExpanded);
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 18,
                    color: secondaryText,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Quick reply suggestions',
                      style: GoogleFonts.urbanist(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                        color: primaryText,
                      ),
                    ),
                  ),
                  Icon(
                    _quickRepliesExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: secondaryText,
                  ),
                ],
              ),
            ),
          ),
          if (_quickRepliesExpanded)
            ...items.map(
              (i) => InkWell(
                onTap: () => onSend(i.prompt),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  child: Row(
                    children: [
                      Icon(i.icon, size: 16, color: secondaryText),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          i.label,
                          style: GoogleFonts.urbanist(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: primaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _VoiceWavePainter extends CustomPainter {
  final Color accent;
  final Color surface;
  final double t;
  final bool isDark;

  const _VoiceWavePainter({
    required this.accent,
    required this.surface,
    required this.t,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final phase = t * 2 * math.pi;

    Path wave({
      required double amplitude,
      required double frequency,
      required double phaseShift,
      required double y,
    }) {
      final path = Path();
      final steps = math.max(20, (w / 14).floor());

      for (var i = 0; i <= steps; i++) {
        final x = (w / steps) * i;
        final s =
            math.sin((x / w) * 2 * math.pi * frequency + phase + phaseShift);
        final yy = y + s * amplitude;
        if (i == 0) {
          path.moveTo(x, yy);
        } else {
          path.lineTo(x, yy);
        }
      }
      return path;
    }

    final waveColor =
        isDark ? accent : (Color.lerp(accent, Colors.white, 0.38) ?? accent);

    final glowShader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        Colors.transparent,
        waveColor.withValues(alpha: isDark ? 0.55 : 0.72),
        Colors.transparent,
      ],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, w, h));

    Paint p(
        {required double width, required double alpha, required bool blur}) {
      return Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = width
        ..shader = glowShader
        ..color = waveColor.withValues(alpha: alpha)
        ..maskFilter =
            blur ? const MaskFilter.blur(BlurStyle.normal, 10) : null;
    }

    final baseY = h * 0.52;
    final waveA = wave(
      amplitude: h * 0.16,
      frequency: 1.0,
      phaseShift: 0.0,
      y: baseY,
    );
    final waveB = wave(
      amplitude: h * 0.12,
      frequency: 1.35,
      phaseShift: 1.2,
      y: baseY + h * 0.03,
    );
    final waveC = wave(
      amplitude: h * 0.10,
      frequency: 1.7,
      phaseShift: 2.4,
      y: baseY - h * 0.02,
    );

    canvas.drawPath(
      waveC,
      p(width: 3.4, alpha: isDark ? 0.20 : 0.18, blur: true),
    );
    canvas.drawPath(
      waveA,
      p(width: 2.2, alpha: isDark ? 0.64 : 0.78, blur: false),
    );
    canvas.drawPath(
      waveB,
      p(width: 1.8, alpha: isDark ? 0.44 : 0.58, blur: false),
    );

    // Subtle horizon glow.
    final haze = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, 0.0),
        radius: 1.2,
        colors: [
          waveColor.withValues(alpha: isDark ? 0.10 : 0.14),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), haze);
  }

  @override
  bool shouldRepaint(covariant _VoiceWavePainter oldDelegate) {
    return oldDelegate.accent != accent ||
        oldDelegate.surface != surface ||
        oldDelegate.t != t ||
        oldDelegate.isDark != isDark;
  }
}

enum _Role { user, bot }

class _ChatMessage {
  final _Role role;
  final String text;

  const _ChatMessage({required this.role, required this.text});
}

class _ParsedCoachResponse {
  final String visibleText;
  final List<Map<String, dynamic>> actions;

  const _ParsedCoachResponse({
    required this.visibleText,
    required this.actions,
  });
}

class _AppliedActions {
  final String? summary;
  final String? followup;

  const _AppliedActions({this.summary, this.followup});
}

class _PendingDeleteRequest {
  final String habitId;
  final String habitTitle;

  const _PendingDeleteRequest({
    required this.habitId,
    required this.habitTitle,
  });
}

class _OfflineAssistantResult {
  final String replyText;
  final String? actionSummary;

  const _OfflineAssistantResult({
    required this.replyText,
    this.actionSummary,
  });
}

class _InlineIconInsert {
  final int index;
  final IconData icon;
  final bool leadingSpace;
  final bool trailingSpace;

  const _InlineIconInsert({
    required this.index,
    required this.icon,
    required this.leadingSpace,
    required this.trailingSpace,
  });

  int get plainLength => (leadingSpace ? 1 : 0) + 1 + (trailingSpace ? 1 : 0);
}
