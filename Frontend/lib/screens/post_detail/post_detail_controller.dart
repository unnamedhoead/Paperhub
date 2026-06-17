/// 帖子详情页状态控制器（ChangeNotifier）。
///
/// 持有详情页的数据状态（帖子点赞/收藏计数、评论树、关注状态、当前用户、回复目标、
/// 图片真实尺寸、引用文献缓存、WebSocket 通道）与全部业务方法（加载详情/评论、点赞/
/// 收藏、关注切换、提交/删除评论、删除帖子、WebSocket 推送处理）。用 [notifyListeners]
/// 替代原 `_PostDetailScreenState` 中散落的 `setState`，驱动 Screen 整页 rebuild，行为等价。
///
/// 遵循 state-management-convention.md 的「类型 A」：
/// Screen `addListener(() => setState(() {}))`，并在 dispose 时释放本控制器。
///
/// 不持有 BuildContext / Navigator / ScaffoldMessenger / TextEditingController /
/// AnimationController 等 UI 资源——需要 UI 副作用（SnackBar、导航、清空输入框、播放
/// 爱心动画）时，通过下列回调通知 Screen 执行：
/// [onMessage]（提示文案）、[onPostDeleted]（帖子删除后返回上一页）、
/// [onLikeAnimation]（点赞成功播放大爱心动画）。
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'; // ChangeNotifier / VoidCallback
// painting.dart 提供 NetworkImage / ImageStream 等图片解析类型。
import 'package:flutter/painting.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../config/app_env.dart';
import '../../models/post_model.dart';
import '../../models/user_profile.dart';
import '../../services/api_service.dart';

/// 详情页数据状态控制器。
class PostDetailController extends ChangeNotifier {
  PostDetailController({required Post post}) : _post = post {
    isLiked = post.isLiked;
    isSaved = post.isSaved;
    likeCount = post.likesCount;
    _currentPostStatus = post.status;
  }

  // ===== 依赖回调（Screen 注入，用于触发需要 BuildContext 的副作用）=====

  /// 显示一条提示（SnackBar）。Screen 注入。
  void Function(String message)? onMessage;

  /// 帖子删除成功后回调（Screen 据此 pop 返回上一页）。
  VoidCallback? onPostDeleted;

  /// 帖子点赞成功后回调（Screen 据此播放大爱心动画）。
  VoidCallback? onLikeAnimation;

  // ===== 数据状态 =====

  final Post _post;
  Post get post => _post;

  WebSocketChannel? _wsChannel;

  late bool isLiked;
  late bool isSaved;
  late int likeCount;

  /// 当前回复的评论。
  Comment? currentReplyTo;

  /// 当前回复的父评论 ID。
  String? currentReplyParentId;

  /// 评论列表。
  List<Comment> _comments = [];
  List<Comment> get comments => _comments;

  /// 评论加载状态。
  bool isLoadingComments = false;
  bool hasMoreComments = true;
  int _currentPage = 1;
  static const int _pageSize = 20;

  /// 防止重复请求（帖子点赞）。
  bool _postLikeInFlight = false;

  /// 引用文献缓存，避免重复加载。
  final Map<int, Map<String, dynamic>> _referencePostCache = {};

  /// 评论点赞防抖集合（commentId）。
  final Set<String> _commentLikeInFlight = {};

  /// 该评论是否正在点赞请求中（供 UI 临时禁用按钮）。
  bool isCommentLikeInFlight(String commentId) =>
      _commentLikeInFlight.contains(commentId);

  bool isSubmittingComment = false;
  bool _saveInFlight = false;

  bool isDeleting = false;

  String? _currentUserId;
  String? get currentUserId => _currentUserId;

  /// 是否关注了作者（null 表示不显示关注按钮，如查看自己的帖子）。
  bool? isFollowingAuthor;

  /// 关注操作进行中。
  bool followInFlight = false;

  /// 当前帖子状态（从后端获取的最新状态）。
  String? _currentPostStatus;
  String? get currentPostStatus => _currentPostStatus;

  /// 图片实际尺寸（用于动态计算宽高比）。
  double? actualImageWidth;
  double? actualImageHeight;
  bool _isLoadingImageSize = false;

  /// 是否为帖子作者。
  bool get isOwner =>
      _currentUserId != null && _post.author.id == _currentUserId;

  /// 图片媒体（非 PDF）。
  List<String> get imageMedia => _post.media.where((m) => !isPdf(m)).toList();

