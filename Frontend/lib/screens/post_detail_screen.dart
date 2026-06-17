// lib/screens/post_detail_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../models/post_model.dart';
import '../services/api_service.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../widgets/pdf_iframe_view.dart';
import '../services/local_storage.dart';
import '../services/browse_history_service.dart';
import 'profile_screen.dart';
import 'search_results_screen.dart';
import '../services/chat_service.dart';
import '../widgets/report_post_dialog.dart';
import '../models/message_model.dart';
import 'chat_screen.dart';
import 'note_editor/note_editor_screen.dart';
import '../utils/dialog_utils.dart';
import 'post_detail/post_content.dart';
import 'post_detail/post_actions.dart';
import 'post_detail/post_detail_controller.dart';
import 'post_detail/post_interaction_controller.dart';
import 'post_detail/post_comment_controller.dart';
import 'post_detail/post_comment_input_bar.dart';

import 'post_detail/post_media.dart';


class PostDetailScreen extends StatefulWidget {
  final Post post;
  const PostDetailScreen({Key? key, required this.post}) : super(key: key);

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class PdfPreviewScreen extends StatefulWidget {
  final String url;
  final String title;

  const PdfPreviewScreen({super.key, required this.url, required this.title});

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  bool _isLoading = true;
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: _hasError ? _buildErrorWidget() : _buildViewer(),
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          _buildAppBar(),
        ],
      ),
    );
  }

  Widget _buildViewer() {
    if (kIsWeb) {
      if (_isLoading) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _isLoading = false);
        });
      }
      return buildPlatformPdfView(widget.url);
    }

    return SfPdfViewer.network(
      widget.url,
      canShowPaginationDialog: false,
      canShowScrollHead: false,
      onDocumentLoaded: (_) => setState(() => _isLoading = false),
      onDocumentLoadFailed: (_) => setState(() {
        _isLoading = false;
        _hasError = true;
      }),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.white, size: 64),
          SizedBox(height: 16),
          Text('PDF加载失败', style: TextStyle(color: Colors.white, fontSize: 18)),
          SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('返回'),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostDetailScreenState extends State<PostDetailScreen>
    with SingleTickerProviderStateMixin {
  // 数据状态 + 业务逻辑都在 controller 里（详见 post_detail_controller.dart）。
  // 本 State 只保留 UI 资源（输入框 / 焦点 / 动画 / 翻页）、@提及输入状态与图片全屏 UI 状态。
  late final PostDetailController _controller;

  // 子控制器快捷访问。
  PostInteractionController get _interaction => _controller.interaction;
  PostCommentController get _comm => _controller.commentController;

  // 下列 getter 桥接到 controller，避免改动大量 _build* 引用点。
  bool get isLiked => _interaction.isLiked;
  bool get isSaved => _interaction.isSaved;
  int get likeCount => _interaction.likeCount;
  List<Comment> get _comments => _comm.comments;
  bool get _isLoadingComments => _comm.isLoadingComments;
  bool get _hasMoreComments => _comm.hasMoreComments;
  bool get _isDeleting => _controller.isDeleting;
  String? get _currentUserId => _controller.currentUserId;
  bool? get _isFollowingAuthor => _interaction.isFollowingAuthor;
  bool get _followInFlight => _interaction.followInFlight;
  String? get _currentPostStatus => _controller.currentPostStatus;
  double? get _actualImageWidth => _controller.actualImageWidth;
  double? get _actualImageHeight => _controller.actualImageHeight;
  bool get _isOwner => _controller.isOwner;
  List<String> get _imageMedia => _controller.imageMedia;
  List<String> get _pdfMedia => _controller.pdfMedia;

  // 评论输入栏（含 @提及）已抽成 PostCommentInputBar，自持其 TextEditingController/
  // FocusNode 与 @提及状态；本 State 不再持有这些。
  late AnimationController _heartCtrl;
  late Animation<double> _heartScale;
  bool _showBigHeart = false;

  bool _isImageFullscreen = false;
  int _currentImageIndex = 0;
  bool _isHoveringImage = false;
  late final PageController _imagePageController;


  @override
  void initState() {
    super.initState();
    _imagePageController = PageController();

    // 创建数据/业务 controller，注入需要 BuildContext 的 UI 副作用回调。
    _controller = PostDetailController(post: widget.post);
    _controller.onMessage = _showSnack;
    _controller.onPostDeleted = () {
      if (mounted) Navigator.of(context).pop(true);
    };
    _controller.onLikeAnimation = () {
      if (!mounted) return;
      setState(() => _showBigHeart = true);
      _heartCtrl.forward(from: 0.0);
    };
    _controller.addListener(_onControllerChanged);

    _heartCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _heartScale = Tween(
      begin: 0.3,
      end: 1.0,
    ).chain(CurveTween(curve: Curves.elasticOut)).animate(_heartCtrl);
    // 在动画结束后自动隐藏大爱心（避免永久显示受 isLiked 控制）
    _heartCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            setState(() {
              _showBigHeart = false;
            });
            _heartCtrl.reset();
          }
        });
      }
    });

    // 记录浏览历史（最多 50 条由 BrowseHistoryService 自己控制）
    final userId = LocalStorage.instance.read('userId')?.toString();
    if (userId != null && userId.isNotEmpty) {
      unawaited(
        BrowseHistoryService.addHistory(
          userId: userId,
          postId: widget.post.id,
          title: widget.post.title,
        ),
      );
    }

    // 启动 controller：拉取详情/评论/当前用户、连接 WebSocket、检查关注、按需加载图片尺寸。
    _controller.init(LocalStorage.instance.read('userId'));
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _heartCtrl.dispose();
    _imagePageController.dispose();
    super.dispose();
  }

  /// 缓存@用户搜索结果，避免重复API调用
  final Map<String, String?> _mentionUserIdCache = {};

  /// 构建包含@提及的评论内容（可点击的@链接）
  Widget _buildCommentContentWithMentions(
    String content,
    List<Author> mentions,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final List<TextSpan> spans = [];
    // 使用与提交时相同的正则表达式，匹配@后面跟着非@非空格的字符（格式：@A @B @C，有空格）
    final RegExp mentionRegex = RegExp(r'@([^\s@]+)');
    int lastIndex = 0;

    // 建立@用户名到用户ID的映射
    // 注意：我们需要确保这里的键和正则表达式匹配的用户名一致
    final Map<String, String> mentionMap = {};
    for (final mention in mentions) {
      // 使用多种可能的名字作为键，确保能匹配到
      final lowerName = mention.name.toLowerCase();
      mentionMap[lowerName] = mention.id;

      // 如果名字包含@，也添加@前缀的版本
      if (lowerName.contains('@')) {
        final prefix = lowerName.substring(0, lowerName.indexOf('@'));
        mentionMap[prefix] = mention.id;
      }

      // 如果名字是email格式，也添加email前缀
      if (mention.name.contains('@')) {
        final emailPrefix = mention.name
            .substring(0, mention.name.indexOf('@'))
            .toLowerCase();
        mentionMap[emailPrefix] = mention.id;
      }
    }

    print(
      '[@功能] _buildCommentContentWithMentions: content="$content", mentions=${mentions.map((m) => '${m.name}(${m.id})').toList()}, mentions长度=${mentions.length}',
    );

    // 额外调试：检查content中是否有@符号
    final hasAtSymbol = content.contains('@');
    print('[@功能] content中包含@符号: $hasAtSymbol');
    print('[@功能] mentionMap keys: ${mentionMap.keys.toList()}');
    print('[@功能] mentionMap: $mentionMap');

    for (final match in mentionRegex.allMatches(content)) {
      // 添加@之前的文本
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: content.substring(lastIndex, match.start),
            style: TextStyle(fontSize: 13, color: scheme.onSurface),
          ),
        );
      }

      // 添加@提及（可点击）
      final mentionText = match.group(0)!; // 包含@的完整文本，如 "@用户名"
      final userName = match.group(1)!; // 用户名部分

      print('[@功能] 匹配到@用户名: "$userName", 查找键: "${userName.toLowerCase()}"');

      // 从mentions列表中查找对应的用户ID
      final userId = mentionMap[userName.toLowerCase()];

      print(
        '[@功能] mentionMap.containsKey("${userName.toLowerCase()}"): ${mentionMap.containsKey(userName.toLowerCase())}',
      );

      if (userId != null) {
        // 如果用户ID存在，显示为可点击的蓝色链接
        print('[@功能] 从mentions找到用户ID: $userId，创建可点击链接');
        spans.add(
          TextSpan(
            text: mentionText,
            style: TextStyle(
              fontSize: 13,
              color: scheme.primary,
              fontWeight: FontWeight.w500,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                // 使用用户ID直接跳转
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfilePage(userId: userId),
                  ),
                );
              },
          ),
        );
      } else {
        // 如果mentions中没有找到，尝试通过API搜索用户
        print('[@功能] mentions中未找到用户ID: $userName，尝试API搜索');

        // 检查缓存
        if (_mentionUserIdCache.containsKey(userName)) {
          final cachedUserId = _mentionUserIdCache[userName];
          if (cachedUserId != null) {
            print('[@功能] 从缓存找到用户ID: $cachedUserId');
            spans.add(
              TextSpan(
                text: mentionText,
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.primary,
                  fontWeight: FontWeight.w500,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfilePage(userId: cachedUserId),
                      ),
                    );
                  },
              ),
            );
          } else {
            spans.add(
              TextSpan(
                text: mentionText,
                style: TextStyle(fontSize: 13, color: scheme.onSurface),
              ),
            );
          }
        } else {
          // 异步搜索用户
          _searchUserByName(userName)
              .then((userId) {
                _mentionUserIdCache[userName] = userId;
                // 搜索完成后不重新构建，因为这会改变UI
                // 用户需要刷新页面或重新进入才能看到可点击链接
              })
              .catchError((e) {
                _mentionUserIdCache[userName] = null;
              });

          spans.add(
            TextSpan(
              text: mentionText,
              style: TextStyle(fontSize: 13, color: scheme.onSurface),
            ),
          );
        }
      }

      lastIndex = match.end;
    }

    // 添加剩余的文本
    if (lastIndex < content.length) {
      spans.add(
        TextSpan(
          text: content.substring(lastIndex),
          style: TextStyle(fontSize: 13, color: scheme.onSurface),
        ),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }

  /// 通过用户名搜索用户ID（用于@功能）
  Future<String?> _searchUserByName(String userName) async {
    try {
      print('[@功能] 搜索用户: $userName');
      final resp = await ApiService.searchUsers(
        query: userName,
        type: 'all',
        pageSize: 10,
      );
      if (resp['statusCode'] == 200) {
        final body = resp['body'] as Map<String, dynamic>?;
        if (body != null) {
          final users = (body['users'] as List? ?? []);
          print('[@功能] 搜索到 ${users.length} 个用户');

          // 精确匹配：先尝试匹配displayName，再尝试匹配email前缀
          for (final user in users) {
            final displayName = user['displayName']?.toString() ?? '';
            final email = user['email']?.toString() ?? '';
            final emailPrefix = email.contains('@') ? email.split('@')[0] : '';

            // 精确匹配displayName或email前缀
            if (displayName.toLowerCase() == userName.toLowerCase() ||
                emailPrefix.toLowerCase() == userName.toLowerCase()) {
              final userId = user['id']?.toString();
              if (userId != null) {
                print('[@功能] 找到匹配用户: id=$userId, displayName=$displayName');
                return userId;
              }
            }
          }

          // 如果没有精确匹配，使用第一个结果
          if (users.isNotEmpty) {
            final user = users[0];
            final userId = user['id']?.toString();
            if (userId != null) {
              print('[@功能] 使用第一个搜索结果: id=$userId');
              return userId;
            }
          }
        }
      }
      print('[@功能] 未找到用户: $userName');
      return null;
    } catch (e) {
      print('[@功能] 搜索用户失败: $e');
      return null;
    }
  }

  /// 通过用户名导航到用户主页
  Future<void> _navigateToUserProfileByName(String userName) async {
    try {
      print('[@功能] 尝试查找用户: $userName');
      // 先搜索用户（搜索name和email）
      final resp = await ApiService.searchUsers(
        query: userName,
        type: 'all',
        pageSize: 20,
      );
      if (resp['statusCode'] == 200) {
        final body = resp['body'] as Map<String, dynamic>?;
        if (body != null) {
          final users = (body['users'] as List? ?? []);
          print('[@功能] 搜索到 ${users.length} 个用户');

          // 精确匹配：先尝试匹配displayName，再尝试匹配email前缀
          for (final user in users) {
            final displayName = user['displayName']?.toString() ?? '';
            final email = user['email']?.toString() ?? '';
            final emailPrefix = email.contains('@') ? email.split('@')[0] : '';

            // 精确匹配displayName或email前缀
            if (displayName.toLowerCase() == userName.toLowerCase() ||
                emailPrefix.toLowerCase() == userName.toLowerCase()) {
              final userId = user['id']?.toString();
              if (userId != null && mounted) {
                print('[@功能] 找到匹配用户: id=$userId, displayName=$displayName');
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfilePage(userId: userId),
                  ),
                );
                return;
              }
            }
          }

          // 如果没有精确匹配，使用第一个结果
          if (users.isNotEmpty) {
            final user = users[0];
            final userId = user['id']?.toString();
            if (userId != null && mounted) {
              print('[@功能] 使用第一个搜索结果: id=$userId');
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ProfilePage(userId: userId)),
              );
              return;
            }
          }
        }
      }
      // 如果搜索失败，显示提示
      print('[@功能] 未找到用户: $userName');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('未找到用户: $userName')));
      }
    } catch (e, stackTrace) {
      print('[@功能] 导航到用户主页失败: $e');
      print('[@功能] 堆栈跟踪: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('查找用户失败: $e')));
      }
    }
  }

  PreferredSizeWidget _buildTopBar() {
    final scheme = Theme.of(context).colorScheme;
    return AppBar(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0.5,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: scheme.onSurface),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        widget.post.title,
        style: TextStyle(color: scheme.onSurface, fontSize: 16),
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.more_horiz,
            color: scheme.onSurface.withOpacity(0.7),
          ),
          onPressed: _isDeleting ? null : _openMoreActions,
        ),
      ],
    );
  }





  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// 删除评论：先弹确认框（需要 BuildContext），确认后把数据/网络交给 controller。
  Future<void> _confirmDeleteComment(
    Comment comment, {
    required bool isTopLevel,
    Comment? parentComment,
  }) async {
    final itemName = isTopLevel ? '评论' : '回复';
    final additionalWarning = isTopLevel ? '删除后所有回复也会被删除。' : null;

    final confirmed = await DialogUtils.showDeleteConfirmDialog(
      context: context,
      itemName: itemName,
      additionalWarning: additionalWarning,
    );

    if (confirmed != true) return;

    await _controller.deleteComment(
      comment,
      isTopLevel: isTopLevel,
      parentComment: parentComment,
    );
  }


  Widget _buildCommentsSection() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(height: 1, color: scheme.outline.withOpacity(0.15)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Text(
                '评论 (${widget.post.commentsCount})',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              const Spacer(),
              if (_isLoadingComments)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: scheme.primary,
                  ),
                ),
              IconButton(
                icon: Icon(
                  Icons.refresh,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
                onPressed: _isLoadingComments
                    ? null
                    : () => _comm.loadComments(refresh: true),
                tooltip: '刷新评论',
              ),
            ],
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _comments.length + (_hasMoreComments ? 1 : 0),
          separatorBuilder: (_, __) =>
              Divider(indent: 16, color: scheme.outline.withOpacity(0.15)),
          itemBuilder: (context, idx) {
            if (idx == _comments.length) {
              // 加载更多按钮
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: _isLoadingComments
                      ? CircularProgressIndicator(color: scheme.primary)
                      : TextButton.icon(
                          onPressed: () => _comm.loadComments(),
                          icon: Icon(
                            Icons.refresh,
                            color: scheme.onSurfaceVariant,
                          ),
                          label: Text(
                            '加载更多评论',
                            style: TextStyle(color: scheme.primary),
                          ),
                        ),
                ),
              );
            }
            final c = _comments[idx];
            final inFlight = _comm.isCommentLikeInFlight(c.id);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  onTap: () => _openUserProfile(c.author.id),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: _buildAvatarWidget(c.author.avatar, 16),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.author.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      // 删除按钮（只有作者自己可以看到）
                      if (_currentUserId != null &&
                          c.author.id == _currentUserId)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          color: Colors.red[300],
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () =>
                              _confirmDeleteComment(c, isTopLevel: true),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (c.replyTo != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Text(
                            '回复 @${c.replyTo!.name}',
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                      _buildCommentContentWithMentions(c.content, c.mentions),
                      Row(
                        children: [
                          Text(
                            _formatRelative(c.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          TextButton(
                            onPressed: () => _comm.startReply(c),
                            child: const Text(
                              '回复',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${c.likesCount}',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                          IconButton(
                            icon: Icon(
                              c.isLiked
                                  ? Icons.thumb_up
                                  : Icons.thumb_up_off_alt,
                              size: 18,
                              color: c.isLiked
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant,
                            ),
                            onPressed: inFlight
                                ? null
                                : () => _comm.handleCommentLikePressed(c),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // 显示回复列表
                if (c.hasReplies)
                  Padding(
                    padding: const EdgeInsets.only(left: 56.0),
                    child: Column(
                      children: c.replies.map((reply) {
                        final replyInFlight = _comm.isCommentLikeInFlight(
                          reply.id,
                        );
                        return ListTile(
                          onTap: () => _openUserProfile(reply.author.id),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          leading: _buildAvatarWidget(reply.author.avatar, 14),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  reply.author.name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              // 删除按钮（只有作者自己可以看到）
                              if (_currentUserId != null &&
                                  reply.author.id == _currentUserId)
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 16,
                                  ),
                                  color: Colors.red[300],
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _confirmDeleteComment(
                                    reply,
                                    isTopLevel: false,
                                    parentComment: c,
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (reply.replyTo != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4.0),
                                  child: Text(
                                    '回复 @${reply.replyTo!.name}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: scheme.primary,
                                    ),
                                  ),
                                ),
                              _buildCommentContentWithMentions(
                                reply.content,
                                reply.mentions,
                              ),
                              Row(
                                children: [
                                  Text(
                                    _formatRelative(reply.createdAt),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        _comm.startReply(reply, parentId: c.id),
                                    child: const Text(
                                      '回复',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${reply.likesCount}',
                                    style: TextStyle(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      reply.isLiked
                                          ? Icons.thumb_up
                                          : Icons.thumb_up_off_alt,
                                      size: 16,
                                      color: reply.isLiked
                                          ? scheme.primary
                                          : scheme.onSurfaceVariant,
                                    ),
                                    onPressed: replyInFlight
                                        ? null
                                        : () => _comm.handleCommentLikePressed(
                                            reply,
                                          ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  // ===== 从 post_actions 移入的 action 方法 =====

  Future<void> _openUserProfile(String userId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => ProfilePage(userId: userId)),
    );
    // 从用户主页返回时，刷新关注状态（特别是如果用户在该页面取关了作者）
    if (userId == widget.post.author.id && _currentUserId != userId) {
      await _controller.checkFollowStatus();
    }
  }

  Future<void> _onShare() async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先登录')));
      return;
    }

    // 显示分享选择界面
    final selectedUserId = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ShareUserSelectionSheet(
        currentUserId: _currentUserId!,
        post: widget.post,
      ),
    );

    if (selectedUserId == null) return;

    // 分享帖子到选中的用户
    await _sharePostToUser(selectedUserId);
  }

  Future<void> _sharePostToUser(String targetUserId) async {
    try {
      // 显示加载提示
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('正在分享...'),
          duration: Duration(seconds: 1),
        ),
      );

      // 获取或创建 conversation
      final chatService = ChatService();
      final conversation = await chatService.createOrGetPrivateConversation(
        targetUserId,
      );

      if (conversation == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('创建会话失败，请稍后重试')));
        return;
      }

      // 发送分享消息
      // 使用 SHARE 类型，content 只存储 post ID
      await chatService.sendMessage(
        conversationId: conversation.id,
        content: widget.post.id, // content 只存储 post ID
        type: MessageType.share,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('分享成功')));

      // 可选：导航到聊天界面
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ChatScreen(conversation: conversation),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('分享失败: $e')));
    }
  }

  void _openMoreActions() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            // 只有作者可以看到"编辑"和"删除"
            if (_isOwner)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('编辑笔记'),
                onTap: () async {
                  // 先关闭底部弹窗
                  Navigator.pop(context);
                  // 复用已有的编辑逻辑
                  await _openEditPost();
                },
              ),

            if (_isOwner)
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('删除笔记', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeletePost();
                },
              ),
            ListTile(
              leading: const Icon(Icons.flag),
              title: const Text('举报'),
              onTap: () async {
                Navigator.pop(context);
                final result = await showDialog(
                  context: context,
                  builder: (context) =>
                      ReportPostDialog(postId: int.parse(widget.post.id)),
                );
                if (result == true && mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('举报成功，我们会尽快处理')));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeletePost() async {
    final confirmed = await DialogUtils.showDeleteConfirmDialog(
      context: context,
      itemName: '笔记',
      additionalWarning: '删除后将无法恢复。',
    );

    if (confirmed == true) {
      // 删除成功后由 controller 的 onPostDeleted 回调 pop 返回上一页。
      await _controller.deletePost();
    }
  }

  Future<void> _openEditPost() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NoteEditorPage(initialPost: widget.post),
      ),
    );

    // 编辑页返回 true，表示"保存成功，需要刷新详情"
    if (result == true) {
      await _controller.loadPostDetail();
    }
  }

  // ===== 从 post_content 移入的方法 =====

  String _formatRelative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 4) return '刚刚';
    if (diff.inMinutes >= 4 && diff.inMinutes < 60)
      return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    return '${diff.inDays} 天前';
  }

  void _onTagTap(String tag) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SearchResultsScreen(query: '#$tag')),
    );
  }

  void _openPdfPreview(String url, String title) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showSnack('PDF 链接无效');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfPreviewScreen(url: uri.toString(), title: title),
        fullscreenDialog: true,
      ),
    );
  }

  Future<void> _downloadPdf(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showSnack('PDF 链接无效');
      return;
    }
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        _showSnack('无法打开下载链接');
      }
    } catch (_) {
      _showSnack('无法打开下载链接');
    }
  }

  void _navigateToReferencePost(int postId) async {
    try {
      final resp = await ApiService.getPost(postId.toString());
      if (resp['statusCode'] == 200) {
        final refPostData = resp['body'];
        final refPost = Post.fromJson(refPostData);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetailScreen(post: refPost),
          ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('引用内容已不可见')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法访问引用内容')));
    }
  }

  // ===== 从 post_media 移入的方法 =====

  Future<void> _openExternalLink(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('链接为空')));
      return;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('无法识别的链接：$trimmed')));
      return;
    }

    if (!await canLaunchUrl(uri)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('当前环境无法打开链接：$trimmed')));
      return;
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }


  void _toggleImageFullscreen() {
    setState(() {
      _isImageFullscreen = !_isImageFullscreen;
    });
  }

  void _handleImageHover(bool isHovering) {
    if (!kIsWeb) return;
    if (_isHoveringImage != isHovering) {
      setState(() {
        _isHoveringImage = isHovering;
      });
    }
  }

  void _goToNextImage() {
    final images = _imageMedia;
    if (images.length <= 1) return;
    final nextIndex = (_currentImageIndex + 1).clamp(0, images.length - 1);
    _imagePageController.animateToPage(
      nextIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _goToPreviousImage() {
    final images = _imageMedia;
    if (images.length <= 1) return;
    final prevIndex = (_currentImageIndex - 1).clamp(0, images.length - 1);
    _imagePageController.animateToPage(
      prevIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Widget _buildFullscreenOverlay() {
    final images = _imageMedia;
    if (!_isImageFullscreen || images.isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.95),
        child: SafeArea(
          child: GestureDetector(
            onTap: _toggleImageFullscreen,
            child: Stack(
              children: [
                PageView.builder(
                  controller: _imagePageController,
                  itemCount: images.length,
                  onPageChanged: (index) {
                    if (_currentImageIndex != index) {
                      setState(() {
                        _currentImageIndex = index;
                      });
                    }
                  },
                  itemBuilder: (_, index) {
                    return Center(
                      child: InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 4.0,
                        child: _buildImageDisplay(
                          images[index],
                          MediaQuery.of(context).size.width,
                          MediaQuery.of(context).size.height,
                          BoxFit.contain,
                        ),
                      ),
                    );
                  },
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_currentImageIndex + 1}/${images.length}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _toggleImageFullscreen,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRemovedWarning() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.red.shade700,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '该笔记已被管理员下架，仅作者可见',
                  style: TextStyle(
                    color: Colors.red.shade900,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (widget.post.hiddenReason != null &&
                    widget.post.hiddenReason!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '原因：${widget.post.hiddenReason}',
                      style: TextStyle(
                        color: Colors.red.shade800,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostUnavailableView() {
    String message;
    IconData icon;
    Color color;

    final status =
        _currentPostStatus?.toUpperCase() ?? widget.post.status?.toUpperCase();
    switch (status) {
      case 'DRAFT':
        message = '该笔记目前为草稿状态，不可见';
        icon = Icons.edit_note;
        color = Colors.orange;
        break;
      case 'AUDIT':
        message = '该笔记正在审核中，暂不可见';
        icon = Icons.hourglass_empty;
        color = Colors.blue;
        break;
      case 'REMOVED':
        message = '该笔记已被下架，不可见';
        icon = Icons.block;
        color = Colors.red;
        break;
      default:
        message = '该笔记目前不可见';
        icon = Icons.visibility_off;
        color = Colors.grey;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: color),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            if (widget.post.hiddenReason != null &&
                widget.post.hiddenReason!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '原因：${widget.post.hiddenReason}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarWidget(String avatarPath, double radius) {
    // 判断是否为网络 URL（以 http:// 或 https:// 开头）
    if (avatarPath.startsWith('http://') || avatarPath.startsWith('https://')) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey[300],
        child: ClipOval(
          child: Image.network(
            avatarPath,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Icon(Icons.person, size: radius, color: Colors.grey);
            },
          ),
        ),
      );
    }

    // 处理本地资源路径
    String assetPath = avatarPath;
    if (assetPath.startsWith('assets/images/')) {
      assetPath = assetPath.substring(14);
    } else if (assetPath.startsWith('assets/')) {
      assetPath = assetPath.substring(7);
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[300],
      child: ClipOval(
        child: Image.asset(
          assetPath,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Icon(Icons.person, size: radius, color: Colors.grey);
          },
        ),
      ),
    );
  }

  Widget _buildImageDisplay(
    String path,
    double width,
    double height,
    BoxFit fit,
  ) {
    final placeholder = Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: const Center(
        child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
      ),
    );

    if (path.startsWith('http')) {
      return Image.network(
        path,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => placeholder,
      );
    }

    return Image.file(
      File(path),
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => placeholder,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 检查帖子状态，如果不是 NORMAL，显示不可见提示页面
    final status =
        _currentPostStatus?.toUpperCase() ?? widget.post.status?.toUpperCase();
    final isPostUnavailable = status != null && status != 'NORMAL';

    return Scaffold(
      appBar: _buildTopBar(),
      body: Stack(
        children: [
          if (isPostUnavailable)
            // 帖子不可见，显示提示页面
            _buildPostUnavailableView()
          else
            // 帖子可见，显示正常内容
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PostMediaGallery(
                    imageUrls: _imageMedia,
                    actualImageWidth: _actualImageWidth,
                    actualImageHeight: _actualImageHeight,
                    imageNaturalWidth: widget.post.imageNaturalWidth,
                    imageNaturalHeight: widget.post.imageNaturalHeight,
                    imageAspectRatio: widget.post.imageAspectRatio,
                    imagePageController: _imagePageController,
                    currentImageIndex: _currentImageIndex,
                    isHoveringImage: _isHoveringImage,
                    showBigHeart: _showBigHeart,
                    heartScale: _heartScale,
                    onDoubleTap: _interaction.handlePostLikePressed,
                    onImageTap: _toggleImageFullscreen,
                    onNextImage: _goToNextImage,
                    onPreviousImage: _goToPreviousImage,
                    onHoverEnter: () => _handleImageHover(true),
                    onHoverExit: () => _handleImageHover(false),
                    onPageChanged: (index) {
                      if (_currentImageIndex != index) {
                        setState(() {
                          _currentImageIndex = index;
                        });
                      }
                    },
                  ),
                  if (widget.post.status == 'REMOVED' &&
                      widget.post.hiddenReason != null)
                    _buildRemovedWarning(),
                  const SizedBox(height: 8),
                  PostContentView(
                    post: widget.post,
                    isFollowingAuthor: _isFollowingAuthor,
                    followInFlight: _followInFlight,
                    pdfMedia: _pdfMedia,
                    onAuthorTap: () =>
                        _openUserProfile(widget.post.author.id),
                    onToggleFollow: _interaction.toggleFollow,
                    onTagTap: _onTagTap,
                    onOpenPdfPreview: _openPdfPreview,
                    onDownloadPdf: _downloadPdf,
                    onOpenExternalLink: _openExternalLink,
                    onFetchReferencePost: _controller.fetchReferencePost,
                    onNavigateToReferencePost: _navigateToReferencePost,
                  ),
                  PostActionsBar(
                    post: widget.post,
                    isLiked: isLiked,
                    likeCount: likeCount,
                    isSaved: isSaved,
                    onLike: _interaction.handlePostLikePressed,
                    onComment: () =>
                        FocusScope.of(context).requestFocus(FocusNode()),
                    onSave: _interaction.toggleSave,
                    onShare: _onShare,
                  ),
                  _buildCommentsSection(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          if (_isImageFullscreen) _buildFullscreenOverlay(),
          if (!isPostUnavailable)
            PostCommentInputBar(commentController: _comm),
          if (_isDeleting)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.25),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }


}

/// 分享用户选择界面
class _ShareUserSelectionSheet extends StatefulWidget {
  final String currentUserId;
  final Post post;

  const _ShareUserSelectionSheet({
    required this.currentUserId,
    required this.post,
  });

  @override
  State<_ShareUserSelectionSheet> createState() =>
      _ShareUserSelectionSheetState();
}

class _ShareUserSelectionSheetState extends State<_ShareUserSelectionSheet> {
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
            // 后端返回的是 ProfileResp，包含 displayName 字段
            return {
              'id': userMap['id']?.toString() ?? '',
              'name':
                  userMap['displayName']?.toString() ??
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
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty ? '还没有关注任何人' : '未找到匹配的用户',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 4,
                    ),
                    itemCount: _filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = _filteredUsers[index];
                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundImage:
                                user['avatar'] != null &&
                                    user['avatar'].toString().isNotEmpty
                                ? NetworkImage(user['avatar'].toString())
                                : null,
                            child:
                                user['avatar'] == null ||
                                    user['avatar'].toString().isEmpty
                                ? Text(
                                    (user['name']?.toString().isNotEmpty ??
                                            false)
                                        ? user['name']
                                              .toString()[0]
                                              .toUpperCase()
                                        : '?',
                                    style: const TextStyle(fontSize: 18),
                                  )
                                : null,
                          ),
                          title: Text(
                            user['name']?.toString() ?? '未知用户',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.pop(context, user['id']?.toString());
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// 可点击标签组件
class ClickableTagWidget extends StatelessWidget {
  final String tag;
  final VoidCallback onTap;

  const ClickableTagWidget({super.key, required this.tag, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1),
        ),
        child: Text(
          '#$tag',
          style: const TextStyle(
            color: Colors.blue,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ContentWithClickableTags moved to widgets/content_with_clickable_tags.dart




