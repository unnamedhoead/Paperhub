/// 文本消息气泡内容组件
import 'package:flutter/material.dart';
import '../../models/message_model.dart';

class TextBubbleContent extends StatelessWidget {
  final Message message;

  const TextBubbleContent({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: message.isMe ? scheme.primary : scheme.surfaceVariant,
        borderRadius: BorderRadius.circular(18).copyWith(
          bottomLeft: message.isMe
              ? const Radius.circular(18)
              : const Radius.circular(4),
          bottomRight: message.isMe
              ? const Radius.circular(4)
              : const Radius.circular(18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        message.content,
        style: TextStyle(
          color: message.isMe ? scheme.onPrimary : scheme.onSurface,
          fontSize: 16,
          height: 1.4,
        ),
      ),
    );
  }
}
