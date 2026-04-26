import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../data/providers/habit_provider.dart';

class MeditationScreen extends StatelessWidget {
  const MeditationScreen({super.key});

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

    const topics = MeditationLibrary.topics;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          'Meditation',
          style: GoogleFonts.urbanist(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
            color: primaryText,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryBlue.withValues(alpha: 0.18),
                  surface,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: primaryBlue.withValues(alpha: 0.14)),
              boxShadow: cardShadow,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: primaryBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.spa, color: primaryBlue, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Voice-guided sessions',
                        style: GoogleFonts.urbanist(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                          color: primaryText,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Pick a topic and press play. Your phone will guide you using on-device voice.',
                        style: GoogleFonts.urbanist(
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                          color: secondaryText,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${topics.length} topics',
                        style: GoogleFonts.urbanist(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                          color: primaryBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const SizedBox(height: 4),
          Text(
            'Library',
            style: GoogleFonts.urbanist(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
              color: primaryText,
            ),
          ),
          const SizedBox(height: 10),
          ...topics.map(
            (topic) => _TopicTile(
              topic: topic,
              surface: surface,
              border: border,
              primaryText: primaryText,
              secondaryText: secondaryText,
              accent: primaryBlue,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MeditationPlayerScreen(topic: topic),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class MeditationTopic {
  final String id;
  final String title;
  final int minutes;
  final String description;
  final IconData icon;
  final List<String> cues;

  const MeditationTopic({
    required this.id,
    required this.title,
    required this.minutes,
    required this.description,
    required this.icon,
    required this.cues,
  });

  String get durationLabel => '$minutes min';
}

class MeditationLibrary {
  static const topics = <MeditationTopic>[
    MeditationTopic(
      id: 'breath-reset-3',
      title: '3-Minute Breath Reset',
      minutes: 3,
      description: 'A quick reset for stress, tension, or overwhelm.',
      icon: Icons.air,
      cues: ['slow breathing', 'soft shoulders', 'steady exhale'],
    ),
    MeditationTopic(
      id: 'grounding-5-4-3-2-1',
      title: 'Grounding 5-4-3-2-1',
      minutes: 5,
      description: 'Come back to the present using your senses.',
      icon: Icons.landscape_outlined,
      cues: ['notice 5 things you see', 'feel 4 sensations', 'hear 3 sounds'],
    ),
    MeditationTopic(
      id: 'anxiety-ease-10',
      title: 'Ease Anxiety Gently',
      minutes: 10,
      description: 'A calm, supportive session for anxious thoughts.',
      icon: Icons.psychology,
      cues: ['name the feeling', 'breathe into the belly', 'return to now'],
    ),
    MeditationTopic(
      id: 'panic-reset-7',
      title: 'Panic Reset',
      minutes: 7,
      description: 'Ground, breathe, and soften panic sensations.',
      icon: Icons.favorite_border,
      cues: ['slow down the exhale', 'feel your feet', 'let the wave pass'],
    ),
    MeditationTopic(
      id: 'overthinking-break-8',
      title: 'Overthinking Break',
      minutes: 8,
      description: 'Create space from looping thoughts and rumination.',
      icon: Icons.psychology_alt_outlined,
      cues: ['label thoughts', 'let them drift by', 'choose one helpful focus'],
    ),
    MeditationTopic(
      id: 'workday-reset-6',
      title: 'Workday Reset',
      minutes: 6,
      description: 'Release pressure and return to clarity.',
      icon: Icons.work_outline,
      cues: ['drop jaw and shoulders', 'one slow breath', 'single next step'],
    ),
    MeditationTopic(
      id: 'focus-deep-12',
      title: 'Deep Focus',
      minutes: 12,
      description: 'Settle attention and re-enter a focused state.',
      icon: Icons.center_focus_strong,
      cues: [
        'anchor to breath',
        'soften distractions',
        'return again and again'
      ],
    ),
    MeditationTopic(
      id: 'study-flow-10',
      title: 'Study Flow',
      minutes: 10,
      description: 'A calm start for study, reading, or learning.',
      icon: Icons.menu_book_outlined,
      cues: ['steady posture', 'gentle focus', 'small consistent effort'],
    ),
    MeditationTopic(
      id: 'confidence-boost-9',
      title: 'Confidence Boost',
      minutes: 9,
      description: 'Ground into self-belief without pressure.',
      icon: Icons.star_outline,
      cues: ['remember a past win', 'stand tall', 'speak kindly to yourself'],
    ),
    MeditationTopic(
      id: 'self-compassion-12',
      title: 'Self-Compassion',
      minutes: 12,
      description: 'Meet yourself with warmth and understanding.',
      icon: Icons.volunteer_activism_outlined,
      cues: ['hand on heart', 'soft words', 'release harsh self-talk'],
    ),
    MeditationTopic(
      id: 'gratitude-6',
      title: 'Gratitude',
      minutes: 6,
      description: 'Shift your attention toward what supports you.',
      icon: Icons.emoji_emotions_outlined,
      cues: ['one small good thing', 'feel appreciation', 'gentle smile'],
    ),
    MeditationTopic(
      id: 'body-scan-15',
      title: 'Body Scan (Deep Relax)',
      minutes: 15,
      description: 'A slow scan to unwind tension head to toe.',
      icon: Icons.self_improvement,
      cues: ['relax forehead', 'release shoulders', 'soft belly and hips'],
    ),
    MeditationTopic(
      id: 'jaw-shoulders-release-5',
      title: 'Jaw & Shoulders Release',
      minutes: 5,
      description: 'Let go of the tension you hold most.',
      icon: Icons.accessibility_new,
      cues: ['unclench jaw', 'drop shoulders', 'slow exhale'],
    ),
    MeditationTopic(
      id: 'sleep-wind-down-12',
      title: 'Wind Down for Sleep',
      minutes: 12,
      description: 'A calming transition into rest.',
      icon: Icons.nights_stay,
      cues: ['dim the mind', 'slow breathing', 'release the day'],
    ),
    MeditationTopic(
      id: 'sleep-release-day-8',
      title: 'Release the Day',
      minutes: 8,
      description: 'Let the day settle. Tomorrow can wait.',
      icon: Icons.bedtime_outlined,
      cues: ['soften face', 'thank yourself', 'let thoughts quiet down'],
    ),
    MeditationTopic(
      id: 'morning-intention-7',
      title: 'Morning Intention',
      minutes: 7,
      description: 'Start with a steady mind and simple intention.',
      icon: Icons.light_mode,
      cues: ['choose one word', 'breathe into the day', 'gentle confidence'],
    ),
    MeditationTopic(
      id: 'evening-reflection-7',
      title: 'Evening Reflection',
      minutes: 7,
      description: 'A quiet check-in to close your day.',
      icon: Icons.wb_twilight,
      cues: ['notice what you did', 'forgive what you didn\'t', 'soft landing'],
    ),
    MeditationTopic(
      id: 'mindfulness-basics-10',
      title: 'Mindfulness Basics',
      minutes: 10,
      description: 'Practice being present without judgment.',
      icon: Icons.visibility,
      cues: ['feel breath', 'notice thoughts', 'return to sensation'],
    ),
    MeditationTopic(
      id: 'emotional-balance-12',
      title: 'Emotional Balance',
      minutes: 12,
      description:
          'Make space for emotions without being pulled around by them.',
      icon: Icons.favorite,
      cues: ['name the emotion', 'allow it to be here', 'breathe and soften'],
    ),
    MeditationTopic(
      id: 'anger-cool-down-9',
      title: 'Cool Down Anger',
      minutes: 9,
      description: 'Lower intensity and return to choice.',
      icon: Icons.local_fire_department_outlined,
      cues: ['slow exhale', 'relax hands', 'choose your next response'],
    ),
    MeditationTopic(
      id: 'loneliness-soften-10',
      title: 'Soften Loneliness',
      minutes: 10,
      description: 'A gentle session for feeling alone or disconnected.',
      icon: Icons.people_outline,
      cues: ['hand on heart', 'kind inner voice', 'remember support'],
    ),
    MeditationTopic(
      id: 'self-esteem-11',
      title: 'Build Self-Esteem',
      minutes: 11,
      description: 'Practice respectful self-talk and steady confidence.',
      icon: Icons.thumb_up_alt_outlined,
      cues: ['speak kindly', 'stand in your values', 'notice what\'s true'],
    ),
    MeditationTopic(
      id: 'social-anxiety-9',
      title: 'Social Anxiety Ease',
      minutes: 9,
      description: 'Ground yourself before a conversation or event.',
      icon: Icons.forum_outlined,
      cues: ['feel feet', 'slow breath', 'focus on listening'],
    ),
    MeditationTopic(
      id: 'clarity-decision-8',
      title: 'Decision Clarity',
      minutes: 8,
      description: 'A calm way to approach decisions without spiraling.',
      icon: Icons.tune,
      cues: ['notice options', 'feel what matters', 'pick the next step'],
    ),
    MeditationTopic(
      id: 'boundaries-10',
      title: 'Healthy Boundaries',
      minutes: 10,
      description: 'Feel your “yes” and “no” more clearly.',
      icon: Icons.shield_outlined,
      cues: ['notice pressure', 'choose respect', 'protect your energy'],
    ),
    MeditationTopic(
      id: 'forgiveness-12',
      title: 'Forgiveness (For You)',
      minutes: 12,
      description: 'Release what you can, for your own peace.',
      icon: Icons.spa_outlined,
      cues: ['soften grip', 'breathe out resentment', 'choose peace'],
    ),
    MeditationTopic(
      id: 'calm-before-exam-6',
      title: 'Calm Before an Exam',
      minutes: 6,
      description: 'Settle nerves and focus your mind.',
      icon: Icons.school_outlined,
      cues: ['steady inhale', 'long exhale', 'trust preparation'],
    ),
    MeditationTopic(
      id: 'mindful-walking-10',
      title: 'Mindful Walking',
      minutes: 10,
      description: 'Turn a short walk into a grounding practice.',
      icon: Icons.directions_walk,
      cues: ['feel steps', 'notice air', 'soft eyes'],
    ),
    MeditationTopic(
      id: 'mindful-eating-7',
      title: 'Mindful Eating',
      minutes: 7,
      description: 'Slow down and reconnect with your body.',
      icon: Icons.restaurant_outlined,
      cues: ['notice taste', 'chew slowly', 'pause between bites'],
    ),
    MeditationTopic(
      id: 'healing-heartbreak-12',
      title: 'Healing Heartbreak',
      minutes: 12,
      description: 'A gentle space for grief, loss, or sadness.',
      icon: Icons.heart_broken_outlined,
      cues: ['allow feelings', 'breathe softly', 'offer yourself kindness'],
    ),
    MeditationTopic(
      id: 'resilience-10',
      title: 'Resilience',
      minutes: 10,
      description: 'Reconnect to inner strength and steady hope.',
      icon: Icons.fitness_center,
      cues: ['remember strength', 'one breath at a time', 'keep going gently'],
    ),
    MeditationTopic(
      id: 'mood-lift-8',
      title: 'Lift Low Mood',
      minutes: 8,
      description: 'A light session for heavy or low days.',
      icon: Icons.wb_sunny_outlined,
      cues: ['small kindness', 'gentle breath', 'one hopeful thought'],
    ),
    MeditationTopic(
      id: 'breathing-box-6',
      title: 'Box Breathing',
      minutes: 6,
      description: 'A structured breath to steady your nervous system.',
      icon: Icons.crop_square,
      cues: ['inhale 4', 'hold 4', 'exhale 4'],
    ),
    MeditationTopic(
      id: 'progressive-relax-14',
      title: 'Progressive Relaxation',
      minutes: 14,
      description: 'Tense and release to unwind deeply.',
      icon: Icons.airline_seat_recline_normal,
      cues: ['tighten then release', 'scan body', 'heavy and relaxed'],
    ),
    MeditationTopic(
      id: 'acceptance-10',
      title: 'Acceptance',
      minutes: 10,
      description: 'Let reality be as it is, so you can move forward.',
      icon: Icons.check_circle_outline,
      cues: ['notice resistance', 'soften around it', 'choose your next step'],
    ),
    MeditationTopic(
      id: 'self-love-12',
      title: 'Self-Love',
      minutes: 12,
      description: 'Practice warmth toward yourself, exactly as you are.',
      icon: Icons.favorite_outline,
      cues: ['kind phrases', 'hand on heart', 'gentle acceptance'],
    ),
    MeditationTopic(
      id: 'hope-7',
      title: 'Hope',
      minutes: 7,
      description: 'A short session to reconnect with possibility.',
      icon: Icons.auto_awesome_outlined,
      cues: ['small light', 'steady breath', 'one step forward'],
    ),
    MeditationTopic(
      id: 'calm-commute-5',
      title: 'Calm Commute',
      minutes: 5,
      description: 'Arrive calmer, whether walking, riding, or waiting.',
      icon: Icons.directions_transit,
      cues: ['soft jaw', 'slow breath', 'notice surroundings'],
    ),
    MeditationTopic(
      id: 'reset-after-argument-8',
      title: 'Reset After an Argument',
      minutes: 8,
      description: 'Settle your body and return to choice.',
      icon: Icons.chat_bubble_outline,
      cues: ['slow breathing', 'release tension', 'choose your values'],
    ),
    MeditationTopic(
      id: 'calm-relationships-9',
      title: 'Calm Communication',
      minutes: 9,
      description: 'Ground before you speak. Listen with steadiness.',
      icon: Icons.record_voice_over_outlined,
      cues: ['slow exhale', 'listen first', 'speak one clear sentence'],
    ),
    MeditationTopic(
      id: 'mindful-break-4',
      title: 'Mindful Break',
      minutes: 4,
      description: 'A tiny pause to reset your mind.',
      icon: Icons.pause_circle_outline,
      cues: ['look around', 'breathe', 'relax shoulders'],
    ),
    MeditationTopic(
      id: 'calm-morning-10',
      title: 'Calm Morning',
      minutes: 10,
      description: 'A steady start when the day feels busy.',
      icon: Icons.wb_sunny,
      cues: ['slow breath', 'choose intention', 'move gently'],
    ),
    MeditationTopic(
      id: 'sleep-body-scan-20',
      title: 'Sleep Body Scan (20)',
      minutes: 20,
      description: 'A long, soothing scan for deeper rest.',
      icon: Icons.hotel_outlined,
      cues: ['soft jaw', 'heavy limbs', 'slow down thoughts'],
    ),
  ];
}

class _TopicTile extends StatelessWidget {
  final MeditationTopic topic;
  final Color surface;
  final Color border;
  final Color primaryText;
  final Color secondaryText;
  final Color accent;
  final VoidCallback onTap;

  const _TopicTile({
    required this.topic,
    required this.surface,
    required this.border,
    required this.primaryText,
    required this.secondaryText,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border.withValues(alpha: 0.9)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(topic.icon, color: accent, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    topic.title,
                    style: GoogleFonts.urbanist(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                      color: primaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${topic.durationLabel} • ${topic.description}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.urbanist(
                      fontSize: 12,
                      height: 1.3,
                      color: secondaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.play_circle_fill, color: accent, size: 30),
          ],
        ),
      ),
    );
  }
}

/*
Garden feature removed (UI + progression) at user request.

Keeping the old implementation commented out for now to avoid any accidental
reintroduction while we redesign the experience.
*/

/*
enum _GardenWeather {
  clear,
  cloudy,
  rain,
  snow,
}

enum _GardenTreeKind {
  redCanopy,
  roundGreen,
  pine,
  palm,
  blossom,
}

double _gardenLerp(double a, double b, double t) => a + (b - a) * t;

Color _gardenTone(
  Color base, {
  double? hue,
  double? saturation,
  double? lightness,
}) {
  final hsl = HSLColor.fromColor(base);
  return hsl
      .withHue(hue ?? hsl.hue)
      .withSaturation(saturation ?? hsl.saturation)
      .withLightness(lightness ?? hsl.lightness)
      .toColor();
}

Color _gardenAdjustLightness(Color base, double delta) {
  final hsl = HSLColor.fromColor(base);
  return hsl.withLightness((hsl.lightness + delta).clamp(0.0, 1.0)).toColor();
}

class _GardenClimate {
  final DateTime now;
  final bool isNight;
  final _GardenWeather weather;

  const _GardenClimate({
    required this.now,
    required this.isNight,
    required this.weather,
  });

  factory _GardenClimate.from(DateTime now) {
    final isNight = now.hour < 6 || now.hour >= 18;

    final m = now.month;
    final isWinter = m == 12 || m == 1 || m == 2;
    final isSummer = m >= 6 && m <= 8;

    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays + 1;
    final weather = () {
      if (isWinter) return _GardenWeather.snow;

      // Deterministic “weather” without external APIs. Changes with calendar time.
      final rainMod = isSummer ? 4 : 7;
      if (dayOfYear % rainMod == 0) return _GardenWeather.rain;
      if (dayOfYear % 5 == 0) return _GardenWeather.cloudy;
      return _GardenWeather.clear;
    }();

    return _GardenClimate(now: now, isNight: isNight, weather: weather);
  }

  String get timeLabel => isNight ? 'Night' : 'Day';

  String get weatherLabel {
    switch (weather) {
      case _GardenWeather.clear:
        return 'Clear';
      case _GardenWeather.cloudy:
        return 'Cloudy';
      case _GardenWeather.rain:
        return 'Rain';
      case _GardenWeather.snow:
        return 'Snow';
    }
  }

  IconData get timeIcon =>
      isNight ? Icons.nights_stay_outlined : Icons.wb_sunny;

  IconData get weatherIcon {
    switch (weather) {
      case _GardenWeather.clear:
        return Icons.wb_sunny_outlined;
      case _GardenWeather.cloudy:
        return Icons.cloud_outlined;
      case _GardenWeather.rain:
        return Icons.grain;
      case _GardenWeather.snow:
        return Icons.ac_unit;
    }
  }

  Color tint({required Color primaryBlue, required bool isDark}) {
    switch (weather) {
      case _GardenWeather.clear:
        return Colors.transparent;
      case _GardenWeather.cloudy:
        return (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06);
      case _GardenWeather.rain:
        return primaryBlue.withValues(alpha: 0.10);
      case _GardenWeather.snow:
        return Colors.white.withValues(alpha: 0.12);
    }
  }

  int seed() {
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays + 1;
    return now.year * 100000 + dayOfYear * 100 + now.hour;
  }
}

class _GardenIslandLayout {
  static const List<Offset> treeSpots = [
    Offset(-0.55, 0.10),
    Offset(-0.48, 0.22),
    Offset(-0.42, 0.34),
    Offset(-0.35, 0.46),
    Offset(-0.25, 0.56),
    Offset(-0.22, 0.32),
    Offset(-0.30, 0.18),
    Offset(-0.40, 0.14),
    Offset(-0.50, -0.02),
    Offset(-0.38, -0.10),
    Offset(-0.26, -0.16),
    Offset(-0.12, -0.18),
    Offset(-0.05, 0.12),
    Offset(-0.12, 0.26),
    Offset(-0.18, 0.44),
    Offset(0.00, -0.08),
    Offset(0.18, -0.06),
    Offset(0.34, -0.02),
    Offset(0.48, 0.06),
    Offset(0.30, 0.18),
    Offset(0.14, 0.30),
    Offset(0.02, 0.44),
    Offset(0.22, 0.36),
    Offset(0.38, 0.30),
    Offset(0.56, 0.18),
    Offset(0.50, 0.40),
    Offset(0.20, 0.56),
    Offset(-0.02, 0.60),
  ];

  static int get capacity => treeSpots.length;
}

class _GardenIslandCard extends StatelessWidget {
  final int treesPlanted;
  final DateTime now;
  final bool isDark;
  final Color surface;
  final Color primaryText;
  final Color secondaryText;
  final Color primaryBlue;
  final Color border;
  final List<BoxShadow> cardShadow;

  const _GardenIslandCard({
    required this.treesPlanted,
    required this.now,
    required this.isDark,
    required this.surface,
    required this.primaryText,
    required this.secondaryText,
    required this.primaryBlue,
    required this.border,
    required this.cardShadow,
  });

  @override
  Widget build(BuildContext context) {
    final climate = _GardenClimate.from(now);
    final capacity = _GardenIslandLayout.capacity;
    final shownTrees = treesPlanted.clamp(0, capacity);
    final extra = treesPlanted - capacity;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _GardenIslandScreen(treesPlanted: treesPlanted),
            ),
          );
        },
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: border),
            boxShadow: cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: primaryBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.park_rounded,
                      color: primaryBlue,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Garden',
                          style: GoogleFonts.urbanist(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                            color: primaryText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Finish a session to plant a tree.',
                          style: GoogleFonts.urbanist(
                            fontSize: 12,
                            height: 1.25,
                            fontWeight: FontWeight.w600,
                            color: secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$treesPlanted',
                        style: GoogleFonts.urbanist(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                          color: primaryBlue,
                        ),
                      ),
                      Text(
                        'trees',
                        style: GoogleFonts.urbanist(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: secondaryText,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _GardenChip(
                    icon: climate.timeIcon,
                    label: climate.timeLabel,
                    primaryBlue: primaryBlue,
                    border: border,
                  ),
                  _GardenChip(
                    icon: climate.weatherIcon,
                    label: climate.weatherLabel,
                    primaryBlue: primaryBlue,
                    border: border,
                  ),
                  if (extra > 0)
                    _GardenChip(
                      icon: Icons.add,
                      label: '+$extra more',
                      primaryBlue: primaryBlue,
                      border: border,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _GardenIslandScene(
                treesPlanted: shownTrees,
                climate: climate,
                primaryBlue: primaryBlue,
                surface: surface,
                isDark: isDark,
              ),
              if (treesPlanted <= 0) ...[
                const SizedBox(height: 10),
                Text(
                  'No trees yet — complete your first session.',
                  style: GoogleFonts.urbanist(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: secondaryText,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GardenChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color primaryBlue;
  final Color border;

  const _GardenChip({
    required this.icon,
    required this.label,
    required this.primaryBlue,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: primaryBlue.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: primaryBlue),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.urbanist(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
              color: primaryBlue,
            ),
          ),
        ],
      ),
    );
  }
}

class _GardenIslandScreen extends StatefulWidget {
  final int treesPlanted;

  const _GardenIslandScreen({required this.treesPlanted});

  @override
  State<_GardenIslandScreen> createState() => _GardenIslandScreenState();
}

class _GardenIslandScreenState extends State<_GardenIslandScreen> {
  DateTime _now = DateTime.now();
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    final bg = isDark ? AppThemeDark.background : AppTheme.background;
    final surface = isDark ? AppThemeDark.surface : AppTheme.surface;
    final primaryBlue =
        isDark ? AppThemeDark.primaryBlue : AppTheme.primaryBlue;

    final climate = _GardenClimate.from(_now);
    final capacity = _GardenIslandLayout.capacity;
    final shownTrees = widget.treesPlanted.clamp(0, capacity);

    final overlayBg = Colors.black.withValues(alpha: isDark ? 0.55 : 0.45);
    final overlayFg = Colors.white.withValues(alpha: 0.92);

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: _GardenIslandFullScene(
              treesPlanted: shownTrees,
              climate: climate,
              primaryBlue: primaryBlue,
              surface: surface,
              isDark: isDark,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              child: Column(
                children: [
                  Row(
                    children: [
                      _OverlayCircleIcon(
                        icon: Icons.card_giftcard,
                        background: overlayBg,
                        foreground: overlayFg,
                      ),
                      const SizedBox(width: 12),
                      _OverlayCircleIcon(
                        icon: climate.timeIcon,
                        background: overlayBg,
                        foreground: overlayFg,
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _OverlayPill(
                            icon: Icons.monetization_on,
                            label: '${widget.treesPlanted}',
                            background: overlayBg,
                            foreground: overlayFg,
                          ),
                          const SizedBox(height: 12),
                          _OverlayCircleIcon(
                            icon: Icons.share,
                            background: overlayBg,
                            foreground: overlayFg,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      _OverlayWidePill(
                        icon: Icons.local_florist,
                        label: 'Nursery',
                        background: overlayBg,
                        foreground: overlayFg,
                      ),
                      const Spacer(),
                      _OverlayCircleIcon(
                        icon: Icons.handyman,
                        background: overlayBg,
                        foreground: overlayFg,
                        size: 54,
                        iconSize: 22,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverlayCircleIcon extends StatelessWidget {
  final IconData icon;
  final Color background;
  final Color foreground;
  final double size;
  final double iconSize;

  const _OverlayCircleIcon({
    required this.icon,
    required this.background,
    required this.foreground,
    this.size = 44,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: foreground, size: iconSize),
    );
  }
}

class _OverlayPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  const _OverlayPill({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.urbanist(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
              color: foreground,
            ),
          ),
          const SizedBox(width: 8),
          Icon(icon, color: foreground, size: 22),
        ],
      ),
    );
  }
}

class _OverlayWidePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  const _OverlayWidePill({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: foreground, size: 22),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.urbanist(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _GardenIslandFullScene extends StatelessWidget {
  final int treesPlanted;
  final _GardenClimate climate;
  final Color primaryBlue;
  final Color surface;
  final bool isDark;

  const _GardenIslandFullScene({
    required this.treesPlanted,
    required this.climate,
    required this.primaryBlue,
    required this.surface,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final tint = climate.tint(primaryBlue: primaryBlue, isDark: isDark);

    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _GardenIslandPainter(
              treesPlanted: treesPlanted,
              climate: climate,
              primaryBlue: primaryBlue,
              surface: surface,
              isDark: isDark,
              cinematic: true,
            ),
          ),
        ),
        if (climate.isNight)
          Positioned.fill(
            child: CustomPaint(
              painter: _StarsOverlayPainter(
                seed: climate.seed(),
                color: Colors.white.withValues(alpha: 0.22),
              ),
            ),
          ),
        if (tint != Colors.transparent)
          Positioned.fill(child: Container(color: tint)),
        if (climate.weather == _GardenWeather.rain)
          Positioned.fill(
            child: CustomPaint(
              painter: _RainOverlayPainter(
                color: Colors.white.withValues(alpha: 0.18),
              ),
            ),
          ),
        if (climate.weather == _GardenWeather.snow)
          Positioned.fill(
            child: CustomPaint(
              painter: _SnowOverlayPainter(
                seed: climate.seed(),
                color: Colors.white.withValues(alpha: 0.30),
              ),
            ),
          ),
      ],
    );
  }
}

class _GardenIslandScene extends StatelessWidget {
  final int treesPlanted;
  final _GardenClimate climate;
  final Color primaryBlue;
  final Color surface;
  final bool isDark;

  const _GardenIslandScene({
    required this.treesPlanted,
    required this.climate,
    required this.primaryBlue,
    required this.surface,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final tint = climate.tint(primaryBlue: primaryBlue, isDark: isDark);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 1.35,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _GardenIslandPainter(
                  treesPlanted: treesPlanted,
                  climate: climate,
                  primaryBlue: primaryBlue,
                  surface: surface,
                  isDark: isDark,
                  cinematic: false,
                ),
              ),
            ),
            if (climate.isNight)
              Positioned.fill(
                child: CustomPaint(
                  painter: _StarsOverlayPainter(
                    seed: climate.seed(),
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
              ),
            if (tint != Colors.transparent)
              Positioned.fill(child: Container(color: tint)),
            if (climate.weather == _GardenWeather.rain)
              Positioned.fill(
                child: CustomPaint(
                  painter: _RainOverlayPainter(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
              ),
            if (climate.weather == _GardenWeather.snow)
              Positioned.fill(
                child: CustomPaint(
                  painter: _SnowOverlayPainter(
                    seed: climate.seed(),
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GardenIslandPainter extends CustomPainter {
  final int treesPlanted;
  final _GardenClimate climate;
  final Color primaryBlue;
  final Color surface;
  final bool isDark;
  final bool cinematic;

  const _GardenIslandPainter({
    required this.treesPlanted,
    required this.climate,
    required this.primaryBlue,
    required this.surface,
    required this.isDark,
    required this.cinematic,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    _paintSky(canvas, rect);
    _paintSunMoon(canvas, rect);
    _paintClouds(canvas, rect);
    _paintIsland(canvas, rect);
  }

  void _paintSky(Canvas canvas, Rect rect) {
    final nightBase = _gardenTone(
      primaryBlue,
      hue: 262,
      saturation: isDark ? 0.56 : 0.60,
      lightness: isDark ? 0.20 : 0.26,
    );

    final nightTop = _gardenAdjustLightness(nightBase, -0.08);
    final nightBottom = _gardenAdjustLightness(nightBase, 0.10);

    final dayTop =
        Color.lerp(primaryBlue, Colors.white, isDark ? 0.22 : 0.80) ??
            primaryBlue;
    final dayBottom =
        Color.lerp(primaryBlue, surface, isDark ? 0.65 : 0.92) ?? surface;

    final colors = climate.isNight
        ? <Color>[nightTop, nightBottom]
        : <Color>[dayTop, dayBottom];

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
      ).createShader(rect);
    canvas.drawRect(rect, paint);

    // Horizon glow (matches the reference's soft purple bloom).
    final glowColor = _gardenTone(
      primaryBlue,
      hue: 312,
      saturation: isDark ? 0.58 : 0.62,
      lightness: isDark ? 0.36 : 0.62,
    );
    final glow = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.02, 0.10),
        radius: 0.95,
        colors: [
          glowColor.withValues(alpha: climate.isNight ? 0.20 : 0.26),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, glow);

    final bottomFog = Paint()
      ..shader = LinearGradient(
        begin: const Alignment(0, 0.35),
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Colors.black.withValues(alpha: climate.isNight ? 0.10 : 0.06),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, bottomFog);

    final vignette = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, -0.3),
        radius: 1.1,
        colors: [
          Colors.transparent,
          Colors.black.withValues(alpha: isDark ? 0.36 : 0.18),
        ],
        stops: const [0.65, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, vignette);
  }

  void _paintSunMoon(Canvas canvas, Rect rect) {
    final center = Offset(rect.right * 0.78, rect.top + rect.height * 0.22);
    final r = rect.shortestSide * 0.085;

    if (climate.isNight) {
      final moonPaint = Paint()
        ..color = Color.lerp(Colors.white, primaryBlue, 0.06)!
            .withValues(alpha: 0.90);
      final glow = Paint()
        ..color = Colors.white.withValues(alpha: 0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);

      canvas.drawCircle(center, r * 1.25, glow);
      canvas.drawCircle(center, r, moonPaint);
      canvas.drawCircle(
        center.translate(-r * 0.22, -r * 0.18),
        r * 0.18,
        Paint()..color = Colors.black.withValues(alpha: 0.06),
      );
    } else {
      final sun = _gardenTone(
        primaryBlue,
        hue: 48,
        saturation: 0.82,
        lightness: isDark ? 0.60 : 0.70,
      );
      final sunPaint = Paint()..color = sun.withValues(alpha: 0.92);
      final glow = Paint()
        ..color = sun.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22);

      canvas.drawCircle(center, r * 1.35, glow);
      canvas.drawCircle(center, r, sunPaint);
    }
  }

  void _paintClouds(Canvas canvas, Rect rect) {
    final isCloudy = climate.weather == _GardenWeather.cloudy ||
        climate.weather == _GardenWeather.rain;
    if (!isCloudy) return;

    final cloudColor = (climate.isNight ? Colors.white : Colors.white)
        .withValues(alpha: climate.isNight ? 0.07 : 0.18);
    final paint = Paint()..color = cloudColor;

    void blob(Offset c, double s) {
      canvas.drawCircle(c.translate(-s * 0.28, 0), s * 0.52, paint);
      canvas.drawCircle(c.translate(s * 0.05, -s * 0.10), s * 0.60, paint);
      canvas.drawCircle(c.translate(s * 0.36, 0), s * 0.46, paint);
    }

    final y = rect.top + rect.height * 0.18;
    blob(Offset(rect.left + rect.width * 0.18, y), rect.width * 0.10);
    blob(Offset(rect.left + rect.width * 0.46, y + rect.height * 0.04),
        rect.width * 0.12);
    blob(Offset(rect.left + rect.width * 0.70, y + rect.height * 0.02),
        rect.width * 0.09);
  }

  void _paintIsland(Canvas canvas, Rect rect) {
    final s = rect.shortestSide;

    final topW =
        cinematic ? min(rect.width * 0.92, s * 1.22) : rect.width * 0.78;
    final topH =
        cinematic ? min(rect.height * 0.34, topW * 0.56) : rect.height * 0.30;
    final depth = cinematic ? rect.height * 0.28 : rect.height * 0.22;

    final cx = rect.left + rect.width * 0.54;
    final cy = rect.top + rect.height * (cinematic ? 0.62 : 0.68);

    final pTop = Offset(cx, cy - topH / 2);
    final pRight = Offset(cx + topW / 2, cy);
    final pBottom = Offset(cx, cy + topH / 2);
    final pLeft = Offset(cx - topW / 2, cy);
    final d = Offset(0, depth);

    final grassBase = _gardenTone(
      primaryBlue,
      hue: 122,
      saturation: isDark ? 0.54 : 0.58,
      lightness: isDark ? 0.30 : 0.44,
    );
    final grassTop =
        _gardenAdjustLightness(grassBase, climate.isNight ? -0.06 : 0.02);
    final grassLeft = _gardenAdjustLightness(grassBase, -0.10);
    final grassRight = _gardenAdjustLightness(grassBase, -0.06);

    final rockBase = _gardenTone(
      primaryBlue,
      hue: 248,
      saturation: isDark ? 0.42 : 0.46,
      lightness: isDark ? 0.13 : 0.17,
    );
    final rockDark = _gardenAdjustLightness(rockBase, -0.10);
    final rockMid = _gardenAdjustLightness(rockBase, -0.04);
    final rockLight = _gardenAdjustLightness(rockBase, 0.02);

    final trunkBase = _gardenTone(
      primaryBlue,
      hue: 28,
      saturation: isDark ? 0.45 : 0.50,
      lightness: isDark ? 0.20 : 0.32,
    );

    // Shadow under the island
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: isDark ? 0.46 : 0.24)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 34);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy + depth * 1.35),
        width: topW * 0.70,
        height: topH * 0.60,
      ),
      shadowPaint,
    );

    // Rock sides
    final leftSide = Path()
      ..moveTo(pLeft.dx, pLeft.dy)
      ..lineTo(pBottom.dx, pBottom.dy)
      ..lineTo(pBottom.dx + d.dx, pBottom.dy + d.dy)
      ..lineTo(pLeft.dx + d.dx, pLeft.dy + d.dy)
      ..close();
    final leftBounds = leftSide.getBounds();
    canvas.drawPath(
      leftSide,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [rockMid, rockDark],
        ).createShader(leftBounds),
    );

    final rightSide = Path()
      ..moveTo(pBottom.dx, pBottom.dy)
      ..lineTo(pRight.dx, pRight.dy)
      ..lineTo(pRight.dx + d.dx, pRight.dy + d.dy)
      ..lineTo(pBottom.dx + d.dx, pBottom.dy + d.dy)
      ..close();
    final rightBounds = rightSide.getBounds();
    canvas.drawPath(
      rightSide,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [rockLight, rockDark],
        ).createShader(rightBounds),
    );

    _paintSpeckles(
      canvas,
      leftSide,
      seed: climate.seed() + 11,
      color: Colors.white.withValues(alpha: isDark ? 0.06 : 0.04),
      count: 26,
      radiusMin: 0.8,
      radiusMax: 1.6,
    );
    _paintSpeckles(
      canvas,
      rightSide,
      seed: climate.seed() + 19,
      color: Colors.white.withValues(alpha: isDark ? 0.06 : 0.04),
      count: 24,
      radiusMin: 0.8,
      radiusMax: 1.6,
    );

    // Grass edges
    canvas.drawPath(
      leftSide,
      Paint()
        ..color = grassLeft.withValues(alpha: 0.30)
        ..blendMode = BlendMode.srcATop,
    );
    canvas.drawPath(
      rightSide,
      Paint()
        ..color = grassRight.withValues(alpha: 0.26)
        ..blendMode = BlendMode.srcATop,
    );

    // Top grass
    final topPath = Path()
      ..moveTo(pTop.dx, pTop.dy)
      ..lineTo(pRight.dx, pRight.dy)
      ..lineTo(pBottom.dx, pBottom.dy)
      ..lineTo(pLeft.dx, pLeft.dy)
      ..close();

    final topRect =
        Rect.fromCenter(center: Offset(cx, cy), width: topW, height: topH);
    final topPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          _gardenAdjustLightness(grassTop, 0.10),
          grassTop,
          _gardenAdjustLightness(grassTop, -0.06),
        ],
        stops: const [0.0, 0.58, 1.0],
      ).createShader(topRect);
    canvas.drawPath(topPath, topPaint);

    // Small pond on the left (keeps the “island in a world” feeling).
    canvas.save();
    canvas.clipPath(topPath);
    final waterBase = _gardenTone(
      primaryBlue,
      hue: 212,
      saturation: isDark ? 0.60 : 0.68,
      lightness: isDark ? 0.34 : 0.52,
    );
    final waterRect = Rect.fromCenter(
      center: Offset(cx - topW * 0.20, cy - topH * 0.06),
      width: topW * 0.30,
      height: topH * 0.18,
    );
    canvas.drawOval(
      waterRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _gardenAdjustLightness(waterBase, 0.10),
            waterBase,
            _gardenAdjustLightness(waterBase, -0.10),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(waterRect),
    );
    canvas.drawArc(
      waterRect.inflate(2.0),
      -0.2,
      pi * 1.2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: climate.isNight ? 0.10 : 0.18),
    );
    canvas.restore();

    // Hill lighting on top.
    canvas.drawPath(
      topPath,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.35, -0.55),
          radius: 1.0,
          colors: [
            Colors.white.withValues(alpha: climate.isNight ? 0.08 : 0.14),
            Colors.transparent,
          ],
          stops: const [0.0, 0.75],
        ).createShader(topRect)
        ..blendMode = BlendMode.screen,
    );
    canvas.drawPath(
      topPath,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.55, 0.70),
          radius: 1.1,
          colors: [
            Colors.black.withValues(alpha: isDark ? 0.18 : 0.12),
            Colors.transparent,
          ],
          stops: const [0.0, 0.80],
        ).createShader(topRect)
        ..blendMode = BlendMode.multiply,
    );

    _paintSpeckles(
      canvas,
      topPath,
      seed: climate.seed() + 3,
      color: Colors.black.withValues(alpha: isDark ? 0.06 : 0.05),
      count: 50,
      radiusMin: 0.7,
      radiusMax: 1.4,
    );

    // Weather accents on the island top
    if (climate.weather == _GardenWeather.snow) {
      canvas.drawPath(
        topPath,
        Paint()..color = Colors.white.withValues(alpha: isDark ? 0.20 : 0.22),
      );
    } else if (climate.weather == _GardenWeather.rain) {
      canvas.drawPath(
        topPath,
        Paint()..color = Colors.black.withValues(alpha: isDark ? 0.12 : 0.06),
      );
    }

    // Subtle outline
    canvas.drawPath(
      topPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.black.withValues(alpha: isDark ? 0.28 : 0.16),
    );

    _paintDecorativeShrubs(canvas,
        cx: cx, cy: cy, topW: topW, topH: topH, grass: grassTop);
    _paintTrees(canvas,
        cx: cx, cy: cy, topW: topW, topH: topH, trunkBase: trunkBase);
  }

  void _paintSpeckles(
    Canvas canvas,
    Path clipPath, {
    required int seed,
    required Color color,
    required int count,
    required double radiusMin,
    required double radiusMax,
  }) {
    final bounds = clipPath.getBounds();
    final rnd = Random(seed);
    final paint = Paint()..color = color;

    canvas.save();
    canvas.clipPath(clipPath);

    for (var i = 0; i < count; i++) {
      final x = bounds.left + rnd.nextDouble() * bounds.width;
      final y = bounds.top + rnd.nextDouble() * bounds.height;
      final r = radiusMin + rnd.nextDouble() * (radiusMax - radiusMin);
      canvas.drawCircle(Offset(x, y), r, paint);
    }

    canvas.restore();
  }

  void _paintDecorativeShrubs(
    Canvas canvas, {
    required double cx,
    required double cy,
    required double topW,
    required double topH,
    required Color grass,
  }) {
    final bush = _gardenAdjustLightness(grass, 0.08);
    final bush2 = _gardenAdjustLightness(grass, -0.02);
    final paint1 = Paint()..color = bush.withValues(alpha: 0.65);
    final paint2 = Paint()..color = bush2.withValues(alpha: 0.55);

    for (final spot in const [
      Offset(-0.06, 0.22),
      Offset(0.24, 0.18),
      Offset(0.42, 0.10),
    ]) {
      final base = Offset(cx + spot.dx * topW / 2, cy + spot.dy * topH / 2);
      final r = topH * 0.08;
      canvas.drawCircle(base.translate(-r * 0.35, 0), r * 0.65, paint2);
      canvas.drawCircle(base.translate(r * 0.10, -r * 0.08), r * 0.78, paint1);
      canvas.drawCircle(base.translate(r * 0.45, 0), r * 0.58, paint2);
    }
  }

  void _paintTrees(
    Canvas canvas, {
    required double cx,
    required double cy,
    required double topW,
    required double topH,
    required Color trunkBase,
  }) {
    final trunk = _gardenTone(
      trunkBase,
      hue: 28,
      saturation: isDark ? 0.42 : 0.46,
      lightness: isDark ? 0.18 : 0.30,
    );
    final count = min(treesPlanted, _GardenIslandLayout.treeSpots.length);
    final items = <({
      Offset base,
      double scale,
      double depth,
      int index,
      _GardenTreeKind kind
    })>[];

    for (var i = 0; i < count; i++) {
      final spot = _GardenIslandLayout.treeSpots[i];
      final base = Offset(cx + spot.dx * topW / 2, cy + spot.dy * topH / 2);
      final depthT = ((spot.dy + 1) / 2).clamp(0.0, 1.0);
      final scale = _gardenLerp(0.78, 1.14, depthT);

      final rnd = Random(9001 + i * 97);
      final jitter = Offset(
        (rnd.nextDouble() - 0.5) * topW * 0.010,
        (rnd.nextDouble() - 0.5) * topH * 0.010,
      );
      final kind = _pickTreeKind(spot: spot, index: i, rnd: rnd);

      items.add((
        base: base + jitter,
        scale: scale,
        depth: depthT,
        index: i,
        kind: kind,
      ));
    }

    // Guarantee a bit of visible variety once the garden grows.
    if (items.isNotEmpty && count >= 8) {
      final last = items.last;
      items[items.length - 1] = (
        base: last.base,
        scale: last.scale,
        depth: last.depth,
        index: last.index,
        kind: _GardenTreeKind.blossom,
      );
    }

    items.sort((a, b) => a.base.dy.compareTo(b.base.dy));

    for (final t in items) {
      Color canopy;
      switch (t.kind) {
        case _GardenTreeKind.redCanopy:
          canopy = _gardenTone(primaryBlue,
              hue: 10, saturation: 0.70, lightness: isDark ? 0.42 : 0.58);
          break;
        case _GardenTreeKind.roundGreen:
          canopy = _gardenTone(primaryBlue,
              hue: 122, saturation: 0.56, lightness: isDark ? 0.34 : 0.50);
          break;
        case _GardenTreeKind.pine:
          canopy = _gardenTone(primaryBlue,
              hue: 138, saturation: 0.46, lightness: isDark ? 0.28 : 0.40);
          break;
        case _GardenTreeKind.palm:
          canopy = _gardenTone(primaryBlue,
              hue: 118, saturation: 0.52, lightness: isDark ? 0.36 : 0.52);
          break;
        case _GardenTreeKind.blossom:
          canopy = _gardenTone(primaryBlue,
              hue: 328, saturation: 0.52, lightness: isDark ? 0.46 : 0.64);
          break;
      }

      // Subtle atmospheric depth: farther trees are a touch lighter.
      canopy = _gardenAdjustLightness(canopy, _gardenLerp(0.07, 0.0, t.depth));

      if (climate.weather == _GardenWeather.snow) {
        canopy = Color.lerp(canopy, Colors.white, 0.24) ?? canopy;
      }
      if (climate.isNight) {
        canopy = canopy.withValues(alpha: 0.88);
      }

      _paintTree(
        canvas,
        base: t.base,
        scale: t.scale,
        depth: t.depth,
        trunk: trunk,
        canopy: canopy,
        kind: t.kind,
        snowy: climate.weather == _GardenWeather.snow,
      );
    }
  }

  _GardenTreeKind _pickTreeKind({
    required Offset spot,
    required int index,
    required Random rnd,
  }) {
    final roll = rnd.nextDouble();

    // Left cluster leans warm (red/orange), similar to the reference.
    if (spot.dx < -0.28) {
      if (roll < 0.74) return _GardenTreeKind.redCanopy;
      if (roll < 0.92) return _GardenTreeKind.roundGreen;
      return _GardenTreeKind.pine;
    }

    // Right cluster leans conifer/palm.
    if (spot.dx > 0.40) {
      if (roll < 0.62) return _GardenTreeKind.pine;
      if (roll < 0.90) return _GardenTreeKind.roundGreen;
      return _GardenTreeKind.palm;
    }

    // Middle mix.
    if (roll < 0.52) return _GardenTreeKind.roundGreen;
    if (roll < 0.74) return _GardenTreeKind.redCanopy;
    if (roll < 0.90) return _GardenTreeKind.pine;
    if (roll < 0.96) return _GardenTreeKind.palm;
    return _GardenTreeKind.blossom;
  }

  void _paintTree(
    Canvas canvas, {
    required Offset base,
    required double scale,
    required double depth,
    required Color trunk,
    required Color canopy,
    required _GardenTreeKind kind,
    required bool snowy,
  }) {
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: isDark ? 0.24 : 0.13);
    canvas.drawOval(
      Rect.fromCenter(
        center: base.translate(0, scale * _gardenLerp(5.0, 6.2, depth)),
        width: 20 * scale * _gardenLerp(0.92, 1.12, depth),
        height: 9 * scale * _gardenLerp(0.92, 1.06, depth),
      ),
      shadowPaint,
    );

    final trunkDark = _gardenAdjustLightness(trunk, -0.10);
    final trunkLight = _gardenAdjustLightness(trunk, 0.10);

    Offset crown;

    if (kind == _GardenTreeKind.palm) {
      final trunkLen = 22.0 * scale;
      final start = base.translate(0, 2.0 * scale);
      final end = base.translate(0, -trunkLen);
      final bend = 4.0 * scale;
      final trunkPath = Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(
          start.dx - bend,
          start.dy - trunkLen * 0.45,
          end.dx,
          end.dy,
        );

      canvas.drawPath(
        trunkPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.8 * scale
          ..strokeCap = StrokeCap.round
          ..color = trunkDark,
      );
      canvas.drawPath(
        trunkPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2 * scale
          ..strokeCap = StrokeCap.round
          ..color = trunkLight.withValues(alpha: 0.55),
      );

      crown = end;
    } else {
      final trunkW = (kind == _GardenTreeKind.pine ? 4.0 : 4.3) * scale;
      final trunkH = (kind == _GardenTreeKind.pine ? 16.0 : 14.0) * scale;
      final trunkRect = Rect.fromLTWH(
        base.dx - trunkW / 2,
        base.dy - trunkH,
        trunkW,
        trunkH,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(trunkRect, Radius.circular(2.4 * scale)),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [trunkDark, trunkLight, trunkDark],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(trunkRect),
      );

      crown = Offset(base.dx, trunkRect.top);
    }

    final canopyDark = _gardenAdjustLightness(canopy, -0.10);
    final canopyLight = _gardenAdjustLightness(canopy, 0.12);

    switch (kind) {
      case _GardenTreeKind.redCanopy:
      case _GardenTreeKind.roundGreen:
      case _GardenTreeKind.blossom:
        final r = (kind == _GardenTreeKind.roundGreen
                ? 10.8
                : kind == _GardenTreeKind.blossom
                    ? 10.5
                    : 11.0) *
            scale;
        final c = crown.translate(0, -r * 0.88);

        // Under-canopy for depth.
        final basePaint = Paint()..color = canopyDark;
        canvas.drawCircle(
            c.translate(-r * 0.55, r * 0.12), r * 0.82, basePaint);
        canvas.drawCircle(c.translate(r * 0.58, r * 0.12), r * 0.78, basePaint);
        canvas.drawCircle(c.translate(0, -r * 0.55), r * 0.90, basePaint);
        canvas.drawCircle(c.translate(0, r * 0.38), r * 0.96, basePaint);

        // Main canopy.
        final canopyPaint = Paint()..color = canopy;
        canvas.drawCircle(
            c.translate(-r * 0.20, -r * 0.22), r * 0.78, canopyPaint);
        canvas.drawCircle(
            c.translate(r * 0.32, -r * 0.08), r * 0.74, canopyPaint);
        canvas.drawCircle(c.translate(0, r * 0.18), r * 0.88, canopyPaint);

        // Highlight.
        canvas.drawCircle(
          c.translate(-r * 0.34, -r * 0.62),
          r * 0.46,
          Paint()..color = canopyLight.withValues(alpha: 0.22),
        );

        if (kind == _GardenTreeKind.blossom) {
          canvas.drawCircle(
            c.translate(r * 0.32, -r * 0.52),
            r * 0.18,
            Paint()
              ..color =
                  Colors.white.withValues(alpha: climate.isNight ? 0.18 : 0.22),
          );
        }
        break;

      case _GardenTreeKind.pine:
        final h = 28.0 * scale;
        final w = 22.0 * scale;

        Path tri(
            {required double topY,
            required double baseY,
            required double width}) {
          final half = width / 2;
          return Path()
            ..moveTo(crown.dx, topY)
            ..lineTo(crown.dx + half, baseY)
            ..lineTo(crown.dx - half, baseY)
            ..close();
        }

        final bottom = tri(
          topY: crown.dy - h * 0.90,
          baseY: crown.dy - h * 0.05,
          width: w,
        );
        final mid = tri(
          topY: crown.dy - h * 1.05,
          baseY: crown.dy - h * 0.28,
          width: w * 0.82,
        );
        final top = tri(
          topY: crown.dy - h * 1.18,
          baseY: crown.dy - h * 0.52,
          width: w * 0.64,
        );

        canvas.drawPath(bottom, Paint()..color = canopyDark);
        canvas.drawPath(mid, Paint()..color = canopy);
        canvas.drawPath(
            top, Paint()..color = canopyLight.withValues(alpha: 0.92));
        canvas.drawCircle(
          Offset(crown.dx, crown.dy - h * 0.05),
          6.2 * scale,
          Paint()..color = canopy,
        );
        break;

      case _GardenTreeKind.palm:
        final frondLen = 18.0 * scale;
        final frondPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6 * scale
          ..strokeCap = StrokeCap.round
          ..color = canopy;
        final hiPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * scale
          ..strokeCap = StrokeCap.round
          ..color = canopyLight.withValues(alpha: 0.35);

        for (final dx in [-0.75, -0.35, 0.0, 0.35, 0.75]) {
          final end = crown.translate(dx * frondLen, frondLen * 0.42);
          final control =
              crown.translate(dx * frondLen * 0.65, -frondLen * 0.78);
          final p = Path()
            ..moveTo(crown.dx, crown.dy)
            ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
          canvas.drawPath(p, frondPaint);
          canvas.drawPath(p, hiPaint);
        }

        canvas.drawCircle(crown.translate(0, -1.0 * scale), 4.0 * scale,
            Paint()..color = canopyDark);
        canvas.drawCircle(crown.translate(0.6 * scale, -1.6 * scale),
            3.4 * scale, Paint()..color = canopy);
        break;
    }

    if (snowy) {
      final snowPaint = Paint()..color = Colors.white.withValues(alpha: 0.55);
      canvas.drawCircle(
          crown.translate(-3.8 * scale, -12.0 * scale), 3.2 * scale, snowPaint);
      canvas.drawCircle(
          crown.translate(4.8 * scale, -9.4 * scale), 2.6 * scale, snowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GardenIslandPainter oldDelegate) {
    return oldDelegate.treesPlanted != treesPlanted ||
        oldDelegate.climate.isNight != climate.isNight ||
        oldDelegate.climate.weather != climate.weather ||
        oldDelegate.isDark != isDark ||
        oldDelegate.primaryBlue != primaryBlue ||
        oldDelegate.surface != surface ||
        oldDelegate.cinematic != cinematic;
  }
}

class _RainOverlayPainter extends CustomPainter {
  final Color color;

  const _RainOverlayPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;

    // Diagonal “rain” streaks.
    const step = 14.0;
    final h = size.height;
    for (double x = -h; x < size.width + h; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x + h, h), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RainOverlayPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _SnowOverlayPainter extends CustomPainter {
  final int seed;
  final Color color;

  const _SnowOverlayPainter({required this.seed, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(seed);
    final paint = Paint()..color = color;

    for (var i = 0; i < 70; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final r = 0.8 + rnd.nextDouble() * 1.6;
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SnowOverlayPainter oldDelegate) {
    return oldDelegate.seed != seed || oldDelegate.color != color;
  }
}

class _StarsOverlayPainter extends CustomPainter {
  final int seed;
  final Color color;

  const _StarsOverlayPainter({required this.seed, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(seed);
    final paint = Paint()..color = color;

    for (var i = 0; i < 48; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height * 0.45;
      final r = 0.6 + rnd.nextDouble() * 1.2;
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarsOverlayPainter oldDelegate) {
    return oldDelegate.seed != seed || oldDelegate.color != color;
  }
}

*/

class MeditationPlayerScreen extends StatefulWidget {
  final MeditationTopic topic;
  const MeditationPlayerScreen({super.key, required this.topic});

  @override
  State<MeditationPlayerScreen> createState() => _MeditationPlayerScreenState();
}

class _MeditationPlayerScreenState extends State<MeditationPlayerScreen> {
  final FlutterTts _tts = FlutterTts();

  static const double _calmSpeechRate = 0.40;
  static const double _calmPitch = 0.92;
  static const Duration _betweenSegmentPause = Duration(milliseconds: 650);

  static const String _prefsVoiceKey = 'meditation_tts_voice_key';
  static const String _prefsSessionsKey = 'meditation_sessions_v1';

  final Map<String, Map<String, String>> _voicesByKey = {};
  List<String> _voiceKeys = [];
  String? _selectedVoiceKey;

  late final List<String> _segments;
  int _segmentIndex = 0;
  bool _isPlaying = false;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _segments = MeditationScriptBuilder.build(widget.topic);
    _initTts();
  }

  Future<void> _initTts() async {
    final prefs = await SharedPreferences.getInstance();
    final storedVoiceKey = prefs.getString(_prefsVoiceKey);

    _selectedVoiceKey = storedVoiceKey;

    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setLanguage('en-US');
      await _applyVoiceSettings();
    } catch (_) {
      // Some platforms throw on unsupported settings; still usable.
    }

    await _loadVoicesAndApplyIfNeeded();

    _tts.setCompletionHandler(() {
      if (!_isPlaying) return;

      final previousText =
          _segmentIndex >= 0 && _segmentIndex < _segments.length
              ? _segments[_segmentIndex]
              : '';

      if (!mounted) return;

      setState(() {
        _segmentIndex = (_segmentIndex + 1).clamp(0, _segments.length);
      });

      if (_segmentIndex >= _segments.length) {
        setState(() => _isPlaying = false);
        _recordSessionCompletion();
        return;
      }

      _speakNextWithPause(previousText: previousText);
    });

    _tts.setErrorHandler((_) {
      if (!mounted) return;
      setState(() => _isPlaying = false);
    });

    if (!mounted) return;
    setState(() => _isReady = true);
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (!_isReady) return;

    if (_isPlaying) {
      setState(() => _isPlaying = false);
      await _tts.stop();
      return;
    }

    if (_segmentIndex >= _segments.length) {
      setState(() => _segmentIndex = 0);
    }

    setState(() => _isPlaying = true);
    await _applySelectedVoice(persist: false);
    await _speakCurrent();
  }

  Future<void> _recordSessionCompletion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsSessionsKey);

      List<dynamic> decoded = [];
      if (raw != null && raw.trim().isNotEmpty) {
        final parsed = jsonDecode(raw);
        if (parsed is List) decoded = parsed;
      }

      decoded.add({
        'topicId': widget.topic.id,
        'title': widget.topic.title,
        'minutes': widget.topic.minutes,
        'timestamp': DateTime.now().toIso8601String(),
      });

      if (decoded.length > 200) {
        decoded.removeRange(0, decoded.length - 200);
      }

      await prefs.setString(_prefsSessionsKey, jsonEncode(decoded));
    } catch (_) {
      // Ignore local persistence errors.
    }
  }

