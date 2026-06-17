import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../models/post_model.dart';
import '../../models/user_profile.dart';
import '../../services/local_storage.dart';
import 'profile_controller.dart';

/// View-model for [ProfilePage]: owns the profile + post-list state and the
/// data-loading / mutation logic. Holds no [BuildContext]; UI side effects
/// (snacks, navigation) stay in the screen.
///
/// Loading errors that the screen used to surface via a SnackBar are reported
/// through [onError] so timing/behavior is preserved.
class ProfileViewController extends ChangeNotifier {
  /// Target user id; null means "the current user's own profile".
  final String? userId;

  /// Called when a background load fails (host shows a SnackBar).
  void Function(String message)? onError;

  ProfileViewController({required this.userId}) {
    currentUserId = LocalStorage.instance.read('userId');
  }

  String? currentUserId;
  UserProfile? profile;
  bool loading = true;
  bool saving = false;
  String? error;
  bool? isFollowing;

  List<Post> authoredPosts = [];
  List<Post> favoritePosts = [];
  List<Post> draftPosts = [];
  bool loadingAuthored = false;
  bool loadingFavorites = false;
  bool loadingDrafts = false;
  bool hasMoreAuthored = true;
  bool hasMoreFavorites = true;
  bool hasMoreDrafts = true;
  int _authoredPage = 1;
  int _favoritesPage = 1;
  int _draftsPage = 1;
  final Set<String> _likeInFlight = {};

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  bool get isViewingSelf {
    if (userId == null) return true;
    if (currentUserId == null) return false;
    return userId == currentUserId;
  }

  bool get canViewFavorites {
    if (profile == null) return false;
    if (isViewingSelf) return true;
    return profile!.publicFavorites;
  }

  /// Toggles the saving indicator (used by the screen during edit/upload flows).
  set isSaving(bool value) {
    saving = value;
    _notify();
  }

  // -- Profile loading --------------------------------------------------

  Future<void> loadProfile({bool forceNetwork = false}) async {
    loading = true;
    error = null;
    _notify();

    try {
      // Try cache first for own profile
      if (isViewingSelf && !forceNetwork) {
        final cached = LocalStorage.instance.read('currentUser');
        if (cached != null) {
          final payload = jsonDecode(cached) as Map<String, dynamic>;
          profile = UserProfile.fromJson(payload);
          isFollowing = profile!.isFollowing;
          _notify();
        }
      }

      if (userId == null) {
        final token = LocalStorage.instance.read('accessToken');
        if (token == null || token.isEmpty) {
          error = '请先登录';
          loading = false;
          _notify();
          return;
        }
      }

      UserProfile loaded;
      if (userId == null) {
        loaded = await ProfileController.loadOwnProfile(
          currentUserId: currentUserId ?? '',
          cached: profile,
        );
        // Refresh cached userId
        final uid = LocalStorage.instance.read('userId');
        if (uid != null) currentUserId = uid;
      } else {
        loaded = await ProfileController.loadUserProfile(userId!);
      }

      profile = loaded;
      isFollowing = loaded.isFollowing;
      loading = false;
      _notify();

      await Future.wait([
        loadUserPosts(refresh: true),
        if (canViewFavorites) loadFavoritePosts(refresh: true),
        if (isViewingSelf) loadDraftPosts(refresh: true),
      ]);
    } catch (e) {
      error = e.toString();
      loading = false;
      _notify();
    }
  }

  // -- Post lists -------------------------------------------------------

  Future<void> loadUserPosts({bool refresh = false}) async {
    if (profile == null || loadingAuthored) return;
    loadingAuthored = true;
    if (refresh) { _authoredPage = 1; hasMoreAuthored = true; authoredPosts = []; }
    _notify();
    final page = refresh ? 1 : _authoredPage;
    try {
      final result = await ProfileController.loadUserPosts(profile!.id, page: page);
      if (refresh) { authoredPosts = result.posts; } else { authoredPosts.addAll(result.posts); }
      hasMoreAuthored = authoredPosts.length < result.total;
      _authoredPage = page + 1;
      _notify();
    } catch (e) { onError?.call('加载我的笔记失败：$e'); }
    finally { loadingAuthored = false; _notify(); }
  }

