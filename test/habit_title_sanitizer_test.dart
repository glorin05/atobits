import 'package:flutter_test/flutter_test.dart';

import 'package:atobits/core/utils/habit_title_sanitizer.dart';

void main() {
  group('sanitizeHabitTitle', () {
    test('keeps clean single-word titles', () {
      expect(sanitizeHabitTitle('journaling'), 'Journaling');
      expect(sanitizeHabitTitle('  Journaling  '), 'Journaling');
    });

    test('strips common command prefixes', () {
      expect(
        sanitizeHabitTitle('add an habit called journaling'),
        'Journaling',
      );
      expect(
        sanitizeHabitTitle('create a habit for reading'),
        'Reading',
      );
      expect(
        sanitizeHabitTitle('remind me to drink water'),
        'Drink Water',
      );
      expect(
        sanitizeHabitTitle("let's add a habit called morning run"),
        'Morning Run',
      );
    });

    test('strips trailing schedule phrases', () {
      expect(sanitizeHabitTitle('jog every morning'), 'Jog');
      expect(sanitizeHabitTitle('meditate daily'), 'Meditate');
      expect(sanitizeHabitTitle('drink water at 7am'), 'Drink Water');
      expect(sanitizeHabitTitle('drink water at 07:30'), 'Drink Water');
    });

    test('preserves acronyms', () {
      expect(sanitizeHabitTitle('HIIT workout'), 'HIIT Workout');
      expect(sanitizeHabitTitle('GTD review'), 'GTD Review');
    });

    test('throws on empty or very noisy titles', () {
      expect(() => sanitizeHabitTitle(''),
          throwsA(isA<HabitTitleParseException>()));
      expect(() => sanitizeHabitTitle('a'),
          throwsA(isA<HabitTitleParseException>()));
      expect(
        () => sanitizeHabitTitle(
          'add a habit of going to the gym after work and before dinner',
        ),
        throwsA(isA<HabitTitleParseException>()),
      );
    });
  });
}