  Future<void> _speakCurrent() async {
    if (_segmentIndex < 0 || _segmentIndex >= _segments.length) return;
    final text = _segments[_segmentIndex];
    await _tts.speak(text);
  }

  Duration _pauseAfterSegment(String text) {
    final t = text.trimRight();
    if (t.isEmpty) return _betweenSegmentPause;

    if (t.endsWith('…') || t.endsWith('...')) {
      return const Duration(milliseconds: 950);
    }
    if (t.endsWith('.') || t.endsWith('!') || t.endsWith('?')) {
      return const Duration(milliseconds: 850);
    }
    if (t.endsWith(',') || t.endsWith(':') || t.endsWith(';')) {
      return const Duration(milliseconds: 750);
    }

    // Longer segments often benefit from a slightly longer reset.
    if (t.length >= 140) {
      return const Duration(milliseconds: 900);
    }

    return _betweenSegmentPause;
  }

  Future<void> _speakNextWithPause({required String previousText}) async {
    if (!_isPlaying) return;
    await Future.delayed(_pauseAfterSegment(previousText));
    if (!_isPlaying) return;
    await _speakCurrent();
  }

  int _voiceScore(Map<String, String> voice) {
    final name = (voice['name'] ?? '').toLowerCase();
    final locale = (voice['locale'] ?? '').toLowerCase();

    var score = 0;
    if (locale == 'en-us') score += 90;
    if (locale.startsWith('en-')) score += 50;
    if (name.contains('neural')) score += 80;
    if (name.contains('enhanced')) score += 60;
    if (name.contains('premium')) score += 50;
    if (name.contains('online')) score += 35;
    if (name.contains('local')) score -= 10;
    return score;
  }

