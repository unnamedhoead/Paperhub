import 'package:flutter_test/flutter_test.dart';
import 'package:test/services/arxiv_service.dart';

void main() {
  group('ArxivService.extractArxivId', () {
    test('extracts plain 4-digit id', () {
      expect(ArxivService.extractArxivId('1234.5678'), '1234.5678');
    });

    test('extracts plain 5-digit id', () {
      expect(ArxivService.extractArxivId('1234.56789'), '1234.56789');
    });

    test('extracts versioned id', () {
      expect(ArxivService.extractArxivId('1234.5678v2'), '1234.5678v2');
    });

    test('strips arxiv: prefix (lowercase)', () {
      expect(ArxivService.extractArxivId('arxiv:1234.5678'), '1234.5678');
    });

    test('strips arXiv: prefix (mixed case)', () {
      expect(ArxivService.extractArxivId('arXiv:1234.5678'), '1234.5678');
    });

    test('extracts id from abs URL', () {
      expect(
        ArxivService.extractArxivId('https://arxiv.org/abs/1234.5678'),
        '1234.5678',
      );
    });

    test('extracts id from pdf URL (drops .pdf)', () {
      expect(
        ArxivService.extractArxivId('https://arxiv.org/pdf/1234.5678.pdf'),
        '1234.5678',
      );
    });

    test('trims surrounding whitespace', () {
      expect(ArxivService.extractArxivId('  1234.5678  '), '1234.5678');
    });

    test('returns null for empty input', () {
      expect(ArxivService.extractArxivId(''), isNull);
    });

    test('returns null for non-id text', () {
      expect(ArxivService.extractArxivId('not-an-arxiv-id'), isNull);
    });

    test('returns null for wrong digit count', () {
      expect(ArxivService.extractArxivId('123.456'), isNull);
    });
  });

  group('ArxivMetadata getters', () {
    test('authorsFormatted joins with comma', () {
      final m = ArxivMetadata(id: '1', title: 't', authors: ['Alice', 'Bob']);
      expect(m.authorsFormatted, 'Alice, Bob');
    });

    test('publishedDateFormatted pads month/day', () {
      final m = ArxivMetadata(
        id: '1',
        title: 't',
        authors: const [],
        publishedDate: DateTime(2023, 1, 5),
      );
      expect(m.publishedDateFormatted, '2023-01-05');
    });

    test('publishedDateFormatted is null when no date', () {
      final m = ArxivMetadata(id: '1', title: 't', authors: const []);
      expect(m.publishedDateFormatted, isNull);
    });

    test('yearFormatted prefers publishedDate year over year field', () {
      final m = ArxivMetadata(
        id: '1',
        title: 't',
        authors: const [],
        publishedDate: DateTime(2021, 6, 1),
        year: 1999,
      );
      expect(m.yearFormatted, 2021);
    });

    test('yearFormatted falls back to year field when no date', () {
      final m = ArxivMetadata(id: '1', title: 't', authors: const [], year: 2018);
      expect(m.yearFormatted, 2018);
    });
  });
}
