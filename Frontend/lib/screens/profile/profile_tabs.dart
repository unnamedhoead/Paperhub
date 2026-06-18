import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../models/post_model.dart';
import '../../widgets/post_card.dart';

/// Tab bar + tab views for authored posts, favorites, and drafts.
class ProfileTabs extends StatelessWidget {
  final bool isViewingSelf;
  final bool canViewFavorites;

  final List<Post> authoredPosts;
  final bool loadingAuthored;
  final bool hasMoreAuthored;

  final List<Post> favoritePosts;
  final bool loadingFavorites;
  final bool hasMoreFavorites;

  final List<Post> draftPosts;
  final bool loadingDrafts;
  final bool hasMoreDrafts;

  final Future<void> Function({bool refresh}) loadUserPosts;
  final Future<void> Function({bool refresh}) loadFavoritePosts;
  final Future<void> Function({bool refresh}) loadDraftPosts;

  final void Function(Post post) onPostTap;
  final void Function(String authorId) onAuthorTap;
  final Future<bool> Function(Post post) onLikeTap;

  const ProfileTabs({
    super.key,
    required this.isViewingSelf,
    required this.canViewFavorites,
    required this.authoredPosts,
    required this.loadingAuthored,
    required this.hasMoreAuthored,
    required this.favoritePosts,
    required this.loadingFavorites,
    required this.hasMoreFavorites,
    required this.draftPosts,
    required this.loadingDrafts,
    required this.hasMoreDrafts,
    required this.loadUserPosts,
    required this.loadFavoritePosts,
    required this.loadDraftPosts,
    required this.onPostTap,
    required this.onAuthorTap,
    required this.onLikeTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cardColor = scheme.surfaceVariant;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          TabBar(
            labelColor: scheme.primary,
            unselectedLabelColor: scheme.onSurface.withOpacity(0.7),
            indicatorColor: scheme.primary,
            tabs: [
              const Tab(text: '笔记'),
              const Tab(text: '收藏'),
              if (isViewingSelf) const Tab(text: '草稿'),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 600,
            child: TabBarView(
              children: [
                _buildPostGrid(
                  posts: authoredPosts,
                  isLoading: loadingAuthored,
                  hasMore: hasMoreAuthored,
                  loader: loadUserPosts,
                  onPostTap: onPostTap,
                  onAuthorTap: onAuthorTap,
                  onLikeTap: onLikeTap,
                ),
                canViewFavorites
                    ? _buildPostGrid(
                        posts: favoritePosts,
                        isLoading: loadingFavorites,
                        hasMore: hasMoreFavorites,
                        loader: loadFavoritePosts,
                        onPostTap: onPostTap,
                        onAuthorTap: onAuthorTap,
                        onLikeTap: onLikeTap,
                      )
                    : Center(
                        child: Text(
                          isViewingSelf
                              ? '你目前未公开收藏给其他用户'
                              : '对方已隐藏收藏',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 16),
                        ),
                      ),
                if (isViewingSelf)
                  _buildPostGrid(
                    posts: draftPosts,
                    isLoading: loadingDrafts,
                    hasMore: hasMoreDrafts,
                    loader: loadDraftPosts,
                    onPostTap: onPostTap,
                    onAuthorTap: onAuthorTap,
                    onLikeTap: onLikeTap,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostGrid({
    required List<Post> posts,
    required bool isLoading,
    required bool hasMore,
    required Future<void> Function({bool refresh}) loader,
    required void Function(Post) onPostTap,
    required void Function(String) onAuthorTap,
    required Future<bool> Function(Post) onLikeTap,
  }) {
    if (posts.isEmpty && !isLoading) {
      return RefreshIndicator(
        onRefresh: () => loader(refresh: true),
        child: ListView(
          children: const [
            SizedBox(height: 180),
            Center(child: Text('暂无数据')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => loader(refresh: true),
      child: MasonryGridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 3,
        mainAxisSpacing: 3,
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        itemCount: posts.length + (hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == posts.length) {
            if (isLoading) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child:
                    Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Center(
                child: TextButton.icon(
                  onPressed: () => loader(refresh: false),
                  icon: const Icon(Icons.refresh),
                  label: const Text('加载更多'),
                ),
              ),
            );
          }
          final post = posts[index];
          return PostCard(
            post: post,
            onTap: () => onPostTap(post),
            onAuthorTap: () => onAuthorTap(post.author.id),
            onLikeTap: (_) => onLikeTap(post),
          );
        },
      ),
    );
  }
}
