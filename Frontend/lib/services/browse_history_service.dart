import 'package:flutter/foundation.dart';
import '../models/browse_history_item.dart';
import '../services/api_service.dart';
import '../utils/local_json_list_store.dart';
import '../constants/cache_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 浏览历史服务：
/// - 优先调用后端 API，若失败回退到本地 SharedPreferences 缓存。
/// - 本地缓存按用户划分 key：browse_history_<userId>。
/// - 本地持久化委托给 [LocalJsonListStore]。
class BrowseHistoryService {
  static String _keyForUser(String userId) => 'browse_history_$userId';

  static SharedPreferences? _cachedPrefs;
  static Future<SharedPreferences> get _prefs async {
    _cachedPrefs ??= await SharedPreferences.getInstance();
    return _cachedPrefs!;
  }

  static Future<LocalJsonListStore<BrowseHistoryItem>> _store(
      String userId) async {
    final prefs = await _prefs;
    return LocalJsonListStore<BrowseHistoryItem>(
      prefs: prefs,
      key: _keyForUser(userId),
      maxCount: kMaxBrowseHistoryCount,
      encode: (item) => item.toMap(),
      decode: (map) => BrowseHistoryItem.fromMap(map),
      sortBy: (a, b) => b.timestamp.compareTo(a.timestamp),
    );
  }

  /// 获取指定用户的浏览历史（最新在前）
  static Future<List<BrowseHistoryItem>> getHistory(String userId) async {
    if (userId.isEmpty) return [];
    // 优先从后端获取，失败时回退到本地缓存
    try {
      final resp = await ApiService.getBrowseHistory(limit: kMaxBrowseHistoryCount);
      if (resp['statusCode'] == 200) {
        final body = resp['body'] as Map<String, dynamic>?;
        final items = (body?['items'] as List<dynamic>? ?? [])
            .map((e) => e as Map<String, dynamic>)
            .map(
              (m) => BrowseHistoryItem(
                postId: m['postId']?.toString() ?? '',
                title: m['title']?.toString() ?? '',
                timestamp: DateTime.parse(
                  (m['viewedAt'] ?? DateTime.now().toIso8601String()).toString(),
                ).millisecondsSinceEpoch,
              ),
            )
            .toList();
        // 同步一份到本地，作为缓存
        final store = await _store(userId);
        await store.setAll(items);
        return items;
      }
    } catch (_) {
      // ignore and fallback
    }
    final store = await _store(userId);
    return store.getAll();
  }

  /// 添加一条浏览历史（若已存在该 postId，则先删除旧记录）
  static Future<void> addHistory({
    required String userId,
    required String postId,
    required String title,
  }) async {
    if (userId.isEmpty || postId.isEmpty) return;
    // 后端记录（忽略失败），本地也维护一份缓存
    try {
      await ApiService.addBrowseHistory(postId: postId, title: title);
    } catch (e) {
      if (kDebugMode) debugPrint('BrowseHistoryService.addHistory backend ignored: $e');
    }
    final store = await _store(userId);
    await store.add(
      BrowseHistoryItem(
        postId: postId,
        title: title,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ),
      isDuplicate: (existing, incoming) => existing.postId == incoming.postId,
    );
  }

  /// 按 postId 删除浏览记录（用于帖子被删除时清理）
  static Future<void> removeByPostId(String userId, String postId) async {
    if (userId.isEmpty || postId.isEmpty) return;
    try {
      await ApiService.deleteBrowseHistory(postId);
    } catch (e) {
      if (kDebugMode) debugPrint('BrowseHistoryService.removeByPostId backend ignored: $e');
    }
    final store = await _store(userId);
    await store.removeWhere((item) => item.postId == postId);
  }

  /// 清空某个用户的浏览历史
  static Future<void> clearHistory(String userId) async {
    if (userId.isEmpty) return;
    try {
      await ApiService.clearBrowseHistory();
    } catch (e) {
      if (kDebugMode) debugPrint('BrowseHistoryService.clearHistory backend ignored: $e');
    }
    final store = await _store(userId);
    await store.clear();
  }
}
