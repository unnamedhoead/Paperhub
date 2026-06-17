// lib/screens/note_editor/note_editor_controller.dart
//
// 笔记编辑器的状态与业务逻辑（state-management-convention.md 类型 A）。
// - 不持有 BuildContext；导航 / SnackBar / 文件选择经返回值或回调交给 screen。
// - TextEditingController / FocusNode 的生命周期由 screen 持有并 dispose，
//   此处仅作为协作对象引用，用于读写文本与光标。
// - 发布管线（上传 + 组装 + 调用后端）委托给无状态的 [NotePublishService]。

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter/widgets.dart' show TextEditingController;
import 'package:image_picker/image_picker.dart' show XFile;

import '../../models/post_model.dart';
import 'note_arxiv_logic.dart';
import 'note_editor_data_loading.dart';
import 'note_editor_results.dart';
import 'note_publish_service.dart';
import 'note_tag_logic.dart';

class NoteEditorController extends ChangeNotifier
    with NoteTagLogic, NoteEditorDataLoading, NoteArxivLogic {
  NoteEditorController({
    required this.titleController,
    required this.contentController,
    required this.linkController,
    required this.arxivController,
    this.initialPost,
    NotePublishService publishService = const NotePublishService(),
  }) : _publishService = publishService {
    if (isEditing && initialPost != null) {
      applyExistingPost(initialPost!);
    }
  }

  /// 编辑模式下的初始帖子；为 null 表示新建。
  final Post? initialPost;

  bool _disposed = false;

  /// 是否已 dispose。异步方法在 await 后据此跳过对（已被 screen dispose 的）
  /// TextEditingController 的写入，避免 used-after-dispose。
  @override
  bool get isDisposed => _disposed;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// dispose 后吞掉通知，避免 "used after dispose" 断言（async 回调竞态）。
  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  // 文本输入控制器（生命周期由 screen 持有）。
  // titleController / contentController / arxivController 同时实现 mixin 的抽象 getter。
  @override
  final TextEditingController titleController;
  @override
  final TextEditingController contentController;
  final TextEditingController linkController;
  @override
  final TextEditingController arxivController;

  final NotePublishService _publishService;

  // 图片与 PDF
  final List<XFile> _images = []; // 最多 9 张
  File? _pdfFile; // 仅允许 1 个 PDF
  Uint8List? _pdfFileBytes; // Web 平台的 PDF 字节数据
  String? _pdfFileName; // Web 平台的 PDF 文件名

  // 外部链接
  final List<String> _externalLinks = [];

  // arXiv 相关状态由 NoteArxivLogic mixin 持有。

  // 分区与推荐细分类标签
  String? _selectedDiscipline; // 必选：学科分区
  bool _showDisciplineDropdown = false; // 控制下拉菜单显示

  // 高级选项是否展开
  bool _showAdvancedOptions = false; // 默认收起

  // #符号触发标签选择相关状态由 NoteTagLogic mixin 持有。
  // 当前用户角色 / 引用候选（我的帖子 / 收藏）由 NoteEditorDataLoading mixin 持有。

  // 引用文献相关状态
  List<int> _selectedReferences = []; // 已选择的引用帖子ID列表

  /// 编辑模式下旧图片的 URL 列表
  final List<String> _existingImageUrls = [];

  /// 编辑模式下旧 PDF 的 URL
  String? _existingPdfUrl;

  // ===== Getters =====
  List<XFile> get images => List.unmodifiable(_images);
  File? get pdfFile => _pdfFile;
  Uint8List? get pdfFileBytes => _pdfFileBytes;
  String? get pdfFileName => _pdfFileName;
  List<String> get externalLinks => List.unmodifiable(_externalLinks);
  String? get selectedDiscipline => _selectedDiscipline;
  bool get showDisciplineDropdown => _showDisciplineDropdown;
  bool get showAdvancedOptions => _showAdvancedOptions;
  List<int> get selectedReferences => List.unmodifiable(_selectedReferences);
  List<String> get existingImageUrls => List.unmodifiable(_existingImageUrls);
  String? get existingPdfUrl => _existingPdfUrl;

  /// 是否处于编辑模式
  bool get isEditing => initialPost != null;

  /// 是否已选择 PDF（新选或沿用旧的）。
  bool get hasPdf => _pdfFile != null || _existingPdfUrl != null;

  // NoteTagLogic 所需：当前分区决定可用二级标签。
  @override
  String? get selectedDisciplineForTags => _selectedDiscipline;

  /// 获取过滤后的分区列表（根据用户角色隐藏"公告区"）。
  List<String> getFilteredDisciplines() => filterDisciplines(currentUserRole);

  // ===== UI 状态变更 =====
  void toggleAdvancedOptions() {
    _showAdvancedOptions = !_showAdvancedOptions;
    notifyListeners();
  }

  void toggleDisciplineDropdown() {
    _showDisciplineDropdown = !_showDisciplineDropdown;
    notifyListeners();
  }

  void closeDisciplineDropdown() {
    _showDisciplineDropdown = false;
    notifyListeners();
  }

  void selectDiscipline(String discipline) {
    _selectedDiscipline = discipline;
    _showDisciplineDropdown = false; // 选择后收起下拉菜单
    notifyListeners();
  }

  // ===== 图片 / PDF / 链接变更 =====
  void addImage(XFile file) {
    if (_images.length < 9) {
      _images.add(file);
      notifyListeners();
    }
  }

  void removeImage(int index) {
    _images.removeAt(index);
    notifyListeners();
  }

  void removeExistingImage(int index) {
    _existingImageUrls.removeAt(index);
    notifyListeners();
  }

  /// 选了新的 PDF：替换旧附件。
  void setPdf({required File file, Uint8List? bytes, String? name}) {
    _pdfFile = file;
    _pdfFileBytes = bytes;
    _pdfFileName = name;
    _existingPdfUrl = null;
    notifyListeners();
  }

  void removePdf() {
    _pdfFile = null;
    _pdfFileBytes = null;
    _pdfFileName = null;
    notifyListeners();
  }

  void removeExistingPdf() {
    _existingPdfUrl = null;
    notifyListeners();
  }

  void addExternalLink(String link) {
    _externalLinks.add(link);
    linkController.clear();
    notifyListeners();
  }

  void removeExternalLink(String link) {
    _externalLinks.remove(link);
    notifyListeners();
  }

  void toggleReference(int postId, bool selected) {
    if (selected) {
      if (!_selectedReferences.contains(postId)) {
        _selectedReferences.add(postId);
      }
    } else {
      _selectedReferences.remove(postId);
    }
    notifyListeners();
  }

  void removeReference(int postId) {
    _selectedReferences.remove(postId);
    notifyListeners();
  }

  // loadCurrentUserRole / loadUserPostsAndFavorites 由
  // NoteEditorDataLoading mixin 提供。

  /// 将已有帖子内容灌入编辑器（编辑模式）
  void applyExistingPost(Post post) {
    // 标题 & 正文
    titleController.text = post.title;
    contentController.text = post.content;

    // 关键：恢复原来的分区
    _selectedDiscipline = post.mainDiscipline;

    // 已有媒体：区分图片和 PDF
    _existingImageUrls.clear();
    _existingPdfUrl = null;
    if (post.media.isNotEmpty) {
      for (final m in post.media) {
        if (m.isEmpty) continue;
        if (_isPdfUrl(m)) {
          // 只用第一份 PDF
          _existingPdfUrl ??= m;
        } else {
          _existingImageUrls.add(m);
        }
      }
    }

    // 外部链接
    _externalLinks
      ..clear()
      ..addAll(post.externalLinks);

    // 文献信息 / arXiv（由 NoteArxivLogic mixin 持有并回填）
    hydrateArxivFrom(
      arxivId: post.arxivId,
      doi: post.doi,
      journal: post.journal,
      year: post.year,
      title: post.title,
      arxivAuthors: post.arxivAuthors,
      arxivPublishedDate: post.arxivPublishedDate,
      arxivCategories: post.arxivCategories,
    );

    // 预填充引用文献
    _selectedReferences = List.from(post.references);
  }

  // 判断 URL 是否为 PDF
  bool _isPdfUrl(String url) => url.toLowerCase().endsWith('.pdf');

  /// 发布前的同步校验。返回首个错误提示文案；通过则返回 null。
  /// screen 应先调用此方法（失败直接弹 SnackBar），再展示加载框调用 [publishNote]，
  /// 以保持原实现"校验失败不出现 loading"的行为。
  String? validateForSubmit() {
    if (titleController.text.trim().isEmpty) {
      return '请输入标题';
    }
    if (contentController.text.trim().isEmpty) {
      return '请输入正文';
    }
    // 只有"新建笔记"强制要求必须选择图片；编辑时可以只改文字 / 链接
    if (!isEditing && _images.isEmpty) {
      return '请添加图片';
    }
    if (_selectedDiscipline == null) {
      return '请选择一个学科分区';
    }
    return null;
  }

  /// 发布 / 编辑 笔记。返回 [NoteSubmitResult] 由 screen 处理副作用。
  Future<NoteSubmitResult> publishNote({
    String? statusOverride,
    String? customSuccessMessage,
  }) async {
    final title = titleController.text.trim();
    final content = contentController.text.trim();

    // 前置校验（与原实现顺序一致：标题 -> 正文 -> 图片 -> 分区）。
    final validationError = validateForSubmit();
    if (validationError != null) {
      return NoteSubmitResult.validationFailed(validationError);
    }

    // 注：原实现在此处从正文提取 #标签并与主分区合并去重，但结果从未发送给后端
    // （createPost / updatePost 不接收 tags 参数）。重构时删除该死代码，行为不变。

    return _publishService.submit(
      NotePublishInput(
        isEditing: isEditing,
        initialPostId: initialPost?.id,
        title: title,
        content: content,
        images: _images,
        existingImageUrls: _existingImageUrls,
        pdfFile: _pdfFile,
        pdfFileBytes: _pdfFileBytes,
        pdfFileName: _pdfFileName,
        existingPdfUrl: _existingPdfUrl,
        externalLinks: _externalLinks,
        mainDiscipline: _selectedDiscipline!,
        arxivId: arxivId,
        doi: arxivDoi,
        journal: arxivJournal,
        year: arxivYear,
        arxivMetadataAuthors: arxivMetadata?.authors,
        arxivMetadataCategories: arxivMetadata?.categories,
        arxivPublishedDate: arxivMetadata?.publishedDateFormatted,
        references: _selectedReferences,
        statusOverride: statusOverride,
        customSuccessMessage: customSuccessMessage,
      ),
    );
  }

  // arXiv 拉取 / 回填 / 清除（fetchArxivMetadata / hydrateArxivFrom /
  // clearArxivMetadata）由 NoteArxivLogic mixin 提供。
  // #标签输入 / 建议逻辑（onContentChanged / selectTagSuggestion /
  // completeCustomTag / extractTagsFromText / getAvailableSubTags）
  // 由 NoteTagLogic mixin 提供。
}
