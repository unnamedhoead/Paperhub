/// 评论输入栏（含 @提及子系统）独立 Widget。
///
/// 从 `_PostDetailScreenState` 抽出的底部评论/回复输入条：自持 [TextEditingController]、
/// [FocusNode] 与全部 @提及输入状态（候选列表、已选用户、@位置/查询、自动添加标志），
/// 负责文本变化检测、@用户搜索/选择/取消、提交评论。提交/回复目标等数据通过传入的
/// [commentController] 完成；需要 UI 提示时用 [onMessage] 回调（避免在此处直接弹 SnackBar，
/// 但因本 Widget 已持有 BuildContext，也可由调用方决定）。
///
/// 行为与原 `_buildBottomCommentInput` + 原 State 内 @提及方法完全一致。
library;

import 'package:flutter/material.dart';

import '../../models/post_model.dart';
import '../../services/api_service.dart';
import 'post_comment_controller.dart';

/// 底部评论输入栏。
class PostCommentInputBar extends StatefulWidget {
  const PostCommentInputBar({super.key, required this.commentController});

  /// 评论子控制器（提供回复目标、提交/刷新评论）。
  final PostCommentController commentController;

  @override
  State<PostCommentInputBar> createState() => _PostCommentInputBarState();
}

class _PostCommentInputBarState extends State<PostCommentInputBar> {
  final FocusNode _commentFocusNode = FocusNode();
  final TextEditingController _commentController = TextEditingController();

  // @功能相关状态
  bool _showMentionList = false;
  List<Author> _mentionCandidates = [];
  String _mentionQuery = '';
  int _mentionStartIndex = -1; // @符号在文本中的位置
  Map<String, Author> _selectedMentions = {}; // 已选择的@用户映射：用户名 -> 用户对象
  bool _isAutoAddingMention = false; // 标记是否正在自动添加@用户名（用于区分自动添加和手动输入）

  PostCommentController get _comm => widget.commentController;

  @override
  void initState() {
    super.initState();
    _commentController.addListener(_onCommentTextChanged);
    // 回复状态变化（startReply/cancelReply）由 commentController 通知，需重建并清空输入。
    _comm.addListener(_onCommentControllerChanged);
  }

