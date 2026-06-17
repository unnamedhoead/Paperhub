import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// 帖子详情页媒体画廊：图片轮播 + 导航 + 全屏预览
class PostMediaGallery extends StatelessWidget {
  final List<String> imageUrls;
  final double? actualImageWidth;
  final double? actualImageHeight;
  final double imageNaturalWidth;
  final double imageNaturalHeight;
  final double imageAspectRatio;
  final PageController imagePageController;
  final int currentImageIndex;
  final bool isHoveringImage;
  final bool showBigHeart;
  final Animation<double> heartScale;
  final VoidCallback onDoubleTap;
  final VoidCallback onImageTap;
  final VoidCallback onNextImage;
  final VoidCallback onPreviousImage;
  final VoidCallback onHoverEnter;
  final VoidCallback onHoverExit;
  final ValueChanged<int> onPageChanged;

  const PostMediaGallery({
    super.key,
    required this.imageUrls,
    this.actualImageWidth,
    this.actualImageHeight,
    required this.imageNaturalWidth,
    required this.imageNaturalHeight,
    required this.imageAspectRatio,
    required this.imagePageController,
    required this.currentImageIndex,
    required this.isHoveringImage,
    required this.showBigHeart,
    required this.heartScale,
    required this.onDoubleTap,
    required this.onImageTap,
    required this.onNextImage,
    required this.onPreviousImage,
    required this.onHoverEnter,
    required this.onHoverExit,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;

        // 计算图片宽高比：优先使用实际加载的图片尺寸，然后是后端返回的尺寸，最后是 imageAspectRatio
        double ratio = 1.5;
        if (imageUrls.isNotEmpty) {
          // 优先使用实际加载的图片尺寸（如果已加载）
          if (actualImageWidth != null &&
              actualImageHeight != null &&
              actualImageWidth! > 0 &&
              actualImageHeight! > 0) {
            ratio = actualImageWidth! / actualImageHeight!;
          }
          // 否则使用后端返回的尺寸（如果看起来不是默认值）
          else if (imageNaturalWidth > 0 &&
              imageNaturalHeight > 0 &&
              !(imageNaturalWidth == 800.0 &&
                  imageNaturalHeight == 600.0)) {
            ratio = imageNaturalWidth / imageNaturalHeight;
          }
          // 最后使用 imageAspectRatio
          else if (imageAspectRatio > 0) {
            ratio = imageAspectRatio;
          }
        }

        // 计算如果宽度填满屏幕时的高度
        final calculatedHeight = screenWidth / ratio;

        // 判断是否需要限制高度
        final bool needsHeightLimit = calculatedHeight > 450;
        final double containerHeight =
            needsHeightLimit ? 450.0 : calculatedHeight;
        final double containerWidth =
            needsHeightLimit ? (450.0 * ratio) : screenWidth;

        if (imageUrls.isEmpty) {
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
          onEnter: (_) => onHoverEnter(),
          onExit: (_) => onHoverExit(),
          child: GestureDetector(
            onDoubleTap: onDoubleTap,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (needsHeightLimit)
                  Center(
                    child: SizedBox(
                      width: containerWidth,
                      height: containerHeight,
                      child: PageView.builder(
                        controller: imagePageController,
                        itemCount: imageUrls.length,
                        onPageChanged: onPageChanged,
                        itemBuilder: (_, index) {
                          return GestureDetector(
                            onTap: onImageTap,
                            child: _buildImageDisplay(
                              imageUrls[index],
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
                      controller: imagePageController,
                      itemCount: imageUrls.length,
                      onPageChanged: onPageChanged,
                      itemBuilder: (_, index) {
                        return GestureDetector(
                          onTap: onImageTap,
                          child: _buildImageDisplay(
                            imageUrls[index],
                            screenWidth,
                            containerHeight,
                            BoxFit.cover,
                          ),
                        );
                      },
                    ),
                  ),
                if (kIsWeb &&
                    imageUrls.length > 1 &&
                    isHoveringImage)
                  Positioned(
                    left: 16,
                    child: _buildImageNavButton(
                      icon: Icons.chevron_left,
                      onTap: onPreviousImage,
                      enabled: currentImageIndex > 0,
                    ),
                  ),
                if (kIsWeb &&
                    imageUrls.length > 1 &&
                    isHoveringImage)
                  Positioned(
                    right: 16,
                    child: _buildImageNavButton(
                      icon: Icons.chevron_right,
                      onTap: onNextImage,
                      enabled:
                          currentImageIndex < imageUrls.length - 1,
                    ),
                  ),
                // 喜欢动画
                Positioned(
                  child: showBigHeart
                      ? ScaleTransition(
                          scale: heartScale,
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
}
