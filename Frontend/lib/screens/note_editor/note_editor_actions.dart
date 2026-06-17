// lib/screens/note_editor/note_editor_actions.dart
//
// 底部发布操作按钮 + 管理员退回说明 banner（独立 Widget）。
// 发布动作经 onPublish 回调交给 screen（screen 负责弹加载框 / 导航）。

import 'package:flutter/material.dart';

/// 发布回调签名：可指定状态覆盖与成功文案。
typedef NotePublishCallback = void Function({
  String? statusOverride,
  String? customSuccessMessage,
});

/// 管理员退回说明 banner。
class NoteAdminFeedbackBanner extends StatelessWidget {
  const NoteAdminFeedbackBanner({super.key, required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    final displayReason = reason.trim().isEmpty ? '管理员未提供具体原因' : reason.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFCC80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.info_outline, color: Color(0xFFF57C00), size: 18),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  '管理员退回说明',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFF57C00),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            displayReason,
            style: const TextStyle(fontSize: 13, color: Color(0xFF5D4037)),
          ),
        ],
      ),
    );
  }
}

/// 底部发布 / 保存按钮组。
class NoteBottomActions extends StatelessWidget {
  const NoteBottomActions({
    super.key,
    required this.isEditing,
    required this.isAdminRejectedDraft,
    required this.onPublish,
  });

  final bool isEditing;
  final bool isAdminRejectedDraft;
  final NotePublishCallback onPublish;

  @override
  Widget build(BuildContext context) {
    if (!isEditing) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => onPublish(),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1976D2),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            '发布笔记',
            style: TextStyle(fontSize: 16, color: Colors.white),
          ),
        ),
      );
    }

    final String secondButtonLabel = isAdminRejectedDraft ? '保存并提交审核' : '保存并发布';
    final String secondButtonStatus = isAdminRejectedDraft ? 'AUDIT' : 'NORMAL';
    final String secondButtonSuccess = isAdminRejectedDraft ? '已提交审核' : '发布成功';

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => onPublish(
              statusOverride: 'DRAFT',
              customSuccessMessage: '已保存为草稿',
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              foregroundColor: const Color(0xFF1976D2),
              side: const BorderSide(color: Color(0xFF1976D2)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('保存为草稿', style: TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () => onPublish(
              statusOverride: secondButtonStatus,
              customSuccessMessage: secondButtonSuccess,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              secondButtonLabel,
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
