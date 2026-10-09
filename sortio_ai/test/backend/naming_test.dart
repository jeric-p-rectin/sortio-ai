import 'package:sortio_ai/backend/sortio_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

const meralco =
    'MANILA ELECTRIC COMPANY (MERALCO) STATEMENT OF ACCOUNT Account No. '
    '1234567890 Billing Period: Feb 14 2026 - Mar 14 2026 Bill Date: March 16, '
    '2026 Total Amount Due: PHP 3,482.15 Due Date: March 26, 2026';
const sevenEleven =
    'OFFICIAL RECEIPT 7-Eleven Store #4521 Katipunan Ave Quezon City '
    '02/03/2026 21:14 Nescafe 3in1 x2 46.00 Skyflakes 12.00 TOTAL 58.00';
const payslip =
    'PAYSLIP Employee: Juan Dela Cruz Pay Period: January 1-15, 2026 '
    'Basic Pay 15,000.00 SSS 581.30 Net Pay 13,543.70 Acme Solutions Inc.';

void main() {
  final now = DateTime(2026, 10, 10);

  group('DateExtractor', () {
    final dates = DateExtractor();

    test('prefers the labeled bill date over period and due dates', () {
      final d = dates.extract(meralco, now: now)!;
      expect(d.yearMonth, '2026-03');
      expect(d.day, 16);
      expect(d.confidence, greaterThanOrEqualTo(0.9));
    });

    test('numeric dates are month-first (PH format)', () {
      expect(dates.extract(sevenEleven, now: now)!.yearMonth, '2026-02');
      expect(dates.extract('Date: 25/03/2026', now: now)!.yearMonth, '2026-03');
    });

    test('day ranges, ISO, day-first and Tagalog months', () {
      expect(dates.extract(payslip, now: now)!.yearMonth, '2026-01');
      expect(dates.extract('Issued 2025-11-30', now: now)!.yearMonth, '2025-11');
      expect(dates.extract('dated 5 August 2025', now: now)!.yearMonth, '2025-08');
      expect(dates.extract('Petsa: Marso 3, 2026', now: now)!.yearMonth, '2026-03');
      expect(dates.extract('Statement for June 2026', now: now)!.yearMonth, '2026-06');
    });

    test('ignores impossible dates and text without dates', () {
      expect(dates.extract('Total 58.00 change 42.00', now: now), isNull);
      expect(dates.extract('ref 13/45/2026', now: now), isNull);
      expect(dates.extract('valid until 2099-01-01', now: now), isNull);
    });
  });

  group('IssuerCleaner', () {
    final c = IssuerCleaner();

    test('cleans model output into short brand names', () {
      expect(c.clean('MANILA ELECTRIC COMPANY (MERALCO)'), 'Meralco');
      expect(c.clean('MERALCO'), 'Meralco');
      expect(c.clean('Acme Solutions Inc.'), 'Acme-Solutions');
      expect(c.clean('ACME SOLUTIONS INC.'), 'Acme-Solutions');
      expect(c.clean('MERCURY DRUG CORPORATION'), 'Mercury-Drug');
      expect(c.clean('BDO'), 'BDO');
      expect(c.clean('7-Eleven Store #4521'), '7-Eleven');
      expect(c.clean('PLDT'), 'PLDT');
      expect(c.clean('GCash'), 'GCash');
      expect(c.clean('The Foo Co., Ltd.'), 'Foo');
    });

    test('unknown or empty issuer becomes null', () {
      expect(c.clean(null), isNull);
      expect(c.clean('  '), isNull);
      expect(c.clean('Unknown'), isNull);
    });
  });

  group('NameBuilder', () {
    const b = NameBuilder();

    test('default template', () {
      expect(
          b.build(date: '2026-03', issuer: 'Meralco', type: 'Bill', extension: '.PDF'),
          '2026-03_Meralco_Bill.pdf');
    });

    test('drops missing parts cleanly', () {
      expect(b.build(issuer: 'Meralco', type: 'Bill', extension: '.pdf'),
          'Meralco_Bill.pdf');
      expect(b.build(date: '2026-03', type: 'Receipt', extension: '.jpg'),
          '2026-03_Receipt.jpg');
    });

    test('custom template', () {
      const custom = NameBuilder(template: '{type} - {issuer} ({date})');
      expect(
          custom.build(date: '2026-03', issuer: 'BDO', type: 'Statement', extension: '.pdf'),
          'Statement - BDO (2026-03).pdf');
    });
  });

  group('RenameService', () {
    test('combines regex date, model issuer/type and cleanup', () async {
      final llm = FakeLlm({'issuer': 'MANILA ELECTRIC COMPANY (MERALCO)', 'doc_type': 'Bill'});
      final r = (await RenameService(llm)
          .propose(fileName: 'IMG_2043.pdf', ocrText: meralco))!;
      expect(r.newName, '2026-03_Meralco_Statement.pdf');
      expect(r.reason, 'Meralco statement from March 2026');
      expect(r.confidence, greaterThan(0.9));
      // Only the short excerpt goes to the model.
      expect(llm.lastUser, isNotNull);
    });

    test('prefers the brand printed in parentheses after the legal name', () async {
      final llm = FakeLlm({'issuer': 'MANILA ELECTRIC COMPANY', 'doc_type': 'Statement'});
      final r = (await RenameService(llm)
          .propose(fileName: 'IMG_2043.pdf', ocrText: meralco))!;
      expect(r.newName, '2026-03_Meralco_Statement.pdf');
    });

    test('a printed heading decides the type over the model', () async {
      final llm = FakeLlm({'issuer': '7-Eleven', 'doc_type': 'Bill'});
      final r = (await RenameService(llm)
          .propose(fileName: 'IMG_1.jpg', ocrText: sevenEleven))!;
      expect(r.newName, '2026-02_7-Eleven_Receipt.jpg');
    });

    test('falls back to the file date and to "Document"', () async {
      final llm = FakeLlm({'issuer': 'BDO', 'doc_type': 'something weird'});
      final r = (await RenameService(llm).propose(
        fileName: 'scan.jpg',
        ocrText: 'BDO Unibank account summary for your reference only',
        modified: DateTime(2026, 4, 2),
      ))!;
      expect(r.newName, '2026-04_BDO_Document.jpg');
      expect(r.confidence, lessThan(0.5));
    });

    test('returns null when there is nothing to go on', () async {
      final llm = FakeLlm({'issuer': 'unknown', 'doc_type': 'Other'});
      final service = RenameService(llm);
      expect(await service.propose(fileName: 'a.pdf', ocrText: 'hi'), isNull);
      expect(
          await service.propose(
              fileName: 'a.pdf', ocrText: 'some random text with no clues at all'),
          isNull);
    });

    test('long OCR text is cut before reaching the model', () async {
      final llm = FakeLlm({'issuer': 'Meralco', 'doc_type': 'Bill'});
      await RenameService(llm, maxChars: 100)
          .propose(fileName: 'a.pdf', ocrText: meralco * 20);
      expect(llm.lastUser!.length, 100);
    });
  });

  group('ContentInsights', () {
    test('extracts the amount to pay and flags sensitive data', () {
      final bill = ContentInsights.fromText(meralco);
      expect(bill.amountLabel, 'Amount due:');
      expect(bill.amountValue, '₱3,482.15');
      expect(bill.sensitiveBadge, 'Contains Account Number');

      final receipt = ContentInsights.fromText(sevenEleven);
      expect(receipt.amountValue, '₱58.00');
      expect(receipt.isSensitive, isFalse);

      final pay = ContentInsights.fromText(payslip);
      expect(pay.amountLabel, 'Net pay:');
      expect(pay.amountValue, '₱13,543.70');
      expect(pay.sensitiveBadge, 'Contains ID Number'); // SSS
    });

    test('nothing found', () {
      final none = ContentInsights.fromText('Meeting notes for Monday');
      expect(none.amountValue, isNull);
      expect(none.sensitiveBadge, isNull);
    });
  });

  group('jsonSchemaToGbnf', () {
    test('builds a grammar with keys in order and enum alternatives', () {
      final g = jsonSchemaToGbnf(classifySchema);
      expect(g, contains(r'root ::= "{" ws "\"issuer\"" ws ":" ws v0 ws "," ws "\"doc_type\"" ws ":" ws v1 ws "}"'));
      expect(g, contains('v0 ::= string'));
      expect(g, contains(r'"\"Invoice\"" | "\"Bill\""'));
    });
  });

  test('parseJsonObject tolerates think blocks and stray text', () {
    expect(parseJsonObject('<think>\nhmm\n</think>\n{"a": 1}'), {'a': 1});
    expect(parseJsonObject('Sure! {"a": {"b": 2}} done'), {'a': {'b': 2}});
    expect(() => parseJsonObject('no json'), throwsFormatException);
  });

  test('OllamaClient refuses non-local servers', () {
    expect(() => OllamaClient(baseUrl: 'http://example.com:11434'),
        throwsArgumentError);
    expect(OllamaClient(baseUrl: 'http://localhost:11434'), isA<OllamaClient>());
  });
}
