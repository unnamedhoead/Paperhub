/// 帖子详情页状态控制器（ChangeNotifier，编排层）。
///
/// 组合两个子控制器并转发其变更通知（参照 HomeController 组合子控制器的模式）：
/// - [PostInteractionController]：点赞 / 收藏 / 关注（乐观更新 + 回滚）。
/// - [PostCommentController]：评论列表 / 分页 / 回复 / 提交 / 删除 / 评论点赞。
///
/// 本类自身持有：当前用户、帖子最新状态、图片真实尺寸、引用文献缓存、WebSocket 通道，
/// 并负责：加载详情、连接 WebSocket 并把事件路由到对应子控制器、删除帖子、加载图片尺寸。
/// 用 [notifyListeners] 替代原 `_PostDetailScreenState` 的 setState。
///
/// 不持有 BuildContext / Navigator / ScaffoldMessenger / TextEditingController /
/// AnimationController；需要 UI 副作用时通过 [onMessage]/[onPostDeleted]/[onLikeAnimation]
/// 回调通知 Screen。遵循 state-management-convention.md 的「类型 A」。
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'; // ChangeNotifier / VoidCallback
// painting.dart 提供 NetworkImage / ImageStream 等图片解析类型。
import 'package:flutter/painting.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../config/app_env.dart';
import '../../models/post_model.dart';
import '../../services/api_service.dart';
import 'post_comment_controller.dart';
import 'post_interaction_controller.dart';

/// 详情页编排控制器。
class PostDetailController extends ChangeNotifier {
  PostDetailController({required Post post}) : _post = post {
    _currentPostStatus = post.status;
    _interaction = PostInteractionController(
      post: post,
      currentUserId: () => _currentUserId,
    );
    _comments = PostCommentController(post: post);
    _interaction.addListener(_forward);
    _comments.addListener(_forward);
  }

  // ===== 依赖回调（Screen 注入，转发给子控制器）=====

  void Function(String message)? _onMessage;
  set onMessage(void Function(String message)? value) {
    _onMessage = value;
    _interaction.onMessage = value;
    _comments.onMessage = value;
  }

  void Function(String message)? get onMessage => _onMessage;

  /// 帖子删除成功后回调（Screen 据此 pop 返回上一页）。
  VoidCallback? onPostDeleted;

  /// 帖子点赞成功后回调（Screen 据此播放大爱心动画）。
  set onLikeAnimation(VoidCallback? value) => _interaction.onLikeAnimation = value;
  VoidCallback? get onLikeAnimation => _interaction.onLikeAnimation;

  // ===== 组合：子控制器 =====

  late final PostInteractionController _interaction;
  PostInteractionController get interaction => _interaction;

  /// 评论子控制器。Screen 直接通过 `commentController.xxx` 访问评论相关状态与方法。
  /// 删除评论因需联动整页遮罩，走本类的 [deleteComment]。
  late final PostCommentController _comments;
  PostCommentController get commentController => _comments;

  /// 转发子控制器变更给 Screen。
  void _forward() => notifyListeners();

  /// 删除评论（已确认）。删除中状态联动本控制器的整页遮罩。
  Future<void> deleteComment(
    Comment comment, {
    required bool isTopLevel,
    Comment? parentComment,
  }) =>
      _comments.deleteComment(
        comment,
        isTopLevel: isTopLevel,
        parentComment: parentComment,
        onDeletingChanged: _setDeleting,
      );

  // ===== 帖子级数据状态 =====

  final Post _post;
  Post get post => _post;

  WebSocketChannel? _wsChannel;

  /// 引用文献缓存，避免重复加载。
  final Map<int, Map<String, dynamic>> _referencePostCache = {};

  bool isDeleting = false;
  void _setDeleting(bool value) {
    isDeleting = value;
    notifyListeners();
  }

  String? _currentUserId;
  String? get currentUserId => _currentUserId;

  /// 当前帖子状态（从后端获取的最新状态）。
  String? _currentPostStatus;
  String? get currentPostStatus => _currentPostStatus;

  /// 图片实际尺寸（用于动态计算宽高比）。
  double? actualImageWidth;
  double? actualImageHeight;
  bool _isLoadingImageSize = false;

  /// 是否为帖子作者。
  bool get isOwner =>
      _currentUserId != null && _post.author.id == _currentUserId;

  /// 图片媒体（非 PDF）。
  List<String> get imageMedia => _post.media.where((m) => !isPdf(m)).toList();

  /// PDF 媒体。
  List<String> get pdfMedia => _post.media.where(isPdf).toList();

  // ===== 初始化与释放 =====

  /// 初始化：读取当前用户、拉取最新详情、加载评论、连接 WebSocket、检查关注状态、
  /// （必要时）加载图片真实尺寸。
  void init(String? userIdFromStorage) {
    _currentUserId = userIdFromStorage;
    loadPostDetail();
    _comments.loadComments();
    loadCurrentUserId();
    initWebSocket();
    _interaction.checkFollowStatus();
    if (imageMedia.isNotEmpty &&
        _post.imageNaturalWidth == 800.0 &&
        _post.imageNaturalHeight == 600.0) {
      loadImageSize();
    }
  }

  @override
  void dispose() {
    _wsChannel?.sink.close();
    _interaction.removeListener(_forward);
    _interaction.dispose();
    _comments.removeListener(_forward);
    _comments.dispose();
    super.dispose();
  }

  // ===== 加载 =====

