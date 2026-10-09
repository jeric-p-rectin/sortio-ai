// ignore_for_file: avoid_print
// Live check of the AI rename pipeline against a local Ollama server.
//   dart run tool/rename_demo.dart [model]
import 'package:sortio_ai/backend/sortio_core.dart';

const samples = {
  'IMG_2043.pdf':
      'MANILA ELECTRIC COMPANY (MERALCO) STATEMENT OF ACCOUNT Account No. 1234567890 '
          'Billing Period: Feb 14 2026 - Mar 14 2026 Bill Date: March 16, 2026 '
          'Total Amount Due: PHP 3,482.15 Due Date: March 26, 2026',
  'IMG_2044.jpg':
      'OFFICIAL RECEIPT 7-Eleven Store #4521 Katipunan Ave Quezon City 02/03/2026 21:14 '
          'Nescafe 3in1 x2 46.00 Skyflakes 12.00 TOTAL 58.00 CASH 100.00 CHANGE 42.00',
  'scan_0001.pdf':
      'PAYSLIP Employee: Juan Dela Cruz Pay Period: January 1-15, 2026 Basic Pay 15,000.00 '
          'SSS 581.30 PhilHealth 375.00 Net Pay 13,543.70 Acme Solutions Inc.',
  'DOC_0007.pdf':
      'BDO Unibank, Inc. STATEMENT OF ACCOUNT Statement Date: 2026-04-30 Savings Account '
          'Ending Balance PHP 52,310.44',
};

Future<void> main(List<String> args) async {
  final model = args.isEmpty ? 'qwen3:0.6b' : args.first;
  final llm = OllamaClient(model: model);
  final service = RenameService(llm);
  print('Model: $model');
  // Warm-up so model load time isn't counted.
  await llm.completeJson(system: 'Reply {"ok":true}', user: 'hi', schema: {'type': 'object'});
  for (final MapEntry(key: file, value: text) in samples.entries) {
    final sw = Stopwatch()..start();
    final r = await service.propose(fileName: file, ocrText: text);
    print('${(sw.elapsedMilliseconds / 1000).toStringAsFixed(1).padLeft(5)}s  '
        '${file.padRight(14)} → ${r?.newName}  (${r?.confidence}, "${r?.reason}")');
  }
  llm.close();
}
