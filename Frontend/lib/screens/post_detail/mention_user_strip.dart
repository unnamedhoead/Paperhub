/// @提及用户横向选择条（从 PostCommentInputBar 抽出的纯展示 Widget）。
///
/// 显示在评论输入框上方：先列已选用户（带蓝色对勾），再列未选候选用户；点击已选项触发
/// [onToggle]（取消），点击候选项触发 [onSelect]（选择）。候选与已选都为空且仍展示时显示
/// 「搜索用户中…」。行为与原 _buildBottomCommentInput 中的横栏一致。
library;

import 'package:flutter/material.dart';

import '../../models/post_model.dart';

/// @提及候选/已选用户横条。
class MentionUserStrip extends StatelessWidget {
  const MentionUserStrip({
    super.key,
    required this.selectedMentions,
    required this.candidates,
    required this.onSelect,
    required this.onToggle,
  });

  /// 已选用户：用户名(小写) -> 用户。
  final Map<String, Author> selectedMentions;

  /// 候选用户列表。
  final List<Author> candidates;

  /// 选择一个候选用户。
  final ValueChanged<Author> onSelect;

  /// 切换（取消）一个已选用户。
  final ValueChanged<Author> onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = scheme.surface;
    final unselected = candidates
        .where((u) => !selectedMentions.containsKey(u.name.toLowerCase()))
        .toList();
    return Container(
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
      child: candidates.isEmpty && selectedMentions.isEmpty
          ? _buildLoading(scheme)
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: selectedMentions.length + unselected.length,
              itemBuilder: (context, index) {
                if (index < selectedMentions.length) {
                  final user = selectedMentions.values.elementAt(index);
                  return _AvatarItem(user: user, selected: true,
                      onTap: () => onToggle(user));
                }
                final user = unselected[index - selectedMentions.length];
                return _AvatarItem(user: user, selected: false,
                    onTap: () => onSelect(user));
              },
            ),
    );
  }

  Widget _buildLoading(ColorScheme scheme) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
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
    );
  }
}

/// 单个用户头像项（已选带蓝色描边与对勾，未选灰色描边）。
class _AvatarItem extends StatelessWidget {
  const _AvatarItem({
    required this.user,
    required this.selected,
    required this.onTap,
  });

  final Author user;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasHttpAvatar = user.avatar.isNotEmpty &&
        (user.avatar.startsWith('http://') ||
            user.avatar.startsWith('https://'));
    final accent = selected ? Colors.blue : Colors.black;
    final avatar = Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? Colors.blue : Colors.grey[300]!,
          width: selected ? 2 : 1,
        ),
      ),
      child: CircleAvatar(
        radius: 24,
        backgroundImage: hasHttpAvatar ? NetworkImage(user.avatar) : null,
        backgroundColor: selected ? Colors.blue[50] : Colors.grey[200],
        child: !hasHttpAvatar
            ? Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.blue : Colors.white,
                ),
              )
            : null,
      ),
    );

    final column = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        avatar,
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxWidth: 65),
          child: Text(
            user.name,
            style: TextStyle(
              fontSize: 12,
              color: accent,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 65,
          margin: const EdgeInsets.only(right: 10),
          child: selected
              ? Stack(
                  children: [
                    column,
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
                        child: const Icon(Icons.check,
                            size: 12, color: Colors.white),
                      ),
                    ),
                  ],
                )
              : column,
        ),
      ),
    );
  }
}
