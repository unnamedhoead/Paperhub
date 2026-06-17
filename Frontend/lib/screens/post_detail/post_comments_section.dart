/// 评论区独立 Widget（评论列表 + 楼中楼 + @提及内容渲染）。
///
/// 从 `_PostDetailScreenState` 抽出的 `_buildCommentsSection`：渲染顶层评论与回复、
/// 头像、相对时间、点赞、回复、删除按钮，以及把评论正文中的 @用户名渲染成可点击链接
/// （含按名搜索用户 ID 的缓存）。数据/网络通过传入的 [commentController] 完成。
///
/// 需要 BuildContext 的副作用（打开用户主页、删除前确认）通过 [onOpenUserProfile] /
/// [onConfirmDeleteComment] 回调上交给 Screen。行为与原 `_buildCommentsSection` 一致。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../models/post_model.dart';
import '../../services/api_service.dart';
import '../profile_screen.dart';
import 'post_comment_controller.dart';

/// 评论区。
class PostCommentsSection extends StatefulWidget {
  const PostCommentsSection({
    super.key,
    required this.commentController,
    required this.commentsCount,
    required this.currentUserId,
    required this.onOpenUserProfile,
    required this.onConfirmDeleteComment,
  });

  final PostCommentController commentController;

  /// 帖子的评论总数（用于标题展示）。
  final int commentsCount;

  /// 当前登录用户 ID（用于决定是否显示删除按钮）。
  final String? currentUserId;

  /// 打开某用户主页（Screen 负责 Navigator + 返回后刷新关注）。
  final void Function(String userId) onOpenUserProfile;

  /// 删除评论前确认（Screen 负责弹确认框并调 controller）。
  final void Function(
    Comment comment, {
    required bool isTopLevel,
    Comment? parentComment,
  }) onConfirmDeleteComment;

  @override
  State<PostCommentsSection> createState() => _PostCommentsSectionState();
}

class _PostCommentsSectionState extends State<PostCommentsSection> {
  /// 缓存@用户搜索结果，避免重复 API 调用。
  final Map<String, String?> _mentionUserIdCache = {};

  PostCommentController get _comm => widget.commentController;

  String? get _currentUserId => widget.currentUserId;

  @override
  void initState() {
    super.initState();
    _comm.addListener(_onChanged);
  }

