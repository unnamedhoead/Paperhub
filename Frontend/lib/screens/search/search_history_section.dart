import 'package:flutter/material.dart';

import '../../models/search_model.dart';
import 'search_placeholders.dart';

/// Search-history sliver: title row with a 「清空历史」action, a loading
/// spinner, an empty placeholder, or the history list with a 展开/收起 toggle.
///
/// Extracted from `search_screen.dart` unchanged. Returns a [SliverToBoxAdapter]
/// for direct use in the page's [CustomScrollView]. All persistence/navigation
/// side effects stay in the host and are delivered through callbacks.
class SearchHistorySection extends StatelessWidget {
  /// History entries, newest first (already ordered by the service layer).
  final List<SearchHistoryItem> history;

  /// Whether the history is still loading (shows a spinner).
  final bool isLoading;

  /// Whether the full list is shown; when false only the first 5 are visible.
  final bool isExpanded;

  /// Map of search-type key -> display label, used for each item's subtitle.
  final Map<String, String> searchTypeLabels;

  /// Clears all history entries.
  final VoidCallback onClearHistory;

  /// Toggles between the collapsed (5 items) and expanded views.
  final VoidCallback onToggleExpand;

  /// Invoked when a history entry is tapped.
  final ValueChanged<SearchHistoryItem> onItemTap;

  /// Invoked to delete a single entry by id.
  final ValueChanged<String> onDeleteItem;

  const SearchHistorySection({
    super.key,
    required this.history,
    required this.isLoading,
    required this.isExpanded,
    required this.searchTypeLabels,
    required this.onClearHistory,
    required this.onToggleExpand,
    required this.onItemTap,
    required this.onDeleteItem,
  });

  /// Builds the visible history items, limited to 5 when collapsed.
  List<Widget> _buildItems() {
    final displayCount =
        isExpanded || history.length <= 5 ? history.length : 5;
    return history
        .take(displayCount)
        .map((item) => _buildItem(item))
        .toList();
  }

  /// Single history row: history icon, keyword title, search-type subtitle,
  /// and a trailing delete button.
  Widget _buildItem(SearchHistoryItem item) {
    return ListTile(
      leading: const Icon(Icons.history, color: Colors.grey, size: 20),
      title: Text(item.keyword),
      subtitle: Text(
        '搜索方式: ${searchTypeLabels[item.searchType]}',
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.close, size: 18, color: Colors.grey),
        onPressed: () => onDeleteItem(item.id),
      ),
      onTap: () => onItemTap(item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.only(top: 16),
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
                  const Text(
                    '搜索历史',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  // 清空历史按钮
                  if (history.isNotEmpty)
                    TextButton(
                      onPressed: onClearHistory,
                      child: const Text(
                        '清空历史',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ),
                ],
              ),
            ),

            // 历史记录列表
            if (isLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (history.isEmpty)
              const SearchEmptyState(message: '暂无搜索历史')
            else
              Column(
                children: [
                  ..._buildItems(),
                  if (history.length > 5)
                    // 展开/收起按钮
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: TextButton(
                          onPressed: onToggleExpand,
                          child: Text(
                            isExpanded ? '收起' : '展开',
                            style: const TextStyle(
                                fontSize: 14, color: Colors.grey),
                          ),
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
