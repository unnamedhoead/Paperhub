/// 评论树纯函数工具：对 `List<Comment>`（含一层 replies 楼中楼）做原地增删改。
///
/// 全部为无副作用的纯算法（不碰 BuildContext / 网络 / 状态通知），便于单测；
/// 由 [PostCommentController] 调用。返回值用于上层调整 `post.commentsCount`。
library;

import '../../models/post_model.dart';

/// 评论树操作。
class CommentTreeOps {
  const CommentTreeOps._();

  /// 列表中是否已存在该 id（顶层或任一楼中楼回复）。
  static bool exists(List<Comment> comments, String id) {
    if (comments.any((c) => c.id == id)) return true;
    for (final c in comments) {
      if (c.replies.any((r) => r.id == id)) return true;
    }
    return false;
  }

  /// 插入新评论。返回 commentsCount 应增加的数量（0 表示去重未插入）。
  static int insertCreated(List<Comment> comments, Comment newComment) {
    if (exists(comments, newComment.id)) return 0;

    if (newComment.parentId == null) {
      comments.insert(0, newComment);
      return 1;
    }
    final pIdx = comments.indexWhere((c) => c.id == newComment.parentId);
    if (pIdx != -1) {
      if (!comments[pIdx].replies.any((r) => r.id == newComment.id)) {
        comments[pIdx].replies.add(newComment);
        return 1;
      }
      return 0;
    }
    // parent 不在当前列表中，降级把回复插为顶层。
    comments.insert(0, newComment);
    return 1;
  }

  /// 用后端返回的更新内容替换对应评论（保留旧的 replies）。返回是否命中。
  static bool applyUpdated(List<Comment> comments, Comment updated) {
    final tIdx = comments.indexWhere((c) => c.id == updated.id);
    if (tIdx != -1) {
      comments[tIdx] = copyFromUpdated(updated, comments[tIdx].replies);
      return true;
    }
    for (final parent in comments) {
      final rIdx = parent.replies.indexWhere((r) => r.id == updated.id);
      if (rIdx != -1) {
        parent.replies[rIdx] =
            copyFromUpdated(updated, parent.replies[rIdx].replies);
        return true;
      }
    }
    return false;
  }

  /// 删除指定评论（顶层或楼中楼）。返回 commentsCount 应减少的数量（0 表示未命中）。
  static int removeDeleted(List<Comment> comments, String commentId) {
    final tIdx = comments.indexWhere((c) => c.id == commentId);
    if (tIdx != -1) {
      final deleted = comments[tIdx];
      final delta = 1 + deleted.replies.length;
      comments.removeAt(tIdx);
      return delta;
    }
    for (int i = 0; i < comments.length; i++) {
      final parent = comments[i];
      final rIdx = parent.replies.indexWhere((r) => r.id == commentId);
      if (rIdx != -1) {
        final updatedReplies =
            parent.replies.where((r) => r.id != commentId).toList();
        comments[i] = copyWithReplies(parent, updatedReplies);
        return 1;
      }
    }
    return 0;
  }

  /// 移除某顶层评论的某条回复（用于本地删除回复）。返回是否命中。
  static bool removeReply(
    List<Comment> comments,
    Comment parentComment,
    String replyId,
  ) {
    final parentIndex =
        comments.indexWhere((c) => c.id == parentComment.id);
    if (parentIndex == -1) return false;
    final updatedReplies =
        parentComment.replies.where((r) => r.id != replyId).toList();
    comments[parentIndex] = copyWithReplies(parentComment, updatedReplies);
    return true;
  }

  /// 应用评论点赞变更（顶层或楼中楼）。返回是否命中。
  static bool applyLikeUpdate(
    List<Comment> comments,
    String commentId,
    Map<String, dynamic> data,
  ) {
    final idx = comments.indexWhere((c) => c.id == commentId);
    if (idx != -1) {
      _applyLikeFields(comments[idx], data);
      return true;
    }
    for (final parent in comments) {
      final ridx = parent.replies.indexWhere((r) => r.id == commentId);
      if (ridx != -1) {
        _applyLikeFields(parent.replies[ridx], data);
        return true;
      }
    }
    return false;
  }

  static void _applyLikeFields(Comment c, Map<String, dynamic> data) {
    if (data.containsKey('likesCount')) {
      c.likesCount = data['likesCount'] as int;
    }
    if (data.containsKey('isLiked')) {
      c.isLiked = data['isLiked'] as bool;
    }
  }

  /// 用新的 replies 复制一份评论（其余字段不变）。
  static Comment copyWithReplies(Comment c, List<Comment> replies) => Comment(
        id: c.id,
        author: c.author,
        content: c.content,
        parentId: c.parentId,
        replyTo: c.replyTo,
        likesCount: c.likesCount,
        isLiked: c.isLiked,
        replies: replies,
        createdAt: c.createdAt,
      );

  /// 用后端返回的更新内容 + 保留的旧 replies 复制一份评论。
  static Comment copyFromUpdated(Comment updated, List<Comment> oldReplies) =>
      Comment(
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

  /// 从 WebSocket payload 中提取 comment JSON（兼容 comment/payload/data 键）。
  static Map<String, dynamic>? extractCommentJson(Map<String, dynamic> data) =>
      (data['comment'] ?? data['payload'] ?? data['data'])
          as Map<String, dynamic>?;

  /// 从 WebSocket payload 中提取被删除的 commentId（兼容 commentId/id/payload.id）。
  static String? extractDeletedId(Map<String, dynamic> data) =>
      (data['commentId'] ??
              data['id'] ??
              (data['payload'] is Map ? data['payload']['id'] : null))
          as String?;
}
