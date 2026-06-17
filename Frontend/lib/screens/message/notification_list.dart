/// Notification sub-pages extracted from message_screen.dart.
///
/// Contains three notification list screens:
/// - LikesAndFavoritesScreen: post likes, favorites, comment likes
/// - NewFollowersScreen: new follower notifications with follow-back
/// - CommentsAndMentionsScreen: comment and @mention notifications

import 'package:flutter/material.dart';
import '../../models/notification_model.dart';
import '../../models/post_model.dart';
import '../../services/api_service.dart';
import '../../services/local_storage.dart';
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

// =============================================================================
// NewFollowersScreen
// =============================================================================

class NewFollowersScreen extends StatefulWidget {
  const NewFollowersScreen({Key? key}) : super(key: key);

  @override
  State<NewFollowersScreen> createState() => _NewFollowersScreenState();
}

class _NewFollowersScreenState extends State<NewFollowersScreen> {
  List<NotificationItem> _notifications = [];
  bool _isLoading = true;
  int _page = 0;
  final int _pageSize = 20;
  bool _hasMore = true;
  final Set<String> _followedUserIds = {};
  final Set<String> _followLoadingUserIds = {};
  final Map<String, bool> _followStatusCache = {};
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = LocalStorage.instance.read('userId');
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
      final resp = await ApiService.getFollows(page: _page, pageSize: _pageSize);
      if (resp['statusCode'] == 200) {
        final body = resp['body'] as Map<String, dynamic>;
        final notifications = (body['notifications'] as List)
            .map((json) => NotificationItem.fromJson(json))
            .toList();
        final resolvedFollowBackIds = await _determineFollowBackIds(notifications);

        setState(() {
          if (loadMore) {
            _notifications.addAll(notifications);
            _followedUserIds.addAll(resolvedFollowBackIds);
          } else {
            _notifications = notifications;
            _followedUserIds
              ..clear()
              ..addAll(resolvedFollowBackIds);
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

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _openUserProfile(String userId) async {
    if (userId.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfilePage(userId: userId),
      ),
    );
    await _updateSingleUserFollowStatus(userId);
  }

  Future<void> _updateSingleUserFollowStatus(String userId) async {
    if (userId.isEmpty) return;

    final currentUserId =
        _currentUserId ??= LocalStorage.instance.read('userId');
    if (currentUserId == null || currentUserId.isEmpty) return;

    _followStatusCache.remove(userId);

    final isFollowed = await _isActorInMyFollowing(
      currentUserId: currentUserId,
      targetUserId: userId,
    );

    if (mounted) {
      setState(() {
        _followStatusCache[userId] = isFollowed;
        if (isFollowed) {
          _followedUserIds.add(userId);
        } else {
          _followedUserIds.remove(userId);
        }
      });
    }
  }

  Future<void> _handleFollowBack(NotificationItem notification) async {
    final userId = notification.actor.id;
    if (userId.isEmpty || _followedUserIds.contains(userId)) return;
    setState(() {
      _followLoadingUserIds.add(userId);
    });

    try {
      final resp = await ApiService.followUser(userId);
      if (resp['statusCode'] != 200) {
        final message =
            (resp['body'] as Map<String, dynamic>?)?['message'] ?? '回关失败';
        throw Exception(message);
      }
      setState(() {
        _followedUserIds.add(userId);
        _followStatusCache[userId] = true;
      });
      _showSnack('已回关 ${notification.actor.name}');
    } catch (e) {
      _showSnack('回关失败：$e');
    } finally {
      if (mounted) {
        setState(() {
          _followLoadingUserIds.remove(userId);
        });
      }
    }
  }

  Future<Set<String>> _determineFollowBackIds(
    List<NotificationItem> notifications,
  ) async {
    final currentUserId =
        _currentUserId ??= LocalStorage.instance.read('userId');
    if (currentUserId == null || currentUserId.isEmpty) return {};

    final actorIds = notifications
        .map((n) => n.actor.id)
        .where((id) => id.isNotEmpty)
        .toSet();
    if (actorIds.isEmpty) return {};

    final futures = actorIds.map((actorId) async {
      final cached = _followStatusCache[actorId];
      if (cached != null) return MapEntry(actorId, cached);
      final isFollowed = await _isActorInMyFollowing(
        currentUserId: currentUserId,
        targetUserId: actorId,
      );
      _followStatusCache[actorId] = isFollowed;
      return MapEntry(actorId, isFollowed);
    });

    final results = await Future.wait(futures);
    final followedIds = <String>{};
    for (final entry in results) {
      if (entry.value) followedIds.add(entry.key);
    }
    return followedIds;
  }

  Future<bool> _isActorInMyFollowing({
    required String currentUserId,
    required String targetUserId,
  }) async {
    int page = 0;
    const int pageSize = 50;

    while (true) {
      try {
        final resp = await ApiService.getFollowing(
          currentUserId,
          page: page,
          pageSize: pageSize,
        );
        if (resp['statusCode'] != 200) return false;
        final body = resp['body'] as Map<String, dynamic>? ?? {};
        final users = (body['users'] as List?) ?? const [];
        final found = users.any((userJson) {
          final id = (userJson['id'] ?? userJson['userId'])?.toString() ?? '';
          return id == targetUserId;
        });
        if (found) return true;
        if (users.length < pageSize) return false;
        page++;
      } catch (_) {
        return false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onSurface = scheme.onSurface;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '新增关注',
          style: TextStyle(
            color: onSurface,
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
                      final actorId = notification.actor.id;
                      final isAlreadyFollowed =
                          _followedUserIds.contains(actorId) ||
                              (notification.actor.isFollowed ?? false);
                      return _buildFollowerItem(
                        notification: notification,
                        isFollowed: isAlreadyFollowed,
                        isLoading: _followLoadingUserIds.contains(actorId),
                        onFollow: () => _handleFollowBack(notification),
                        onAvatarTap: () {
                          if (!notification.read) {
                            ApiService.markNotificationAsRead(notification.id);
                          }
                          _openUserProfile(actorId);
                        },
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildFollowerItem({
    required NotificationItem notification,
    required bool isFollowed,
    required bool isLoading,
    required VoidCallback onFollow,
    required VoidCallback onAvatarTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final cardColor = Theme.of(context).cardColor;
    final unreadBg = scheme.primary.withOpacity(0.08);
    return GestureDetector(
      onTap: () async {
        if (!notification.read) {
          try {
            await ApiService.markNotificationAsRead(notification.id);
          } catch (e) {
            // ignore
          }
        }
        _openUserProfile(notification.actor.id);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: notification.read ? cardColor : unreadBg,
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
              onTap: onAvatarTap,
              child: CircleAvatar(
                radius: 24,
                backgroundImage: notification.actor.avatar != null
                    ? NetworkImage(notification.actor.avatar!)
                    : null,
                child: notification.actor.avatar == null
                    ? Text(
                        notification.actor.name.isNotEmpty
                            ? notification.actor.name[0].toUpperCase()
                            : '?',
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
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.content,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              children: [
                Text(
                  _formatTime(notification.createdAt),
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: isFollowed || isLoading ? null : onFollow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isFollowed ? Colors.grey[200] : const Color(0xFF1976D2),
                    foregroundColor:
                        isFollowed ? Colors.grey[700] : Colors.white,
                    disabledBackgroundColor: isFollowed
                        ? Colors.grey[200]
                        : const Color(0xFF1976D2),
                    disabledForegroundColor:
                        isFollowed ? Colors.grey[600] : Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 0,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          isFollowed ? '已回关' : '回关',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

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
