/// 首页"关注"tab 内容：关注作者的帖子瀑布流。
///
/// 纯展示组件：帖子列表、加载/分页状态、滚动控制器均由父组件传入，
/// 点击帖子/作者/点赞通过回调上抛。空列表时展示引导占位。
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../models/post_model.dart';
import '../../widgets/post_card.dart';
import 'home_loading_indicator.dart';

/// 关注流内容组件。
class FollowingFeed extends StatelessWidget {
  /// 关注流帖子列表。
  final List<Post> posts;

  /// 是否正在加载（首屏或加载更多）。
  final bool isLoading;

  /// 是否还有更多数据。
  final bool hasMore;

  /// 关注流滚动控制器（由父组件管理生命周期与监听）。
  final ScrollController scrollController;

  /// 点击帖子卡片回调。
  final void Function(Post post) onPostTap;

  /// 点击作者头像/名称回调。
  final void Function(String userId) onAuthorTap;

  /// 点赞回调，返回是否成功。
  final Future<bool> Function(Post post) onLikeTap;

  const FollowingFeed({
    Key? key,
    required this.posts,
    required this.isLoading,
    required this.hasMore,
    required this.scrollController,
    required this.onPostTap,
    required this.onAuthorTap,
    required this.onLikeTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading && posts.isEmpty) {
      return const HomeLoadingIndicator();
    }

    if (posts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            '还没有关注的人的动态，去发现页多关注一些优质作者吧～',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }

    return MasonryGridView.count(
      controller: scrollController,
      crossAxisCount: 2,
      crossAxisSpacing: 3,
      mainAxisSpacing: 3,
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      itemCount: posts.length + (isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == posts.length) {
          return _buildLoadMoreIndicator();
        }
        final post = posts[index];
        return PostCard(
          post: post,
          onTap: () => onPostTap(post),
          onAuthorTap: () => onAuthorTap(post.author.id),
          onLikeTap: onLikeTap,
        );
      },
    );
  }

  /// 底部加载更多指示器。
  Widget _buildLoadMoreIndicator() {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    } else if (!hasMore) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('没有更多内容了', style: TextStyle(color: Colors.grey)),
        ),
      );
    } else {
      return const SizedBox();
    }
  }
}
