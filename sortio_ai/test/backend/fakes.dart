import 'package:sortio_ai/backend/sortio_core.dart';

/// Returns a fixed answer and remembers what it was asked.
class FakeLlm implements LlmClient {
  final Map<String, dynamic> answer;
  final bool fail;
  String? lastUser;
  int calls = 0;

  FakeLlm(this.answer, {this.fail = false});

  @override
  Future<Map<String, dynamic>> completeJson({
    required String system,
    required String user,
    required Map<String, dynamic> schema,
  }) async {
    calls++;
    lastUser = user;
    if (fail) throw const LlmException('fake failure');
    return answer;
  }
}
