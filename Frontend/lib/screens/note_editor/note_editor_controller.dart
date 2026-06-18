// lib/screens/note_editor/note_editor_controller.dart
part of 'note_editor_screen.dart';

/// 上传文件类型枚举（Bug Fix 1：替换 String fileType 参数）
enum UploadFileType { image, pdf }

extension on _NoteEditorPageState {
  // 加载当前用户角色
  Future<void> _loadCurrentUserRole() async {
    try {
      // 尝试从API获取当前用户信息
      final response = await ApiService.getCurrentUserProfile();
      final status = response['statusCode'] as int? ?? 500;

      if (status >= 200 && status < 300) {
        final body = response['body'] as Map<String, dynamic>?;
        if (body != null) {
          final userProfile = UserProfile.fromJson(body);
          setState(() {
            _currentUserRole = userProfile.role.toUpperCase();
          });
          return;
        }
      }

      // 如果API调用失败，尝试从本地存储获取
      final userJson = LocalStorage.instance.read('currentUser');
      if (userJson != null) {
        try {
          final userData = jsonDecode(userJson) as Map<String, dynamic>;
          final userProfile = UserProfile.fromJson(userData);
          setState(() {
            _currentUserRole = userProfile.role.toUpperCase();
          });
          return;
        } catch (e) {
          print('解析本地用户数据失败: $e');
        }
      }

      // 如果都失败，设置为普通用户
      setState(() {
        _currentUserRole = 'USER';
      });
    } catch (e) {
      print('获取用户角色失败: $e');
      // 失败时设置为普通用户
      setState(() {
        _currentUserRole = 'USER';
      });
    }
    // 异步加载用户的帖子和收藏，用于引用文献选择
    // 不在initState中立即调用，而是在需要时调用，这样可以避免阻塞UI
  }

  // 将已有帖子内容灌入编辑器（编辑模式）
  void _applyExistingPost(Post post) {
    // 标题 & 正文
    _titleController.text = post.title;
    _contentController.text = post.content;

    // 关键：恢复原来的分区
    _selectedDiscipline = post.mainDiscipline;

    // 已有媒体：区分图片和 PDF
    _existingImageUrls.clear();
    _existingPdfUrl = null;
    if (post.media.isNotEmpty) {
      for (final m in post.media) {
        if (m.isEmpty) continue;
        if (_isPdfUrl(m)) {
          // 只用第一份 PDF
          _existingPdfUrl ??= m;
        } else {
          _existingImageUrls.add(m);
        }
      }
    }

    // 外部链接
    _externalLinks
      ..clear()
      ..addAll(post.externalLinks);

    // 文献信息 / arXiv
    _arxivId = post.arxivId;
    _doi = post.doi;
    _journal = post.journal;
    _year = post.year;

    if (post.arxivId != null && post.arxivId!.isNotEmpty) {
      _arxivController.text = post.arxivId!;
      _arxivMetadata = ArxivMetadata(
        id: post.arxivId!,
        title: post.title,
        authors: post.arxivAuthors,
        abstract: null,
        publishedDate: post.arxivPublishedDate != null
            ? DateTime.tryParse(post.arxivPublishedDate!)
            : null,
        updatedDate: null,
        categories: post.arxivCategories,
        doi: post.doi,
        journal: post.journal,
        year: post.year,
      );
    }

    // 预填充引用文献
    _selectedReferences = List.from(post.references);
  }

  // 上传图片或 PDF 到后端，返回 URL
  // Bug Fix 1：fileType 参数从 String 改为 UploadFileType 枚举
  Future<String?> _uploadFileToServer(XFile file, UploadFileType fileType) async {
    try {
      final uri = Uri.parse('${AppEnv.apiBaseUrl}/posts/upload');
      final request = http.MultipartRequest('POST', uri);

      if (fileType == UploadFileType.image) {
        if (kIsWeb) {
          final bytes = await file.readAsBytes();
          request.files.add(
            http.MultipartFile.fromBytes(
              'file',
              bytes,
              filename: file.name,
              contentType: MediaType(
                'image',
                file.mimeType?.split('/').last ?? 'jpeg',
              ),
            ),
          );
        } else {
          request.files.add(
            await http.MultipartFile.fromPath('file', file.path),
          );
        }
      } else if (fileType == UploadFileType.pdf) {
        if (kIsWeb) {
          final bytes = await file.readAsBytes();
          request.files.add(
            http.MultipartFile.fromBytes(
              'file',
              bytes,
              filename: file.name,
              contentType: MediaType('application', 'pdf'),
            ),
          );
        } else {
          request.files.add(
            await http.MultipartFile.fromPath('file', file.path),
          );
        }
      } else {
        print('不支持的文件类型');
        return null;
      }

      final response = await request.send();
      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        final data = jsonDecode(respStr) as Map<String, dynamic>;
        return data['url'] as String?;
      } else {
        print('上传失败: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('上传文件失败: $e');
      return null;
    }
  }

  // 发布 / 编辑 笔记
  Future<void> _publishNote({
    String? statusOverride,
    String? customSuccessMessage,
  }) async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    // 不允许为空的内容
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入标题')));
      return;
    }
    if (content.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入正文')));
      return;
    }
    // 只有"新建笔记"强制要求必须选择图片；编辑时可以只改文字 / 链接
    if (!_isEditing && _images.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请添加图片')));
      return;
    }
    if (_selectedDiscipline == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请选择一个学科分区')));
      return;
    }

