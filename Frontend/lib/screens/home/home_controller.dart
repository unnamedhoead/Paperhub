/// 首页状态控制器（ChangeNotifier）。
///
/// 从 [HomeScreen] 抽离的数据状态与加载/变更逻辑：关注流、分区流、未读角标、
/// 点赞、浏览历史标记、关注红点跟踪。不持有 BuildContext / Navigator /
/// GlobalKey 等 UI 资源（那些仍由 Screen 负责）。
///
/// 用法遵循 state-management-convention.md 的类型 A：
/// Screen `addListener(() => setState(() {}))`，每次 `notifyListeners` 即触发
/// 一次整页 rebuild，与原先散落的 setState 行为等价。
import 'package:flutter/foundation.dart';

import '../../models/post_model.dart';
import '../../models/notification_model.dart';
import '../../constants/discipline_constants.dart';
import '../../services/api_service.dart';
import '../../services/chat_service.dart';
import '../../services/unread_service.dart';
import '../../services/notification_websocket_service.dart';
import '../../services/local_storage.dart';
import '../../services/browse_history_service.dart';

/// 首页数据状态控制器。
class HomeController extends ChangeNotifier {
  final ChatService _chatService = ChatService();

  /// 点赞操作防抖集合（防止重复请求，供关注/分区流使用）。
  final Set<String> _likeInFlight = {};

  /// 顶部 tab 选择：0=关注, 1=发现, 2=分区。
  int _selectedTab = 1;
  int get selectedTab => _selectedTab;

  /// 分区页当前选中的主分区。
  String _currentZoneDiscipline = kMainDisciplines.first;
  String get currentZoneDiscipline => _currentZoneDiscipline;

  /// 分区页帖子列表（独立于发现页）。
  final List<Post> _zonePosts = [];
  List<Post> get zonePosts => _zonePosts;

  /// 分区页加载状态。
  bool _zoneLoading = false;
  bool get zoneLoading => _zoneLoading;

  /// 分区页是否还有更多数据。
  bool _zoneHasMore = true;

  /// 分区页当前页码。
  int _zonePage = 1;

  /// 关注页帖子列表与加载状态。
  final List<Post> _followingPosts = [];
  List<Post> get followingPosts => _followingPosts;
  bool _followingLoading = false;
  bool get followingLoading => _followingLoading;
  bool _followingHasMore = true;
  bool get followingHasMore => _followingHasMore;
  int _followingPage = 1;
  bool _followingHasNew = false;
  bool get followingHasNew => _followingHasNew;

  /// 最近一次“已在关注页看过”的顶部帖子 ID（用于跨页面防止红点反复出现）。
  String? _lastFollowingTopPostIdSeen;

  /// 已浏览过的帖子ID集合（用于在关注流中标记未读红点）。
  final Set<String> _viewedPostIds = {};
  Set<String> get viewedPostIds => _viewedPostIds;

  /// 当前用户刚发布的帖子（优先展示在发现页顶部，直到刷新/离开）。
  Post? _pinnedSelfPost;
  Post? get pinnedSelfPost => _pinnedSelfPost;
  set pinnedSelfPost(Post? value) {
    _pinnedSelfPost = value;
    notifyListeners();
  }

  /// 初始化：恢复本地状态、预加载角标、刷新关注流、检查 WebSocket。
  void init() {
    preloadUnreadBadges();
    loadViewedPostIds();
    loadLastFollowingSeenFromStorage();
    // 初始进入首页也要检查关注流，便于及时展示红点
    refreshFollowingFeed();
    // 检查WebSocket连接状态
    checkWebSocketConnection();
  }

  /// 检查WebSocket连接状态。
  Future<void> checkWebSocketConnection() async {
    try {
      // 延迟执行，确保其他初始化完成
      await Future.delayed(const Duration(seconds: 2));
      await NotificationWebSocketService.instance.checkAndReconnect();
    } catch (e) {
      debugPrint('检查WebSocket连接失败: $e');
    }
  }

  /// 加载当前用户的浏览历史，用于关注流“未读”标记。
  Future<void> loadViewedPostIds() async {
    try {
      final userId = LocalStorage.instance.read('userId')?.toString() ?? '';
      if (userId.isEmpty) return;
      final historyItems = await BrowseHistoryService.getHistory(userId);
      _viewedPostIds
        ..clear()
        ..addAll(historyItems.map((e) => e.postId));
      notifyListeners();
    } catch (_) {
      // 忽略错误，不影响主流程
    }
  }

