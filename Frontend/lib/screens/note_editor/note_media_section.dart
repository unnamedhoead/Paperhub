// lib/screens/note_editor/note_media_section.dart
//
// 媒体相关 UI：图片九宫格、外部链接区、PDF 附件区。
// 均为独立 Widget，读取 [NoteEditorController] 状态，IO / 校验经回调交给 screen。

import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'note_editor_controller.dart';

/// 图片九宫格（支持：已有图片 + 新选图片）。
class NoteImageGrid extends StatelessWidget {
  const NoteImageGrid({
    super.key,
    required this.controller,
    required this.onPickImage,
  });

  final NoteEditorController controller;
  final VoidCallback onPickImage;

  @override
  Widget build(BuildContext context) {
    final existing = controller.existingImageUrls;
    final images = controller.images;
    final int existingCount = existing.length;
    final int newCount = images.length;
    final int totalImages = existingCount + newCount;

    // 最多 9 张，多出来的不再显示"添加"按钮
    final bool showAddButton = totalImages < 9;
    final int itemCount = showAddButton ? totalImages + 1 : totalImages;

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: itemCount,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        // 1) 先画"已有图片"（后端返回的 URL）
        if (index < existingCount) {
          return _Tile(
            image: NetworkImage(existing[index]),
            onRemove: () => controller.removeExistingImage(index),
          );
        }

        // 2) 再画"新选图片"（本地 XFile）
        final int newIndex = index - existingCount;
        if (newIndex < newCount) {
          final xfile = images[newIndex];
          // Web：image_picker 返回的 path 是 blob: 本地 URL，用 NetworkImage；
          // 移动端 / 桌面：用 FileImage。
          final ImageProvider previewImage =
              kIsWeb ? NetworkImage(xfile.path) : FileImage(File(xfile.path));
          return _Tile(
            image: previewImage,
            onRemove: () => controller.removeImage(newIndex),
          );
        }

        // 3) 最后是"添加图片"按钮
        return GestureDetector(
          onTap: onPickImage,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Icon(Icons.add, size: 34, color: Colors.grey),
            ),
          ),
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.image, required this.onRemove});

  final ImageProvider image;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
            image: DecorationImage(image: image, fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(3),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }
}

/// 外部链接输入区。
class NoteExternalLinksSection extends StatelessWidget {
  const NoteExternalLinksSection({
    super.key,
    required this.controller,
    required this.onAddLink,
  });

  final NoteEditorController controller;
  final VoidCallback onAddLink;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          '外部链接',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller.linkController,
                decoration: InputDecoration(
                  hintText: '输入链接后点击右侧添加',
                  hintStyle:
                      TextStyle(color: scheme.onSurface.withOpacity(0.6)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        BorderSide(color: scheme.outline.withOpacity(0.3)),
                  ),
                  isDense: true,
                  filled: true,
                  fillColor: scheme.surfaceVariant,
                ),
                style: TextStyle(color: scheme.onSurface),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: onAddLink,
              icon: const Icon(Icons.add_link, size: 18),
              label: const Text('添加'),
              style: ElevatedButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (controller.externalLinks.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: controller.externalLinks.map((link) {
              return Chip(
                label: SizedBox(
                  width: 160,
                  child: Text(link, overflow: TextOverflow.ellipsis),
                ),
                onDeleted: () => controller.removeExternalLink(link),
              );
            }).toList(),
          ),
      ],
    );
  }
}

/// PDF 附件区域。
class NotePdfSection extends StatelessWidget {
  const NotePdfSection({
    super.key,
    required this.controller,
    required this.onPickPdf,
  });

  final NoteEditorController controller;
  final VoidCallback onPickPdf;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasPdf = controller.hasPdf;
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: onPickPdf,
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: Text(hasPdf ? '替换 PDF' : '添加 PDF 附件（仅一篇）'),
          style: ElevatedButton.styleFrom(
            backgroundColor: scheme.surfaceVariant,
            foregroundColor: scheme.onSurface,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(width: 12),
        if (hasPdf)
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      controller.pdfFile != null
                          ? (controller.pdfFileName ?? '已选择 PDF')
                          : (controller.existingPdfUrl!.split('/').last),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: scheme.onSurface),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      if (controller.pdfFile != null) {
                        controller.removePdf(); // 清空新选 PDF
                      } else {
                        controller.removeExistingPdf(); // 清空旧的 PDF URL
                      }
                    },
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
