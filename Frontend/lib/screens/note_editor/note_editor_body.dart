// lib/screens/note_editor/note_editor_body.dart
//
// 笔记编辑器表单主体（独立 Widget）。组合各 section 子 Widget，
// 读取 [NoteEditorController] 状态；所有副作用（IO / 导航 / SnackBar）经回调
// 由 NoteEditorPage 提供。

import 'package:flutter/material.dart';

import '../../models/post_model.dart';
import 'note_arxiv_section.dart';
import 'note_discipline_selector.dart';
import 'note_editor_actions.dart';
import 'note_editor_controller.dart';
import 'note_media_section.dart';
import 'note_reference_section.dart';
import 'note_tag_suggestions.dart';

class NoteEditorBody extends StatelessWidget {
  const NoteEditorBody({
    super.key,
    required this.controller,
    required this.initialPost,
    required this.isEditing,
    required this.titleController,
    required this.contentController,
    required this.contentFocusNode,
    required this.onPickImage,
    required this.onPickPdf,
    required this.onAddLink,
    required this.onFetchArxiv,
    required this.onAddReference,
    required this.onPublish,
  });

  final NoteEditorController controller;
  final Post? initialPost;
  final bool isEditing;
  final TextEditingController titleController;
  final TextEditingController contentController;
  final FocusNode contentFocusNode;
  final VoidCallback onPickImage;
  final VoidCallback onPickPdf;
  final VoidCallback onAddLink;
  final VoidCallback onFetchArxiv;
  final VoidCallback onAddReference;
  final NotePublishCallback onPublish;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Post? editingPost = initialPost;
    final String? currentStatus = editingPost?.status?.toUpperCase();
    final bool isDraft = isEditing && currentStatus == 'DRAFT';
    final bool hasHiddenReason =
        isDraft && (editingPost?.hiddenReason?.trim().isNotEmpty ?? false);
    final bool isAdminRejectedDraft = isDraft && hasHiddenReason;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isAdminRejectedDraft) ...[
            NoteAdminFeedbackBanner(
              reason:
                  editingPost!.draftReason ?? editingPost.hiddenReason ?? '',
            ),
            const SizedBox(height: 16),
          ],

          // 选择图片
          NoteImageGrid(controller: controller, onPickImage: onPickImage),
          const SizedBox(height: 16),

          // 标题
          TextField(
            controller: titleController,
            textInputAction: TextInputAction.next,
            maxLines: 1,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: '添加标题（最多一行）',
              hintStyle: TextStyle(color: scheme.onSurface.withOpacity(0.6)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
            ),
          ),
          Divider(height: 1, color: scheme.outline.withOpacity(0.3)),
          const SizedBox(height: 8),

          // 正文（支持#符号添加标签）
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: contentController,
                focusNode: contentFocusNode,
                keyboardType: TextInputType.multiline,
                maxLines: null,
                minLines: 6,
                onChanged: controller.onContentChanged,
                decoration: InputDecoration(
                  hintText: '写下你的笔记（输入#添加标签，支持学术笔记格式）',
                  hintStyle:
                      TextStyle(color: scheme.onSurface.withOpacity(0.6)),
                  border: InputBorder.none,
                  isCollapsed: false,
                ),
                style: TextStyle(color: scheme.onSurface),
              ),
              NoteTagSuggestions(controller: controller),
            ],
          ),

          // 一级标签选择（学科分区）
          NoteDisciplineSelector(controller: controller),
          const SizedBox(height: 16),

          // 高级选项入口（+ 号展开 / 收起）
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '更多学术选项（可选）',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurface,
                ),
              ),
              IconButton(
                onPressed: controller.toggleAdvancedOptions,
                icon: Icon(
                  controller.showAdvancedOptions
                      ? Icons.remove_circle_outline // 展开时显示 -
                      : Icons.add_circle_outline, // 收起时显示 +
                  color: scheme.primary,
                ),
              ),
            ],
          ),

          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: controller.showAdvancedOptions
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NoteExternalLinksSection(
                  controller: controller,
                  onAddLink: onAddLink,
                ),
                const SizedBox(height: 16),
                NoteArxivSection(controller: controller, onFetch: onFetchArxiv),
                const SizedBox(height: 16),
                NoteReferencesSection(
                  controller: controller,
                  onAddReference: onAddReference,
                ),
                const SizedBox(height: 16),
                NotePdfSection(controller: controller, onPickPdf: onPickPdf),
              ],
            ),
            secondChild: const SizedBox.shrink(),
          ),

          const SizedBox(height: 24),

          // 发布按钮
          NoteBottomActions(
            isEditing: isEditing,
            isAdminRejectedDraft: isAdminRejectedDraft,
            onPublish: onPublish,
          ),
        ],
      ),
    );
  }
}
