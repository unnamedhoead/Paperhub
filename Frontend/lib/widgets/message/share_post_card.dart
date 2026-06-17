/// 分享帖子卡片组件（独立组件，支持图片高度自适应）。
/// 由 ShareBubbleContent 在帖子详情加载完成后构建：渲染封面图、标题、作者与
/// 点赞/评论计数；封面图缺宽高信息时异步探测真实尺寸以计算高度。
import 'dart:async';
import 'package:flutter/material.dart';

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

    return (widget.cardWidth / aspect).clamp(150.0, 400.0);
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
