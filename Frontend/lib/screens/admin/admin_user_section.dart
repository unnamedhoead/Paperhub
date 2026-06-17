import 'package:flutter/material.dart';

import '../../services/api/admin_api.dart';
import 'admin_controller.dart';
import 'admin_common.dart';

// ==================== UserManagement Section ====================

/// User management section (super admin only).
class AdminUserSection extends StatelessWidget {
  final AdminController controller;
  const AdminUserSection({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return SectionScaffold(
      title: '用户管理',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AdminSearchBar(
                  hintText: '输入用户名或邮箱（留空则查询全部）',
                  buttonLabel: '搜索',
                  onPressed: () => c.loadUsers(page: 0),
                  onChanged: (v) => c.userSearchKeyword = v,
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: c.userStatusFilter,
                items: const [
                  DropdownMenuItem(
                      value: 'NON_NORMAL', child: Text('非正常状态')),
                  DropdownMenuItem(value: 'AUDIT', child: Text('待审核')),
                  DropdownMenuItem(value: 'BANNED', child: Text('已封禁')),
                  DropdownMenuItem(value: 'MUTE', child: Text('已禁言')),
                  DropdownMenuItem(value: 'NORMAL', child: Text('正常')),
                  DropdownMenuItem(value: '', child: Text('全部')),
                ],
                onChanged: (v) {
                  c.userStatusFilter = v ?? 'NON_NORMAL';
                  c.loadUsers(page: 0);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (c.userLoading)
            const Center(child: CircularProgressIndicator())
          else
            PlaceholderTable(
              headers: const ['用户名', '邮箱', '角色', '状态', '操作'],
              rows: c.userList
                  .map((u) => [
                        Text(u['name']?.toString() ?? ''),
                        Text(u['email']?.toString() ?? ''),
                        Text(u['role']?.toString() ?? ''),
                        AdminController.buildStatusChip(
                            u['status']?.toString()),
                        _buildUserActions(context, u),
                      ])
                  .toList(),
            ),
          const SizedBox(height: 12),
          Pagination(
            currentPage: c.userPage,
            totalItems: c.userTotal,
            onPageChanged: (p) => c.loadUsers(page: p),
          ),
        ],
      ),
    );
  }

  Widget _buildUserActions(BuildContext context, Map<String, dynamic> u) {
    final role = (u['role'] ?? '').toString();
    final status = (u['status'] ?? 'NORMAL').toString();
    final id = (u['id'] ?? '').toString();

    return UserModerationActions(
      userId: id,
      status: status,
      role: role,
      onBan: () async {
        await controller.banUser(id);
        _showSnackBar(context, '用户已封禁');
      },
      onUnban: () async {
        await controller.unbanUser(id);
        _showSnackBar(context, '已解除封禁');
      },
      onMute: () => showMuteDialog(context, controller, id),
      onApprove: () async {
        await controller.approveUser(id);
        _showSnackBar(context, '审核通过');
      },
      onReject: () => showRejectUserDialog(context, controller, id),
    );
  }
}

// ==================== UserReportManagement Section ====================

/// User report management section.
class AdminUserReportSection extends StatelessWidget {
  final AdminController controller;
  const AdminUserReportSection({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    // Local filtering and pagination
    var filteredUsers = c.auditUserList.where((u) {
      if (c.auditUserSearchKeyword.isEmpty) return true;
      final keyword = c.auditUserSearchKeyword.toLowerCase();
      final name = (u['name']?.toString() ?? '').toLowerCase();
      final email = (u['email']?.toString() ?? '').toLowerCase();
      return name.contains(keyword) || email.contains(keyword);
    }).toList();

    final totalUsers = filteredUsers.length;
    final startIndex =
        c.auditUserPage * AdminController.auditUserPageSize;
    final endIndex = (startIndex + AdminController.auditUserPageSize)
        .clamp(0, totalUsers);
    final paginatedUsers = filteredUsers.sublist(
      startIndex.clamp(0, totalUsers),
      endIndex,
    );

    return SectionScaffold(
      title: '用户举报管理',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AdminSearchBar(
                  hintText: '输入用户名或邮箱（留空则查询全部）',
                  buttonLabel: '搜索',
                  onPressed: () => c.auditUserPage = 0,
                  onChanged: (v) => c.auditUserSearchKeyword = v,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (c.auditUserLoading)
            const Center(child: CircularProgressIndicator())
          else
            PlaceholderTable(
              headers: const ['用户名', '邮箱', '角色', '状态', '操作'],
              rows: paginatedUsers
                  .map((u) => [
                        Text(u['name']?.toString() ?? ''),
                        Text(u['email']?.toString() ?? ''),
                        Text(u['role']?.toString() ?? ''),
                        AdminController.buildStatusChip(
                            u['status']?.toString()),
                        _buildUserActionsForAudit(context, u),
                      ])
                  .toList(),
            ),
          const SizedBox(height: 12),
          Pagination(
            currentPage: c.auditUserPage,
            totalItems: totalUsers,
            onPageChanged: (p) => c.auditUserPage = p,
          ),
        ],
      ),
    );
  }

