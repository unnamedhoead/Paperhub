// lib/screens/follow/follow_user_list_item.dart
/// 关注/粉丝列表中的单个用户项
import 'package:flutter/material.dart';
import '../../models/user_summary.dart';
import '../../services/local_storage.dart';
import '../profile_screen.dart';
import 'follow_action_button.dart';

/// 用户列表项
class FollowUserListItem extends StatelessWidget {
  final UserSummary user;
  final String type;
  final ValueChanged<UserSummary>? onRelationshipChanged;
  final ValueChanged<UserSummary>? onFollowChanged;

  /// 当前列表项所在的Tab刷新回调
  final VoidCallback? onStateChanged;

  /// 从个人主页返回时通知上层（FollowListScreen）统一刷新所有Tab
  final VoidCallback? onProfileReturned;

  const FollowUserListItem({
    Key? key,
    required this.user,
    required this.type,
    this.onRelationshipChanged,
    this.onFollowChanged,
    this.onStateChanged,
    this.onProfileReturned,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUserId = LocalStorage.instance.read('userId')?.toString();
    final isMe = currentUserId != null && currentUserId == user.id;
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfilePage(userId: user.id),
          ),
        ).then((_) {
          // 返回后刷新当前Tab
          onStateChanged?.call();
          // 同时通知上层刷新其他Tab，避免关注/互关列表不同步
          onProfileReturned?.call();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // 头像
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: _getAvatarImage(user.avatar),
                ),
                if (type == 'mutual')
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle,
                        color: scheme.primary,
                        size: 16,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // 用户信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  if (user.bio != null && user.bio!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      user.bio!,
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            // 如果这一项就是当前登录用户自己，则不显示关注按钮
            if (!isMe)
              FollowActionButton(
                key: ValueKey('follow-btn-${type}-${user.id}'),
                user: user,
                listType: type,
                onStateChanged: onStateChanged,
                onFollowChanged: onFollowChanged,
              ),
          ],
        ),
      ),
    );
  }

  ImageProvider _getAvatarImage(String avatar) {
    if (avatar.startsWith('http')) {
      return NetworkImage(avatar);
    }
    return const AssetImage('images/DefaultAvatar.png');
  }
}
