/// PaperHub 首页（关注流 / 发现流 / 分区流）——薄组合层。
///
/// 本文件只做"页面状态协调 + 组合"：数据状态与加载逻辑在 [HomeController]
/// （及其 Following/Zone 子控制器）；各区块为独立 Widget：
/// - 顶部切换栏 -> [HomeTabBar]
/// - 关注流 -> [FollowingFeed]
/// - 发现流 -> [FeedWidget]（通过 [_feedKey] 触发刷新）
/// - 分区流 -> [ZoneTab]
/// - 底部导航跳转 -> [HomeBottomNav]
///
/// Screen 仅持有依赖 UI 上下文的资源：FeedWidget 的 GlobalKey、关注流
/// ScrollController、底部导航高亮索引；并负责 Navigator 跳转（搜索/详情/
/// 消息/发布/个人页）与跳转返回后的状态恢复。
///
/// 约定与注意：
/// - Screen `addListener(() => setState(() {}))` 监听 [HomeController]，
///   每次 notify 触发整页 rebuild。
/// - 导航返回后通过回调恢复首页 tab 高亮（`_currentIndex = 0`）。
/// - 释放资源：在 `dispose` 中释放 `ScrollController` 与 [HomeController]。
///
import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../widgets/feed_widget.dart';
import 'search_screen.dart';
import 'post_detail_screen.dart';
import 'home/home_controller.dart';
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
  /// 数据状态控制器（关注流/分区流/角标/点赞等）。
  late final HomeController _controller = HomeController();

  /// 底部导航当前索引（0=首页，1=消息，2=发布，3=我的）。
  int _currentIndex = 0;

  /// 发现流独立组件的 key，用于触发刷新
  final GlobalKey<FeedWidgetState> _feedKey = GlobalKey<FeedWidgetState>();

  /// 关注流滚动控制器（UI 资源，监听里触发 controller 加载更多）。
  final ScrollController _followingScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    _followingScrollController.addListener(_followingScrollListener);
    _controller.init();
  }

  /// 控制器状态变更时整页刷新（等价于原先散落的 setState）。
  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  /// 关注流滚动监听
  void _followingScrollListener() {
    if (_followingScrollController.offset >=
        _followingScrollController.position.maxScrollExtent - 200) {
      _controller.following.loadMore();
    }
  }

  /// 发现流帖子点击 -> 打开详情页
  void _onFeedPostTap(Post post) {
    _onPostTap(post);
  }

  /// 通用卡片点击 -> 打开详情页
  void _onPostTap(Post post) {
    // 本地立即标记为已浏览，移除"未读"红点
    _controller.markPostViewed(post.id);

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PostDetailScreen(post: post)),
    ).then((result) {
      if (result == true) {
        // 帖子已删除：清除可能的置顶态并通知 FeedWidget 刷新
        _controller.clearPinnedIfMatches(post.id);
        _feedKey.currentState?.reloadFeed();
        return;
      }
      // 从详情页返回时，尝试同步帖子点赞状态
      if (_controller.pinnedSelfPost?.id == post.id) {
        _controller.syncPostLikeStatus(post.id);
      }
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部导航栏
            HomeTabBar(
              selectedTab: _controller.selectedTab,
              followingHasNew: _controller.following.hasNew,
              themeModeNotifier: widget.themeModeNotifier,
              onThemeToggle: widget.onThemeToggle,
              onThemeModeChanged: widget.onThemeModeChanged,
              onTabSelected: _onTabSelected,
              onSearchTap: _onSearchTap,
            ),

            // 内容区域
            Expanded(
              child: _controller.selectedTab == 0
                  ? FollowingFeed(
                      posts: _controller.following.posts,
                      isLoading: _controller.following.loading,
                      hasMore: _controller.following.hasMore,
                      scrollController: _followingScrollController,
                      onPostTap: _onPostTap,
                      onAuthorTap: _openUserProfile,
                      onLikeTap: _controller.handlePostLike,
                    )
                  : _controller.selectedTab == 1
                      ? FeedWidget(
                          key: _feedKey,
                          pinnedPost: _controller.pinnedSelfPost,
                          onPostTap: _onFeedPostTap,
                          onAuthorTap: _openUserProfile,
                        )
                      : ZoneTab(
                          currentDiscipline: _controller.zone.currentDiscipline,
                          posts: _controller.zone.posts,
                          isLoading: _controller.zone.loading,
                          onDisciplineSelected: _controller.selectZoneDiscipline,
                          onPostTap: _onPostTap,
                          onAuthorTap: _openUserProfile,
                          onLikeTap: _controller.handlePostLike,
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

  /// 顶部 tab 切换处理：委托 controller 维护状态与懒加载；
  /// 重复点击"发现"时由本页触发发现流刷新（需要 FeedWidget 的 GlobalKey）。
  void _onTabSelected(int index) {
    final bool shouldReloadFeed = _controller.selectTab(index);
    if (shouldReloadFeed) {
      _feedKey.currentState?.reloadFeed();
    }
  }

  /// 底部导航点击：切换高亮索引；离开首页时清除置顶的自发帖子。
  /// 实际页面跳转由 [HomeBottomNav] 负责，跳转后通过回调恢复状态。
  void _onBottomNavTap(int index) {
    setState(() {
      _currentIndex = index;
    });
    if (index != 0) {
      _controller.pinnedSelfPost = null; // 离开首页清除置顶的自发帖子
    }
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
      _controller.pinPublishedPost(result);
      return;
    }
    // 发布结果未知/失败时刷新发现流
    _feedKey.currentState?.reloadFeed();
  }

  @override
  void dispose() {
    // 释放滚动控制器与控制器，避免内存泄漏。
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _followingScrollController.dispose();
    super.dispose();
  }
}
