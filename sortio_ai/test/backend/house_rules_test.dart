import 'package:flutter_test/flutter_test.dart';
import 'package:sortio_ai/backend/sortio_core.dart';

void main() {
  group('HouseRules.parse', () {
    test('English phrasings', () {
      final r = HouseRules.parse(
        'Always file Zoom receipts under Finance.\n'
        'Put payslips in Work/Payslips\n'
        'move my Meralco bills into the Bills folder',
      ).rules;
      expect(r, hasLength(3));
      expect(r[0].keywords, ['zoom', 'receipt']);
      expect(r[0].folder, 'Finance');
      expect(r[1].keywords, ['payslip']);
      expect(r[1].folder, 'Work/Payslips');
      expect(r[2].keywords, ['meralco', 'bill']);
      expect(r[2].folder, 'Bills');
    });

    test('Tagalog phrasing', () {
      final r = HouseRules.parse('Ilagay ang mga resibo sa Finance').rules;
      expect(r.single.keywords, ['resibo']);
      expect(r.single.folder, 'Finance');
    });

    test('ignores chatter and unsafe folders', () {
      expect(HouseRules.parse('Be careful with my IDs').isEmpty, isTrue);
      expect(HouseRules.parse('put receipts in ../outside').isEmpty, isTrue);
      expect(HouseRules.parse('put receipts in Bad:Name').isEmpty, isTrue);
      expect(HouseRules.parse('').isEmpty, isTrue);
    });
  });

  group('HouseRules.match', () {
    final rules = HouseRules.parse('Always file Zoom receipts under Finance');

    test('matches the file name or the text inside the document', () {
      expect(rules.match('Zoom_Receipt_2026-03.pdf'), isNotNull);
      expect(rules.match('IMG_2043.pdf', 'ZOOM VIDEO COMMUNICATIONS Receipt #123'), isNotNull);
    });

    test('needs every keyword', () {
      expect(rules.match('zoom_meeting_notes.pdf'), isNull);
      expect(rules.match('7eleven_receipt.pdf'), isNull);
    });
  });
}
