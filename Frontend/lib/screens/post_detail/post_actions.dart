part of '../post_detail_screen.dart';
// Mechanically extracted from post_detail_screen.dart

extension _PostDetailScreenStateActions on _PostDetailScreenState {

  void _toggleLike() {
    // keep backward-compatible call site (double tap)
    _handlePostLikePressed();
  }


  Future<void> _handlePostLikePressed() async {
    if (_postLikeInFlight) return; // 防止重复请求
    _postLikeInFlight = true;

    final previousLiked = isLiked;
    final previousCount = likeCount;

    // 乐观更新
    setState(() {
      isLiked = !isLiked;
      likeCount += isLiked ? 1 : -1;
      widget.post.isLiked = isLiked;
      widget.post.likesCount = likeCount;
    });

    if (isLiked) {
      // 仅控制动画显示，不作为大爱心常驻显示的条件
      setState(() {
        _showBigHeart = true;
      });
      _heartCtrl.forward(from: 0.0);
    }

    try {
      final resp = isLiked
          ? await ApiService.likePost(widget.post.id)
          : await ApiService.unlikePost(widget.post.id);
      final status = (resp['statusCode'] ?? 500) as int;
      final body = resp['body'] as Map<String, dynamic>?;

      print('点赞响应: status=$status, body=$body'); // 调试日志

      if (status >= 200 && status < 300) {
        // 如果后端返回了最新计数，则以后端为准
        if (body != null &&
            body.containsKey('likesCount') &&
            body.containsKey('isLiked')) {
          setState(() {
            likeCount = body['likesCount'] as int;
            isLiked = body['isLiked'] as bool;
            widget.post.likesCount = likeCount;
            widget.post.isLiked = isLiked;
          });
        } else if (body != null && body.containsKey('message')) {
          // 如果只有 message，说明可能是 204 或其他情况，保持乐观更新
          print('警告: 响应缺少 likesCount 或 isLiked，保持乐观更新');
        }
        // （可选）如果后端不自动创建通知，前端可以调用通知接口：
        // await ApiService.createNotification({ ... });
      } else {
        // 请求失败 -> 回滚
        setState(() {
          isLiked = previousLiked;
          likeCount = previousCount;
          widget.post.isLiked = previousLiked;
          widget.post.likesCount = previousCount;
        });
        final msg = body != null && body['message'] != null
            ? body['message'].toString()
            : '点赞失败，请稍后重试';
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
        }
      }
    } catch (e, stackTrace) {
      // 网络或解析错误 -> 回滚
      print('点赞异常: $e');
      print('堆栈跟踪: $stackTrace');
      setState(() {
        isLiked = previousLiked;
        likeCount = previousCount;
        widget.post.isLiked = previousLiked;
        widget.post.likesCount = previousCount;
      });
      if (mounted) {
        final errorMsg = e.toString().contains('超时')
            ? '请求超时，请检查网络连接'
            : '网络错误，点赞未成功，请稍后重试';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMsg)));
      }
    } finally {
      _postLikeInFlight = false;
    }
  }


  Future<void> _toggleSave() async {
    if (_saveInFlight) return;
    _saveInFlight = true;
    final previousSaved = isSaved;
    final previousFavoriteCount = widget.post.favoriteCount;
    // 只对收藏状态做乐观更新，不对数量做乐观更新
    setState(() {
      isSaved = !isSaved;
      widget.post.isSaved = isSaved;
    });
    try {
      final resp = isSaved
          ? await ApiService.favoritePost(widget.post.id)
          : await ApiService.unfavoritePost(widget.post.id);
      final status = resp['statusCode'] as int? ?? 500;
      final body = resp['body'] as Map<String, dynamic>?;
      if (status >= 200 && status < 300) {
        if (body != null) {
          final serverValue = body['isSaved'] as bool?;
          final serverFavoritesCount = body['favoritesCount'] as int?;
          setState(() {
            if (serverValue != null) {
              isSaved = serverValue;
              widget.post.isSaved = serverValue;
            }
            if (serverFavoritesCount != null) {
              widget.post.favoriteCount = serverFavoritesCount;
            }
          });
        }
      } else {
        setState(() {
          isSaved = previousSaved;
          widget.post.isSaved = previousSaved;
        });
        final msg = body != null && body['message'] != null
            ? body['message'].toString()
            : '收藏操作失败';
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
        }
      }
    } catch (e) {
      setState(() {
        isSaved = previousSaved;
        widget.post.isSaved = previousSaved;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('网络错误，收藏操作未成功')));
      }
    } finally {
      _saveInFlight = false;
    }
  }


  Future<void> _openUserProfile(String userId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => ProfilePage(userId: userId)),
    );
    // 从用户主页返回时，刷新关注状态（特别是如果用户在该页面取关了作者）
    if (userId == widget.post.author.id && _currentUserId != userId) {
      await _checkFollowStatus();
    }
  }


  Future<void> _onShare() async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先登录')));
      return;
    }

    // 显示分享选择界面
    final selectedUserId = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ShareUserSelectionSheet(
        currentUserId: _currentUserId!,
        post: widget.post,
      ),
    );

    if (selectedUserId == null) return;

    // 分享帖子到选中的用户
    await _sharePostToUser(selectedUserId);
  }


  Future<void> _sharePostToUser(String targetUserId) async {
    try {
      // 显示加载提示
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('正在分享...'),
          duration: Duration(seconds: 1),
        ),
      );

      // 获取或创建 conversation
      final chatService = ChatService();
      final conversation = await chatService.createOrGetPrivateConversation(
        targetUserId,
      );

      if (conversation == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('创建会话失败，请稍后重试')));
        return;
      }

      // 发送分享消息
      // 使用 SHARE 类型，content 只存储 post ID
      await chatService.sendMessage(
        conversationId: conversation.id,
        content: widget.post.id, // content 只存储 post ID
        type: MessageType.share,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('分享成功')));

      // 可选：导航到聊天界面
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ChatScreen(conversation: conversation),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('分享失败: $e')));
    }
  }


  void _openMoreActions() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            // 只有作者可以看到“编辑”和“删除”
            if (_isOwner)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('编辑笔记'),
                onTap: () async {
                  // 先关闭底部弹窗
                  Navigator.pop(context);
                  // 复用已有的编辑逻辑
                  await _openEditPost();
                },
              ),

            if (_isOwner)
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('删除笔记', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeletePost();
                },
              ),
            ListTile(
              leading: const Icon(Icons.flag),
              title: const Text('举报'),
              onTap: () async {
                Navigator.pop(context);
                final result = await showDialog(
                  context: context,
                  builder: (context) =>
                      ReportPostDialog(postId: int.parse(widget.post.id)),
                );
                if (result == true && mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('举报成功，我们会尽快处理')));
                }
              },
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _confirmDeletePost() async {
    final confirmed = await DialogUtils.showDeleteConfirmDialog(
      context: context,
      itemName: '笔记',
      additionalWarning: '删除后将无法恢复。',
    );

    if (confirmed == true) {
      await _deletePost();
    }
  }


  Future<void> _deletePost() async {
    setState(() => _isDeleting = true);
    try {
      final resp = await ApiService.deletePost(widget.post.id);
      final status = resp['statusCode'] as int? ?? 500;
      final body = resp['body'] as Map<String, dynamic>?;

      if (status >= 200 && status < 300) {
        if (!mounted) return;
        Navigator.of(context).pop(true);
        return;
      }

      final msg = body != null && body['message'] != null
          ? body['message'].toString()
          : '删除失败，请稍后重试';
      _showSnack(msg);
    } catch (e) {
      _showSnack('删除失败：$e');
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }


  Future<void> _openEditPost() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NoteEditorPage(initialPost: widget.post),
      ),
    );

    // 编辑页返回 true，表示“保存成功，需要刷新详情”
    if (result == true) {
      await _loadPostDetail();
    }
  }


  Widget _buildActionBar() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: scheme.outline.withOpacity(0.15)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              isLiked ? Icons.favorite : Icons.favorite_border,
              color: isLiked ? Colors.redAccent : scheme.onSurface,
            ),
            onPressed: _toggleLike,
          ),
          Text('$likeCount', style: TextStyle(color: scheme.onSurface)),
          const SizedBox(width: 12),
          IconButton(
            icon: Icon(Icons.mode_comment_outlined, color: scheme.onSurface),
            onPressed: () => FocusScope.of(context).requestFocus(FocusNode()),
          ),
          const SizedBox(width: 8),
          Text(
            '${widget.post.commentsCount}',
            style: TextStyle(color: scheme.onSurface),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: Icon(
              isSaved ? Icons.bookmark : Icons.bookmark_border,
              color: isSaved ? scheme.primary : scheme.onSurface,
            ),
            onPressed: _toggleSave,
          ),
          const SizedBox(width: 8),
          Text(
            '${widget.post.favoriteCount}',
            style: TextStyle(color: scheme.onSurface),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.share_outlined, color: scheme.onSurface),
            onPressed: _onShare,
          ),
        ],
      ),
    );
  }


}
