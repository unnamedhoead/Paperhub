import 'package:flutter/material.dart';

/// Reusable scaffold for each admin section page.
class SectionScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  const SectionScaffold({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: ValueKey(title),
      color: theme.scaffoldBackgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: constraints.maxWidth,
                minHeight: constraints.maxHeight,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  child,
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Reusable search bar widget.
class AdminSearchBar extends StatelessWidget {
  final String hintText;
  final String buttonLabel;
  final VoidCallback? onPressed;
  final ValueChanged<String>? onChanged;
  const AdminSearchBar({
    super.key,
    required this.hintText,
    required this.buttonLabel,
    this.onPressed,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            decoration: InputDecoration(
              hintText: hintText,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
            onPressed: onPressed ?? () {}, child: Text(buttonLabel)),
      ],
    );
  }
}

/// Reusable data table inside a Card.
class PlaceholderTable extends StatelessWidget {
  final List<String> headers;
  final List<List<Widget>> rows;
  const PlaceholderTable(
      {super.key, required this.headers, required this.rows});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Card(
          margin: EdgeInsets.zero,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                columns: headers
                    .map((h) => DataColumn(label: Text(h)))
                    .toList(),
                rows: rows
                    .map((cells) => DataRow(
                        cells:
                            cells.map((cell) => DataCell(cell)).toList()))
                    .toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Reusable pagination bar.
class Pagination extends StatelessWidget {
  final int currentPage;
  final int totalItems;
  final int pageSize;
  final ValueChanged<int> onPageChanged;
  const Pagination({
    super.key,
    required this.currentPage,
    required this.totalItems,
    this.pageSize = 10,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (totalItems <= 0) return const SizedBox.shrink();
    final totalPages = (totalItems + pageSize - 1) ~/ pageSize;
    if (totalPages <= 1) return const SizedBox.shrink();
    final displayPage = currentPage + 1;
    return Align(
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: currentPage <= 0
                ? null
                : () => onPageChanged(currentPage - 1),
            icon: const Icon(Icons.chevron_left),
          ),
          Text('第 $displayPage / $totalPages 页'),
          IconButton(
            onPressed: currentPage >= totalPages - 1
                ? null
                : () => onPageChanged(currentPage + 1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

/// Reusable filter bar for reports.
class ReportFilterBar extends StatelessWidget {
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onSearch;
  const ReportFilterBar({super.key, this.onSearchChanged, this.onSearch});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AdminSearchBar(
            hintText: '搜索举报（举报人 / 被举报人 / 理由 / 对象）',
            buttonLabel: '搜索',
            onChanged: onSearchChanged,
            onPressed: onSearch,
          ),
        ),
      ],
    );
  }
}