  List<String> _uiVoiceKeysFor(List<String> sortedKeys) {
    if (sortedKeys.isEmpty) return const [];

    final first = sortedKeys.first;
    String? second;

    // Intentionally skip the 2nd-ranked voice because on many devices the
    // top few voices can be very similar. Using #3 often yields a clearer
    // “second choice”.
    if (sortedKeys.length > 2) {
      second = sortedKeys[2];
    } else if (sortedKeys.length > 1) {
      second = sortedKeys[1];
    }

    final keys = <String>[first];
    if (second != null && !keys.contains(second)) {
      keys.add(second);
    }
    return keys;
  }

  List<_NamedVoiceOption> _namedVoiceOptions() {
    final keys = _uiVoiceKeysFor(_voiceKeys);
    if (keys.isEmpty) return const <_NamedVoiceOption>[];

    final options = <_NamedVoiceOption>[
      _NamedVoiceOption(name: 'John', voiceKey: keys[0]),
    ];

    if (keys.length > 1) {
      options.add(_NamedVoiceOption(name: 'Anna', voiceKey: keys[1]));
    }

    return options;
  }

  Future<void> _loadVoicesAndApplyIfNeeded() async {
    dynamic raw;
    try {
      raw = await _tts.getVoices;
    } catch (_) {
      raw = null;
    }

    final voicesByKey = <String, Map<String, String>>{};
    if (raw is List) {
      for (final v in raw) {
        if (v is! Map) continue;
        final name = (v['name'] ?? '').toString();
        final locale = (v['locale'] ?? '').toString();
        if (name.trim().isEmpty || locale.trim().isEmpty) continue;
        if (!locale.toLowerCase().startsWith('en')) continue;

        final key = '$locale|$name';
        voicesByKey[key] = {'name': name, 'locale': locale};
      }
    }

    final keys = voicesByKey.keys.toList();
    keys.sort(
      (a, b) =>
          _voiceScore(voicesByKey[b]!).compareTo(_voiceScore(voicesByKey[a]!)),
    );

    final uiKeys = _uiVoiceKeysFor(keys);

    // If the stored selection disappeared (engine changed), fall back to default.
    final storedKey = _selectedVoiceKey;
    String? nextSelected =
        (storedKey != null && voicesByKey.containsKey(storedKey))
            ? storedKey
            : null;

    // If no selection yet, auto-pick the best voice for this device.
    final prefs = await SharedPreferences.getInstance();
    if (nextSelected == null && uiKeys.isNotEmpty) {
      nextSelected = uiKeys.first;
      await prefs.setString(_prefsVoiceKey, nextSelected);
    }

    // Keep the persisted selection aligned with the visible options.
    if (nextSelected != null &&
        uiKeys.isNotEmpty &&
        !uiKeys.contains(nextSelected)) {
      nextSelected = uiKeys.first;
      await prefs.setString(_prefsVoiceKey, nextSelected);
    }

    if (mounted) {
      setState(() {
        _voicesByKey
          ..clear()
          ..addAll(voicesByKey);
        _voiceKeys = keys;
        _selectedVoiceKey = nextSelected;
      });
    } else {
      _voicesByKey
        ..clear()
        ..addAll(voicesByKey);
      _voiceKeys = keys;
      _selectedVoiceKey = nextSelected;
    }

    if (nextSelected != null) {
      await _applySelectedVoice(persist: false);
    }
  }

