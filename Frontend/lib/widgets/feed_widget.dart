import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../models/post_model.dart';
import '../models/user_profile.dart';
import '../widgets/post_card.dart';
import '../services/api_service.dart';
import '../services/local_storage.dart';

/// 首页发现流独立组件——管理瀑布流加载/分页/热度排序/点赞。
///
/// 父组件通过 [FeedWidgetState.reloadFeed] / [refreshFirstPage] 触发刷新。
class FeedWidget extends StatefulWidget {
  final Post? pinnedPost;
  final void Function(Post post) onPostTap;
  final void Function(String userId) onAuthorTap;

  const FeedWidget({
    Key? key,
    this.pinnedPost,
    required this.onPostTap,
    required this.onAuthorTap,
  }) : super(key: key);

  @override
  State<FeedWidget> createState() => FeedWidgetState();
}

class FeedWidgetState extends State<FeedWidget> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _hasMore = true;
  final List<Post> _posts = [];
  bool _useHotRanking = false;
  final Set<String> _likeInFlight = {};
  Post? _internalPinnedPost;

  Post? get _effectivePinnedPost => widget.pinnedPost ?? _internalPinnedPost;

  @override
  void initState() {
    super.initState();
    _loadInitialPosts();
    _scrollController.addListener(_scrollListener);
    _evaluateUserSignals();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 父组件调用：清空并重新加载发现流。
  Future<void> reloadFeed() async {
    if (_isLoading) return;
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
    setState(() {
      _internalPinnedPost = null;
      _posts.clear();
      _hasMore = true;
    });
    await _loadInitialPosts();
  }

  /// 父组件调用：刷新第一页，不清空现有列表。
  Future<void> refreshFirstPage() async {
    try {
      final resp = await ApiService.getRecommendedPosts(page: 1, pageSize: 6);
      final body = _okBody(resp);
      if (body == null) return;
      final newPosts = _parsePosts(body['posts']);
      final total = body['total'] as int? ?? 0;
      setState(() {
        for (var np in newPosts) {
          if (!_posts.any((p) => p.id == np.id)) {
            _useHotRanking ? _posts.add(np) : _posts.insert(0, np);
          }
        }
        if (_useHotRanking) {
          _posts..clear()..addAll(_sortedByHeat([..._posts]));
        }
        _hasMore = _posts.length < total;
      });
    } catch (e) {
      if (kDebugMode) debugPrint('FeedWidget._loadMorePosts ignored: $e');
    }
  }

  void _scrollListener() {
    if (_scrollController.offset >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMorePosts();
    }
  }

  // ── 数据加载 ──

  Future<void> _loadInitialPosts() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final resp = await ApiService.getRecommendedPosts(page: 1, pageSize: 6);
      final body = _okBody(resp);
      if (body != null) {
        final newPosts = _parsePosts(body['posts']);
        final total = body['total'] as int? ?? 0;
        final useHot = _shouldUseHotRankingOnChunk(newPosts);
        final List<Post> ordered =
            useHot ? _sortedByHeat(newPosts) : newPosts;
        final pinned = _consumeLastCreatedPostForPin(ordered);
        setState(() {
          _useHotRanking = useHot;
          if (pinned != null) _internalPinnedPost = pinned;
          _posts..clear()..addAll(ordered);
          _hasMore = _posts.length < total;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);
    try {
      final currentPage = (_posts.length ~/ 6) + 1;
      final resp =
          await ApiService.getRecommendedPosts(page: currentPage, pageSize: 6);
      final body = _okBody(resp);
      if (body != null) {
        final newPosts = _parsePosts(body['posts']);
        final total = body['total'] as int? ?? 0;
        final useHot = _shouldUseHotRankingOnChunk(newPosts);
        final combined = [..._posts, ...newPosts];
        final ordered = useHot ? _sortedByHeat(combined) : combined;
        setState(() {
          _useHotRanking = useHot;
          _posts..clear()..addAll(ordered);
          _hasMore = _posts.length < total;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  /// 成功时返回 body，否则返回 null。
  Map<String, dynamic>? _okBody(Map<String, dynamic> resp) {
    final status = resp['statusCode'] as int? ?? 500;
    final body = resp['body'] as Map<String, dynamic>?;
    return (status >= 200 && status < 300) ? body : null;
  }

  List<Post> _parsePosts(dynamic postsData) {
    return ((postsData as List<dynamic>?) ?? <dynamic>[])
        .map((p) => Post.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  // ── 热度排序 ──

  double _computeHeat(Post p) =>
      p.likesCount + p.commentsCount * 0.5 + p.searchHistoryScore * 1.0;

  List<Post> _sortedByHeat(List<Post> list) {
    final sorted = [...list];
    sorted.sort((a, b) => _computeHeat(b).compareTo(_computeHeat(a)));
    return sorted;
  }

  bool _shouldUseHotRankingOnChunk(List<Post> chunk) {
    if (chunk.isEmpty) return _useHotRanking;
    return _useHotRanking || chunk.every((p) => p.recommendationScore < 2);
  }

  Post? _consumeLastCreatedPostForPin(List<Post> currentList) {
    try {
      final raw = LocalStorage.instance.read('lastCreatedPost');
      if (raw == null || raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final pinned = Post.fromJson(decoded);
      currentList.removeWhere((p) => p.id == pinned.id);
      LocalStorage.instance.write('lastCreatedPost', '');
      return pinned;
    } catch (_) {
      return null;
    }
  }

  Future<void> _evaluateUserSignals() async {
    try {
      final token = LocalStorage.instance.read('accessToken');
      if (token == null || token.isEmpty) {
        _tryLocalUserSignals();
        return;
      }
      final resp = await ApiService.getCurrentUserProfile();
      if (resp['statusCode'] == 200) {
        final body = resp['body'] as Map<String, dynamic>?;
        if (body != null) {
          _applyUserSignals(UserProfile.fromJson(body));
          return;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('FeedWidget._evaluateUserSignals ignored: $e');
    }
    _tryLocalUserSignals();
  }

  void _tryLocalUserSignals() {
    try {
      final cached = LocalStorage.instance.read('currentUser');
      if (cached != null) {
        final decoded = jsonDecode(cached) as Map<String, dynamic>;
        _applyUserSignals(UserProfile.fromJson(decoded));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('FeedWidget._tryLocalUserSignals ignored: $e');
    }
  }

  void _applyUserSignals(UserProfile profile) {
    final missingDirections = profile.researchDirections.isEmpty;
    setState(() {
      _useHotRanking = missingDirections || _useHotRanking;
    });
    if (_useHotRanking && _posts.isNotEmpty) {
      _sortDiscoverByHeat();
    }
  }

  void _sortDiscoverByHeat() {
    final sorted = _sortedByHeat(_posts);
    setState(() {
      _posts..clear()..addAll(sorted);
    });
  }

  // ── 点赞乐观更新 ──

  Future<bool> _handlePostLike(Post post) async {
    if (_likeInFlight.contains(post.id)) return false;
    _likeInFlight.add(post.id);
    try {
      final resp = post.isLiked
          ? await ApiService.unlikePost(post.id)
          : await ApiService.likePost(post.id);
      if (resp['statusCode'] == 200) {
        final body = resp['body'] as Map<String, dynamic>?;
        final updatedLikesCount = (body?['likesCount'] as num?)?.toInt();
        final updatedIsLiked = body?['isLiked'] as bool?;
        final idx = _posts.indexWhere((p) => p.id == post.id);
        if (idx != -1) {
          setState(() {
            _posts[idx].likesCount = updatedLikesCount ?? _posts[idx].likesCount;
            _posts[idx].isLiked = updatedIsLiked ?? !_posts[idx].isLiked;
          });
        }
        return true;
      }
      return false;
    } catch (_) {
      return false;
    } finally {
      _likeInFlight.remove(post.id);
    }
  }

  // ── 构建 ──

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _posts.isEmpty) return _buildInitialLoading();
    return _buildWaterfallGrid();
  }

  Widget _buildWaterfallGrid() {
    final pinned = _effectivePinnedPost;
    final hasPinned = pinned != null;
    final baseCount = _posts.length + (hasPinned ? 1 : 0);
    final totalCount = baseCount + (_isLoading ? 1 : 0);
    return MasonryGridView.count(
      controller: _scrollController,
      crossAxisCount: 2,
      crossAxisSpacing: 3,
      mainAxisSpacing: 3,
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      itemCount: totalCount,
      itemBuilder: (context, index) {
        if (index == baseCount) return _buildLoadMoreIndicator();
        final Post target = hasPinned
            ? (index == 0 ? pinned : _posts[index - 1])
            : _posts[index];
        return PostCard(
          post: target,
          onTap: () => widget.onPostTap(target),
          onAuthorTap: () => widget.onAuthorTap(target.author.id),
          onLikeTap: _handlePostLike,
        );
      },
    );
  }

  Widget _buildLoadMoreIndicator() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (!_hasMore) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('没有更多内容了', style: TextStyle(color: Colors.grey)),
        ),
      );
    }
    return const SizedBox();
  }

  Widget _buildInitialLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('加载中...', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
