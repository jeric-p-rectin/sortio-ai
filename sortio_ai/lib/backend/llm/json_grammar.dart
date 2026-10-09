import 'dart:convert';

/// Converts the small JSON-schema subset used in `prompts.dart` into a GBNF
/// grammar for llama.cpp, so the on-device model can only produce valid JSON
/// with exactly the expected keys.
///
/// Supported: `object` with `properties` (emitted in `required` order, then
/// the rest), `string` (optionally with `enum`), `integer`, `number`,
/// `boolean`.
String jsonSchemaToGbnf(Map<String, dynamic> schema, {int maxStringLength = 60}) {
  final props = (schema['properties'] as Map).cast<String, dynamic>();
  final required = [
    for (final k in (schema['required'] as List? ?? const [])) k as String,
  ];
  final keys = [...required, ...props.keys.where((k) => !required.contains(k))];

  final rules = <String>[];
  final members = <String>[];
  for (var i = 0; i < keys.length; i++) {
    final key = keys[i];
    final prop = (props[key] as Map).cast<String, dynamic>();
    final ruleName = 'v$i';
    rules.add('$ruleName ::= ${_valueRule(prop)}');
    members.add('${_literal(jsonEncode(key))} ws ":" ws $ruleName');
  }

  return [
    'root ::= "{" ws ${members.join(' ws "," ws ')} ws "}"',
    ...rules,
    'string ::= "\\"" char{0,$maxStringLength} "\\""',
    r'char ::= [^"\\\x00-\x1F] | "\\" ["\\/bfnrt]',
    'integer ::= "-"? [0-9]{1,10}',
    'number ::= "-"? [0-9]{1,10} ("." [0-9]{1,6})?',
    'boolean ::= "true" | "false"',
    'ws ::= [ \\t\\n]{0,2}',
  ].join('\n');
}

String _valueRule(Map<String, dynamic> prop) {
  final values = prop['enum'] as List?;
  if (values != null) {
    return values.map((v) => _literal(jsonEncode(v))).join(' | ');
  }
  return switch (prop['type']) {
    'integer' => 'integer',
    'number' => 'number',
    'boolean' => 'boolean',
    _ => 'string',
  };
}

/// A GBNF string literal for [text] (escapes quotes and backslashes).
String _literal(String text) =>
    '"${text.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
