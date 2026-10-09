import 'package:sortio_ai/backend/sortio_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RulesEngine', () {
    final rules = RulesEngine();

    test('classifies by extension', () {
      expect(rules.classify('report.PDF')!.category, 'Documents');
      expect(rules.classify('photo.jpg')!.category, 'Images');
      expect(rules.classify('setup.apk')!.category, 'Installers');
    });

    test('executables are suggested for quarantine', () {
      final exe = rules.classify('setup_v2.exe')!;
      expect(exe.quarantine, isTrue);
      expect(exe.category, RulesEngine.quarantineCategory);
      expect(exe.reason, contains('Unrecognized executable'));
    });

    test('screenshots and scans', () {
      expect(rules.classify('Screenshot_20260310-101522.png')!.category,
          'Screenshots');
      final scan = rules.classify('IMG_2043.pdf')!;
      expect(scan.category, 'Scans');
      expect(scan.needsRename, isTrue);
      expect(rules.classify('CamScanner 03-14-2026.jpg')!.category, 'Scans');
      // A camera photo is not a scan.
      expect(rules.classify('IMG_2043.jpg')!.category, 'Images');
    });

    test('ignores hidden, partial and unknown files', () {
      expect(rules.classify('.nomedia'), isNull);
      expect(rules.classify('movie.mp4.crdownload'), isNull);
      expect(rules.classify('weird.xyz'), isNull);
    });
  });
}
