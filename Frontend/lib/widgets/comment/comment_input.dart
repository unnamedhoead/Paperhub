/// Bottom comment input bar with reply state and @mention support.
///
/// Extracted from PostDetailScreen's _buildBottomCommentInput method.
/// Displays an optional reply banner, a text input field, and a send button.
/// Supports @mention user selection above the input.
import 'package:flutter/material.dart';
import '../../models/post_model.dart';

class CommentInputBar extends StatelessWidget {
  final Comment? replyTo;
  final String? replyParentId;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSubmitting;
  final VoidCallback onSubmit;
  final VoidCallback onCancelReply;
  final bool showMentionList;
  final Map<String, Author> selectedMentions;
  final List<Author> mentionCandidates;
  final ValueChanged<Author> onSelectMention;
  final ValueChanged<Author> onToggleMention;

  const CommentInputBar({
    Key? key,
    this.replyTo,
    this.replyParentId,
    required this.controller,
    required this.focusNode,
    this.isSubmitting = false,
    required this.onSubmit,
    required this.onCancelReply,
    this.showMentionList = false,
    this.selectedMentions = const <String, Author>{},
    this.mentionCandidates = const <Author>[],
    required this.onSelectMention,
    required this.onToggleMention,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = scheme.surface;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        color: bg,
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          bottom: MediaQuery.of(context).padding.bottom == 0
              ? 12
              : MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // @mention user selection bar
            if (showMentionList &&
                (selectedMentions.isNotEmpty || mentionCandidates.isNotEmpty))
              Container(
                height: 100,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: bg,
                  border: Border(
                    bottom: BorderSide(
                      color: scheme.outline.withOpacity(0.15),
                      width: 0.5,
                    ),
                  ),
                ),
                child: mentionCandidates.isEmpty && selectedMentions.isEmpty
                    ? Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  scheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '搜索用户中...',
                              style: TextStyle(
                                color: scheme.onSurface.withOpacity(0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: selectedMentions.length +
                            mentionCandidates
                                .where((u) => !selectedMentions
                                    .containsKey(u.name.toLowerCase()))
                                .length,
                        itemBuilder: (context, index) {
                          if (index < selectedMentions.length) {
                            final user =
                                selectedMentions.values.elementAt(index);
                            return _buildSelectedMentionChip(user);
                          } else {
                            final unselectedCandidates = mentionCandidates
                                .where((u) => !selectedMentions
                                    .containsKey(u.name.toLowerCase()))
                                .toList();
                            final user =
                                unselectedCandidates[index - selectedMentions.length];
                            return _buildCandidateChip(user);
                          }
                        },
                      ),
              ),
            // Reply banner
            if (replyTo != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                color: scheme.surfaceVariant,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '回复 @${replyTo!.author.name}',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: onCancelReply,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      hintText: replyTo != null ? '写回复...' : '写评论...',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: scheme.surfaceVariant,
                      hintStyle: TextStyle(
                        color: scheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    style: TextStyle(color: scheme.onSurface),
                    enabled: !isSubmitting,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: isSubmitting ? null : onSubmit,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(replyTo != null ? '回复' : '发送'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedMentionChip(Author user) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onToggleMention(user),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 65,
          margin: const EdgeInsets.only(right: 10),
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.blue, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundImage:
                          user.avatar.isNotEmpty &&
                                  (user.avatar.startsWith('http://') ||
                                      user.avatar.startsWith('https://'))
                              ? NetworkImage(user.avatar)
                              : null,
                      backgroundColor: Colors.blue[50],
                      child: user.avatar.isEmpty ||
                              (!user.avatar.startsWith('http://') &&
                                  !user.avatar.startsWith('https://'))
                          ? Text(
                              user.name.isNotEmpty
                                  ? user.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 65),
                    child: Text(
                      user.name,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.check, size: 12, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCandidateChip(Author user) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onSelectMention(user),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 65,
          margin: const EdgeInsets.only(right: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey[300]!, width: 1),
                ),
                child: CircleAvatar(
                  radius: 24,
                  backgroundImage:
                      user.avatar.isNotEmpty &&
                              (user.avatar.startsWith('http://') ||
                                  user.avatar.startsWith('https://'))
                          ? NetworkImage(user.avatar)
                          : null,
                  backgroundColor: Colors.grey[200],
                  child: user.avatar.isEmpty ||
                          (!user.avatar.startsWith('http://') &&
                              !user.avatar.startsWith('https://'))
                      ? Text(
                          user.name.isNotEmpty
                              ? user.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxWidth: 65),
                child: Text(
                  user.name,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