  Future<void> loadPostDetail() async {
    try {
      final resp = await ApiService.getPost(_post.id);
      final status = resp['statusCode'] as int? ?? 500;
      final body = resp['body'] as Map<String, dynamic>?;

      if (status >= 200 && status < 300 && body != null) {
        final updatedPost = Post.fromJson(body);
        _post.likesCount = updatedPost.likesCount;
        _post.isLiked = updatedPost.isLiked;
        _post.commentsCount = updatedPost.commentsCount;
        _currentPostStatus = updatedPost.status;
        _interaction.syncLikeFromPost(); // 同步点赞状态（会 notify）。
        notifyListeners();
      }
    } catch (e) {
      // 加载失败则沿用传入的 post 对象；不提示，因已有初始数据。
    }
  }

  Future<void> loadCurrentUserId() async {
    try {
      final resp = await ApiService.getCurrentUserProfile();
      if (resp['statusCode'] == 200) {
        final body = resp['body'] as Map<String, dynamic>;
        _currentUserId = body['id']?.toString();
        notifyListeners();
      }
    } catch (e) {
      // 忽略错误。
    }
  }

  /// 刷新关注状态（从作者主页返回时调用）。
  Future<void> checkFollowStatus() => _interaction.checkFollowStatus();

  // ===== WebSocket =====

  /// 初始化 WebSocket 连接，监听后端推送的点赞/评论变更。
  void initWebSocket() {
    final wsUrl = 'ws:${AppEnv.apiBaseUrl}/ws/posts/${_post.id}';
    _wsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
    _wsChannel!.stream.listen(
      _onWsEvent,
      onError: (err) {
        // 可选：记录错误或做重连策略。
      },
      onDone: () {
        // 可选：自动重连（根据实际需要实现）。
      },
    );
  }

  /// 路由 WebSocket 事件到对应子控制器。
  void _onWsEvent(dynamic event) {
    try {
      final data = jsonDecode(event);
      final type = data['type'] as String?;

      if (type == 'like_update') {
        _interaction.applyLikeUpdate(data);
      } else if (type == 'favorite_update') {
        _interaction.applyFavoriteUpdate(data);
      } else if (type == 'comment_like_update' && data['commentId'] != null) {
        _comments.applyCommentLikeUpdate(data);
      } else if (type == 'comment_created') {
        _comments.applyCommentCreated(data);
      } else if (type == 'comment_updated') {
        _comments.applyCommentUpdated(data);
      } else if (type == 'comment_deleted') {
        _comments.applyCommentDeleted(data);
      }
    } catch (e) {
      // ignore: 格式或解析错误，避免影响主流程。
    }
  }

  // ===== 删除帖子 =====

  /// 删除帖子。确认对话框由 Screen 负责，此方法只在已确认后执行删除。
  /// 成功后通过 [onPostDeleted] 通知 Screen 返回上一页。
  Future<void> deletePost() async {
    _setDeleting(true);
    try {
      final resp = await ApiService.deletePost(_post.id);
      final status = resp['statusCode'] as int? ?? 500;
      final body = resp['body'] as Map<String, dynamic>?;

      if (status >= 200 && status < 300) {
        onPostDeleted?.call();
        return;
      }

      final msg = body != null && body['message'] != null
          ? body['message'].toString()
          : '删除失败，请稍后重试';
      _onMessage?.call(msg);
    } catch (e) {
      _onMessage?.call('删除失败：$e');
    } finally {
      _setDeleting(false);
    }
  }

  // ===== 引用文献 =====

  Future<Map<String, dynamic>> fetchReferencePost(int postId) async {
    if (_referencePostCache.containsKey(postId)) {
      return _referencePostCache[postId]!;
    }
    final resp = await ApiService.getPost(postId.toString());
    if (resp['statusCode'] == 200) {
      final postData = resp['body'] as Map<String, dynamic>;
      _referencePostCache[postId] = postData;
      return postData;
    } else {
      throw Exception('无法获取引用帖子');
    }
  }

  // ===== 图片尺寸 =====

  Future<void> loadImageSize() async {
    if (_isLoadingImageSize || imageMedia.isEmpty) return;

    _isLoadingImageSize = true;
    notifyListeners();

    try {
      final imageProvider = NetworkImage(imageMedia.first);
      final ImageStream stream =
          imageProvider.resolve(const ImageConfiguration());
      final Completer<void> completer = Completer<void>();

      ImageStreamListener? listener;
      listener = ImageStreamListener(
        (ImageInfo info, bool synchronousCall) {
          final image = info.image;
          actualImageWidth = image.width.toDouble();
          actualImageHeight = image.height.toDouble();
          _isLoadingImageSize = false;
          notifyListeners();

          stream.removeListener(listener!);
          if (!completer.isCompleted) completer.complete();
        },
        onError: (exception, stackTrace) {
          stream.removeListener(listener!);
          if (!completer.isCompleted) completer.complete();
          _isLoadingImageSize = false;
          notifyListeners();
        },
      );

      stream.addListener(listener);
      await completer.future;
    } catch (e) {
      _isLoadingImageSize = false;
      notifyListeners();
    }
  }

  // ===== 工具 =====

  /// 判断 URL 是否为 PDF。
  bool isPdf(String url) {
    if (url.isEmpty) return false;
    try {
      final uri = Uri.tryParse(url);
      final path = uri?.path.toLowerCase() ?? url.toLowerCase();
      if (path.endsWith('.pdf')) return true;
      if (path.contains('/pdf/') || path.contains('/pdfs/')) return true;
      final query = uri?.queryParameters;
      if (query != null) {
        final type =
            query['type']?.toLowerCase() ?? query['format']?.toLowerCase();
        if (type == 'pdf' || type == 'application/pdf') return true;
      }
      return false;
    } catch (_) {
      return url.toLowerCase().endsWith('.pdf');
    }
  }
}
