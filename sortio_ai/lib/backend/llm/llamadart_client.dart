import 'dart:async';

import 'package:llamadart/llamadart.dart';

import 'json_grammar.dart';
import 'llm_client.dart';
import 'ollama_client.dart' show parseJsonObject;

/// Runs a GGUF model (Qwen3-0.6B) fully on the device through llama.cpp
/// (`llamadart`). Output is constrained by a GBNF grammar built from the JSON
/// schema, so it is always valid JSON with the expected keys.
class LlamaDartClient implements LlmClient {
  final String modelPath;
  final int maxTokens;
  LlamaEngine? _engine;
  Future<LlamaEngine>? _loading;
  final Map<Map<String, dynamic>, String> _grammars = {};

  LlamaDartClient(this.modelPath, {this.maxTokens = 96});

  bool get isLoaded => _engine != null;

  /// Loads the model once; later calls reuse it.
  Future<LlamaEngine> load() => _loading ??= () async {
        try {
          final engine = await LlamaEngine.load(
            LlamaModel(ModelSource.parse(modelPath)),
          );
          _engine = engine;
          return engine;
        } on Object catch (e) {
          _loading = null;
          throw LlmException('Could not load the on-device model: $e');
        }
      }();

  /// llama.cpp serves one request at a time: AI naming and chat routing
  /// queue up here instead of overlapping.
  Future<void> _queue = Future<void>.value();

  @override
  Future<Map<String, dynamic>> completeJson({
    required String system,
    required String user,
    required Map<String, dynamic> schema,
  }) {
    final result = _queue.then((_) => _complete(system, user, schema));
    _queue = result.then((_) {}, onError: (Object _) {});
    return result;
  }

  Future<Map<String, dynamic>> _complete(
    String system,
    String user,
    Map<String, dynamic> schema,
  ) async {
    final engine = await load();
    final grammar = _grammars[schema] ??= jsonSchemaToGbnf(schema);
    try {
      final text = await engine
          .create(
            [
              LlamaChatMessage.fromText(role: LlamaChatRole.system, text: system),
              // Qwen3 soft switch: answer directly, no reasoning block.
              LlamaChatMessage.fromText(role: LlamaChatRole.user, text: '$user /no_think'),
            ],
            params: GenerationParams(
              maxTokens: maxTokens,
              temp: 0,
              topK: 1,
              grammar: grammar,
            ),
          )
          .text();
      return parseJsonObject(text);
    } on FormatException catch (e) {
      throw LlmException('Model returned invalid JSON: ${e.message}');
    } on LlmException {
      rethrow;
    } on Object catch (e) {
      throw LlmException('On-device model failed: $e');
    }
  }

  Future<void> dispose() async {
    final engine = _engine;
    _engine = null;
    _loading = null;
    await engine?.dispose();
  }
}
