// lib/screens/note_editor/note_tag_suggestions.dart
//
// #标签建议浮层（独立 Widget）。读取 [NoteEditorController] 的标签建议状态，
// 选择标签经 controller.selectTagSuggestion。

import 'package:flutter/material.dart';

import 'note_editor_controller.dart';

/// #标签建议浮层。
class NoteTagSuggestions extends StatelessWidget {
  const NoteTagSuggestions({super.key, required this.controller});

  final NoteEditorController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.showTagSuggestions) {
      return const SizedBox.shrink();
    }

    final isCustom = controller.isTypingCustomTag;
    final input = controller.currentTagInput;
    final suggestions = controller.filteredTagSuggestions;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade300),
      ),
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              isCustom ? '自定义标签（按空格或回车完成输入）' : '标签建议（输入#继续筛选）',
              style: TextStyle(
                fontSize: 12,
                color: isCustom ? Colors.orange.shade700 : Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Divider(height: 1),
          ...suggestions.map((tag) {
            final bool alreadySelected =
                controller.contentController.text.contains('#$tag ');
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => controller.selectTagSuggestion(tag),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.shade200,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.tag,
                        size: 16,
                        color: alreadySelected
                            ? Colors.blue
                            : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 14,
                            color:
                                alreadySelected ? Colors.blue : Colors.black87,
                            fontWeight: alreadySelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (alreadySelected)
                        const Icon(Icons.check, size: 16, color: Colors.blue),
                    ],
                  ),
                ),
              ),
            );
          }),
          if (suggestions.isEmpty && input.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isCustom
                          ? '正在输入自定义标签 "$input"，按空格或回车完成输入'
                          : '未找到匹配的标签，按空格或回车可输入自定义标签 "$input"',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                      ),
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
