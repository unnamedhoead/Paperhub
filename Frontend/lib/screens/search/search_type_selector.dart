import 'package:flutter/material.dart';

/// Search-type selector sliver: an [ExpansionTile] with radio options for the
/// active search mode (关键词 / 标签 / 作者).
///
/// Extracted from `search_screen.dart` unchanged. Returns a [SliverToBoxAdapter]
/// so it can be dropped directly into the page's [CustomScrollView]. Selection
/// and expansion state are owned by the host and delivered through callbacks.
class SearchTypeSelector extends StatelessWidget {
  /// Map of internal type key -> display label (e.g. `keyword` -> `关键词`).
  final Map<String, String> options;

  /// Currently selected type key; must be one of [options]'s keys.
  final String selectedType;

  /// Whether the expansion tile is open (drives the trailing arrow icon).
  final bool isExpanded;

  /// Invoked when the expansion tile opens/closes.
  final ValueChanged<bool> onExpansionChanged;

  /// Invoked when a type is chosen (radio tap or row tap).
  final ValueChanged<String> onTypeChanged;

  const SearchTypeSelector({
    super.key,
    required this.options,
    required this.selectedType,
    required this.isExpanded,
    required this.onExpansionChanged,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(
              bottom: BorderSide(color: scheme.outline.withOpacity(0.12))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '搜索方式',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: scheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: scheme.surfaceVariant,
                border: Border.all(color: scheme.outline.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ExpansionTile(
                title: Text(
                  options[selectedType]!,
                  style: TextStyle(color: scheme.onSurface),
                ),
                trailing: Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: scheme.onSurface.withOpacity(0.7),
                ),
                initiallyExpanded: false,
                onExpansionChanged: onExpansionChanged,
                children: options.entries.map((entry) {
                  return ListTile(
                    title: Text(entry.value,
                        style: TextStyle(color: scheme.onSurface)),
                    leading: Radio<String>(
                      value: entry.key,
                      groupValue: selectedType,
                      onChanged: (value) => onTypeChanged(value!),
                      activeColor: scheme.primary,
                    ),
                    onTap: () => onTypeChanged(entry.key),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
