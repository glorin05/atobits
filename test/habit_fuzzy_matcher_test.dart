import 'package:flutter_test/flutter_test.dart';

import 'package:atobits/core/utils/habit_fuzzy_matcher.dart';

void main() {
  const habits = [
    'Morning Run',
    'Journaling',
    'Meditation',
    'Drink Water',
    'Read 20 Pages',
    'HIIT Workout',
    'Evening Walk',
    'Cold Shower',
  ];

  group('HabitFuzzyMatcher.findBestMatch', () {
    test('exact match (same case)', () {
      expect(
        HabitFuzzyMatcher.findBestMatch('Morning Run', habits),
        equals('Morning Run'),
      );
    });

    test('exact match (different case)', () {
      expect(
        HabitFuzzyMatcher.findBestMatch('morning run', habits),
        equals('Morning Run'),
      );
    });

    test('normalised exact (articles stripped)', () {
      expect(
        HabitFuzzyMatcher.findBestMatch('my meditation', habits),
        equals('Meditation'),
      );
      expect(
        HabitFuzzyMatcher.findBestMatch('the evening walk', habits),
        equals('Evening Walk'),
      );
    });

    test('contains match (query is substring of title)', () {
      expect(
        HabitFuzzyMatcher.findBestMatch('run', habits),
        equals('Morning Run'),
      );
    });

    test('contains match (title is substring of query)', () {
      expect(
        HabitFuzzyMatcher.findBestMatch('do some journaling today', habits),
        equals('Journaling'),
      );
    });

    test('typo tolerance via Levenshtein', () {
      expect(
        HabitFuzzyMatcher.findBestMatch('Meditaton', habits),
        equals('Meditation'),
      );
      expect(
        HabitFuzzyMatcher.findBestMatch('Journalingg', habits),
        equals('Journaling'),
      );
    });

    test('returns null when nothing is close enough', () {
      expect(
        HabitFuzzyMatcher.findBestMatch('Cooking', habits),
        isNull,
      );
    });

    test('acronym match: "hiit" → "HIIT Workout"', () {
      expect(
        HabitFuzzyMatcher.findBestMatch('hiit', habits),
        equals('HIIT Workout'),
      );
    });
  });

  group('HabitFuzzyMatcher.findWithConfidence', () {
    test('exact match returns MatchConfidence.exact', () {
      final result = HabitFuzzyMatcher.findWithConfidence('Meditation', habits);
      expect(result, isNotNull);
      expect(result!.title, equals('Meditation'));
      expect(result.confidence, equals(MatchConfidence.exact));
    });

    test('contains match returns MatchConfidence.high', () {
      final result = HabitFuzzyMatcher.findWithConfidence('run', habits);
      expect(result, isNotNull);
      expect(result!.confidence, equals(MatchConfidence.high));
    });

    test('no match returns null', () {
      final result = HabitFuzzyMatcher.findWithConfidence('Skydiving', habits);
      expect(result, isNull);
    });
  });

  group('HabitFuzzyMatcher.levenshtein', () {
    test('identical strings → 0', () {
      expect(HabitFuzzyMatcher.levenshtein('abc', 'abc'), equals(0));
    });

    test('empty vs non-empty → length of non-empty', () {
      expect(HabitFuzzyMatcher.levenshtein('', 'abc'), equals(3));
      expect(HabitFuzzyMatcher.levenshtein('abc', ''), equals(3));
    });

    test('single substitution', () {
      expect(HabitFuzzyMatcher.levenshtein('cat', 'bat'), equals(1));
    });
  });
}