  /// 加载分区帖子。
  Future<void> loadZonePosts() async {
    if (_zoneLoading || !_zoneHasMore) return;

    _zoneLoading = true;
    notifyListeners();

    try {
      final resp = await ApiService.getPosts(
        page: _zonePage,
        pageSize: 12,
        disciplineTag: _currentZoneDiscipline,
      );
      final status = resp['statusCode'] as int? ?? 500;
      final body = resp['body'] as Map<String, dynamic>?;

      if (status >= 200 && status < 300 && body != null) {
        final postsData = (body['posts'] as List<dynamic>?) ?? [];
        final total = body['total'] as int? ?? postsData.length;
        final newPosts = postsData
            .map((e) => Post.fromJson(e as Map<String, dynamic>))
            .toList();

        _zonePosts.addAll(newPosts);
        _zoneHasMore = _zonePosts.length < total;
        _zonePage += 1;
        _zoneLoading = false;
        notifyListeners();
      } else {
        _zoneLoading = false;
        notifyListeners();
      }
    } catch (_) {
      _zoneLoading = false;
      notifyListeners();
    }
  }

  Future<void> preloadUnreadBadges() async {
    // 检查是否有 token，没有 token 就不发起需要认证的请求
    final token = LocalStorage.instance.read('accessToken');
    if (token == null || token.isEmpty) {
      return; // 未登录，不加载需要认证的数据
    }

    // 预加载聊天未读
    _chatService.loadConversations();

    // 预加载通知未读
    try {
      final resp = await ApiService.getUnreadNotificationCount();
      if (resp['statusCode'] == 200) {
        final body = resp['body'] as Map<String, dynamic>;
        final count = UnreadCount.fromJson(body);
        UnreadService.instance.updateNotificationUnread(count);
      }
    } catch (_) {
      // 忽略网络异常
    }
  }

  /// 关注流：初次加载。
  Future<void> loadInitialFollowingPosts() async {
    if (_followingLoading) return;

    // 检查是否有 token，没有 token 就不发起需要认证的请求
    final token = LocalStorage.instance.read('accessToken');
    if (token == null || token.isEmpty) {
      _followingLoading = false;
      _followingHasMore = false;
      notifyListeners();
      return; // 未登录，不加载关注流
    }

    _followingLoading = true;
    notifyListeners();

    try {
      final resp = await ApiService.getFollowingPosts(page: 1, pageSize: 6);
      final status = resp['statusCode'] as int? ?? 500;
      final body = resp['body'] as Map<String, dynamic>?;

      if (status >= 200 && status < 300 && body != null) {
        final postsData = (body['posts'] as List<dynamic>?) ?? <dynamic>[];
        final total = body['total'] as int? ?? 0;

        final newPosts = postsData
            .map((p) => Post.fromJson(p as Map<String, dynamic>))
            .toList();

        // 如果还没有记录"看过的关注顶部帖子"，先记录一次，避免新建 Home 实例时误亮红点
        if (_lastFollowingTopPostIdSeen == null && newPosts.isNotEmpty) {
          _persistLastFollowingSeen(newPosts.first.id);
        }

        final bool hasNewFollowing = _shouldShowFollowingBadge(newPosts);

        _followingPosts
          ..clear()
          ..addAll(newPosts);
        _followingHasMore = _followingPosts.length < total;
        _followingPage = 2;
        _followingLoading = false;
        if (_selectedTab == 0 && newPosts.isNotEmpty) {
          _persistLastFollowingSeen(newPosts.first.id);
        }
        if (hasNewFollowing) {
          _followingHasNew = true;
        }
        notifyListeners();
      } else {
        _followingLoading = false;
        notifyListeners();
      }
    } catch (_) {
      _followingLoading = false;
      notifyListeners();
    }
  }

  /// 关注流：加载更多。
  Future<void> loadMoreFollowingPosts() async {
    if (_followingLoading || !_followingHasMore) return;

    _followingLoading = true;
    notifyListeners();

    try {
      final resp = await ApiService.getFollowingPosts(
        page: _followingPage,
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

        _followingPosts.addAll(newPosts);
        _followingHasMore = _followingPosts.length < total;
        _followingPage += 1;
        _followingLoading = false;
        if (_selectedTab != 0 && newPosts.isNotEmpty) {
          _followingHasNew = true;
        }
        notifyListeners();
      } else {
        _followingLoading = false;
        notifyListeners();
      }
    } catch (_) {
      _followingLoading = false;
      notifyListeners();
    }
  }

