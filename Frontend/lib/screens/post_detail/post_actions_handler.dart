/// 帖子分享 / 更多操作的交互处理器（从 post_detail_screen.dart 抽出）。
///
/// 封装需要 BuildContext 的 UI 流程：分享给某用户、弹出「编辑/删除/举报」菜单、
/// 删除前确认、打开编辑页。数据/网络通过传入的 [controller] 完成；当前用户、是否作者、
/// 组件是否仍挂载等动态值通过取值器读取。Screen 仅持有一个 handler 实例并在事件里调用。
///
/// 行为与原 _PostDetailScreenState 中的 _onShare / _sharePostToUser / _openMoreActions /
/// _confirmDeletePost / _openEditPost 完全一致。
library;

import 'package:flutter/material.dart';

import '../../models/message_model.dart';
import '../../models/post_model.dart';
import '../../services/chat_service.dart';
import '../../utils/dialog_utils.dart';
import '../../widgets/report_post_dialog.dart';
import '../chat_screen.dart';
import '../note_editor/note_editor_screen.dart';
import 'post_detail_controller.dart';
import 'share_user_selection_sheet.dart';

/// 帖子分享 / 更多操作处理器。
class PostActionsHandler {
  PostActionsHandler({
    required this.post,
    required this.controller,
    required this.currentUserId,
    required this.isOwner,
    required this.isMounted,
    required this.showMessage,
  });

  final Post post;
  final PostDetailController controller;
  final String? Function() currentUserId;
  final bool Function() isOwner;
  final bool Function() isMounted;

  /// 显示提示（复用 Screen 的 SnackBar）。
  final void Function(String message) showMessage;

  /// 分享入口：弹出用户选择，选中后分享给该用户。
  Future<void> share(BuildContext context) async {
    final uid = currentUserId();
    if (uid == null) {
      showMessage('请先登录');
      return;
    }

    final selectedUserId = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ShareUserSelectionSheet(currentUserId: uid, post: post),
    );

    if (selectedUserId == null) return;
    if (!context.mounted) return;
    await _shareToUser(context, selectedUserId);
  }

  Future<void> _shareToUser(BuildContext context, String targetUserId) async {
    try {
      if (!isMounted()) return;
      showMessage('正在分享...');

      final chatService = ChatService();
      final conversation =
          await chatService.createOrGetPrivateConversation(targetUserId);

      if (conversation == null) {
        if (!isMounted()) return;
        showMessage('创建会话失败，请稍后重试');
        return;
      }

      // 使用 SHARE 类型，content 只存储 post ID。
      await chatService.sendMessage(
        conversationId: conversation.id,
        content: post.id,
        type: MessageType.share,
      );

      if (!isMounted() || !context.mounted) return;
      showMessage('分享成功');

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(conversation: conversation),
        ),
      );
    } catch (e) {
      if (!isMounted()) return;
      showMessage('分享失败: $e');
    }
  }

  /// 弹出「编辑/删除/举报」菜单。
  void openMoreActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            if (isOwner())
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('编辑笔记'),
                onTap: () async {
                  Navigator.pop(context);
                  await openEditPost(context);
                },
              ),
            if (isOwner())
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title:
                    const Text('删除笔记', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeletePost(context);
                },
              ),
            ListTile(
              leading: const Icon(Icons.flag),
              title: const Text('举报'),
              onTap: () async {
                Navigator.pop(context);
                final result = await showDialog(
                  context: context,
                  builder: (_) =>
                      ReportPostDialog(postId: int.parse(post.id)),
                );
                if (result == true && isMounted()) {
                  showMessage('举报成功，我们会尽快处理');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeletePost(BuildContext context) async {
    final confirmed = await DialogUtils.showDeleteConfirmDialog(
      context: context,
      itemName: '笔记',
      additionalWarning: '删除后将无法恢复。',
    );
    if (confirmed == true) {
      // 删除成功后由 controller 的 onPostDeleted 回调 pop 返回上一页。
      await controller.deletePost();
    }
  }

  /// 打开编辑页；保存成功（返回 true）则刷新详情。
  Future<void> openEditPost(BuildContext context) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => NoteEditorPage(initialPost: post)),
    );
    if (result == true) {
      await controller.loadPostDetail();
    }
  }
}
