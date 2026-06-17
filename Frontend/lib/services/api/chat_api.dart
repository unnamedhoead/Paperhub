import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/http_client.dart';

class ChatApi {
  /// 获取会话列表
  /// GET /api/conversations
  static Future<Map<String, dynamic>> getConversations() async {
    return HttpClient.instance.get('/api/conversations');
  }

  /// 创建或获取私聊会话
  /// POST /api/conversations
  static Future<Map<String, dynamic>> createOrGetConversation(
    String targetUserId,
  ) async {
    return HttpClient.instance.post('/api/conversations', body: {
      'targetUserId': int.tryParse(targetUserId) ?? 0,
    });
  }

  /// 获取会话消息列表
  /// GET /api/conversations/{conversationId}/messages
  static Future<Map<String, dynamic>> getConversationMessages(
    String conversationId, {
    int page = 0,
    int pageSize = 100,
  }) async {
    return HttpClient.instance.get(
        '/api/conversations/$conversationId/messages',
        queryParameters: {
          'page': page.toString(),
          'size': pageSize.toString(),
        });
  }

  /// 发送消息
  /// POST /api/conversations/{conversationId}/messages
  static Future<Map<String, dynamic>> sendMessage(
    String conversationId,
    String content, {
    String type = 'TEXT',
    String? fileUrl,
    String? fileName,
    int? fileSize,
  }) async {
    final body = <String, dynamic>{
      'content': content,
      'type': type,
      if (fileUrl != null) 'fileUrl': fileUrl,
      if (fileName != null) 'fileName': fileName,
      if (fileSize != null) 'fileSize': fileSize,
    };
    return HttpClient.instance.post(
        '/api/conversations/$conversationId/messages',
        body: body);
  }

  /// 发送带媒体的消息
  /// POST /api/conversations/{conversationId}/messages
  static Future<Map<String, dynamic>> sendMessageWithMedia(
    String conversationId,
    List<String> mediaUrls, {
    String type = 'IMAGE',
    String content = '',
    String? fileName,
    int? fileSize,
  }) async {
    final body = <String, dynamic>{
      'content': content,
      'type': type,
      'mediaUrls': mediaUrls,
      if (fileName != null) 'fileName': fileName,
      if (fileSize != null) 'fileSize': fileSize,
    };
    return HttpClient.instance.post(
        '/api/conversations/$conversationId/messages',
        body: body);
  }

  /// 标记会话为已读
  /// PUT /api/conversations/{conversationId}/read
  static Future<Map<String, dynamic>> markConversationAsRead(
    String conversationId,
  ) async {
    return HttpClient.instance.put(
        '/api/conversations/$conversationId/read');
  }

  /// 上传聊天文件
  /// POST /api/upload/chat-file
  static Future<Map<String, dynamic>> uploadChatFile(
    List<int> fileBytes,
    String fileName,
  ) async {
    return HttpClient.instance.multipart('POST', '/api/upload/chat-file',
        files: [
          http.MultipartFile.fromBytes('file', Uint8List.fromList(fileBytes),
              filename: fileName),
        ]);
  }
}
