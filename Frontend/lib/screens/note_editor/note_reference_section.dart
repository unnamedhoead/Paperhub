// lib/screens/note_editor/note_reference_section.dart
//
// 引用文献区（独立 Widget）+ 引用选择对话框。
// 读取 [NoteEditorController] 的引用状态，加载 / 选择动作经 controller 方法。

import 'package:flutter/material.dart';

import '../../models/post_model.dart';
import 'note_editor_controller.dart';

/// 引用文献输入区。
class NoteReferencesSection extends StatelessWidget {
  const NoteReferencesSection({
    super.key,
    required this.controller,
    required this.onAddReference,
  });

  final NoteEditorController controller;
  final VoidCallback onAddReference;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = controller.selectedReferences;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '引用文献',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: onAddReference,
              icon: const Icon(Icons.library_books, size: 18),
              label: const Text('添加引用文献'),
              style: ElevatedButton.styleFrom(
                backgroundColor: scheme.surfaceVariant,
                foregroundColor: scheme.onSurface,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(width: 12),
            if (selected.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '已选择 ${selected.length} 篇',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
        if (selected.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: scheme.outline.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '已选择的引用文献：',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                ...selected.map((postId) => _SelectedReferenceRow(
                      controller: controller,
                      postId: postId,
                      scheme: scheme,
                    )),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SelectedReferenceRow extends StatelessWidget {
  const _SelectedReferenceRow({
    required this.controller,
    required this.postId,
    required this.scheme,
  });

  final NoteEditorController controller;
  final int postId;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final selected = controller.selectedReferences;
    // 从用户帖子和收藏中找到对应的帖子信息
    final post = [...controller.userPosts, ...controller.userFavorites]
        .where((p) => int.tryParse(p.id) == postId)
        .cast<Post?>()
        .firstWhere((p) => p != null, orElse: () => null);

    final index = selected.indexOf(postId) + 1;
    final String label;
    final bool loaded = post != null;
    if (loaded) {
      final d = post.createdAt;
      final date =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      label = '[$index] ${post.author.name}. ${post.title}. '
          '${post.mainDiscipline}, $date.';
    } else {
      label = '[$index] 帖子ID: $postId (信息加载中...)';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: loaded ? scheme.onSurface : Colors.grey,
              ),
            ),
          ),
          IconButton(
            onPressed: () => controller.removeReference(postId),
            icon: const Icon(Icons.close, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

/// 弹出引用文献选择对话框。返回时由调用方刷新页面。
Future<void> showReferenceSelectorDialog(
  BuildContext context,
  NoteEditorController controller,
) {
  return showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setLocalState) => AlertDialog(
        title: const Text('选择引用文献'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: '我的帖子'),
                    Tab(text: '我的收藏'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _ReferencePostList(
                        controller: controller,
                        posts: controller.userPosts,
                        onChanged: setLocalState,
                      ),
                      _ReferencePostList(
                        controller: controller,
                        posts: controller.userFavorites,
                        onChanged: setLocalState,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    ),
  );
}

class _ReferencePostList extends StatelessWidget {
  const _ReferencePostList({
    required this.controller,
    required this.posts,
    required this.onChanged,
  });

  final NoteEditorController controller;
  final List<Post> posts;
  final void Function(VoidCallback) onChanged;

  @override
  Widget build(BuildContext context) {
    if (controller.isLoadingReferences) {
      return const Center(child: CircularProgressIndicator());
    }
    if (posts.isEmpty) {
      return const Center(child: Text('暂无内容'));
    }

    return ListView.builder(
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        final postId = int.tryParse(post.id) ?? 0;
        final isSelected = controller.selectedReferences.contains(postId);

        void toggle() {
          // 更新 controller 状态并同步刷新对话框本地 UI
          controller.toggleReference(postId, !isSelected);
          onChanged(() {});
        }

        final d = post.createdAt;
        return ListTile(
          leading: Checkbox(
            value: isSelected,
            onChanged: (_) => toggle(),
          ),
          title:
              Text(post.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            '${post.author.name} · ${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
            style: const TextStyle(fontSize: 12),
          ),
          onTap: toggle,
        );
      },
    );
  }
}