  /// 刷新关注流（用于其他页面触发的全局刷新）。
  Future<void> refreshFollowingFeed() async {
    if (_followingLoading) return;

    // 检查是否有 token，没有 token 就不发起需要认证的请求
    final token = LocalStorage.instance.read('accessToken');
    if (token == null || token.isEmpty) {
      _followingLoading = false;
      _followingHasMore = false;
      notifyListeners();
      return; // 未登录，不刷新关注流
    }

    _followingLoading = true;
    notifyListeners();

    try {
      final resp = await ApiService.getFollowingPosts(page: 1, pageSize: 6);
      final status = resp['statusCode'] as int? ?? 500;
      final body = resp['body'] as Map<String, dynamic>?;

      if (status >= 200 && status < 300 && body != null) {
        final postsData = (body['posts'] as List<dynamic>?) ?? <dynamic>[];
        final total = body['total'] as int? ?? 0;
        final newPosts = postsData
            .map((p) => Post.fromJson(p as Map<String, dynamic>))
            .toList();

        // 如果还没有记录"看过的关注顶部帖子"，先记录一次，避免新建 Home 实例时误亮红点
        if (_lastFollowingTopPostIdSeen == null && newPosts.isNotEmpty) {
          _persistLastFollowingSeen(newPosts.first.id);
        }

        final bool hasNewFollowing = _shouldShowFollowingBadge(newPosts);

        _followingPosts
          ..clear()
          ..addAll(newPosts);
        _followingHasMore = _followingPosts.length < total;
        _followingPage = 2;
        _followingLoading = false;
        if (_selectedTab == 0 && newPosts.isNotEmpty) {
          _persistLastFollowingSeen(newPosts.first.id);
        }
        // 不在关注页时展示红点提示
        if (hasNewFollowing) {
          _followingHasNew = true;
        }
        notifyListeners();
      } else {
        _followingLoading = false;
        notifyListeners();
      }
    } catch (_) {
      _followingLoading = false;
      notifyListeners();
    }
  }

  /// 判断关注流是否有新帖子需要显示红点。
  bool _shouldShowFollowingBadge(List<Post> newPosts) {
    if (newPosts.isEmpty) return false;
    final String? latestId = newPosts.first.id;
    if (latestId == null || latestId.isEmpty) return false;
    // 已在关注页则不显示红点；仅当有新的顶部帖子且未在关注页时展示
    return _selectedTab != 0 && latestId != _lastFollowingTopPostIdSeen;
  }

  /// 从本地存储恢复最近一次"已看过的关注顶部帖子"。
  void loadLastFollowingSeenFromStorage() {
    try {
      final raw = LocalStorage.instance.read('lastFollowingTopIdSeen');
      if (raw is String && raw.trim().isNotEmpty) {
        _lastFollowingTopPostIdSeen = raw.trim();
      }
    } catch (e) {
      debugPrint('读取 lastFollowingTopIdSeen 失败: $e');
    }
  }

  /// 更新最近一次"已看过的关注顶部帖子"，并持久化到本地（不触发 UI 刷新）。
  void _persistLastFollowingSeen(String? id) {
    if (id == null || id.isEmpty) return;
    _lastFollowingTopPostIdSeen = id;
    try {
      LocalStorage.instance.write('lastFollowingTopIdSeen', id);
    } catch (e) {
      debugPrint('写入 lastFollowingTopIdSeen 失败: $e');
    }
  }

  /// 顶部 tab 切换：维护选中状态、红点清除、置顶帖清理与懒加载。
  /// 返回是否需要由 Screen 触发"发现流刷新"（重复点击"发现"时）。
  bool selectTab(int index) {
    final bool wasSelected = _selectedTab == index;
    _selectedTab = index;
    if (index == 0) {
      _followingHasNew = false; // 进入关注页后红点立即消失
      if (_followingPosts.isNotEmpty) {
        // 记录当前关注流顶部帖子，后续刷新用于判断是否有新内容
        _persistLastFollowingSeen(_followingPosts.first.id);
      }
    }
    // 离开发现页即清除置顶的"我刚发的"帖子
    if (index != 1) {
      _pinnedSelfPost = null;
    }
    notifyListeners();

    // 懒加载关注流 / 分区内容
    if (index == 0 && _followingPosts.isEmpty && !_followingLoading) {
      loadInitialFollowingPosts();
    } else if (index == 2 &&
        _zonePosts.isEmpty &&
        !_zoneLoading &&
        _zoneHasMore) {
      loadZonePosts();
    } else if (index == 1) {
      // 从其他 tab 切回发现时，触发一次关注流刷新以获取最新关注动态
      refreshFollowingFeed();
    }

    // 重复点击"发现"文案时，由 Screen 触发刷新推荐流（小红书同款）
    if (index == 1 && wasSelected) {
      _pinnedSelfPost = null;
      return true;
    }
    return false;
  }

