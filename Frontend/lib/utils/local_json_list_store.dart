import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 基于 SharedPreferences StringList 的泛型 JSON 列表存储。
///
/// 职责：
/// - 将 [T] 对象以 JSON 字符串列表形式持久化到 SharedPreferences。
/// - 提供统一的增/删/查/清空操作，自动处理编解码、排序和容量裁剪。
///
/// 使用方式：
/// ```dart
/// final store = LocalJsonListStore<MyItem>(
///   prefs: await SharedPreferences.getInstance(),
///   key: 'my_items',
///   maxCount: 30,
///   encode: (item) => item.toMap(),
///   decode: (map) => MyItem.fromMap(map),
///   sortBy: (a, b) => b.timestamp.compareTo(a.timestamp), // 降序
/// );
/// await store.add(newItem, isDuplicate: (a, b) => a.id == b.id);
/// final items = await store.getAll();
/// ```
///
/// 容错策略：
/// - [getAll] 逐条解析 JSON，单条损坏时跳过（保留其他条目），避免全部丢失。
/// - 所有写操作在 try/catch 内静默处理。
class LocalJsonListStore<T> {
  final SharedPreferences _prefs;
  final String _key;
  final int _maxCount;
  final Map<String, dynamic> Function(T) _encode;
  final T Function(Map<String, dynamic>) _decode;
  final int Function(T a, T b)? _sortBy;

  LocalJsonListStore({
    required SharedPreferences prefs,
    required String key,
    int maxCount = 50,
    required Map<String, dynamic> Function(T) encode,
    required T Function(Map<String, dynamic>) decode,
    int Function(T a, T b)? sortBy,
  })  : _prefs = prefs,
        _key = key,
        _maxCount = maxCount,
        _encode = encode,
        _decode = decode,
        _sortBy = sortBy;

  /// 获取全部条目（排序后返回，最新在前由 [sortBy] 决定）。
  Future<List<T>> getAll() async {
    try {
      final raw = _prefs.getStringList(_key) ?? [];
      final List<T> result = [];
      for (final s in raw) {
        try {
          final map = json.decode(s) as Map<String, dynamic>;
          result.add(_decode(map));
        } catch (_) {
          // 逐条容错：跳过损坏的条目
        }
      }
      if (_sortBy != null) {
        result.sort(_sortBy);
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  /// 添加一条记录。
  ///
  /// [isDuplicate] 用于去重：若提供，则先移除已有列表中匹配的条目。
  /// 添加后自动截断至 [_maxCount]。
  Future<void> add(T item, {bool Function(T existing, T incoming)? isDuplicate}) async {
    try {
      final items = await getAll();
      if (isDuplicate != null) {
        items.removeWhere((e) => isDuplicate(e, item));
      }
      items.insert(0, item);
      if (items.length > _maxCount) {
        items.removeRange(_maxCount, items.length);
      }
      await _save(items);
    } catch (e) {
      if (kDebugMode) debugPrint('LocalJsonListStore[$_key].add ignored: $e');
    }
  }

  /// 按条件移除条目。
  Future<void> removeWhere(bool Function(T) test) async {
    try {
      final items = await getAll();
      items.removeWhere(test);
      await _save(items);
    } catch (e) {
      if (kDebugMode) debugPrint('LocalJsonListStore[$_key].removeWhere ignored: $e');
    }
  }

  /// 清空全部条目。
  Future<void> clear() async {
    try {
      await _prefs.remove(_key);
    } catch (e) {
      if (kDebugMode) debugPrint('LocalJsonListStore[$_key].clear ignored: $e');
    }
  }

  /// 全量替换（用于云端数据同步到本地缓存）。
  Future<void> setAll(List<T> items) async {
    try {
      final capped = items.length > _maxCount ? items.sublist(0, _maxCount) : items;
      await _save(capped);
    } catch (e) {
      if (kDebugMode) debugPrint('LocalJsonListStore[$_key].setAll ignored: $e');
    }
  }

  /// 删除指定 key 下的所有数据（直接操作 SharedPreferences）。
  static Future<void> removeKey(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (e) {
      if (kDebugMode) debugPrint('LocalJsonListStore.removeKey[$key] ignored: $e');
    }
  }

  Future<void> _save(List<T> items) async {
    final encoded = items.map((e) => json.encode(_encode(e))).toList();
    await _prefs.setStringList(_key, encoded);
  }
}
