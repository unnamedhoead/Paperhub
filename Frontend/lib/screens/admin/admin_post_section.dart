import 'package:flutter/material.dart';

import 'admin_controller.dart';
import 'admin_common.dart';
import 'admin_post_detail_dialog.dart';
import 'admin_post_dialogs.dart';

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
