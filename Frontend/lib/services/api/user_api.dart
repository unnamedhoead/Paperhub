import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/http_client.dart';

class UserApi {
  /// 获取当前登录用户的资料
  static Future<Map<String, dynamic>> getCurrentUserProfile() async {
    return HttpClient.instance.get('/users/me');
  }

  /// 获取指定用户的资料
  static Future<Map<String, dynamic>> getUserProfile(String userId) async {
    return HttpClient.instance.get('/users/$userId');
  }

  /// 获取当前用户的隐私设置
  static Future<Map<String, dynamic>> getPrivacySettings() async {
    return HttpClient.instance.get('/users/me/privacy');
  }

  /// 更新当前用户的个人资料
  static Future<Map<String, dynamic>> updateProfile({
    required String displayName,
    String? bio,
    List<String>? researchDirections,
    String? avatarUrl,
    String? backgroundImage,
  }) async {
    final payload = <String, dynamic>{
      'name': displayName,
      if (bio != null) 'bio': bio,
      if (researchDirections != null) 'researchDirections': researchDirections,
      if (avatarUrl != null) 'avatar': avatarUrl,
      if (backgroundImage != null) 'backgroundImage': backgroundImage,
    };
    return HttpClient.instance.put('/users/me', body: payload);
  }

  /// 更新当前用户的隐私设置
  static Future<Map<String, dynamic>> updatePrivacySettings({
    required bool hideFollowing,
    required bool hideFollowers,
    required bool publicFavorites,
  }) async {
    return HttpClient.instance.put('/users/me/privacy', body: {
      'hideFollowing': hideFollowing,
      'hideFollowers': hideFollowers,
      'publicFavorites': publicFavorites,
    });
  }

  /// 上传头像（字节数据）
  static Future<Map<String, dynamic>> uploadAvatarBytes(
    Uint8List data,
    String fileName,
  ) async {
    return HttpClient.instance.multipart('POST', '/users/me/avatar', files: [
      http.MultipartFile.fromBytes('file', data, filename: fileName),
    ]);
  }

  /// 上传个人主页背景图（字节数据）
  static Future<Map<String, dynamic>> uploadBackgroundBytes(
    Uint8List data,
    String fileName,
  ) async {
    return HttpClient.instance.multipart('POST', '/users/me/background',
        files: [
          http.MultipartFile.fromBytes('file', data, filename: fileName),
        ]);
  }

  /// 搜索用户（用于 @ 功能）
  /// GET /users/search?q=name&type=following|all
  static Future<Map<String, dynamic>> searchUsers({
    required String query,
    String type = 'all',
    int page = 0,
    int pageSize = 20,
  }) async {
    return HttpClient.instance.get('/users/search', queryParameters: {
      'q': query,
      'type': type,
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    });
  }

  /// 获取用户的帖子列表
  static Future<Map<String, dynamic>> getUserPosts(
    String userId, {
    int page = 1,
    int pageSize = 10,
  }) async {
    return HttpClient.instance.get('/users/$userId/posts',
        queryParameters: {
          'page': page.toString(),
          'pageSize': pageSize.toString(),
        });
  }

  /// 获取用户的收藏列表
  static Future<Map<String, dynamic>> getUserFavorites(
    String userId, {
    int page = 1,
    int pageSize = 10,
  }) async {
    return HttpClient.instance.get('/users/$userId/favorites',
        queryParameters: {
          'page': page.toString(),
          'pageSize': pageSize.toString(),
        });
  }

  /// 获取用户的草稿列表
  static Future<Map<String, dynamic>> getUserDrafts({
    int page = 1,
    int pageSize = 20,
  }) async {
    return HttpClient.instance.get('/posts/drafts', queryParameters: {
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    });
  }
}
