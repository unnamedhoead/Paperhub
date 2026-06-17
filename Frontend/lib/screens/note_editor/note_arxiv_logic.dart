// lib/screens/note_editor/note_arxiv_logic.dart
//
// arXiv 文献信息子系统：拉取元数据、回填标题 / 摘要 / DOI / 期刊 / 年份、清除。
// 作为 mixin 混入 [NoteEditorController]，持有 arXiv 相关状态字段。
// 拆分为独立文件以遵守单文件 ≤300 行；mixin 是组合机制，非 part-of 假拆分。

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter/widgets.dart' show TextEditingController;

import '../../services/arxiv_service.dart';
import 'note_editor_results.dart';

mixin NoteArxivLogic on ChangeNotifier {
  /// 由宿主提供：标题 / 正文 / arXiv 输入控制器。
  TextEditingController get titleController;
  TextEditingController get contentController;
  TextEditingController get arxivController;

  /// 由宿主提供：是否已 dispose（await 后据此跳过 TextEditingController 写入）。
  bool get isDisposed;

  // arXiv 相关状态
  ArxivMetadata? _arxivMetadata;
  bool _isLoadingArxiv = false;
  String? _arxivId;
  String? _doi;
  String? _journal;
  int? _year;

  ArxivMetadata? get arxivMetadata => _arxivMetadata;
  bool get isLoadingArxiv => _isLoadingArxiv;
  String? get arxivId => _arxivId;
  String? get arxivDoi => _doi;
  String? get arxivJournal => _journal;
  int? get arxivYear => _year;

  /// 从已有帖子回填 arXiv 字段（编辑模式调用）。
  void hydrateArxivFrom({
    required String? arxivId,
    required String? doi,
    required String? journal,
    required int? year,
    required String title,
    required List<String> arxivAuthors,
    required String? arxivPublishedDate,
    required List<String> arxivCategories,
  }) {
    _arxivId = arxivId;
    _doi = doi;
    _journal = journal;
    _year = year;

    if (arxivId != null && arxivId.isNotEmpty) {
      arxivController.text = arxivId;
      _arxivMetadata = ArxivMetadata(
        id: arxivId,
        title: title,
        authors: arxivAuthors,
        abstract: null,
        publishedDate: arxivPublishedDate != null
            ? DateTime.tryParse(arxivPublishedDate)
            : null,
        updatedDate: null,
        categories: arxivCategories,
        doi: doi,
        journal: journal,
        year: year,
      );
    }
  }

  /// 从 arXiv 获取文献元数据。返回 [ArxivFetchResult] 由 screen 弹提示。
  Future<ArxivFetchResult> fetchArxivMetadata() async {
    final input = arxivController.text.trim();
    if (input.isEmpty) {
      return const ArxivFetchResult(
        ArxivFetchStatus.failure,
        '请输入 arXiv ID 或链接',
      );
    }

    _isLoadingArxiv = true;
    notifyListeners();

    try {
      final metadata = await ArxivService.fetchMetadata(input);

      // 页面已关闭：controller/TextEditingController 已被 dispose，不再写入。
      // （对应旧实现 await 后的 `if (!mounted) return;` 守卫）
      if (isDisposed) {
        return ArxivFetchResult(ArxivFetchStatus.success, metadata.title);
      }

      _arxivMetadata = metadata;
      _arxivId = metadata.id;

      // 自动填充标题（如果为空）
      if (titleController.text.trim().isEmpty) {
        titleController.text = metadata.title;
      }

      // 填充元数据
      _doi = metadata.doi;
      _journal = metadata.journal;
      _year = metadata.yearFormatted;

      // 如果摘要存在且内容为空，可以添加到内容中
      if (metadata.abstract != null && contentController.text.trim().isEmpty) {
        contentController.text = '摘要：${metadata.abstract}';
      }

      return ArxivFetchResult(
        ArxivFetchStatus.success,
        '成功获取文献信息：${metadata.title}',
      );
    } on ArxivException catch (e) {
      _clearArxivState();
      return ArxivFetchResult(ArxivFetchStatus.failure, e.message);
    } catch (e) {
      _clearArxivState();
      return ArxivFetchResult(
        ArxivFetchStatus.failure,
        '获取文献信息失败：${e.toString()}',
      );
    } finally {
      _isLoadingArxiv = false;
      notifyListeners();
    }
  }

  void _clearArxivState() {
    _arxivMetadata = null;
    _arxivId = null;
    _doi = null;
    _journal = null;
    _year = null;
  }

  /// 清除 arXiv 信息
  void clearArxivMetadata() {
    arxivController.clear();
    _clearArxivState();
    notifyListeners();
  }
}