  /// PDF 媒体。
  List<String> get pdfMedia => _post.media.where(isPdf).toList();

  // ===== 初始化与释放 =====

  /// 初始化：读取当前用户、拉取最新详情、加载评论、连接 WebSocket、检查关注状态、
  /// （必要时）加载图片真实尺寸。
  void init(String? userIdFromStorage) {
    _currentUserId = userIdFromStorage;
    loadPostDetail();
    loadComments();
    loadCurrentUserId();
    initWebSocket();
    checkFollowStatus();
    if (imageMedia.isNotEmpty &&
        _post.imageNaturalWidth == 800.0 &&
        _post.imageNaturalHeight == 600.0) {
      loadImageSize();
    }
  }

  @override
  void dispose() {
    _wsChannel?.sink.close();
    super.dispose();
  }

  // ===== 加载 =====

  Future<void> loadPostDetail() async {
    try {
      final resp = await ApiService.getPost(_post.id);
      final status = resp['statusCode'] as int? ?? 500;
      final body = resp['body'] as Map<String, dynamic>?;

      if (status >= 200 && status < 300 && body != null) {
        final updatedPost = Post.fromJson(body);
        isLiked = updatedPost.isLiked;
        likeCount = updatedPost.likesCount;
        _post.likesCount = updatedPost.likesCount;
        _post.isLiked = updatedPost.isLiked;
        _post.commentsCount = updatedPost.commentsCount;
        _currentPostStatus = updatedPost.status;
        notifyListeners();
      }
    } catch (e) {
      // 如果加载失败，使用传入的 post 对象；不显示错误，因为已经有初始数据。
    }
  }

  /// 检查是否已关注作者。
  Future<void> checkFollowStatus() async {
    if (_currentUserId == null || _post.author.id.isEmpty) {
      return;
    }

    // 如果是查看自己的帖子，不需要显示关注按钮。
    if (_currentUserId == _post.author.id) {
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
      // 如果获取失败，默认显示未关注。
      isFollowingAuthor = false;
      notifyListeners();
    }
  }

