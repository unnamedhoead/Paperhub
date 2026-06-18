import '../core/http_client.dart';

class AdminApi {
  /// 管理员搜索用户（用于"用户管理"页面）
  /// GET /admin/users?q=...&page=&pageSize=
  static Future<Map<String, dynamic>> adminSearchUsers({
    String? query,
    String? status,
    int page = 0,
    int pageSize = 20,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    };
    if (query != null && query.trim().isNotEmpty) {
      params['q'] = query.trim();
    }
    if (status != null && status.trim().isNotEmpty) {
      params['status'] = status.trim();
    }
    return HttpClient.instance.get('/admin/users', queryParameters: params);
  }

  /// 获取所有待审核用户（status = AUDIT）
  /// GET /admin/users/audit-list
  static Future<Map<String, dynamic>> getAuditUsers() async {
    return HttpClient.instance.get('/admin/users/audit-list');
  }

  /// 审核通过用户
  static Future<Map<String, dynamic>> adminApproveUser(String userId) async {
    return HttpClient.instance.post('/admin/users/$userId/approve');
  }

  /// 审核拒绝用户
  static Future<Map<String, dynamic>> adminRejectUser(
    String userId, {
    required String action,
    String? reason,
  }) async {
    final body = <String, dynamic>{
      'action': action,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    };
    return HttpClient.instance.post('/admin/users/$userId/reject', body: body);
  }

  /// 帖子下架
  /// POST /admin/posts/{postId}/hide
  static Future<Map<String, dynamic>> adminHidePost(String postId) async {
    return HttpClient.instance.post('/admin/posts/$postId/hide');
  }

  /// 管理员搜索帖子
  /// GET /admin/posts?q=&author=&page=&pageSize=
  static Future<Map<String, dynamic>> adminSearchPosts({
    String? query,
    String? author,
    int page = 0,
    int pageSize = 20,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    };
    if (query != null && query.trim().isNotEmpty) {
      params['q'] = query.trim();
    }
    if (author != null && author.trim().isNotEmpty) {
      params['author'] = author.trim();
    }
    return HttpClient.instance.get('/admin/posts', queryParameters: params);
  }

  /// 获取公告列表
  /// GET /admin/notices?q=&page=&pageSize=
  static Future<Map<String, dynamic>> adminGetNotices({
    String? query,
    int page = 0,
    int pageSize = 20,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    };
    if (query != null && query.trim().isNotEmpty) {
      params['q'] = query.trim();
    }
    return HttpClient.instance.get('/admin/notices', queryParameters: params);
  }

  /// 创建公告
  static Future<Map<String, dynamic>> adminCreateNotice({
    required String title,
    String? content,
    String? attachmentsJson,
    bool published = true,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      if (content != null) 'content': content,
      if (attachmentsJson != null) 'attachments': attachmentsJson,
      'published': published,
    };
    return HttpClient.instance.post('/admin/notices', body: body);
  }

  /// 更新公告
  static Future<Map<String, dynamic>> adminUpdateNotice({
    required String id,
    required String title,
    String? content,
    String? attachmentsJson,
    bool published = true,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      if (content != null) 'content': content,
      if (attachmentsJson != null) 'attachments': attachmentsJson,
      'published': published,
    };
    return HttpClient.instance.put('/admin/notices/$id', body: body);
  }

  /// 删除公告
  static Future<Map<String, dynamic>> adminDeleteNotice(String id) async {
    return HttpClient.instance.delete('/admin/notices/$id');
  }

  /// 获取举报列表
  /// GET /admin/reports?q=&status=&targetType=&page=&pageSize=
  static Future<Map<String, dynamic>> adminGetReports({
    String? query,
    String? status,
    String? targetType,
    int page = 0,
    int pageSize = 20,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    };
    if (query != null && query.trim().isNotEmpty) {
      params['q'] = query.trim();
    }
    if (status != null && status.isNotEmpty) {
      params['status'] = status;
    }
    if (targetType != null && targetType.isNotEmpty) {
      params['targetType'] = targetType;
    }
    return HttpClient.instance.get('/admin/reports', queryParameters: params);
  }

  /// 处理举报
  /// POST /admin/reports/{id}/handle
  static Future<Map<String, dynamic>> adminHandleReport({
    required String id,
    required String action, // DELETE_POST / NO_VIOLATION / BAN_USER
    String? note,
  }) async {
    final body = <String, dynamic>{
      'action': action,
      if (note != null && note.isNotEmpty) 'resolutionNote': note,
    };
    return HttpClient.instance.post('/admin/reports/$id/handle', body: body);
  }

  /// 创建管理员申请（由管理员或超管发起）
  /// POST /admin/applications
  static Future<Map<String, dynamic>> adminCreateApplication({
    required String candidateUserId,
    required String reason,
  }) async {
    final payload = {
      'candidateUserId': int.tryParse(candidateUserId) ?? candidateUserId,
      'reason': reason,
    };
    return HttpClient.instance.post('/admin/applications', body: payload);
  }