  Future<void> loadFavoritePosts({bool refresh = false}) async {
    if (profile == null || !isViewingSelf && !canViewFavorites || loadingFavorites) return;
    loadingFavorites = true;
    if (refresh) { _favoritesPage = 1; hasMoreFavorites = true; favoritePosts = []; }
    _notify();
    final page = refresh ? 1 : _favoritesPage;
    try {
      final result = await ProfileController.loadFavoritePosts(profile!.id, page: page);
      if (refresh) { favoritePosts = result.posts; } else { favoritePosts.addAll(result.posts); }
      hasMoreFavorites = favoritePosts.length < result.total;
      _favoritesPage = page + 1;
      _notify();
    } catch (e) { onError?.call('加载收藏失败：$e'); }
    finally { loadingFavorites = false; _notify(); }
  }

  Future<void> loadDraftPosts({bool refresh = false}) async {
    if (!isViewingSelf || loadingDrafts) return;
    loadingDrafts = true;
    if (refresh) { _draftsPage = 1; hasMoreDrafts = true; draftPosts = []; }
    _notify();
    final page = refresh ? 1 : _draftsPage;
    try {
      final result = await ProfileController.loadDraftPosts(page: page);
      if (refresh) { draftPosts = result.posts; } else { draftPosts.addAll(result.posts); }
      hasMoreDrafts = draftPosts.length < result.total;
      _draftsPage = page + 1;
      _notify();
    } catch (e) { onError?.call('加载草稿失败：$e'); }
    finally { loadingDrafts = false; _notify(); }
  }

  /// Removes a post (e.g. after deletion in the detail screen) from the lists.
  void removePost(String postId) {
    authoredPosts.removeWhere((p) => p.id == postId);
    favoritePosts.removeWhere((p) => p.id == postId);
    _notify();
  }

  // -- Follow -----------------------------------------------------------

  /// Optimistically toggles follow state. Reports failures via [onError].
  Future<void> toggleFollow() async {
    if (profile == null || isViewingSelf || profile!.id.isEmpty) return;
    final targetId = profile!.id;
    final original = profile!.followersCount;
    final prev = isFollowing ?? false;
    final next = !prev;
    isFollowing = next;
    profile = profile!.copyWith(followersCount: next ? original + 1 : (original > 0 ? original - 1 : 0), isFollowing: next);
    _notify();
    try {
      await ProfileController.toggleFollow(targetId, prev);
    } catch (e) {
      isFollowing = prev;
      profile = profile!.copyWith(followersCount: original, isFollowing: prev);
      _notify();
      onError?.call('操作失败：$e');
    }
  }

  // -- Like -------------------------------------------------------------

  Future<bool> handlePostLike(Post post) async {
    if (_likeInFlight.contains(post.id)) return false;
    _likeInFlight.add(post.id);
    try {
      final result = await ProfileController.toggleLike(post.id, post.isLiked);
      void update(List<Post> list) {
        final idx = list.indexWhere((p) => p.id == post.id);
        if (idx != -1) {
          list[idx].likesCount = result.likesCount ?? list[idx].likesCount;
          list[idx].isLiked = result.isLiked ?? !list[idx].isLiked;
          _notify();
        }
      }
      update(authoredPosts);
      update(favoritePosts);
      return true;
    } catch (_) {
      return false;
    } finally { _likeInFlight.remove(post.id); }
  }

  // -- Profile edit / upload helpers ------------------------------------

  Future<String?> uploadIf(Uint8List? bytes, String? name, {required bool isAvatar}) async {
    if (bytes == null || bytes.isEmpty) return null;
    return isAvatar
        ? ProfileController.uploadAvatar(bytes, name ?? 'avatar.png')
        : ProfileController.uploadBackground(bytes, name ?? 'background.png');
  }

  /// Uploads a new background image and reloads the profile.
  Future<void> uploadBackgroundAndReload(Uint8List bytes, String fileName) async {
    final bgUrl = await ProfileController.uploadBackground(bytes, fileName);
    await ProfileController.updateProfile(
      displayName: profile!.displayName,
      bio: profile!.bio,
      researchDirections: profile!.researchDirections,
      backgroundImage: bgUrl,
    );
    await loadProfile(forceNetwork: true);
  }
}
