import 'package:path/path.dart' as p;

/// Structured search filters. Built by [SearchQuery.parse] (no AI) today;
/// the LLM will later produce the same shape via [SearchQuery.fromJson],
/// e.g. "invoice from March" → {"keywords": ["invoice"], "month": 3}.
class SearchQuery {
  final List<String> keywords;
  final int? month;
  final int? year;

  const SearchQuery({this.keywords = const [], this.month, this.year});

  bool get isEmpty => keywords.isEmpty && month == null && year == null;

  factory SearchQuery.fromJson(Map<String, dynamic> json) => SearchQuery(
        keywords: [
          for (final k in (json['keywords'] as List<dynamic>? ?? const []))
            (k as String).toLowerCase()
        ],
        month: json['month'] as int?,
        year: json['year'] as int?,
      );

  Map<String, dynamic> toJson() =>
      {'keywords': keywords, 'month': month, 'year': year};

  static const _stopwords = {
    // English
    'a', 'an', 'the', 'from', 'of', 'in', 'on', 'for', 'to', 'my', 'that',
    'this', 'with', 'file', 'files', 'find', 'show', 'me', 'last', 'about',
    'please', 'pls', 'can', 'could', 'you', 'i', 'want', 'need', 'get', 'give',
    'where', 'is', 'are', 'search', 'look', 'open',
    // Tagalog / Taglish
    'yung', 'iyong', 'ang', 'ng', 'sa', 'mga', 'na', 'ko', 'kong', 'noong',
    'nung', 'para', 'hanapin', 'pakihanap', 'galing', 'paki', 'po', 'naman',
    'nasaan', 'asan', 'saan', 'hanap', 'pahanap',
  };

  static const _months = <String, int>{
    'january': 1, 'jan': 1, 'enero': 1,
    'february': 2, 'feb': 2, 'pebrero': 2,
    'march': 3, 'mar': 3, 'marso': 3,
    'april': 4, 'apr': 4, 'abril': 4,
    'may': 5, 'mayo': 5,
    'june': 6, 'jun': 6, 'hunyo': 6,
    'july': 7, 'jul': 7, 'hulyo': 7,
    'august': 8, 'aug': 8, 'agosto': 8,
    'september': 9, 'sep': 9, 'sept': 9, 'setyembre': 9,
    'october': 10, 'oct': 10, 'oktubre': 10,
    'november': 11, 'nov': 11, 'nobyembre': 11,
    'december': 12, 'dec': 12, 'disyembre': 12,
  };

  static const _monthNames = [
    'january', 'february', 'march', 'april', 'may', 'june',
    'july', 'august', 'september', 'october', 'november', 'december',
  ];

  static final _yearPattern = RegExp(r'^(19|20)\d\d$');

  /// Rule-based parse, used when the LLM is unavailable.
  factory SearchQuery.parse(String text) {
    final keywords = <String>[];
    int? month;
    int? year;
    for (final raw in text.toLowerCase().split(RegExp(r"[\s,.!?']+"))) {
      if (raw.isEmpty || _stopwords.contains(raw)) continue;
      if (_months.containsKey(raw)) {
        month = _months[raw];
      } else if (_yearPattern.hasMatch(raw)) {
        year = int.parse(raw);
      } else {
        keywords.add(raw);
      }
    }
    return SearchQuery(keywords: keywords, month: month, year: year);
  }

  /// Does a file match by name alone? Used when there is no index.
  /// Returns a human-readable reason, or null for no match.
  String? match(String path, DateTime modified) {
    if (isEmpty) return null;
    final name = p.basename(path).toLowerCase();
    for (final k in keywords) {
      if (!name.contains(k)) return null;
    }
    final dateReasons = matchDate(name, modified);
    if (dateReasons == null) return null;
    return [
      if (keywords.isNotEmpty) 'name has "${keywords.join(' ')}"',
      ...dateReasons,
    ].join(', ');
  }

  /// Month/year filter only. Matches, in order: the file name
  /// (e.g. 2026-03_Meralco_Invoice.pdf), the date printed inside the document
  /// ([documentDate], from OCR), then the file's modified date.
  /// Returns the reasons (empty when no date filter), or null for no match.
  List<String>? matchDate(String fileName, DateTime modified, {DateTime? documentDate}) {
    final name = fileName.toLowerCase();
    final reasons = <String>[];

    if (month != null) {
      final mm = month!.toString().padLeft(2, '0');
      final full = _monthNames[month! - 1];
      final inName = name.contains(full) ||
          name.contains(full.substring(0, 3)) ||
          RegExp('(^|[^0-9])(19|20)\\d\\d[-_.]?$mm([^0-9]|\$)').hasMatch(name);
      if (inName) {
        reasons.add('dated ${_cap(full)} in name');
      } else if (documentDate != null && documentDate.month == month) {
        reasons.add('document dated ${_cap(full)}');
      } else if (modified.month == month) {
        reasons.add('modified in ${_cap(full)}');
      } else {
        return null;
      }
    }

    if (year != null) {
      if (name.contains('$year')) {
        reasons.add('$year in name');
      } else if (documentDate != null && documentDate.year == year) {
        reasons.add('document dated $year');
      } else if (modified.year == year) {
        reasons.add('modified in $year');
      } else {
        return null;
      }
    }
    return reasons;
  }

  static String _cap(String s) => s[0].toUpperCase() + s.substring(1);
}
