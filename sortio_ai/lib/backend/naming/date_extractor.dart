/// A document date found in OCR text.
class ExtractedDate {
  final int year;
  final int month;
  final int? day;

  /// 0.0–1.0. Higher when the date sits next to a label like "Bill Date".
  final double confidence;

  /// The matched text, for debugging/reasons.
  final String source;

  const ExtractedDate(this.year, this.month,
      {this.day, this.confidence = 0.8, this.source = ''});

  /// "2026-03"
  String get yearMonth => '$year-${month.toString().padLeft(2, '0')}';

  @override
  String toString() => 'ExtractedDate($yearMonth${day != null ? '-$day' : ''}, '
      'conf: $confidence, "$source")';
}

/// Finds the document's own date in OCR text with regexes — more reliable
/// than a small LLM. When several dates appear (billing period, due date,
/// bill date) it prefers the one labeled as the document's date.
class DateExtractor {
  static const monthNumbers = <String, int>{
    'january': 1, 'jan': 1, 'enero': 1,
    'february': 2, 'feb': 2, 'pebrero': 2,
    'march': 3, 'mar': 3, 'marso': 3,
    'april': 4, 'apr': 4, 'abril': 4,
    'may': 5, 'mayo': 5,
    'june': 6, 'jun': 6, 'hunyo': 6,
    'july': 7, 'jul': 7, 'hulyo': 7,
    'august': 8, 'aug': 8, 'agosto': 8,
    'september': 9, 'sept': 9, 'sep': 9, 'setyembre': 9,
    'october': 10, 'oct': 10, 'oktubre': 10,
    'november': 11, 'nov': 11, 'nobyembre': 11,
    'december': 12, 'dec': 12, 'disyembre': 12,
  };

  static final String _monthAlt = (monthNumbers.keys.toList()
        ..sort((a, b) => b.length.compareTo(a.length)))
      .join('|');

  // Labels that mark the document's own date vs. other dates.
  static final _positive = RegExp(
      r'\b(date|dated|bill|invoice|statement|receipt|issued|petsa|or no)\b');
  static final _negative = RegExp(
      r'\b(due|period|from|until|to|birth|expir\w*|valid|coverage|next|deadline)\b');

  late final List<(RegExp, _Parser)> _patterns = [
    // 2026-03-16, 2026/03/16
    (
      RegExp(r'\b((?:19|20)\d\d)[-/.](\d{1,2})[-/.](\d{1,2})\b'),
      (m) => (int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!)),
    ),
    // March 16, 2026 · Mar 14 2026 · January 1-15, 2026
    (
      RegExp(
        '\\b($_monthAlt)\\.?\\s+(\\d{1,2})(?:st|nd|rd|th)?'
        '(?:\\s*[-–]\\s*\\d{1,2})?,?\\s+((?:19|20)\\d\\d)\\b',
        caseSensitive: false,
      ),
      (m) => (int.parse(m[3]!), monthNumbers[m[1]!.toLowerCase()]!, int.parse(m[2]!)),
    ),
    // 16 March 2026
    (
      RegExp(
        '\\b(\\d{1,2})\\s+($_monthAlt)\\.?,?\\s+((?:19|20)\\d\\d)\\b',
        caseSensitive: false,
      ),
      (m) => (int.parse(m[3]!), monthNumbers[m[2]!.toLowerCase()]!, int.parse(m[1]!)),
    ),
    // 02/03/2026 → MM/DD (Philippine/US order) unless the first part > 12.
    (
      RegExp(r'\b(\d{1,2})[/.-](\d{1,2})[/.-]((?:19|20)\d\d|\d\d)\b'),
      (m) {
        var a = int.parse(m[1]!), b = int.parse(m[2]!);
        var y = int.parse(m[3]!);
        if (y < 100) y += 2000;
        if (a > 12 && b <= 12) (a, b) = (b, a);
        return (y, a, b);
      },
    ),
    // March 2026
    (
      RegExp('\\b($_monthAlt)\\.?,?\\s+((?:19|20)\\d\\d)\\b', caseSensitive: false),
      (m) => (int.parse(m[2]!), monthNumbers[m[1]!.toLowerCase()]!, null),
    ),
  ];

  ExtractedDate? extract(String text, {DateTime? now}) {
    final maxYear = (now ?? DateTime.now()).year + 1;
    final found = <_Found>[];

    for (final (regex, parse) in _patterns) {
      for (final m in regex.allMatches(text)) {
        // Skip spans already claimed by a more specific pattern.
        if (found.any((f) => m.start < f.end && f.start < m.end)) continue;
        final (y, mo, d) = parse(m);
        if (y < 1990 || y > maxYear || mo < 1 || mo > 12) continue;
        if (d != null && (d < 1 || d > 31)) continue;
        found.add(_Found(m.start, m.end, y, mo, d, m[0]!));
      }
    }
    if (found.isEmpty) return null;
    found.sort((a, b) => a.start.compareTo(b.start));

    _Found? best;
    var bestScore = -1 << 30;
    for (var i = 0; i < found.length; i++) {
      final f = found[i];
      // Only look at the label text right before this date, not past the
      // previous date (so "Due Date" doesn't leak onto the next date).
      final windowStart = [
        f.start - 30,
        if (i > 0) found[i - 1].end,
        0,
      ].reduce((a, b) => a > b ? a : b);
      final label = text.substring(windowStart, f.start).toLowerCase();
      var score = 0;
      if (_positive.hasMatch(label)) score += 2;
      if (_negative.hasMatch(label)) score -= 2;
      if (f.day != null) score += 1;
      f.score = score;
      if (score > bestScore) {
        best = f;
        bestScore = score;
      }
    }

    final b = best!;
    final confidence = b.score >= 3
        ? 0.95
        : b.score >= 1
            ? 0.85
            : 0.65;
    return ExtractedDate(b.year, b.month,
        day: b.day, confidence: confidence, source: b.text);
  }
}

typedef _Parser = (int, int, int?) Function(RegExpMatch m);

class _Found {
  final int start, end, year, month;
  final int? day;
  final String text;
  int score = 0;
  _Found(this.start, this.end, this.year, this.month, this.day, this.text);
}
