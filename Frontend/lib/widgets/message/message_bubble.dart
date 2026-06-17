/// 消息气泡组件 — 主入口
///
/// 根据 MessageType 分发到对应的内容组件，统一处理头像、对齐、时间等外层布局。
import 'package:flutter/material.dart';
import '../../models/message_model.dart';
import 'text_bubble.dart';
import 'image_bubble.dart';
import 'video_bubble.dart';
import 'audio_bubble.dart';
import 'file_bubble.dart';
import 'system_bubble.dart';
import 'share_bubble.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool showAvatar;
  final bool showTime;
  final VoidCallback? onAvatarTap;

  const MessageBubble({
    Key? key,
    required this.message,
    this.showAvatar = true,
    this.showTime = true,
    this.onAvatarTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment:
            message.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isMe && showAvatar) ...[
            _buildAvatar(context),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  message.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                _buildContent(context),
                if (showTime) ...[
                  const SizedBox(height: 4),
                  _buildMeta(context),
                ],
              ],
            ),
          ),
          if (message.isMe && showAvatar) ...[
            const SizedBox(width: 8),
            _buildAvatar(context),
          ],
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (message.type) {
      case MessageType.text:
        return TextBubbleContent(message: message);
      case MessageType.image:
        return ImageBubbleContent(message: message);
      case MessageType.video:
        return VideoBubbleContent(message: message);
      case MessageType.file:
        return FileBubbleContent(message: message);
      case MessageType.voice:
        return AudioBubbleContent(message: message);
      case MessageType.system:
        return SystemBubbleContent(message: message);
      case MessageType.share:
        return ShareBubbleContent(message: message);
      default:
        return TextBubbleContent(message: message);
    }
  }

  Widget _buildAvatar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onAvatarTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: scheme.surfaceVariant,
        ),
        child: message.senderAvatar != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  message.senderAvatar!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _buildDefaultAvatar(),
                ),
              )
            : _buildDefaultAvatar(),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    final name = message.senderName;
    final firstChar = name.isNotEmpty ? name[0] : '?';
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: message.isMe
              ? [const Color(0xFF1976D2), const Color(0xFF42A5F5)]
              : [Colors.grey[400]!, Colors.grey[600]!],
        ),
      ),
      child: Center(
        child: Text(
          firstChar,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildMeta(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final secondary = scheme.onSurfaceVariant;
    return Row(
      mainAxisAlignment:
          message.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!message.isMe) ...[
          Text(
            _formatTime(message.createdAt),
            style: TextStyle(color: secondary, fontSize: 11),
          ),
          const SizedBox(width: 4),
          Text(
            message.senderName,
            style: TextStyle(
              color: secondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ] else ...[
          _buildStatus(),
          const SizedBox(width: 4),
          Text(
            _formatTime(message.createdAt),
            style: TextStyle(color: secondary, fontSize: 11),
          ),
        ],
      ],
    );
  }

  Widget _buildStatus() {
    IconData icon;
    Color color;
    switch (message.status) {
      case MessageStatus.sending:
        icon = Icons.access_time;
        color = Colors.grey[400]!;
        break;
      case MessageStatus.sent:
        icon = Icons.check;
        color = Colors.grey[400]!;
        break;
      case MessageStatus.delivered:
        icon = Icons.done_all;
        color = Colors.grey[400]!;
        break;
      case MessageStatus.read:
        icon = Icons.done_all;
        color = Colors.blue[400]!;
        break;
      case MessageStatus.failed:
        icon = Icons.error;
        color = Colors.red[400]!;
        break;
      default:
        icon = Icons.check;
        color = Colors.grey[400]!;
    }
    return Icon(icon, size: 14, color: color);
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inDays == 0) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return '昨天 ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.month}/${dateTime.day}';
    }
  }
}

/// Shared helpers used by bubble content widgets.
class BubbleHelpers {
  static String getFileName(String url) {
    return url.split('/').last.split('?').first;
  }

  static String getFileExtension(String url) {
    final fileName = getFileName(url);
    if (fileName.contains('.')) {
      return fileName.split('.').last;
    }
    return 'file';
  }

  static IconData getFileIconFromName(String fileName) {
    final ext = getFileExtension(fileName).toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
      case 'csv':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.folder_zip;
      case 'txt':
        return Icons.text_snippet;
      case 'exe':
        return Icons.settings_applications;
      case 'mp4':
        return Icons.video_library;
      default:
        return Icons.insert_drive_file;
    }
  }

  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  static String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
