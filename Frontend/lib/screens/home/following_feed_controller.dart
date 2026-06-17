/// 首页"关注"流状态控制器（ChangeNotifier）。
///
/// 持有关注流帖子列表、分页/加载状态、未读红点与"已看过的顶部帖子"跟踪。
/// 红点逻辑依赖"当前是否在关注 tab"，通过构造入参 [isOnFollowingTab] 回调
/// 获取，避免与 [HomeController] 的 selectedTab 形成硬耦合。
/// 由 [HomeController] 组合并转发其变更通知。
import 'package:flutter/foundation.dart';

import '../../models/post_model.dart';
import '../../services/api_service.dart';
import '../../services/local_storage.dart';

/// 关注流控制器。
class FollowingFeedController extends ChangeNotifier {
  /// 返回当前是否处于关注 tab（影响红点显示与"已看过"记录）。
  final bool Function() isOnFollowingTab;

  FollowingFeedController({required this.isOnFollowingTab});

  /// 关注页帖子列表。
  final List<Post> _posts = [];
  List<Post> get posts => _posts;

  bool _loading = false;
  bool get loading => _loading;
  bool _hasMore = true;
  bool get hasMore => _hasMore;
  int _page = 1;
  bool _hasNew = false;
  bool get hasNew => _hasNew;

  /// 最近一次“已在关注页看过”的顶部帖子 ID（跨页面防止红点反复出现）。
  String? _lastTopPostIdSeen;

  /// 从本地存储恢复最近一次"已看过的关注顶部帖子"。
  void loadLastSeenFromStorage() {
    try {
      final raw = LocalStorage.instance.read('lastFollowingTopIdSeen');
      if (raw is String && raw.trim().isNotEmpty) {
        _lastTopPostIdSeen = raw.trim();
      }
    } catch (e) {
      debugPrint('读取 lastFollowingTopIdSeen 失败: $e');
    }
  }

  /// 更新最近一次"已看过的关注顶部帖子"，并持久化到本地（不触发 UI 刷新）。
  void _persistLastSeen(String? id) {
    if (id == null || id.isEmpty) return;
    _lastTopPostIdSeen = id;
    try {
      LocalStorage.instance.write('lastFollowingTopIdSeen', id);
    } catch (e) {
      debugPrint('写入 lastFollowingTopIdSeen 失败: $e');
    }
  }

  /// 判断关注流是否有新帖子需要显示红点。
  bool _shouldShowBadge(List<Post> newPosts) {
    if (newPosts.isEmpty) return false;
    final String? latestId = newPosts.first.id;
    if (latestId == null || latestId.isEmpty) return false;
    // 已在关注页则不显示红点；仅当有新的顶部帖子且未在关注页时展示
    return !isOnFollowingTab() && latestId != _lastTopPostIdSeen;
  }

  /// 进入关注 tab 时：清除红点并记录当前顶部帖子。
  void onEnterTab() {
    _hasNew = false;
    if (_posts.isNotEmpty) {
      _persistLastSeen(_posts.first.id);
    }
    notifyListeners();
  }

  /// 是否应在切到关注 tab 时触发首次加载。
  bool get shouldLoadOnEnter => _posts.isEmpty && !_loading;

  /// 关注流：初次加载。
  Future<void> loadInitial() async {
    if (_loading) return;

    final token = LocalStorage.instance.read('accessToken');
    if (token == null || token.isEmpty) {
      _loading = false;
      _hasMore = false;
      notifyListeners();
      return; // 未登录，不加载关注流
    }

    _loading = true;
    notifyListeners();

    try {
      final resp = await ApiService.getFollowingPosts(page: 1, pageSize: 6);
      final status = resp['statusCode'] as int? ?? 500;
      final body = resp['body'] as Map<String, dynamic>?;

      if (status >= 200 && status < 300 && body != null) {
        _applyFirstPage(body);
      } else {
        _loading = false;
        notifyListeners();
      }
    } catch (_) {
      _loading = false;
      notifyListeners();
    }
  }

  /// 关注流：加载更多。
  Future<void> loadMore() async {
    if (_loading || !_hasMore) return;

    _loading = true;
    notifyListeners();

    try {
      final resp = await ApiService.getFollowingPosts(
        page: _page,
        pageSize: 6,
      );
      final status = resp['statusCode'] as int? ?? 500;
      final body = resp['body'] as Map<String, dynamic>?;

      if (status >= 200 && status < 300 && body != null) {
        final postsData = (body['posts'] as List<dynamic>?) ?? <dynamic>[];
        final total = body['total'] as int? ?? 0;

        final newPosts = postsData
            .map((p) => Post.fromJson(p as Map<String, dynamic>))
            .toList();

        _posts.addAll(newPosts);
        _hasMore = _posts.length < total;
        _page += 1;
        _loading = false;
        if (!isOnFollowingTab() && newPosts.isNotEmpty) {
          _hasNew = true;
        }
        notifyListeners();
      } else {
        _loading = false;
        notifyListeners();
      }
    } catch (_) {
      _loading = false;
      notifyListeners();
    }
  }

  /// 刷新关注流（用于其他页面触发的全局刷新）。
  Future<void> refresh() async {
    if (_loading) return;

    final token = LocalStorage.instance.read('accessToken');
    if (token == null || token.isEmpty) {
      _loading = false;
      _hasMore = false;
      notifyListeners();
      return; // 未登录，不刷新关注流
    }

    _loading = true;
    notifyListeners();

    try {
      final resp = await ApiService.getFollowingPosts(page: 1, pageSize: 6);
      final status = resp['statusCode'] as int? ?? 500;
      final body = resp['body'] as Map<String, dynamic>?;

      if (status >= 200 && status < 300 && body != null) {
        _applyFirstPage(body);
      } else {
        _loading = false;
        notifyListeners();
      }
    } catch (_) {
      _loading = false;
      notifyListeners();
    }
  }

  /// 处理首页/刷新返回的第一页数据（loadInitial 与 refresh 共用）。
  void _applyFirstPage(Map<String, dynamic> body) {
    final postsData = (body['posts'] as List<dynamic>?) ?? <dynamic>[];
    final total = body['total'] as int? ?? 0;
    final newPosts = postsData
        .map((p) => Post.fromJson(p as Map<String, dynamic>))
        .toList();

    // 如果还没有记录"看过的关注顶部帖子"，先记录一次，避免新建 Home 实例时误亮红点
    if (_lastTopPostIdSeen == null && newPosts.isNotEmpty) {
      _persistLastSeen(newPosts.first.id);
    }

    final bool hasNewFollowing = _shouldShowBadge(newPosts);

    _posts
      ..clear()
      ..addAll(newPosts);
    _hasMore = _posts.length < total;
    _page = 2;
    _loading = false;
    if (isOnFollowingTab() && newPosts.isNotEmpty) {
      _persistLastSeen(newPosts.first.id);
    }
    if (hasNewFollowing) {
      _hasNew = true;
    }
    notifyListeners();
  }

  /// 同步某帖的点赞状态到关注列表（由点赞处理统一调用，不单独通知）。
  void applyLikeUpdate(String postId, int? likesCount, bool? isLiked) {
    final idx = _posts.indexWhere((p) => p.id == postId);
    if (idx != -1) {
      _posts[idx].likesCount = likesCount ?? _posts[idx].likesCount;
      _posts[idx].isLiked = isLiked ?? !_posts[idx].isLiked;
    }
  }
}
