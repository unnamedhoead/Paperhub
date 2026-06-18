// lib/screens/note_editor/reference_selector.dart
part of 'note_editor_screen.dart';

extension on _NoteEditorPageState {
  // 获取当前可选的二级标签（用于#符号提示）
  List<String> _getAvailableSubTags() {
    if (_selectedDiscipline != null &&
        kRecommendedSubTags.containsKey(_selectedDiscipline)) {
      return kRecommendedSubTags[_selectedDiscipline!]!;
    } else {
      final set = <String>{};
      for (final list in kRecommendedSubTags.values) {
        set.addAll(list);
      }
      return set.toList();
    }
  }

  // 获取过滤后的分区列表（根据用户角色隐藏"公告区"）
  List<String> _getFilteredDisciplines() {
    // 如果用户角色是管理员或超级管理员，显示所有分区（包括公告区）
    if (_currentUserRole == 'ADMIN' || _currentUserRole == 'SUPER_ADMIN') {
      return kMainDisciplines; // 管理员和超级管理员可以看到所有分区
    } else {
      // 普通用户或角色未加载时隐藏"公告区"
      return kMainDisciplines
          .where((discipline) => discipline != '公告区')
          .toList();
    }
  }

  // 处理正文文本变化，检测#符号
  void _onContentChanged(String text) {
    // 检查是否正在输入#标签 - 只检查最后一个#，并且后面没有空格
    final lastIndex = text.lastIndexOf('#');
    if (lastIndex != -1) {
      // 提取#后面的所有内容
      final afterHash = text.substring(lastIndex + 1);

      // 检查#后面是否有空格或换行（表示标签已结束）
      final nextSpaceIndex = afterHash.indexOf(' ');
      final nextNewlineIndex = afterHash.indexOf('\n');

      // 如果#后面有空格或换行，表示标签已结束
      if (nextSpaceIndex != -1 || nextNewlineIndex != -1) {
        // 完成自定义标签输入
        _completeCustomTag();

        // 立即隐藏建议
        setState(() {
          _showTagSuggestions = false;
          _currentTagInput = '';
          _filteredTagSuggestions.clear();
          _isTypingCustomTag = false;
        });
        return;
      }

      // 如果#后面没有内容，不显示建议
      if (afterHash.isEmpty) {
        if (_showTagSuggestions) {
          setState(() {
            _showTagSuggestions = false;
            _currentTagInput = '';
            _filteredTagSuggestions.clear();
            _isTypingCustomTag = false;
          });
        }
        return;
      }

      // 提取当前正在输入的标签内容（到空格或换行为止）
      final endIndex = nextSpaceIndex != -1
          ? nextSpaceIndex
          : (nextNewlineIndex != -1 ? nextNewlineIndex : afterHash.length);

      if (endIndex > 0) {
        final tagInput = afterHash.substring(0, endIndex);

        setState(() {
          _currentTagInput = tagInput;
          _showTagSuggestions = true;

          // 过滤标签建议
          final availableTags = _getAvailableSubTags();
          _filteredTagSuggestions.clear();
          if (tagInput.isNotEmpty) {
            _filteredTagSuggestions.addAll(
              availableTags
                  .where(
                    (tag) => tag.toLowerCase().contains(tagInput.toLowerCase()),
                  )
                  .toList(),
            );
          }

          // 限制显示数量
          if (_filteredTagSuggestions.length > 10) {
            _filteredTagSuggestions = _filteredTagSuggestions.sublist(0, 10);
          }

          // 如果没有匹配的建议，表示用户正在输入自定义标签
          if (_filteredTagSuggestions.isEmpty && tagInput.isNotEmpty) {
            _isTypingCustomTag = true;
          } else {
            _isTypingCustomTag = false;
          }
        });
        return;
      }
    }

    // 如果没有#标签输入，隐藏建议
    if (_showTagSuggestions) {
      setState(() {
        _showTagSuggestions = false;
        _currentTagInput = '';
        _filteredTagSuggestions.clear();
        _isTypingCustomTag = false;
      });
    }
  }

