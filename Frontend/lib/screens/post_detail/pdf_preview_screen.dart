/// PDF 全屏预览页（从 post_detail_screen.dart 原样抽出）。
///
/// Web 用平台 iframe（[buildPlatformPdfView]），其他平台用 Syncfusion PDF 查看器。
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../widgets/pdf_iframe_view.dart';

/// PDF 全屏预览页。
class PdfPreviewScreen extends StatefulWidget {
  final String url;
  final String title;

  const PdfPreviewScreen({super.key, required this.url, required this.title});

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  bool _isLoading = true;
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: _hasError ? _buildErrorWidget() : _buildViewer(),
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          _buildAppBar(),
        ],
      ),
    );
  }

  Widget _buildViewer() {
    if (kIsWeb) {
      if (_isLoading) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _isLoading = false);
        });
      }
      return buildPlatformPdfView(widget.url);
    }

    return SfPdfViewer.network(
      widget.url,
      canShowPaginationDialog: false,
      canShowScrollHead: false,
      onDocumentLoaded: (_) => setState(() => _isLoading = false),
      onDocumentLoadFailed: (_) => setState(() {
        _isLoading = false;
        _hasError = true;
      }),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 64),
          const SizedBox(height: 16),
          const Text('PDF加载失败',
              style: TextStyle(color: Colors.white, fontSize: 18)),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('返回'),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
