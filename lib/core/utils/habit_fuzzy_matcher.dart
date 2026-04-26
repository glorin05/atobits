/// Fuzzy matching for habit titles.
///
/// This helps resolve user phrases like "complete my jog" when the stored
/// habit title is "Morning Jog".
///
/// Resolution order (first match wins):
///  1) Exact match (case-insensitive)
///  2) Normalised exact match (strip punctuation/articles)
///  3) One-way contains (query ⊂ title OR title ⊂ query)
///  4) Word-overlap score ≥ threshold
///  5) Levenshtein distance ≤ [maxDistance]
class HabitFuzzyMatcher {
  HabitFuzzyMatcher._();

  static const int _defaultMaxDistance = 3;
  static const double _wordOverlapThreshold = 0.6;

  /// Return the best matching title from [existingTitles] for [query].
  ///
  /// Returns `null` when no title is close enough (callers should ask the user
  /// to clarify rather than guessing).
  static String? findBestMatch(
    String query,
    List<String> existingTitles, {
    int maxDistance = _defaultMaxDistance,
  }) {
    if (existingTitles.isEmpty) return null;

    final q = _normalise(query);
    if (q.isEmpty) return null;

    // 1) Exact (case-insensitive)
    for (final t in existingTitles) {
      if (_normalise(t) == q) return t;
    }

    // 2) Normalised exact (strip articles)
    final qStripped = _stripArticles(q);
    for (final t in existingTitles) {
      if (_stripArticles(_normalise(t)) == qStripped) return t;
    }

    // 3) Contains
    for (final t in existingTitles) {
      final tn = _normalise(t);
      if (tn.contains(q) || q.contains(tn)) return t;
    }

    // 4) Word overlap
    final qWords = _words(q);
    String? bestOverlapTitle;
    double bestOverlapScore = 0;

    for (final t in existingTitles) {
      final score = _wordOverlap(qWords, _words(_normalise(t)));
      if (score >= _wordOverlapThreshold && score > bestOverlapScore) {
        bestOverlapScore = score;
        bestOverlapTitle = t;
      }
    }
    if (bestOverlapTitle != null) return bestOverlapTitle;

    // 5) Levenshtein
    String? bestLevTitle;
    int bestDist = maxDistance + 1;

    for (final t in existingTitles) {
      final d = levenshtein(q, _normalise(t));
      if (d < bestDist) {
        bestDist = d;
        bestLevTitle = t;
      }
    }

    return bestDist <= maxDistance ? bestLevTitle : null;
  }

  /// Like [findBestMatch], but returns confidence tier.
  static MatchResult? findWithConfidence(
    String query,
    List<String> existingTitles, {
    int maxDistance = _defaultMaxDistance,
  }) {
    if (existingTitles.isEmpty) return null;

    final q = _normalise(query);
    if (q.isEmpty) return null;

    // Exact
    for (final t in existingTitles) {
      if (_normalise(t) == q) {
        return MatchResult(title: t, confidence: MatchConfidence.exact);
      }
    }

    // Normalised exact
    final qStripped = _stripArticles(q);
    for (final t in existingTitles) {
      if (_stripArticles(_normalise(t)) == qStripped) {
        return MatchResult(title: t, confidence: MatchConfidence.exact);
      }
    }

    // Contains
    for (final t in existingTitles) {
      final tn = _normalise(t);
      if (tn.contains(q) || q.contains(tn)) {
        return MatchResult(title: t, confidence: MatchConfidence.high);
      }
    }

    // Word overlap
    final qWords = _words(q);
    for (final t in existingTitles) {
      final score = _wordOverlap(qWords, _words(_normalise(t)));
      if (score >= _wordOverlapThreshold) {
        return MatchResult(title: t, confidence: MatchConfidence.high);
      }
    }

    // Levenshtein
    String? bestLevTitle;
    int bestDist = maxDistance + 1;

    for (final t in existingTitles) {
      final d = levenshtein(q, _normalise(t));
      if (d < bestDist) {
        bestDist = d;
        bestLevTitle = t;
      }
    }

    if (bestDist <= maxDistance && bestLevTitle != null) {
      final confidence =
          bestDist <= 1 ? MatchConfidence.high : MatchConfidence.low;
      return MatchResult(title: bestLevTitle, confidence: confidence);
    }

    return null;
  }

  /// Standard Levenshtein edit distance.
  static int levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    // Use two-row rolling array (O(min(m,n)) space).
    if (a.length < b.length) {
      final tmp = a;
      a = b;
      b = tmp;
    }

    var prev = List<int>.generate(b.length + 1, (i) => i);
    var curr = List<int>.filled(b.length + 1, 0);

    for (int i = 1; i <= a.length; i++) {
      curr[0] = i;
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        curr[j] = _min3(curr[j - 1] + 1, prev[j] + 1, prev[j - 1] + cost);
      }
      final swap = prev;
      prev = curr;
      curr = swap;
    }

    return prev[b.length];
  }

  static String _normalise(String s) =>
      s.toLowerCase().trim().replaceAll(RegExp(r'[^\w\s]'), '');

  static String _stripArticles(String s) =>
      s.replaceAll(RegExp(r'\b(a|an|the|my|our)\b\s*'), '').trim();

  static List<String> _words(String s) =>
      s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

  static double _wordOverlap(List<String> a, List<String> b) {
    if (a.isEmpty || b.isEmpty) return 0;
    final setA = a.toSet();
    final setB = b.toSet();
    final intersection = setA.intersection(setB).length;
    final union = setA.union(setB).length;
    return union == 0 ? 0 : intersection / union;
  }

  static int _min3(int a, int b, int c) =>
      a < b ? (a < c ? a : c) : (b < c ? b : c);
}

enum MatchConfidence {
  exact,
  high,
  low,
}

class MatchResult {
  final String title;
  final MatchConfidence confidence;

  const MatchResult({required this.title, required this.confidence});

  @override
  String toString() => 'MatchResult($title, $confidence)';
}
