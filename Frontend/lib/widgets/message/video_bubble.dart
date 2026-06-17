/// 视频消息气泡内容组件
import 'package:flutter/material.dart';
import '../../models/message_model.dart';
import '../video_message_player.dart';
import 'text_bubble.dart';

class VideoBubbleContent extends StatelessWidget {
  final Message message;

  const VideoBubbleContent({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final videoUrl =
        message.fileUrl ?? message.mediaUrls.firstOrNull ?? '';
    if (videoUrl.isEmpty) {
      return TextBubbleContent(message: message);
    }
    return VideoMessagePlayer(
      videoUrl: videoUrl,
      isMe: message.isMe,
    );
  }
}
