/// 聊天页顶部 AppBar
///
/// 私聊显示对方名称与头像，群聊显示群名与成员数。
/// 点击标题区触发 [onTitleTap]（携带应跳转的用户 id）。
import 'package:flutter/material.dart';
import '../../models/conversation_model.dart';

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Conversation? conversation;
  final VoidCallback onBack;

  /// 点击标题区时回调，参数为对方用户 id（仅私聊且有参与者时调用）。
  final ValueChanged<String> onTitleTap;

  const ChatAppBar({
    Key? key,
    required this.conversation,
    required this.onBack,
    required this.onTitleTap,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final conversation = this.conversation;

    if (conversation == null) {
      return AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        leading: IconButton(
            icon: Icon(Icons.arrow_back, color: scheme.onSurface),
            onPressed: onBack),
        title: Text('加载中...',
            style: TextStyle(
                color: scheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
      );
    }

    return AppBar(
      backgroundColor: scheme.surface,
      elevation: 0,
      leading: IconButton(
          icon: Icon(Icons.arrow_back, color: scheme.onSurface),
          onPressed: onBack),
      title: GestureDetector(
        onTap: () {
          if (conversation.type == ConversationType.private &&
              conversation.participants.isNotEmpty) {
            final otherUser = conversation.participants.firstWhere(
                (p) => !p.isMe,
                orElse: () => conversation.participants.first);
            onTitleTap(otherUser.id);
          }
        },
        child: Row(children: [
          _buildAvatar(conversation),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(conversation.displayName,
                    style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                if (conversation.type == ConversationType.group)
                  Text('${conversation.participants.length} 位成员',
                      style: TextStyle(
                          color: scheme.onSurfaceVariant, fontSize: 12)),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildAvatar(Conversation conversation) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9), color: Colors.grey[200]),
      child: conversation.displayAvatar != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Image.network(conversation.displayAvatar!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _buildDefaultAvatar(conversation)),
            )
          : _buildDefaultAvatar(conversation),
    );
  }

  Widget _buildDefaultAvatar(Conversation conversation) {
    final name = conversation.displayName;
    final firstChar = name.isNotEmpty ? name[0] : '?';
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
        ),
      ),
      child: Center(
        child: Text(firstChar,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold)),
      ),
    );
  }
}
