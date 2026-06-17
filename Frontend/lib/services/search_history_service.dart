/// 搜索历史服务。
///
/// 功能职责：
/// - 读取/新增/删除/清空搜索历史记录；
/// - 生成唯一 ID（毫秒时间戳字符串）。
///
/// 增强版：支持云端存储（优先）与本地缓存（回退）。
/// - 用户登录时：优先从云端加载搜索历史，失败时回退到本地存储。
/// - 添加历史：同时保存到云端和本地（云端失败时仅保存到本地）。
/// - 删除/清空：同步操作云端和本地。
/// - 本地持久化委托给 [LocalJsonListStore]。
///
/// 容量与去重策略：
/// - 最多保存 [kMaxSearchHistoryCount] 条。
/// - 去重按 (keyword + searchType) 维度。
///
import 'package:shared_preferences/shared_preferences.dart';
import '../models/search_model.dart';
import '../services/api_service.dart';
import '../services/local_storage.dart';
import '../utils/local_json_list_store.dart';
import '../constants/cache_constants.dart';

/// 搜索历史服务：提供静态方法便于直接调用
class SearchHistoryService {
  /// SharedPreferences 的键名前缀（按用户隔离）
  static String _searchHistoryKey(String userId) => 'search_history_$userId';

  /// 获取当前用户ID（从LocalStorage）
  static String? _getCurrentUserId() {
    return LocalStorage.instance.read('userId');
  }

  static SharedPreferences? _cachedPrefs;
  static Future<SharedPreferences> get _prefs async {
    _cachedPrefs ??= await SharedPreferences.getInstance();
    return _cachedPrefs!;
  }

  static Future<LocalJsonListStore<SearchHistoryItem>> _store(
      String userId) async {
    final prefs = await _prefs;
    return LocalJsonListStore<SearchHistoryItem>(
      prefs: prefs,
      key: _searchHistoryKey(userId),
      maxCount: kMaxSearchHistoryCount,
      encode: (item) => item.toMap(),
      decode: (map) => SearchHistoryItem.fromMap(map),
      sortBy: (a, b) => b.timestamp.compareTo(a.timestamp),
    );
  }

  // 获取搜索历史
  /// 返回值：最新在前的 [SearchHistoryItem] 列表；失败时返回空列表。
  /// 策略：优先从云端获取，失败时回退到本地存储
  static Future<List<SearchHistoryItem>> getSearchHistory() async {
    final userId = _getCurrentUserId();
    if (userId == null || userId.isEmpty) {
      // 用户未登录，只返回本地存储的历史（如果有）
      final store = await _store('');
      return store.getAll();
    }

    // 优先从云端获取
    try {
      final resp = await ApiService.getSearchHistory(limit: kMaxSearchHistoryCount);
      if (resp['statusCode'] == 200) {
        final body = resp['body'] as Map<String, dynamic>?;
        final items = (body?['items'] as List<dynamic>? ?? [])
            .map((e) => e as Map<String, dynamic>)
            .map(SearchHistoryItem.fromCloudData)
            .toList();

        // 同步到本地缓存
        final store = await _store(userId);
        await store.setAll(items);
        return items;
      }
    } catch (_) {
      // ignore and fallback
    }

    // 回退到本地存储
    final store = await _store(userId);
    return store.getAll();
  }

  // 添加搜索历史
  /// 行为：
  /// 1) 保存到云端（如果用户已登录）
  /// 2) 保存到本地存储
  /// 3) 去重（按 keyword + searchType）
  /// 4) 头插（最新在前）
  /// 5) 截断至最大容量
  static Future<void> addSearchHistory(SearchHistoryItem item) async {
    final userId = _getCurrentUserId();

    // 保存到云端（如果用户已登录）
    if (userId != null && userId.isNotEmpty) {
      try {
        await ApiService.addSearchHistory(
          keyword: item.keyword,
          searchType: item.searchType,
        );
      } catch (_) {
        // 忽略错误，继续保存到本地
      }
    }

    // 保存到本地存储
    final store = await _store(userId ?? '');
    await store.add(item, isDuplicate: (existing, incoming) =>
        existing.keyword == incoming.keyword &&
        existing.searchType == incoming.searchType);
  }

  // 删除单条搜索历史
  /// 按 id 精确删除；同时删除云端和本地记录
  static Future<void> removeSearchHistory(String id) async {
    final userId = _getCurrentUserId();

    // 删除云端记录（如果用户已登录且ID是数字，可能是云端ID）
    if (userId != null && userId.isNotEmpty) {
      try {
        // 尝试将ID解析为数字，如果是云端ID
        final cloudId = int.tryParse(id);
        if (cloudId != null && cloudId > 0) {
          await ApiService.deleteSearchHistory(id);
        }
      } catch (_) {
        // 忽略错误
      }
    }

    // 删除本地记录（同时处理云端ID和本地时间戳ID）
    final store = await _store(userId ?? '');
    await store.removeWhere((item) => item.id == id);
  }

  // 清空搜索历史
  /// 清空云端和本地的搜索历史
  static Future<void> clearSearchHistory() async {
    final userId = _getCurrentUserId();

    // 清空云端历史（如果用户已登录）
    if (userId != null && userId.isNotEmpty) {
      try {
        await ApiService.clearSearchHistory();
      } catch (_) {
        // 忽略错误
      }
    }

    // 清空本地历史
    final store = await _store(userId ?? '');
    await store.clear();
  }

  // 生成唯一ID
  /// 使用当前毫秒时间戳作为字符串 ID；
  /// 在多数场景下可满足唯一性需求，但跨设备并发场景不保证绝对唯一。
  static String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}
