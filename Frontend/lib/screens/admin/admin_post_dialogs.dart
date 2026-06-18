import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import 'admin_controller.dart';
import 'admin_report_actions.dart';

// ==================== Remove Post Dialog ====================

void showRemovePostDialog(BuildContext context,
    AdminController controller, Map<String, dynamic> post) {
  final reasonController = TextEditingController();
  showDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.4),
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.dialogBackground,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      title: Text(
        '确认下架帖子',
        style: TextStyle(
          fontSize: 18.0,
          fontWeight: FontWeight.w700,
          color: AppColors.dialogTitle,
        ),
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '帖子标题: ${post['title'] ?? ''}',
            style: TextStyle(
                fontSize: 14.0, color: AppColors.dialogContent),
          ),
          const SizedBox(height: 8),
          Text(
            '作者: ${post['authorName'] ?? ''}',
            style: TextStyle(
                fontSize: 14.0, color: AppColors.dialogContent),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: reasonController,
            decoration: InputDecoration(
              labelText: '下架原因',
              hintText: '请输入下架原因（必填）',
              filled: true,
              fillColor: AppColors.backgroundLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(
                    color: AppColors.primary, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16.0, vertical: 12.0),
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () async {
            final reason = reasonController.text.trim();
            if (reason.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入下架原因')));
              return;
            }
            Navigator.pop(ctx);
            await controller.handleRemovePostDirectly(
                post['id']?.toString() ?? '');
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('帖子已下架')));
            }
          },
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red),
          child: const Text('确认下架'),
        ),
      ],
    ),
  );
}

// ==================== Post Report Dialog ====================

void showPostReportDialog(BuildContext context,
    AdminController controller, Map<String, dynamic> report) {
  final reasonController = TextEditingController();
  final postStatus = report['postStatusAfter']?.toString();
  final isAudit = postStatus == 'AUDIT';

  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.4),
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.dialogBackground,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      insetPadding: const EdgeInsets.all(24.0),
      titlePadding: const EdgeInsets.only(
          top: 24.0, left: 24.0, right: 24.0, bottom: 16.0),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 24.0),
      actionsPadding: const EdgeInsets.all(24.0),
      title: Text(
        isAudit ? '处理待审核帖子' : '处理帖子举报',
        style: TextStyle(
          fontSize: 18.0,
          fontWeight: FontWeight.w700,
          color: AppColors.dialogTitle,
        ),
        textAlign: TextAlign.center,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bug fix: only show reporter for non-AUDIT cases
            if (!isAudit) ...[
              Text(
                '举报人: ${report['reporterName']}',
                style: TextStyle(
                  fontSize: 14.0,
                  color: AppColors.dialogContent,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              '帖子: ${report['postTitle']}',
              style: TextStyle(
                fontSize: 14.0,
                color: AppColors.dialogContent,
              ),
            ),
            const SizedBox(height: 8),
            if (!isAudit) ...[
              Text(
                '举报理由: ${report['description']}',
                style: TextStyle(
                  fontSize: 14.0,
                  color: AppColors.dialogContent,
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (isAudit) const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: '处理原因',
                hintText: isAudit
                    ? '请输入打回原因（审核通过可留空）'
                    : '请输入下架或忽略的原因',
                filled: true,
                fillColor: AppColors.backgroundLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(
                      color: AppColors.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 12.0),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
        if (isAudit) ...[
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await handleRejectAudit(context, controller,
                  report['postId'], reasonController.text);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange),
            child: const Text('继续打回'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await handleApproveAudit(context, controller,
                  report['postId']);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green),
            child: const Text('审核通过'),
          ),
        ] else ...[
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await handleIgnoreReport(context, controller,
                  report['id'], reasonController.text);
            },
            child: const Text('忽略举报'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await handleRemovePost(context, controller,
                  report['id'], reasonController.text);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red),
            child: const Text('打回帖子'),
          ),
        ],
      ],
    ),
  );
}
