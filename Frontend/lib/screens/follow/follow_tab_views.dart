// lib/screens/follow/follow_tab_views.dart
/// FollowTab 的占位视图（禁止访问 / 空列表）与响应解析辅助函数
import 'package:flutter/material.dart';
import '../../models/user_summary.dart';

/// 当对方隐藏了该列表时显示的提示视图
class FollowTabForbiddenView extends StatelessWidget {
  final String message;

  const FollowTabForbiddenView({Key? key, required this.message})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Text(
          message,
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 15,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// 列表为空时显示的占位视图
class FollowTabEmptyView extends StatelessWidget {
  final String type; // 'following', 'followers', 'mutual'

  const FollowTabEmptyView({Key? key, required this.type}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            type == 'mutual'
                ? '暂无互相关注'
                : type == 'followers'
                    ? '暂无粉丝'
                    : '暂无关注',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

/// 从响应 body 中解析用户列表，并按 tab 类型补全关注/粉丝标记。
List<UserSummary> parseFollowUsers(
  Map<String, dynamic> body,
  String type,
) {
  final usersData = (body['users'] as List<dynamic>?) ??
      (body['data'] as List<dynamic>?) ??
      (body['followers'] as List<dynamic>?) ??
      (body['following'] as List<dynamic>?) ??
      [];

  return usersData
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
}
