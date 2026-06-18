import 'dart:convert';
import 'dart:typed_data';

import '../../models/post_model.dart';
import '../../models/user_profile.dart';
import '../../services/api/auth_api.dart';
import '../../services/api/interaction_api.dart';
import '../../services/api/post_api.dart';
import '../../services/api/user_api.dart';
import '../../services/local_storage.dart';

/// Pure data-loading and mutation logic for profile. No BuildContext, no setState.
class ProfileController {
  /// Fetch the current user's own profile.
  static Future<UserProfile> loadOwnProfile({
    required String currentUserId,
    UserProfile? cached,
  }) async {
    final resp = await UserApi.getCurrentUserProfile();
    if (resp['statusCode'] != 200) {
      final message =
          (resp['body'] as Map<String, dynamic>?)?['message'] ?? '加载失败';
      throw Exception(message);
    }
    final payload = resp['body'] as Map<String, dynamic>;
    await LocalStorage.instance.write('currentUser', jsonEncode(payload));
    final id = payload['id'];
    if (id != null) {
      await LocalStorage.instance.write('userId', id.toString());
    }
    return UserProfile.fromJson(payload);
  }

  /// Fetch a specific user's profile.
  static Future<UserProfile> loadUserProfile(String userId) async {
    final resp = await UserApi.getUserProfile(userId);
    if (resp['statusCode'] != 200) {
      final message =
          (resp['body'] as Map<String, dynamic>?)?['message'] ?? '加载失败';
      throw Exception(message);
    }
    return UserProfile.fromJson(resp['body'] as Map<String, dynamic>);
  }

  /// Load authored posts with pagination.
  static Future<PostListResult> loadUserPosts(
    String userId, {
    int page = 1,
    int pageSize = 10,
  }) async {
    final resp = await UserApi.getUserPosts(userId,
        page: page, pageSize: pageSize);
    return _parsePostListResult(resp, 'posts');
  }

  /// Load favorite posts with pagination.
  static Future<PostListResult> loadFavoritePosts(
    String userId, {
    int page = 1,
    int pageSize = 10,
  }) async {
    final resp = await UserApi.getUserFavorites(userId,
        page: page, pageSize: pageSize);
    return _parsePostListResult(resp, 'posts');
  }

  /// Load draft posts with pagination.
  static Future<PostListResult> loadDraftPosts({
    int page = 1,
    int pageSize = 10,
  }) async {
    final resp = await UserApi.getUserDrafts(page: page, pageSize: pageSize);
    return _parsePostListResult(resp, 'posts');
  }

  /// Toggle follow state for a user. Returns the new isFollowing state.
  static Future<bool> toggleFollow(String userId, bool currentlyFollowing) async {
    final resp = currentlyFollowing
        ? await InteractionApi.unfollowUser(userId)
        : await InteractionApi.followUser(userId);
    if (resp['statusCode'] != 200) {
      throw Exception(
        (resp['body'] as Map<String, dynamic>?)?['message'] ?? '操作失败',
      );
    }
    return !currentlyFollowing;
  }

  /// Toggle like on a post. Returns updated likesCount and isLiked.
  static Future<LikeResult> toggleLike(String postId, bool isLiked) async {
    final resp = isLiked
        ? await InteractionApi.unlikePost(postId)
        : await InteractionApi.likePost(postId);
    if (resp['statusCode'] != 200) {
      throw Exception('操作失败');
    }
    final body = resp['body'] as Map<String, dynamic>?;
    return LikeResult(
      likesCount: (body?['likesCount'] as num?)?.toInt(),
      isLiked: body?['isLiked'] as bool?,
    );
  }

  /// Update user profile. Returns updated UserProfile.
  static Future<UserProfile> updateProfile({
    required String displayName,
    String? bio,
    List<String>? researchDirections,
    String? avatarUrl,
    String? backgroundImage,
  }) async {
    final resp = await UserApi.updateProfile(
      displayName: displayName,
      bio: bio,
      researchDirections: researchDirections,
      avatarUrl: avatarUrl,
      backgroundImage: backgroundImage,
    );
    if (resp['statusCode'] != 200) {
      final message =
          (resp['body'] as Map<String, dynamic>?)?['message'] ?? '保存失败';
      throw Exception(message);
    }
    // Reload profile after update
    return ProfileController.loadOwnProfile(currentUserId: '');
  }

  /// Upload avatar bytes, returns URL string or null.
  static Future<String?> uploadAvatar(Uint8List bytes, String fileName) async {
    final resp = await UserApi.uploadAvatarBytes(bytes, fileName);
    if (resp['statusCode'] != 200) {
      final message =
          (resp['body'] as Map<String, dynamic>?)?['message'] ?? '头像上传失败';
      throw Exception(message);
    }
    final body = resp['body'] as Map<String, dynamic>;
    return (body['url'] ?? body['avatar'])?.toString();
  }

  /// Upload background bytes, returns URL string or null.
  static Future<String?> uploadBackground(
      Uint8List bytes, String fileName) async {
    final resp = await UserApi.uploadBackgroundBytes(bytes, fileName);
    if (resp['statusCode'] != 200) {
      final message =
          (resp['body'] as Map<String, dynamic>?)?['message'] ?? '背景图上传失败';
      throw Exception(message);
    }
    final body = resp['body'] as Map<String, dynamic>;
    return (body['url'] ?? body['background'])?.toString();
  }

  /// Fetch a single post. Used for browse history.
  static Future<Post?> getPost(String postId) async {
    final resp = await PostApi.getPost(postId);
    final status = resp['statusCode'] as int? ?? 500;
    if (status == 200) {
      final body = resp['body'] as Map<String, dynamic>;
      return Post.fromJson(body);
    }
    return null;
  }

  /// Logout: clear auth tokens.
  static Future<void> logout() async {
    await AuthApi.logout();
  }

  static PostListResult _parsePostListResult(
    Map<String, dynamic> resp,
    String listKey,
  ) {
    if (resp['statusCode'] != 200) {
      return const PostListResult(posts: [], total: 0);
    }
    final body = resp['body'] as Map<String, dynamic>?;
    final data = (body?[listKey] as List<dynamic>?) ?? [];
    final total = body?['total'] as int? ?? data.length;
    final posts = data
        .map((item) => Post.fromJson(item as Map<String, dynamic>))
        .toList();
    return PostListResult(posts: posts, total: total);
  }
}

class PostListResult {
  final List<Post> posts;
  final int total;
  const PostListResult({required this.posts, required this.total});
}

class LikeResult {
  final int? likesCount;
  final bool? isLiked;
  const LikeResult({this.likesCount, this.isLiked});
}
