// lib/screens/note_editor/note_media_section.dart
part of 'note_editor_screen.dart';

extension on _NoteEditorPageState {
  // 选择图片
  Future<void> _pickImage() async {
    if (_images.length >= 9) return;
    final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      setState(() {
        if (_images.length < 9) {
          _images.add(file);
        }
      });
    }
  }

  // 移除指定索引图片
  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  // 移除已有的 PDF（编辑模式）
  void _removeExistingPdf() {
    setState(() {
      _existingPdfUrl = null;
    });
  }

  // 选择 PDF（只允许一个）
  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: kIsWeb, // Web 平台需要读取字节数据
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.single;
      if (kIsWeb) {
        // Web 平台：使用字节数据创建临时文件路径标识
        if (file.bytes != null) {
          setState(() {
            // 在 Web 上，我们存储文件名和字节数据
            // 使用一个特殊的路径格式来标识这是 Web 文件
            _pdfFile = File('web://${file.name}');
            // 存储字节数据以便后续上传
            _pdfFileBytes = file.bytes;
            _pdfFileName = file.name;
            // 选了新的 PDF，则视为替换旧附件
            _existingPdfUrl = null;
          });
        }
      } else {
        // 移动平台：使用文件路径
        final path = file.path;
        if (path != null) {
          setState(() {
            _pdfFile = File(path);
            _pdfFileBytes = null;
            _pdfFileName = null;
            _existingPdfUrl = null;
          });
        }
      }
    }
  }

  // 取消 PDF
  void _removePdf() {
    setState(() {
      _pdfFile = null;
      _pdfFileBytes = null;
      _pdfFileName = null;
    });
  }

  // 移除已有图片（编辑模式）
  void _removeExistingImage(int index) {
    setState(() {
      _existingImageUrls.removeAt(index);
    });
  }

  // 图片九宫格（支持：已有图片 + 新选图片）
  Widget _buildImageGrid() {
    final int existingCount = _existingImageUrls.length;
    final int newCount = _images.length;
    final int totalImages = existingCount + newCount;

    // 最多 9 张，多出来的不再显示"添加"按钮
    final bool showAddButton = totalImages < 9;
    final int itemCount = showAddButton ? totalImages + 1 : totalImages;

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: itemCount,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        // 1) 先画"已有图片"（后端返回的 URL）
        if (index < existingCount) {
          final url = _existingImageUrls[index];
          return Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: NetworkImage(url), // 用网络图
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => _removeExistingImage(index),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(3),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        // 2) 再画"新选图片"（本地 XFile）
        final int newIndex = index - existingCount;
        if (newIndex < newCount) {
          final XFile xfile = _images[newIndex];

          // 根据平台选择不同的预览方式
          ImageProvider previewImage;
          if (kIsWeb) {
            // Web：image_picker 返回的 path 是一个 blob: 开头的本地 URL，用 NetworkImage 即可
            previewImage = NetworkImage(xfile.path);
          } else {
            // 移动端 / 桌面：正常使用 FileImage
            previewImage = FileImage(File(xfile.path));
          }

          return Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: previewImage, // ← 用上面选择好的 ImageProvider
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => _removeImage(newIndex),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(3),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        // 3) 最后是"添加图片"按钮
        return GestureDetector(
          onTap: _pickImage,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Icon(Icons.add, size: 34, color: Colors.grey),
            ),
          ),
        );
      },
    );
  }

  // 外部链接输入区
  Widget _buildExternalLinksSection() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          '外部链接',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _linkController,
                decoration: InputDecoration(
                  hintText: '输入链接后点击右侧添加',
                  hintStyle: TextStyle(color: scheme.onSurface.withOpacity(0.6)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: scheme.outline.withOpacity(0.3)),
                  ),
                  isDense: true,
                  filled: true,
                  fillColor: scheme.surfaceVariant,
                ),
                style: TextStyle(color: scheme.onSurface),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () {
                final text = _linkController.text.trim();

                if (text.isEmpty) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('链接不能为空')));
                  return;
                }

                if (!_isValidUrl(text)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('链接格式不正确，请以 http 或 https 开头')),
                  );
                  return;
                }

                setState(() {
                  _externalLinks.add(text);
                  _linkController.clear();
                });
              },
              icon: const Icon(Icons.add_link, size: 18),
              label: const Text('添加'),
              style: ElevatedButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_externalLinks.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _externalLinks.map((link) {
              return Chip(
                label: SizedBox(
                  width: 160,
                  child: Text(link, overflow: TextOverflow.ellipsis),
                ),
                onDeleted: () {
                  setState(() {
                    _externalLinks.remove(link);
                  });
                },
              );
            }).toList(),
          ),
      ],
    );
  }

  // PDF 附件区域
  Widget _buildPdfSection(bool hasPdf) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: _pickPdf,
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: Text(hasPdf ? '替换 PDF' : '添加 PDF 附件（仅一篇）'),
          style: ElevatedButton.styleFrom(
            backgroundColor: scheme.surfaceVariant,
            foregroundColor: scheme.onSurface,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(width: 12),
        if (hasPdf)
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _pdfFile != null
                          ? (_pdfFileName ?? '已选择 PDF')
                          : (_existingPdfUrl!.split('/').last),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: scheme.onSurface),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      if (_pdfFile != null) {
                        _removePdf(); // 清空新选 PDF
                      } else {
                        _removeExistingPdf(); // 清空旧的 PDF URL
                      }
                    },
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