  /// 获取管理员申请列表（仅超级管理员）
  /// GET /admin/applications?status=&page=&pageSize=
  static Future<Map<String, dynamic>> adminGetApplications({
    String? status,
    int page = 0,
    int pageSize = 20,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    };
    if (status != null && status.isNotEmpty) {
      params['status'] = status;
    }
    return HttpClient.instance.get('/admin/applications',
        queryParameters: params);
  }

  /// 审批通过管理员申请
  static Future<Map<String, dynamic>> adminApproveApplication(String id) async {
    return HttpClient.instance.post('/admin/applications/$id/approve');
  }

  /// 拒绝管理员申请
  static Future<Map<String, dynamic>> adminRejectApplication(String id) async {
    return HttpClient.instance.post('/admin/applications/$id/reject');
  }

  /// 授予管理员权限（仅超级管理员）
  static Future<Map<String, dynamic>> adminGrantAdmin(String userId) async {
    return HttpClient.instance
        .post('/admin/permissions/$userId/grant-admin');
  }

  /// 收回管理员权限（仅超级管理员）
  static Future<Map<String, dynamic>> adminRevokeAdmin(String userId) async {
    return HttpClient.instance
        .post('/admin/permissions/$userId/revoke-admin');
  }

  /// 封禁用户
  static Future<Map<String, dynamic>> adminBanUser(String userId) async {
    return HttpClient.instance.post('/admin/users/$userId/ban');
  }

  /// 解封用户
  static Future<Map<String, dynamic>> adminUnbanUser(String userId) async {
    return HttpClient.instance.post('/admin/users/$userId/unban');
  }

  /// 禁言用户
  static Future<Map<String, dynamic>> adminMuteUser(
    String userId, {
    required int duration,
    required String unit, // HOURS / DAYS / MONTHS / YEARS
  }) async {
    return HttpClient.instance.post(
        '/admin/users/$userId/mute?duration=$duration&unit=$unit');
  }

  /// 解除禁言
  static Future<Map<String, dynamic>> adminUnmuteUser(String userId) async {
    return HttpClient.instance.post('/admin/users/$userId/unmute');
  }

  // ==================== 管理员端举报系统接口 ====================

  /// 管理员查看举报帖子列表
  static Future<Map<String, dynamic>> adminGetReportPosts({
    String? status,
    int page = 0,
    int pageSize = 20,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    };
    if (status != null && status.isNotEmpty) {
      params['status'] = status;
    }
    return HttpClient.instance.get('/api/admin/report/posts',
        queryParameters: params);
  }

  /// 管理员下架帖子（通过举报）
  static Future<Map<String, dynamic>> adminRemovePost({
    required int reportId,
    required String reason,
  }) async {
    return HttpClient.instance.post('/api/admin/report/$reportId/remove',
        body: {'reason': reason});
  }

  /// 管理员忽略举报
  static Future<Map<String, dynamic>> adminIgnoreReport({
    required int reportId,
    String? reason,
  }) async {
    return HttpClient.instance.post('/api/admin/report/$reportId/ignore',
        body: {'reason': reason ?? '未发现违规'});
  }

  /// 管理员审核通过帖子
  static Future<Map<String, dynamic>> adminApprovePost(int postId) async {
    return HttpClient.instance.post('/api/admin/post/$postId/approve');
  }

  /// 管理员拒绝审核帖子
  static Future<Map<String, dynamic>> adminRejectPost({
    required int postId,
    required String reason,
  }) async {
    return HttpClient.instance.post('/api/admin/post/$postId/reject',
        body: {'reason': reason});
  }

  /// 管理员查询待审核的帖子列表
  static Future<Map<String, dynamic>> adminGetAuditPosts({
    int page = 0,
    int pageSize = 20,
  }) async {
    return HttpClient.instance.get('/api/admin/post/audit',
        queryParameters: {
          'page': page.toString(),
          'pageSize': pageSize.toString(),
        });
  }

  /// 管理员统计待处理举报数量
  static Future<Map<String, dynamic>> adminCountPendingReports() async {
    return HttpClient.instance.get('/api/admin/report/count');
  }

  /// 管理员审核通过AUDIT状态帖子
  static Future<Map<String, dynamic>> adminApproveAuditPost({
    required int postId,
  }) async {
    return HttpClient.instance
        .post('/admin/post/$postId/approve-audit');
  }

  /// 管理员打回AUDIT状态帖子
  static Future<Map<String, dynamic>> adminRejectAuditPost({
    required int postId,
    required String reason,
  }) async {
    return HttpClient.instance.post('/admin/post/$postId/reject-audit',
        body: {'reason': reason});
  }
}
