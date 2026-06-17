/// 分享帖子消息气泡内容组件
///
/// SHARE 类型的 content 存储的是 post ID，通过 FutureBuilder 异步加载帖子详情并渲染卡片。
import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/message_model.dart';
import '../../models/post_model.dart';
import '../../screens/post_detail_screen.dart';
import '../../services/api_service.dart';
import 'text_bubble.dart';

class ShareBubbleContent extends StatelessWidget {
  /// 缓存帖子详情的 Future，避免反复加载
  static final Map<String, Future<Map<String, dynamic>>> postCache = {};

  final Message message;

  const ShareBubbleContent({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final postId = message.content;
    if (postId.isEmpty) {
      return TextBubbleContent(message: message);
    }

    if (!postCache.containsKey(postId)) {
      postCache[postId] = _loadPostDetails(postId);
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: postCache[postId],
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard(context);
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _buildErrorCard();
        }

        final post = snapshot.data!;
        final title = post['title']?.toString() ?? '无标题';
        final authorName =
            post['author']?['name']?.toString() ?? '未知用户';
        final authorAvatar = post['author']?['avatar']?.toString();
        final media = post['media'] as List<dynamic>?;
        final firstImage =
            media != null && media.isNotEmpty ? media[0].toString() : null;
        final likesCount =
            (post['likesCount'] as num?)?.toInt() ?? 0;
        final commentsCount =
            (post['commentsCount'] as num?)?.toInt() ?? 0;
        final imageAspectRatio =
            (post['imageAspectRatio'] as num?)?.toDouble();
        final imageNaturalWidth =
            (post['imageNaturalWidth'] as num?)?.toDouble();
        final imageNaturalHeight =
            (post['imageNaturalHeight'] as num?)?.toDouble();

        return GestureDetector(
          onTap: () => _navigateToPost(context, postId),
          child: SharePostCard(
            cardWidth:
                (MediaQuery.of(context).size.width * 0.75).clamp(200.0, 280.0),
            title: title,
            authorName: authorName,
            authorAvatar: authorAvatar,
            firstImage: firstImage,
            likesCount: likesCount,
            commentsCount: commentsCount,
            imageAspectRatio: imageAspectRatio,
            imageNaturalWidth: imageNaturalWidth,
            imageNaturalHeight: imageNaturalHeight,
          ),
        );
      },
    );
  }

  Widget _buildLoadingCard(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 0.5),
      ),
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 0.5),
      ),
      child: const Center(
        child: Text('加载帖子失败', style: TextStyle(color: Colors.grey)),
      ),
    );
  }

  Future<void> _navigateToPost(BuildContext context, String postId) async {
    try {
      final result = await ApiService.getPost(postId);
      if (result['statusCode'] == 200) {
        final postData = result['body'] as Map<String, dynamic>;
        final postObj = Post.fromJson(postData);

        final status = postObj.status?.toUpperCase();
        if (status != null && status != 'NORMAL') {
          String message;
          switch (status) {
            case 'DRAFT':
              message = '该笔记目前不可见';
              break;
            case 'AUDIT':
              message = '该笔记正在审核中，暂不可见';
              break;
            case 'REMOVED':
              message = '该笔记已被下架，不可见';
              break;
            default:
              message = '该笔记目前不可见';
          }
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
            );
          }
          return;
        }

        if (context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PostDetailScreen(post: postObj),
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    '获取帖子详情失败: ${result['body']['message'] ?? '未知错误'}')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('获取帖子详情失败: $e')),
        );
      }
    }
  }

  Future<Map<String, dynamic>> _loadPostDetails(String postId) async {
    try {
      final result = await ApiService.getPost(postId);
      if (result['statusCode'] == 200 && result['body'] != null) {
        final body = result['body'] as Map<String, dynamic>?;
        if (body != null && body.isNotEmpty) {
          return body;
        } else {
          throw Exception('服务器返回空响应体');
        }
      } else {
        throw Exception(result['body']?['message'] ?? '获取帖子失败');
      }
    } catch (e) {
      postCache.remove(postId);
      rethrow;
    }
  }
}

/// 分享帖子卡片组件（独立组件，支持图片高度自适应）
class SharePostCard extends StatefulWidget {
  final double cardWidth;
  final String title;
  final String authorName;
  final String? authorAvatar;
  final String? firstImage;
  final int likesCount;
  final int commentsCount;
  final double? imageAspectRatio;
  final double? imageNaturalWidth;
  final double? imageNaturalHeight;

