// lib/screens/post_detail_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
import 'post_detail/post_comments_section.dart';
import 'post_detail/pdf_preview_screen.dart';
import 'post_detail/share_user_selection_sheet.dart';
import 'post_detail/post_status_views.dart';
import 'post_detail/post_fullscreen_image_overlay.dart';

import 'post_detail/post_media.dart';


class PostDetailScreen extends StatefulWidget {
  final Post post;
  const PostDetailScreen({Key? key, required this.post}) : super(key: key);

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
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
      builder: (context) => ShareUserSelectionSheet(
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
            PostUnavailableView(
              status: _currentPostStatus ?? widget.post.status,
              hiddenReason: widget.post.hiddenReason,
            )
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
                    PostRemovedWarning(hiddenReason: widget.post.hiddenReason),
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
                  PostCommentsSection(
                    commentController: _comm,
                    commentsCount: widget.post.commentsCount,
                    currentUserId: _currentUserId,
                    onOpenUserProfile: _openUserProfile,
                    onConfirmDeleteComment: _confirmDeleteComment,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          if (_isImageFullscreen && _imageMedia.isNotEmpty)
            PostFullscreenImageOverlay(
              images: _imageMedia,
              pageController: _imagePageController,
              currentIndex: _currentImageIndex,
              onIndexChanged: (index) {
                if (_currentImageIndex != index) {
                  setState(() => _currentImageIndex = index);
                }
              },
              onClose: _toggleImageFullscreen,
            ),
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