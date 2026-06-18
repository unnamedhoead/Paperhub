/// Controller for follow/follower/mutual list state management.
///
/// Extracted from [FollowListScreen] to separate data loading and
/// state management from UI rendering.
import 'package:flutter/foundation.dart';
import '../models/user_summary.dart';
import '../services/api/interaction_api.dart';

class FollowController extends ChangeNotifier {
  final String userId;
  final String type; // 'following', 'followers', 'mutual'

  List<UserSummary> users = [];
  bool isFetching = false;
  bool refreshing = false;
  bool loadingMore = false;
  bool hasMore = true;
  int page = 0;
  final int pageSize = 20;
  String? forbiddenMessage;

  FollowController({
    required this.userId,
    required this.type,
  });

  /// Load users from the API.
  Future<void> loadUsers({bool loadMore = false}) async {
    if (isFetching || (loadMore && (!hasMore || forbiddenMessage != null))) {
      return;
    }

    isFetching = true;
    if (loadMore) {
      loadingMore = true;
    } else {
      refreshing = users.isNotEmpty;
      page = 0;
      if (users.isEmpty) {
        refreshing = false;
      }
      forbiddenMessage = null;
    }
    notifyListeners();

    try {
      final resp = await _fetchUsers(page: page);

      if (resp['statusCode'] == 200) {
        final body = resp['body'] as Map<String, dynamic>?;
        if (body == null) return;

        final usersData = (body['users'] as List<dynamic>?) ??
            (body['data'] as List<dynamic>?) ??
            (body['followers'] as List<dynamic>?) ??
            (body['following'] as List<dynamic>?) ??
            [];

        final fetched = usersData
            .map((e) {
              try {
                return UserSummary.fromJson(e as Map<String, dynamic>);
              } catch (_) {
                return null;
              }
            })
            .whereType<UserSummary>()
            .map((user) {
              if (type == 'followers') {
                return user.copyWith(isFollower: user.isFollower ?? true);
              }
              if (type == 'following') {
                return user.copyWith(isFollowing: user.isFollowing ?? true);
              }
              return user;
            })
            .toList();

        final total = (body['total'] as num?)?.toInt() ??
            (body['count'] as num?)?.toInt() ??
            fetched.length;

        if (loadMore) {
          users.addAll(fetched);
          page++;
        } else {
          users = fetched;
          page = 1;
        }
        hasMore = users.length < total;
      } else if (resp['statusCode'] == 403) {
        forbiddenMessage =
            (resp['body'] as Map<String, dynamic>?)?['message'] ??
                '对方已隐藏该列表';
        users = [];
        hasMore = false;
      }
    } finally {
      isFetching = false;
      refreshing = false;
      loadingMore = false;
      notifyListeners();
    }
  }

  /// Scroll-triggered load more.
  Future<void> loadMore() async {
    if (!hasMore || isFetching) return;
    await loadUsers(loadMore: true);
  }

  /// Public reload (for parent to call).
  void reload() {
    loadUsers();
  }

  /// Handle a local follow/unfollow change and update the list.
  void handleLocalChange(UserSummary user) {
    _upsertOrRemove(user);
    notifyListeners();
  }

  /// Apply an external update (from another tab) to this list.
  void applyExternalUpdate(UserSummary user) {
    if (!_shouldDisplay(user) &&
        !users.any((element) => element.id == user.id)) {
      return;
    }
    _upsertOrRemove(user);
    notifyListeners();
  }

  void _upsertOrRemove(UserSummary user) {
    final shouldExist = _shouldDisplay(user);
    final index = users.indexWhere((u) => u.id == user.id);
    if (shouldExist) {
      if (index >= 0) {
        users[index] = user;
      } else {
        users.insert(0, user);
      }
    } else {
      if (index >= 0) {
        users.removeAt(index);
      }
    }
  }

  bool _shouldDisplay(UserSummary user) {
    switch (type) {
      case 'following':
        return user.isFollowing ?? false;
      case 'followers':
        return user.isFollower ?? false;
      case 'mutual':
        return (user.isFollowing ?? false) && (user.isFollower ?? false);
      default:
        return false;
    }
  }

  Future<Map<String, dynamic>> _fetchUsers({required int page}) {
    switch (type) {
      case 'followers':
        return InteractionApi.getFollowers(userId, page: page, pageSize: pageSize);
      case 'mutual':
        return InteractionApi.getMutualFollowers(userId, page: page, pageSize: pageSize);
      default:
        return InteractionApi.getFollowing(userId, page: page, pageSize: pageSize);
    }
  }
}
