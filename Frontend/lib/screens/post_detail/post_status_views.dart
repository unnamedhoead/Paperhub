/// 帖子状态提示视图（从 post_detail_screen.dart 抽出，行为不变）。
///
/// - [PostRemovedWarning]：帖子被下架但作者仍可见时，正文上方的红色告警条。
/// - [PostUnavailableView]：帖子整体不可见（草稿/审核中/已下架等）时的占位整页提示。
library;

import 'package:flutter/material.dart';

/// 帖子被下架（仅作者可见）时的告警条。
class PostRemovedWarning extends StatelessWidget {
  const PostRemovedWarning({super.key, this.hiddenReason});

  final String? hiddenReason;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '该笔记已被管理员下架，仅作者可见',
                  style: TextStyle(
                    color: Colors.red.shade900,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (hiddenReason != null && hiddenReason!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '原因：$hiddenReason',
                      style: TextStyle(color: Colors.red.shade800, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 帖子整体不可见时的占位提示页。[status] 为帖子状态（DRAFT/AUDIT/REMOVED…）。
class PostUnavailableView extends StatelessWidget {
  const PostUnavailableView({super.key, this.status, this.hiddenReason});

  final String? status;
  final String? hiddenReason;

  @override
  Widget build(BuildContext context) {
    String message;
    IconData icon;
    Color color;

    switch (status?.toUpperCase()) {
      case 'DRAFT':
        message = '该笔记目前为草稿状态，不可见';
        icon = Icons.edit_note;
        color = Colors.orange;
        break;
      case 'AUDIT':
        message = '该笔记正在审核中，暂不可见';
        icon = Icons.hourglass_empty;
        color = Colors.blue;
        break;
      case 'REMOVED':
        message = '该笔记已被下架，不可见';
        icon = Icons.block;
        color = Colors.red;
        break;
      default:
        message = '该笔记目前不可见';
        icon = Icons.visibility_off;
        color = Colors.grey;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: color),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            if (hiddenReason != null && hiddenReason!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '原因：$hiddenReason',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
