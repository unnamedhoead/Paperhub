/// 首页"分区"流状态控制器（ChangeNotifier）。
///
/// 独立于关注流/发现流：持有当前分区、分区帖子列表与分页/加载状态。
/// 由 [HomeController] 组合并转发其变更通知。
import 'package:flutter/foundation.dart';

import '../../models/post_model.dart';
import '../../constants/discipline_constants.dart';
import '../../services/api_service.dart';

/// 分区流控制器。
class ZoneFeedController extends ChangeNotifier {
  /// 分区页当前选中的主分区。
  String _currentDiscipline = kMainDisciplines.first;
  String get currentDiscipline => _currentDiscipline;

  /// 分区页帖子列表（独立于发现页）。
  final List<Post> _posts = [];
  List<Post> get posts => _posts;

  /// 分区页加载状态。
  bool _loading = false;
  bool get loading => _loading;

  /// 分区页是否还有更多数据。
  bool _hasMore = true;

  /// 分区页当前页码。
  int _page = 1;

  /// 加载分区帖子。
  Future<void> loadPosts() async {
    if (_loading || !_hasMore) return;

    _loading = true;
    notifyListeners();

    try {
      final resp = await ApiService.getPosts(
        page: _page,
        pageSize: 12,
        disciplineTag: _currentDiscipline,
      );
      final status = resp['statusCode'] as int? ?? 500;
      final body = resp['body'] as Map<String, dynamic>?;

      if (status >= 200 && status < 300 && body != null) {
        final postsData = (body['posts'] as List<dynamic>?) ?? [];
        final total = body['total'] as int? ?? postsData.length;
        final newPosts = postsData
            .map((e) => Post.fromJson(e as Map<String, dynamic>))
            .toList();

        _posts.addAll(newPosts);
        _hasMore = _posts.length < total;
        _page += 1;
        _loading = false;
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

  /// 切换分区：重置分区流状态并加载新分区数据。
  void selectDiscipline(String discipline) {
    _currentDiscipline = discipline;
    // 切换分区时重置状态并加载新分区的数据
    _posts.clear();
    _page = 1;
    _hasMore = true;
    notifyListeners();
    loadPosts();
  }

  /// 是否应在切到分区 tab 时触发首次加载。
  bool get shouldLoadOnEnter => _posts.isEmpty && !_loading && _hasMore;

  /// 同步某帖的点赞状态到分区列表（由点赞处理统一调用，不单独通知）。
  void applyLikeUpdate(String postId, int? likesCount, bool? isLiked) {
    final idx = _posts.indexWhere((p) => p.id == postId);
    if (idx != -1) {
      _posts[idx].likesCount = likesCount ?? _posts[idx].likesCount;
      _posts[idx].isLiked = isLiked ?? !_posts[idx].isLiked;
    }
  }
}
