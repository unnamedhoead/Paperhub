/// PaperHub 首页（发现流 + 分区占位）
///
/// 职责与交互：
/// - 展示“发现”瀑布流内容，委托给 [FeedWidget]。
/// - 顶部切换“关注/发现/分区”，关注和分区各自管理帖子流。
/// - 右上角搜索入口 -> `SearchScreen`。
/// - 卡片点击 -> `PostDetailScreen`。
/// - 底部导航：消息页、发布弹窗、个人页的跳转与返回后高亮恢复。
///
/// 约定与注意：
/// - 导航返回后，通过 `then` 回调恢复首页 tab 高亮（`_currentIndex = 0`）。
/// - 释放资源：在 `dispose` 中释放 `ScrollController`。
///
import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../widgets/feed_widget.dart';
import 'search_screen.dart';
import 'post_detail_screen.dart';
import '../services/api_service.dart';
import '../services/chat_service.dart';
import '../services/unread_service.dart';
import '../services/notification_websocket_service.dart';
import '../models/notification_model.dart';
import '../services/local_storage.dart';
import '../services/browse_history_service.dart';
import '../constants/discipline_constants.dart';
import 'home/home_tab_bar.dart';
import 'home/following_feed.dart';
import 'home/zone_tab.dart';
import 'home/home_bottom_nav.dart';

