import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../config/app_env.dart';
import '../../services/api/admin_api.dart';
import '../../services/api/post_api.dart';

/// Shared state and business logic for the admin panel.
/// Owned by [AdminScreen], passed to section widgets.
class AdminController extends ChangeNotifier {
  AdminController({required this.role});

  final String role;

  bool get isSuperAdmin => role.toUpperCase() == 'SUPER_ADMIN';

  // ---- navigation ----
  AdminSection selectedSection = AdminSection.userReports;
  bool sidebarCollapsed = false;

  // ---- user management ----
  String userSearchKeyword = '';
  String userStatusFilter = 'NON_NORMAL';
  List<Map<String, dynamic>> userList = [];
  bool userLoading = false;
  int userPage = 0;
  int userTotal = 0;

  // ---- post management ----
  String postSearchKeyword = '';
  String postAuthorKeyword = '';
  List<Map<String, dynamic>> postList = [];
  bool postLoading = false;
  int postPage = 0;
  int postTotal = 0;

  // ---- report management ----
  String reportSearchKeyword = '';
  String reportStatus = '';
  String reportTargetType = '';
  List<Map<String, dynamic>> reportList = [];
  bool reportLoading = false;
  int reportPage = 0;
  int reportTotal = 0;
  WebSocketChannel? _wsChannel;

  // ---- audit users ----
  List<Map<String, dynamic>> auditUserList = [];
  bool auditUserLoading = false;
  String auditUserSearchKeyword = '';
  int auditUserPage = 0;
  static const int auditUserPageSize = 10;

  // ---- notices ----
  String noticeSearchKeyword = '';
  List<Map<String, dynamic>> noticeList = [];
  bool noticeLoading = false;
  int noticePage = 0;
  int noticeTotal = 0;

  // ---- applications ----
  List<Map<String, dynamic>> applicationList = [];
  bool applicationLoading = false;
  int applicationPage = 0;
  int applicationTotal = 0;

  // ---- permissions ----
  String adminSearchKeyword = '';
  String userSearchKeywordForGrant = '';
  List<Map<String, dynamic>> adminList = [];
  List<Map<String, dynamic>> normalUserList = [];
  bool permissionLoading = false;
  int adminPageLocal = 0;
  int normalPageLocal = 0;

  // ---- recommend ----
  String recommendSearchKeyword = '';
  List<Map<String, dynamic>> recommendUserList = [];
  bool recommendLoading = false;
  int recommendPage = 0;
  int recommendTotal = 0;

  // ---- lifecycle ----
  void init() {
    selectedSection = (isSuperAdmin
            ? AdminSection.users
            : AdminSection.userReports);
    _loadInitialData();
    _connectWebSocket();
  }

  /// Public wrapper to allow external callers to trigger a rebuild.
  void notify() => notifyListeners();

  @override
  void dispose() {
    _wsChannel?.sink.close();
    super.dispose();
  }

  // ==================== WebSocket ====================

  void _connectWebSocket() {
    try {
      final wsUrl = '${AppEnv.wsBaseUrl}/ws/admin';
      _wsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _wsChannel!.stream.listen(
        (event) {
          try {
            final data = jsonDecode(event);
            if (data['type'] == 'post_status_update') {
              _handlePostStatusUpdate(data);
            }
          } catch (e) {
            debugPrint('WebSocket message parse error: $e');
          }
        },
        onError: (error) {
          debugPrint('WebSocket error: $error');
        },
        onDone: () {
          debugPrint('WebSocket connection closed');
        },
      );
    } catch (e) {
      debugPrint('WebSocket connection error: $e');
    }
  }

  void _handlePostStatusUpdate(Map<String, dynamic> data) {
    if (selectedSection == AdminSection.postReports && !reportLoading) {
      loadReports(page: reportPage);
    }
  }

  // ==================== Initial load ====================

