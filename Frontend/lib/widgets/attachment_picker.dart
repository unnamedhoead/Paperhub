/// 附件选择器 — 附件类型选择底部弹窗 + 文件选取 + 上传逻辑
///
/// 提供以下功能：
/// - 图片/视频选择（从相册或相机）
/// - 文件选择
/// - 音频文件选择
/// - 文件上传到服务器
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../services/local_storage.dart';
import '../config/app_env.dart';

class AttachmentPicker {
  /// 显示附件类型选择底部弹窗
  static void showAttachmentOptions(
    BuildContext context, {
    required Function(List<String> mediaUrls, String messageType,
            String fileName, int fileSize)
        onSendMedia,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '选择附件类型',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF1976D2)),
              title: const Text('图片和视频'),
              subtitle: const Text('从相册选择图片或视频'),
              onTap: () {
                Navigator.pop(ctx);
                _pickMedia(context, onSendMedia: onSendMedia);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF1976D2)),
              title: const Text('拍照'),
              subtitle: const Text('使用相机拍照'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera, context,
                    onSendMedia: onSendMedia);
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file, color: Color(0xFF1976D2)),
              title: const Text('文件'),
              subtitle: const Text('选择文档文件'),
              onTap: () {
                Navigator.pop(ctx);
                _pickFile(context, onSendMedia: onSendMedia);
              },
            ),
            ListTile(
              leading: const Icon(Icons.mic, color: Color(0xFF1976D2)),
              title: const Text('语音文件'),
              subtitle: const Text('上传音频文件'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAudioFile(context, onSendMedia: onSendMedia);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  static Future<void> _pickMedia(
    BuildContext context, {
    required Function(List<String> mediaUrls, String messageType,
            String fileName, int fileSize)
        onSendMedia,
  }) async {
    final ImagePicker picker = ImagePicker();
    final type = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择类型'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('图片'),
              onTap: () => Navigator.pop(ctx, 'IMAGE'),
            ),
            ListTile(
              leading: const Icon(Icons.video_library),
              title: const Text('视频'),
              onTap: () => Navigator.pop(ctx, 'VIDEO'),
            ),
          ],
        ),
      ),
    );

    if (type == null) return;

    final XFile? file;
    if (type == 'IMAGE') {
      file = await picker.pickImage(source: ImageSource.gallery);
    } else {
      file = await picker.pickVideo(source: ImageSource.gallery);
    }

    if (file != null) {
      await _uploadAndSendMediaFile(file, type, context,
          onSendMedia: onSendMedia);
    }
  }

  static Future<void> _pickImage(
    ImageSource source,
    BuildContext context, {
    required Function(List<String> mediaUrls, String messageType,
            String fileName, int fileSize)
        onSendMedia,
  }) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);
    if (image != null) {
      await _uploadAndSendMediaFile(image, 'IMAGE', context,
          onSendMedia: onSendMedia);
    }
  }

  static Future<void> _pickFile(
    BuildContext context, {
    required Function(List<String> mediaUrls, String messageType,
            String fileName, int fileSize)
        onSendMedia,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx',
        'txt', 'csv', 'zip', 'rar', '7z', 'exe', 'mp4',
      ],
    );
    if (result != null) {
      final file = result.files.single;
      await _uploadAndSendMediaBytes(
          file.bytes!, file.name, 'FILE', context,
          onSendMedia: onSendMedia);
    }
  }

  static Future<void> _pickAudioFile(
    BuildContext context, {
    required Function(List<String> mediaUrls, String messageType,
            String fileName, int fileSize)
        onSendMedia,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a', 'ogg', 'aac', 'webm'],
    );
    if (result != null) {
      final file = result.files.single;
      await _uploadAndSendMediaBytes(
          file.bytes!, file.name, 'VOICE', context,
          onSendMedia: onSendMedia);
    }
  }

  static Future<void> _uploadAndSendMediaFile(
    XFile file,
    String messageType,
    BuildContext context, {
    required Function(List<String> mediaUrls, String messageType,
            String fileName, int fileSize)
        onSendMedia,
  }) async {
    final bytes = await file.readAsBytes();
    await _uploadAndSendMediaBytes(bytes, file.name, messageType, context,
        onSendMedia: onSendMedia);
  }

  static Future<void> _uploadAndSendMediaBytes(
    List<int> bytes,
    String fileName,
    String messageType,
    BuildContext context, {
    required Function(List<String> mediaUrls, String messageType,
            String fileName, int fileSize)
        onSendMedia,
  }) async {
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final url = await uploadFileBytes(bytes, fileName);
      if (context.mounted) Navigator.pop(context);

      if (url != null) {
        onSendMedia([url], messageType, fileName, bytes.length);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('上传失败，未获取到文件URL')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('上传失败: $e')),
        );
      }
    }
  }

  /// 上传文件字节到服务器，返回文件URL
  static Future<String?> uploadFileBytes(
      List<int> bytes, String fileName) async {
    try {
      final String? token = LocalStorage.instance.read('accessToken');
      if (token == null) {
        throw Exception('未登录');
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppEnv.apiBaseUrl}/api/upload/chat-file'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
      ));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['url'];
      } else {
        throw Exception('上传失败: ${response.body}');
      }
    } catch (e) {
      return null;
    }
  }
}