/// 首页入口组件（Stateful）：承载发现流与分区切换
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    Key? key,
    this.themeModeNotifier,
    this.onThemeModeChanged,
    this.onThemeToggle,
  }) : super(key: key);

  final ValueNotifier<ThemeMode>? themeModeNotifier;
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  final VoidCallback? onThemeToggle;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// 底部导航当前索引（0=首页，1=消息，2=发布，3=我的）。
  int _currentIndex = 0;

  /// 点赞操作防抖集合（防止重复请求，供关注/分区流使用）
  final Set<String> _likeInFlight = {};

  /// 顶部 tab 选择
  /// 0=关注, 1=发现, 2=分区
  int _selectedTab = 1;
  final ChatService _chatService = ChatService();

  /// 发现流独立组件的 key，用于触发刷新
  final GlobalKey<FeedWidgetState> _feedKey = GlobalKey<FeedWidgetState>();

  /// 分区页当前选中的主分区
  String _currentZoneDiscipline = kMainDisciplines.first;

  /// 分区页帖子列表（独立于发现页）
  final List<Post> _zonePosts = [];

  /// 分区页加载状态
  bool _zoneLoading = false;

  /// 分区页是否还有更多数据
  bool _zoneHasMore = true;

  /// 分区页当前页码
  int _zonePage = 1;

  /// 关注页帖子列表与加载状态
  final List<Post> _followingPosts = [];
  bool _followingLoading = false;
  bool _followingHasMore = true;
  int _followingPage = 1;
  bool _followingHasNew = false;
  /// 最近一次“已在关注页看过”的顶部帖子 ID（用于跨页面防止红点反复出现）
  String? _lastFollowingTopPostIdSeen;
  final ScrollController _followingScrollController = ScrollController();

  /// 已浏览过的帖子ID集合（用于在关注流中标记未读红点）
  final Set<String> _viewedPostIds = {};

  /// 当前用户刚发布的帖子（优先展示在发现页顶部，直到刷新/离开）
  Post? _pinnedSelfPost;

  @override
  void initState() {
    super.initState();
    _followingScrollController.addListener(_followingScrollListener);
    _preloadUnreadBadges();
    _loadViewedPostIds();
    _loadLastFollowingSeenFromStorage();
    // 初始进入首页也要检查关注流，便于及时展示红点
    _refreshFollowingFeed();

    // 检查WebSocket连接状态
    _checkWebSocketConnection();
  }

  /// 检查WebSocket连接状态
  Future<void> _checkWebSocketConnection() async {
    try {
      // 延迟执行，确保其他初始化完成
      await Future.delayed(const Duration(seconds: 2));
      await NotificationWebSocketService.instance.checkAndReconnect();
    } catch (e) {
      print('检查WebSocket连接失败: $e');
    }
  }

  /// 加载当前用户的浏览历史，用于关注流“未读”标记
  Future<void> _loadViewedPostIds() async {
    try {
      final userId = LocalStorage.instance.read('userId')?.toString() ?? '';
      if (userId.isEmpty) return;
      final historyItems = await BrowseHistoryService.getHistory(userId);
      setState(() {
        _viewedPostIds
          ..clear()
          ..addAll(historyItems.map((e) => e.postId));
      });
    } catch (_) {
      // 忽略错误，不影响主流程
    }
  }

  /// 加载分区帖子
  Future<void> _loadZonePosts() async {
    if (_zoneLoading || !_zoneHasMore) return;

    setState(() {
      _zoneLoading = true;
    });

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

        setState(() {
          _zonePosts.addAll(newPosts);
          _zoneHasMore = _zonePosts.length < total;
          _zonePage += 1;
          _zoneLoading = false;
        });
      } else {
        setState(() {
          _zoneLoading = false;
        });
      }
    } catch (_) {
      setState(() {
        _zoneLoading = false;
      });
    }
  }

  Future<void> _preloadUnreadBadges() async {
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

  /// 关注流：初次加载
  Future<void> _loadInitialFollowingPosts() async {
    if (_followingLoading) return;

    // 检查是否有 token，没有 token 就不发起需要认证的请求
    final token = LocalStorage.instance.read('accessToken');
    if (token == null || token.isEmpty) {
      setState(() {
        _followingLoading = false;
        _followingHasMore = false;
      });
      return; // 未登录，不加载关注流
    }

    setState(() {
      _followingLoading = true;
    });

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
          _updateLastFollowingSeen(newPosts.first.id);
        }

        final bool hasNewFollowing = _shouldShowFollowingBadge(newPosts);

        setState(() {
          _followingPosts
            ..clear()
            ..addAll(newPosts);
          _followingHasMore = _followingPosts.length < total;
          _followingPage = 2;
          _followingLoading = false;
          if (_selectedTab == 0 && newPosts.isNotEmpty) {
            _updateLastFollowingSeen(newPosts.first.id);
          }
          if (hasNewFollowing) {
            _followingHasNew = true;
          }
        });
      } else {
        setState(() {
          _followingLoading = false;
        });
      }
    } catch (_) {
      setState(() {
        _followingLoading = false;
      });
    }
  }

  /// 关注流：加载更多
  Future<void> _loadMoreFollowingPosts() async {
    if (_followingLoading || !_followingHasMore) return;

    setState(() {
      _followingLoading = true;
    });

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

        setState(() {
          _followingPosts.addAll(newPosts);
          _followingHasMore = _followingPosts.length < total;
          _followingPage += 1;
          _followingLoading = false;
          if (_selectedTab != 0 && newPosts.isNotEmpty) {
            _followingHasNew = true;
          }
        });
      } else {
        setState(() {
          _followingLoading = false;
        });
      }
    } catch (_) {
      setState(() {
        _followingLoading = false;
      });
    }
  }

  /// 刷新关注流（用于其他页面触发的全局刷新）
  Future<void> _refreshFollowingFeed() async {
    if (_followingLoading) return;

    // 检查是否有 token，没有 token 就不发起需要认证的请求
    final token = LocalStorage.instance.read('accessToken');
    if (token == null || token.isEmpty) {
      setState(() {
        _followingLoading = false;
        _followingHasMore = false;
      });
      return; // 未登录，不刷新关注流
    }

    setState(() {
      _followingLoading = true;
    });

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
          _updateLastFollowingSeen(newPosts.first.id);
        }

        final bool hasNewFollowing = _shouldShowFollowingBadge(newPosts);

        setState(() {
          _followingPosts
            ..clear()
            ..addAll(newPosts);
          _followingHasMore = _followingPosts.length < total;
          _followingPage = 2;
          _followingLoading = false;
          if (_selectedTab == 0 && newPosts.isNotEmpty) {
            _updateLastFollowingSeen(newPosts.first.id);
          }
          // 不在关注页时展示红点提示
          if (hasNewFollowing) {
            _followingHasNew = true;
          }
        });
      } else {
        setState(() {
          _followingLoading = false;
        });
      }
    } catch (_) {
      setState(() {
        _followingLoading = false;
      });
    }
  }

  /// 判断关注流是否有新帖子需要显示红点
  bool _shouldShowFollowingBadge(List<Post> newPosts) {
    if (newPosts.isEmpty) return false;
    final String? latestId = newPosts.first.id;
    if (latestId == null || latestId.isEmpty) return false;
    // 已在关注页则不显示红点；仅当有新的顶部帖子且未在关注页时展示
    return _selectedTab != 0 && latestId != _lastFollowingTopPostIdSeen;
  }

  /// 从本地存储恢复最近一次"已看过的关注顶部帖子"
  void _loadLastFollowingSeenFromStorage() {
    try {
      final raw = LocalStorage.instance.read('lastFollowingTopIdSeen');
      if (raw is String && raw.trim().isNotEmpty) {
        _lastFollowingTopPostIdSeen = raw.trim();
      }
    } catch (e) {
      print('读取 lastFollowingTopIdSeen 失败: $e');
    }
  }

  /// 更新最近一次"已看过的关注顶部帖子"，并持久化到本地
  void _updateLastFollowingSeen(String? id) {
    if (id == null || id.isEmpty) return;
    _lastFollowingTopPostIdSeen = id;
    try {
      LocalStorage.instance.write('lastFollowingTopIdSeen', id);
    } catch (e) {
      print('写入 lastFollowingTopIdSeen 失败: $e');
    }
  }

  /// 关注流滚动监听
  void _followingScrollListener() {
    if (_followingScrollController.offset >=
        _followingScrollController.position.maxScrollExtent - 200) {
      _loadMoreFollowingPosts();
    }
  }

  /// 发现流帖子点击 -> 打开详情页
  void _onFeedPostTap(Post post) {
    _onPostTap(post);
  }

  /// 通用卡片点击 -> 打开详情页
  void _onPostTap(Post post) {
    // 本地立即标记为已浏览，移除"未读"红点
    if (!_viewedPostIds.contains(post.id)) {
      setState(() {
        _viewedPostIds.add(post.id);
      });
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PostDetailScreen(post: post)),
    ).then((result) {
      if (result == true) {
        setState(() {
          if (_pinnedSelfPost?.id == post.id) {
            _pinnedSelfPost = null;
          }
        });
        // 通知 FeedWidget 刷新（帖子已删除）
        _feedKey.currentState?.reloadFeed();
        return;
      }
      // 从详情页返回时，尝试同步帖子点赞状态
      if (_pinnedSelfPost?.id == post.id) {
        _syncPostLikeStatus(post.id);
      }
    });
  }

  /// 同步单个帖子的点赞状态（用于置顶帖从详情页返回后更新）
  Future<void> _syncPostLikeStatus(String postId) async {
    try {
      final resp = await ApiService.getPost(postId);
      if (resp['statusCode'] == 200) {
        final body = resp['body'] as Map<String, dynamic>;
        final updatedPost = Post.fromJson(body);
        if (_pinnedSelfPost?.id == postId) {
          setState(() {
            _pinnedSelfPost!.likesCount = updatedPost.likesCount;
            _pinnedSelfPost!.isLiked = updatedPost.isLiked;
          });
        }
      }
    } catch (_) {
      // 忽略错误，不影响用户体验
    }
  }

  /// 顶部搜索图标点击 -> 打开搜索页
  void _onSearchTap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SearchScreen()),
    );
  }

  void _openUserProfile(String userId) {
    Navigator.of(context).pushNamed('/user/$userId');
  }

  /// 处理帖子点赞（关注流与分区流共用）
  Future<bool> _handlePostLike(Post post) async {
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
          setState(() {
            _followingPosts[followingIdx].likesCount =
                updatedLikesCount ?? _followingPosts[followingIdx].likesCount;
            _followingPosts[followingIdx].isLiked =
                updatedIsLiked ?? !_followingPosts[followingIdx].isLiked;
          });
        }

        // 更新分区流中的帖子
        final zoneIdx = _zonePosts.indexWhere((p) => p.id == post.id);
        if (zoneIdx != -1) {
          setState(() {
            _zonePosts[zoneIdx].likesCount =
                updatedLikesCount ?? _zonePosts[zoneIdx].likesCount;
            _zonePosts[zoneIdx].isLiked =
                updatedIsLiked ?? !_zonePosts[zoneIdx].isLiked;
          });
        }

        // 更新置顶帖
        if (_pinnedSelfPost?.id == post.id) {
          setState(() {
            _pinnedSelfPost!.likesCount =
                updatedLikesCount ?? _pinnedSelfPost!.likesCount;
            _pinnedSelfPost!.isLiked =
                updatedIsLiked ?? !_pinnedSelfPost!.isLiked;
          });
        }

        return true;
      } else {
        return false;
      }
    } catch (e) {
      print('点赞失败: $e');
      return false;
    } finally {
      _likeInFlight.remove(post.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部导航栏
            HomeTabBar(
              selectedTab: _selectedTab,
              followingHasNew: _followingHasNew,
              themeModeNotifier: widget.themeModeNotifier,
              onThemeToggle: widget.onThemeToggle,
              onThemeModeChanged: widget.onThemeModeChanged,
              onTabSelected: _onTabSelected,
              onSearchTap: _onSearchTap,
            ),

            // 内容区域
            Expanded(
              child: _selectedTab == 0
                  ? FollowingFeed(
                      posts: _followingPosts,
                      isLoading: _followingLoading,
                      hasMore: _followingHasMore,
                      scrollController: _followingScrollController,
                      onPostTap: _onPostTap,
                      onAuthorTap: _openUserProfile,
                      onLikeTap: _handlePostLike,
                    )
                  : _selectedTab == 1
                      ? FeedWidget(
                          key: _feedKey,
                          pinnedPost: _pinnedSelfPost,
                          onPostTap: _onFeedPostTap,
                          onAuthorTap: _openUserProfile,
                        )
                      : ZoneTab(
                          currentDiscipline: _currentZoneDiscipline,
                          posts: _zonePosts,
                          isLoading: _zoneLoading,
                          onDisciplineSelected: _onZoneDisciplineSelected,
                          onPostTap: _onPostTap,
                          onAuthorTap: _openUserProfile,
                          onLikeTap: _handlePostLike,
                        ), // 分区页
            ),
          ],
        ),
      ),
      bottomNavigationBar: HomeBottomNav(
        currentIndex: _currentIndex,
        onIndexChanged: _onBottomNavTap,
        onMessageReturn: _restoreHomeHighlight,
        onPublishReturn: _onPublishReturn,
        onProfileReturn: _restoreHomeHighlight,
      ),
    );
  }

  /// 顶部 tab 切换处理：维护选中状态、红点清除、置顶帖清理与懒加载。
  void _onTabSelected(int index) {
    final bool wasSelected = _selectedTab == index;
    setState(() {
      _selectedTab = index;
      if (index == 0) {
        _followingHasNew = false; // 进入关注页后红点立即消失
        if (_followingPosts.isNotEmpty) {
          // 记录当前关注流顶部帖子，后续刷新用于判断是否有新内容
          _updateLastFollowingSeen(_followingPosts.first.id);
        }
      }
      // 离开发现页即清除置顶的"我刚发的"帖子
      if (index != 1) {
        _pinnedSelfPost = null;
      }
    });

    // 懒加载关注流 / 分区内容
    if (index == 0 && _followingPosts.isEmpty && !_followingLoading) {
      _loadInitialFollowingPosts();
    } else if (index == 2 &&
        _zonePosts.isEmpty &&
        !_zoneLoading &&
        _zoneHasMore) {
      _loadZonePosts();
    } else if (index == 1) {
      // 从其他 tab 切回发现时，触发一次关注流刷新以获取最新关注动态
      _refreshFollowingFeed();
    }

    // 点击"发现"文案时，触发刷新推荐流（小红书同款）
    if (index == 1 && wasSelected) {
      _pinnedSelfPost = null;
      _feedKey.currentState?.reloadFeed();
    }
  }

  /// 切换分区：重置分区流状态并加载新分区数据。
  void _onZoneDisciplineSelected(String discipline) {
    setState(() {
      _currentZoneDiscipline = discipline;
      // 切换分区时重置状态并加载新分区的数据
      _zonePosts.clear();
      _zonePage = 1;
      _zoneHasMore = true;
    });
    _loadZonePosts();
  }

  /// 底部导航点击：切换高亮索引；离开首页时清除置顶的自发帖子。
  /// 实际页面跳转由 [HomeBottomNav] 负责，跳转后通过回调恢复状态。
  void _onBottomNavTap(int index) {
    setState(() {
      _currentIndex = index;
      if (index != 0) {
        _pinnedSelfPost = null; // 离开首页清除置顶的自发帖子
      }
    });
  }

  /// 从消息页 / 个人页返回时恢复首页高亮。
  void _restoreHomeHighlight() {
    setState(() {
      _currentIndex = 0;
    });
  }

  /// 从发布页返回时：恢复高亮；发布成功则置顶新帖并切到发现页，否则刷新发现流。
  void _onPublishReturn(Object? result) {
    setState(() {
      _currentIndex = 0;
    });
    if (result is Post) {
      setState(() {
        _selectedTab = 1;
        _pinnedSelfPost = result;
      });
      return;
    }
    // 发布结果未知/失败时刷新发现流
    _feedKey.currentState?.reloadFeed();
  }

  @override
  void dispose() {
    // 释放滚动控制器，避免内存泄漏。
    _followingScrollController.dispose();
    super.dispose();
  }
}
