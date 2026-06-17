import 'package:flutter/material.dart';
import '../../models/post_model.dart';
import '../../constants/discipline_constants.dart';
import '../../widgets/content_with_clickable_tags.dart';
import '../zone_screen.dart';

// ===== 顶层工具函数 =====

String _formatRelative(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 4) return '刚刚';
  if (diff.inMinutes >= 4 && diff.inMinutes < 60)
    return '${diff.inMinutes} 分钟前';
  if (diff.inHours < 24) return '${diff.inHours} 小时前';
  return '${diff.inDays} 天前';
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

Widget _buildAvatarWidget(String avatarPath, double radius) {
  // 判断是否为网络 URL（以 http:// 或 https:// 开头）
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
          errorBuilder: (context, error, stackTrace) {
            return Icon(Icons.person, size: radius, color: Colors.grey);
          },
        ),
      ),
    );
  }

  // 处理本地资源路径
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
        errorBuilder: (context, error, stackTrace) {
          return Icon(Icons.person, size: radius, color: Colors.grey);
        },
      ),
    ),
  );
}

// ===== PostContentView Widget =====

/// 帖子详情页内容区：作者行 + 正文 + 元数据 + 引用 + PDF
class PostContentView extends StatelessWidget {
  final Post post;
  final bool? isFollowingAuthor;
  final bool followInFlight;
  final List<String> pdfMedia;
  final VoidCallback onAuthorTap;
  final VoidCallback onToggleFollow;
  final void Function(String tag) onTagTap;
  final void Function(String url, String title) onOpenPdfPreview;
  final void Function(String url) onDownloadPdf;
  final void Function(String url) onOpenExternalLink;
  final Future<Map<String, dynamic>> Function(int postId) onFetchReferencePost;
  final void Function(int postId) onNavigateToReferencePost;

  const PostContentView({
    super.key,
    required this.post,
    required this.isFollowingAuthor,
    required this.followInFlight,
    required this.pdfMedia,
    required this.onAuthorTap,
    required this.onToggleFollow,
    required this.onTagTap,
    required this.onOpenPdfPreview,
    required this.onDownloadPdf,
    required this.onOpenExternalLink,
    required this.onFetchReferencePost,
    required this.onNavigateToReferencePost,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAuthorRow(context),
        _buildContent(context),
      ],
    );
  }

  bool _hasArxivMetadata() {
    return post.arxivId != null &&
        (post.arxivAuthors.isNotEmpty ||
            post.arxivPublishedDate != null ||
            post.arxivCategories.isNotEmpty);
  }

  Widget _buildAuthorRow(BuildContext context) {
    if (isFollowingAuthor == null) {
      return ListTile(
        onTap: onAuthorTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: _buildAvatarWidget(post.author.avatar, 20),
        title: Text(
          post.author.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${post.author.affiliation ?? ''} • ${_formatRelative(post.createdAt)}',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );
    }

    final isFollowing = isFollowingAuthor ?? false;

    return ListTile(
      onTap: onAuthorTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: _buildAvatarWidget(post.author.avatar, 20),
      title: Text(
        post.author.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${post.author.affiliation ?? ''} • ${_formatRelative(post.createdAt)}',
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      trailing: ElevatedButton(
        onPressed: followInFlight ? null : onToggleFollow,
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
        child: followInFlight
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

  Widget _buildContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDisciplineTagArea(context),
          const SizedBox(height: 12),
          Text(
            post.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ContentWithClickableTags(
            content: post.content,
            subTags: post.subTags,
            onTagTap: onTagTap,
          ),
          const SizedBox(height: 12),
          if (_hasArxivMetadata()) _buildArxivMetadataSection(),
          const SizedBox(height: 10),
          if (post.references.isNotEmpty)
            _buildReferencesSection(context),
          const SizedBox(height: 10),
          if (pdfMedia.isNotEmpty) _buildPdfSection(context),
          if (post.attachments.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: post.attachments.map((att) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content:
                                    Text('打开 ${att.fileName}（演示）')),
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
          if (post.externalLinks.isNotEmpty)
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
                  children: post.externalLinks.map((link) {
                    return InkWell(
                      onTap: () {
                        onOpenExternalLink(link);
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
          if (post.doi != null)
            Text(
              'DOI: ${post.doi}',
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
            ),
          if (post.journal != null)
            Text(
              '${post.journal}${post.year != null ? ' · ${post.year}' : ''}',
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
          if (post.arxivAuthors.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '作者：${post.arxivAuthors.join(", ")}',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
            ),
          if (post.arxivPublishedDate != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '发布日期：${post.arxivPublishedDate}',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
            ),
          if (post.arxivCategories.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '分类：${post.arxivCategories.join(", ")}',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
            ),
          if (post.arxivId != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'arXiv ID: ${post.arxivId}',
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

  Widget _buildReferencesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '引用文献',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ...post.references.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final postId = entry.value;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: FutureBuilder<Map<String, dynamic>>(
              future: onFetchReferencePost(postId),
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
                      style:
                          const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  );
                } else {
                  final refPost = snapshot.data!;
                  final title = refPost['title'] ?? '未知标题';
                  final authorName =
                      refPost['author']?['name'] ?? '未知作者';
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
                      onTap: () => onNavigateToReferencePost(postId),
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

  Widget _buildPdfSection(BuildContext context) {
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
        ...pdfMedia.map((url) => _buildPdfTile(context, url)),
      ],
    );
  }

  Widget _buildPdfTile(BuildContext context, String url) {
    final scheme = Theme.of(context).colorScheme;
    final fileName = _extractFileName(url);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
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
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => onDownloadPdf(url),
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

  Widget _buildDisciplineTagArea(BuildContext context) {
    final mainDiscipline = post.mainDiscipline;
    if (mainDiscipline.isEmpty) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = kDisciplineColors[mainDiscipline] ?? Colors.blue;
    final bgColor =
        isDark ? color.withOpacity(0.22) : color.withOpacity(0.06);
    final borderColor =
        isDark ? color.withOpacity(0.85) : color.withOpacity(0.4);
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
}
