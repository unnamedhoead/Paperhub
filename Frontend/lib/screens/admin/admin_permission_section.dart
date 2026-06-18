import 'package:flutter/material.dart';

import '../../services/api/admin_api.dart';
import 'admin_controller.dart';
import 'admin_common.dart';

// ==================== PermissionManagement Section ====================

/// Permission management section (super admin only).
class AdminPermissionSection extends StatelessWidget {
  final AdminController controller;
  const AdminPermissionSection({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return SectionScaffold(
      title: '管理员权限管理',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '管理员列表',
            style:
                TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          AdminSearchBar(
            hintText: '搜索管理员（ID / 昵称 / 邮箱）',
            buttonLabel: '搜索',
            onChanged: (v) => c.adminSearchKeyword = v,
            onPressed: () => c.loadPermissionUsers(),
          ),
          const SizedBox(height: 12),
          if (c.permissionLoading)
            const Center(child: CircularProgressIndicator())
          else
            Builder(
              builder: (context) {
                final source = c.adminList.isNotEmpty
                    ? c.adminList
                    : c.userList
                        .where((u) {
                          final role = (u['role'] ?? '')
                              .toString()
                              .toUpperCase();
                          return role == 'ADMIN' ||
                              role == 'SUPER_ADMIN';
                        })
                        .toList();
                const pageSize = 10;
                final total = source.length;
                final start = c.adminPageLocal * pageSize;
                final visible =
                    source.skip(start).take(pageSize).toList();
                return Column(
                  children: [
                    PlaceholderTable(
                      headers: const [
                        '用户名',
                        '当前角色',
                        '操作'
                      ],
                      rows: visible
                          .map((u) => [
                                Text(AdminController
                                    .getUserDisplayName(u)),
                                Text(u['role']?.toString() ?? ''),
                                if ((u['role'] ?? '')
                                        .toString()
                                        .toUpperCase() ==
                                    'SUPER_ADMIN')
                                  const Text('无法操作')
                                else
                                  OutlinedButton(
                                    onPressed: () => c.revokeAdmin(
                                        (u['id'] ?? '')
                                            .toString()),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor:
                                          Colors.redAccent,
                                    ),
                                    child:
                                        const Text('收回权限'),
                                  ),
                              ])
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                    Pagination(
                      currentPage: c.adminPageLocal,
                      totalItems: total,
                      onPageChanged: (p) =>
                          c.adminPageLocal = p,
                    ),
                  ],
                );
              },
            ),
          const SizedBox(height: 32),
          const Text(
            '普通用户列表',
            style:
                TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          AdminSearchBar(
            hintText: '搜索普通用户（ID / 昵称 / 邮箱）',
            buttonLabel: '搜索',
            onChanged: (v) => c.userSearchKeywordForGrant = v,
            onPressed: () => c.loadPermissionUsers(),
          ),
          const SizedBox(height: 12),
          if (c.permissionLoading)
            const SizedBox.shrink()
          else
            Builder(
              builder: (context) {
                final source = c.normalUserList.isNotEmpty
                    ? c.normalUserList
                    : c.userList
                        .where((u) =>
                            (u['role'] ?? '')
                                .toString()
                                .toUpperCase() ==
                            'USER')
                        .toList();
                const pageSize = 10;
                final total = source.length;
                final start = c.normalPageLocal * pageSize;
                final visible =
                    source.skip(start).take(pageSize).toList();
                return Column(
                  children: [
                    PlaceholderTable(
                      headers: const [
                        '用户名',
                        '当前角色',
                        '操作'
                      ],
                      rows: visible
                          .map((u) => [
                                Text(AdminController
                                    .getUserDisplayName(u)),
                                Text(u['role']?.toString() ?? ''),
                                ElevatedButton(
                                  onPressed: () => c.grantAdmin(
                                      (u['id'] ?? '')
                                          .toString()),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Colors.green,
                                  ),
                                  child: const Text(
                                      '授权为管理员'),
                                ),
                              ])
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                    Pagination(
                      currentPage: c.normalPageLocal,
                      totalItems: total,
                      onPageChanged: (p) =>
                          c.normalPageLocal = p,
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

// ==================== ApplyReview Section ====================

/// Admin application review section (super admin only).
class AdminApplyReviewSection extends StatelessWidget {
  final AdminController controller;
  const AdminApplyReviewSection(
      {super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return SectionScaffold(
      title: '管理员申请审核',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (c.applicationLoading)
            const Center(child: CircularProgressIndicator())
          else
            PlaceholderTable(
              headers: const [
                '推荐管理员(ID/昵称)',
                '被推荐用户(ID/昵称)',
                '申请理由',
                '申请时间',
                '操作',
              ],
              rows: c.applicationList
                  .map((a) => [
                        Text(
                          'A${a['recommender']?['id'] ?? ''} / ${a['recommender']?['name'] ?? ''}',
                        ),
                        Text(
                          'U${a['candidate']?['id'] ?? ''} / ${a['candidate']?['name'] ?? ''}',
                        ),
                        Text(a['reason']?.toString() ?? ''),
                        Text(AdminController.formatPostTime(
                            a['createdAt']?.toString())),
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: () => c.approveApplication(
                                  (a['id'] ?? '').toString()),
                              child: const Text('批准'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () => c.rejectApplication(
                                  (a['id'] ?? '').toString()),
                              style: OutlinedButton.styleFrom(
                                foregroundColor:
                                    Colors.redAccent,
                              ),
                              child: const Text('拒绝'),
                            ),
                          ],
                        ),
                      ])
                  .toList(),
            ),
          const SizedBox(height: 12),
          Pagination(
            currentPage: c.applicationPage,
            totalItems: c.applicationTotal,
            onPageChanged: (p) => c.loadApplications(page: p),
          ),
        ],
      ),
    );
  }
}

// ==================== Recommend Section ====================

/// Admin recommend section (regular admin).
class AdminRecommendSection extends StatelessWidget {
  final AdminController controller;
  const AdminRecommendSection(
      {super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return SectionScaffold(
      title: '管理员推荐',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSearchBar(
            hintText: '输入普通用户昵称或邮箱（可选）',
            buttonLabel: '搜索',
            onChanged: (v) => c.recommendSearchKeyword = v,
            onPressed: () => c.loadRecommendUsers(page: 0),
          ),
          const SizedBox(height: 16),
          if (c.recommendLoading)
            const Center(child: CircularProgressIndicator())
          else
            PlaceholderTable(
              headers: const ['用户名', '邮箱', '角色', '状态', '操作'],
              rows: c.recommendUserList
                  .map((u) => [
                        Text(u['name']?.toString() ?? ''),
                        Text(u['email']?.toString() ?? ''),
                        Text(u['role']?.toString() ?? ''),
                        AdminController.buildStatusChip(
                            u['status']?.toString()),
                        ElevatedButton(
                          onPressed: () => showRecommendDialog(
                              context, controller,
                              (u['id'] ?? '').toString()),
                          child: const Text('推荐为管理员'),
                        ),
                      ])
                  .toList(),
            ),
          const SizedBox(height: 12),
          Pagination(
            currentPage: c.recommendPage,
            totalItems: c.recommendTotal,
            onPageChanged: (p) =>
                c.loadRecommendUsers(page: p),
          ),
        ],
      ),
    );
  }
}

// ==================== Recommend Dialog ====================

Future<void> showRecommendDialog(
    BuildContext context, AdminController controller,
    String userId) async {
  final reasonCtrl = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('推荐用户为管理员'),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: '推荐理由',
            hintText: '请输入推荐理由',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('提交'),
          ),
        ],
      );
    },
  );

  if (ok != true) return;
  final reason = reasonCtrl.text.trim();
  if (reason.isEmpty) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('推荐理由不能为空')));
    return;
  }
  final resp = await AdminApi.adminCreateApplication(
    candidateUserId: userId,
    reason: reason,
  );
  final msg = resp['body']?['message']?.toString() ??
      '推荐已提交，等待超级管理员审核';
  if (context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
}