    // 显示加载中
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 从正文中提取#标签
      final textTags = _extractTagsFromText(content);

      // 组装标签：至少包含一个主分区，加上正文中的所有#标签
      final List<String> tags = [
        _selectedDiscipline!,
        ...textTags,
      ].toSet().toList();

      List<String> mediaUrls = [];

      // 往里面加已有的图片 URL
      mediaUrls.addAll(_existingImageUrls);

      // 如果你还有别的要加，比如新选的图片 / pdf，就继续：
      // if (_existingPdfUrl != null) {
      //   mediaUrls.add(_existingPdfUrl!);
      // }

      // 2) 上传新选择的图片
      for (var img in _images) {
        final url = await _uploadFileToServer(img, UploadFileType.image);
        if (url != null) mediaUrls.add(url);
      }

      // 3) 处理 PDF：优先使用新选择的 PDF，其次沿用旧的 URL
      String? pdfUrlToUse;
      if (_pdfFile != null) {
        XFile pdfXFile;
        if (kIsWeb) {
          if (_pdfFileBytes == null) {
            if (mounted) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('PDF 文件数据异常，请重新选择')));
            }
            return;
          }
          pdfXFile = XFile.fromData(
            _pdfFileBytes!,
            name: _pdfFileName ?? 'document.pdf',
            mimeType: 'application/pdf',
          );
        } else {
          pdfXFile = XFile(_pdfFile!.path);
        }
        pdfUrlToUse = await _uploadFileToServer(pdfXFile, UploadFileType.pdf);
      } else if (_existingPdfUrl != null) {
        pdfUrlToUse = _existingPdfUrl;
      }

      if (pdfUrlToUse != null) {
        mediaUrls.add(pdfUrlToUse);
      }

      // 4) 外部链接（过滤空字符串）
      final links = _externalLinks.where((e) => e.trim().isNotEmpty).toList();

      // 5) arXiv 相关
      final String? arxivPublishedDate = _arxivMetadata?.publishedDateFormatted;
      final List<String>? arxivAuthors = _arxivMetadata?.authors;
      final List<String>? arxivCategories = _arxivMetadata?.categories;

      // 6) 调用后端接口：新建 or 更新
      final String? normalizedStatus = statusOverride != null
          ? statusOverride.toUpperCase()
          : null;

      Map<String, dynamic> resp;
      if (_isEditing && widget.initialPost != null) {
        // === 编辑已有帖子 ===
        resp = await ApiService.updatePost(
          postId: widget.initialPost!.id,
          title: title,
          content: content.isNotEmpty ? content : null,
          media: mediaUrls,
          mainDiscipline: _selectedDiscipline!,
          doi: _doi,
          journal: _journal,
          year: _year,
          externalLinks: links.isNotEmpty ? links : null,
          arxivId: _arxivId,
          arxivAuthors: arxivAuthors,
          arxivPublishedDate: arxivPublishedDate,
          arxivCategories: arxivCategories,
          references: _selectedReferences.isNotEmpty
              ? _selectedReferences
              : null,
          status: normalizedStatus,
        );
      } else {
        // === 新建帖子 ===
        resp = await ApiService.createPost(
          title: title,
          content: content.isNotEmpty ? content : null,
          media: mediaUrls.isNotEmpty ? mediaUrls : null,
          mainDiscipline: _selectedDiscipline!,
          doi: _doi,
          journal: _journal,
          year: _year,
          externalLinks: links.isNotEmpty ? links : null,
          arxivId: _arxivId,
          arxivAuthors: arxivAuthors,
          arxivPublishedDate: arxivPublishedDate,
          arxivCategories: arxivCategories,
          references: _selectedReferences.isNotEmpty
              ? _selectedReferences
              : null,
          status: normalizedStatus,
        );
      }

      // 关闭加载对话框
      if (mounted) Navigator.of(context).pop();

      final status = resp['statusCode'] as int? ?? 500;
      final body = resp['body'] as Map<String, dynamic>?;

      if (status >= 200 && status < 300) {
        if (mounted) {
          Post? createdPost;
          Map<String, dynamic>? createdPostRaw;
          // 尝试从响应体解析新建的帖子，并缓存原始 JSON 以便首页置顶显示
          if (!_isEditing && body != null) {
            final raw = body['post'] ?? body;
            if (raw is Map<String, dynamic>) {
              createdPostRaw = raw;
              createdPost = Post.fromJson(raw);
            }
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                customSuccessMessage ?? (_isEditing ? '笔记已更新' : '发布成功'),
              ),
            ),
          );

          if (_isEditing) {
            // 编辑模式：仍然返回上一页，由上一页决定是否刷新
            // Bug Fix 2: Navigator after pop is already guarded by mounted check
            Navigator.of(context).pop(createdPost ?? true);
          } else {
            // 新建笔记：无论从哪个页面进入，统一跳转到首页，
            // 并通过本地存储把新帖子传递给首页，用于临时置顶展示
            if (createdPostRaw != null) {
              try {
                LocalStorage.instance
                    .write('lastCreatedPost', jsonEncode(createdPostRaw));
              } catch (e) {
                print('缓存新建帖子到本地失败: $e');
              }
            }

            // Bug Fix 2: Navigator.of(context).pushNamedAndRemoveUntil
            // is already inside if (mounted) block from line above
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/home',
              (route) => false,
            );
          }
        }
      } else {
        final msg = body != null && body['message'] != null
            ? body['message'].toString()
            : (_isEditing ? '保存失败' : '发布失败');
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditing ? '保存失败，网络错误' : '发布失败，网络错误')),
        );
      }
    }
  }

  // 从 arXiv 获取文献元数据
  Future<void> _fetchArxivMetadata() async {
    final input = _arxivController.text.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入 arXiv ID 或链接')));
      return;
    }

    setState(() {
      _isLoadingArxiv = true;
    });

    try {
      final metadata = await ArxivService.fetchMetadata(input);

      if (!mounted) return;

      setState(() {
        _arxivMetadata = metadata;
        _arxivId = metadata.id;

        // 自动填充标题（如果为空）
        if (_titleController.text.trim().isEmpty) {
          _titleController.text = metadata.title;
        }

        // 填充元数据
        _doi = metadata.doi;
        _journal = metadata.journal;
        _year = metadata.yearFormatted;

        // 如果摘要存在且内容为空，可以添加到内容中
        if (metadata.abstract != null &&
            _contentController.text.trim().isEmpty) {
          _contentController.text = '摘要：${metadata.abstract}';
        }
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('成功获取文献信息：${metadata.title}'),
          backgroundColor: Colors.green,
        ),
      );
    } on ArxivException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      if (!mounted) return;
      setState(() {
        _arxivMetadata = null;
        _arxivId = null;
        _doi = null;
        _journal = null;
        _year = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('获取文献信息失败：${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      if (!mounted) return;
      setState(() {
        _arxivMetadata = null;
        _arxivId = null;
        _doi = null;
        _journal = null;
        _year = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingArxiv = false;
        });
      }
    }
  }

  // 清除 arXiv 信息
  void _clearArxivMetadata() {
    setState(() {
      _arxivController.clear();
      _arxivMetadata = null;
      _arxivId = null;
      _doi = null;
      _journal = null;
      _year = null;
    });
  }

  Widget _buildAdminFeedbackBanner(String reason) {
    final displayReason = reason.trim().isEmpty ? '管理员未提供具体原因' : reason.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFCC80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.info_outline, color: Color(0xFFF57C00), size: 18),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  '管理员退回说明',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFF57C00),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            displayReason,
            style: const TextStyle(fontSize: 13, color: Color(0xFF5D4037)),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions({
    required bool isDraft,
    required bool isAdminRejectedDraft,
  }) {
    if (!_isEditing) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => _publishNote(),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1976D2),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            '发布笔记',
            style: TextStyle(fontSize: 16, color: Colors.white),
          ),
        ),
      );
    }

    final String secondButtonLabel = isAdminRejectedDraft ? '保存并提交审核' : '保存并发布';
    final String secondButtonStatus = isAdminRejectedDraft ? 'AUDIT' : 'NORMAL';
    final String secondButtonSuccess = isAdminRejectedDraft ? '已提交审核' : '发布成功';

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => _publishNote(
              statusOverride: 'DRAFT',
              customSuccessMessage: '已保存为草稿',
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              foregroundColor: const Color(0xFF1976D2),
              side: const BorderSide(color: Color(0xFF1976D2)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('保存为草稿', style: TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () => _publishNote(
              statusOverride: secondButtonStatus,
              customSuccessMessage: secondButtonSuccess,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              secondButtonLabel,
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