  const SharePostCard({
    Key? key,
    required this.cardWidth,
    required this.title,
    required this.authorName,
    this.authorAvatar,
    this.firstImage,
    required this.likesCount,
    required this.commentsCount,
    this.imageAspectRatio,
    this.imageNaturalWidth,
    this.imageNaturalHeight,
  }) : super(key: key);

  @override
  State<SharePostCard> createState() => _SharePostCardState();
}

class _SharePostCardState extends State<SharePostCard> {
  double? _actualImageWidth;
  double? _actualImageHeight;
  bool _isLoadingImageSize = false;

  @override
  void initState() {
    super.initState();
    if (widget.firstImage != null &&
        (widget.imageAspectRatio == null || widget.imageAspectRatio == 0) &&
        (widget.imageNaturalWidth == null || widget.imageNaturalWidth == 0)) {
      _loadImageSize();
    }
  }

  Future<void> _loadImageSize() async {
    if (_isLoadingImageSize || widget.firstImage == null) return;
    setState(() {
      _isLoadingImageSize = true;
    });

    try {
      final imageProvider = NetworkImage(widget.firstImage!);
      final ImageStream stream =
          imageProvider.resolve(const ImageConfiguration());
      final Completer<void> completer = Completer<void>();

      late ImageStreamListener listener;
      listener = ImageStreamListener((ImageInfo info, bool synchronousCall) {
        if (!mounted) return;
        final image = info.image;
        setState(() {
          _actualImageWidth = image.width.toDouble();
          _actualImageHeight = image.height.toDouble();
          _isLoadingImageSize = false;
        });
        stream.removeListener(listener);
        if (!completer.isCompleted) {
          completer.complete();
        }
      }, onError: (exception, stackTrace) {
        stream.removeListener(listener);
        if (!completer.isCompleted) {
          completer.complete();
        }
        if (mounted) {
          setState(() {
            _isLoadingImageSize = false;
          });
        }
      });

      stream.addListener(listener);
      await completer.future;
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingImageSize = false;
        });
      }
    }
  }

  double _calculateImageHeight() {
    if (widget.firstImage == null) return 120.0;

    double aspect = 1.5;
    if (_actualImageWidth != null &&
        _actualImageHeight != null &&
        _actualImageWidth! > 0 &&
        _actualImageHeight! > 0) {
      aspect = _actualImageWidth! / _actualImageHeight!;
    } else if (widget.imageAspectRatio != null &&
        widget.imageAspectRatio! > 0) {
      aspect = widget.imageAspectRatio!;
    } else if (widget.imageNaturalWidth != null &&
        widget.imageNaturalHeight != null &&
        widget.imageNaturalWidth! > 0 &&
        widget.imageNaturalHeight! > 0) {
      aspect = widget.imageNaturalWidth! / widget.imageNaturalHeight!;
    }

    final calculatedHeight = widget.cardWidth / aspect;
    return calculatedHeight.clamp(150.0, 400.0);
  }

  @override
  Widget build(BuildContext context) {
    final imageHeight = _calculateImageHeight();

    return Container(
      width: widget.cardWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.firstImage != null)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: Container(
                width: widget.cardWidth,
                height: imageHeight,
                color: Colors.grey[100],
                child: Image.network(
                  widget.firstImage!,
                  width: widget.cardWidth,
                  height: imageHeight,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      width: widget.cardWidth,
                      height: imageHeight,
                      color: Colors.grey[100],
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: widget.cardWidth,
                      height: imageHeight,
                      color: Colors.grey[100],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image_outlined,
                              size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            '图片加载失败',
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            )
          else
            Container(
              width: widget.cardWidth,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Center(
                child: Icon(Icons.article_outlined,
                    size: 48, color: Colors.grey[400]),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.grey[300],
                      child: widget.authorAvatar != null &&
                              widget.authorAvatar!.isNotEmpty
                          ? ClipOval(
                              child: Image.network(
                                widget.authorAvatar!,
                                width: 24,
                                height: 24,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.person,
                                      size: 16, color: Colors.grey);
                                },
                              ),
                            )
                          : const Icon(Icons.person,
                              size: 16, color: Colors.grey),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.authorName,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[700]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.likesCount > 0 || widget.commentsCount > 0) ...[
                      Icon(Icons.favorite_outline,
                          size: 12, color: Colors.grey[500]),
                      const SizedBox(width: 2),
                      Text(
                        _formatCount(widget.likesCount),
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.comment_outlined,
                          size: 12, color: Colors.grey[500]),
                      const SizedBox(width: 2),
                      Text(
                        _formatCount(widget.commentsCount),
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count < 1000) {
      return count.toString();
    } else if (count < 10000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    } else {
      return '${(count / 10000).toStringAsFixed(1)}w';
    }
  }
}
