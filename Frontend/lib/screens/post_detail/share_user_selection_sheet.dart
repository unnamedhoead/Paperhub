/// 分享用户选择底部弹窗（从 post_detail_screen.dart 原样抽出，原为私有
/// `_ShareUserSelectionSheet`，抽出后改为公开）。
///
/// 加载当前用户的关注列表，支持搜索，选中某用户后 `Navigator.pop(context, userId)`
/// 把目标用户 ID 返回给调用方。
library;

import 'package:flutter/material.dart';

import '../../models/post_model.dart';
import '../../services/api_service.dart';

/// 分享用户选择界面。
class ShareUserSelectionSheet extends StatefulWidget {
  final String currentUserId;
  final Post post;

  const ShareUserSelectionSheet({
    super.key,
    required this.currentUserId,
    required this.post,
  });

  @override
  State<ShareUserSelectionSheet> createState() =>
      _ShareUserSelectionSheetState();
}

class _ShareUserSelectionSheetState extends State<ShareUserSelectionSheet> {
  List<Map<String, dynamic>> _followingUsers = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadFollowingUsers();
  }

  Future<void> _loadFollowingUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 获取当前用户的关注列表
      final result = await ApiService.getFollowing(
        widget.currentUserId,
        page: 0,
        pageSize: 100, // 获取所有关注用户
      );

      if (result['statusCode'] == 200) {
        final body = result['body'];
        // 后端返回的字段是 'users'，不是 'content'
        final users = body['users'] as List<dynamic>? ?? [];
        setState(() {
          _followingUsers = users.map((user) {
            final userMap = user as Map<String, dynamic>;
            return {
              'id': userMap['id']?.toString() ?? '',
              'name': userMap['displayName']?.toString() ??
                  (userMap['email']?.toString() ?? '未知用户'),
              'avatar': userMap['avatar']?.toString(),
            };
          }).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('加载关注列表失败: ${result['body']['message'] ?? '未知错误'}'),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('加载关注列表失败: $e')));
      }
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchQuery.isEmpty) {
      return _followingUsers;
    }
    return _followingUsers.where((user) {
      final name = user['name']?.toString().toLowerCase() ?? '';
      return name.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 顶部拖拽指示器
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 标题
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                const Text(
                  '分享给',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // 搜索框
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: '搜索用户',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          // 用户列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                    ? _buildEmpty()
                    : _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? '还没有关注任何人' : '未找到匹配的用户',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      itemCount: _filteredUsers.length,
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        final avatar = user['avatar']?.toString() ?? '';
        final name = user['name']?.toString() ?? '未知用户';
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            leading: CircleAvatar(
              radius: 24,
              backgroundImage:
                  avatar.isNotEmpty ? NetworkImage(avatar) : null,
              child: avatar.isEmpty
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 18),
                    )
                  : null,
            ),
            title: Text(
              name,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pop(context, user['id']?.toString()),
          ),
        );
      },
    );
  }
}
