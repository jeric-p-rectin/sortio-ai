import '../safety/validator.dart';

/// Builds file names from a template, e.g. the default
/// `{date}_{issuer}_{type}` → `2026-03_Meralco_Bill.pdf`.
/// Missing parts are dropped along with their separator.
class NameBuilder {
  static const defaultTemplate = '{date}_{issuer}_{type}';
  static final _token = RegExp(r'\{(date|issuer|type)\}');

  final String template;

  const NameBuilder({this.template = defaultTemplate});

  /// Returns null if the result is not a valid file name.
  String? build({
    String? date,
    String? issuer,
    required String type,
    required String extension,
  }) {
    final values = {'date': date, 'issuer': issuer, 'type': type};

    // Split into literal / token parts: "{date}_{issuer}" → [token, "_", token].
    final parts = <(bool isToken, String text)>[];
    var last = 0;
    for (final m in _token.allMatches(template)) {
      if (m.start > last) parts.add((false, template.substring(last, m.start)));
      parts.add((true, m[1]!));
      last = m.end;
    }
    if (last < template.length) parts.add((false, template.substring(last)));

    // Drop empty tokens together with the separator before (or after) them.
    for (var i = 0; i < parts.length; i++) {
      final (isToken, key) = parts[i];
      if (!isToken || (values[key]?.isNotEmpty ?? false)) continue;
      if (i > 0 && !parts[i - 1].$1) {
        parts.removeRange(i - 1, i + 1);
        i -= 2;
      } else if (i + 1 < parts.length && !parts[i + 1].$1) {
        parts.removeRange(i, i + 2);
        i -= 1;
      } else {
        parts.removeAt(i);
        i -= 1;
      }
    }

    final stem = parts
        .map((part) => part.$1 ? values[part.$2]! : part.$2)
        .join()
        .replaceAll(RegExp(r'^[_\- ]+|[_\- ]+$'), '');
    if (stem.isEmpty) return null;
    final name = '$stem${extension.toLowerCase()}';
    return Validator.checkFileName(name) == null ? name : null;
  }
}
