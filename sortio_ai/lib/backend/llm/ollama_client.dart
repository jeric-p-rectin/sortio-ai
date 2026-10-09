import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'llm_client.dart';

/// Talks to a local Ollama server. Only loopback addresses are accepted, so
/// documents can never be sent off the device by misconfiguration.
class OllamaClient implements LlmClient {
  final String model;
  final Uri baseUrl;
  final Duration timeout;
  final int contextSize;
  final HttpClient _http = HttpClient();

  OllamaClient({
    this.model = 'qwen3:0.6b',
    String baseUrl = 'http://127.0.0.1:11434',
    this.timeout = const Duration(seconds: 90),
    this.contextSize = 2048,
  }) : baseUrl = Uri.parse(baseUrl) {
    const loopback = {'127.0.0.1', 'localhost', '::1', '[::1]'};
    if (!loopback.contains(this.baseUrl.host)) {
      throw ArgumentError.value(
          baseUrl, 'baseUrl', 'Only a local (loopback) Ollama server is allowed');
    }
  }

  @override
  Future<Map<String, dynamic>> completeJson({
    required String system,
    required String user,
    required Map<String, dynamic> schema,
  }) async {
    final body = jsonEncode({
      'model': model,
      'stream': false,
      'think': false,
      'format': schema,
      'options': {'temperature': 0, 'num_ctx': contextSize},
      'messages': [
        {'role': 'system', 'content': system},
        {'role': 'user', 'content': user},
      ],
    });

    try {
      final request = await _http.postUrl(baseUrl.resolve('/api/chat'));
      request.headers.contentType = ContentType.json;
      request.add(utf8.encode(body));
      final response = await request.close().timeout(timeout);
      final text = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw LlmException('Ollama returned ${response.statusCode}: $text');
      }
      final content =
          ((jsonDecode(text) as Map<String, dynamic>)['message'] as Map)['content']
              as String;
      return parseJsonObject(content);
    } on SocketException catch (e) {
      throw LlmException('Ollama is not running (${e.message})');
    } on TimeoutException {
      throw LlmException('Ollama timed out after ${timeout.inSeconds}s');
    } on FormatException catch (e) {
      throw LlmException('Model returned invalid JSON: ${e.message}');
    }
  }

  void close() => _http.close(force: true);
}

/// Parses the first JSON object in [content], ignoring any `<think>` block or
/// stray text around it.
Map<String, dynamic> parseJsonObject(String content) {
  final cleaned = content.replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '');
  final start = cleaned.indexOf('{');
  final end = cleaned.lastIndexOf('}');
  if (start < 0 || end < start) {
    throw const FormatException('No JSON object in model output');
  }
  return jsonDecode(cleaned.substring(start, end + 1)) as Map<String, dynamic>;
}
