// lib/screens/note_editor/note_arxiv_section.dart
//
// arXiv 文献信息区（独立 Widget）。读取 [NoteEditorController] 的 arXiv 状态，
// 拉取动作经 onFetch 回调交给 screen（screen 负责弹 SnackBar）。

import 'package:flutter/material.dart';

import 'note_editor_controller.dart';

class NoteArxivSection extends StatelessWidget {
  const NoteArxivSection({
    super.key,
    required this.controller,
    required this.onFetch,
  });

  final NoteEditorController controller;
  final VoidCallback onFetch;

  @override
  Widget build(BuildContext context) {
    final isLoading = controller.isLoadingArxiv;
    final metadata = controller.arxivMetadata;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'arXiv 文献信息',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller.arxivController,
                decoration: InputDecoration(
                  hintText: '输入 arXiv ID (如: 1234.5678) 或链接',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  enabled: !isLoading,
                ),
                onSubmitted: (_) => onFetch(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: isLoading ? null : onFetch,
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search, size: 18),
              label: const Text('获取'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        if (metadata != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        metadata.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: controller.clearArxivMetadata,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (metadata.authors.isNotEmpty)
                  _MetaLine('作者：${metadata.authorsFormatted}'),
                if (metadata.publishedDateFormatted != null)
                  _MetaLine('发布日期：${metadata.publishedDateFormatted}'),
                if (metadata.categories.isNotEmpty)
                  _MetaLine('分类：${metadata.categories.join(", ")}'),
                if (metadata.doi != null) _MetaLine('DOI：${metadata.doi}'),
                if (metadata.journal != null)
                  _MetaLine('期刊：${metadata.journal}'),
                if (controller.arxivId != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'arXiv ID: ${controller.arxivId}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
      ),
    );
  }
}
