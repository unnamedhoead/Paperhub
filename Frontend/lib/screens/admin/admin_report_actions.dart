import 'package:flutter/material.dart';

import '../../services/api/admin_api.dart';
import 'admin_controller.dart';

// ==================== Report Action Helpers ====================
//
// Async handlers backing the post-report dialog buttons. Each calls the
// matching [AdminApi] endpoint, shows a result snackbar, and refreshes the
// controller's report list. Extracted from admin_post_section.dart.

Future<void> handleRemovePost(BuildContext context,
    AdminController controller, int reportId, String reason) async {
  try {
    final resp = await AdminApi.adminRemovePost(
      reportId: reportId,
      reason: reason.isEmpty ? '违规内容' : reason,
    );
    if (resp['statusCode'] == 200 && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('帖子已打回')));
      controller.loadReports(page: controller.reportPage);
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('操作失败: $e')));
    }
  }
}

Future<void> handleIgnoreReport(BuildContext context,
    AdminController controller, int reportId, String reason) async {
  try {
    final resp = await AdminApi.adminIgnoreReport(
      reportId: reportId,
      reason: reason.isEmpty ? '未发现违规' : reason,
    );
    if (resp['statusCode'] == 200 && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已忽略该举报')));
      controller.loadReports(page: controller.reportPage);
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('操作失败: $e')));
    }
  }
}

Future<void> handleRejectAudit(BuildContext context,
    AdminController controller, int postId, String reason) async {
  try {
    final resp = await AdminApi.adminRejectAuditPost(
      postId: postId,
      reason: reason.isEmpty ? '不符合发布要求' : reason,
    );
    if (resp['statusCode'] == 200 && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已打回草稿')));
      controller.loadReports(page: controller.reportPage);
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('操作失败: $e')));
    }
  }
}

Future<void> handleApproveAudit(BuildContext context,
    AdminController controller, int postId) async {
  try {
    final resp =
        await AdminApi.adminApproveAuditPost(postId: postId);
    if (resp['statusCode'] == 200 && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('审核通过')));
      controller.loadReports(page: controller.reportPage);
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('操作失败: $e')));
    }
  }
}
