/// PaperHub 聊天界面
///
/// 功能：
/// - 显示聊天消息列表
/// - 发送文本/媒体消息
/// - 通过 ChatWebSocketService 实时接收新消息
/// - 消息状态指示
/// - 时间分组显示
///
/// 视图拆分为 screens/chat/ 下的 ChatAppBar / ChatMessageList /
/// ChatInputArea 三个独立 Widget；本 State 只保留会话初始化、滚动分页、
/// WebSocket 订阅与消息发送等控制逻辑。
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';
import '../services/chat_service.dart';
import '../services/chat_websocket_service.dart';
import '../services/api_service.dart';
import '../services/local_storage.dart';
import 'chat/chat_app_bar.dart';
import 'chat/chat_input_area.dart';
import 'chat/chat_message_list.dart';
import 'chat/chat_scroll_manager.dart';
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
  late final ChatScrollManager _scrollManager;

  bool _loadingConversation = false;
  Conversation? _loadedConversation;
  bool _initialLoadComplete = false;
  int _previousMessageCount = 0;
  String? _currentUserId;

  StreamSubscription<Message>? _wsSubscription;

  /// 当前会话（直接传入或按 id 查到的）。
  Conversation? get _conversation => widget.conversation ?? _loadedConversation;

  @override
  void initState() {
    super.initState();
    _currentUserId = LocalStorage.instance.read('userId');
    _scrollManager = ChatScrollManager(
      scrollController: _scrollController,
      chatService: _chatService,
      conversationId: () => _conversation?.id,
      isMounted: () => mounted,
    );
    _initializeConversation();
    _scrollController.addListener(_scrollManager.onScroll);
    _chatService.addListener(_onChatServiceChanged);
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _wsService.disconnect();
    _chatService.removeListener(_onChatServiceChanged);
    _scrollController.removeListener(_scrollManager.onScroll);
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _onChatServiceChanged() {
    if (mounted && !_chatService.isLoadingMessages) {
      final currentCount = _chatService.messages.length;
      final shouldScroll = currentCount > _previousMessageCount &&
          _scrollManager.isNearBottom();
      setState(() {});
      if (shouldScroll) {
        _scrollManager.scrollToBottom(force: true);
      }
      _previousMessageCount = currentCount;
    }
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

    _scrollManager.scrollToBottom(force: false);
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
        _scrollManager.scrollToBottom(force: true);
      }
    });
  }

  void _onSendMessage(String content) {
    if (content.trim().isEmpty) return;
    final conversation = _conversation;
    if (conversation == null) return;

    _chatService.sendMessage(
      conversationId: conversation.id,
      content: content.trim(),
    );
    _textController.clear();
    _previousMessageCount = _chatService.messages.length;
    _scrollManager.scrollToBottom(force: true);
  }

  void _onSendMedia(List<String> mediaUrls, String messageType,
      String fileName, int fileSize) {
    final conversation = _conversation;
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
    _scrollManager.scrollToBottom(force: true);
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
      await Future.wait(preloadFutures.map((future) => future.timeout(
          const Duration(seconds: 5), onTimeout: () {
        debugPrint('图片预加载超时');
        return;
      })));
    }
  }

  void _navigateToUserProfile(String userId) {
    if (userId == _currentUserId) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const ProfilePage()));
    } else {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => ProfilePage(userId: userId)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: ChatAppBar(
        conversation: _conversation,
        onBack: () => Navigator.pop(context),
        onTitleTap: _navigateToUserProfile,
      ),
      body: Column(children: [
        Expanded(
          child: ChatMessageList(
            messages: _chatService.messages,
            scrollController: _scrollController,
            // 会话加载中时复用列表的加载视图，保持原行为一致。
            initialLoadComplete:
                _loadingConversation ? false : _initialLoadComplete,
            isLoadingMoreMessages: _chatService.isLoadingMoreMessages,
            onAvatarTap: _navigateToUserProfile,
          ),
        ),
        ChatInputArea(
          controller: _textController,
          onSend: _onSendMessage,
          onSendMedia: _onSendMedia,
        ),
      ]),
    );
  }
}