  @override
  void dispose() {
    _comm.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  // ===== UI =====

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final comments = _comm.comments;
    final isLoadingComments = _comm.isLoadingComments;
    final hasMoreComments = _comm.hasMoreComments;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(height: 1, color: scheme.outline.withOpacity(0.15)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Text(
                '评论 (${widget.commentsCount})',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              const Spacer(),
              if (isLoadingComments)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: scheme.primary,
                  ),
                ),
              IconButton(
                icon: Icon(
                  Icons.refresh,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
                onPressed: isLoadingComments
                    ? null
                    : () => _comm.loadComments(refresh: true),
                tooltip: '刷新评论',
              ),
            ],
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: comments.length + (hasMoreComments ? 1 : 0),
          separatorBuilder: (_, __) =>
              Divider(indent: 16, color: scheme.outline.withOpacity(0.15)),
          itemBuilder: (context, idx) {
            if (idx == comments.length) {
              return _buildLoadMore(scheme, isLoadingComments);
            }
            return _buildCommentItem(scheme, comments[idx]);
          },
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildLoadMore(ColorScheme scheme, bool isLoadingComments) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Center(
        child: isLoadingComments
            ? CircularProgressIndicator(color: scheme.primary)
            : TextButton.icon(
                onPressed: () => _comm.loadComments(),
                icon: Icon(Icons.refresh, color: scheme.onSurfaceVariant),
                label: Text(
                  '加载更多评论',
                  style: TextStyle(color: scheme.primary),
                ),
              ),
      ),
    );
  }

  Widget _buildCommentItem(ColorScheme scheme, Comment c) {
    final inFlight = _comm.isCommentLikeInFlight(c.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          onTap: () => widget.onOpenUserProfile(c.author.id),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: _buildAvatarWidget(c.author.avatar, 16),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  c.author.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_currentUserId != null && c.author.id == _currentUserId)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  color: Colors.red[300],
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () =>
                      widget.onConfirmDeleteComment(c, isTopLevel: true),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (c.replyTo != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text(
                    '回复 @${c.replyTo!.name}',
                    style: TextStyle(fontSize: 12, color: scheme.primary),
                  ),
                ),
              _buildCommentContentWithMentions(c.content, c.mentions),
              _buildCommentMeta(scheme, c, inFlight, isReply: false),
            ],
          ),
        ),
        if (c.hasReplies)
          Padding(
            padding: const EdgeInsets.only(left: 56.0),
            child: Column(
              children: c.replies.map((reply) {
                return _buildReplyItem(scheme, c, reply);
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildReplyItem(ColorScheme scheme, Comment parent, Comment reply) {
    final replyInFlight = _comm.isCommentLikeInFlight(reply.id);
    return ListTile(
      onTap: () => widget.onOpenUserProfile(reply.author.id),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _buildAvatarWidget(reply.author.avatar, 14),
      title: Row(
        children: [
          Expanded(
            child: Text(
              reply.author.name,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (_currentUserId != null && reply.author.id == _currentUserId)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 16),
              color: Colors.red[300],
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => widget.onConfirmDeleteComment(
                reply,
                isTopLevel: false,
                parentComment: parent,
              ),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (reply.replyTo != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Text(
                '回复 @${reply.replyTo!.name}',
                style: TextStyle(fontSize: 12, color: scheme.primary),
              ),
            ),
          _buildCommentContentWithMentions(reply.content, reply.mentions),
          _buildCommentMeta(scheme, reply, replyInFlight,
              isReply: true, parentId: parent.id),
        ],
      ),
    );
  }

  /// 评论/回复底部的「时间 · 回复 · 点赞」行。
  Widget _buildCommentMeta(
    ColorScheme scheme,
    Comment c,
    bool inFlight, {
    required bool isReply,
    String? parentId,
  }) {
    final iconSize = isReply ? 16.0 : 18.0;
    return Row(
      children: [
        Text(
          _formatRelative(c.createdAt),
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
        TextButton(
          onPressed: () => _comm.startReply(c, parentId: parentId),
          child: const Text('回复', style: TextStyle(fontSize: 12)),
        ),
        const Spacer(),
        Text('${c.likesCount}',
            style: TextStyle(color: scheme.onSurfaceVariant)),
        IconButton(
          icon: Icon(
            c.isLiked ? Icons.thumb_up : Icons.thumb_up_off_alt,
            size: iconSize,
            color: c.isLiked ? scheme.primary : scheme.onSurfaceVariant,
          ),
          onPressed: inFlight ? null : () => _comm.handleCommentLikePressed(c),
        ),
      ],
    );
  }

  /// 构建包含 @提及的评论内容（可点击的 @链接）。
  Widget _buildCommentContentWithMentions(
    String content,
    List<Author> mentions,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final List<TextSpan> spans = [];
    final RegExp mentionRegex = RegExp(r'@([^\s@]+)');
    int lastIndex = 0;

    // 建立 @用户名到用户 ID 的映射（多种键确保能匹配）。
    final Map<String, String> mentionMap = {};
    for (final mention in mentions) {
      final lowerName = mention.name.toLowerCase();
      mentionMap[lowerName] = mention.id;
      if (lowerName.contains('@')) {
        final prefix = lowerName.substring(0, lowerName.indexOf('@'));
        mentionMap[prefix] = mention.id;
      }
      if (mention.name.contains('@')) {
        final emailPrefix = mention.name
            .substring(0, mention.name.indexOf('@'))
            .toLowerCase();
        mentionMap[emailPrefix] = mention.id;
      }
    }

    for (final match in mentionRegex.allMatches(content)) {
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: content.substring(lastIndex, match.start),
            style: TextStyle(fontSize: 13, color: scheme.onSurface),
          ),
        );
      }

      final mentionText = match.group(0)!; // 包含@的完整文本
      final userName = match.group(1)!; // 用户名部分
      final userId = mentionMap[userName.toLowerCase()];

      if (userId != null) {
        spans.add(_clickableMention(scheme, mentionText, userId));
      } else if (_mentionUserIdCache.containsKey(userName)) {
        final cachedUserId = _mentionUserIdCache[userName];
        if (cachedUserId != null) {
          spans.add(_clickableMention(scheme, mentionText, cachedUserId));
        } else {
          spans.add(_plainMention(scheme, mentionText));
        }
      } else {
        // 异步搜索用户（结果仅入缓存，不触发重建，与原行为一致）。
        _searchUserByName(userName)
            .then((id) => _mentionUserIdCache[userName] = id)
            .catchError((e) {
          if (kDebugMode) {
            debugPrint('PostCommentsSection.searchUserByName ignored: $e');
          }
          _mentionUserIdCache[userName] = null;
          return null;
        });
        spans.add(_plainMention(scheme, mentionText));
      }

      lastIndex = match.end;
    }

    if (lastIndex < content.length) {
      spans.add(
        TextSpan(
          text: content.substring(lastIndex),
          style: TextStyle(fontSize: 13, color: scheme.onSurface),
        ),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }

  TextSpan _clickableMention(
    ColorScheme scheme,
    String text,
    String userId,
  ) {
    return TextSpan(
      text: text,
      style: TextStyle(
        fontSize: 13,
        color: scheme.primary,
        fontWeight: FontWeight.w500,
      ),
      recognizer: TapGestureRecognizer()
        ..onTap = () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ProfilePage(userId: userId)),
          );
        },
    );
  }

  TextSpan _plainMention(ColorScheme scheme, String text) => TextSpan(
        text: text,
        style: TextStyle(fontSize: 13, color: scheme.onSurface),
      );

  /// 通过用户名搜索用户 ID（用于 @功能）。
  Future<String?> _searchUserByName(String userName) async {
    try {
      final resp = await ApiService.searchUsers(
        query: userName,
        type: 'all',
        pageSize: 10,
      );
      if (resp['statusCode'] == 200) {
        final body = resp['body'] as Map<String, dynamic>?;
        if (body != null) {
          final users = (body['users'] as List? ?? []);
          // 精确匹配 displayName 或 email 前缀。
          for (final user in users) {
            final displayName = user['displayName']?.toString() ?? '';
            final email = user['email']?.toString() ?? '';
            final emailPrefix = email.contains('@') ? email.split('@')[0] : '';
            if (displayName.toLowerCase() == userName.toLowerCase() ||
                emailPrefix.toLowerCase() == userName.toLowerCase()) {
              final userId = user['id']?.toString();
              if (userId != null) return userId;
            }
          }
          // 无精确匹配则用第一个结果。
          if (users.isNotEmpty) {
            return users[0]['id']?.toString();
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Widget _buildAvatarWidget(String avatarPath, double radius) {
    if (avatarPath.startsWith('http://') || avatarPath.startsWith('https://')) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey[300],
        child: ClipOval(
          child: Image.network(
            avatarPath,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                Icon(Icons.person, size: radius, color: Colors.grey),
          ),
        ),
      );
    }

    String assetPath = avatarPath;
    if (assetPath.startsWith('assets/images/')) {
      assetPath = assetPath.substring(14);
    } else if (assetPath.startsWith('assets/')) {
      assetPath = assetPath.substring(7);
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[300],
      child: ClipOval(
        child: Image.asset(
          assetPath,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              Icon(Icons.person, size: radius, color: Colors.grey),
        ),
      ),
    );
  }

  String _formatRelative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 4) return '刚刚';
    if (diff.inMinutes >= 4 && diff.inMinutes < 60) {
      return '${diff.inMinutes} 分钟前';
    }
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    return '${diff.inDays} 天前';
  }
}