  Widget _buildUserActionsForAudit(
      BuildContext context, Map<String, dynamic> u) {
    final role = (u['role'] ?? '').toString();
    final status = (u['status'] ?? 'NORMAL').toString();
    final id = (u['id'] ?? '').toString();

    return UserModerationActions(
      userId: id,
      status: status,
      role: role,
      onBan: () async {
        await controller.banUserAndRefresh(id);
        _showSnackBar(context, '用户已封禁');
      },
      onUnban: () async {
        await controller.unbanUserAndRefresh(id);
        _showSnackBar(context, '已解除封禁');
      },
      onMute: () => showMuteDialogForAudit(context, controller, id),
      onApprove: () async {
        await controller.approveUser(id);
        _showSnackBar(context, '审核通过');
      },
      onReject: () => showRejectUserDialog(context, controller, id),
    );
  }
}

// ==================== UserModerationActions Widget ====================

class UserModerationActions extends StatelessWidget {
  final String userId;
  final String status;
  final String role;
  final VoidCallback onBan;
  final VoidCallback onUnban;
  final VoidCallback onMute;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const UserModerationActions({
    super.key,
    required this.userId,
    required this.status,
    required this.role,
    required this.onBan,
    required this.onUnban,
    required this.onMute,
    this.onApprove,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final roleUpper = role.toUpperCase();
    final statusUpper = status.toUpperCase();

    if (roleUpper == 'ADMIN' || roleUpper == 'SUPER_ADMIN') {
      return const Text(
        '管理员帐号，无法封禁/禁言',
        style: TextStyle(fontSize: 12, color: Colors.grey),
      );
    }

    final isAudit = statusUpper == 'AUDIT';
    final isBanned = statusUpper == 'BANNED';
    final isSilent = statusUpper == 'MUTE' || statusUpper == 'SILENT';

    if (isAudit && onApprove != null && onReject != null) {
      return Row(
        children: [
          OutlinedButton(
            onPressed: onApprove,
            style:
                OutlinedButton.styleFrom(foregroundColor: Colors.green),
            child: const Text('忽略举报'),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onReject,
            style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent),
            child: const Text('处理举报'),
          ),
        ],
      );
    }

    return Row(
      children: [
        OutlinedButton(
          onPressed: isBanned ? null : onBan,
          style:
              OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
          child: const Text('封禁'),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: (!isBanned && !isSilent) ? null : onUnban,
          style: OutlinedButton.styleFrom(foregroundColor: Colors.green),
          child: const Text('解封'),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: isBanned ? null : onMute,
          style:
              OutlinedButton.styleFrom(foregroundColor: Colors.orange),
          child: Text(isSilent ? '重新禁言' : '禁言'),
        ),
      ],
    );
  }
}

// ==================== Dialogs ====================

Future<void> showMuteDialog(
    BuildContext context, AdminController controller, String userId) async {
  final durationCtrl = TextEditingController(text: '24');
  String unit = 'HOURS';
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('设置禁言时长'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: durationCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '时长数值',
                      hintText: '例如 24',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: unit,
                  items: const [
                    DropdownMenuItem(value: 'HOURS', child: Text('小时')),
                    DropdownMenuItem(value: 'DAYS', child: Text('天')),
                    DropdownMenuItem(value: 'MONTHS', child: Text('月')),
                    DropdownMenuItem(value: 'YEARS', child: Text('年')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      unit = v;
                    }
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定'),
          ),
        ],
      );
    },
  );

  if (result != true) return;
  final duration = int.tryParse(durationCtrl.text.trim()) ?? 0;
  if (duration <= 0) {
    _showSnackBar(context, '请输入正确的禁言时长');
    return;
  }
  await _muteUserWithDuration(
      context, controller, userId, duration, unit);
}

