import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test/utils/local_json_list_store.dart';

/// 用于测试的简单模型
class _TestItem {
  final String id;
  final String name;
  final int score;

  _TestItem({required this.id, required this.name, required this.score});

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'score': score};

  factory _TestItem.fromMap(Map<String, dynamic> map) => _TestItem(
        id: map['id']?.toString() ?? '',
        name: map['name']?.toString() ?? '',
        score: (map['score'] as num?)?.toInt() ?? 0,
      );
}

void main() {
  const storeKey = 'test_store';

  Future<LocalJsonListStore<_TestItem>> _createStore({
    int maxCount = 10,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return LocalJsonListStore<_TestItem>(
      prefs: prefs,
      key: storeKey,
      maxCount: maxCount,
      encode: (item) => item.toMap(),
      decode: (map) => _TestItem.fromMap(map),
      sortBy: (a, b) => b.score.compareTo(a.score),
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('LocalJsonListStore', () {
    test('getAll returns empty list when no data', () async {
      final store = await _createStore();
      final items = await store.getAll();
      expect(items, isEmpty);
    });

    test('add stores item and getAll returns it sorted', () async {
      final store = await _createStore();
      await store.add(_TestItem(id: '1', name: 'A', score: 10));
      await store.add(_TestItem(id: '2', name: 'B', score: 30));
      await store.add(_TestItem(id: '3', name: 'C', score: 20));

      final items = await store.getAll();
      expect(items.length, 3);
      // sorted by score descending
      expect(items[0].id, '2'); // score 30
      expect(items[1].id, '3'); // score 20
      expect(items[2].id, '1'); // score 10
    });

    test('add with isDuplicate deduplicates by custom predicate', () async {
      final store = await _createStore();
      await store.add(_TestItem(id: '1', name: 'A', score: 10));
      await store.add(_TestItem(id: '1', name: 'A-v2', score: 50),
          isDuplicate: (a, b) => a.id == b.id);

      final items = await store.getAll();
      expect(items.length, 1);
      expect(items[0].name, 'A-v2');
      expect(items[0].score, 50);
    });

    test('add enforces maxCount capacity', () async {
      final store = await _createStore(maxCount: 3);
      for (var i = 0; i < 5; i++) {
        await store.add(_TestItem(
            id: '$i', name: 'Item$i', score: i * 10));
      }

      final items = await store.getAll();
      expect(items.length, 3);
      // newest inserted first, so the last 3 added (2,3,4) should remain
      expect(items[0].id, '4');
      expect(items[1].id, '3');
      expect(items[2].id, '2');
    });

    test('removeWhere removes matching items', () async {
      final store = await _createStore();
      await store.add(_TestItem(id: '1', name: 'A', score: 10));
      await store.add(_TestItem(id: '2', name: 'B', score: 20));
      await store.add(_TestItem(id: '3', name: 'C', score: 30));

      await store.removeWhere((item) => item.id == '2');

      final items = await store.getAll();
      expect(items.length, 2);
      expect(items.any((e) => e.id == '2'), isFalse);
    });

    test('clear removes all items', () async {
      final store = await _createStore();
      await store.add(_TestItem(id: '1', name: 'A', score: 10));
      await store.add(_TestItem(id: '2', name: 'B', score: 20));

      await store.clear();

      final items = await store.getAll();
      expect(items, isEmpty);
    });

    test('setAll replaces all existing items', () async {
      final store = await _createStore();
      await store.add(_TestItem(id: '1', name: 'A', score: 10));

      await store.setAll([
        _TestItem(id: '2', name: 'B', score: 20),
        _TestItem(id: '3', name: 'C', score: 30),
      ]);

      final items = await store.getAll();
      expect(items.length, 2);
      expect(items.any((e) => e.id == '1'), isFalse);
      expect(items[0].id, '3'); // sorted by score desc
    });

    test('setAll caps to maxCount', () async {
      final store = await _createStore(maxCount: 2);
      await store.setAll([
        _TestItem(id: '1', name: 'A', score: 10),
        _TestItem(id: '2', name: 'B', score: 20),
        _TestItem(id: '3', name: 'C', score: 30),
      ]);

      final items = await store.getAll();
      expect(items.length, 2);
    });

    test('per-item error tolerance: corrupt JSON entries are skipped', () async {
      // Directly write a corrupt entry to SharedPreferences to simulate
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(storeKey, [
        '{"id":"1","name":"valid","score":10}', // valid
        'not-valid-json-at-all', // corrupt
        '{"id":"2","name":"also-valid","score":20}', // valid
      ]);

      final store = await _createStore();
      final items = await store.getAll();
      expect(items.length, 2);
      expect(items[0].id, '2');
      expect(items[1].id, '1');
    });

    test('removeKey static method deletes the key', () async {
      final store = await _createStore();
      await store.add(_TestItem(id: '1', name: 'A', score: 10));

      await LocalJsonListStore.removeKey(storeKey);

      final items = await store.getAll();
      expect(items, isEmpty);
    });
  });
}
