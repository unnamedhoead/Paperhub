import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:test/models/post_model.dart';
import 'package:test/screens/note_editor/note_editor_controller.dart';
import 'package:test/screens/note_editor/note_editor_results.dart';

/// 构造一个 NoteEditorController（自带文本控制器，便于测试后 dispose）。
NoteEditorController _makeController({Post? initialPost}) {
  return NoteEditorController(
    titleController: TextEditingController(),
    contentController: TextEditingController(),
    linkController: TextEditingController(),
    arxivController: TextEditingController(),
    initialPost: initialPost,
  );
}

Post _post(Map<String, dynamic> overrides) {
  return Post.fromJson({
    'id': '1',
    'title': 'T',
    'content': 'C',
    'mainDiscipline': '计算机科学',
    'author': {'id': 'a1', 'name': 'Alice'},
    ...overrides,
  });
}

void main() {
  group('NoteEditorController — 初始状态', () {
    test('新建模式：isEditing 为 false，集合为空', () {
      final c = _makeController();
      addTearDown(c.dispose);

      expect(c.isEditing, false);
      expect(c.images, isEmpty);
      expect(c.existingImageUrls, isEmpty);
      expect(c.externalLinks, isEmpty);
      expect(c.selectedReferences, isEmpty);
      expect(c.selectedDiscipline, isNull);
      expect(c.hasPdf, false);
      expect(c.showAdvancedOptions, false);
      expect(c.showDisciplineDropdown, false);
      expect(c.showTagSuggestions, false);
      expect(c.arxivMetadata, isNull);
    });

    test('编辑模式：构造时回填标题/正文/分区/链接/引用', () {
      final post = _post({
        'title': '已有标题',
        'content': '已有正文',
        'mainDiscipline': '物理学',
        'externalLinks': ['https://a.com', 'https://b.com'],
        'references': [10, 20],
      });
      final c = _makeController(initialPost: post);
      addTearDown(c.dispose);

      expect(c.isEditing, true);
      expect(c.titleController.text, '已有标题');
      expect(c.contentController.text, '已有正文');
      expect(c.selectedDiscipline, '物理学');
      expect(c.externalLinks, ['https://a.com', 'https://b.com']);
      expect(c.selectedReferences, [10, 20]);
    });

    test('编辑模式：媒体按图片/PDF 区分，PDF 只取第一份', () {
      final post = _post({
        'media': [
          'https://x.com/a.png',
          'https://x.com/doc.pdf',
          'https://x.com/b.jpg',
          'https://x.com/second.pdf',
        ],
      });
      final c = _makeController(initialPost: post);
      addTearDown(c.dispose);

      expect(c.existingImageUrls, [
        'https://x.com/a.png',
        'https://x.com/b.jpg',
      ]);
      expect(c.existingPdfUrl, 'https://x.com/doc.pdf');
      expect(c.hasPdf, true);
    });

    test('编辑模式：含 arxivId 时回填 arXiv 元数据', () {
      final post = _post({
        'arxivId': '1234.5678',
        'doi': '10.1/x',
        'journal': 'Nature',
        'year': 2020,
        'arxivAuthors': ['Bob'],
        'arxivCategories': ['cs.AI'],
      });
      final c = _makeController(initialPost: post);
      addTearDown(c.dispose);

      expect(c.arxivId, '1234.5678');
      expect(c.arxivMetadata, isNotNull);
      expect(c.arxivMetadata!.id, '1234.5678');
      expect(c.arxivController.text, '1234.5678');
      expect(c.arxivDoi, '10.1/x');
      expect(c.arxivJournal, 'Nature');
      expect(c.arxivYear, 2020);
    });
  });

  group('NoteEditorController — UI 状态变更', () {
    test('toggleAdvancedOptions 触发 notifyListeners 并翻转', () {
      final c = _makeController();
      addTearDown(c.dispose);
      var notified = 0;
      c.addListener(() => notified++);

      c.toggleAdvancedOptions();
      expect(c.showAdvancedOptions, true);
      expect(notified, 1);
      c.toggleAdvancedOptions();
      expect(c.showAdvancedOptions, false);
      expect(notified, 2);
    });

    test('selectDiscipline 设置分区并关闭下拉', () {
      final c = _makeController();
      addTearDown(c.dispose);
      c.toggleDisciplineDropdown();
      expect(c.showDisciplineDropdown, true);

      c.selectDiscipline('数学');
      expect(c.selectedDiscipline, '数学');
      expect(c.showDisciplineDropdown, false);
    });

    test('closeDisciplineDropdown 收起下拉', () {
      final c = _makeController();
      addTearDown(c.dispose);
      c.toggleDisciplineDropdown();
      c.closeDisciplineDropdown();
      expect(c.showDisciplineDropdown, false);
    });
  });

  group('NoteEditorController — 图片 / 链接 / 引用变更', () {
    test('addImage 最多 9 张', () {
      final c = _makeController();
      addTearDown(c.dispose);
      for (var i = 0; i < 12; i++) {
        c.addImage(XFile('/tmp/$i.png'));
      }
      expect(c.images.length, 9);
    });

    test('removeImage 按索引删除', () {
      final c = _makeController();
      addTearDown(c.dispose);
      c.addImage(XFile('/tmp/0.png'));
      c.addImage(XFile('/tmp/1.png'));
      c.removeImage(0);
      expect(c.images.length, 1);
      expect(c.images.first.path, '/tmp/1.png');
    });

    test('removeExistingImage 按索引删除已有图片', () {
      final post = _post({
        'media': ['https://x.com/a.png', 'https://x.com/b.png'],
      });
      final c = _makeController(initialPost: post);
      addTearDown(c.dispose);
      c.removeExistingImage(0);
      expect(c.existingImageUrls, ['https://x.com/b.png']);
    });

    test('外部链接 add / remove', () {
      final c = _makeController();
      addTearDown(c.dispose);
      c.addExternalLink('https://a.com');
      c.addExternalLink('https://b.com');
      expect(c.externalLinks, ['https://a.com', 'https://b.com']);
      // addExternalLink 会清空输入框
      expect(c.linkController.text, '');
      c.removeExternalLink('https://a.com');
      expect(c.externalLinks, ['https://b.com']);
    });

    test('引用 toggle 选中 / 取消、去重、remove', () {
      final c = _makeController();
      addTearDown(c.dispose);
      c.toggleReference(5, true);
      c.toggleReference(5, true); // 重复不应再加
      expect(c.selectedReferences, [5]);
      c.toggleReference(7, true);
      expect(c.selectedReferences, [5, 7]);
      c.toggleReference(5, false);
      expect(c.selectedReferences, [7]);
      c.removeReference(7);
      expect(c.selectedReferences, isEmpty);
    });

    test('PDF setPdf / removePdf / removeExistingPdf', () {
      final c = _makeController();
      addTearDown(c.dispose);
      expect(c.hasPdf, false);
      c.setPdf(file: File('/tmp/x.pdf'), name: 'x.pdf');
      expect(c.hasPdf, true);
      expect(c.pdfFileName, 'x.pdf');
      c.removePdf();
      expect(c.hasPdf, false);
      expect(c.pdfFile, isNull);
    });
  });

  group('NoteEditorController — 标签引擎 (NoteTagLogic)', () {
    test('extractTagsFromText 提取去重 #标签', () {
      final c = _makeController();
      addTearDown(c.dispose);
      final tags = c.extractTagsFromText('hello #ml world #ml #nlp end');
      expect(tags, {'ml', 'nlp'});
    });

    test('getFilteredDisciplines 普通用户隐藏公告区', () {
      final c = _makeController();
      addTearDown(c.dispose);
      // 默认 currentUserRole 为 null -> 视为普通用户
      expect(c.getFilteredDisciplines().contains('公告区'), false);
    });

    test('selectTagSuggestion 将 # 输入替换为完整标签', () {
      final c = _makeController();
      addTearDown(c.dispose);
      c.contentController.text = '正文 #m';
      c.selectTagSuggestion('机器学习');
      expect(c.contentController.text, '正文 #机器学习 ');
      expect(c.showTagSuggestions, false);
    });

    test('onContentChanged：输入 #x 显示建议浮层', () {
      final c = _makeController();
      addTearDown(c.dispose);
      c.selectDiscipline('计算机科学');
      c.onContentChanged('hello #x');
      expect(c.showTagSuggestions, true);
      expect(c.currentTagInput, 'x');
    });

    test('onContentChanged：# 后接空格视为标签结束，隐藏建议', () {
      final c = _makeController();
      addTearDown(c.dispose);
      c.onContentChanged('hello #x');
      expect(c.showTagSuggestions, true);
      c.onContentChanged('hello #x ');
      expect(c.showTagSuggestions, false);
    });
  });

  group('NoteEditorController — 发布前校验 validateForSubmit', () {
    test('标题为空', () {
      final c = _makeController();
      addTearDown(c.dispose);
      expect(c.validateForSubmit(), '请输入标题');
    });

    test('正文为空', () {
      final c = _makeController();
      addTearDown(c.dispose);
      c.titleController.text = '标题';
      expect(c.validateForSubmit(), '请输入正文');
    });

    test('新建模式无图片', () {
      final c = _makeController();
      addTearDown(c.dispose);
      c.titleController.text = '标题';
      c.contentController.text = '正文';
      expect(c.validateForSubmit(), '请添加图片');
    });

    test('未选分区', () {
      final c = _makeController();
      addTearDown(c.dispose);
      c.titleController.text = '标题';
      c.contentController.text = '正文';
      c.addImage(XFile('/tmp/a.png'));
      expect(c.validateForSubmit(), '请选择一个学科分区');
    });

    test('全部满足返回 null', () {
      final c = _makeController();
      addTearDown(c.dispose);
      c.titleController.text = '标题';
      c.contentController.text = '正文';
      c.addImage(XFile('/tmp/a.png'));
      c.selectDiscipline('数学');
      expect(c.validateForSubmit(), isNull);
    });

    test('编辑模式无图片也可通过（只改文字）', () {
      final post = _post({'title': 'T', 'content': 'C'});
      final c = _makeController(initialPost: post);
      addTearDown(c.dispose);
      // 编辑模式已回填 title/content/discipline，无新图片
      expect(c.validateForSubmit(), isNull);
    });
  });

  group('NoteEditorController — dispose 安全', () {
    test('dispose 后 isDisposed 为 true', () {
      final c = _makeController();
      c.dispose();
      expect(c.isDisposed, true);
    });

    test('dispose 后 notifyListeners 不再触发监听（无 used-after-dispose 断言）', () {
      final c = _makeController();
      var notified = 0;
      c.addListener(() => notified++);
      c.dispose();
      // 直接触发受保护的 notifyListeners（经由公共可变方法）
      c.toggleAdvancedOptions();
      expect(notified, 0);
    });
  });

  group('NoteSubmitResult', () {
    test('validationFailed 携带 message', () {
      const r = NoteSubmitResult.validationFailed('请输入标题');
      expect(r.kind, NoteSubmitKind.validationFailed);
      expect(r.message, '请输入标题');
      expect(r.isSuccess, false);
    });

    test('createSuccess / editSuccess isSuccess 为 true', () {
      const create = NoteSubmitResult(NoteSubmitKind.createSuccess);
      const edit = NoteSubmitResult(NoteSubmitKind.editSuccess);
      expect(create.isSuccess, true);
      expect(edit.isSuccess, true);
    });
  });
}
