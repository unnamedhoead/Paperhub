/// Notification sub-page: Comments and @mentions.
///
/// Displays notifications for:
/// - comments on posts
/// - @mentions in comments

import 'package:flutter/material.dart';
import '../../models/notification_model.dart';
import '../../models/post_model.dart';
import '../../services/api_service.dart';
import '../profile_screen.dart';
import '../post_detail_screen.dart';

// =============================================================================
// CommentsAndMentionsScreen
// =============================================================================

class CommentsAndMentionsScreen extends StatefulWidget {
  const CommentsAndMentionsScreen({Key? key}) : super(key: key);

  @override
  State<CommentsAndMentionsScreen> createState() =>
      _CommentsAndMentionsScreenState();
}

class _CommentsAndMentionsScreenState
    extends State<CommentsAndMentionsScreen> {
  List<NotificationItem> _notifications = [];
  bool _isLoading = true;
  int _page = 0;
  final int _pageSize = 20;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications({bool loadMore = false}) async {
    if (!loadMore) {
      setState(() {
        _isLoading = true;
        _page = 0;
      });
    }

    try {
      final resp = await ApiService.getCommentsAndMentions(
        page: _page,
        pageSize: _pageSize,
      );
      if (resp['statusCode'] == 200) {
        final body = resp['body'] as Map<String, dynamic>;
        final notifications = (body['notifications'] as List)
            .map((json) => NotificationItem.fromJson(json))
            .toList();

        setState(() {
          if (loadMore) {
            _notifications.addAll(notifications);
          } else {
            _notifications = notifications;
          }
          _hasMore = notifications.length == _pageSize;
          _page++;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inDays > 0) return '${diff.inDays}天前';
    if (diff.inHours > 0) return '${diff.inHours}小时前';
    if (diff.inMinutes > 0) return '${diff.inMinutes}分钟前';
    return '刚刚';
  }

  Future<void> _navigateToPostDetail(String postId) async {
    try {
      final resp = await ApiService.getPost(postId);
      if (resp['statusCode'] == 200) {
        final body = resp['body'] as Map<String, dynamic>;
        final post = Post.fromJson(body);
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PostDetailScreen(post: post),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载帖子失败: $e')),
        );
      }
    }
  }

  void _openUserProfile(String userId) {
    if (userId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfilePage(userId: userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: scheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '评论和@',
          style: TextStyle(
            color: scheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading && _notifications.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? const Center(child: Text('暂无通知'))
              : RefreshIndicator(
                  onRefresh: () => _loadNotifications(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemCount: _notifications.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _notifications.length) {
                        _loadNotifications(loadMore: true);
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                      final notification = _notifications[index];
                      return _buildCommentItem(notification: notification);
                    },
                  ),
                ),
    );
  }

  Widget _buildCommentItem({required NotificationItem notification}) {
    final scheme = Theme.of(context).colorScheme;
    final isUnread = !notification.read;
    final cardColor =
        isUnread ? scheme.primary.withOpacity(0.12) : scheme.surfaceVariant;
    final secondary = scheme.onSurfaceVariant;
    final textColor = scheme.onSurface;
    final chipBg = scheme.surface.withOpacity(0.6);
    final isMention = notification.type == NotificationType.mention;
    final commentContent = notification.comment?.content ?? '';

    return GestureDetector(
      onTap: () async {
        if (!notification.read) {
          try {
            await ApiService.markNotificationAsRead(notification.id);
          } catch (e) {
            // ignore
          }
        }
        if (notification.post != null) {
          _navigateToPostDetail(notification.post!.id);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (!notification.read) {
                      ApiService.markNotificationAsRead(notification.id);
                    }
                    _openUserProfile(notification.actor.id);
                  },
                  child: CircleAvatar(
                    radius: 16,
                    backgroundImage: notification.actor.avatar != null
                        ? NetworkImage(notification.actor.avatar!)
                        : null,
                    child: notification.actor.avatar == null
                        ? Text(
                            notification.actor.name.isNotEmpty
                                ? notification.actor.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(color: scheme.onPrimaryContainer),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  notification.actor.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: textColor,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatTime(notification.createdAt),
                  style: TextStyle(
                    color: secondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              commentContent.isNotEmpty ? commentContent : notification.content,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: textColor,
              ),
            ),
            if (notification.post != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      isMention
                          ? Icons.alternate_email
                          : Icons.chat_bubble_outline,
                      color: secondary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        notification.post!.title,
                        style: TextStyle(
                          color: secondary,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
