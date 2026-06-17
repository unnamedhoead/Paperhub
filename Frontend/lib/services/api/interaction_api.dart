import '../core/http_client.dart';

class InteractionApi {
  /// 点赞帖子
  static Future<Map<String, dynamic>> likePost(
    String postId, {
    String? authToken,
  }) async {
    return HttpClient.instance.post('/posts/$postId/like');
  }

  /// 取消点赞帖子
  static Future<Map<String, dynamic>> unlikePost(
    String postId, {
    String? authToken,
  }) async {
    return HttpClient.instance.delete('/posts/$postId/like');
  }

  /// 点赞评论
  static Future<Map<String, dynamic>> likeComment(
    String postId,
    String commentId, {
    String? authToken,
  }) async {
    return HttpClient.instance.post(
        '/posts/$postId/comments/$commentId/like');
  }

  /// 取消点赞评论
  static Future<Map<String, dynamic>> unlikeComment(
    String postId,
    String commentId, {
    String? authToken,
  }) async {
    return HttpClient.instance.delete(
        '/posts/$postId/comments/$commentId/like');
  }

  /// 收藏帖子
  static Future<Map<String, dynamic>> favoritePost(String postId) async {
    return HttpClient.instance.post('/posts/$postId/favorite');
  }

  /// 取消收藏帖子
  static Future<Map<String, dynamic>> unfavoritePost(String postId) async {
    return HttpClient.instance.delete('/posts/$postId/favorite');
  }

  /// 关注用户
  static Future<Map<String, dynamic>> followUser(String userId) async {
    return HttpClient.instance.post('/users/$userId/follow');
  }

  /// 取消关注用户
  static Future<Map<String, dynamic>> unfollowUser(String userId) async {
    return HttpClient.instance.delete('/users/$userId/follow');
  }

  /// 获取粉丝列表
  static Future<Map<String, dynamic>> getFollowers(
    String userId, {
    int page = 0,
    int pageSize = 20,
  }) async {
    return HttpClient.instance.get('/users/$userId/followers',
        queryParameters: {
          'page': page.toString(),
          'pageSize': pageSize.toString(),
        });
  }

  /// 获取关注列表
  static Future<Map<String, dynamic>> getFollowing(
    String userId, {
    int page = 0,
    int pageSize = 20,
  }) async {
    return HttpClient.instance.get('/users/$userId/following',
        queryParameters: {
          'page': page.toString(),
          'pageSize': pageSize.toString(),
        });
  }

  /// 获取互相关注列表
  static Future<Map<String, dynamic>> getMutualFollowers(
    String userId, {
    int page = 0,
    int pageSize = 20,
  }) async {
    return HttpClient.instance.get('/users/$userId/mutual',
        queryParameters: {
          'page': page.toString(),
          'pageSize': pageSize.toString(),
        });
  }

  /// 获取未读通知数量
  /// GET /notifications/unread-count
  static Future<Map<String, dynamic>> getUnreadNotificationCount() async {
    return HttpClient.instance.get('/notifications/unread-count');
  }

  /// 获取赞和收藏通知
  /// GET /notifications/likes?page=0&pageSize=20
  static Future<Map<String, dynamic>> getLikesAndFavorites({
    int page = 0,
    int pageSize = 20,
  }) async {
    return HttpClient.instance.get('/notifications/likes',
        queryParameters: {
          'page': page.toString(),
          'pageSize': pageSize.toString(),
        });
  }

  /// 获取关注通知
  /// GET /notifications/follows?page=0&pageSize=20
  static Future<Map<String, dynamic>> getFollows({
    int page = 0,
    int pageSize = 20,
  }) async {
    return HttpClient.instance.get('/notifications/follows',
        queryParameters: {
          'page': page.toString(),
          'pageSize': pageSize.toString(),
        });
  }

  /// 获取评论和@通知
  /// GET /notifications/comments?page=0&pageSize=20
  static Future<Map<String, dynamic>> getCommentsAndMentions({
    int page = 0,
    int pageSize = 20,
  }) async {
    return HttpClient.instance.get('/notifications/comments',
        queryParameters: {
          'page': page.toString(),
          'pageSize': pageSize.toString(),
        });
  }

  /// 标记通知为已读
  /// PUT /notifications/{id}/read
  static Future<Map<String, dynamic>> markNotificationAsRead(
    String notificationId,
  ) async {
    return HttpClient.instance.put('/notifications/$notificationId/read');
  }

  /// 批量标记指定类型的所有未读通知为已读
  /// PUT /notifications/mark-all-read?types=POST_LIKE,POST_FAVORITE
  static Future<Map<String, dynamic>> markAllNotificationsAsReadByTypes(
    List<String> types,
  ) async {
    final typesParam = types.join(',');
    return HttpClient.instance.put(
        '/notifications/mark-all-read?types=$typesParam');
  }

  /// 创建通知
  static Future<Map<String, dynamic>> createNotification(
    Map<String, dynamic> payload, {
    String? authToken,
  }) async {
    return HttpClient.instance.post('/notifications', body: payload);
  }
}
