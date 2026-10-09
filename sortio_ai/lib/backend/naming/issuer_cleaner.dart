/// Turns whatever the LLM returns as the issuer into a short, file-name-safe
/// brand: "MANILA ELECTRIC COMPANY (MERALCO)" → "Meralco",
/// "Acme Solutions Inc." → "Acme-Solutions", "7-Eleven Store #4521" → "7-Eleven".
class IssuerCleaner {
  static const maxLength = 30;

  static final _parenthesized = RegExp(r'\(([A-Za-z0-9&.\- ]{2,20})\)');
  static final _branchTail =
      RegExp(r'\s*(\bstore\b|\bbranch\b|#|\bno\.|\bunit\b).*$', caseSensitive: false);
  static final _suffix = RegExp(
    r'[\s,]+(inc|incorporated|corp|corporation|co|company|ltd|limited|llc|plc)\.?$',
    caseSensitive: false,
  );
  static const _unknown = {'unknown', 'n/a', 'na', 'none', 'null', 'other', '-'};

  String? clean(String? raw) {
    if (raw == null) return null;
    var s = raw.trim();
    if (s.isEmpty || _unknown.contains(s.toLowerCase())) return null;

    final paren = _parenthesized.firstMatch(s);
    if (paren != null) s = paren[1]!;

    s = s.replaceFirst(_branchTail, '');
    s = s.replaceFirst(RegExp(r'^the\s+', caseSensitive: false), '');
    // Strip legal suffixes repeatedly ("Foo Co., Ltd.").
    for (var prev = ''; prev != s;) {
      prev = s;
      s = s.replaceFirst(_suffix, '').trim();
    }

    final words = s
        .split(RegExp(r'\s+'))
        .map((w) => w.replaceAll(RegExp(r'[^A-Za-z0-9\-]'), ''))
        .where((w) => w.isNotEmpty)
        .map(_caseWord)
        .toList();
    if (words.isEmpty) return null;

    var out = '';
    for (final w in words) {
      final next = out.isEmpty ? w : '$out-$w';
      if (next.length > maxLength) break;
      out = next;
    }
    if (out.isEmpty) out = words.first.substring(0, maxLength);
    return out.replaceAll(RegExp(r'-{2,}'), '-');
  }

  /// MERALCO → Meralco, DRUG → Drug, but keep acronyms (BDO, SSS, PLDT) and
  /// mixed case (GCash, 7-Eleven). An acronym is up to 3 letters, or a
  /// 4-letter word without vowels.
  static String _caseWord(String w) {
    final letters = w.replaceAll(RegExp(r'[^A-Za-z]'), '');
    if (letters.isEmpty) return w;
    final allUpper = letters == letters.toUpperCase();
    final allLower = letters == letters.toLowerCase();
    final acronym = letters.length <= 3 ||
        (letters.length == 4 && !RegExp('[AEIOU]').hasMatch(letters));
    if (allUpper && acronym) return w;
    if (allUpper || allLower) {
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }
    return w;
  }
}
