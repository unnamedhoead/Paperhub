/// Notification sub-page: Likes and Favorites.
///
/// Displays notifications for:
/// - post likes
/// - post favorites
/// - comment likes

import 'package:flutter/material.dart';
import '../../models/notification_model.dart';
import '../../models/post_model.dart';
import '../../services/api_service.dart';
import '../profile_screen.dart';
import '../post_detail_screen.dart';

// =============================================================================
// LikesAndFavoritesScreen
// =============================================================================

class LikesAndFavoritesScreen extends StatefulWidget {
  const LikesAndFavoritesScreen({Key? key}) : super(key: key);

  @override
  State<LikesAndFavoritesScreen> createState() =>
      _LikesAndFavoritesScreenState();
}

class _LikesAndFavoritesScreenState extends State<LikesAndFavoritesScreen> {
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
      final resp = await ApiService.getLikesAndFavorites(
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
    if (diff.inDays > 0) {
      return '${diff.inDays}天前';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}小时前';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }

  IconData _getIcon(NotificationType type) {
    switch (type) {
      case NotificationType.postLike:
      case NotificationType.commentLike:
        return Icons.favorite;
      case NotificationType.postFavorite:
        return Icons.bookmark;
      default:
        return Icons.favorite;
    }
  }

  Color _getIconColor(NotificationType type) {
    switch (type) {
      case NotificationType.postLike:
      case NotificationType.commentLike:
        return Colors.red;
      case NotificationType.postFavorite:
        return Colors.blue;
      default:
        return Colors.red;
    }
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

  Widget _buildIconBadge(IconData icon, Color color) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0.2,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: scheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '赞和收藏',
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
                      return _buildNotificationItem(
                        notification: notification,
                        icon: _getIcon(notification.type),
                        iconColor: _getIconColor(notification.type),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildNotificationItem({
    required NotificationItem notification,
    required IconData icon,
    required Color iconColor,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final readBg = scheme.surfaceVariant;
    final unreadBg = scheme.primary.withOpacity(0.12);
    final textColor = scheme.onSurface;
    final secondary = scheme.onSurfaceVariant;
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
          color: notification.read ? readBg : unreadBg,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                if (!notification.read) {
                  ApiService.markNotificationAsRead(notification.id);
                }
                _openUserProfile(notification.actor.id);
              },
              child: CircleAvatar(
                radius: 20,
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
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.actor.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.content,
                    style: TextStyle(
                      color: secondary,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatTime(notification.createdAt),
                  style: TextStyle(
                    color: secondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                _buildIconBadge(icon, iconColor),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
