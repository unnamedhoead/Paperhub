import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../services/api/admin_api.dart';
import '../../services/api/post_api.dart';
import 'admin_controller.dart';
import 'admin_common.dart';

// ==================== PostManagement Section ====================

/// Post management section (super admin only).
class AdminPostSection extends StatelessWidget {
  final AdminController controller;
  const AdminPostSection({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return SectionScaffold(
      title: '帖子管理',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSearchBar(
            hintText: '按标题或内容搜索帖子（留空为全部）',
            buttonLabel: '搜索',
            onChanged: (v) => c.postSearchKeyword = v,
            onPressed: () => c.loadPosts(page: 0),
          ),
          const SizedBox(height: 12),
          AdminSearchBar(
            hintText: '按作者昵称或邮箱筛选（可选）',
            buttonLabel: '筛选',
            onChanged: (v) => c.postAuthorKeyword = v,
            onPressed: () => c.loadPosts(page: 0),
          ),
          const SizedBox(height: 16),
          if (c.postLoading)
            const Center(child: CircularProgressIndicator())
          else
            PlaceholderTable(
              headers: const [
                'ID', '标题', '作者信息', '状态', '发布时间', '操作'
              ],
              rows: c.postList
                  .map((p) => [
                        Text(p['id']?.toString() ?? ''),
                        Text(
                          AdminController.truncateTitle(
                              p['title']?.toString() ?? ''),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'ID: ${p['authorId'] ?? ''} | 昵称: ${p['authorName'] ?? ''} | 邮箱: ${p['authorEmail'] ?? ''}',
                        ),
                        AdminController.buildPostStatusChip(
                            p['status']?.toString()),
                        Text(AdminController.formatPostTime(
                            p['createdAt']?.toString())),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () => viewPostDetail(context,
                                  postId: p['id']?.toString(),
                                  showManageButton: true,
                                  onRemove: () => showRemovePostDialog(
                                      context, controller, p)),
                              child: const Text('查看详情'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: (p['status']
                                          ?.toString()
                                          .toUpperCase() ==
                                      'REMOVED')
                                  ? null
                                  : () => showRemovePostDialog(
                                      context, controller, p),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                disabledBackgroundColor: Colors.grey,
                              ),
                              child: const Text('下架'),
                            ),
                          ],
                        ),
                      ])
                  .toList(),
            ),
          const SizedBox(height: 12),
          Pagination(
            currentPage: c.postPage,
            totalItems: c.postTotal,
            onPageChanged: (p) => c.loadPosts(page: p),
          ),
        ],
      ),
    );
  }
}

// ==================== PostReportManagement Section ====================

/// Post report management section.
class AdminPostReportSection extends StatelessWidget {
  final AdminController controller;
  const AdminPostReportSection({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return SectionScaffold(
      title: '帖子举报管理',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReportFilterBar(
            onSearchChanged: (v) => c.reportSearchKeyword = v,
            onSearch: () => c.loadReports(page: 0),
          ),
          const SizedBox(height: 16),
          if (c.reportLoading)
            const Center(child: CircularProgressIndicator())
          else
            PlaceholderTable(
              headers: const [
                '举报人', '举报时间', '被举报帖子', '理由',
                '举报状态', '帖子状态', '操作',
              ],
              rows: c.reportList
                  .map((r) => [
                        Text(
                          '${r['reporterName'] ?? ''} (ID: ${r['reporterId'] ?? ''})',
                        ),
                        Text(AdminController.formatPostTime(
                            r['reportTime']?.toString())),
                        TextButton(
                          onPressed: () => viewPostDetail(context,
                              postId: r['postId']?.toString(),
                              showManageButton: false),
                          child: Text(
                            '${r['postTitle'] ?? ''} (ID: ${r['postId'] ?? ''})',
                          ),
                        ),
                        Text(r['description']?.toString() ?? ''),
                        AdminController.buildStatusChip(
                            r['status']?.toString()),
                        AdminController.buildPostStatusChip(
                            r['postStatusAfter']?.toString()),
                        OutlinedButton(
                          onPressed: (r['status']?.toString() ==
                                      'PENDING' ||
                                  r['postStatusAfter']
                                          ?.toString() ==
                                      'AUDIT')
                              ? () => showPostReportDialog(
                                  context, controller, r)
                              : null,
                          child: const Text('处理'),
                        ),
                      ])
                  .toList(),
            ),
          const SizedBox(height: 12),
          Pagination(
            currentPage: c.reportPage,
            totalItems: c.reportTotal,
            onPageChanged: (p) => c.loadReports(page: p),
          ),
        ],
      ),
    );
  }
}

// ==================== View Post Detail (merged) ====================

/// Shows a post detail dialog.
/// [showManageButton] controls whether the "下架此帖子" button appears.
void viewPostDetail(BuildContext context,
    {String? postId,
    bool showManageButton = false,
    VoidCallback? onRemove}) async {
  if (postId == null || postId.isEmpty) return;
  try {
    final resp = await PostApi.getPostDetail(postId);
    if (resp['statusCode'] != 200) return;
    final postData = resp['body'];
    if (postData == null) return;

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('帖子详情',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(postData['title'] ?? '',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        '作者: ${postData['author']?['name'] ?? ''}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      if (showManageButton)
                        Row(
                          children: [
                            const Text('状态: '),
                            AdminController.buildPostStatusChip(
                                postData['status']?.toString()),
                          ],
                        )
                      else
                        Text(
                          '状态: ${postData['status'] ?? ''}',
                          style:
                              TextStyle(color: Colors.grey[600]),
                        ),
                      if (postData['hiddenReason'] != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          showManageButton
                              ? '下架原因: ${postData['hiddenReason']}'
                              : '打回原因: ${postData['hiddenReason']}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(postData['content'] ?? ''),
                      const SizedBox(height: 16),
                      if (postData['media'] != null &&
                          (postData['media'] as List).isNotEmpty)
                        ...((postData['media'] as List).map(
                          (url) => Padding(
                            padding:
                                const EdgeInsets.only(bottom: 8),
                            child: Image.network(
                              url,
                              errorBuilder: (context, error,
                                      stackTrace) =>
                                  const Text('图片加载失败'),
                            ),
                          ),
                        )),
                    ],
                  ),
                ),
              ),
              if (showManageButton &&
                  postData['status']?.toString() != 'REMOVED')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      onRemove?.call();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                    ),
                    child: const Text('下架此帖子'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法查看帖子: $e')));
    }
  }
}

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
              await _handleRejectAudit(context, controller,
                  report['postId'], reasonController.text);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange),
            child: const Text('继续打回'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _handleApproveAudit(context, controller,
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
              await _handleIgnoreReport(context, controller,
                  report['id'], reasonController.text);
            },
            child: const Text('忽略举报'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _handleRemovePost(context, controller,
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

// ==================== Report Action Helpers ====================

Future<void> _handleRemovePost(BuildContext context,
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

Future<void> _handleIgnoreReport(BuildContext context,
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

Future<void> _handleRejectAudit(BuildContext context,
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

Future<void> _handleApproveAudit(BuildContext context,
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