Future<void> showMuteDialogForAudit(
    BuildContext context, AdminController controller, String userId) async {
  final durationCtrl = TextEditingController(text: '24');
  String unit = 'HOURS';
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('设置禁言时长'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: durationCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '时长数值',
                      hintText: '例如 24',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: unit,
                  items: const [
                    DropdownMenuItem(value: 'HOURS', child: Text('小时')),
                    DropdownMenuItem(value: 'DAYS', child: Text('天')),
                    DropdownMenuItem(value: 'MONTHS', child: Text('月')),
                    DropdownMenuItem(value: 'YEARS', child: Text('年')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      unit = v;
                    }
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定'),
          ),
        ],
      );
    },
  );

  if (result != true) return;
  final duration = int.tryParse(durationCtrl.text.trim()) ?? 0;
  if (duration <= 0) {
    _showSnackBar(context, '请输入正确的禁言时长');
    return;
  }
  await _muteUserWithDuration(
      context, controller, userId, duration, unit);
}

Future<void> _muteUserWithDuration(BuildContext context,
    AdminController controller, String userId, int duration,
    String unit) async {
  final resp = await AdminApi.adminMuteUser(userId,
      duration: duration, unit: unit);
  final msg = resp['body']?['message']?.toString() ?? '操作已提交';
  _showSnackBar(context, msg);

  if (resp['statusCode'] == 200) {
    final index = controller.auditUserList
        .indexWhere((u) => u['id']?.toString() == userId);
    if (index != -1) {
      controller.auditUserList[index]['status'] = 'MUTE';
    }
  }

  await controller.loadAuditUsers();
  controller.notify();
}

Future<void> showRejectUserDialog(
    BuildContext context, AdminController controller, String userId) async {
  String action = 'BAN';
  final reasonCtrl = TextEditingController();

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('处理举报'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('选择处理方式：'),
                const SizedBox(height: 12),
                RadioListTile<String>(
                  title: const Text('封禁用户'),
                  value: 'BAN',
                  groupValue: action,
                  onChanged: (v) => setState(() => action = v!),
                ),
                RadioListTile<String>(
                  title: const Text('禁言用户（7天）'),
                  value: 'MUTE',
                  groupValue: action,
                  onChanged: (v) => setState(() => action = v!),
                ),
                RadioListTile<String>(
                  title: const Text('恢复正常'),
                  value: 'NORMAL',
                  groupValue: action,
                  onChanged: (v) => setState(() => action = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(
                    labelText: '处理说明（可选）',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('确定'),
              ),
            ],
          );
        },
      );
    },
  );

  if (result == true) {
    final resp = await AdminApi.adminRejectUser(userId,
        action: action, reason: reasonCtrl.text);
    final msg = resp['body']?['message']?.toString() ?? '处理完成';
    _showSnackBar(context, msg);
    if (controller.selectedSection == AdminSection.users) {
      await controller.loadUsers();
    } else if (controller.selectedSection == AdminSection.userReports) {
      await controller.loadReports();
      await controller.loadAuditUsers();
    }
  }
}

void _showSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));
}
