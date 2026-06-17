/// 帖子详情页「评论子系统」控制器（ChangeNotifier）。
///
/// 由 [PostDetailController] 组合持有，专管评论树相关的数据状态与业务：
/// 评论列表与分页加载、回复目标、提交/删除评论、评论点赞、以及 WebSocket 推送的
/// 评论增删改。评论树的纯算法在 [CommentTreeOps] 里，本类只负责状态/网络/通知。
///
/// 不持有 BuildContext / TextEditingController；@提及文本解析等输入层职责留在 Screen。
/// 需要 UI 提示时通过 [onMessage] 回调通知。直接复用传入的 [post] 对象维护 commentsCount，
/// 与原 `_PostDetailScreenState` 行为一致。
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/post_model.dart';
import '../../services/api_service.dart';
import 'comment_tree_ops.dart';

/// 评论子系统控制器。
class PostCommentController extends ChangeNotifier {
  PostCommentController({required Post post}) : _post = post;

  final Post _post;

  /// 显示一条提示（SnackBar）。Screen 注入。
  void Function(String message)? onMessage;

  /// 评论列表。
  List<Comment> _comments = [];
  List<Comment> get comments => _comments;

  /// 评论加载状态。
  bool isLoadingComments = false;
  bool hasMoreComments = true;
  int _currentPage = 1;
  static const int _pageSize = 20;

  /// 评论点赞防抖集合（commentId）。
  final Set<String> _commentLikeInFlight = {};

  /// 该评论是否正在点赞请求中（供 UI 临时禁用按钮）。
  bool isCommentLikeInFlight(String commentId) =>
      _commentLikeInFlight.contains(commentId);

  bool isSubmittingComment = false;

  /// 当前回复的评论。
  Comment? currentReplyTo;

  /// 当前回复的父评论 ID。
  String? currentReplyParentId;

  // ===== 加载 =====

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
      }

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
  /// [onDeletingChanged] 把删除中状态回传给 [PostDetailController]（驱动整页遮罩）。
  Future<void> deleteComment(
    Comment comment, {
    required bool isTopLevel,
    Comment? parentComment,
    void Function(bool deleting)? onDeletingChanged,
  }) async {
    onDeletingChanged?.call(true);

    try {
      final resp = await ApiService.deleteComment(_post.id, comment.id);
      if (resp['statusCode'] == 204 || resp['statusCode'] == 200) {
        if (isTopLevel) {
          final delta = CommentTreeOps.removeDeleted(_comments, comment.id);
          _decreaseCount(delta);
        } else if (parentComment != null) {
          final hit = CommentTreeOps.removeReply(
            _comments,
            parentComment,
            comment.id,
          );
          if (hit) _decreaseCount(1);
        }
        notifyListeners();
        onMessage?.call('评论已删除');
      } else {
        onMessage?.call('删除失败，请稍后重试');
      }
    } catch (e) {
      onMessage?.call('删除失败: $e');
    } finally {
      onDeletingChanged?.call(false);
    }
  }

  // ===== 点赞 =====

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

  // ===== WebSocket 推送应用（委托 CommentTreeOps 做纯算法）=====

  /// 应用 WebSocket 推送的「评论点赞变更」。
  void applyCommentLikeUpdate(Map<String, dynamic> data) {
    final commentId = data['commentId'] as String;
    if (CommentTreeOps.applyLikeUpdate(_comments, commentId, data)) {
      notifyListeners();
    }
  }

  /// 应用 WebSocket 推送的「新评论」。
  void applyCommentCreated(Map<String, dynamic> data) {
    final commentJson = CommentTreeOps.extractCommentJson(data);
    if (commentJson == null) return;
    try {
      final newComment = Comment.fromJson(commentJson);
      final delta = CommentTreeOps.insertCreated(_comments, newComment);
      if (delta > 0) {
        _post.commentsCount += delta;
        notifyListeners();
      }
    } catch (e) {
      // ignore: 如果解析失败则不阻塞。
    }
  }

  /// 应用 WebSocket 推送的「评论更新」。
  void applyCommentUpdated(Map<String, dynamic> data) {
    final commentJson = CommentTreeOps.extractCommentJson(data);
    if (commentJson == null) return;
    try {
      final updated = Comment.fromJson(commentJson);
      if (CommentTreeOps.applyUpdated(_comments, updated)) {
        notifyListeners();
      }
    } catch (e) {
      // ignore
    }
  }

  /// 应用 WebSocket 推送的「评论删除」。
  void applyCommentDeleted(Map<String, dynamic> data) {
    final commentId = CommentTreeOps.extractDeletedId(data);
    if (commentId == null) return;
    final delta = CommentTreeOps.removeDeleted(_comments, commentId);
    if (delta > 0) {
      _decreaseCount(delta);
      notifyListeners();
    }
  }

  void _decreaseCount(int delta) {
    _post.commentsCount =
        (_post.commentsCount >= delta) ? _post.commentsCount - delta : 0;
  }
}
