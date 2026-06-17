// lib/screens/note_editor/note_tag_logic.dart
//
// 正文 #标签 输入与建议子系统。作为 mixin 混入 [NoteEditorController]，
// 持有标签建议相关状态并直接操作正文 TextEditingController。
// 拆分为独立文件以遵守单文件 ≤300 行；mixin 是组合机制，非 part-of 假拆分。

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter/widgets.dart'
    show TextEditingController, TextSelection, TextPosition;

import '../../constants/discipline_constants.dart';

mixin NoteTagLogic on ChangeNotifier {
  /// 由宿主提供：正文输入控制器。
  TextEditingController get contentController;

  /// 由宿主提供：当前已选学科分区（决定可用二级标签）。
  String? get selectedDisciplineForTags;

  // #符号触发标签选择相关状态
  bool _showTagSuggestions = false;
  String _currentTagInput = '';
  List<String> _filteredTagSuggestions = [];
  bool _isTypingCustomTag = false;

  bool get showTagSuggestions => _showTagSuggestions;
  String get currentTagInput => _currentTagInput;
  List<String> get filteredTagSuggestions =>
      List.unmodifiable(_filteredTagSuggestions);
  bool get isTypingCustomTag => _isTypingCustomTag;

  /// 获取当前可选的二级标签（用于#符号提示）
  List<String> getAvailableSubTags() {
    final discipline = selectedDisciplineForTags;
    if (discipline != null && kRecommendedSubTags.containsKey(discipline)) {
      return kRecommendedSubTags[discipline]!;
    } else {
      final set = <String>{};
      for (final list in kRecommendedSubTags.values) {
        set.addAll(list);
      }
      return set.toList();
    }
  }

  /// 获取过滤后的分区列表（根据用户角色隐藏"公告区"）
  List<String> filterDisciplines(String? currentUserRole) {
    // 如果用户角色是管理员或超级管理员，显示所有分区（包括公告区）
    if (currentUserRole == 'ADMIN' || currentUserRole == 'SUPER_ADMIN') {
      return kMainDisciplines; // 管理员和超级管理员可以看到所有分区
    } else {
      // 普通用户或角色未加载时隐藏"公告区"
      return kMainDisciplines
          .where((discipline) => discipline != '公告区')
          .toList();
    }
  }

  /// 处理正文文本变化，检测#符号
  void onContentChanged(String text) {
    // 检查是否正在输入#标签 - 只检查最后一个#，并且后面没有空格
    final lastIndex = text.lastIndexOf('#');
    if (lastIndex != -1) {
      // 提取#后面的所有内容
      final afterHash = text.substring(lastIndex + 1);

      // 检查#后面是否有空格或换行（表示标签已结束）
      final nextSpaceIndex = afterHash.indexOf(' ');
      final nextNewlineIndex = afterHash.indexOf('\n');

      // 如果#后面有空格或换行，表示标签已结束
      if (nextSpaceIndex != -1 || nextNewlineIndex != -1) {
        // 完成自定义标签输入
        completeCustomTag();

        // 立即隐藏建议
        _resetTagSuggestions();
        return;
      }

      // 如果#后面没有内容，不显示建议
      if (afterHash.isEmpty) {
        if (_showTagSuggestions) {
          _resetTagSuggestions();
        }
        return;
      }

      // 提取当前正在输入的标签内容（到空格或换行为止）
      final endIndex = nextSpaceIndex != -1
          ? nextSpaceIndex
          : (nextNewlineIndex != -1 ? nextNewlineIndex : afterHash.length);

      if (endIndex > 0) {
        final tagInput = afterHash.substring(0, endIndex);

        _currentTagInput = tagInput;
        _showTagSuggestions = true;

        // 过滤标签建议
        final availableTags = getAvailableSubTags();
        _filteredTagSuggestions.clear();
        if (tagInput.isNotEmpty) {
          _filteredTagSuggestions.addAll(
            availableTags
                .where(
                  (tag) => tag.toLowerCase().contains(tagInput.toLowerCase()),
                )
                .toList(),
          );
        }

        // 限制显示数量
        if (_filteredTagSuggestions.length > 10) {
          _filteredTagSuggestions = _filteredTagSuggestions.sublist(0, 10);
        }

        // 如果没有匹配的建议，表示用户正在输入自定义标签
        _isTypingCustomTag =
            _filteredTagSuggestions.isEmpty && tagInput.isNotEmpty;
        notifyListeners();
        return;
      }
    }

    // 如果没有#标签输入，隐藏建议
    if (_showTagSuggestions) {
      _resetTagSuggestions();
    }
  }

  void _resetTagSuggestions() {
    _showTagSuggestions = false;
    _currentTagInput = '';
    _filteredTagSuggestions.clear();
    _isTypingCustomTag = false;
    notifyListeners();
  }

  /// 选择标签建议
  void selectTagSuggestion(String tag) {
    final currentText = contentController.text;
    final lastIndex = currentText.lastIndexOf('#');

    if (lastIndex != -1) {
      // 替换#及其后面的输入为完整的标签
      final beforeHash = currentText.substring(0, lastIndex);
      final newText = beforeHash + '#$tag ';
      contentController.text = newText;
      contentController.selection = TextSelection.fromPosition(
        TextPosition(offset: newText.length),
      );

      // 隐藏建议
      _resetTagSuggestions();
    }
  }

  /// 处理自定义标签完成（按空格或回车）
  void completeCustomTag() {
    if (_currentTagInput.isNotEmpty &&
        !_filteredTagSuggestions.contains(_currentTagInput)) {
      // 这是一个自定义标签
      final currentText = contentController.text;
      final lastIndex = currentText.lastIndexOf('#');

      if (lastIndex != -1) {
        // 替换#及其后面的输入为完整的自定义标签
        final beforeHash = currentText.substring(0, lastIndex);
        final newText = beforeHash + '#$_currentTagInput ';
        contentController.text = newText;
        contentController.selection = TextSelection.fromPosition(
          TextPosition(offset: newText.length),
        );
      }
    }

    // 隐藏建议
    _resetTagSuggestions();
  }

  /// 从文本中提取所有#标签
  Set<String> extractTagsFromText(String text) {
    final Set<String> tags = {};
    // 匹配#后面的非空格字符，支持中文、英文、数字等
    final regex = RegExp(r'#([^\s#]+)');
    final matches = regex.allMatches(text);

    for (final match in matches) {
      if (match.groupCount >= 1) {
        final tag = match.group(1)!.trim();
        if (tag.isNotEmpty) {
          tags.add(tag);
        }
      }
    }

    return tags;
  }
}
