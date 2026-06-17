import 'package:flutter/material.dart';

import '../../models/search_model.dart';
import 'search_placeholders.dart';

/// Hot-search ranking sliver: a title row with a refresh action, plus loading /
/// error / empty / list states for the live hot-search data.
///
/// Extracted from `search_screen.dart` unchanged. Returns a [SliverToBoxAdapter]
/// for direct use in the page's [CustomScrollView]. Data loading and navigation
/// are owned by the host and delivered through [onRefresh] / [onItemTap].
class HotSearchSection extends StatelessWidget {
  /// Ranked hot-search entries to render.
  final List<HotSearchItem> hotSearches;

  /// Whether hot-search data is currently loading.
  final bool isLoading;

  /// Error message to show instead of the list; null when there is no error.
  final String? error;

  /// Reloads the hot-search data (refresh button and error retry).
  final VoidCallback onRefresh;

  /// Invoked when a hot-search entry is tapped.
  final ValueChanged<HotSearchItem> onItemTap;

  const HotSearchSection({
    super.key,
    required this.hotSearches,
    required this.isLoading,
    required this.error,
    required this.onRefresh,
    required this.onItemTap,
  });

  /// Single hot-search row: rank (top 3 in red), title, optional 新/热 badge,
  /// and the formatted heat value on the trailing edge.
  Widget _buildItem(BuildContext context, HotSearchItem item) {
    final scheme = Theme.of(context).colorScheme;
    Color rankColor = scheme.onSurfaceVariant;
    if (item.rank <= 3) {
      rankColor = const Color(0xFFFF2D55); // 前3名用红色
    }

    return ListTile(
      leading: Container(
        width: 24,
        alignment: Alignment.center,
        child: Text(
          item.rank.toString(),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: rankColor,
          ),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              item.title,
              style: TextStyle(
                fontSize: 14,
                color: scheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (item.tag != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: item.tag == '热' ? Colors.red[50] : Colors.orange[50],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: item.tag == '热' ? Colors.red : Colors.orange,
                  width: 0.5,
                ),
              ),
              child: Text(
                item.tag!,
                style: TextStyle(
                  fontSize: 10,
                  color: item.tag == '热' ? Colors.red : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      trailing: Text(
        item.formattedHeat,
        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
      ),
      onTap: () => onItemTap(item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.only(top: 16, bottom: 16),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题栏
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '热搜榜',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                  // 刷新按钮（非加载状态时显示）
                  if (!isLoading && error == null)
                    IconButton(
                      icon: Icon(Icons.refresh,
                          size: 20, color: scheme.onSurface),
                      onPressed: onRefresh,
                      tooltip: '刷新热搜榜',
                    ),
                ],
              ),
            ),

            // 加载状态
            if (isLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            // 错误状态
            else if (error != null)
              SearchErrorState(
                message: error!,
                onRetry: onRefresh,
              )
            // 空状态（无错误但数据为空）
            else if (hotSearches.isEmpty)
              const SearchEmptyState(message: '暂无热搜数据')
            // 热搜列表
            else
              ...hotSearches.map((item) => _buildItem(context, item)),
          ],
        ),
      ),
    );
  }
}
