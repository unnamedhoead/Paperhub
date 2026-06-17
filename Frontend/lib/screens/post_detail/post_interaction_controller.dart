/// 帖子详情页「互动子系统」控制器（ChangeNotifier）。
///
/// 由 [PostDetailController] 组合持有，专管帖子级互动状态与逻辑：点赞、收藏、关注作者
/// （乐观更新 + 失败回滚）。同时承接 WebSocket 推送的 like_update / favorite_update。
///
/// 不持有 BuildContext；当前用户 ID 通过 [currentUserId] 取值器读取（其值由父控制器
/// 异步更新）。需要 UI 提示 / 点赞动画时通过 [onMessage] / [onLikeAnimation] 回调通知。
/// 直接复用传入的 [post] 对象，与原 `_PostDetailScreenState` 行为一致。
library;

import 'package:flutter/foundation.dart';

import '../../models/post_model.dart';
import '../../models/user_profile.dart';
import '../../services/api_service.dart';

/// 互动子系统控制器。
class PostInteractionController extends ChangeNotifier {
  PostInteractionController({
    required Post post,
    required this.currentUserId,
  }) : _post = post {
    isLiked = post.isLiked;
    isSaved = post.isSaved;
    likeCount = post.likesCount;
  }

  final Post _post;

  /// 当前登录用户 ID 取值器（值由父控制器异步刷新）。
  final String? Function() currentUserId;

  /// 显示一条提示（SnackBar）。父控制器注入。
  void Function(String message)? onMessage;

  /// 点赞成功后回调（Screen 据此播放大爱心动画）。
  VoidCallback? onLikeAnimation;

  late bool isLiked;
  late bool isSaved;
  late int likeCount;

  /// 是否关注了作者（null 表示不显示关注按钮，如查看自己的帖子）。
  bool? isFollowingAuthor;

  /// 关注操作进行中。
  bool followInFlight = false;

  bool _postLikeInFlight = false;
  bool _saveInFlight = false;

  // ===== WebSocket / 详情刷新同步 =====

  /// 详情刷新后，用最新 post 数据同步点赞状态。
  void syncLikeFromPost() {
    isLiked = _post.isLiked;
    likeCount = _post.likesCount;
    notifyListeners();
  }

  /// 应用 WebSocket 推送的帖子点赞变更。
  void applyLikeUpdate(Map<String, dynamic> data) {
    if (data.containsKey('likesCount')) likeCount = data['likesCount'] as int;
    if (data.containsKey('isLiked')) isLiked = data['isLiked'] as bool;
    notifyListeners();
  }

  /// 应用 WebSocket 推送的帖子收藏变更。
  void applyFavoriteUpdate(Map<String, dynamic> data) {
    if (data.containsKey('favoriteCount')) {
      _post.favoriteCount = data['favoriteCount'] as int;
    }
    if (data.containsKey('isSaved')) {
      _post.isSaved = data['isSaved'] as bool;
    }
    notifyListeners();
  }

  // ===== 关注 =====

  /// 检查是否已关注作者。
  Future<void> checkFollowStatus() async {
    final uid = currentUserId();
    if (uid == null || _post.author.id.isEmpty) return;

    // 查看自己的帖子时不显示关注按钮。
    if (uid == _post.author.id) {
      isFollowingAuthor = null;
      notifyListeners();
      return;
    }
    try {
      final resp = await ApiService.getUserProfile(_post.author.id);
      if (resp['statusCode'] == 200) {
        final body = resp['body'] as Map<String, dynamic>;
        final profile = UserProfile.fromJson(body);
        isFollowingAuthor = profile.isFollowing ?? false;
        notifyListeners();
      }
    } catch (e) {
      isFollowingAuthor = false; // 获取失败默认未关注。
      notifyListeners();
    }
  }

