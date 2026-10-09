/// Anything that can answer a prompt with JSON matching a schema.
///
/// - `OllamaClient`: laptop development and the desktop fallback.
/// - The Flutter app will provide a llama.cpp implementation for the phone.
abstract class LlmClient {
  /// Returns the parsed JSON object. Throws [LlmException] on failure.
  Future<Map<String, dynamic>> completeJson({
    required String system,
    required String user,
    required Map<String, dynamic> schema,
  });
}

class LlmException implements Exception {
  final String message;
  const LlmException(this.message);

  @override
  String toString() => 'LlmException: $message';
}
