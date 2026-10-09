import 'package:sortio_ai/backend/sortio_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SearchQuery', () {
    test('parses plain-language queries (English and Tagalog)', () {
      final q = SearchQuery.parse('that invoice from March');
      expect(q.keywords, ['invoice']);
      expect(q.month, 3);
      final t = SearchQuery.parse('yung resibo sa Marso 2026');
      expect(t.keywords, ['resibo']);
      expect(t.month, 3);
      expect(t.year, 2026);
    });

    test('LLM output shape is accepted', () {
      final q = SearchQuery.fromJson({'keywords': ['Invoice'], 'month': 3, 'year': null});
      expect(q.keywords, ['invoice']);
      expect(q.month, 3);
    });

    test('matchDate uses the name first, then the modified date', () {
      final q = SearchQuery.parse('march');
      expect(q.matchDate('2026-03_Meralco_Bill.pdf', DateTime(2026, 9)), isNotNull);
      expect(q.matchDate('bill.pdf', DateTime(2026, 3, 5)), isNotNull);
      expect(q.matchDate('bill.pdf', DateTime(2026, 4, 5)), isNull);
    });
  });
}
