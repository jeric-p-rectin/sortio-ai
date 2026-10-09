import 'package:path/path.dart' as p;

import '../llm/llm_client.dart';
import '../llm/prompts.dart';
import 'date_extractor.dart';
import 'issuer_cleaner.dart';
import 'name_builder.dart';

/// A proposed name for a scanned document.
class RenameProposal {
  final String newName;
  final String? issuer;
  final String docType;
  final ExtractedDate? date;
  final double confidence;

  /// e.g. "Meralco bill from March 2026"
  final String reason;

  const RenameProposal({
    required this.newName,
    required this.issuer,
    required this.docType,
    required this.date,
    required this.confidence,
    required this.reason,
  });

  @override
  String toString() => 'RenameProposal($newName, conf: $confidence, "$reason")';
}

/// OCR text → `2026-03_Meralco_Bill.pdf`.
///
/// Split of work (based on testing Qwen3-0.6B vs 1.7B):
/// - date: regex ([DateExtractor]) — the models got dates wrong
/// - issuer + type: LLM, with a fixed list of types
/// - cleanup and naming: code ([IssuerCleaner], [NameBuilder])
class RenameService {
  final LlmClient _llm;
  final DateExtractor _dates;
  final IssuerCleaner _issuers;
  final NameBuilder names;

  /// OCR text sent to the model is cut to this many characters (~300
  /// tokens) — the header of a document has the issuer and type, and short
  /// prompts are what keep this fast on a phone.
  final int maxChars;

  RenameService(
    this._llm, {
    DateExtractor? dates,
    IssuerCleaner? issuers,
    this.names = const NameBuilder(),
    this.maxChars = 1200,
  })  : _dates = dates ?? DateExtractor(),
        _issuers = issuers ?? IssuerCleaner();

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December',
  ];

  /// "MANILA ELECTRIC COMPANY" + text "…COMPANY (MERALCO)…" → "MERALCO":
  /// documents often print the brand in parentheses after the legal name.
  static String? _preferAcronym(String? issuer, String text) {
    if (issuer == null || issuer.trim().length < 3) return issuer;
    final words = issuer
        .trim()
        .split(RegExp(r'\s+'))
        .map(RegExp.escape)
        .join(r'[\s,.]+');
    final m = RegExp('$words\\s*\\(([A-Za-z0-9&.\\- ]{2,15})\\)', caseSensitive: false)
        .firstMatch(text);
    return m == null ? issuer : m[1];
  }

  static final _headings = <(RegExp, String)>[
    (RegExp(r'\bofficial\s+receipt\b|\bsales\s+invoice\b(?!.*due)', caseSensitive: false), 'Receipt'),
    (RegExp(r'\bpay\s?slip\b|\bpay\s+stub\b', caseSensitive: false), 'Payslip'),
    (RegExp(r'\bstatement\s+of\s+account\b', caseSensitive: false), 'Statement'),
  ];

  /// "OFFICIAL RECEIPT" / "PAYSLIP" / "STATEMENT OF ACCOUNT" in the text
  /// decide the type outright.
  static String? _typeFromHeading(String text) {
    for (final (pattern, type) in _headings) {
      if (pattern.hasMatch(text)) return type;
    }
    return null;
  }

  /// Returns null when the text gives nothing useful to name the file by.
  /// Throws [LlmException] if the model fails.
  Future<RenameProposal?> propose({
    required String fileName,
    required String ocrText,
    DateTime? modified,
  }) async {
    final text = ocrText.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.length < 20) return null;
    final excerpt = text.length > maxChars ? text.substring(0, maxChars) : text;

    var date = _dates.extract(text);
    if (date == null && modified != null) {
      date = ExtractedDate(modified.year, modified.month,
          confidence: 0.5, source: 'file date');
    }

    final json = await _llm.completeJson(
      system: classifySystemPrompt,
      user: excerpt,
      schema: classifySchema,
    );
    final issuer =
        _issuers.clean(_preferAcronym(json['issuer'] as String?, text));
    final rawType = json['doc_type'] as String?;
    // A heading printed on the document beats the small model's guess.
    final docType =
        _typeFromHeading(text) ?? (docTypes.contains(rawType) ? rawType! : 'Other');
    if (issuer == null && docType == 'Other') return null;

    final newName = names.build(
      date: date?.yearMonth,
      issuer: issuer,
      type: docType == 'Other' ? 'Document' : docType,
      extension: p.extension(fileName),
    );
    if (newName == null) return null;

    var confidence = date?.confidence ?? 0.5;
    if (docType == 'Other') confidence *= 0.6;
    if (issuer == null) confidence *= 0.8;

    final what = [
      if (issuer != null) issuer.replaceAll('-', ' '),
      (docType == 'Other' ? 'document' : docType).toLowerCase(),
    ].join(' ');
    final when =
        date == null ? '' : ' from ${_monthNames[date.month - 1]} ${date.year}';

    return RenameProposal(
      newName: newName,
      issuer: issuer,
      docType: docType,
      date: date,
      confidence: double.parse(confidence.toStringAsFixed(2)),
      reason: '$what$when',
    );
  }
}
