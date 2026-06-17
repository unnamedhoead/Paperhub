import 'package:flutter/material.dart';

import '../../models/post_model.dart';
import '../../models/user_profile.dart';
import 'profile_header.dart';
import 'profile_research_directions.dart';
import 'profile_tabs.dart';

/// Scrollable body of the profile page: handles the loading / error / empty /
/// loaded states and composes the header, research directions and tabs.
///
/// All side effects stay with the host screen and arrive through callbacks; this
/// widget is purely presentational.
class ProfileContent extends StatelessWidget {
  final bool loading;
  final String? error;
  final bool saving;
  final UserProfile? profile;
  final bool isViewingSelf;
  final bool canViewFavorites;
  final bool? isFollowing;
  final String? currentUserId;

  final List<Post> authoredPosts;
  final bool loadingAuthored;
  final bool hasMoreAuthored;
  final List<Post> favoritePosts;
  final bool loadingFavorites;
  final bool hasMoreFavorites;
  final List<Post> draftPosts;
  final bool loadingDrafts;
  final bool hasMoreDrafts;

  final VoidCallback onRetry;
  final VoidCallback onEditProfile;
  final VoidCallback onToggleFollow;
  final VoidCallback onStartChat;
  final void Function(String? avatar) onShowAvatarViewer;
  final VoidCallback onShowBackgroundViewer;
  final void Function(bool showFollowers) onOpenFollowList;

  final Future<void> Function({bool refresh}) loadUserPosts;
  final Future<void> Function({bool refresh}) loadFavoritePosts;
  final Future<void> Function({bool refresh}) loadDraftPosts;
  final void Function(Post post) onPostTap;
  final void Function(String authorId) onAuthorTap;
  final Future<bool> Function(Post post) onLikeTap;

  const ProfileContent({
    super.key,
    required this.loading,
    required this.error,
    required this.saving,
    required this.profile,
    required this.isViewingSelf,
    required this.canViewFavorites,
    required this.isFollowing,
    required this.currentUserId,
    required this.authoredPosts,
    required this.loadingAuthored,
    required this.hasMoreAuthored,
    required this.favoritePosts,
    required this.loadingFavorites,
    required this.hasMoreFavorites,
    required this.draftPosts,
    required this.loadingDrafts,
    required this.hasMoreDrafts,
    required this.onRetry,
    required this.onEditProfile,
    required this.onToggleFollow,
    required this.onStartChat,
    required this.onShowAvatarViewer,
    required this.onShowBackgroundViewer,
    required this.onOpenFollowList,
    required this.loadUserPosts,
    required this.loadFavoritePosts,
    required this.loadDraftPosts,
    required this.onPostTap,
    required this.onAuthorTap,
    required this.onLikeTap,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.6, child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48), const SizedBox(height: 12),
          Text(error!), const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, child: const Text('重试')),
        ]))),
      ]);
    }
    final profile = this.profile;
    if (profile == null) {
      return ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [
        SizedBox(height: 200, child: Center(child: Text('暂无资料'))),
      ]);
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(children: [
        if (saving) const LinearProgressIndicator(minHeight: 2),
        ProfileHeader(
          profile: profile,
          isViewingSelf: isViewingSelf,
          isFollowing: isFollowing,
          saving: saving,
          onEditProfile: onEditProfile,
          onToggleFollow: onToggleFollow,
          onStartChat: onStartChat,
          onAvatarTap: () => onShowAvatarViewer(profile.avatar),
          onBackgroundTap: () => isViewingSelf ? onShowBackgroundViewer() : null,
          onOpenFollowList: onOpenFollowList,
          onShowAvatarViewer: onShowAvatarViewer,
        ),
        ProfileResearchDirections(profile: profile),
        ProfileTabs(
          isViewingSelf: isViewingSelf,
          canViewFavorites: canViewFavorites,
          authoredPosts: authoredPosts,
          loadingAuthored: loadingAuthored,
          hasMoreAuthored: hasMoreAuthored,
          favoritePosts: favoritePosts,
          loadingFavorites: loadingFavorites,
          hasMoreFavorites: hasMoreFavorites,
          draftPosts: draftPosts,
          loadingDrafts: loadingDrafts,
          hasMoreDrafts: hasMoreDrafts,
          loadUserPosts: loadUserPosts,
          loadFavoritePosts: loadFavoritePosts,
          loadDraftPosts: loadDraftPosts,
          onPostTap: onPostTap,
          onAuthorTap: onAuthorTap,
          onLikeTap: onLikeTap,
        ),
      ]),
    );
  }
}
