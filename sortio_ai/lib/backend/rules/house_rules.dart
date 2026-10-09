import '../safety/validator.dart';

/// One plain-words rule, e.g. "Always file Zoom receipts under Finance".
class HouseRule {
  /// Lower-case word stems that must all appear in the file name or the text
  /// inside the document ("zoom", "receipt").
  final List<String> keywords;

  /// Destination folder inside the allowed folder ("Finance", "Bills/Meralco").
  final String folder;

  /// The sentence the user typed, shown back as the suggestion's reason.
  final String source;

  const HouseRule({required this.keywords, required this.folder, required this.source});

  @override
  String toString() => 'HouseRule($keywords → $folder)';
}

/// The user's house rules from Settings, parsed without AI so they are
/// predictable. English and Tagalog phrasings are understood:
///   "Always file Zoom receipts under Finance"
///   "Put payslips in Work/Payslips"
///   "Ilagay ang mga resibo sa Finance"
class HouseRules {
  final List<HouseRule> rules;

  const HouseRules(this.rules);

  static const empty = HouseRules([]);

  bool get isEmpty => rules.isEmpty;

  static final _english = RegExp(
    r'^(?:please\s+)?(?:always\s+)?(?:file|put|move|save|keep|send|store|sort)\s+'
    r'(.+?)\s+(?:under|in|into|to|inside)\s+(?:the\s+|my\s+|a\s+)?(.+?)(?:\s+folder)?$',
    caseSensitive: false,
  );
  static final _tagalog = RegExp(
    r'^(?:pakis?\s+)?(?:lagi(?:ng)?\s+)?(?:ilagay|ilipat|itabi|i-?file)\s+'
    r'(.+?)\s+sa\s+(?:folder\s+na\s+)?(.+?)(?:\s+folder)?$',
    caseSensitive: false,
  );
  static const _fillers = {
    'all', 'my', 'the', 'a', 'an', 'any', 'every', 'of', 'files', 'file',
    'documents', 'ang', 'ng', 'mga', 'lahat', 'na', 'yung', 'iyong',
  };

  factory HouseRules.parse(String text) {
    final rules = <HouseRule>[];
    for (final raw in text.split(RegExp(r'[\n;.!]+'))) {
      final sentence = raw.trim();
      if (sentence.isEmpty) continue;
      final m = _english.firstMatch(sentence) ?? _tagalog.firstMatch(sentence);
      if (m == null) continue;
      final keywords = [
        for (final w in m[1]!.toLowerCase().split(RegExp(r'[^a-z0-9\-]+')))
          if (w.isNotEmpty && !_fillers.contains(w)) _stem(w),
      ];
      final folder = _cleanFolder(m[2]!);
      if (keywords.isEmpty || folder == null) continue;
      rules.add(HouseRule(keywords: keywords, folder: folder, source: sentence));
    }
    return HouseRules(rules);
  }

  /// The first rule whose keywords all appear in the name or document text.
  HouseRule? match(String fileName, [String? documentText]) {
    if (rules.isEmpty) return null;
    final haystack = '${fileName.toLowerCase()} ${(documentText ?? '').toLowerCase()}';
    for (final rule in rules) {
      if (rule.keywords.every(haystack.contains)) return rule;
    }
    return null;
  }

  /// "receipts" → "receipt", so singular and plural both match.
  static String _stem(String w) =>
      w.length > 3 && w.endsWith('s') && !w.endsWith('ss') ? w.substring(0, w.length - 1) : w;

  /// "Finance" / "Bills/Meralco" → safe relative folder, or null.
  static String? _cleanFolder(String raw) {
    final parts = [
      for (final part in raw.trim().split(RegExp(r'[\\/>]+')))
        if (part.trim().isNotEmpty) part.trim().replaceAll(RegExp(r'\s+'), ' '),
    ];
    if (parts.isEmpty || parts.length > 3) return null;
    for (final part in parts) {
      if (part == '..' || Validator.checkFileName(part) != null) return null;
    }
    return parts.join('/');
  }
}
