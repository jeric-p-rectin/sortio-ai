/// What Sortio can tell about a document from its OCR text, without AI:
/// the amount to pay ("Magic extract") and whether it holds sensitive data.
class ContentInsights {
  /// e.g. "Total Amount Due:" → label "Total:", value "₱3,482.15".
  final String? amountLabel;
  final String? amountValue;

  /// e.g. "Contains Account Number". Null when nothing sensitive was found.
  final String? sensitiveBadge;

  const ContentInsights({this.amountLabel, this.amountValue, this.sensitiveBadge});

  bool get isSensitive => sensitiveBadge != null;

  static final _amount = RegExp(
    r'(total\s+amount\s+due|amount\s+due|total\s+due|grand\s+total|net\s+pay|total)'
    r'\s*[:\-]?\s*(?:php|₱|p)?\s*([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{2})|[0-9]+\.[0-9]{2})',
    caseSensitive: false,
  );

  // Most specific first: the first match decides the badge.
  static final _sensitive = <(RegExp, String)>[
    (RegExp(r'\b(TIN|tax identification)\b[\s:#no.]*\d{3}[- ]?\d{3}[- ]?\d{3}', caseSensitive: false),
        'Contains TIN'),
    (RegExp(r'\b(SSS|GSIS|PhilHealth|Pag-?IBIG|UMID|passport|driver.?s license|PhilSys|national id)\b',
            caseSensitive: false),
        'Contains ID Number'),
    (RegExp(r'\b(account|acct|card)\s*(no|number|#)\.?\s*[:#]?\s*[0-9][0-9\- ]{5,}', caseSensitive: false),
        'Contains Account Number'),
    (RegExp(r'\b(payslip|net pay|basic pay|salary)\b', caseSensitive: false),
        'Contains Salary Info'),
  ];

  factory ContentInsights.fromText(String text) {
    String? label;
    String? value;
    // Prefer the most specific label ("Total Amount Due" over "Total").
    RegExpMatch? best;
    for (final m in _amount.allMatches(text)) {
      if (best == null || m[1]!.length > best[1]!.length) best = m;
    }
    if (best != null) {
      final raw = best[1]!.toLowerCase();
      label = raw.contains('net pay') ? 'Net pay:' : raw.contains('due') ? 'Amount due:' : 'Total:';
      value = '₱${best[2]}';
    }

    String? badge;
    for (final (pattern, name) in _sensitive) {
      if (pattern.hasMatch(text)) {
        badge = name;
        break;
      }
    }
    return ContentInsights(amountLabel: label, amountValue: value, sensitiveBadge: badge);
  }
}