  /// 切换关注状态。
  Future<void> toggleFollow() async {
    if (followInFlight || isFollowingAuthor == null) return;

    final authorId = _post.author.id;
    if (authorId.isEmpty || _currentUserId == authorId) return;

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
      // 回滚状态。
      isFollowingAuthor = prev;
      notifyListeners();
      onMessage?.call('操作失败：$e');
    } finally {
      followInFlight = false;
      notifyListeners();
    }
  }

  Future<void> loadComments({bool refresh = false}) async {
    if (isLoadingComments) return;

    isLoadingComments = true;
    if (refresh) {
      _comments = [];
      _currentPage = 1;
      hasMoreComments = true;
    }
    notifyListeners();

    try {
      // 使用后端 API 加载评论（分页）。
      final resp = await ApiService.getComments(
        _post.id,
        page: _currentPage,
        pageSize: _pageSize,
      );

      final status = resp['statusCode'] as int? ?? 500;
      final body = resp['body'] as Map<String, dynamic>?;
      if (status >= 200 && status < 300 && body != null) {
        final commentsData =
            (body['comments'] as List<dynamic>?) ?? <dynamic>[];
        final total = body['total'] as int? ?? commentsData.length;

        final newComments = commentsData
            .map((c) => Comment.fromJson(c as Map<String, dynamic>))
            .toList();

        if (refresh) {
          _comments = newComments;
        } else {
          _comments.addAll(newComments);
        }

        hasMoreComments = _comments.length < total;
        _currentPage++;
      } else {
        final msg = body != null && body['message'] != null
            ? body['message'].toString()
            : '加载评论失败';
        onMessage?.call(msg);
      }
    } catch (e) {
      onMessage?.call('加载评论失败');
    } finally {
      isLoadingComments = false;
      notifyListeners();
    }
  }

  Future<void> loadCurrentUserId() async {
    try {
      final resp = await ApiService.getCurrentUserProfile();
      if (resp['statusCode'] == 200) {
        final body = resp['body'] as Map<String, dynamic>;
        _currentUserId = body['id']?.toString();
        notifyListeners();
      }
    } catch (e) {
      // 忽略错误。
    }
  }

  // ===== 回复状态 =====

  void startReply(Comment comment, {String? parentId}) {
    currentReplyTo = comment;
    currentReplyParentId = parentId ?? comment.id;
    notifyListeners();
  }

  void cancelReply() {
    currentReplyTo = null;
    currentReplyParentId = null;
    notifyListeners();
  }

  // ===== WebSocket =====

  /// 初始化 WebSocket 连接，监听后端推送的点赞/评论变更。
  void initWebSocket() {
    final wsUrl = 'ws:${AppEnv.apiBaseUrl}/ws/posts/${_post.id}';
    _wsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
    _wsChannel!.stream.listen(
      (event) {
        try {
          final data = jsonDecode(event);
          final type = data['type'] as String?;

          // 常见事件：
          // - like_update: 帖子点赞变化
          // - comment_like_update: 单条评论的点赞变化
          // - comment_created / comment_updated / comment_deleted
          // - favorite_update: 帖子收藏变化
          if (type == 'like_update') {
            if (data.containsKey('likesCount')) {
              likeCount = data['likesCount'] as int;
            }
            if (data.containsKey('isLiked')) {
              isLiked = data['isLiked'] as bool;
            }
            notifyListeners();
          } else if (type == 'favorite_update') {
            if (data.containsKey('favoriteCount')) {
              _post.favoriteCount = data['favoriteCount'] as int;
            }
            if (data.containsKey('isSaved')) {
              _post.isSaved = data['isSaved'] as bool;
            }
            notifyListeners();
          } else if (type == 'comment_like_update' &&
              data['commentId'] != null) {
            final commentId = data['commentId'] as String;
            final idx = _comments.indexWhere((c) => c.id == commentId);
            if (idx != -1) {
              if (data.containsKey('likesCount')) {
                _comments[idx].likesCount = data['likesCount'] as int;
              }
              if (data.containsKey('isLiked')) {
                _comments[idx].isLiked = data['isLiked'] as bool;
              }
              notifyListeners();
            } else {
              // 可能是子回复的点赞变化。
              for (var parent in _comments) {
                final ridx = parent.replies.indexWhere(
                  (r) => r.id == commentId,
                );
                if (ridx != -1) {
                  if (data.containsKey('likesCount')) {
                    parent.replies[ridx].likesCount =
                        data['likesCount'] as int;
                  }
                  if (data.containsKey('isLiked')) {
                    parent.replies[ridx].isLiked = data['isLiked'] as bool;
                  }
                  notifyListeners();
                  break;
                }
              }
            }
          } else if (type == 'comment_created') {
            handleCommentCreated(data);
          } else if (type == 'comment_updated') {
            handleCommentUpdated(data);
          } else if (type == 'comment_deleted') {
            handleCommentDeleted(data);
          }
        } catch (e) {
          // ignore: 格式或解析错误，避免影响主流程。
        }
      },
      onError: (err) {
        // 可选：记录错误或做重连策略。
      },
      onDone: () {
        // 可选：自动重连（根据实际需要实现）。
      },
    );
  }

  void handleCommentCreated(Map<String, dynamic> data) {
    final commentJson =
        (data['comment'] ?? data['payload'] ?? data['data'])
            as Map<String, dynamic>?;
    if (commentJson == null) return;

    try {
      final newComment = Comment.fromJson(commentJson);

      // 防止重复插入：检查顶层评论和所有子回复。
      bool exists = false;
      if (_comments.any((c) => c.id == newComment.id)) {
        exists = true;
      }
      if (!exists) {
        for (var comment in _comments) {
          if (comment.replies.any((r) => r.id == newComment.id)) {
            exists = true;
            break;
          }
        }
      }
      if (exists) {
        return; // 已存在，忽略。
      }

      if (newComment.parentId == null) {
        // 顶层评论，插入到顶部。
        _comments.insert(0, newComment);
        _post.commentsCount += 1;
      } else {
        // 找到父评论并追加到 replies。
        final pIdx = _comments.indexWhere((c) => c.id == newComment.parentId);
        if (pIdx != -1) {
          if (!_comments[pIdx].replies.any((r) => r.id == newComment.id)) {
            _comments[pIdx].replies.add(newComment);
            _post.commentsCount += 1;
          }
        } else {
          // parent 不在当前列表中，降级把回复插为顶层。
          _comments.insert(0, newComment);
          _post.commentsCount += 1;
        }
      }
      notifyListeners();
    } catch (e) {
      // ignore: 如果解析失败则不阻塞。
    }
  }

  void handleCommentUpdated(Map<String, dynamic> data) {
    final commentJson =
        (data['comment'] ?? data['payload'] ?? data['data'])
            as Map<String, dynamic>?;
    if (commentJson == null) return;

    try {
      final updated = Comment.fromJson(commentJson);

      // 先尝试在顶层查找。
      final tIdx = _comments.indexWhere((c) => c.id == updated.id);
      if (tIdx != -1) {
        // 保留子 replies（如果后端未返回）。
        final oldReplies = _comments[tIdx].replies;
        _comments[tIdx] = Comment(
          id: updated.id,
          author: updated.author,
          content: updated.content,
          parentId: updated.parentId,
          replyTo: updated.replyTo,
          likesCount: updated.likesCount,
          isLiked: updated.isLiked,
          replies: oldReplies,
          createdAt: updated.createdAt,
        );
        notifyListeners();
        return;
      }

      // 在子回复中查找。
      for (var parent in _comments) {
        final rIdx = parent.replies.indexWhere((r) => r.id == updated.id);
        if (rIdx != -1) {
          final oldReplies = parent.replies[rIdx].replies;
          parent.replies[rIdx] = Comment(
            id: updated.id,
            author: updated.author,
            content: updated.content,
            parentId: updated.parentId,
            replyTo: updated.replyTo,
            likesCount: updated.likesCount,
            isLiked: updated.isLiked,
            replies: oldReplies,
            createdAt: updated.createdAt,
          );
          notifyListeners();
          break;
        }
      }
    } catch (e) {
      // ignore
    }
  }

  void handleCommentDeleted(Map<String, dynamic> data) {
    final commentId =
        (data['commentId'] ??
                data['id'] ??
                (data['payload'] is Map ? data['payload']['id'] : null))
            as String?;
    if (commentId == null) return;

    // 从顶层删除。
    final tIdx = _comments.indexWhere((c) => c.id == commentId);
    if (tIdx != -1) {
      final deletedComment = _comments[tIdx];
      final deletedCount = 1 + deletedComment.replies.length;
      _comments.removeAt(tIdx);
      _post.commentsCount = (_post.commentsCount >= deletedCount)
          ? _post.commentsCount - deletedCount
          : 0;
      notifyListeners();
      return;
    }

    // 从子回复中删除。
    for (int i = 0; i < _comments.length; i++) {
      final parent = _comments[i];
      final rIdx = parent.replies.indexWhere((r) => r.id == commentId);
      if (rIdx != -1) {
        final updatedReplies = parent.replies
            .where((r) => r.id != commentId)
            .toList();
        _comments[i] = Comment(
          id: parent.id,
          author: parent.author,
          content: parent.content,
          parentId: parent.parentId,
          replyTo: parent.replyTo,
          likesCount: parent.likesCount,
          isLiked: parent.isLiked,
          replies: updatedReplies,
          createdAt: parent.createdAt,
        );
        _post.commentsCount =
            (_post.commentsCount > 0) ? _post.commentsCount - 1 : 0;
        notifyListeners();
        return;
      }
    }
  }

  // ===== 评论提交 / 删除 =====

  /// 提交评论。[text] 为已 trim 的评论内容，[mentionIds] 为有效的 @用户 ID 列表。
  /// 返回 true 表示创建成功（Screen 据此清空输入框、刷新评论）。
  Future<bool> submitComment({
    required String text,
    List<String>? mentionIds,
    String? parentId,
    Author? replyTo,
  }) async {
    if (text.isEmpty) return false;
    if (isSubmittingComment) return false;

    isSubmittingComment = true;
    notifyListeners();

    try {
      // 调用真实后端 API 创建评论。
      final resp = await ApiService.createComment(
        _post.id,
        text,
        parentId: parentId,
        replyToId: replyTo?.id,
        mentionIds: (mentionIds != null && mentionIds.isNotEmpty)
            ? mentionIds
            : null,
      );

      final status = resp['statusCode'] as int? ?? 500;
      final body = resp['body'] as Map<String, dynamic>?;

      if (status >= 200 && status < 300 && body != null) {
        // 手动增加评论总数（因为 WebSocket 推送不给自己）。
        _post.commentsCount += 1;
        notifyListeners();

        // 延迟刷新评论列表，给 WebSocket 推送一些时间。
        Future.delayed(const Duration(milliseconds: 500), () {
          loadComments(refresh: true);
        });

        onMessage?.call('评论发表成功');
        return true;
      } else {
        // 处理错误响应。
        String errorMsg = '评论失败，请稍后重试';
        if (status == 401 || status == 403) {
          errorMsg = body != null && body['message'] != null
              ? body['message'].toString()
              : '未认证，请先登录';
        } else if (body != null && body['message'] != null) {
          errorMsg = body['message'].toString();
        }
        onMessage?.call(errorMsg);
        return false;
      }
    } catch (e) {
      final errorMsg = e.toString().contains('超时')
          ? '请求超时，请检查网络连接'
          : '网络错误，评论未成功，请稍后重试';
      onMessage?.call(errorMsg);
      return false;
    } finally {
      isSubmittingComment = false;
      notifyListeners();
    }
  }

  /// 删除评论。确认对话框由 Screen 负责，此方法只在已确认后执行删除。
  Future<void> deleteComment(
    Comment comment, {
    required bool isTopLevel,
    Comment? parentComment,
  }) async {
    isDeleting = true;
    notifyListeners();

    try {
      final resp = await ApiService.deleteComment(_post.id, comment.id);
      if (resp['statusCode'] == 204 || resp['statusCode'] == 200) {
        if (isTopLevel) {
          // 计算需要减少的评论数（包括所有子回复）。
          final deletedCount = 1 + comment.replies.length;
          _comments.removeWhere((c) => c.id == comment.id);
          _post.commentsCount = (_post.commentsCount >= deletedCount)
              ? _post.commentsCount - deletedCount
              : 0;
        } else if (parentComment != null) {
          final parentIndex = _comments.indexWhere(
            (c) => c.id == parentComment.id,
          );
          if (parentIndex != -1) {
            final updatedReplies = parentComment.replies
                .where((r) => r.id != comment.id)
                .toList();
            _comments[parentIndex] = Comment(
              id: parentComment.id,
              author: parentComment.author,
              content: parentComment.content,
              parentId: parentComment.parentId,
              replyTo: parentComment.replyTo,
              likesCount: parentComment.likesCount,
              isLiked: parentComment.isLiked,
              replies: updatedReplies,
              createdAt: parentComment.createdAt,
            );
            _post.commentsCount =
                (_post.commentsCount > 0) ? _post.commentsCount - 1 : 0;
          }
        }
        onMessage?.call('评论已删除');
      } else {
        onMessage?.call('删除失败，请稍后重试');
      }
    } catch (e) {
      onMessage?.call('删除失败: $e');
    } finally {
      isDeleting = false;
      notifyListeners();
    }
  }

  // ===== 点赞 / 收藏 =====

  Future<void> handleCommentLikePressed(Comment c) async {
    if (_commentLikeInFlight.contains(c.id)) return;
    _commentLikeInFlight.add(c.id);

    final prevLiked = c.isLiked;
    final prevCount = c.likesCount;

    // 乐观更新。
    c.isLiked = !c.isLiked;
    c.likesCount += c.isLiked ? 1 : -1;
    notifyListeners();

    try {
      final resp = c.isLiked
          ? await ApiService.likeComment(_post.id, c.id)
          : await ApiService.unlikeComment(_post.id, c.id);

      final status = resp['statusCode'] as int? ?? 500;
      final body = resp['body'] as Map<String, dynamic>?;
      if (status >= 200 && status < 300 && body != null) {
        if (body.containsKey('likesCount')) {
          c.likesCount = body['likesCount'] as int;
        }
        if (body.containsKey('isLiked')) {
          c.isLiked = body['isLiked'] as bool;
        }
        notifyListeners();
      } else {
        // 回滚乐观更新。
        c.isLiked = prevLiked;
        c.likesCount = prevCount;
        notifyListeners();
        final msg = body != null && body['message'] != null
            ? body['message'].toString()
            : '操作失败';
        onMessage?.call(msg);
      }
    } catch (e) {
      c.isLiked = prevLiked;
      c.likesCount = prevCount;
      notifyListeners();
      onMessage?.call('网络错误，操作未成功');
    } finally {
      _commentLikeInFlight.remove(c.id);
    }
  }

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

    if (isLiked) {
      onLikeAnimation?.call();
    }

    try {
      final resp = isLiked
          ? await ApiService.likePost(_post.id)
          : await ApiService.unlikePost(_post.id);
      final status = (resp['statusCode'] ?? 500) as int;
      final body = resp['body'] as Map<String, dynamic>?;

      if (status >= 200 && status < 300) {
        // 如果后端返回了最新计数，则以后端为准。
        if (body != null &&
            body.containsKey('likesCount') &&
            body.containsKey('isLiked')) {
          likeCount = body['likesCount'] as int;
          isLiked = body['isLiked'] as bool;
          _post.likesCount = likeCount;
          _post.isLiked = isLiked;
          notifyListeners();
        }
        // 否则保持乐观更新。
      } else {
        // 请求失败 -> 回滚。
        isLiked = previousLiked;
        likeCount = previousCount;
        _post.isLiked = previousLiked;
        _post.likesCount = previousCount;
        notifyListeners();
        final msg = body != null && body['message'] != null
            ? body['message'].toString()
            : '点赞失败，请稍后重试';
        onMessage?.call(msg);
      }
    } catch (e) {
      // 网络或解析错误 -> 回滚。
      isLiked = previousLiked;
      likeCount = previousCount;
      _post.isLiked = previousLiked;
      _post.likesCount = previousCount;
      notifyListeners();
      final errorMsg = e.toString().contains('超时')
          ? '请求超时，请检查网络连接'
          : '网络错误，点赞未成功，请稍后重试';
      onMessage?.call(errorMsg);
    } finally {
      _postLikeInFlight = false;
    }
  }

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

  // ===== 删除帖子 =====

  /// 删除帖子。确认对话框由 Screen 负责，此方法只在已确认后执行删除。
  /// 成功后通过 [onPostDeleted] 通知 Screen 返回上一页。
  Future<void> deletePost() async {
    isDeleting = true;
    notifyListeners();
    try {
      final resp = await ApiService.deletePost(_post.id);
      final status = resp['statusCode'] as int? ?? 500;
      final body = resp['body'] as Map<String, dynamic>?;

      if (status >= 200 && status < 300) {
        onPostDeleted?.call();
        return;
      }

      final msg = body != null && body['message'] != null
          ? body['message'].toString()
          : '删除失败，请稍后重试';
      onMessage?.call(msg);
    } catch (e) {
      onMessage?.call('删除失败：$e');
    } finally {
      isDeleting = false;
      notifyListeners();
    }
  }

  // ===== 引用文献 =====

  Future<Map<String, dynamic>> fetchReferencePost(int postId) async {
    if (_referencePostCache.containsKey(postId)) {
      return _referencePostCache[postId]!;
    }
    final resp = await ApiService.getPost(postId.toString());
    if (resp['statusCode'] == 200) {
      final postData = resp['body'] as Map<String, dynamic>;
      _referencePostCache[postId] = postData;
      return postData;
    } else {
      throw Exception('无法获取引用帖子');
    }
  }

  // ===== 图片尺寸 =====

  Future<void> loadImageSize() async {
    if (_isLoadingImageSize || imageMedia.isEmpty) return;

    _isLoadingImageSize = true;
    notifyListeners();

    try {
      final imageUrl = imageMedia.first;
      final imageProvider = NetworkImage(imageUrl);

      final ImageStream stream = imageProvider.resolve(
        const ImageConfiguration(),
      );
      final Completer<void> completer = Completer<void>();

      ImageStreamListener? listener;
      listener = ImageStreamListener(
        (ImageInfo info, bool synchronousCall) {
          final image = info.image;
          actualImageWidth = image.width.toDouble();
          actualImageHeight = image.height.toDouble();
          _isLoadingImageSize = false;
          notifyListeners();

          stream.removeListener(listener!);
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        onError: (exception, stackTrace) {
          stream.removeListener(listener!);
          if (!completer.isCompleted) {
            completer.complete();
          }
          _isLoadingImageSize = false;
          notifyListeners();
        },
      );

      stream.addListener(listener);
      await completer.future;
    } catch (e) {
      _isLoadingImageSize = false;
      notifyListeners();
    }
  }

  // ===== 工具 =====

  /// 判断 URL 是否为 PDF。
  bool isPdf(String url) {
    if (url.isEmpty) return false;
    try {
      final uri = Uri.tryParse(url);
      final path = uri?.path.toLowerCase() ?? url.toLowerCase();
      if (path.endsWith('.pdf')) return true;
      if (path.contains('/pdf/') || path.contains('/pdfs/')) return true;
      final query = uri?.queryParameters;
      if (query != null) {
        final type =
            query['type']?.toLowerCase() ?? query['format']?.toLowerCase();
        if (type == 'pdf' || type == 'application/pdf') return true;
      }
      return false;
    } catch (_) {
      return url.toLowerCase().endsWith('.pdf');
    }
  }
}
