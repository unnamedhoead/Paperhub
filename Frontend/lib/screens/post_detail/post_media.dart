part of '../post_detail_screen.dart';
// Mechanically extracted from post_detail_screen.dart

extension _PostDetailScreenStateMedia on _PostDetailScreenState {

  Future<void> _openExternalLink(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('链接为空')));
      return;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('无法识别的链接：$trimmed')));
      return;
    }

    if (!await canLaunchUrl(uri)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('当前环境无法打开链接：$trimmed')));
      return;
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }


  List<String> get _imageMedia =>
      widget.post.media.where((m) => !_isPdf(m)).toList();

  List<String> get _pdfMedia => widget.post.media.where(_isPdf).toList();
  bool get _isOwner =>
      _currentUserId != null && widget.post.author.id == _currentUserId;

  // 检查是否有 arXiv 元数据
  bool _hasArxivMetadata() {
    return widget.post.arxivId != null &&
        (widget.post.arxivAuthors.isNotEmpty ||
            widget.post.arxivPublishedDate != null ||
            widget.post.arxivCategories.isNotEmpty);
  }


  Future<void> _loadImageSize() async {
    if (_isLoadingImageSize || _imageMedia.isEmpty) return;

    setState(() {
      _isLoadingImageSize = true;
    });

    try {
      final imageUrl = _imageMedia.first;
      final imageProvider = NetworkImage(imageUrl);

      // 使用 ImageProvider.resolve 获取图片信息
      final ImageStream stream = imageProvider.resolve(
        const ImageConfiguration(),
      );
      final Completer<void> completer = Completer<void>();

      ImageStreamListener? listener;
      listener = ImageStreamListener(
        (ImageInfo info, bool synchronousCall) {
          if (!mounted) return;

          final image = info.image;
          setState(() {
            _actualImageWidth = image.width.toDouble();
            _actualImageHeight = image.height.toDouble();
            _isLoadingImageSize = false;
          });

          stream.removeListener(listener!);
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        onError: (exception, stackTrace) {
          stream.removeListener(listener!);
          if (!completer.isCompleted) {
            completer.complete();
          }
          if (mounted) {
            setState(() {
              _isLoadingImageSize = false;
            });
          }
        },
      );

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


  void _toggleImageFullscreen() {
    setState(() {
      _isImageFullscreen = !_isImageFullscreen;
    });
  }


  void _handleImageHover(bool isHovering) {
    if (!kIsWeb) return;
    if (_isHoveringImage != isHovering) {
      setState(() {
        _isHoveringImage = isHovering;
      });
    }
  }


  void _goToNextImage() {
    final images = _imageMedia;
    if (images.length <= 1) return;
    final nextIndex = (_currentImageIndex + 1).clamp(0, images.length - 1);
    _imagePageController.animateToPage(
      nextIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }


  void _goToPreviousImage() {
    final images = _imageMedia;
    if (images.length <= 1) return;
    final prevIndex = (_currentImageIndex - 1).clamp(0, images.length - 1);
    _imagePageController.animateToPage(
      prevIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  /// 从后端加载帖子详情


  Widget _buildMediaGallery() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;

        // 计算图片宽高比：优先使用实际加载的图片尺寸，然后是后端返回的尺寸，最后是 imageAspectRatio
        double ratio = 1.5;
        if (_imageMedia.isNotEmpty) {
          // 优先使用实际加载的图片尺寸（如果已加载）
          if (_actualImageWidth != null &&
              _actualImageHeight != null &&
              _actualImageWidth! > 0 &&
              _actualImageHeight! > 0) {
            ratio = _actualImageWidth! / _actualImageHeight!;
          }
          // 否则使用后端返回的尺寸（如果看起来不是默认值）
          else if (widget.post.imageNaturalWidth > 0 &&
              widget.post.imageNaturalHeight > 0 &&
              !(widget.post.imageNaturalWidth == 800.0 &&
                  widget.post.imageNaturalHeight == 600.0)) {
            ratio =
                widget.post.imageNaturalWidth / widget.post.imageNaturalHeight;
          }
          // 最后使用 imageAspectRatio
          else if (widget.post.imageAspectRatio > 0) {
            ratio = widget.post.imageAspectRatio;
          }
        }

        // 计算如果宽度填满屏幕时的高度
        final calculatedHeight = screenWidth / ratio;

        // 判断是否需要限制高度
        final bool needsHeightLimit = calculatedHeight > 450;
        final double containerHeight = needsHeightLimit
            ? 450.0
            : calculatedHeight;
        final double containerWidth = needsHeightLimit
            ? (450.0 * ratio)
            : screenWidth;

        final images = _imageMedia;
        if (images.isEmpty) {
          return Container(
            height: 220,
            color: Colors.grey[200],
            child: const Center(
              child: Icon(
                Icons.image_not_supported,
                size: 48,
                color: Colors.grey,
              ),
            ),
          );
        }

        return MouseRegion(
          onEnter: (_) => _handleImageHover(true),
          onExit: (_) => _handleImageHover(false),
          child: GestureDetector(
            onDoubleTap: _toggleLike,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (needsHeightLimit)
                  Center(
                    child: SizedBox(
                      width: containerWidth,
                      height: containerHeight,
                      child: PageView.builder(
                        controller: _imagePageController,
                        itemCount: images.length,
                        onPageChanged: (index) {
                          if (_currentImageIndex != index) {
                            setState(() {
                              _currentImageIndex = index;
                            });
                          }
                        },
                        itemBuilder: (_, index) {
                          return GestureDetector(
                            onTap: _toggleImageFullscreen,
                            child: _buildImageDisplay(
                              images[index],
                              containerWidth,
                              containerHeight,
                              BoxFit.cover,
                            ),
                          );
                        },
                      ),
                    ),
                  )
                else
                  SizedBox(
                    width: screenWidth,
                    height: containerHeight,
                    child: PageView.builder(
                      controller: _imagePageController,
                      itemCount: images.length,
                      onPageChanged: (index) {
                        if (_currentImageIndex != index) {
                          setState(() {
                            _currentImageIndex = index;
                          });
                        }
                      },
                      itemBuilder: (_, index) {
                        return GestureDetector(
                          onTap: _toggleImageFullscreen,
                          child: _buildImageDisplay(
                            images[index],
                            screenWidth,
                            containerHeight,
                            BoxFit.cover,
                          ),
                        );
                      },
                    ),
                  ),
                if (kIsWeb && images.length > 1 && _isHoveringImage)
                  Positioned(
                    left: 16,
                    child: _buildImageNavButton(
                      icon: Icons.chevron_left,
                      onTap: _goToPreviousImage,
                      enabled: _currentImageIndex > 0,
                    ),
                  ),
                if (kIsWeb && images.length > 1 && _isHoveringImage)
                  Positioned(
                    right: 16,
                    child: _buildImageNavButton(
                      icon: Icons.chevron_right,
                      onTap: _goToNextImage,
                      enabled: _currentImageIndex < images.length - 1,
                    ),
                  ),
                // 喜欢动画
                Positioned(
                  child: _showBigHeart
                      ? ScaleTransition(
                          scale: _heartScale,
                          child: const Icon(
                            Icons.favorite,
                            color: Colors.redAccent,
                            size: 100,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  Widget _buildImageDisplay(
    String path,
    double width,
    double height,
    BoxFit fit,
  ) {
    final placeholder = Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: const Center(
        child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
      ),
    );

    if (path.startsWith('http')) {
      return Image.network(
        path,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => placeholder,
      );
    }

    return Image.file(
      File(path),
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => placeholder,
    );
  }


  Widget _buildImageNavButton({
    required IconData icon,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.35,
      child: Material(
        color: Colors.black45,
        shape: const CircleBorder(),
        child: IconButton(
          icon: Icon(icon, color: Colors.white),
          onPressed: enabled ? onTap : null,
        ),
      ),
    );
  }


  Widget _buildRemovedWarning() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.red.shade700,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '该笔记已被管理员下架，仅作者可见',
                  style: TextStyle(
                    color: Colors.red.shade900,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (widget.post.hiddenReason != null &&
                    widget.post.hiddenReason!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '原因：${widget.post.hiddenReason}',
                      style: TextStyle(
                        color: Colors.red.shade800,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildPostUnavailableView() {
    String message;
    IconData icon;
    Color color;

    final status =
        _currentPostStatus?.toUpperCase() ?? widget.post.status?.toUpperCase();
    switch (status) {
      case 'DRAFT':
        message = '该笔记目前为草稿状态，不可见';
        icon = Icons.edit_note;
        color = Colors.orange;
        break;
      case 'AUDIT':
        message = '该笔记正在审核中，暂不可见';
        icon = Icons.hourglass_empty;
        color = Colors.blue;
        break;
      case 'REMOVED':
        message = '该笔记已被下架，不可见';
        icon = Icons.block;
        color = Colors.red;
        break;
      default:
        message = '该笔记目前不可见';
        icon = Icons.visibility_off;
        color = Colors.grey;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: color),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            if (widget.post.hiddenReason != null &&
                widget.post.hiddenReason!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '原因：${widget.post.hiddenReason}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }


  Widget _buildFullscreenOverlay() {
    final images = _imageMedia;
    if (!_isImageFullscreen || images.isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.95),
        child: SafeArea(
          child: GestureDetector(
            onTap: _toggleImageFullscreen,
            child: Stack(
              children: [
                PageView.builder(
                  controller: _imagePageController,
                  itemCount: images.length,
                  onPageChanged: (index) {
                    if (_currentImageIndex != index) {
                      setState(() {
                        _currentImageIndex = index;
                      });
                    }
                  },
                  itemBuilder: (_, index) {
                    return Center(
                      child: InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 4.0,
                        child: _buildImageDisplay(
                          images[index],
                          MediaQuery.of(context).size.width,
                          MediaQuery.of(context).size.height,
                          BoxFit.contain,
                        ),
                      ),
                    );
                  },
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_currentImageIndex + 1}/${images.length}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _toggleImageFullscreen,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
    // pubspec.yaml 配置了 assets: - assets/images/，所以使用时应该是 images/xxx
    String assetPath = avatarPath;
    if (assetPath.startsWith('assets/images/')) {
      assetPath = assetPath.substring(14); // 去掉 "assets/images/" 前缀
    } else if (assetPath.startsWith('assets/')) {
      assetPath = assetPath.substring(7); // 去掉 "assets/" 前缀
    }

    // 使用 Image.asset 并添加错误处理
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


}