  // 选择标签建议
  void _selectTagSuggestion(String tag) {
    final currentText = _contentController.text;
    final lastIndex = currentText.lastIndexOf('#');

    if (lastIndex != -1) {
      // 替换#及其后面的输入为完整的标签
      final beforeHash = currentText.substring(0, lastIndex);
      final afterHash = currentText.substring(lastIndex);
      final nextSpaceIndex = afterHash.indexOf(' ');
      final nextNewlineIndex = afterHash.indexOf('\n');
      final endIndex = nextSpaceIndex != -1
          ? nextSpaceIndex
          : (nextNewlineIndex != -1 ? nextNewlineIndex : afterHash.length);

      final newText = beforeHash + '#$tag ';
      _contentController.text = newText;
      _contentController.selection = TextSelection.fromPosition(
        TextPosition(offset: newText.length),
      );

      // 隐藏建议
      setState(() {
        _showTagSuggestions = false;
        _currentTagInput = '';
        _filteredTagSuggestions.clear();
        _isTypingCustomTag = false;
      });
    }
  }

  // 处理自定义标签完成（按空格或回车）
  void _completeCustomTag() {
    if (_currentTagInput.isNotEmpty &&
        !_filteredTagSuggestions.contains(_currentTagInput)) {
      // 这是一个自定义标签
      final currentText = _contentController.text;
      final lastIndex = currentText.lastIndexOf('#');

      if (lastIndex != -1) {
        // 替换#及其后面的输入为完整的自定义标签
        final beforeHash = currentText.substring(0, lastIndex);
        final afterHash = currentText.substring(lastIndex);
        final nextSpaceIndex = afterHash.indexOf(' ');
        final nextNewlineIndex = afterHash.indexOf('\n');
        final endIndex = nextSpaceIndex != -1
            ? nextSpaceIndex
            : (nextNewlineIndex != -1 ? nextNewlineIndex : afterHash.length);

        final newText = beforeHash + '#$_currentTagInput ';
        _contentController.text = newText;
        _contentController.selection = TextSelection.fromPosition(
          TextPosition(offset: newText.length),
        );
      }
    }

    // 隐藏建议
    setState(() {
      _showTagSuggestions = false;
      _currentTagInput = '';
      _filteredTagSuggestions.clear();
      _isTypingCustomTag = false;
    });
  }

  // 从文本中提取所有#标签
  Set<String> _extractTagsFromText(String text) {
    final Set<String> tags = {};
    // 匹配#后面的非空格字符，支持中文、英文、数字等
    final regex = RegExp(r'#([^\s#]+)');
    final matches = regex.allMatches(text);

    for (final match in matches) {
      if (match.groupCount >= 1) {
        final tag = match.group(1)!.trim();
        if (tag.isNotEmpty) {
          tags.add(tag);
        }
      }
    }

    return tags;
  }

  // 加载用户的帖子和收藏（用于引用文献选择）
  Future<void> _loadUserPostsAndFavorites() async {
    setState(() {
      _isLoadingReferences = true;
    });

    try {
      // 获取当前用户信息
      final userResp = await ApiService.getCurrentUserProfile();
      if (userResp['statusCode'] == 200) {
        final userId = userResp['body']['id']?.toString();

        // 检查用户ID是否存在
        if (userId == null || userId.isEmpty) {
          print('用户ID为空，无法加载引用文献');
          return;
        }

        // 并行加载用户帖子和收藏
        final results = await Future.wait([
          ApiService.getUserPosts(userId!, page: 1, pageSize: 50),
          ApiService.getUserFavorites(userId!, page: 1, pageSize: 50),
        ]);

        final postsResp = results[0] as Map<String, dynamic>;
        final favoritesResp = results[1] as Map<String, dynamic>;

        if (postsResp['statusCode'] == 200) {
          final postsData = postsResp['body']['posts'] as List<dynamic>? ?? [];
          setState(() {
            _userPosts = postsData.map((p) => Post.fromJson(p)).toList();
          });
        }

        if (favoritesResp['statusCode'] == 200) {
          final favoritesData =
              favoritesResp['body']['posts'] as List<dynamic>? ?? [];
          setState(() {
            _userFavorites = favoritesData
                .map((p) => Post.fromJson(p))
                .toList();
          });
        }
      }
    } catch (e) {
      print('加载用户帖子和收藏失败: $e');
    } finally {
      setState(() {
        _isLoadingReferences = false;
      });
    }
  }

