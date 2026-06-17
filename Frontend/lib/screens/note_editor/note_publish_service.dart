// lib/screens/note_editor/note_publish_service.dart
//
// 笔记发布管线（无状态，state-management-convention.md 类型 B）。
// 负责：上传图片 / PDF、组装 payload、调用后端 createPost / updatePost、
// 解析结果。不持有可变状态、不依赖 BuildContext，便于单测与替换依赖。

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import '../../config/app_env.dart';
import '../../models/post_model.dart';
import '../../services/api_service.dart';
import '../../services/local_storage.dart';
import 'note_editor_results.dart';

/// 发布管线所需的全部输入（由 [NoteEditorController] 从自身状态收集）。
class NotePublishInput {
  const NotePublishInput({
    required this.isEditing,
    required this.initialPostId,
    required this.title,
    required this.content,
    required this.images,
    required this.existingImageUrls,
    required this.pdfFile,
    required this.pdfFileBytes,
    required this.pdfFileName,
    required this.existingPdfUrl,
    required this.externalLinks,
    required this.mainDiscipline,
    required this.arxivId,
    required this.doi,
    required this.journal,
    required this.year,
    required this.arxivMetadataAuthors,
    required this.arxivMetadataCategories,
    required this.arxivPublishedDate,
    required this.references,
    this.statusOverride,
    this.customSuccessMessage,
  });

  final bool isEditing;
  final String? initialPostId;
  final String title;
  final String content;
  final List<XFile> images;
  final List<String> existingImageUrls;
  final File? pdfFile;
  final Uint8List? pdfFileBytes;
  final String? pdfFileName;
  final String? existingPdfUrl;
  final List<String> externalLinks;
  final String mainDiscipline;
  final String? arxivId;
  final String? doi;
  final String? journal;
  final int? year;
  final List<String>? arxivMetadataAuthors;
  final List<String>? arxivMetadataCategories;
  final String? arxivPublishedDate;
  final List<int> references;
  final String? statusOverride;
  final String? customSuccessMessage;
}

class NotePublishService {
  const NotePublishService();

