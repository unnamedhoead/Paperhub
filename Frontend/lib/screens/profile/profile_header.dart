import 'package:flutter/material.dart';

import '../../models/user_profile.dart';

/// Displays avatar, background, display name, bio, stats, and action buttons.
class ProfileHeader extends StatelessWidget {
  final UserProfile profile;
  final bool isViewingSelf;
  final bool? isFollowing;
  final bool saving;
  final VoidCallback onEditProfile;
  final VoidCallback onToggleFollow;
  final VoidCallback onStartChat;
  final VoidCallback onAvatarTap;
  final VoidCallback onBackgroundTap;
  final void Function(bool showFollowers) onOpenFollowList;
  final void Function(String? avatarUrl) onShowAvatarViewer;

  const ProfileHeader({
    super.key,
    required this.profile,
    required this.isViewingSelf,
    required this.isFollowing,
    required this.saving,
    required this.onEditProfile,
    required this.onToggleFollow,
    required this.onStartChat,
    required this.onAvatarTap,
    required this.onBackgroundTap,
    required this.onOpenFollowList,
    required this.onShowAvatarViewer,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isViewingSelf ? onBackgroundTap : null,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          image: DecorationImage(
            image: resolveBackground(profile.backgroundImage),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.45),
              BlendMode.darken,
            ),
          ),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        child: Padding(
          padding:
              const EdgeInsets.only(top: 32, bottom: 24, left: 20, right: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(context),
              _buildUserRow(context),
              const SizedBox(height: 24),
              _buildStatsRow(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (isViewingSelf)
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          )
        else if (Navigator.canPop(context))
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          )
        else
          const SizedBox(width: 48),
        if (isViewingSelf && Navigator.canPop(context))
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          )
        else if (!isViewingSelf)
          IconButton(
            icon: const Icon(Icons.flag_outlined, color: Colors.white),
            onPressed: () {},
          ),
      ],
    );
  }

  Widget _buildUserRow(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onAvatarTap,
          child: Stack(
            children: [
              CircleAvatar(
                radius: 48,
                backgroundImage: resolveAvatar(profile.avatar),
              ),
              if (isViewingSelf)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: onAvatarTap,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.black87,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(profile.displayName,
                  style: const TextStyle(
                      fontSize: 22,
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
              if (profile.bio != null) ...[
                const SizedBox(height: 4),
                Text(profile.bio!,
                    style: const TextStyle(color: Colors.white70)),
              ],
              const SizedBox(height: 8),
              Text(profile.email,
                  style:
                      const TextStyle(color: Colors.white54, fontSize: 12)),
              if (profile.statusMessage != null &&
                  profile.statusMessage!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(profile.statusMessage!,
                    style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ),
        if (isViewingSelf)
          IconButton(
            onPressed: onEditProfile,
            icon: const Icon(Icons.edit, color: Colors.white),
          )
        else
          Row(
            children: [
              ElevatedButton(
                onPressed: onToggleFollow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: (isFollowing ?? false)
                      ? Colors.white.withOpacity(0.2)
                      : Colors.blueAccent,
                  foregroundColor: Colors.white,
                ),
                child: Text((isFollowing ?? false) ? '已关注' : '关注'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: onStartChat,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('私聊'),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildStatsRow(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
              title: '关注',
              count: profile.followingCount,
              onTap: () => onOpenFollowList(false)),
          _StatItem(
              title: '粉丝',
              count: profile.followersCount,
              onTap: () => onOpenFollowList(true)),
          _StatItem(title: '被收藏', count: profile.favoritesReceivedCount),
          _StatItem(title: '点赞', count: profile.likesCount),
        ],
      ),
    );
  }

  static ImageProvider<Object> resolveAvatar(String? avatar) {
    if (avatar == null || avatar.isEmpty) {
      return const AssetImage('images/DefaultAvatar.png');
    }
    if (avatar.startsWith('http')) return NetworkImage(avatar);
    if (avatar.startsWith('assets/')) return AssetImage(avatar);
    return AssetImage(avatar);
  }

  static ImageProvider<Object> resolveBackground(String? bg) {
    if (bg == null || bg.isEmpty) {
      return const AssetImage('images/profile_bg.jpg');
    }
    if (bg.startsWith('http')) return NetworkImage(bg);
    if (bg.startsWith('assets/')) return AssetImage(bg);
    return AssetImage(bg);
  }
}

class _StatItem extends StatelessWidget {
  final String title;
  final int count;
  final VoidCallback? onTap;

  const _StatItem({required this.title, required this.count, this.onTap});

  @override
  Widget build(BuildContext context) {
    final displayCount = count == -1 ? '-' : '$count';
    final content = Column(
      children: [
        Text(displayCount,
            style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 5),
        Text(title, style: const TextStyle(color: Colors.grey)),
      ],
    );
    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}
