/// 首页状态控制器（ChangeNotifier）。
///
/// 组合 [FollowingFeedController] 与 [ZoneFeedController]，并持有跨流的共享状态：
/// 顶部 tab 选择、置顶自发帖、浏览历史标记、点赞防抖。订阅两个子控制器并转发其
/// 变更通知——子控制器任一 notify 都会触发本控制器 notify，从而驱动 Screen 整页
/// rebuild，与原先散落在 _HomeScreenState 的 setState 行为等价。
///
/// 不持有 BuildContext / Navigator / GlobalKey 等 UI 资源（仍由 Screen 负责）。
/// 用法遵循 state-management-convention.md 的类型 A：
/// Screen `addListener(() => setState(() {}))`。
import 'package:flutter/foundation.dart';

import '../../models/post_model.dart';
import '../../models/notification_model.dart';
import '../../services/api_service.dart';
import '../../services/chat_service.dart';
import '../../services/unread_service.dart';
import '../../services/notification_websocket_service.dart';
import '../../services/local_storage.dart';
import '../../services/browse_history_service.dart';
import 'following_feed_controller.dart';
import 'zone_feed_controller.dart';

/// 首页数据状态控制器。
class HomeController extends ChangeNotifier {
  HomeController() {
    _following = FollowingFeedController(isOnFollowingTab: () => _selectedTab == 0);
    _zone = ZoneFeedController();
    _following.addListener(_forward);
    _zone.addListener(_forward);
  }

  final ChatService _chatService = ChatService();

  /// 关注流子控制器。
  late final FollowingFeedController _following;
  FollowingFeedController get following => _following;

  /// 分区流子控制器。
  late final ZoneFeedController _zone;
  ZoneFeedController get zone => _zone;

  /// 转发子控制器变更通知给 Screen。
  void _forward() => notifyListeners();

  /// 点赞操作防抖集合（防止重复请求，供关注/分区流使用）。
  final Set<String> _likeInFlight = {};

  /// 顶部 tab 选择：0=关注, 1=发现, 2=分区。
  int _selectedTab = 1;
  int get selectedTab => _selectedTab;

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
    _following.loadLastSeenFromStorage();
    // 初始进入首页也要检查关注流，便于及时展示红点
    _following.refresh();
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

  /// 顶部 tab 切换：维护选中状态、红点清除、置顶帖清理与懒加载。
  /// 返回是否需要由 Screen 触发"发现流刷新"（重复点击"发现"时）。
  bool selectTab(int index) {
    final bool wasSelected = _selectedTab == index;
    _selectedTab = index;
    if (index == 0) {
      // 进入关注页：清红点 + 记录已看过顶部帖（内部会 notify）
      _following.onEnterTab();
    }
    // 离开发现页即清除置顶的"我刚发的"帖子
    if (index != 1) {
      _pinnedSelfPost = null;
    }
    notifyListeners();

    // 懒加载关注流 / 分区内容
    if (index == 0 && _following.shouldLoadOnEnter) {
      _following.loadInitial();
    } else if (index == 2 && _zone.shouldLoadOnEnter) {
      _zone.loadPosts();
    } else if (index == 1) {
      // 从其他 tab 切回发现时，触发一次关注流刷新以获取最新关注动态
      _following.refresh();
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

  /// 切换分区：委托分区子控制器。
  void selectZoneDiscipline(String discipline) {
    _zone.selectDiscipline(discipline);
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

        // 同步到关注流、分区流
        _following.applyLikeUpdate(post.id, updatedLikesCount, updatedIsLiked);
        _zone.applyLikeUpdate(post.id, updatedLikesCount, updatedIsLiked);

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

  @override
  void dispose() {
    _following.removeListener(_forward);
    _zone.removeListener(_forward);
    _following.dispose();
    _zone.dispose();
    super.dispose();
  }
}