  /// 上传图片或 PDF 到后端，返回 URL。
  // Bug Fix 1：fileType 参数从 String 改为 UploadFileType 枚举
  Future<String?> uploadFileToServer(
    XFile file,
    UploadFileType fileType,
  ) async {
    try {
      final uri = Uri.parse('${AppEnv.apiBaseUrl}/posts/upload');
      final request = http.MultipartRequest('POST', uri);

      if (fileType == UploadFileType.image) {
        if (kIsWeb) {
          final bytes = await file.readAsBytes();
          request.files.add(
            http.MultipartFile.fromBytes(
              'file',
              bytes,
              filename: file.name,
              contentType: MediaType(
                'image',
                file.mimeType?.split('/').last ?? 'jpeg',
              ),
            ),
          );
        } else {
          request.files.add(
            await http.MultipartFile.fromPath('file', file.path),
          );
        }
      } else if (fileType == UploadFileType.pdf) {
        if (kIsWeb) {
          final bytes = await file.readAsBytes();
          request.files.add(
            http.MultipartFile.fromBytes(
              'file',
              bytes,
              filename: file.name,
              contentType: MediaType('application', 'pdf'),
            ),
          );
        } else {
          request.files.add(
            await http.MultipartFile.fromPath('file', file.path),
          );
        }
      } else {
        debugPrint('不支持的文件类型');
        return null;
      }

      final response = await request.send();
      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        final data = jsonDecode(respStr) as Map<String, dynamic>;
        return data['url'] as String?;
      } else {
        debugPrint('上传失败: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('上传文件失败: $e');
      return null;
    }
  }

  /// 执行发布 / 编辑：上传媒体 -> 组装 payload -> 调用后端 -> 解析结果。
  /// 调用方应已完成前置校验（标题 / 正文 / 图片 / 分区）。
  Future<NoteSubmitResult> submit(NotePublishInput input) async {
    final customSuccessMessage = input.customSuccessMessage;
    try {
      List<String> mediaUrls = [];

      // 往里面加已有的图片 URL
      mediaUrls.addAll(input.existingImageUrls);

      // 2) 上传新选择的图片
      for (var img in input.images) {
        final url = await uploadFileToServer(img, UploadFileType.image);
        if (url != null) mediaUrls.add(url);
      }

      // 3) 处理 PDF：优先使用新选择的 PDF，其次沿用旧的 URL
      String? pdfUrlToUse;
      if (input.pdfFile != null) {
        XFile pdfXFile;
        if (kIsWeb) {
          if (input.pdfFileBytes == null) {
            return const NoteSubmitResult.pdfDataError('PDF 文件数据异常，请重新选择');
          }
          pdfXFile = XFile.fromData(
            input.pdfFileBytes!,
            name: input.pdfFileName ?? 'document.pdf',
            mimeType: 'application/pdf',
          );
        } else {
          pdfXFile = XFile(input.pdfFile!.path);
        }
        pdfUrlToUse = await uploadFileToServer(pdfXFile, UploadFileType.pdf);
      } else if (input.existingPdfUrl != null) {
        pdfUrlToUse = input.existingPdfUrl;
      }

      if (pdfUrlToUse != null) {
        mediaUrls.add(pdfUrlToUse);
      }

      // 4) 外部链接（过滤空字符串）
      final links =
          input.externalLinks.where((e) => e.trim().isNotEmpty).toList();

      // 6) 调用后端接口：新建 or 更新
      final String? normalizedStatus = input.statusOverride?.toUpperCase();

      Map<String, dynamic> resp;
      if (input.isEditing && input.initialPostId != null) {
        // === 编辑已有帖子 ===
        resp = await ApiService.updatePost(
          postId: input.initialPostId!,
          title: input.title,
          content: input.content.isNotEmpty ? input.content : null,
          media: mediaUrls,
          mainDiscipline: input.mainDiscipline,
          doi: input.doi,
          journal: input.journal,
          year: input.year,
          externalLinks: links.isNotEmpty ? links : null,
          arxivId: input.arxivId,
          arxivAuthors: input.arxivMetadataAuthors,
          arxivPublishedDate: input.arxivPublishedDate,
          arxivCategories: input.arxivMetadataCategories,
          references: input.references.isNotEmpty ? input.references : null,
          status: normalizedStatus,
        );
      } else {
        // === 新建帖子 ===
        resp = await ApiService.createPost(
          title: input.title,
          content: input.content.isNotEmpty ? input.content : null,
          media: mediaUrls.isNotEmpty ? mediaUrls : null,
          mainDiscipline: input.mainDiscipline,
          doi: input.doi,
          journal: input.journal,
          year: input.year,
          externalLinks: links.isNotEmpty ? links : null,
          arxivId: input.arxivId,
          arxivAuthors: input.arxivMetadataAuthors,
          arxivPublishedDate: input.arxivPublishedDate,
          arxivCategories: input.arxivMetadataCategories,
          references: input.references.isNotEmpty ? input.references : null,
          status: normalizedStatus,
        );
      }

      final status = resp['statusCode'] as int? ?? 500;
      final body = resp['body'] as Map<String, dynamic>?;

      if (status >= 200 && status < 300) {
        Post? createdPost;
        Map<String, dynamic>? createdPostRaw;
        // 尝试从响应体解析新建的帖子，并缓存原始 JSON 以便首页置顶显示
        if (!input.isEditing && body != null) {
          final raw = body['post'] ?? body;
          if (raw is Map<String, dynamic>) {
            createdPostRaw = raw;
            createdPost = Post.fromJson(raw);
          }
        }

        final successMessage = customSuccessMessage ??
            (input.isEditing ? '笔记已更新' : '发布成功');

        if (input.isEditing) {
          return NoteSubmitResult(
            NoteSubmitKind.editSuccess,
            createdPost: createdPost,
            successMessage: successMessage,
          );
        }

        // 新建笔记：把新帖子缓存到本地，用于首页临时置顶展示
        if (createdPostRaw != null) {
          try {
            LocalStorage.instance
                .write('lastCreatedPost', jsonEncode(createdPostRaw));
          } catch (e) {
            debugPrint('缓存新建帖子到本地失败: $e');
          }
        }
        return NoteSubmitResult(
          NoteSubmitKind.createSuccess,
          createdPost: createdPost,
          createdPostRaw: createdPostRaw,
          successMessage: successMessage,
        );
      } else {
        final msg = body != null && body['message'] != null
            ? body['message'].toString()
            : (input.isEditing ? '保存失败' : '发布失败');
        return NoteSubmitResult.failure(msg);
      }
    } catch (e) {
      return NoteSubmitResult.error(
        input.isEditing ? '保存失败，网络错误' : '发布失败，网络错误',
      );
    }
  }
}
