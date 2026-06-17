// lib/screens/note_editor/note_editor_data_loading.dart
//
// 笔记编辑器的远程数据加载子系统：当前用户角色 + 引用候选（我的帖子 / 收藏）。
// 作为 mixin 混入 [NoteEditorController]，持有这些只读数据状态。
// 拆分为独立文件以遵守单文件 ≤300 行；mixin 是组合机制，非 part-of 假拆分。

import 'dart:convert';

import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint;

import '../../models/post_model.dart';
import '../../models/user_profile.dart';
import '../../services/api_service.dart';
import '../../services/local_storage.dart';

mixin NoteEditorDataLoading on ChangeNotifier {
  // 当前用户角色
  String? _currentUserRole;

  // 引用文献候选
  List<Post> _userPosts = [];
  List<Post> _userFavorites = [];
  bool _isLoadingReferences = false;

  String? get currentUserRole => _currentUserRole;
  List<Post> get userPosts => List.unmodifiable(_userPosts);
  List<Post> get userFavorites => List.unmodifiable(_userFavorites);
  bool get isLoadingReferences => _isLoadingReferences;

  /// 加载当前用户角色
  Future<void> loadCurrentUserRole() async {
    try {
      // 尝试从API获取当前用户信息
      final response = await ApiService.getCurrentUserProfile();
      final status = response['statusCode'] as int? ?? 500;

      if (status >= 200 && status < 300) {
        final body = response['body'] as Map<String, dynamic>?;
        if (body != null) {
          final userProfile = UserProfile.fromJson(body);
          _currentUserRole = userProfile.role.toUpperCase();
          notifyListeners();
          return;
        }
      }

      // 如果API调用失败，尝试从本地存储获取
      final userJson = LocalStorage.instance.read('currentUser');
      if (userJson != null) {
        try {
          final userData = jsonDecode(userJson) as Map<String, dynamic>;
          final userProfile = UserProfile.fromJson(userData);
          _currentUserRole = userProfile.role.toUpperCase();
          notifyListeners();
          return;
        } catch (e) {
          debugPrint('解析本地用户数据失败: $e');
        }
      }

      // 如果都失败，设置为普通用户
      _currentUserRole = 'USER';
      notifyListeners();
    } catch (e) {
      debugPrint('获取用户角色失败: $e');
      // 失败时设置为普通用户
      _currentUserRole = 'USER';
      notifyListeners();
    }
  }

  /// 加载用户的帖子和收藏（用于引用文献选择）
  Future<void> loadUserPostsAndFavorites() async {
    _isLoadingReferences = true;
    notifyListeners();

    try {
      // 获取当前用户信息
      final userResp = await ApiService.getCurrentUserProfile();
      if (userResp['statusCode'] == 200) {
        final userId = userResp['body']['id']?.toString();

        // 检查用户ID是否存在
        if (userId == null || userId.isEmpty) {
          debugPrint('用户ID为空，无法加载引用文献');
          return;
        }

        // 并行加载用户帖子和收藏
        final results = await Future.wait([
          ApiService.getUserPosts(userId, page: 1, pageSize: 50),
          ApiService.getUserFavorites(userId, page: 1, pageSize: 50),
        ]);

        final postsResp = results[0];
        final favoritesResp = results[1];

        if (postsResp['statusCode'] == 200) {
          final postsData = postsResp['body']['posts'] as List<dynamic>? ?? [];
          _userPosts = postsData.map((p) => Post.fromJson(p)).toList();
          notifyListeners();
        }

        if (favoritesResp['statusCode'] == 200) {
          final favoritesData =
              favoritesResp['body']['posts'] as List<dynamic>? ?? [];
          _userFavorites = favoritesData.map((p) => Post.fromJson(p)).toList();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('加载用户帖子和收藏失败: $e');
    } finally {
      _isLoadingReferences = false;
      notifyListeners();
    }
  }
}
