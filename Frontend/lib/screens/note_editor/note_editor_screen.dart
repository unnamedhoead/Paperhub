// lib/screens/note_editor/note_editor_screen.dart

import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/app_env.dart';
import '../../services/api_service.dart';
import '../../services/arxiv_service.dart';
import '../../services/local_storage.dart';
import '../../constants/discipline_constants.dart';
import '../../models/post_model.dart';
import '../../models/user_profile.dart';

part 'note_editor_controller.dart';
part 'note_media_section.dart';
part 'arxiv_metadata_section.dart';
part 'reference_selector.dart';

class NoteEditorPage extends StatefulWidget {
  /// 如果传入 initialPost，则进入"编辑模式"，否则是"新建笔记"
  final Post? initialPost;

  const NoteEditorPage({Key? key, this.initialPost}) : super(key: key);

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  final ImagePicker _picker = ImagePicker();

  // 图片与 PDF
  List<XFile> _images = []; // 最多 9 张
  File? _pdfFile; // 仅允许 1 个 PDF
  Uint8List? _pdfFileBytes; // Web 平台的 PDF 字节数据
  String? _pdfFileName; // Web 平台的 PDF 文件名

  // 文本输入
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  // 外部链接
  final TextEditingController _linkController = TextEditingController();
  final List<String> _externalLinks = [];

  // arXiv 相关
  final TextEditingController _arxivController = TextEditingController();
  ArxivMetadata? _arxivMetadata;
  bool _isLoadingArxiv = false;
  String? _arxivId;
  String? _doi;
  String? _journal;
  int? _year;

  // 分区与推荐细分类标签
  String? _selectedDiscipline; // 必选：学科分区
  bool _showDisciplineDropdown = false; // 控制下拉菜单显示
  String? _currentUserRole; // 当前用户角色

  // 高级选项（外部链接 / arXiv / 引用文献 / PDF）是否展开
  bool _showAdvancedOptions = false; // 默认收起

  // #符号触发标签选择相关状态
  bool _showTagSuggestions = false;
  String _currentTagInput = '';
  List<String> _filteredTagSuggestions = [];
  final FocusNode _contentFocusNode = FocusNode();
  bool _isTypingCustomTag = false;

  // 引用文献相关状态
  List<int> _selectedReferences = []; // 已选择的引用帖子ID列表
  List<Post> _userPosts = []; // 用户的帖子列表
  List<Post> _userFavorites = []; // 用户的收藏列表
  bool _isLoadingReferences = false;

  /// 编辑模式下旧图片的 URL 列表
  final List<String> _existingImageUrls = [];

  /// 编辑模式下旧 PDF 的 URL
  String? _existingPdfUrl;

  /// 是否处于编辑模式
  bool get _isEditing => widget.initialPost != null;

  @override
  void initState() {
    super.initState();
    // 如果传入了 initialPost，则进入编辑模式，预填内容
    if (_isEditing && widget.initialPost != null) {
      _applyExistingPost(widget.initialPost!);
    }
    // 获取当前用户角色
    _loadCurrentUserRole();
  }

  // 判断 URL 是否为 PDF
  bool _isPdfUrl(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.pdf');
  }

  /// 校验链接格式是否可识别，只接受 http / https
  bool _isValidUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return false;

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return false;