  @override
  void dispose() {
    _comm.removeListener(_onCommentControllerChanged);
    _commentController.removeListener(_onCommentTextChanged);
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  /// commentController 变更（包括开始/取消回复）时：开始回复要聚焦输入框并清空。
  Comment? _lastReplyTo;
  void _onCommentControllerChanged() {
    final replyTo = _comm.currentReplyTo;
    if (!identical(replyTo, _lastReplyTo)) {
      _lastReplyTo = replyTo;
      // 开始/切换回复时清空输入与 @状态，并聚焦；取消回复时也清空。
      _resetMentionState();
      _commentController.text = '';
      if (replyTo != null) {
        _commentFocusNode.requestFocus();
      }
    }
    if (mounted) setState(() {});
  }

  void _resetMentionState() {
    _showMentionList = false;
    _mentionCandidates = [];
    _mentionQuery = '';
    _mentionStartIndex = -1;
    _selectedMentions.clear();
    _isAutoAddingMention = false;
  }

  // ===== @提及：文本变化检测 =====

  void _onCommentTextChanged() {
    final text = _commentController.text;
    final cursorPosition = _commentController.selection.baseOffset;

    if (cursorPosition < 0 || cursorPosition > text.length) {
      setState(() {
        _showMentionList = false;
        _mentionQuery = '';
        _mentionStartIndex = -1;
      });
      return;
    }

    // 如果正在自动添加@用户名，不处理文本变化（避免误判为单选模式）
    if (_isAutoAddingMention) {
      return;
    }

    // 解析评论内容中实际存在的@用户名（格式：@A @B @C，有空格）
    final RegExp mentionRegex = RegExp(r'@([^\s@]+)');
    final Set<String> actualMentionedNames = {};
    for (final match in mentionRegex.allMatches(text)) {
      final userName = match.group(1)!.trim();
      if (userName.isNotEmpty && !userName.startsWith('@')) {
        actualMentionedNames.add(userName.toLowerCase());
      }
    }

    // 移除评论内容中不存在的@用户
    final keysToRemove = <String>[];
    for (final key in _selectedMentions.keys) {
      if (!actualMentionedNames.contains(key)) {
        keysToRemove.add(key);
      }
    }
    if (keysToRemove.isNotEmpty) {
      setState(() {
        for (final key in keysToRemove) {
          _selectedMentions.remove(key);
        }
      });
    }

    // 当选择列表为空且没有检测到@时，关闭横栏
    if (_selectedMentions.isEmpty && _mentionStartIndex == -1) {
      setState(() {
        _showMentionList = false;
        _mentionQuery = '';
        _mentionStartIndex = -1;
      });
    }

    // 查找最近的@符号（用于检测是否正在输入@）
    int atIndex = -1;
    for (int i = cursorPosition - 1; i >= 0; i--) {
      if (text[i] == '@') {
        // 检查这个@后面是否跟着已选择的用户名
        bool isMentioned = false;
        if (i + 1 < text.length) {
          for (final user in _selectedMentions.values) {
            if (text.length >= i + 1 + user.name.length &&
                text.substring(i + 1, i + 1 + user.name.length) == user.name) {
              isMentioned = true;
              break;
            }
          }
        }
        if (!isMentioned) {
          atIndex = i;
          break;
        }
      } else if (text[i] == ' ' || text[i] == '\n') {
        break; // 遇到空格或换行，说明不在@上下文中
      }
    }

    if (atIndex != -1) {
      // 检测到@符号
      final query = text.substring(atIndex + 1, cursorPosition).trim();

      setState(() {
        _mentionStartIndex = atIndex;
        _mentionQuery = query;
        _showMentionList = true;
      });

      if (query.isEmpty) {
        // 多选模式：@后面没有内容，显示关注用户列表
        if (_mentionCandidates.isEmpty || _mentionQuery != '') {
          _mentionCandidates = [];
          _searchMentionUsers('');
        }
      } else {
        // 单选模式：@后面有内容，搜索所有用户
        _mentionCandidates = [];
        _searchMentionUsers(query);
      }
    } else {
      // 如果没有检测到@符号
      bool isTypingAfterMentions = false;
      if (_selectedMentions.isNotEmpty && cursorPosition > 0) {
        final textBeforeCursor = text.substring(0, cursorPosition);
        final RegExp mentionRegex = RegExp(r'@([^\s@]+)');
        final matches = mentionRegex.allMatches(textBeforeCursor);

        if (matches.isNotEmpty) {
          final lastMatch = matches.last;
          final lastMentionEnd = lastMatch.end;
          if (cursorPosition > lastMentionEnd) {
            final textAfterLastMention =
                textBeforeCursor.substring(lastMentionEnd);
            if (textAfterLastMention.isNotEmpty &&
                !textAfterLastMention.trim().isEmpty) {
              isTypingAfterMentions = true;
            }
          }
        }
      }

      if (isTypingAfterMentions) {
        setState(() {
          _showMentionList = false;
          _mentionQuery = '';
          _mentionStartIndex = -1;
        });
      } else if (_selectedMentions.isNotEmpty) {
        final textBeforeCursor = text.substring(0, cursorPosition);
        final RegExp mentionRegex = RegExp(r'@([^\s@]+)');
        final matches = mentionRegex.allMatches(textBeforeCursor);

        bool shouldKeepOpen = false;
        if (matches.isNotEmpty) {
          final lastMatch = matches.last;
          final lastMentionEnd = lastMatch.end;
          final textAfterLastMention = cursorPosition > lastMentionEnd
              ? textBeforeCursor.substring(lastMentionEnd, cursorPosition)
              : '';

          if (cursorPosition == lastMentionEnd) {
            shouldKeepOpen = true;
          } else if (textAfterLastMention.trim().isEmpty &&
              textAfterLastMention.length <= 1) {
            shouldKeepOpen = true;
          }
        }

        if (shouldKeepOpen) {
          setState(() {
            _mentionQuery = '';
            _mentionStartIndex = -1;
            _showMentionList = true;
            if (_mentionCandidates.isEmpty) {
              _searchMentionUsers('');
            }
          });
        } else {
          setState(() {
            _showMentionList = false;
            _mentionQuery = '';
            _mentionStartIndex = -1;
          });
        }
      } else {
        setState(() {
          _showMentionList = false;
          _mentionQuery = '';
          _mentionStartIndex = -1;
        });
      }
    }
  }

  // ===== @提及：搜索 / 选择 =====

  Future<void> _searchMentionUsers(String query) async {
    try {
      Map<String, dynamic> resp;
      if (query.isEmpty) {
        resp = await ApiService.searchUsers(
          query: '',
          type: 'following',
          pageSize: 10,
        );
      } else {
        resp = await ApiService.searchUsers(
          query: query,
          type: 'all',
          pageSize: 10,
        );
      }

      if (resp['statusCode'] == 200 && mounted) {
        final body = resp['body'] as Map<String, dynamic>?;
        if (body != null) {
          final users = (body['users'] as List? ?? [])
              .map((u) {
                try {
                  String userName = u['displayName']?.toString() ?? '';
                  if (userName.isEmpty) {
                    userName = u['email']?.toString() ?? '';
                    if (userName.isNotEmpty && userName.contains('@')) {
                      userName = userName.split('@')[0];
                    }
                  }
                  return Author(
                    id: u['id']?.toString() ?? '',
                    name: userName,
                    avatar: u['avatar']?.toString() ?? '',
                    affiliation: u['affiliation']?.toString(),
                  );
                } catch (e) {
                  return null;
                }
              })
              .where((u) => u != null && u.name.isNotEmpty)
              .cast<Author>()
              .toList();

          if (mounted) {
            setState(() {
              _mentionCandidates = users;
            });
          }
        }
      }
    } catch (e) {
      // 忽略错误，不显示给用户
    }
  }

  void _selectMentionUser(Author user) {
    final userNameLower = user.name.toLowerCase();
    final isCurrentlySelected = _selectedMentions.containsKey(userNameLower);

    if (isCurrentlySelected) {
      _toggleMentionUser(user);
      return;
    }

    try {
      final text = _commentController.text;
      final cursorPosition = _commentController.selection.baseOffset;

      final isMultiSelectMode = _mentionQuery.isEmpty; // @后面没有内容 = 多选模式

      if (_mentionStartIndex != -1 && _mentionStartIndex < text.length) {
        final beforeAt = text.substring(0, _mentionStartIndex);
        final afterCursor = cursorPosition < text.length
            ? text.substring(cursorPosition)
            : '';

        String newText;
        int newCursorPosition;

        if (isMultiSelectMode) {
          if (_selectedMentions.isEmpty) {
            newText = '$beforeAt@${user.name} $afterCursor';
            newCursorPosition = beforeAt.length + user.name.length + 2;
          } else {
            final lastMentionMatch =
                RegExp(r'@([^\s@]+)\s*').allMatches(text).lastOrNull;
            if (lastMentionMatch != null) {
              final lastMentionEnd = lastMentionMatch.end;
              final beforeLastMention = text.substring(0, lastMentionEnd);
              final afterLastMention = text.substring(lastMentionEnd);
              newText = '$beforeLastMention@${user.name} $afterLastMention';
              newCursorPosition = lastMentionEnd + user.name.length + 2;
            } else {
              newText = '$beforeAt@${user.name} $afterCursor';
              newCursorPosition = beforeAt.length + user.name.length + 2;
            }
          }
        } else {
          newText = '$beforeAt@${user.name} $afterCursor';
          newCursorPosition = beforeAt.length + user.name.length + 2;
        }

        _isAutoAddingMention = true;
        _commentController.text = newText;
        _commentController.selection = TextSelection.collapsed(
          offset: newCursorPosition,
        );

        setState(() {
          _selectedMentions[userNameLower] = user;
          if (isMultiSelectMode) {
            _mentionQuery = '';
            _mentionStartIndex = -1;
            _showMentionList = true;
          } else {
            _showMentionList = false;
            _mentionQuery = '';
            _mentionStartIndex = -1;
          }
        });

        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            setState(() {
              _isAutoAddingMention = false;
            });
          }
        });
      } else {
        // 不在输入@状态：在文本末尾追加@用户名 + 空格（多选模式）
        final newText = '$text@${user.name} ';
        final newCursorPosition = newText.length;

        _isAutoAddingMention = true;
        _commentController.text = newText;
        _commentController.selection = TextSelection.collapsed(
          offset: newCursorPosition,
        );

        setState(() {
          _selectedMentions[userNameLower] = user;
          _showMentionList = true;
          _mentionQuery = '';
          _mentionStartIndex = -1;
        });

        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            setState(() {
              _isAutoAddingMention = false;
            });
          }
        });
      }
    } catch (e) {
      // ignore
    }
  }

  void _toggleMentionUser(Author user) {
    final userNameLower = user.name.toLowerCase();
    final isCurrentlySelected = _selectedMentions.containsKey(userNameLower);

    if (isCurrentlySelected) {
      // 取消选择：从评论框中删除@用户名（格式：@A @B @C，删除@B后变成@A @C）
      final text = _commentController.text;
      final RegExp mentionRegex = RegExp(r'@([^\s@]+)\s*');

      String newText = text;
      for (final match in mentionRegex.allMatches(text)) {
        final mentionedName = match.group(1)!.trim();
        if (mentionedName.toLowerCase() == userNameLower) {
          final startIndex = match.start;
          final endIndex = match.end;
          newText = text.substring(0, startIndex) + text.substring(endIndex);
          break;
        }
      }

      _isAutoAddingMention = true;
      _commentController.text = newText;

      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() {
            _isAutoAddingMention = false;
          });
        }
      });

      setState(() {
        _selectedMentions.remove(userNameLower);
        if (_selectedMentions.isEmpty) {
          _showMentionList = false;
          _mentionQuery = '';
          _mentionStartIndex = -1;
        }
      });
    } else {
      _selectMentionUser(user);
    }
  }

  // ===== 提交 =====

  /// 提交评论：解析输入框中的 @用户名，把数据/网络交给 commentController。
  Future<void> _handleCommentSubmit() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final RegExp mentionRegex = RegExp(r'@([^\s@]+)');
    final Set<String> actualMentionedNames = {};
    for (final match in mentionRegex.allMatches(text)) {
      final userName = match.group(1)!.trim();
      if (userName.isNotEmpty && !userName.startsWith('@')) {
        actualMentionedNames.add(userName.toLowerCase());
      }
    }

    final List<String> mentionIds = [];
    for (final entry in _selectedMentions.entries) {
      if (actualMentionedNames.contains(entry.key)) {
        mentionIds.add(entry.value.id);
      }
    }

    _selectedMentions.clear();

    final ok = await _comm.submitComment(
      text: text,
      mentionIds: mentionIds,
      parentId: _comm.currentReplyParentId,
      replyTo: _comm.currentReplyTo?.author,
    );

    if (!ok || !mounted) return;

    setState(() {
      _commentController.clear();
      _resetMentionState();
    });
    _commentFocusNode.unfocus();
    if (_comm.currentReplyTo != null) {
      _comm.cancelReply();
    }
  }

  // ===== UI =====

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = scheme.surface;
    final currentReplyTo = _comm.currentReplyTo;
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
            if (_showMentionList &&
                (_selectedMentions.isNotEmpty || _mentionCandidates.isNotEmpty))
              _buildMentionStrip(scheme, bg),
            if (currentReplyTo != null) _buildReplyBanner(scheme, currentReplyTo),
            _buildInputRow(scheme, currentReplyTo),
          ],
        ),
      ),
    );
  }

  Widget _buildMentionStrip(ColorScheme scheme, Color bg) {
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
      child: _mentionCandidates.isEmpty && _selectedMentions.isEmpty
          ? Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(scheme.primary),
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
              itemCount: _selectedMentions.length +
                  _mentionCandidates
                      .where(
                        (u) => !_selectedMentions
                            .containsKey(u.name.toLowerCase()),
                      )
                      .length,
              itemBuilder: (context, index) {
                if (index < _selectedMentions.length) {
                  final user = _selectedMentions.values.elementAt(index);
                  return _buildSelectedAvatar(user);
                }
                final unselectedCandidates = _mentionCandidates
                    .where(
                      (u) =>
                          !_selectedMentions.containsKey(u.name.toLowerCase()),
                    )
                    .toList();
                final user =
                    unselectedCandidates[index - _selectedMentions.length];
                return _buildCandidateAvatar(user);
              },
            ),
    );
  }

  Widget _buildSelectedAvatar(Author user) {
    final hasHttpAvatar = user.avatar.isNotEmpty &&
        (user.avatar.startsWith('http://') ||
            user.avatar.startsWith('https://'));
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _toggleMentionUser(user),
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
                          hasHttpAvatar ? NetworkImage(user.avatar) : null,
                      backgroundColor: Colors.blue[50],
                      child: !hasHttpAvatar
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

  Widget _buildCandidateAvatar(Author user) {
    final hasHttpAvatar = user.avatar.isNotEmpty &&
        (user.avatar.startsWith('http://') ||
            user.avatar.startsWith('https://'));
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectMentionUser(user),
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
                      hasHttpAvatar ? NetworkImage(user.avatar) : null,
                  backgroundColor: Colors.grey[200],
                  child: !hasHttpAvatar
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

  Widget _buildReplyBanner(ColorScheme scheme, Comment currentReplyTo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: scheme.surfaceVariant,
      child: Row(
        children: [
          Expanded(
            child: Text(
              '回复 @${currentReplyTo.author.name}',
              style: TextStyle(fontSize: 12, color: scheme.onSurface),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: _comm.cancelReply,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputRow(ColorScheme scheme, Comment? currentReplyTo) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _commentController,
            focusNode: _commentFocusNode,
            decoration: InputDecoration(
              hintText: currentReplyTo != null ? '写回复...' : '写评论...',
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
              hintStyle: TextStyle(color: scheme.onSurface.withOpacity(0.6)),
            ),
            style: TextStyle(color: scheme.onSurface),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _handleCommentSubmit,
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: Text(currentReplyTo != null ? '回复' : '发送'),
        ),
      ],
    );
  }
}
