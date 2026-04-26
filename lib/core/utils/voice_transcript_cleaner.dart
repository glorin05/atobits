/// Cleans raw speech-to-text transcripts before they are passed to the
/// local intent interpreter or the LLM.
///
/// STT engines frequently emit:
///  - Leading filler words ("um", "uh", ...)
///  - Spurious punctuation at the end ("add meditation.")
///  - Double spaces from hesitation gaps
///  - All-lowercase output
///
/// This cleaner is intentionally conservative — it only removes artefacts that
/// are unambiguously noise.
class VoiceTranscriptCleaner {
  VoiceTranscriptCleaner._();

  static final _leadingFillerRe = RegExp(
    r'^(um+h?|uh+|er+|ah+|hmm+|hm+|mhm+|oh+)\b\s*',
    caseSensitive: false,
  );

  static final _trailingPunctuationRe = RegExp(r'[.\u2026]+$');

  static final _whitespaceRe = RegExp(r'\s{2,}');

  /// Return a cleaned transcript ready for intent parsing.
  static String clean(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return s;

    // Strip one leading filler token.
    s = s.replaceFirst(_leadingFillerRe, '');

    // Collapse multiple spaces.
    s = s.replaceAll(_whitespaceRe, ' ').trim();

    // Strip trailing STT punctuation artefacts.
    s = s.replaceFirst(_trailingPunctuationRe, '').trim();

    // Capitalise first character.
    if (s.isNotEmpty) {
      s = s[0].toUpperCase() + s.substring(1);
    }

    return s;
  }

  /// Returns true if [raw] appears to be empty or pure noise (all fillers).
  static bool isNoise(String raw) {
    final cleaned = clean(raw);
    return cleaned.length < 2;
  }
}
