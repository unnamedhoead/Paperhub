/// 分享帖子消息气泡内容组件
///
/// SHARE 类型的 content 存储的是 post ID，通过 FutureBuilder 异步加载帖子详情并渲染卡片。
import 'package:flutter/material.dart';
import '../../models/message_model.dart';
import '../../models/post_model.dart';
import '../../screens/post_detail_screen.dart';
import '../../services/api_service.dart';
import 'share_post_card.dart';
import 'text_bubble.dart';

class ShareBubbleContent extends StatelessWidget {
  /// 缓存帖子详情的 Future，避免反复加载
  static final Map<String, Future<Map<String, dynamic>>> postCache = {};

  final Message message;

  const ShareBubbleContent({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final postId = message.content;
    if (postId.isEmpty) {
      return TextBubbleContent(message: message);
    }

    if (!postCache.containsKey(postId)) {
      postCache[postId] = _loadPostDetails(postId);
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: postCache[postId],
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard(context);
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _buildErrorCard();
        }

        final post = snapshot.data!;
        final title = post['title']?.toString() ?? '无标题';
        final authorName =
            post['author']?['name']?.toString() ?? '未知用户';
        final authorAvatar = post['author']?['avatar']?.toString();
        final media = post['media'] as List<dynamic>?;
        final firstImage =
            media != null && media.isNotEmpty ? media[0].toString() : null;
        final likesCount =
            (post['likesCount'] as num?)?.toInt() ?? 0;
        final commentsCount =
            (post['commentsCount'] as num?)?.toInt() ?? 0;
        final imageAspectRatio =
            (post['imageAspectRatio'] as num?)?.toDouble();
        final imageNaturalWidth =
            (post['imageNaturalWidth'] as num?)?.toDouble();
        final imageNaturalHeight =
            (post['imageNaturalHeight'] as num?)?.toDouble();

        return GestureDetector(
          onTap: () => _navigateToPost(context, postId),
          child: SharePostCard(
            cardWidth:
                (MediaQuery.of(context).size.width * 0.75).clamp(200.0, 280.0),
            title: title,
            authorName: authorName,
            authorAvatar: authorAvatar,
            firstImage: firstImage,
            likesCount: likesCount,
            commentsCount: commentsCount,
            imageAspectRatio: imageAspectRatio,
            imageNaturalWidth: imageNaturalWidth,
            imageNaturalHeight: imageNaturalHeight,
          ),
        );
      },
    );
  }

  Widget _buildLoadingCard(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 0.5),
      ),
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 0.5),
      ),
      child: const Center(
        child: Text('加载帖子失败', style: TextStyle(color: Colors.grey)),
      ),
    );
  }

  Future<void> _navigateToPost(BuildContext context, String postId) async {
    try {
      final result = await ApiService.getPost(postId);
      if (result['statusCode'] == 200) {
        final postData = result['body'] as Map<String, dynamic>;
        final postObj = Post.fromJson(postData);

        final status = postObj.status?.toUpperCase();
        if (status != null && status != 'NORMAL') {
          String message;
          switch (status) {
            case 'DRAFT':
              message = '该笔记目前不可见';
              break;
            case 'AUDIT':
              message = '该笔记正在审核中，暂不可见';
              break;
            case 'REMOVED':
              message = '该笔记已被下架，不可见';
              break;
            default:
              message = '该笔记目前不可见';
          }
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
            );
          }
          return;
        }

        if (context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PostDetailScreen(post: postObj),
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    '获取帖子详情失败: ${result['body']['message'] ?? '未知错误'}')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('获取帖子详情失败: $e')),
        );
      }
    }
  }

  Future<Map<String, dynamic>> _loadPostDetails(String postId) async {
    try {
      final result = await ApiService.getPost(postId);
      if (result['statusCode'] == 200 && result['body'] != null) {
        final body = result['body'] as Map<String, dynamic>?;
        if (body != null && body.isNotEmpty) {
          return body;
        } else {
          throw Exception('服务器返回空响应体');
        }
      } else {
        throw Exception(result['body']?['message'] ?? '获取帖子失败');
      }
    } catch (e) {
      postCache.remove(postId);
      rethrow;
    }
  }
}