    return uri.isScheme('http') || uri.isScheme('https');
  }

  @override
  void dispose() {
    _contentFocusNode.dispose();
    _titleController.dispose();
    _contentController.dispose();
    _linkController.dispose();
    _arxivController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasPdf = _pdfFile != null || _existingPdfUrl != null;
    final Post? editingPost = widget.initialPost;
    final String? currentStatus = editingPost?.status?.toUpperCase();
    final bool isDraft = _isEditing && currentStatus == 'DRAFT';
    final bool hasHiddenReason =
        isDraft && (editingPost?.hiddenReason?.trim().isNotEmpty ?? false);
    final bool isAdminRejectedDraft = isDraft && hasHiddenReason;

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
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isAdminRejectedDraft) ...[
                _buildAdminFeedbackBanner(
                  editingPost!.draftReason ?? editingPost.hiddenReason ?? '',
                ),
                const SizedBox(height: 16),
              ],

              //选择图片
              _buildImageGrid(),
              const SizedBox(height: 16),

              // 标题
              TextField(
                controller: _titleController,
                textInputAction: TextInputAction.next,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: '添加标题（最多一行）',
                  hintStyle: TextStyle(color: scheme.onSurface.withOpacity(0.6)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                ),
              ),
              Divider(height: 1, color: scheme.outline.withOpacity(0.3)),
              const SizedBox(height: 8),

              // 正文（支持#符号添加标签）
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _contentController,
                    focusNode: _contentFocusNode,
                    keyboardType: TextInputType.multiline,
                    maxLines: null,
                    minLines: 6,
                    onChanged: _onContentChanged,
                    decoration: InputDecoration(
                      hintText: '写下你的笔记（输入#添加标签，支持学术笔记格式）',
                      hintStyle: TextStyle(color: scheme.onSurface.withOpacity(0.6)),
                      border: InputBorder.none,
                      isCollapsed: false,
                    ),
                    style: TextStyle(color: scheme.onSurface),
                  ),
                  _buildTagSuggestions(),
                ],
              ),

              // 一级标签选择（学科分区）
              _buildDisciplineSelector(),
              const SizedBox(height: 16),

              // 高级选项入口（+ 号展开 / 收起）
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '更多学术选项（可选）',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurface,
                    ),
                  ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _showAdvancedOptions = !_showAdvancedOptions;
                        });
                      },
                      icon: Icon(
                        _showAdvancedOptions
                            ? Icons.remove_circle_outline // 展开时显示 -
                            : Icons.add_circle_outline, // 收起时显示 +
                        color: scheme.primary,
                      ),
                    ),
                ],
              ),

                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 200),
                  crossFadeState: _showAdvancedOptions
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  firstChild: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 外部链接区
                      _buildExternalLinksSection(),
                      const SizedBox(height: 16),

                      // arXiv 文献信息区
                      _buildArxivSection(),
                      const SizedBox(height: 16),

                      // 引用文献区
                      _buildReferencesSection(),
                      const SizedBox(height: 16),

                      // PDF 附件
                      _buildPdfSection(hasPdf),
                    ],
                  ),
                  secondChild: const SizedBox.shrink(),
                ),

              const SizedBox(height: 24),

              // 发布按钮
              _buildBottomActions(
                isDraft: isDraft,
                isAdminRejectedDraft: isAdminRejectedDraft,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTagSuggestions() {
    if (!_showTagSuggestions) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade300),
      ),
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _isTypingCustomTag ? '自定义标签（按空格或回车完成输入）' : '标签建议（输入#继续筛选）',
              style: TextStyle(
                fontSize: 12,
                color: _isTypingCustomTag
                    ? Colors.orange.shade700
                    : Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Divider(height: 1),
          ..._filteredTagSuggestions.map((tag) {
            // 检查标签是否已经出现在正文中
            final bool alreadySelected = _contentController.text.contains(
              '#$tag ',
            );
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _selectTagSuggestion(tag),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.shade200,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.tag,
                        size: 16,
                        color: alreadySelected
                            ? Colors.blue
                            : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 14,
                            color: alreadySelected
                                ? Colors.blue
                                : Colors.black87,
                            fontWeight: alreadySelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (alreadySelected)
                        Icon(Icons.check, size: 16, color: Colors.blue),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
          if (_filteredTagSuggestions.isEmpty && _currentTagInput.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isTypingCustomTag
                          ? '正在输入自定义标签 "$_currentTagInput"，按空格或回车完成输入'
                          : '未找到匹配的标签，按空格或回车可输入自定义标签 "$_currentTagInput"',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
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

  // 一级标签选择（放在外部链接之上）- 下拉隐藏式选择器
  Widget _buildDisciplineSelector() {
    final scheme = Theme.of(context).colorScheme;
    final filteredDisciplines = _getFilteredDisciplines();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题行
        Row(
          children: [
            Text(
              '选择分区',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: scheme.onSurface),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '必选',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Spacer(),

            // 显示已选分区和下拉按钮
            Row(
              children: [
                if (_selectedDiscipline != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color:
                          kDisciplineColors[_selectedDiscipline]?.withOpacity(
                            0.1,
                          ) ??
                          const Color(0xFF1976D2).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            kDisciplineColors[_selectedDiscipline]?.withOpacity(
                              0.3,
                            ) ??
                            const Color(0xFF1976D2).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _selectedDiscipline!,
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            kDisciplineColors[_selectedDiscipline] ??
                            const Color(0xFF1976D2),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                // 下拉按钮
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showDisciplineDropdown = !_showDisciplineDropdown;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: scheme.outline.withOpacity(0.3)),
                    ),
                    child: Icon(
                      _showDisciplineDropdown
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 20,
                      color: scheme.onSurface.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),

        // 下拉菜单区域 - 椭圆形文字泡矩阵排布
        if (_showDisciplineDropdown)
          Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outline.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题和关闭按钮
                Row(
                  children: [
                    Text(
                      '选择分区',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _showDisciplineDropdown = false;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: scheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: scheme.onSurface.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 椭圆形文字泡矩阵
                Wrap(
                  spacing: 10, // 水平间距
                  runSpacing: 10, // 垂直间距
                  children: filteredDisciplines.map((discipline) {
                    final bool selected = _selectedDiscipline == discipline;
                    final scheme = Theme.of(context).colorScheme;
                    final chipColor =
                        kDisciplineColors[discipline] ?? scheme.primary;
                    final textColor = scheme.onSurface;
                    final borderColor = scheme.onSurface.withOpacity(0.45);

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedDiscipline = discipline;
                          _showDisciplineDropdown = false; // 选择后收起下拉菜单
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? chipColor.withOpacity(0.16)
                              : Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(20), // 椭圆形
                          border: Border.all(
                            color: borderColor,
                            width: selected ? 1.5 : 1,
                          ),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: chipColor.withOpacity(0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 颜色指示点
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: chipColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: chipColor.withOpacity(0.4),
                                    blurRadius: 3,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              discipline,
                              style: TextStyle(
                                fontSize: 13,
                                color: textColor,
                                fontWeight:
                                    selected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                            if (selected)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                child: Icon(
                                  Icons.check_circle,
                                  size: 14,
                                  color: chipColor,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                // 如果没有选择任何分区，显示提示
                if (_selectedDiscipline == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 14,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '请点击上方的椭圆形标签选择一个分区',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

        const SizedBox(height: 8),
        const Text(
          '选择学科分区后，在正文中输入#可添加相关细分类标签',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}