  // 选择引用文献对话框
  void _showReferenceSelector() async {
    // 如果还没有加载过数据，先加载
    if (_userPosts.isEmpty && _userFavorites.isEmpty && !_isLoadingReferences) {
      await _loadUserPostsAndFavorites();
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('选择引用文献'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: '我的帖子'),
                      Tab(text: '我的收藏'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // 我的帖子标签页
                        _buildPostList(_userPosts, setState),
                        // 我的收藏标签页
                        _buildPostList(_userFavorites, setState),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                this.setState(() {}); // 刷新页面显示选中的引用
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }

  // 构建帖子列表
  Widget _buildPostList(List<Post> posts, StateSetter setState) {
    if (_isLoadingReferences) {
      return const Center(child: CircularProgressIndicator());
    }

    if (posts.isEmpty) {
      return const Center(child: Text('暂无内容'));
    }

    return ListView.builder(
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        final postId = int.tryParse(post.id) ?? 0;
        final isSelected = _selectedReferences.contains(postId);

        return ListTile(
          leading: Checkbox(
            value: isSelected,
            onChanged: (bool? value) {
              setState(() {
                final postId = int.tryParse(post.id) ?? 0;
                if (value == true) {
                  _selectedReferences.add(postId);
                } else {
                  _selectedReferences.remove(postId);
                }
              });
            },
          ),
          title: Text(post.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            '${post.author.name} · ${post.createdAt.year}-${post.createdAt.month.toString().padLeft(2, '0')}-${post.createdAt.day.toString().padLeft(2, '0')}',
            style: const TextStyle(fontSize: 12),
          ),
          onTap: () {
            // 点击文字区域时切换checkbox状态
            setState(() {
              final postId = int.tryParse(post.id) ?? 0;
              if (isSelected) {
                _selectedReferences.remove(postId);
              } else {
                _selectedReferences.add(postId);
              }
            });
          },
        );
      },
    );
  }

  // 引用文献输入区
  Widget _buildReferencesSection() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '引用文献',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _showReferenceSelector,
              icon: const Icon(Icons.library_books, size: 18),
              label: const Text('添加引用文献'),
              style: ElevatedButton.styleFrom(
                backgroundColor: scheme.surfaceVariant,
                foregroundColor: scheme.onSurface,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
            const SizedBox(width: 12),
            if (_selectedReferences.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '已选择 ${_selectedReferences.length} 篇',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
        if (_selectedReferences.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: scheme.outline.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '已选择的引用文献：',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                ..._selectedReferences.map((postId) {
                  // 从用户帖子和收藏中找到对应的帖子信息
                  final post = [..._userPosts, ..._userFavorites]
                      .where((p) => int.tryParse(p.id) == postId)
                      .cast<Post?>()
                      .firstWhere((p) => p != null, orElse: () => null);

                  if (post != null) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '[${_selectedReferences.indexOf(postId) + 1}] ${post.author.name}. ${post.title}. ${post.mainDiscipline}, ${post.createdAt.year}-${post.createdAt.month.toString().padLeft(2, '0')}-${post.createdAt.day.toString().padLeft(2, '0')}.',
                              style: TextStyle(fontSize: 12, color: scheme.onSurface),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _selectedReferences.remove(postId);
                              });
                            },
                            icon: const Icon(Icons.close, size: 16),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    );
                  } else {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '[${_selectedReferences.indexOf(postId) + 1}] 帖子ID: $postId (信息加载中...)',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _selectedReferences.remove(postId);
                              });
                            },
                            icon: const Icon(Icons.close, size: 16),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    );
                  }
                }),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
