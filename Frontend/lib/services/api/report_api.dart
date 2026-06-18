import '../core/http_client.dart';

class ReportApi {
  /// 举报帖子
  static Future<Map<String, dynamic>> reportPost({
    required int postId,
    required String description,
  }) async {
    return HttpClient.instance.post('/posts/$postId/report', body: {
      'description': description,
    });
  }

  /// 举报用户
  static Future<Map<String, dynamic>> reportUser(
    String userId,
    String reason,
  ) async {
    return HttpClient.instance.post('/api/report/user/$userId', body: {
      'reason': reason,
    });
  }
}
