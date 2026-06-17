/// 聊天消息列表区域
///
/// 负责渲染消息 ListView、日期分组头、加载更多指示器，以及
/// 加载中 / 空会话两种占位视图。滚动控制由外部传入的 [scrollController]
/// 管理（外层 State 监听它做分页与已读上报）。
import 'package:flutter/material.dart';
import '../../models/message_model.dart';
import '../../widgets/message_bubble.dart';

class ChatMessageList extends StatelessWidget {
  final List<Message> messages;
  final ScrollController scrollController;
  final bool initialLoadComplete;
  final bool isLoadingMoreMessages;

  /// 点击某条消息头像时回调，参数为该消息发送者 id。
  final ValueChanged<String> onAvatarTap;

  const ChatMessageList({
    Key? key,
    required this.messages,
    required this.scrollController,
    required this.initialLoadComplete,
    required this.isLoadingMoreMessages,
    required this.onAvatarTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!initialLoadComplete) return _buildLoadingView();
    if (messages.isEmpty) return _buildEmptyView();

    return Column(children: [
      if (isLoadingMoreMessages)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Color(0xFF1976D2))),
            ),
          ),
        ),
      Expanded(
        child: ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(vertical: 16),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            final showDateHeader = index == 0 ||
                !_isSameDay(
                    messages[index - 1].createdAt, message.createdAt);
            return Column(children: [
              if (showDateHeader)
                _buildDateHeader(context, message.createdAt),
              MessageBubble(
                message: message,
                showAvatar: true,
                onAvatarTap: () => onAvatarTap(message.senderId),
              ),
            ]);
          },
        ),
      ),
    ]);
  }

  Widget _buildDateHeader(BuildContext context, DateTime date) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
              color: scheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12)),
          child: Text(_formatDateHeader(date),
              style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(Color(0xFF1976D2)),
                strokeWidth: 2),
            SizedBox(height: 16),
            Text('加载消息中...',
                style: TextStyle(color: Colors.grey, fontSize: 14)),
          ]),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline,
                size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('暂无消息',
                style: TextStyle(color: Colors.grey[600], fontSize: 16)),
            const SizedBox(height: 8),
            Text('开始对话吧',
                style: TextStyle(color: Colors.grey[500], fontSize: 14)),
          ]),
    );
  }

  String _formatDateHeader(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate =
        DateTime(dateTime.year, dateTime.month, dateTime.day);
    final difference = messageDate.difference(today).inDays;
    switch (difference) {
      case 0:
        return '今天';
      case -1:
        return '昨天';
      default:
        return '${dateTime.month}月${dateTime.day}日';
    }
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}
