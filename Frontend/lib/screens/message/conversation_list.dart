/// 会话列表组件
///
/// 从 MessageScreen 中提取的会话列表部分，展示 ChatService 中的会话列表。
import 'package:flutter/material.dart';
import '../../models/conversation_model.dart';
import '../../widgets/conversation_item.dart';

class ConversationList extends StatelessWidget {
  final List<Conversation> conversations;
  final bool isLoading;
  final bool isSearching;
  final Future<void> Function() onRefresh;
  final VoidCallback onReload;
  final void Function(Conversation) onConversationTap;

  const ConversationList({
    Key? key,
    required this.conversations,
    required this.isLoading,
    required this.isSearching,
    required this.onRefresh,
    required this.onReload,
    required this.onConversationTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoadingView();
    }

    if (conversations.isEmpty) {
      return _buildEmptyView(context);
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: const Color(0xFF1976D2),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: conversations.length,
        separatorBuilder: (context, index) => const SizedBox(height: 1),
        itemBuilder: (context, index) {
          return ConversationItem(
            conversation: conversations[index],
            onTap: () => onConversationTap(conversations[index]),
          );
        },
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1976D2)),
            strokeWidth: 2,
          ),
          SizedBox(height: 16),
          Text(
            '加载中...',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.message_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            isSearching ? '没有找到相关聊天' : '暂无聊天记录',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            isSearching ? '尝试其他关键词' : '开始与同学聊天吧',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
          if (!isSearching) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: onReload,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF1976D2),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              ),
              child: const Text('重新加载'),
            ),
          ],
        ],
      ),
    );
  }
}