  /// 切换关注状态。
  Future<void> toggleFollow() async {
    if (followInFlight || isFollowingAuthor == null) return;

    final authorId = _post.author.id;
    if (authorId.isEmpty || currentUserId() == authorId) return;

    final prev = isFollowingAuthor!;
    final next = !prev;

    followInFlight = true;
    isFollowingAuthor = next;
    notifyListeners();

    try {
      final resp = next
          ? await ApiService.followUser(authorId)
          : await ApiService.unfollowUser(authorId);

      if (resp['statusCode'] != 200) {
        throw Exception(
          (resp['body'] as Map<String, dynamic>?)?['message'] ?? '操作失败',
        );
      }

      onMessage?.call(next ? '已关注 ${_post.author.name}' : '已取消关注');
    } catch (e) {
      isFollowingAuthor = prev; // 回滚。
      notifyListeners();
      onMessage?.call('操作失败：$e');
    } finally {
      followInFlight = false;
      notifyListeners();
    }
  }

  // ===== 点赞 =====

  Future<void> handlePostLikePressed() async {
    if (_postLikeInFlight) return; // 防止重复请求。
    _postLikeInFlight = true;

    final previousLiked = isLiked;
    final previousCount = likeCount;

    // 乐观更新。
    isLiked = !isLiked;
    likeCount += isLiked ? 1 : -1;
    _post.isLiked = isLiked;
    _post.likesCount = likeCount;
    notifyListeners();

    if (isLiked) onLikeAnimation?.call();

    try {
      final resp = isLiked
          ? await ApiService.likePost(_post.id)
          : await ApiService.unlikePost(_post.id);
      final status = (resp['statusCode'] ?? 500) as int;
      final body = resp['body'] as Map<String, dynamic>?;

      if (status >= 200 && status < 300) {
        // 如果后端返回了最新计数，则以后端为准；否则保持乐观更新。
        if (body != null &&
            body.containsKey('likesCount') &&
            body.containsKey('isLiked')) {
          likeCount = body['likesCount'] as int;
          isLiked = body['isLiked'] as bool;
          _post.likesCount = likeCount;
          _post.isLiked = isLiked;
          notifyListeners();
        }
      } else {
        _rollbackLike(previousLiked, previousCount);
        final msg = body != null && body['message'] != null
            ? body['message'].toString()
            : '点赞失败，请稍后重试';
        onMessage?.call(msg);
      }
    } catch (e) {
      _rollbackLike(previousLiked, previousCount);
      final errorMsg = e.toString().contains('超时')
          ? '请求超时，请检查网络连接'
          : '网络错误，点赞未成功，请稍后重试';
      onMessage?.call(errorMsg);
    } finally {
      _postLikeInFlight = false;
    }
  }

  void _rollbackLike(bool prevLiked, int prevCount) {
    isLiked = prevLiked;
    likeCount = prevCount;
    _post.isLiked = prevLiked;
    _post.likesCount = prevCount;
    notifyListeners();
  }

  // ===== 收藏 =====

  Future<void> toggleSave() async {
    if (_saveInFlight) return;
    _saveInFlight = true;
    final previousSaved = isSaved;
    // 只对收藏状态做乐观更新，不对数量做乐观更新。
    isSaved = !isSaved;
    _post.isSaved = isSaved;
    notifyListeners();
    try {
      final resp = isSaved
          ? await ApiService.favoritePost(_post.id)
          : await ApiService.unfavoritePost(_post.id);
      final status = resp['statusCode'] as int? ?? 500;
      final body = resp['body'] as Map<String, dynamic>?;
      if (status >= 200 && status < 300) {
        if (body != null) {
          final serverValue = body['isSaved'] as bool?;
          final serverFavoritesCount = body['favoritesCount'] as int?;
          if (serverValue != null) {
            isSaved = serverValue;
            _post.isSaved = serverValue;
          }
          if (serverFavoritesCount != null) {
            _post.favoriteCount = serverFavoritesCount;
          }
          notifyListeners();
        }
      } else {
        isSaved = previousSaved;
        _post.isSaved = previousSaved;
        notifyListeners();
        final msg = body != null && body['message'] != null
            ? body['message'].toString()
            : '收藏操作失败';
        onMessage?.call(msg);
      }
    } catch (e) {
      isSaved = previousSaved;
      _post.isSaved = previousSaved;
      notifyListeners();
      onMessage?.call('网络错误，收藏操作未成功');
    } finally {
      _saveInFlight = false;
    }
  }
}
