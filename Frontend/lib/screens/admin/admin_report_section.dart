import 'package:flutter/material.dart';

import '../../services/api/admin_api.dart';
import 'admin_controller.dart';
import 'admin_common.dart';

// ==================== General ReportManagement Section ====================

/// General report management section.
class AdminReportSection extends StatelessWidget {
  final AdminController controller;
  const AdminReportSection({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return SectionScaffold(
      title: '举报管理',
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
                '举报人(ID/昵称)',
                '对象类型',
                '举报时间',
                '被举报对象(ID/昵称)',
                '理由',
                '状态',
                '操作',
              ],
              rows: c.reportList
                  .map((r) => [
                        Text(
                          'U${r['reporter']?['id'] ?? ''} / ${r['reporter']?['name'] ?? ''}',
                        ),
                        Text(r['targetType']?.toString() ?? ''),
                        Text(AdminController.formatPostTime(
                            r['createdAt']?.toString())),
                        Text(c.formatReportedTarget(r)),
                        Text(r['reason']?.toString() ?? ''),
                        Text(r['status']?.toString() ?? ''),
                        OutlinedButton(
                          onPressed: () => showReportDialog(
                              context, c, reportId: r['id'].toString()),
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

// ==================== Report Dialog ====================

void showReportDialog(BuildContext context, AdminController controller,
    {String? reportId}) {
  final report = controller.reportList.firstWhere(
    (r) => r['id'].toString() == reportId,
  );
  final targetType = report['targetType']?.toString();

  if (targetType == 'USER') {
    showUserReportDialog(context, controller, report);
  } else {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('处理举报'),
        content: const Text('该举报类型暂不支持'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}

void showUserReportDialog(
    BuildContext context, AdminController controller,
    Map<String, dynamic> report) {
  final userId = report['reportedUser']?['id']?.toString();
  if (userId == null) return;

  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('处理用户举报'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('举报人: ${report['reporter']?['name']}'),
          const SizedBox(height: 8),
          Text('被举报用户: ${report['reportedUser']?['name']}'),
          const SizedBox(height: 8),
          Text('举报理由: ${report['reason']}'),
          const SizedBox(height: 16),
          const Text('请选择处理方式：'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await handleBanUser(context, controller, userId);
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red),
                child: const Text('封禁用户'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await handleUnbanUser(context, controller, userId);
                },
                child: const Text('解除封禁'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await handleMuteUser(context, controller, userId);
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange),
                child: const Text('禁言'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await handleUnmuteUser(
                      context, controller, userId);
                },
                child: const Text('解除禁言'),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ],
    ),
  );
}

// ==================== User Report Action Helpers ====================

Future<void> handleBanUser(
    BuildContext context, AdminController controller, String userId) async {
  try {
    final resp = await AdminApi.adminBanUser(userId);
    if (resp['statusCode'] == 200) {
      _showSnackBar(context, '用户已封禁');
      controller.loadReports(page: controller.reportPage);
    } else {
      _showSnackBar(context,
          '操作失败: ${resp['body']?['message'] ?? '未知错误'}');
    }
  } catch (e) {
    _showSnackBar(context, '操作失败: $e');
  }
}

Future<void> handleUnbanUser(
    BuildContext context, AdminController controller, String userId) async {
  try {
    final resp = await AdminApi.adminUnbanUser(userId);
    if (resp['statusCode'] == 200) {
      _showSnackBar(context, '已解除封禁');
      controller.loadReports(page: controller.reportPage);
    } else {
      _showSnackBar(context,
          '操作失败: ${resp['body']?['message'] ?? '未知错误'}');
    }
  } catch (e) {
    _showSnackBar(context, '操作失败: $e');
  }
}

Future<void> handleMuteUser(
    BuildContext context, AdminController controller, String userId) async {
  final durationController = TextEditingController(text: '7');
  String selectedUnit = 'DAYS';

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('禁言用户'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: durationController,
              decoration: const InputDecoration(
                labelText: '禁言时长',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedUnit,
              decoration: const InputDecoration(
                labelText: '时间单位',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                    value: 'HOURS', child: Text('小时')),
                DropdownMenuItem(
                    value: 'DAYS', child: Text('天')),
                DropdownMenuItem(
                    value: 'MONTHS', child: Text('月')),
                DropdownMenuItem(
                    value: 'YEARS', child: Text('年')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => selectedUnit = value);
                }
              },
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
              final duration =
                  int.tryParse(durationController.text);
              if (duration == null || duration <= 0) {
                _showSnackBar(context, '请输入有效的时长');
                return;
              }
              Navigator.pop(ctx);
              try {
                final resp = await AdminApi.adminMuteUser(
                  userId,
                  duration: duration,
                  unit: selectedUnit,
                );
                if (resp['statusCode'] == 200) {
                  _showSnackBar(context, '用户已禁言');
                  controller.loadReports(
                      page: controller.reportPage);
                } else {
                  _showSnackBar(context,
                      '操作失败: ${resp['body']?['message'] ?? '未知错误'}');
                }
              } catch (e) {
                _showSnackBar(context, '操作失败: $e');
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    ),
  );
}

Future<void> handleUnmuteUser(
    BuildContext context, AdminController controller, String userId) async {
  try {
    final resp = await AdminApi.adminUnmuteUser(userId);
    if (resp['statusCode'] == 200) {
      _showSnackBar(context, '已解除禁言');
      controller.loadReports(page: controller.reportPage);
    } else {
      _showSnackBar(context,
          '操作失败: ${resp['body']?['message'] ?? '未知错误'}');
    }
  } catch (e) {
    _showSnackBar(context, '操作失败: $e');
  }
}

void _showSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));
}
