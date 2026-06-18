/// 图片全屏预览浮层（从 post_detail_screen.dart 的 _buildFullscreenOverlay 抽出）。
///
/// 与详情页内联图廊共享同一个 [pageController] 与当前索引：通过 [currentIndex] 读入、
/// [onIndexChanged] 回写，[onClose] 关闭。行为与原实现一致。
library;

import 'dart:io';

import 'package:flutter/material.dart';

/// 图片全屏预览浮层（铺满父 Stack）。
class PostFullscreenImageOverlay extends StatelessWidget {
  const PostFullscreenImageOverlay({
    super.key,
    required this.images,
    required this.pageController,
    required this.currentIndex,
    required this.onIndexChanged,
    required this.onClose,
  });

  final List<String> images;
  final PageController pageController;
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();

    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.95),
        child: SafeArea(
          child: GestureDetector(
            onTap: onClose,
            child: Stack(
              children: [
                PageView.builder(
                  controller: pageController,
                  itemCount: images.length,
                  onPageChanged: (index) {
                    if (currentIndex != index) onIndexChanged(index);
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
                      '${currentIndex + 1}/${images.length}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: onClose,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
}
