part of '../post_detail_screen.dart';
// Mechanically extracted from post_detail_screen.dart

extension _PostDetailScreenStateContent on _PostDetailScreenState {

  Widget _buildAuthorRow() {
    // 如果是查看自己的帖子，不显示关注按钮
    if (_isFollowingAuthor == null) {
      return ListTile(
        onTap: () => _openUserProfile(widget.post.author.id),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: _buildAvatarWidget(widget.post.author.avatar, 20),
        title: Text(
          widget.post.author.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${widget.post.author.affiliation ?? ''} • ${_formatRelative(widget.post.createdAt)}',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );
    }

    final isFollowing = _isFollowingAuthor ?? false;

    return ListTile(
      onTap: () => _openUserProfile(widget.post.author.id),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: _buildAvatarWidget(widget.post.author.avatar, 20),
      title: Text(
        widget.post.author.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${widget.post.author.affiliation ?? ''} • ${_formatRelative(widget.post.createdAt)}',
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      trailing: ElevatedButton(
        onPressed: _followInFlight ? null : _toggleFollow,
        style: ElevatedButton.styleFrom(
          backgroundColor: isFollowing
              ? Colors.grey[300]
              : const Color(0xFF1976D2),
          foregroundColor: isFollowing ? Colors.grey[700] : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
        ),
        child: _followInFlight
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                isFollowing ? '已关注' : '+ 关注',
                style: const TextStyle(fontSize: 13),
              ),
      ),
    );
  }


  String _formatRelative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 4) return '刚刚';
    if (diff.inMinutes >= 4 && diff.inMinutes < 60)
      return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    return '${diff.inDays} 天前';
  }


  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 分区标签区域（点击可跳转到对应分区页）
          _buildDisciplineTagArea(),
          const SizedBox(height: 12),
          Text(
            //标题
            widget.post.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ContentWithClickableTags(
            content: widget.post.content,
            subTags: widget.post.subTags,
            onTagTap: _onTagTap,
          ),
          const SizedBox(height: 12),
          // arXiv 文献信息（如果有）
          if (_hasArxivMetadata()) _buildArxivMetadataSection(),
          const SizedBox(height: 10),
          // 引用文献（如果有）
          if (widget.post.references.isNotEmpty) _buildReferencesSection(),
          const SizedBox(height: 10),
          if (_pdfMedia.isNotEmpty) _buildPdfSection(),
          if (widget.post.attachments.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.post.attachments.map((att) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('打开 ${att.fileName}（演示）')),
                          );
                        },
                        icon: const Icon(Icons.picture_as_pdf),
                        label: Text(att.fileName),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        ' • ${(att.sizeBytes / 1024).toStringAsFixed(0)} KB',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 8),

          //外部链接列表
          if (widget.post.externalLinks.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '外部链接',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: widget.post.externalLinks.map((link) {
                    return InkWell(
                      onTap: () {
                        _openExternalLink(link);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          link,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),

          if (widget.post.doi != null)
            Text(
              'DOI: ${widget.post.doi}',
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
            ),
          if (widget.post.journal != null)
            Text(
              '${widget.post.journal}${widget.post.year != null ? ' · ${widget.post.year}' : ''}',
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
            ),
        ],
      ),
    );
  }


  Widget _buildArxivMetadataSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.post.arxivAuthors.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '作者：${widget.post.arxivAuthors.join(", ")}',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
            ),
          if (widget.post.arxivPublishedDate != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '发布日期：${widget.post.arxivPublishedDate}',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
            ),
          if (widget.post.arxivCategories.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '分类：${widget.post.arxivCategories.join(", ")}',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
            ),
          if (widget.post.arxivId != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'arXiv ID: ${widget.post.arxivId}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }


  Widget _buildReferencesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '引用文献',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ...widget.post.references.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final postId = entry.value;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: FutureBuilder<Map<String, dynamic>>(
              future: _fetchReferencePost(postId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '[$index] 加载中...',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  );
                } else if (snapshot.hasError || !snapshot.hasData) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      '[$index] 引用内容已不可见',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  );
                } else {
                  final refPost = snapshot.data!;
                  final title = refPost['title'] ?? '未知标题';
                  final authorName = refPost['author']?['name'] ?? '未知作者';
                  final discipline = refPost['mainDiscipline'] ?? '';
                  final createdAt = refPost['createdAt'];
                  String dateStr = '';
                  if (createdAt != null) {
                    try {
                      final date = DateTime.parse(createdAt);
                      dateStr =
                          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                    } catch (e) {
                      dateStr = '';
                    }
                  }

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: InkWell(
                      onTap: () => _navigateToReferencePost(postId),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.library_books,
                            size: 16,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '[$index] $authorName. $title. $discipline${dateStr.isNotEmpty ? ', $dateStr' : ''}.',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              },
            ),
          );
        }),
      ],
    );
  }


  Future<Map<String, dynamic>> _fetchReferencePost(int postId) async {
    // 先检查缓存
    if (_referencePostCache.containsKey(postId)) {
      return _referencePostCache[postId]!;
    }

    try {
      final resp = await ApiService.getPost(postId.toString());
      if (resp['statusCode'] == 200) {
        final postData = resp['body'];
        // 缓存数据
        _referencePostCache[postId] = postData;
        return postData;
      } else {
        throw Exception('无法获取引用帖子');
      }
    } catch (e) {
      throw e;
    }
  }


  void _navigateToReferencePost(int postId) async {
    try {
      final resp = await ApiService.getPost(postId.toString());
      if (resp['statusCode'] == 200) {
        final refPostData = resp['body'];
        final refPost = Post.fromJson(refPostData);

        // 导航到引用帖子详情页
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetailScreen(post: refPost),
          ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('引用内容已不可见')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法访问引用内容')));
    }
  }


  Widget _buildPdfSection() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PDF 附件',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        ..._pdfMedia.map(_buildPdfTile),
      ],
    );
  }


  Widget _buildPdfTile(String url) {
    final scheme = Theme.of(context).colorScheme;
    final fileName = _extractFileName(url);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: scheme.errorContainer.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.picture_as_pdf, color: scheme.error),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 只保留“下载”按钮，占满一行
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _downloadPdf(url),
              icon: const Icon(Icons.download_outlined),
              label: const Text('下载'),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: scheme.surface,
                foregroundColor: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }


  void _onTagTap(String tag) {
    // 跳转到搜索页面，搜索该标签相关的帖子
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SearchResultsScreen(query: '#$tag')),
    );
  }


  Widget _buildDisciplineTagArea() {
    final mainDiscipline = widget.post.mainDiscipline;
    if (mainDiscipline.isEmpty) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = kDisciplineColors[mainDiscipline] ?? Colors.blue;
    final bgColor = isDark ? color.withOpacity(0.22) : color.withOpacity(0.06);
    final borderColor = isDark
        ? color.withOpacity(0.85)
        : color.withOpacity(0.4);
    final labelColor = isDark ? scheme.onPrimary : color;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ZoneScreen(initialDiscipline: mainDiscipline),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1.1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_offer, size: 16, color: labelColor),
            const SizedBox(width: 6),
            Text(
              mainDiscipline,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: labelColor,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '· 点击查看该分区更多笔记',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? scheme.onSurfaceVariant : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }


  void _openPdfPreview(String url, String title) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showSnack('PDF 链接无效');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfPreviewScreen(url: uri.toString(), title: title),
        fullscreenDialog: true,
      ),
    );
  }


  Future<void> _downloadPdf(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showSnack('PDF 链接无效');
      return;
    }
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        _showSnack('无法打开下载链接');
      }
    } catch (_) {
      _showSnack('无法打开下载链接');
    }
  }


  bool _isPdf(String url) {
    if (url.isEmpty) return false;
    try {
      final uri = Uri.tryParse(url);
      final path = uri?.path.toLowerCase() ?? url.toLowerCase();
      // 主要检查：路径是否以 .pdf 结尾
      if (path.endsWith('.pdf')) return true;
      // 次要检查：URL 路径中包含 /pdf/ 或 /pdfs/ 等 PDF 专用路径
      if (path.contains('/pdf/') || path.contains('/pdfs/')) return true;
      // 检查查询参数中是否有 type=pdf 或 format=pdf
      final query = uri?.queryParameters;
      if (query != null) {
        final type =
            query['type']?.toLowerCase() ?? query['format']?.toLowerCase();
        if (type == 'pdf' || type == 'application/pdf') return true;
      }
      return false;
    } catch (_) {
      // 如果解析失败，回退到简单的字符串检查
      return url.toLowerCase().endsWith('.pdf');
    }
  }


  String _extractFileName(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.pathSegments.isNotEmpty) {
        final segment = uri.pathSegments.last;
        if (segment.isNotEmpty) return Uri.decodeComponent(segment);
      }
    } catch (_) {
      // ignore
    }
    final sanitized = url.split('?').first;
    final parts = sanitized.split('/');
    final fallback = parts.isNotEmpty ? parts.last : 'PDF 附件';
    return fallback.isEmpty ? 'PDF 附件' : fallback;
  }


}
