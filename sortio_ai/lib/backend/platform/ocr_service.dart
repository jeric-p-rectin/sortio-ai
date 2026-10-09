import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as p;
import 'package:pdfx/pdfx.dart';

/// On-device OCR: ML Kit text recognition (bundled model, works offline).
/// PDFs are rendered to an image first (page 1 is enough for the issuer,
/// date and totals).
class OcrService {
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);
  final String tempDir;

  OcrService({required this.tempDir});

  static const _images = {'.jpg', '.jpeg', '.png', '.webp', '.bmp', '.heic'};

  /// Returns the recognized text, or '' when there is none.
  Future<String> read(String path) async {
    final ext = p.extension(path).toLowerCase();
    if (ext == '.pdf') return _readPdf(path);
    if (_images.contains(ext)) return _readImage(path);
    return '';
  }

  Future<String> _readImage(String path) async {
    final result = await _recognizer.processImage(InputImage.fromFilePath(path));
    return result.text;
  }

  Future<String> _readPdf(String path) async {
    final doc = await PdfDocument.openFile(path);
    File? rendered;
    try {
      final page = await doc.getPage(1);
      try {
        // ~2x scale keeps small print readable for OCR.
        final image = await page.render(
          width: page.width * 2,
          height: page.height * 2,
          format: PdfPageImageFormat.png,
          backgroundColor: '#FFFFFF',
        );
        if (image == null) return '';
        rendered = File(p.join(
            tempDir, 'sortio_ocr_${DateTime.now().microsecondsSinceEpoch}.png'));
        await rendered.writeAsBytes(image.bytes, flush: true);
      } finally {
        await page.close();
      }
      return await _readImage(rendered.path);
    } finally {
      await doc.close();
      if (rendered != null && rendered.existsSync()) await rendered.delete();
    }
  }

  Future<void> close() => _recognizer.close();
}