  Future<void> _applyVoiceSettings() async {
    try {
      await _tts.setSpeechRate(_calmSpeechRate);
      await _tts.setPitch(_calmPitch);
      await _tts.setVolume(1.0);
    } catch (_) {
      // Ignore unsupported settings.
    }
  }

  Future<void> _applySelectedVoice({required bool persist}) async {
    final key = _selectedVoiceKey;
    if (key == null) return;
    final voice = _voicesByKey[key];
    if (voice == null) return;

    try {
      final locale = voice['locale'];
      if (locale != null && locale.trim().isNotEmpty) {
        await _tts.setLanguage(locale);
      }
    } catch (_) {
      // Ignore.
    }

    try {
      await _tts.setVoice(voice);
    } catch (_) {
      // Some engines don't support explicit voice selection.
    }

    // Some engines reset parameters after setVoice.
    await _applyVoiceSettings();

    if (!persist) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsVoiceKey, key);
  }

  Future<void> _previewVoice() async {
    if (!_isReady) return;

    if (_isPlaying) {
      setState(() => _isPlaying = false);
    }

    await _tts.stop();
    await _applySelectedVoice(persist: false);
    await _applyVoiceSettings();
    await _tts.speak(
        'Take a slow breath in through your nose… and a slower breath out.');
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

    final progress = _segments.isEmpty
        ? 0.0
        : (_segmentIndex / _segments.length).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text('Now Playing', style: TextStyle(color: primaryText)),
        iconTheme: IconThemeData(color: primaryText),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color: primaryBlue.withValues(alpha: 0.14)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            color: primaryBlue.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(widget.topic.icon,
                              color: primaryBlue, size: 56),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.topic.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: primaryText),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.topic.durationLabel,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: secondaryText),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.topic.description,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 13, height: 1.45, color: secondaryText),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _segmentIndex >= _segments.length
                              ? 'Completed'
                              : 'Step ${_segmentIndex + 1} of ${_segments.length}',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: secondaryText),
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 10,
                            backgroundColor:
                                primaryBlue.withValues(alpha: 0.12),
                            valueColor: AlwaysStoppedAnimation(primaryBlue),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _segmentIndex < _segments.length
                              ? _segments[_segmentIndex]
                              : 'Nice work. Take one slow breath and carry this calm with you.',
                          style: TextStyle(
                              fontSize: 13, height: 1.45, color: primaryText),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: primaryBlue.withValues(alpha: 0.14)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Voice',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: secondaryText,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Builder(
                          builder: (context) {
                            final options = _namedVoiceOptions();
                            if (options.isEmpty) {
                              return Text(
                                'Use your device Voice settings to change the voice.',
                                style: TextStyle(
                                  color: secondaryText,
                                  fontSize: 12,
                                  height: 1.35,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            }

                            return Row(
                              children: List.generate(options.length, (index) {
                                final opt = options[index];
                                final isSelected =
                                    _selectedVoiceKey == opt.voiceKey;
                                return Expanded(
                                  child: GestureDetector(
                                    onTap: !_isReady
                                        ? null
                                        : () async {
                                            if (_isPlaying) {
                                              setState(
                                                  () => _isPlaying = false);
                                            }
                                            await _tts.stop();
                                            if (!mounted) return;
                                            setState(() => _selectedVoiceKey =
                                                opt.voiceKey);
                                            await _applySelectedVoice(
                                                persist: true);
                                          },
                                    child: Container(
                                      margin: EdgeInsets.only(
                                          right: index == options.length - 1
                                              ? 0
                                              : 8),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      decoration: BoxDecoration(
                                        color:
                                            isSelected ? primaryBlue : surface,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color:
                                              isSelected ? primaryBlue : border,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          opt.name,
                                          style: TextStyle(
                                            color: isSelected
                                                ? Colors.white
                                                : primaryText,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _previewVoice,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryBlue,
                              side: BorderSide(color: border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Preview',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isReady ? _togglePlay : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _isPlaying ? 'Pause' : 'Play',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16),
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
}

class _NamedVoiceOption {
  final String name;
  final String voiceKey;

  const _NamedVoiceOption({
    required this.name,
    required this.voiceKey,
  });
}

class MeditationScriptBuilder {
  static List<String> build(MeditationTopic topic) {
    final cues = topic.cues;

    final intro =
        'Welcome. This is ${topic.title}. Find a comfortable position. If it feels safe, let your eyes gently close.';

    const settle =
        'Take a slow breath in through your nose… and an even slower breath out. Let your shoulders soften. Let your jaw unclench.';

    final guidance = <String>[
      'For the next few minutes, we\'ll keep it simple. You don\'t need to force calm. You\'re practicing returning, again and again.',
      ...cues.map((c) => 'Gently notice: $c.'),
      'If your mind wanders, that\'s normal. Notice it, and come back to your breath without judging yourself.',
    ];

    const closing =
        'Now take one deeper breath in… and let it go. Notice how you feel. When you\'re ready, open your eyes. Well done.';

    return [intro, settle, ...guidance, closing];
  }
}
