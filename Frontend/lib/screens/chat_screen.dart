/// PaperHub 聊天界面
///
/// 功能：
/// - 显示聊天消息列表
/// - 发送文本/媒体消息
/// - 通过 ChatWebSocketService 实时接收新消息
/// - 消息状态指示
/// - 时间分组显示
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';
import '../services/chat_service.dart';
import '../services/chat_websocket_service.dart';
import '../services/api_service.dart';
import '../services/local_storage.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input.dart';
import 'profile_screen.dart';

class ChatScreen extends StatefulWidget {
  final Conversation? conversation;
  final String? conversationId;

  const ChatScreen({
    Key? key,
    this.conversation,
    this.conversationId,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final ChatWebSocketService _wsService = ChatWebSocketService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();

  bool _loadingConversation = false;
  Conversation? _loadedConversation;
  bool _initialLoadComplete = false;
  int _previousMessageCount = 0;
  String? _currentUserId;
  bool _userHasScrolled = false;

  StreamSubscription<Message>? _wsSubscription;

  @override
  void initState() {
    super.initState();
    _currentUserId = LocalStorage.instance.read('userId');
    _initializeConversation();
    _scrollController.addListener(_scrollListener);
    _chatService.addListener(_onChatServiceChanged);
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _wsService.disconnect();
    _chatService.removeListener(_onChatServiceChanged);
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _onChatServiceChanged() {
    if (mounted && !_chatService.isLoadingMessages) {
      final currentCount = _chatService.messages.length;
      final shouldScroll =
          currentCount > _previousMessageCount && _isNearBottom();
      setState(() {});
      if (shouldScroll) {
        _scrollToBottom(force: true);
      }
      _previousMessageCount = currentCount;
    }
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    return position.maxScrollExtent - position.pixels < 100;
  }

  Future<void> _initializeConversation() async {
    // Case 1: conversation object provided directly
    if (widget.conversation != null) {
      await _setupConversation(widget.conversation!);
      return;
    }

    // Case 2: conversationId provided, need to look up
    if (widget.conversationId != null) {
      setState(() => _loadingConversation = true);

      Conversation conversation;
      try {
        final result = await ApiService.getConversations();
        if (result['statusCode'] == 200) {
          final List<dynamic> data = result['body'];
          final conversations =
              data.map((json) => Conversation.fromJson(json)).toList();
          conversation = conversations.firstWhere(
            (c) => c.id == widget.conversationId,
            orElse: () => _buildFallbackConversation(),
          );
        } else {
          conversation = _buildFallbackConversation();
        }
      } catch (e) {
        conversation = _buildFallbackConversation();
      }

      setState(() {
        _loadedConversation = conversation;
        _loadingConversation = false;
      });

      await _setupConversation(conversation);
    }
  }

  Conversation _buildFallbackConversation() {
    return Conversation(
      id: widget.conversationId!,
      name: 'Unknown User',
      type: ConversationType.private,
      participants: [],
      updatedAt: DateTime.now(),
    );
  }

  /// 统一的会话初始化：加载消息、预加载媒体、启动 WebSocket 订阅
  Future<void> _setupConversation(Conversation conversation) async {
    _chatService.setCurrentConversation(conversation);
    await _chatService.loadMessages(conversation.id, page: 0);
    await _preloadMedia();

    setState(() {
      _initialLoadComplete = true;
      _previousMessageCount = _chatService.messages.length;
    });

    _scrollToBottom(force: false);
    _startWebSocketSubscription(conversation.id);
  }

  /// 通过 WebSocket 订阅新消息，替代原有的 2s Timer 轮询
  void _startWebSocketSubscription(String conversationId) {
    _wsSubscription?.cancel();
    _wsService.setConversationId(conversationId);
    _wsService.connect();

    _wsSubscription = _wsService.newMessageStream.listen((message) {
      if (!mounted) return;
      // 新消息到达时，追加到 ChatService 的消息列表
      final exists = _chatService.messages.any((m) => m.id == message.id);
      if (!exists) {
        _chatService.messages.add(message);
        setState(() {});
        _scrollToBottom(force: true);
      }
    });
  }

  Future<void> _loadMoreMessagesIfNeeded() async {
    final conversation = widget.conversation ?? _loadedConversation;
    if (conversation == null) return;

    if (_chatService.hasMoreMessages && !_chatService.isLoadingMoreMessages) {
      double distanceFromBottom = 0;
      if (_scrollController.hasClients) {
        final maxExtent = _scrollController.position.maxScrollExtent;
        distanceFromBottom = maxExtent - _scrollController.offset;
      }

      final int beforeMessageCount = _chatService.messages.length;
      await _chatService.loadMessages(conversation.id,
          page: _chatService.currentPage + 1);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        final int afterMessageCount = _chatService.messages.length;
        final int loadedMessageCount =
            afterMessageCount - beforeMessageCount;
        if (loadedMessageCount > 0) {
          final newMaxExtent =
              _scrollController.position.maxScrollExtent;
          final double newOffset = newMaxExtent - distanceFromBottom;
          _scrollController
              .jumpTo(newOffset.clamp(0.0, newMaxExtent));
        }
      });
    }
  }

  void _scrollListener() {
    if (_scrollController.hasClients &&
        _scrollController.position.userScrollDirection !=
            ScrollDirection.idle) {
      _userHasScrolled = true;
    }

    final conversation = widget.conversation ?? _loadedConversation;
    if (conversation != null &&
        _scrollController.offset >=
            _scrollController.position.maxScrollExtent - 100) {
      _chatService.markAsRead(conversation.id);
    }

    if (_scrollController.hasClients &&
        _scrollController.offset <= 100) {
      _loadMoreMessagesIfNeeded();
    }
  }

  void _onSendMessage(String content) {
    if (content.trim().isEmpty) return;
    final conversation = widget.conversation ?? _loadedConversation;
    if (conversation == null) return;

    _chatService.sendMessage(
      conversationId: conversation.id,
      content: content.trim(),
    );
    _textController.clear();
    _previousMessageCount = _chatService.messages.length;
    _scrollToBottom(force: true);
  }

  void _onSendMedia(List<String> mediaUrls, String messageType,
      String fileName, int fileSize) {
    final conversation = widget.conversation ?? _loadedConversation;
    if (conversation == null) return;

    MessageType type = MessageType.image;
    if (messageType == 'FILE') {
      type = MessageType.file;
    } else if (messageType == 'IMAGE') {
      type = MessageType.image;
    } else if (messageType == 'VIDEO') {
      type = MessageType.video;
    } else if (messageType == 'VOICE') {
      type = MessageType.voice;
    }

    _chatService.sendMessageWithMedia(
      conversationId: conversation.id,
      mediaUrls: mediaUrls,
      type: type,
      fileName: fileName,
      fileSize: fileSize,
    );
    _previousMessageCount = _chatService.messages.length;
    _scrollToBottom(force: true);
  }

  Future<void> _preloadMedia() async {
    final messages = _chatService.messages;
    final List<Future<void>> preloadFutures = [];

    for (final message in messages) {
      if (message.type == MessageType.image &&
          message.mediaUrls.isNotEmpty) {
        for (final url in message.mediaUrls) {
          try {
            final imageProvider = NetworkImage(url);
            final future = precacheImage(imageProvider, context);
            preloadFutures.add(future);
          } catch (e) {
            debugPrint('预加载图片失败: $e');
          }
        }
      }
    }

    if (preloadFutures.isNotEmpty) {
      await Future.wait(preloadFutures.map((future) =>
          future.timeout(const Duration(seconds: 5),
              onTimeout: () {
                debugPrint('图片预加载超时');
                return;
              })));
    }
  }

  void _scrollToBottom({bool force = false}) {
    if (!mounted) return;
    if (!force && _userHasScrolled) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_scrollController.hasClients) return;

      final hasVoiceMessages = _chatService.messages
          .any((msg) => msg.type == MessageType.voice);
      final int maxRetries = hasVoiceMessages ? 5 : 3;

      double previousMaxExtent = 0;
      int stableFrameCount = 0;

      for (int retry = 0; retry < maxRetries; retry++) {
        await Future.delayed(Duration(
            milliseconds:
                hasVoiceMessages ? 150 * (retry + 1) : 100 * (retry + 1)));

        if (!mounted || !_scrollController.hasClients) return;

        final maxExtent = _scrollController.position.maxScrollExtent;
        if (maxExtent > 0) {
          _scrollController.jumpTo(maxExtent);
        }

        if (_scrollController.hasClients) {
          final currentMaxExtent =
              _scrollController.position.maxScrollExtent;
          if ((currentMaxExtent - previousMaxExtent).abs() < 1.0) {
            stableFrameCount++;
          } else {
            stableFrameCount = 0;
          }
          previousMaxExtent = currentMaxExtent;

          final position = _scrollController.position;
          final isAtBottom =
              position.maxScrollExtent - position.pixels <= 10;
          if (isAtBottom && stableFrameCount >= 2) {
            break;
          }
        }
      }
    });
  }

  String _formatDateHeader(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate =
        DateTime(dateTime.year, dateTime.month, dateTime.day);
    final difference = messageDate.difference(today).inDays;
    switch (difference) {
      case 0:
        return '今天';
      case -1:
        return '昨天';
      default:
        return '${dateTime.month}月${dateTime.day}日';
    }
  }

  void _navigateToUserProfile(String userId) {
    if (userId == _currentUserId) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const ProfilePage()));
    } else {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ProfilePage(userId: userId)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(scheme),
      body: Column(children: [
        Expanded(
          child: _loadingConversation
              ? _buildLoadingView()
              : _buildMessageList(),
        ),
        _buildInputArea(),
      ]),
    );
  }

  PreferredSizeWidget _buildAppBar(ColorScheme scheme) {
    final conversation = widget.conversation ?? _loadedConversation;

    if (conversation == null) {
      return AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        leading: IconButton(
            icon: Icon(Icons.arrow_back, color: scheme.onSurface),
            onPressed: () => Navigator.pop(context)),
        title: Text('加载中...',
            style: TextStyle(
                color: scheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
      );
    }

    return AppBar(
      backgroundColor: scheme.surface,
      elevation: 0,
      leading: IconButton(
          icon: Icon(Icons.arrow_back, color: scheme.onSurface),
          onPressed: () => Navigator.pop(context)),
      title: GestureDetector(
        onTap: () {
          if (conversation.type == ConversationType.private &&
              conversation.participants.isNotEmpty) {
            final otherUser = conversation.participants.firstWhere(
                (p) => !p.isMe,
                orElse: () => conversation.participants.first);
            _navigateToUserProfile(otherUser.id);
          }
        },
        child: Row(children: [
          _buildAppBarAvatar(conversation),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(conversation.displayName,
                    style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                if (conversation.type == ConversationType.group)
                  Text('${conversation.participants.length} 位成员',
                      style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12)),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildAppBarAvatar(Conversation conversation) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          color: Colors.grey[200]),
      child: conversation.displayAvatar != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Image.network(conversation.displayAvatar!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _buildDefaultAvatar(conversation)),
            )
          : _buildDefaultAvatar(conversation),
    );
  }

  Widget _buildDefaultAvatar(Conversation conversation) {
    final name = conversation.displayName;
    final firstChar = name.isNotEmpty ? name[0] : '?';
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
        ),
      ),
      child: Center(
        child: Text(firstChar,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildMessageList() {
    if (!_initialLoadComplete) return _buildLoadingView();

    final messages = _chatService.messages;
    if (messages.isEmpty) return _buildEmptyView();

    return Column(children: [
      if (_chatService.isLoadingMoreMessages)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF1976D2))),
            ),
          ),
        ),
      Expanded(
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 16),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            final showDateHeader = index == 0 ||
                !_isSameDay(
                    messages[index - 1].createdAt, message.createdAt);
            return Column(children: [
              if (showDateHeader) _buildDateHeader(message.createdAt),
              MessageBubble(
                message: message,
                showAvatar: true,
                onAvatarTap: () =>
                    _navigateToUserProfile(message.senderId),
              ),
            ]);
          },
        ),
      ),
    ]);
  }

  Widget _buildDateHeader(DateTime date) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
              color: scheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12)),
          child: Text(_formatDateHeader(date),
              style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(Color(0xFF1976D2)),
                strokeWidth: 2),
            SizedBox(height: 16),
            Text('加载消息中...',
                style: TextStyle(color: Colors.grey, fontSize: 14)),
          ]),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline,
                size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('暂无消息',
                style:
                    TextStyle(color: Colors.grey[600], fontSize: 16)),
            const SizedBox(height: 8),
            Text('开始对话吧',
                style:
                    TextStyle(color: Colors.grey[500], fontSize: 14)),
          ]),
    );
  }

  Widget _buildInputArea() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: scheme.surface, boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 3,
            offset: const Offset(0, -2)),
      ]),
      child: ChatInput(
        controller: _textController,
        onSend: _onSendMessage,
        onSendMedia: _onSendMedia,
        hintText: '输入消息...',
      ),
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}
