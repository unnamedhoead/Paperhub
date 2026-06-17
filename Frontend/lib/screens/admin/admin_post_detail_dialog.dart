import 'package:flutter/material.dart';

import '../../services/api/post_api.dart';
import 'admin_controller.dart';

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