  /// 发布成功返回：切到发现页并把新帖置顶展示（不触发懒加载副作用）。
  void pinPublishedPost(Post post) {
    _selectedTab = 1;
    _pinnedSelfPost = post;
    notifyListeners();
  }

  /// 切换分区：重置分区流状态并加载新分区数据。
  void selectZoneDiscipline(String discipline) {
    _currentZoneDiscipline = discipline;
    // 切换分区时重置状态并加载新分区的数据
    _zonePosts.clear();
    _zonePage = 1;
    _zoneHasMore = true;
    notifyListeners();
    loadZonePosts();
  }

  /// 标记帖子为已浏览（移除关注流"未读"红点）。
  void markPostViewed(String postId) {
    if (!_viewedPostIds.contains(postId)) {
      _viewedPostIds.add(postId);
      notifyListeners();
    }
  }

  /// 清除从详情页返回时已删除帖子的置顶态（返回是否清除了）。
  bool clearPinnedIfMatches(String postId) {
    if (_pinnedSelfPost?.id == postId) {
      _pinnedSelfPost = null;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// 同步单个帖子的点赞状态（用于置顶帖从详情页返回后更新）。
  Future<void> syncPostLikeStatus(String postId) async {
    try {
      final resp = await ApiService.getPost(postId);
      if (resp['statusCode'] == 200) {
        final body = resp['body'] as Map<String, dynamic>;
        final updatedPost = Post.fromJson(body);
        if (_pinnedSelfPost?.id == postId) {
          _pinnedSelfPost!.likesCount = updatedPost.likesCount;
          _pinnedSelfPost!.isLiked = updatedPost.isLiked;
          notifyListeners();
        }
      }
    } catch (_) {
      // 忽略错误，不影响用户体验
    }
  }

  /// 处理帖子点赞（关注流与分区流共用）。
  Future<bool> handlePostLike(Post post) async {
    if (_likeInFlight.contains(post.id)) {
      return false;
    }

    _likeInFlight.add(post.id);

    try {
      final resp = post.isLiked
          ? await ApiService.unlikePost(post.id)
          : await ApiService.likePost(post.id);

      if (resp['statusCode'] == 200) {
        final body = resp['body'] as Map<String, dynamic>?;
        final updatedLikesCount = (body?['likesCount'] as num?)?.toInt();
        final updatedIsLiked = body?['isLiked'] as bool?;

        // 更新关注流中的帖子
        final followingIdx = _followingPosts.indexWhere((p) => p.id == post.id);
        if (followingIdx != -1) {
          _followingPosts[followingIdx].likesCount =
              updatedLikesCount ?? _followingPosts[followingIdx].likesCount;
          _followingPosts[followingIdx].isLiked =
              updatedIsLiked ?? !_followingPosts[followingIdx].isLiked;
        }

        // 更新分区流中的帖子
        final zoneIdx = _zonePosts.indexWhere((p) => p.id == post.id);
        if (zoneIdx != -1) {
          _zonePosts[zoneIdx].likesCount =
              updatedLikesCount ?? _zonePosts[zoneIdx].likesCount;
          _zonePosts[zoneIdx].isLiked =
              updatedIsLiked ?? !_zonePosts[zoneIdx].isLiked;
        }

        // 更新置顶帖
        if (_pinnedSelfPost?.id == post.id) {
          _pinnedSelfPost!.likesCount =
              updatedLikesCount ?? _pinnedSelfPost!.likesCount;
          _pinnedSelfPost!.isLiked =
              updatedIsLiked ?? !_pinnedSelfPost!.isLiked;
        }

        notifyListeners();
        return true;
      } else {
        return false;
      }
    } catch (e) {
      debugPrint('点赞失败: $e');
      return false;
    } finally {
      _likeInFlight.remove(post.id);
    }
  }
}
