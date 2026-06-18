import 'package:flutter/foundation.dart';

import '../../services/api/admin_api.dart';

/// Per-section list state plus the data-loading methods for the admin panel.
///
/// Mixed into [AdminController]. Kept `on ChangeNotifier` so the loaders can
/// call [notifyListeners] directly. Each loader owns only its own group of
/// fields, so this mixin is self-contained; orchestration (initial load,
/// websocket, simple actions) lives in [AdminController].
mixin AdminControllerLoaders on ChangeNotifier {
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

  // ---- audit users ----
  // Note: `auditUserPageSize` stays a static const on [AdminController] (used
  // by widgets as `AdminController.auditUserPageSize`); static members are not
  // exposed through a mixin, so it cannot live here.
  List<Map<String, dynamic>> auditUserList = [];
  bool auditUserLoading = false;
  String auditUserSearchKeyword = '';
  int auditUserPage = 0;

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
}
