class HabitTitleParseException implements Exception {
  final String message;
  const HabitTitleParseException(this.message);

  @override
  String toString() => message;
}

String sanitizeHabitTitle(String raw) {
  var s = _stripQuotes(raw).trim();
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

  if (s.isEmpty) {
    throw const HabitTitleParseException('Empty habit title');
  }

  // Stage 1 — Command prefix stripping (ordered).
  var iterations = 0;
  var changed = true;
  while (changed && iterations < 6) {
    changed = false;
    for (final re in _prefixPatterns) {
      final replaced = s.replaceFirst(re, '').trim();
      if (replaced != s) {
        s = replaced;
        changed = true;
        break;
      }
    }
    iterations++;
  }

  // Stage 2 — Trailing noise stripping.
  for (final re in _suffixPatterns) {
    final replaced = s.replaceFirst(re, '').trim();
    if (replaced != s) {
      s = replaced;
    }
  }

  // Stage 3 — Normalization.
  s = s
      .replaceAll(RegExp(r'^[\s\-:]+'), '')
      .replaceAll(RegExp(r'[\s\-:]+$'), '')
      .replaceAll(RegExp(r'[\.!?,;]+$'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  final wordCount = _countWords(s);
  if (s.isEmpty || wordCount == 0) {
    throw HabitTitleParseException(
        'Could not extract a clean habit title from: "$raw"');
  }

  // Guard: reject likely-sentence payloads.
  if (wordCount > 6) {
    throw HabitTitleParseException(
        'Could not extract a clean habit title from: "$raw"');
  }

  // Guard: reject extremely short titles.
  final alphaNumCount = RegExp(r'[A-Za-z0-9]').allMatches(s).length;
  if (alphaNumCount < 2) {
    throw HabitTitleParseException(
        'Could not extract a clean habit title from: "$raw"');
  }

  return _toTitleCasePreservingAcronyms(s);
}

String? trySanitizeHabitTitle(String raw) {
  try {
    return sanitizeHabitTitle(raw);
  } catch (_) {
    return null;
  }
}

String _stripQuotes(String value) {
  final v = value.trim();
  if ((v.startsWith('"') && v.endsWith('"')) ||
      (v.startsWith("'") && v.endsWith("'"))) {
    return v.substring(1, v.length - 1).trim();
  }
  return v;
}

int _countWords(String value) {
  return value
      .split(RegExp(r'\s+'))
      .map((w) => w.trim())
      .where((w) => w.isNotEmpty)
      .length;
}

String _toTitleCasePreservingAcronyms(String value) {
  final words = value.split(' ').where((w) => w.isNotEmpty).toList();
  final out = <String>[];

  for (final w in words) {
    out.add(_titleCaseToken(w));
  }

  return out.join(' ');
}

String _titleCaseToken(String token) {
  // Preserve tokens containing digits as-is except we still want to titlecase
  // pure alpha segments around hyphens.
  final parts = token.split('-');
  final casedParts = parts.map(_titleCasePart).toList();
  return casedParts.join('-');
}

String _titleCasePart(String part) {
  if (part.isEmpty) return part;

  // Numbers or symbols.
  if (!RegExp(r'[A-Za-z]').hasMatch(part)) return part;

  // Acronyms.
  if (part.length > 1 && part.toUpperCase() == part) return part;

  // Preserve internal casing (e.g., iOS) when user clearly provided it.
  final hasUpperAfterFirst =
      part.length > 1 && RegExp(r'[A-Z]').hasMatch(part.substring(1));
  if (hasUpperAfterFirst && part.toLowerCase() != part) return part;

  if (part.length == 1) return part.toUpperCase();

  return part[0].toUpperCase() + part.substring(1).toLowerCase();
}

final List<RegExp> _prefixPatterns = <RegExp>[
  // "add a habit called X" / "add an habit called X"
  RegExp(r'^\s*(?:please\s+)?add\s+an?\s+habit\s+called\s+',
      caseSensitive: false),
  RegExp(r'^\s*(?:please\s+)?add\s+an?\s+habit\s+named\s+',
      caseSensitive: false),
  RegExp(r'^\s*(?:please\s+)?add\s+an?\s+habit\s+(?:for|of)\s+',
      caseSensitive: false),

  // "add X" (strip filler articles after add).
  RegExp(r'^\s*(?:please\s+)?add\s+(?:a|an|the)\s+', caseSensitive: false),

  // "create / set up / track / start ..."
  RegExp(
      r'^\s*(?:please\s+)?(?:create|set\s+up|track|start)\s+(?:a|an|the)?\s*',
      caseSensitive: false),

  // "remind me to ..."
  RegExp(r'^\s*(?:please\s+)?remind\s+me\s+to\s+', caseSensitive: false),

  // "I want to ..."
  RegExp(
      r'^\s*i\s+want\s+to\s+(?:start\s+)?(?:track(?:ing)?|do(?:ing)?|add)?\s*',
      caseSensitive: false),

  // "Let's ..."
  RegExp(r"^\s*let'?s\s+(?:add|track|start|do)\s+(?:a|an|the)?\s*",
      caseSensitive: false),

  // "Can you ..."
  RegExp(r'^\s*can\s+you\s+(?:add|create|set\s+up)\s+(?:a|an|the)?\s*',
      caseSensitive: false),

  // "new habit: X" / "habit: X"
  RegExp(r'^\s*new\s+habit\s*[:\-]?\s*', caseSensitive: false),
  RegExp(r'^\s*(?:the\s+)?(?:my\s+)?habit\s*[:\-]?\s*', caseSensitive: false),

  // "habit for X" often leaves a leading "for" after stripping.
  RegExp(r'^\s*(?:for|of)\s+', caseSensitive: false),

  // Stray "called/named".
  RegExp(r'^\s*called\s+', caseSensitive: false),
  RegExp(r'^\s*named\s+', caseSensitive: false),
];

final List<RegExp> _suffixPatterns = <RegExp>[
  RegExp(r'\s+(?:every|each)\s+(?:day|morning|evening|night|week)$',
      caseSensitive: false),
  RegExp(r'\s+daily$', caseSensitive: false),
  RegExp(r'\s+in\s+the\s+(?:morning|evening|afternoon|night)$',
      caseSensitive: false),
  RegExp(r'\s+at\s+\d{1,2}(?::\d{2})?\s*(?:am|pm)?$', caseSensitive: false),
];
