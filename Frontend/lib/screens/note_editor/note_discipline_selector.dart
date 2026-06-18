// lib/screens/note_editor/note_discipline_selector.dart
//
// 学科分区选择器（独立 Widget）。读取 [NoteEditorController] 状态，
// 分区选择经 controller 方法。#标签建议浮层见 note_tag_suggestions.dart。

import 'package:flutter/material.dart';

import '../../constants/discipline_constants.dart';
import 'note_editor_controller.dart';

/// 一级标签（学科分区）下拉隐藏式选择器。
class NoteDisciplineSelector extends StatelessWidget {
  const NoteDisciplineSelector({super.key, required this.controller});

  final NoteEditorController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = controller.selectedDiscipline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题行
        Row(
          children: [
            Text(
              '选择分区',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '必选',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Spacer(),
            Row(
              children: [
                if (selected != null) _SelectedChip(discipline: selected),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: controller.toggleDisciplineDropdown,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: scheme.outline.withOpacity(0.3)),
                    ),
                    child: Icon(
                      controller.showDisciplineDropdown
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 20,
                      color: scheme.onSurface.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (controller.showDisciplineDropdown) _DropdownPanel(controller: controller),
        const SizedBox(height: 8),
        const Text(
          '选择学科分区后，在正文中输入#可添加相关细分类标签',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}

class _SelectedChip extends StatelessWidget {
  const _SelectedChip({required this.discipline});
  final String discipline;

  @override
  Widget build(BuildContext context) {
    final color = kDisciplineColors[discipline] ?? const Color(0xFF1976D2);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Text(
        discipline,
        style: TextStyle(
          fontSize: 14,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DropdownPanel extends StatelessWidget {
  const _DropdownPanel({required this.controller});
  final NoteEditorController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filteredDisciplines = controller.getFilteredDisciplines();
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '选择分区',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: controller.closeDisciplineDropdown,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: scheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: scheme.onSurface.withOpacity(0.8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: filteredDisciplines
                .map((d) => _DisciplineChip(controller: controller, discipline: d))
                .toList(),
          ),
          if (controller.selectedDiscipline == null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 14, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '请点击上方的椭圆形标签选择一个分区',
                      style: TextStyle(
                          fontSize: 12, color: Colors.orange.shade700),
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

class _DisciplineChip extends StatelessWidget {
  const _DisciplineChip({required this.controller, required this.discipline});
  final NoteEditorController controller;
  final String discipline;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bool selected = controller.selectedDiscipline == discipline;
    final chipColor = kDisciplineColors[discipline] ?? scheme.primary;
    final textColor = scheme.onSurface;
    final borderColor = scheme.onSurface.withOpacity(0.45);

    return GestureDetector(
      onTap: () => controller.selectDiscipline(discipline),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? chipColor.withOpacity(0.16)
              : scheme.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: selected ? 1.5 : 1),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: chipColor.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: chipColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: chipColor.withOpacity(0.4),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
            Text(
              discipline,
              style: TextStyle(
                fontSize: 13,
                color: textColor,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (selected)
              Container(
                margin: const EdgeInsets.only(left: 6),
                child: Icon(Icons.check_circle, size: 14, color: chipColor),
              ),
          ],
        ),
      ),
    );
  }
}
