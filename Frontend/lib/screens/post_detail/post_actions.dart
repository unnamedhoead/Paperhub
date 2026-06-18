import 'package:flutter/material.dart';
import '../../models/post_model.dart';

/// 帖子详情页底部操作栏：点赞、评论、收藏、分享
class PostActionsBar extends StatelessWidget {
  final Post post;
  final bool isLiked;
  final int likeCount;
  final bool isSaved;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onSave;
  final VoidCallback onShare;

  const PostActionsBar({
    super.key,
    required this.post,
    required this.isLiked,
    required this.likeCount,
    required this.isSaved,
    required this.onLike,
    required this.onComment,
    required this.onSave,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: scheme.outline.withOpacity(0.15)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              isLiked ? Icons.favorite : Icons.favorite_border,
              color: isLiked ? Colors.redAccent : scheme.onSurface,
            ),
            onPressed: onLike,
          ),
          Text('$likeCount', style: TextStyle(color: scheme.onSurface)),
          const SizedBox(width: 12),
          IconButton(
            icon: Icon(Icons.mode_comment_outlined, color: scheme.onSurface),
            onPressed: onComment,
          ),
          const SizedBox(width: 8),
          Text(
            '${post.commentsCount}',
            style: TextStyle(color: scheme.onSurface),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: Icon(
              isSaved ? Icons.bookmark : Icons.bookmark_border,
              color: isSaved ? scheme.primary : scheme.onSurface,
            ),
            onPressed: onSave,
          ),
          const SizedBox(width: 8),
          Text(
            '${post.favoriteCount}',
            style: TextStyle(color: scheme.onSurface),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.share_outlined, color: scheme.onSurface),
            onPressed: onShare,
          ),
        ],
      ),
    );
  }
}
