/// 聊天页底部输入区
///
/// 在 [ChatInput] 外包一层带阴影的容器，承接文本与媒体两类发送回调。
import 'package:flutter/material.dart';
import '../../widgets/chat_input.dart';

class ChatInputArea extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSend;
  final void Function(
          List<String> mediaUrls, String messageType, String fileName, int fileSize)
      onSendMedia;

  const ChatInputArea({
    Key? key,
    required this.controller,
    required this.onSend,
    required this.onSendMedia,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: scheme.surface, boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 3,
            offset: const Offset(0, -2)),
      ]),
      child: ChatInput(
        controller: controller,
        onSend: onSend,
        onSendMedia: onSendMedia,
        hintText: '输入消息...',
      ),
    );
  }
}
