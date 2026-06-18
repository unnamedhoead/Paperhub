/// 文件消息气泡内容组件
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/message_model.dart';
import 'message_bubble.dart';
import 'text_bubble.dart';
import '../html_stub.dart'
    if (dart.library.html) '../html_web.dart' as html;

class FileBubbleContent extends StatelessWidget {
  final Message message;

  const FileBubbleContent({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final fileUrl = message.fileUrl ??
        (message.mediaUrls.isNotEmpty ? message.mediaUrls.first : null);
    if (fileUrl == null) return TextBubbleContent(message: message);

    final fileName = message.fileName ?? BubbleHelpers.getFileName(fileUrl);
    final fileSize = message.fileSize;

    return GestureDetector(
      onTap: () => _openFile(fileUrl, fileName),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: message.isMe ? const Color(0xFF1976D2) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              BubbleHelpers.getFileIconFromName(fileName),
              color: message.isMe ? Colors.white : const Color(0xFF1976D2),
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: TextStyle(
                      color: message.isMe ? Colors.white : Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fileSize != null
                        ? BubbleHelpers.formatFileSize(fileSize)
                        : BubbleHelpers.getFileExtension(fileName)
                            .toUpperCase(),
                    style: TextStyle(
                      color: message.isMe ? Colors.white70 : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.download,
              color: message.isMe ? Colors.white70 : Colors.grey[400],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _openFile(String url, String fileName) {
    try {
      html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
    } catch (e) {
      final uri = Uri.parse(url);
      canLaunchUrl(uri).then((can) {
        if (can) {
          launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      });
    }
  }
}
