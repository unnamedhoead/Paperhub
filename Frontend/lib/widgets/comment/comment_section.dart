/// Comment section widget — header, comment list, load more.
///
/// Extracted from PostDetailScreen's _buildCommentsSection method.
/// Displays the comments header with count and refresh, a list of
/// CommentItem widgets, and a "load more" button for pagination.
import 'package:flutter/material.dart';
import '../../models/post_model.dart';
import 'comment_item.dart';

class CommentSection extends StatelessWidget {
  final List<Comment> comments;
  final int commentsCount;
  final bool isLoading;
  final bool hasMore;
  final String? currentUserId;
  final Set<String> likeInFlight;
  final VoidCallback onRefresh;
  final VoidCallback onLoadMore;
  final ValueChanged<Comment> onStartReply;
  final ValueChanged<Comment> onLikePressed;
  final void Function(Comment comment, {bool isTopLevel, Comment? parent}) onDelete;
  final ValueChanged<String> onOpenUserProfile;

  const CommentSection({
    Key? key,
    required this.comments,
    required this.commentsCount,
    this.isLoading = false,
    this.hasMore = false,
    this.currentUserId,
    this.likeInFlight = const <String>{},
    required this.onRefresh,
    required this.onLoadMore,
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
        Divider(height: 1, color: scheme.outline.withOpacity(0.15)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Text(
                '评论 ($commentsCount)',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              const Spacer(),
              if (isLoading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: scheme.primary,
                  ),
                ),
              IconButton(
                icon: Icon(
                  Icons.refresh,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
                onPressed: isLoading ? null : onRefresh,
                tooltip: '刷新评论',
              ),
            ],
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: comments.length + (hasMore ? 1 : 0),
          separatorBuilder: (_, __) =>
              Divider(indent: 16, color: scheme.outline.withOpacity(0.15)),
          itemBuilder: (context, idx) {
            if (idx == comments.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: isLoading
                      ? CircularProgressIndicator(color: scheme.primary)
                      : TextButton.icon(
                          onPressed: onLoadMore,
                          icon: Icon(
                            Icons.refresh,
                            color: scheme.onSurfaceVariant,
                          ),
                          label: Text(
                            '加载更多评论',
                            style: TextStyle(color: scheme.primary),
                          ),
                        ),
                ),
              );
            }
            final c = comments[idx];
            final inFlight = likeInFlight.contains(c.id);
            return CommentItem(
              key: ValueKey('comment-${c.id}'),
              comment: c,
              currentUserId: currentUserId,
              isLikeInFlight: inFlight,
              onStartReply: onStartReply,
              onLikePressed: onLikePressed,
              onDelete: (comment, {bool isTopLevel = true, Comment? parent}) =>
                  onDelete(comment, isTopLevel: isTopLevel, parent: parent),
              onOpenUserProfile: onOpenUserProfile,
            );
          },
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}
