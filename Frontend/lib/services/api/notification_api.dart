import '../core/http_client.dart';

/// Notification API — unread counts, notification lists, and read marking.
class NotificationApi {
  /// Get unread notification counts (GET /notifications/unread-count).
  static Future<Map<String, dynamic>> getUnreadNotificationCount() async {
    return HttpClient.instance.get('/notifications/unread-count');
  }

  /// Get likes and favorites notifications (GET /notifications/likes).
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

  /// Get follow notifications (GET /notifications/follows).
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

  /// Get comment and @mention notifications (GET /notifications/comments).
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

  /// Mark a single notification as read (PUT /notifications/{id}/read).
  static Future<Map<String, dynamic>> markNotificationAsRead(
    String notificationId,
  ) async {
    return HttpClient.instance.put('/notifications/$notificationId/read');
  }

  /// Mark all unread notifications of given types as read
  /// (PUT /notifications/mark-all-read?types=...).
  static Future<Map<String, dynamic>> markAllNotificationsAsReadByTypes(
    List<String> types,
  ) async {
    final typesParam = types.join(',');
    return HttpClient.instance.put(
        '/notifications/mark-all-read?types=$typesParam');
  }

  /// Create a notification (POST /notifications).
  static Future<Map<String, dynamic>> createNotification(
    Map<String, dynamic> payload,
  ) async {
    return HttpClient.instance.post('/notifications', body: payload);
  }
}
