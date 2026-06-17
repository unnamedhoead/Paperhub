// lib/screens/note_editor/note_editor_screen.dart

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/post_model.dart';
import 'note_editor_body.dart';
import 'note_editor_controller.dart';
import 'note_editor_results.dart';
import 'note_reference_section.dart';

class NoteEditorPage extends StatefulWidget {
  /// 如果传入 initialPost，则进入"编辑模式"，否则是"新建笔记"
  final Post? initialPost;

  const NoteEditorPage({Key? key, this.initialPost}) : super(key: key);

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  final ImagePicker _picker = ImagePicker();

  // 文本输入 / 焦点：生命周期归 State，传给 controller 作为协作对象。
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();
  final TextEditingController _arxivController = TextEditingController();
  final FocusNode _contentFocusNode = FocusNode();

  late final NoteEditorController _controller = NoteEditorController(
    titleController: _titleController,
    contentController: _contentController,
    linkController: _linkController,
    arxivController: _arxivController,
    initialPost: widget.initialPost,
  );

  bool get _isEditing => widget.initialPost != null;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    // 获取当前用户角色
    _controller.loadCurrentUserRole();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _contentFocusNode.dispose();
    _titleController.dispose();
    _contentController.dispose();
    _linkController.dispose();
    _arxivController.dispose();
    super.dispose();
  }

  /// 校验链接格式是否可识别，只接受 http / https
  bool _isValidUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return false;

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return false;

    return uri.isScheme('http') || uri.isScheme('https');
  }

  // 统一弹 SnackBar。沿用框架默认时长（与原实现一致）。
  void _showSnack(String message, {Color? backgroundColor}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
  }

  // 选择图片
  Future<void> _pickImage() async {
    if (_controller.images.length >= 9) return;
    final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      _controller.addImage(file);
    }
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
        // Web 平台：使用字节数据，路径用特殊标识。
        if (file.bytes != null) {
          _controller.setPdf(
            file: File('web://${file.name}'),
            bytes: file.bytes,
            name: file.name,
          );
        }
      } else {
        // 移动平台：使用文件路径
        final path = file.path;
        if (path != null) {
          _controller.setPdf(file: File(path));
        }
      }
    }
  }

  // 添加外部链接（校验 + SnackBar 由 screen 负责）
  void _handleAddLink() {
    final text = _linkController.text.trim();
    if (text.isEmpty) {
      _showSnack('链接不能为空');
      return;
    }
    if (!_isValidUrl(text)) {
      _showSnack('链接格式不正确，请以 http 或 https 开头');
      return;
    }
    _controller.addExternalLink(text);
  }

  // 拉取 arXiv 元数据
  Future<void> _handleFetchArxiv() async {
    final result = await _controller.fetchArxivMetadata();
    if (!mounted) return;
    _showSnack(
      result.message,
      backgroundColor: result.isSuccess ? Colors.green : Colors.red,
    );
  }

  // 发布 / 编辑：校验 -> 弹加载框 -> 调 controller -> 根据结果处理导航与提示
  Future<void> _handlePublish({
    String? statusOverride,
    String? customSuccessMessage,
  }) async {
    // 前置校验失败不出现 loading（与原实现一致）。
    final validationError = _controller.validateForSubmit();
    if (validationError != null) {
      _showSnack(validationError);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final result = await _controller.publishNote(
      statusOverride: statusOverride,
      customSuccessMessage: customSuccessMessage,
    );

    if (!mounted) return;
    // 关闭加载对话框
    Navigator.of(context).pop();

    switch (result.kind) {
      case NoteSubmitKind.validationFailed:
      case NoteSubmitKind.pdfDataError:
      case NoteSubmitKind.failure:
      case NoteSubmitKind.error:
        _showSnack(result.message ?? '操作失败');
        break;
      case NoteSubmitKind.editSuccess:
        _showSnack(result.successMessage ?? '笔记已更新');
        // 编辑模式：返回上一页，由上一页决定是否刷新
        Navigator.of(context).pop(result.createdPost ?? true);
        break;
      case NoteSubmitKind.createSuccess:
        _showSnack(result.successMessage ?? '发布成功');
        // 新建：统一跳转首页（新帖子已缓存到本地用于置顶）
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
        break;
    }
  }

  // 选择引用文献对话框
  Future<void> _showReferenceSelector() async {
    // 如果还没有加载过数据，先加载
    if (_controller.userPosts.isEmpty &&
        _controller.userFavorites.isEmpty &&
        !_controller.isLoadingReferences) {
      await _controller.loadUserPostsAndFavorites();
    }
    if (!mounted) return;
    await showReferenceSelectorDialog(context, _controller);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0.3,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        automaticallyImplyLeading: false,
        title: Text(
          _isEditing ? '编辑笔记' : '发布笔记',
          style: TextStyle(color: scheme.onSurface),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.close, color: scheme.onSurface),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: const [SizedBox(width: 48)],
      ),
      body: SafeArea(
        child: NoteEditorBody(
          controller: _controller,
          initialPost: widget.initialPost,
          isEditing: _isEditing,
          titleController: _titleController,
          contentController: _contentController,
          contentFocusNode: _contentFocusNode,
          onPickImage: _pickImage,
          onPickPdf: _pickPdf,
          onAddLink: _handleAddLink,
          onFetchArxiv: _handleFetchArxiv,
          onAddReference: _showReferenceSelector,
          onPublish: _handlePublish,
        ),
      ),
    );
  }
}
