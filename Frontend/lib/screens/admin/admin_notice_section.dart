import 'package:flutter/material.dart';

import 'admin_controller.dart';
import 'admin_common.dart';

/// Notice management section (super admin only).
class AdminNoticeSection extends StatefulWidget {
  final AdminController controller;
  const AdminNoticeSection({super.key, required this.controller});

  @override
  State<AdminNoticeSection> createState() => _AdminNoticeSectionState();
}

class _AdminNoticeSectionState extends State<AdminNoticeSection> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return SectionScaffold(
      title: '公告管理',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AdminSearchBar(
                  hintText: '搜索公告标题',
                  buttonLabel: '搜索',
                  onChanged: (v) => c.noticeSearchKeyword = v,
                  onPressed: () => c.loadNotices(page: 0),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () {
                  _titleCtrl.clear();
                  _contentCtrl.clear();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('清空编辑区'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (c.noticeLoading)
            const Center(child: CircularProgressIndicator())
          else
            PlaceholderTable(
              headers: const ['标题', '发布时间', '状态', '操作'],
              rows: c.noticeList
                  .map((n) => [
                        Text(n['title']?.toString() ?? ''),
                        Text(AdminController.formatPostTime(
                            n['createdAt']?.toString())),
                        Text((n['published'] == true) ? '已发布' : '草稿'),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () {
                                _titleCtrl.text =
                                    n['title']?.toString() ?? '';
                                _contentCtrl.text =
                                    n['content']?.toString() ?? '';
                              },
                              child: const Text('编辑'),
                            ),
                            TextButton(
                              onPressed: () => c.deleteNotice(
                                  (n['id'] ?? '').toString()),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              child: const Text('删除'),
                            ),
                          ],
                        ),
                      ])
                  .toList(),
            ),
          const SizedBox(height: 12),
          Pagination(
            currentPage: c.noticePage,
            totalItems: c.noticeTotal,
            pageSize: 5,
            onPageChanged: (p) => c.loadNotices(page: p),
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 12),
          const Text(
            '发布公告',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              hintText: '公告标题',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            controller: _titleCtrl,
          ),
          const SizedBox(height: 12),
          TextField(
            minLines: 5,
            maxLines: 12,
            decoration: InputDecoration(
              hintText: '请输入公告正文',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            controller: _contentCtrl,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.image_outlined),
                label: const Text('添加图片'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.link_outlined),
                label: const Text('添加链接'),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '（占位：后续可支持选择上传图片、插入外部链接，效果类似发帖编辑器）',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: () => _publishNotice(context),
              child: const Text('发布'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _publishNotice(BuildContext context) async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('公告标题不能为空')));
      return;
    }
    final content = _contentCtrl.text.trim();
    await widget.controller.createOrUpdateNotice(
      title: title,
      content: content.isEmpty ? null : content,
      onSuccess: () {
        _titleCtrl.clear();
        _contentCtrl.clear();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('公告发布成功')));
      },
    );
  }
}
