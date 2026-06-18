// lib/screens/follow/follow_tab.dart
/// 单个Tab的内容（关注/粉丝/互相关注），含加载/空态/列表渲染
import 'package:flutter/material.dart';
import '../../models/user_summary.dart';
import '../../services/api_service.dart';
import 'follow_tab_views.dart';
import 'follow_user_list_item.dart';

/// 单个Tab的内容（关注/粉丝/互相关注）
class FollowTab extends StatefulWidget {
  final String userId;
  final String type; // 'following', 'followers', 'mutual'
  final void Function(String sourceType, UserSummary user)? onRelationshipChanged;

  /// 从某个用户的个人主页返回时回调，用于让上层统一刷新其他Tab
  final VoidCallback? onProfileReturned;

  const FollowTab({
    Key? key,
    required this.userId,
    required this.type,
    this.onRelationshipChanged,
    this.onProfileReturned,
  }) : super(key: key);

  @override
  State<FollowTab> createState() => FollowTabState();
}

class FollowTabState extends State<FollowTab>
    with AutomaticKeepAliveClientMixin<FollowTab> {
  List<UserSummary> _users = [];
  bool _isFetching = false;
  bool _refreshing = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 0;
  final int _pageSize = 20;
  final ScrollController _scrollController = ScrollController();
  String? _forbiddenMessage;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadUsers({bool loadMore = false}) async {
    if (_isFetching || (loadMore && (!_hasMore || _forbiddenMessage != null))) return;
    setState(() {
      _isFetching = true;
      if (loadMore) {
        _loadingMore = true;
      } else {
        _refreshing = _users.isNotEmpty;
        _page = 0;
        if (_users.isEmpty) {
          _refreshing = false;
        }
        // 手动刷新时清除之前的禁止访问提示，重新尝试
        _forbiddenMessage = null;
      }
    });

    try {
      final resp = await _fetchUsers(page: _page);

      if (resp['statusCode'] == 200) {
        final body = resp['body'] as Map<String, dynamic>?;
        if (body == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('加载失败: 响应数据为空')),
            );
          }
          return;
        }

        final users = parseFollowUsers(body, widget.type);

        final total = (body['total'] as num?)?.toInt() ??
            (body['count'] as num?)?.toInt() ??
            users.length;

        setState(() {
          if (loadMore) {
            _users.addAll(users);
            _page++;
          } else {
            _users = users;
            _page = 1;
          }
          _hasMore = _users.length < total;
        });
      } else if (resp['statusCode'] == 403) {
        // 隐私限制：对方隐藏了该列表
        final message =
            (resp['body'] as Map<String, dynamic>?)?['message'] ?? '对方已隐藏该列表';
        setState(() {
          _forbiddenMessage = message;
          _users = [];
          _hasMore = false;
        });
      } else {
        final message =
            (resp['body'] as Map<String, dynamic>?)?['message'] ?? '未知错误';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('加载失败: $message (${resp['statusCode']})')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFetching = false;
          _refreshing = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _isFetching) return;
    await _loadUsers(loadMore: true);
  }

  /// 对外提供的刷新接口，供上层在需要时强制刷新当前Tab
  void reload() {
    _loadUsers();
  }

  void _handleLocalChange(UserSummary user) {
    setState(() {
      _upsertOrRemove(user);
    });
    widget.onRelationshipChanged?.call(widget.type, user);
  }

  void _upsertOrRemove(UserSummary user) {
    final shouldExist = _shouldDisplay(user);
    final index = _users.indexWhere((u) => u.id == user.id);
    if (shouldExist) {
      if (index >= 0) {
        _users[index] = user;
      } else {
        _users.insert(0, user);
      }
    } else {
      if (index >= 0) {
        _users.removeAt(index);
      }
    }
  }

  bool _shouldDisplay(UserSummary user) {
    switch (widget.type) {
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

  void applyExternalUpdate(UserSummary user) {
    if (!_shouldDisplay(user) &&
        !_users.any((element) => element.id == user.id)) {
      return;
    }
    setState(() {
      _upsertOrRemove(user);
    });
  }

  @override
  bool get wantKeepAlive => true;

  Future<Map<String, dynamic>> _fetchUsers({required int page}) {
    switch (widget.type) {
      case 'followers':
        return ApiService.getFollowers(
          widget.userId,
          page: page,
          pageSize: _pageSize,
        );
      case 'mutual':
        return ApiService.getMutualFollowers(
          widget.userId,
          page: page,
          pageSize: _pageSize,
        );
      default:
        return ApiService.getFollowing(
          widget.userId,
          page: page,
          pageSize: _pageSize,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scheme = Theme.of(context).colorScheme;

    if (_forbiddenMessage != null) {
      return FollowTabForbiddenView(message: _forbiddenMessage!);
    }

    if (_isFetching && _users.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
          color: scheme.primary,
        ),
      );
    }

    if (_users.isEmpty) {
      return FollowTabEmptyView(type: widget.type);
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => _loadUsers(),
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _users.length + (_hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _users.length) {
                return _loadingMore
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : const SizedBox.shrink();
              }

              final user = _users[index];
              return FollowUserListItem(
                key: ValueKey('${widget.type}-${user.id}'),
                user: user,
                type: widget.type,
                onStateChanged: () => _loadUsers(),
                onProfileReturned: widget.onProfileReturned,
                onRelationshipChanged: (updated) =>
                    widget.onRelationshipChanged?.call(widget.type, updated),
                onFollowChanged: _handleLocalChange,
              );
            },
          ),
        ),
        if (_refreshing)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.transparent,
            ),
          ),
      ],
    );
  }
}
