import 'package:flutter_test/flutter_test.dart';
import 'package:test/models/browse_history_item.dart';

void main() {
  group('BrowseHistoryItem', () {
    test('toMap and fromMap roundtrip', () {
      final original = BrowseHistoryItem(
        postId: 'post-123',
        title: 'Test Title',
        timestamp: 1700000000000,
      );

      final map = original.toMap();
      final restored = BrowseHistoryItem.fromMap(map);

      expect(restored.postId, 'post-123');
      expect(restored.title, 'Test Title');
      expect(restored.timestamp, 1700000000000);
    });

    test('fromMap with missing fields uses defaults', () {
      final item = BrowseHistoryItem.fromMap({});

      expect(item.postId, '');
      expect(item.title, '');
      expect(item.timestamp, isNotNull); // defaults to current time
    });

    test('fromMap with numeric timestamp as int', () {
      final item = BrowseHistoryItem.fromMap({
        'postId': 'p1',
        'title': 'T',
        'timestamp': 42,
      });

      expect(item.timestamp, 42);
    });

    test('fromMap with numeric timestamp as double', () {
      final item = BrowseHistoryItem.fromMap({
        'postId': 'p1',
        'title': 'T',
        'timestamp': 42.0,
      });

      expect(item.timestamp, 42);
    });
  });
}
