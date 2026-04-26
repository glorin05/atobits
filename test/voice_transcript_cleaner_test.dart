import 'package:flutter_test/flutter_test.dart';

import 'package:atobits/core/utils/voice_transcript_cleaner.dart';

void main() {
  group('VoiceTranscriptCleaner.clean', () {
    test('strips leading filler words', () {
      expect(
        VoiceTranscriptCleaner.clean('um add meditation'),
        equals('Add meditation'),
      );
      expect(
        VoiceTranscriptCleaner.clean('uh remind me to journal'),
        equals('Remind me to journal'),
      );
      expect(
        VoiceTranscriptCleaner.clean('er complete morning run'),
        equals('Complete morning run'),
      );
      expect(
        VoiceTranscriptCleaner.clean('ah show my stats'),
        equals('Show my stats'),
      );
    });

    test('does not strip filler mid-sentence', () {
      expect(
        VoiceTranscriptCleaner.clean('add um journaling'),
        equals('Add um journaling'),
      );
    });

    test('strips trailing punctuation artefacts', () {
      expect(
        VoiceTranscriptCleaner.clean('add journaling.'),
        equals('Add journaling'),
      );
      expect(
        VoiceTranscriptCleaner.clean('open analytics\u2026'),
        equals('Open analytics'),
      );
      expect(
        VoiceTranscriptCleaner.clean('complete meditation...'),
        equals('Complete meditation'),
      );
    });

    test('collapses whitespace and capitalises first character', () {
      expect(
        VoiceTranscriptCleaner.clean('   add  journaling   '),
        equals('Add journaling'),
      );
      expect(
        VoiceTranscriptCleaner.clean('add morning run'),
        equals('Add morning run'),
      );
      expect(
        VoiceTranscriptCleaner.clean('Add Morning Run'),
        equals('Add Morning Run'),
      );
    });

    test('combined: filler + spaces + period', () {
      expect(
        VoiceTranscriptCleaner.clean('uh  complete  meditation.'),
        equals('Complete meditation'),
      );
    });

    test('empty / whitespace-only input stays empty', () {
      expect(VoiceTranscriptCleaner.clean(''), equals(''));
      expect(VoiceTranscriptCleaner.clean('   '), equals(''));
    });

    test('single character capitalised', () {
      expect(VoiceTranscriptCleaner.clean('a'), equals('A'));
    });
  });

  group('VoiceTranscriptCleaner.isNoise', () {
    test('empty / filler-only is noise', () {
      expect(VoiceTranscriptCleaner.isNoise(''), isTrue);
      expect(VoiceTranscriptCleaner.isNoise('   '), isTrue);
      expect(VoiceTranscriptCleaner.isNoise('a'), isTrue);
      expect(VoiceTranscriptCleaner.isNoise('um '), isTrue);
    });

    test('valid transcript is not noise', () {
      expect(VoiceTranscriptCleaner.isNoise('add meditation'), isFalse);
    });
  });
}