  Future<void> _loadInitialData() async {
    await Future.wait([
      if (isSuperAdmin) loadUsers(page: 0),
      if (isSuperAdmin) loadPosts(page: 0),
      loadReports(page: 0),
      loadAuditUsers(),
      if (isSuperAdmin) loadNotices(page: 0),
      if (isSuperAdmin) loadRecommendUsers(page: 0),
      if (isSuperAdmin) loadApplications(page: 0),
      if (isSuperAdmin) loadPermissionUsers(),
    ]);
  }

  // ==================== Data loading ====================

  Future<void> loadUsers({int page = 0}) async {
    userLoading = true;
    notifyListeners();
    try {
      const pageSize = 10;
      final resp = await AdminApi.adminSearchUsers(
        query: userSearchKeyword,
        status: userStatusFilter,
        page: page,
        pageSize: pageSize,
      );
      final body = resp['body'] as Map<String, dynamic>?;
      userList = (body?['users'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      userTotal = (body?['total'] as num?)?.toInt() ?? 0;
      userPage = (body?['page'] as num?)?.toInt() ?? page;
    } finally {
      userLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadPosts({int page = 0}) async {
    postLoading = true;
    notifyListeners();
    try {
      const pageSize = 10;
      final resp = await AdminApi.adminSearchPosts(
        query: postSearchKeyword,
        author: postAuthorKeyword,
        page: page,
        pageSize: pageSize,
      );
      final body = resp['body'] as Map<String, dynamic>?;
      postList = (body?['posts'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      postTotal = (body?['total'] as num?)?.toInt() ?? 0;
      postPage = (body?['page'] as num?)?.toInt() ?? page;
    } finally {
      postLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadReports({int page = 0}) async {
    reportLoading = true;
    notifyListeners();
    try {
      const pageSize = 10;
      final resp = await AdminApi.adminGetReportPosts(
        status: reportStatus.isEmpty ? null : reportStatus,
        page: page,
        pageSize: pageSize,
      );
      final body = resp['body'] as Map<String, dynamic>?;
      reportList = (body != null && body['reports'] is List)
          ? (body['reports'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
          : [];
      reportTotal = (body?['total'] as num?)?.toInt() ?? 0;
      reportPage = (body?['page'] as num?)?.toInt() ?? page;
    } finally {
      reportLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadAuditUsers() async {
    auditUserLoading = true;
    notifyListeners();
    try {
      final resp = await AdminApi.getAuditUsers();
      final body = resp['body'] as Map<String, dynamic>?;
      auditUserList = (body != null && body['users'] is List)
          ? (body['users'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
          : [];
    } finally {
      auditUserLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadApplications({int page = 0}) async {
    applicationLoading = true;
    notifyListeners();
    try {
      const pageSize = 10;
      final resp = await AdminApi.adminGetApplications(
        status: 'PENDING',
        page: page,
        pageSize: pageSize,
      );
      final body = resp['body'] as Map<String, dynamic>?;
      applicationList = (body?['applications'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      applicationTotal = (body?['total'] as num?)?.toInt() ?? 0;
      applicationPage = (body?['page'] as num?)?.toInt() ?? page;
    } finally {
      applicationLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadPermissionUsers() async {
    permissionLoading = true;
    notifyListeners();
    try {
      adminPageLocal = 0;
      normalPageLocal = 0;
      final adminResp = await AdminApi.adminSearchUsers(
        query: adminSearchKeyword,
        page: 0,
        pageSize: 100,
      );
      final adminBody = adminResp['body'] as Map<String, dynamic>?;
      final allUsers = (adminBody?['users'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      adminList = allUsers
          .where((u) => u['role'] == 'ADMIN' || u['role'] == 'SUPER_ADMIN')
          .toList();

      final userResp = await AdminApi.adminSearchUsers(
        query: userSearchKeywordForGrant,
        page: 0,
        pageSize: 100,
      );
      final userBody = userResp['body'] as Map<String, dynamic>?;
      final allUsers2 = (userBody?['users'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      normalUserList = allUsers2
          .where((u) => (u['role'] ?? '').toString() == 'USER')
          .toList();
    } finally {
      permissionLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadNotices({int page = 0}) async {
    noticeLoading = true;
    notifyListeners();
    try {
      const pageSize = 5;
      final resp = await AdminApi.adminGetNotices(
        query: noticeSearchKeyword,
        page: page,
        pageSize: pageSize,
      );
      final body = resp['body'] as Map<String, dynamic>?;
      noticeList = (body?['notices'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      noticeTotal = (body?['total'] as num?)?.toInt() ?? 0;
      noticePage = (body?['page'] as num?)?.toInt() ?? page;
    } finally {
      noticeLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadRecommendUsers({int page = 0}) async {
    recommendLoading = true;
    notifyListeners();
    try {
      const pageSize = 10;
      final resp = await AdminApi.adminSearchUsers(
        query: recommendSearchKeyword,
        page: page,
        pageSize: pageSize,
      );
      final body = resp['body'] as Map<String, dynamic>?;
      final users = (body?['users'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      recommendUserList =
          users.where((u) => (u['role'] ?? '').toString() == 'USER').toList();
      recommendTotal = (body?['total'] as num?)?.toInt() ?? 0;
      recommendPage = (body?['page'] as num?)?.toInt() ?? page;
    } finally {
      recommendLoading = false;
      notifyListeners();
    }
  }

  // ==================== Simple actions (API calls) ====================

  Future<void> banUser(String userId) async {
    if (userId.isEmpty) return;
    final resp = await AdminApi.adminBanUser(userId);
    final msg = resp['body']?['message']?.toString() ?? '操作已提交';
    return _afterAction(msg, () => loadUsers());
  }

  Future<void> unbanUser(String userId) async {
    if (userId.isEmpty) return;
    final resp = await AdminApi.adminUnbanUser(userId);
    final msg = resp['body']?['message']?.toString() ?? '操作已提交';
    return _afterAction(msg, () => loadUsers());
  }

  Future<void> banUserAndRefresh(String userId) async {
    if (userId.isEmpty) return;
    final resp = await AdminApi.adminBanUser(userId);
    final msg = resp['body']?['message']?.toString() ?? '操作已提交';
    return _afterAction(msg, () => loadAuditUsers());
  }

  Future<void> unbanUserAndRefresh(String userId) async {
    if (userId.isEmpty) return;
    final resp = await AdminApi.adminUnbanUser(userId);
    final msg = resp['body']?['message']?.toString() ?? '操作已提交';
    return _afterAction(msg, () => loadAuditUsers());
  }

  Future<void> approveUser(String userId) async {
    if (userId.isEmpty) return;
    final resp = await AdminApi.adminApproveUser(userId);
    final msg = resp['body']?['message']?.toString() ?? '审核通过';
    return _afterAction(msg, () async {
      if (selectedSection == AdminSection.users) {
        await loadUsers();
      } else if (selectedSection == AdminSection.userReports) {
        await loadReports();
        await loadAuditUsers();
      }
    });
  }

  Future<void> grantAdmin(String userId) async {
    if (userId.isEmpty) return;
    await AdminApi.adminGrantAdmin(userId);
    return _afterAction('', () => loadPermissionUsers());
  }

  Future<void> revokeAdmin(String userId) async {
    if (userId.isEmpty) return;
    await AdminApi.adminRevokeAdmin(userId);
    return _afterAction('', () => loadPermissionUsers());
  }

  Future<void> approveApplication(String id) async {
    if (id.isEmpty) return;
    await AdminApi.adminApproveApplication(id);
    await loadApplications();
  }

  Future<void> rejectApplication(String id) async {
    if (id.isEmpty) return;
    await AdminApi.adminRejectApplication(id);
    await loadApplications();
  }

  Future<void> createOrUpdateNotice({
    required String title,
    String? content,
    required VoidCallback onSuccess,
  }) async {
    noticeLoading = true;
    notifyListeners();
    try {
      await AdminApi.adminCreateNotice(
        title: title,
        content: content,
        published: true,
      );
      await loadNotices();
      onSuccess();
    } finally {
      noticeLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteNotice(String id) async {
    if (id.isEmpty) return;
    await AdminApi.adminDeleteNotice(id);
    await loadNotices();
  }

  Future<void> handleRemovePostDirectly(String postId) async {
    if (postId.isEmpty) return;
    final resp = await AdminApi.adminHidePost(postId);
    final msg = resp['body']?['message']?.toString() ?? '下架失败';
    return _afterAction(msg, () => loadPosts(page: postPage));
  }

  /// Helper: show snackbar with msg, then run [refresh].
  void _afterAction(String msg, Future<void> Function() refresh) async {
    // Snackbar is shown by caller via context; we just refresh.
    await refresh();
    if (msg.isNotEmpty) {
      // caller handles snackbar via context
    }
  }

  // ==================== Helpers ====================

  /// Extracts a display name from a user map.
  /// Uses name first, falls back to email (trimmed before '@'), then empty.
  static String getUserDisplayName(Map<String, dynamic>? user) {
    if (user == null) return '';
    final String? name = user['name']?.toString();
    if (name != null && name.isNotEmpty) return name.split('@').first;
    final String? email = user['email']?.toString();
    if (email != null && email.isNotEmpty) return email.split('@').first;
    return '';
  }

  static String formatPostTime(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      String two(int v) => v.toString().padLeft(2, '0');
      return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
          '${two(dt.hour)}:${two(dt.minute)}';
    } catch (_) {
      return raw;
    }
  }

  static String truncateTitle(String title) {
    const maxLen = 20;
    if (title.runes.length <= maxLen) return title;
    return String.fromCharCodes(title.runes.take(maxLen)) + '...';
  }

  String formatReportedTarget(Map<String, dynamic> r) {
    final targetType = r['targetType']?.toString() ?? '';
    if (targetType == 'POST') {
      return 'POST ${r['postId'] ?? ''}';
    } else if (targetType == 'COMMENT') {
      return 'COMMENT ${r['commentId'] ?? ''}';
    } else if (targetType == 'USER') {
      final user = r['reportedUser'] as Map<String, dynamic>?;
      return 'U${user?['id'] ?? ''} / ${user?['name'] ?? ''}';
    }
    return '';
  }

  /// Builds a colored status chip for user statuses.
  static Widget buildStatusChip(String? rawStatus) {
    final status = (rawStatus ?? 'NORMAL').toUpperCase();
    Color bg;
    String label;
    switch (status) {
      case 'AUDIT':
        bg = Colors.blue;
        label = '待审核';
        break;
      case 'BANNED':
        bg = Colors.redAccent;
        label = '封禁中';
        break;
      case 'MUTE':
      case 'SILENT': // 兼容旧数据
        bg = Colors.orange;
        label = '禁言中';
        break;
      default:
        bg = Colors.green;
        label = '正常';
        break;
    }
    return Chip(
      label: Text(label),
      backgroundColor: bg,
      labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
    );
  }

  /// Builds a colored status chip for post statuses.
  static Widget buildPostStatusChip(String? rawStatus) {
    if (rawStatus == null || rawStatus.isEmpty) {
      return const Text('-', style: TextStyle(color: Colors.grey));
    }
    final status = rawStatus.toUpperCase();
    Color bg;
    String label;
    switch (status) {
      case 'NORMAL':
        bg = Colors.green;
        label = '正常';
        break;
      case 'AUDIT':
        bg = Colors.orange;
        label = '审核中';
        break;
      case 'DRAFT':
        bg = Colors.blue;
        label = '打回草稿';
        break;
      case 'REMOVED':
        bg = Colors.red;
        label = '下架';
        break;
      default:
        bg = Colors.grey;
        label = rawStatus;
        break;
    }
    return Chip(
      label: Text(label),
      backgroundColor: bg,
      labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
    );
  }
}

/// Enum of admin panel sections.
enum AdminSection {
  users,
  posts,
  reports,
  userReports,
  postReports,
  notices,
  recommend,
  applyReview,
  permissions,
}
