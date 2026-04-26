import 'package:flutter/material.dart';

class HabitIconOption {
  final String key;
  final String label;
  final IconData icon;

  const HabitIconOption({
    required this.key,
    required this.label,
    required this.icon,
  });
}

class HabitIconRegistry {
  static const String defaultKey = 'mi:water_drop';

  static const List<HabitIconOption> options = [
    HabitIconOption(
        key: 'mi:water_drop', label: 'water', icon: Icons.water_drop),
    HabitIconOption(key: 'mi:check', label: 'task', icon: Icons.check),
    HabitIconOption(key: 'mi:menu_book', label: 'read', icon: Icons.menu_book),
    HabitIconOption(
        key: 'mi:self_improvement',
        label: 'meditate',
        icon: Icons.self_improvement),
    HabitIconOption(
        key: 'mi:directions_run', label: 'run', icon: Icons.directions_run),
    HabitIconOption(
        key: 'mi:fitness_center', label: 'workout', icon: Icons.fitness_center),
    HabitIconOption(key: 'mi:bedtime', label: 'sleep', icon: Icons.bedtime),
    HabitIconOption(
        key: 'mi:track_changes', label: 'goal', icon: Icons.track_changes),
    HabitIconOption(key: 'mi:edit_note', label: 'write', icon: Icons.edit_note),
    HabitIconOption(
        key: 'mi:psychology', label: 'focus', icon: Icons.psychology),
    HabitIconOption(
        key: 'mi:medication', label: 'medicine', icon: Icons.medication),
    HabitIconOption(
        key: 'mi:restaurant', label: 'nutrition', icon: Icons.restaurant),
    HabitIconOption(
        key: 'mi:directions_walk', label: 'walk', icon: Icons.directions_walk),
    HabitIconOption(
        key: 'mi:emoji_food_beverage',
        label: 'diet',
        icon: Icons.emoji_food_beverage),
    HabitIconOption(key: 'mi:spa', label: 'wellness', icon: Icons.spa),
    HabitIconOption(key: 'mi:school', label: 'study', icon: Icons.school),
    HabitIconOption(key: 'mi:code', label: 'coding', icon: Icons.code),
    HabitIconOption(
        key: 'mi:cleaning_services',
        label: 'cleaning',
        icon: Icons.cleaning_services),
    HabitIconOption(key: 'mi:savings', label: 'saving', icon: Icons.savings),
    HabitIconOption(
        key: 'mi:music_note', label: 'music', icon: Icons.music_note),
    HabitIconOption(key: 'mi:palette', label: 'art', icon: Icons.palette),
    HabitIconOption(
        key: 'mi:nightlight_round',
        label: 'night routine',
        icon: Icons.nightlight_round),
    HabitIconOption(
        key: 'mi:wb_sunny', label: 'morning routine', icon: Icons.wb_sunny),
    HabitIconOption(key: 'mi:push_pin', label: 'pin', icon: Icons.push_pin),
  ];

  static final Map<String, HabitIconOption> _byKey = {
    for (final item in options) item.key: item,
  };

  static const Map<String, String> _legacyToKey = {
    '58727': 'mi:check',
    '983075': 'mi:water_drop',
    '984482': 'mi:water_drop',
    '58319': 'mi:menu_book',
    '57701': 'mi:self_improvement',
    '58713': 'mi:directions_run',
    '57544': 'mi:fitness_center',
    '59343': 'mi:bedtime',
    '59390': 'mi:track_changes',
    '58396': 'mi:edit_note',
    '59620': 'mi:psychology',
    '57714': 'mi:medication',
    '58710': 'mi:restaurant',
    '💧': 'mi:water_drop',
    '✅': 'mi:check',
    '📚': 'mi:menu_book',
    '🧘': 'mi:self_improvement',
    '🏃': 'mi:directions_run',
    '🏋️': 'mi:fitness_center',
    '😴': 'mi:bedtime',
    '🎯': 'mi:track_changes',
    '✍️': 'mi:edit_note',
    '🧠': 'mi:psychology',
    '💊': 'mi:medication',
    '🍽️': 'mi:restaurant',
    '📌': 'mi:push_pin',
    '❓': 'mi:push_pin',
  };

  static String normalizeStored(dynamic rawValue) {
    final value = (rawValue ?? '').toString().trim();
    if (value.isEmpty) return defaultKey;

    if (_byKey.containsKey(value)) return value;

    final mapped = _legacyToKey[value];
    if (mapped != null) return mapped;

    if (int.tryParse(value) != null) return defaultKey;

    return defaultKey;
  }

  static IconData iconFromStored(dynamic rawValue) {
    final key = normalizeStored(rawValue);
    return _byKey[key]?.icon ?? Icons.push_pin;
  }

  static String keyFromStored(dynamic rawValue) {
    return normalizeStored(rawValue);
  }

  static List<HabitIconOption> search(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return options;
    return options
        .where((item) => item.label.contains(q) || item.key.contains(q))
        .toList();
  }
}
