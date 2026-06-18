/// 首页"分区"tab 内容：顶部分区滑条 + 当前分区的帖子瀑布流。
///
/// 纯展示组件：当前分区、帖子列表、加载状态由父组件传入，
/// 切换分区/点击帖子/作者/点赞通过回调上抛。
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../models/post_model.dart';
import '../../widgets/post_card.dart';
import '../../constants/discipline_constants.dart';
import 'home_loading_indicator.dart';

/// 分区 tab 内容组件。
class ZoneTab extends StatelessWidget {
  /// 当前选中的主分区。
  final String currentDiscipline;

  /// 当前分区的帖子列表。
  final List<Post> posts;

  /// 是否正在加载。
  final bool isLoading;

  /// 切换分区回调（传入新选中的分区名）。
  final void Function(String discipline) onDisciplineSelected;

  /// 点击帖子卡片回调。
  final void Function(Post post) onPostTap;

  /// 点击作者头像/名称回调。
  final void Function(String userId) onAuthorTap;

  /// 点赞回调，返回是否成功。
  final Future<bool> Function(Post post) onLikeTap;

  const ZoneTab({
    Key? key,
    required this.currentDiscipline,
    required this.posts,
    required this.isLoading,
    required this.onDisciplineSelected,
    required this.onPostTap,
    required this.onAuthorTap,
    required this.onLikeTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildZoneSelectorBar(context),
        const Divider(height: 1),
        Expanded(
          child: _buildZoneWaterfallGrid(),
        ),
      ],
    );
  }

  /// 顶部分区滑条。
  Widget _buildZoneSelectorBar(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemBuilder: (context, index) {
          final discipline = kMainDisciplines[index];
          final selected = discipline == currentDiscipline;
          final color = kDisciplineColors[discipline] ?? Colors.blue;
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final textColor = isDark ? Colors.white : Colors.black87;
          return GestureDetector(
            onTap: () {
              if (currentDiscipline == discipline) return;
              onDisciplineSelected(discipline);
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? color.withOpacity(isDark ? 0.3 : 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected
                      ? color
                      : (isDark ? Colors.white24 : Colors.grey.shade300),
                ),
              ),
              child: Center(
                child: Text(
                  discipline,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.normal,
                    color: textColor,
                  ),
                ),
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: kMainDisciplines.length,
      ),
    );
  }

  /// 分区内瀑布流（使用后端标签过滤）。
  Widget _buildZoneWaterfallGrid() {
    if (posts.isEmpty && isLoading) {
      return const HomeLoadingIndicator();
    }

    if (posts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            '当前分区暂时没有内容，试试切换到其他分区或先在该分区发布一条笔记吧～',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }

    return MasonryGridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 3,
      mainAxisSpacing: 3,
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      itemCount: posts.length,
      itemBuilder: (context, index) {
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
}
