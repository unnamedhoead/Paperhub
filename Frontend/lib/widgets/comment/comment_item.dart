/// A single comment item widget, including reply list.
///
/// Extracted from PostDetailScreen's inline comment rendering.
/// Displays avatar, author name, content with @mentions,
/// reply-to indication, timestamp, reply/like/delete actions,
/// and nested replies.
import 'package:flutter/material.dart';
import '../../models/post_model.dart';

class CommentItem extends StatelessWidget {
  final Comment comment;
  final bool isReply;
  final String? currentUserId;
  final bool isLikeInFlight;
  final ValueChanged<Comment> onStartReply;
  final ValueChanged<Comment> onLikePressed;
  final void Function(Comment comment, {bool isTopLevel, Comment? parent}) onDelete;
  final ValueChanged<String> onOpenUserProfile;

  const CommentItem({
    Key? key,
    required this.comment,
    this.isReply = false,
    this.currentUserId,
    this.isLikeInFlight = false,
    required this.onStartReply,
    required this.onLikePressed,
    required this.onDelete,
    required this.onOpenUserProfile,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          onTap: () => onOpenUserProfile(comment.author.id),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: _buildAvatar(comment.author.avatar, isReply ? 14 : 16),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  comment.author.name,
                  style: TextStyle(
                    fontSize: isReply ? 13 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (currentUserId != null && comment.author.id == currentUserId)
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      size: isReply ? 16 : 18),
                  color: Colors.red[300],
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => onDelete(comment, isTopLevel: !isReply, parent: null),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (comment.replyTo != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text(
                    '回复 @${comment.replyTo!.name}',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.primary,
                    ),
                  ),
                ),
              _buildContentWithMentions(context, comment.content, comment.mentions),
              Row(
                children: [
                  Text(
                    _formatRelative(comment.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  TextButton(
                    onPressed: () => onStartReply(comment),
                    child: const Text('回复', style: TextStyle(fontSize: 12)),
                  ),
                  const Spacer(),
                  Text(
                    '${comment.likesCount}',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  IconButton(
                    icon: Icon(
                      comment.isLiked
                          ? Icons.thumb_up
                          : Icons.thumb_up_off_alt,
                      size: isReply ? 16 : 18,
                      color: comment.isLiked
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                    onPressed:
                        isLikeInFlight ? null : () => onLikePressed(comment),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Nested replies
        if (comment.hasReplies && !isReply)
          Padding(
            padding: const EdgeInsets.only(left: 56.0),
            child: Column(
              children: comment.replies.map((reply) {
                return CommentItem(
                  key: ValueKey('reply-${reply.id}'),
                  comment: reply,
                  isReply: true,
                  currentUserId: currentUserId,
                  onStartReply: onStartReply,
                  onLikePressed: onLikePressed,
                  onDelete: (comment, {bool isTopLevel = false, Comment? parent}) =>
                      onDelete(comment, isTopLevel: false, parent: this.comment),
                  onOpenUserProfile: onOpenUserProfile,
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildAvatar(String avatarPath, double radius) {
    if (avatarPath.startsWith('http://') || avatarPath.startsWith('https://')) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey[300],
        child: ClipOval(
          child: Image.network(
            avatarPath,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Icon(Icons.person, size: radius, color: Colors.grey);
            },
          ),
        ),
      );
    }
    String assetPath = avatarPath;
    if (assetPath.startsWith('assets/images/')) {
      assetPath = assetPath.substring(14);
    } else if (assetPath.startsWith('assets/')) {
      assetPath = assetPath.substring(7);
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[300],
      child: ClipOval(
        child: Image.asset(
          assetPath,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Icon(Icons.person, size: radius, color: Colors.grey);
          },
        ),
      ),
    );
  }

  /// Renders comment content with clickable @mentions.
  Widget _buildContentWithMentions(
    BuildContext context,
    String content,
    List<Author> mentions,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final List<TextSpan> spans = [];
    final RegExp mentionRegex = RegExp(r'@([^\s@]+)');
    int lastIndex = 0;

    final Map<String, String> mentionMap = {};
    for (final mention in mentions) {
      final lowerName = mention.name.toLowerCase();
      mentionMap[lowerName] = mention.id;
      if (lowerName.contains('@')) {
        final prefix = lowerName.substring(0, lowerName.indexOf('@'));
        mentionMap[prefix] = mention.id;
      }
      if (mention.name.contains('@')) {
        final emailPrefix = mention.name
            .substring(0, mention.name.indexOf('@'))
            .toLowerCase();
        mentionMap[emailPrefix] = mention.id;
      }
    }

    for (final match in mentionRegex.allMatches(content)) {
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: content.substring(lastIndex, match.start),
            style: TextStyle(fontSize: 13, color: scheme.onSurface),
          ),
        );
      }

      final mentionText = match.group(0)!;
      final userName = match.group(1)!;
      final userId = mentionMap[userName.toLowerCase()];

      if (userId != null) {
        spans.add(
          TextSpan(
            text: mentionText,
            style: TextStyle(
              fontSize: 13,
              color: scheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: mentionText,
            style: TextStyle(fontSize: 13, color: scheme.onSurface),
          ),
        );
      }

      lastIndex = match.end;
    }

    if (lastIndex < content.length) {
      spans.add(
        TextSpan(
          text: content.substring(lastIndex),
          style: TextStyle(fontSize: 13, color: scheme.onSurface),
        ),
      );
    }

    if (spans.isEmpty) {
      return Text(content, style: TextStyle(fontSize: 13, color: scheme.onSurface));
    }
    return RichText(text: TextSpan(children: spans));
  }

  String _formatRelative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 4) return '刚刚';
    if (diff.inMinutes >= 4 && diff.inMinutes < 60) {
      return '${diff.inMinutes} 分钟前';
    }
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    return '${diff.inDays} 天前';
  }
}
