import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../models/post_model.dart';
import '../../widgets/post_card.dart';

/// Bottom-sheet content listing the user's recently browsed posts.
///
/// Use as the body of a [showModalBottomSheet] call. The sheet closes itself
/// (`Navigator.pop`) before delegating side effects to the host via callbacks,
/// preserving the original screen behavior.
class BrowseHistorySheet extends StatelessWidget {
  final List<Post> posts;
  final String? currentUserId;

  /// Clears the persisted history (awaited before the sheet closes).
  final Future<void> Function() onClearConfirmed;

  /// Invoked after the sheet has closed (host shows the confirmation snack).
  final VoidCallback onCleared;

  final void Function(Post post) onPostTap;
  final void Function(Post post) onAuthorTap;
  final Future<bool> Function(Post post) onLikeTap;

  const BrowseHistorySheet({
    super.key,
    required this.posts,
    required this.currentUserId,
    required this.onClearConfirmed,
    required this.onCleared,
    required this.onPostTap,
    required this.onAuthorTap,
    required this.onLikeTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('浏览历史', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          TextButton.icon(onPressed: () async { await onClearConfirmed(); if (context.mounted) Navigator.of(context).pop(); onCleared(); }, icon: const Icon(Icons.delete_outline), label: const Text('清空')),
        ])),
        const Divider(height: 1),
        Expanded(child: MasonryGridView.count(
          crossAxisCount: 2, crossAxisSpacing: 3, mainAxisSpacing: 3,
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
          itemCount: posts.length,
          itemBuilder: (ctx, index) {
            final p = posts[index];
            return PostCard(post: p, onTap: () { Navigator.of(context).pop(); onPostTap(p); },
              onAuthorTap: () { if (p.author.id != currentUserId) { Navigator.of(context).pop(); onAuthorTap(p); } },
              onLikeTap: (_) => onLikeTap(p));
          },
        )),
      ]),
    ));
  }
}
