import '../core/http_client.dart';

class CommentApi {
  /// 获取帖子的评论列表
  /// @param postId 帖子 ID
  /// @param page 分页页码（从 1 开始）
  /// @param pageSize 每页数量，默认 20
  /// @param sort 排序方式，支持 'time'（时间）和 'hot'（热度），默认按时间
  static Future<Map<String, dynamic>> getComments(
    String postId, {
    int page = 1,
    int pageSize = 20,
    String sort = 'time',
  }) async {
    return HttpClient.instance.get('/posts/$postId/comments',
        queryParameters: {
          'page': page.toString(),
          'pageSize': pageSize.toString(),
          'sort': sort,
        });
  }

  /// 发布评论
  /// @param postId 帖子 ID
  /// @param content 评论内容
  /// @param parentId 回复的父评论 ID（可选，用于嵌套回复）
  /// @param replyToId 被回复用户 ID（可选，用于 @ 通知）
  static Future<Map<String, dynamic>> createComment(
    String postId,
    String content, {
    String? parentId,
    String? replyToId,
    List<String>? mentionIds,
  }) async {
    final body = <String, dynamic>{
      'content': content,
      if (parentId != null) 'parentId': parentId,
      if (replyToId != null) 'replyToId': replyToId,
      if (mentionIds != null && mentionIds.isNotEmpty) 'mentionIds': mentionIds,
    };
    return HttpClient.instance.post('/posts/$postId/comments', body: body);
  }

  /// 更新评论（仅评论作者可操作）
  static Future<Map<String, dynamic>> updateComment(
    String postId,
    String commentId,
    String content,
  ) async {
    return HttpClient.instance.put('/posts/$postId/comments/$commentId', body: {
      'content': content,
    });
  }

  /// 删除评论（仅评论作者或帖子作者可操作）
  static Future<Map<String, dynamic>> deleteComment(
    String postId,
    String commentId,
  ) async {
    return HttpClient.instance.delete('/posts/$postId/comments/$commentId');
  }

  /// 举报评论
  static Future<Map<String, dynamic>> reportComment(
    String postId,
    String commentId,
    String reason,
  ) async {
    return HttpClient.instance.post(
        '/posts/$postId/comments/$commentId/report',
        body: {'reason': reason});
  }
}
