import '../core/http_client.dart';

/// Follow/Unfollow API — user relationship management endpoints.
class FollowApi {
  /// Follow a user (POST /users/{userId}/follow).
  static Future<Map<String, dynamic>> followUser(String userId) async {
    return HttpClient.instance.post('/users/$userId/follow');
  }

  /// Unfollow a user (DELETE /users/{userId}/follow).
  static Future<Map<String, dynamic>> unfollowUser(String userId) async {
    return HttpClient.instance.delete('/users/$userId/follow');
  }

  /// Get followers list (GET /users/{userId}/followers).
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

  /// Get following list (GET /users/{userId}/following).
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

  /// Get mutual followers list (GET /users/{userId}/mutual).
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
}
