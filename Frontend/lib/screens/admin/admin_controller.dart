import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../config/app_env.dart';
import '../../services/api/admin_api.dart';
import 'admin_controller_loaders.dart';
import 'admin_utils.dart' as utils;

/// Shared state and business logic for the admin panel.
/// Owned by [AdminScreen], passed to section widgets.
///
/// Per-section list state and the `load*` data-loading methods live in
/// [AdminControllerLoaders]; pure formatting helpers live in `admin_utils.dart`
/// (re-exposed below as static methods for backwards compatibility). This class
/// keeps navigation state, lifecycle, the websocket, and the simple actions.
class AdminController extends ChangeNotifier with AdminControllerLoaders {
  AdminController({required this.role});

  final String role;

  bool get isSuperAdmin => role.toUpperCase() == 'SUPER_ADMIN';

  // ---- navigation ----
  AdminSection selectedSection = AdminSection.userReports;
  bool sidebarCollapsed = false;

  /// Page size used by the audit-user list (consumed by widgets).
  static const int auditUserPageSize = 10;

  WebSocketChannel? _wsChannel;

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

  // ==================== Helpers (delegated to admin_utils) ====================

  /// Extracts a display name from a user map.
  /// Uses name first, falls back to email (trimmed before '@'), then empty.
  static String getUserDisplayName(Map<String, dynamic>? user) =>
      utils.adminGetUserDisplayName(user);

  static String formatPostTime(String? raw) => utils.adminFormatPostTime(raw);

  static String truncateTitle(String title) =>
      utils.adminTruncateTitle(title);

  String formatReportedTarget(Map<String, dynamic> r) =>
      utils.adminFormatReportedTarget(r);

  /// Builds a colored status chip for user statuses.
  static Widget buildStatusChip(String? rawStatus) =>
      utils.adminBuildStatusChip(rawStatus);

  /// Builds a colored status chip for post statuses.
  static Widget buildPostStatusChip(String? rawStatus) =>
      utils.adminBuildPostStatusChip(rawStatus);
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
