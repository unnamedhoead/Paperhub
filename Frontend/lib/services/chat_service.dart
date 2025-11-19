import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';
import 'api_service.dart';

/// 聊天服务类
///
/// 负责处理所有聊天相关的业务逻辑：
/// - 会话管理
/// - 消息发送与接收
/// - WebSocket连接管理
class ChatService extends ChangeNotifier {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  // 会话列表
  List<Conversation> _conversations = [];
  List<Conversation> get conversations => _conversations;

  // 当前聊天会话
  Conversation? _currentConversation;
  Conversation? get currentConversation => _currentConversation;

  // 当前会话的消息列表
  List<Message> _messages = [];
  List<Message> get messages => _messages;

  // 加载状态
  bool _isLoadingConversations = false;
  bool get isLoadingConversations => _isLoadingConversations;

  bool _isLoadingMessages = false;
  bool get isLoadingMessages => _isLoadingMessages;

  // 连接状态
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  // 模拟数据
  void _initMockData() {
    _conversations = [
      Conversation(
        id: '1',
        name: '张同学',
        avatar: 'https://via.placeholder.com/50',
        type: ConversationType.private,
        lastMessage: Message(
          id: 'm1',
          conversationId: '1',
          senderId: 'user1',
          senderName: '张同学',
          senderAvatar: 'https://via.placeholder.com/50',
          content: '论文写得怎么样了？',
          createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
          isMe: false,
        ),
        unreadCount: 2,
        updatedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        participants: [
          ConversationParticipant(
            id: 'user1',
            name: '张同学',
            avatar: 'https://via.placeholder.com/50',
            isOnline: true,
          ),
        ],
        isOnline: true,
      ),
      Conversation(
        id: '2',
        name: '李同学',
        avatar: 'https://via.placeholder.com/50',
        type: ConversationType.private,
        lastMessage: Message(
          id: 'm2',
          conversationId: '2',
          senderId: 'me',
          senderName: '我',
          senderAvatar: 'https://via.placeholder.com/50',
          content: '好的，谢谢！',
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
          isMe: true,
        ),
        unreadCount: 0,
        updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
        participants: [
          ConversationParticipant(
            id: 'user2',
            name: '李同学',
            avatar: 'https://via.placeholder.com/50',
            isOnline: false,
            lastSeen: DateTime.now().subtract(const Duration(minutes: 30)),
          ),
        ],
        isOnline: false,
      ),
      Conversation(
        id: '3',
        name: '学习小组',
        avatar: 'https://via.placeholder.com/50',
        type: ConversationType.group,
        lastMessage: Message(
          id: 'm3',
          conversationId: '3',
          senderId: 'user3',
          senderName: '王同学',
          senderAvatar: 'https://via.placeholder.com/50',
          content: '明天几点讨论？',
          createdAt: DateTime.now().subtract(const Duration(hours: 3)),
          isMe: false,
        ),
        unreadCount: 5,
        updatedAt: DateTime.now().subtract(const Duration(hours: 3)),
        participants: [
          ConversationParticipant(id: 'me', name: '我', isMe: true),
          ConversationParticipant(
            id: 'user3',
            name: '王同学',
            avatar: 'https://via.placeholder.com/50',
            isOnline: true,
          ),
          ConversationParticipant(
            id: 'user4',
            name: '刘同学',
            avatar: 'https://via.placeholder.com/50',
            isOnline: false,
          ),
        ],
        isOnline: false,
      ),
    ];
  }

  /// 获取会话列表
  Future<void> loadConversations() async {
    _isLoadingConversations = true;
    notifyListeners();

    try {
      final resp = await ApiService.get('/api/chat/conversations');
      if (resp['statusCode'] == 200) {
        final body = resp['body'] as Map<String, dynamic>;

        // 解析实际的API响应
        if (body.containsKey('conversations')) {
          final conversationsData = body['conversations'] as List<dynamic>;
          _conversations = conversationsData.map((json) => Conversation.fromJson(json)).toList();
        } else {
          // 如果API返回格式不符合预期，使用模拟数据作为fallback
          debugPrint('API响应格式不符合预期，使用模拟数据');
          _initMockData();
        }

        _conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      } else {
        // API调用失败，使用模拟数据
        debugPrint('API调用失败，状态码: ${resp['statusCode']}');
        _initMockData();
        _conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      }
    } catch (e) {
      debugPrint('加载会话列表失败: $e');
      // 出错时使用模拟数据
      _initMockData();
      _conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } finally {
      _isLoadingConversations = false;
      notifyListeners();
    }
  }

  /// 获取指定会话的消息列表
  Future<void> loadMessages(String conversationId) async {
    _isLoadingMessages = true;
    notifyListeners();

    try {
      // 调用实际API获取消息
      final resp = await ApiService.get('/api/chat/messages/$conversationId');

      if (resp['statusCode'] == 200) {
        final body = resp['body'] as Map<String, dynamic>;

        // 解析实际的API响应
        if (body.containsKey('messages')) {
          final messagesData = body['messages'] as List<dynamic>;
          _messages = messagesData.map((json) => Message.fromJson(json)).toList();
        } else {
          // 如果API返回格式不符合预期，使用模拟数据作为fallback
          debugPrint('消息API响应格式不符合预期，使用模拟数据');
          _initMockMessages(conversationId);
        }
      } else {
        // API调用失败，使用模拟数据
        debugPrint('获取消息API调用失败，状态码: ${resp['statusCode']}');
        _initMockMessages(conversationId);
      }
    } catch (e) {
      debugPrint('加载消息失败: $e');
      // 出错时使用模拟数据
      _initMockMessages(conversationId);
    } finally {
      _isLoadingMessages = false;
      notifyListeners();
    }
  }

  /// 初始化模拟消息数据
  void _initMockMessages(String conversationId) {
    _messages = [
      Message(
        id: 'msg1',
        conversationId: conversationId,
        senderId: 'other',
        senderName: '张同学',
        senderAvatar: 'https://via.placeholder.com/50',
        content: '你好！最近在忙什么？',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        isMe: false,
      ),
      Message(
        id: 'msg2',
        conversationId: conversationId,
        senderId: 'me',
        senderName: '我',
        senderAvatar: 'https://via.placeholder.com/50',
        content: '在写论文，有点头疼',
        createdAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 50)),
        isMe: true,
      ),
      Message(
        id: 'msg3',
        conversationId: conversationId,
        senderId: 'other',
        senderName: '张同学',
        senderAvatar: 'https://via.placeholder.com/50',
        content: '论文写得怎么样了？',
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        isMe: false,
      ),
    ];
  }

  /// 发送消息
  Future<void> sendMessage({
    required String conversationId,
    required String content,
    MessageType type = MessageType.text,
  }) async {
    final newMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      conversationId: conversationId,
      senderId: 'me',
      senderName: '我',
      senderAvatar: 'https://via.placeholder.com/50',
      content: content,
      type: type,
      createdAt: DateTime.now(),
      status: MessageStatus.sending,
      isMe: true,
    );

    _messages.add(newMessage);
    notifyListeners();

    try {
      // 调用实际API发送消息
      final resp = await ApiService.post('/api/chat/sendMessage', {
        'contactId': conversationId,
        'messageContent': content,
        'messageType': type == MessageType.text ? 0 : 1,
      });

      if (resp['statusCode'] == 200) {
        // 更新消息状态为已发送
        final updatedMessage = newMessage.copyWith(status: MessageStatus.sent);
        final index = _messages.indexWhere((m) => m.id == newMessage.id);
        if (index != -1) {
          _messages[index] = updatedMessage;
          notifyListeners();
        }

        // 更新会话的最后消息
        _updateLastMessage(conversationId, updatedMessage);
      } else {
        throw Exception('发送失败: ${resp['body']}');
      }
    } catch (e) {
      debugPrint('发送消息失败: $e');

      // 更新消息状态为发送失败
      final failedMessage = newMessage.copyWith(status: MessageStatus.failed);
      final index = _messages.indexWhere((m) => m.id == newMessage.id);
      if (index != -1) {
        _messages[index] = failedMessage;
        notifyListeners();
      }
    }
  }

  /// 设置当前会话
  void setCurrentConversation(Conversation conversation) {
    _currentConversation = conversation;
    loadMessages(conversation.id);
  }

  /// 更新会话的最后消息
  void _updateLastMessage(String conversationId, Message message) {
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      _conversations[index] = _conversations[index].copyWith(
        lastMessage: message,
        updatedAt: message.createdAt,
      );
      // 重新排序
      _conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      notifyListeners();
    }
  }

  /// 标记消息为已读
  Future<void> markAsRead(String conversationId) async {
    try {
      // TODO: 替换为实际的API调用
      await Future.delayed(const Duration(milliseconds: 300));

      final index = _conversations.indexWhere((c) => c.id == conversationId);
      if (index != -1 && _conversations[index].unreadCount > 0) {
        _conversations[index] = _conversations[index].copyWith(unreadCount: 0);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('标记已读失败: $e');
    }
  }

  /// 搜索会话
  List<Conversation> searchConversations(String query) {
    if (query.isEmpty) return _conversations;

    return _conversations.where((conversation) {
      return conversation.displayName.toLowerCase().contains(query.toLowerCase()) ||
          (conversation.lastMessage?.content.toLowerCase().contains(query.toLowerCase()) ?? false);
    }).toList();
  }

  /// 删除会话
  Future<void> deleteConversation(String conversationId) async {
    try {
      // TODO: 替换为实际的API调用
      await Future.delayed(const Duration(milliseconds: 500));

      _conversations.removeWhere((c) => c.id == conversationId);
      if (_currentConversation?.id == conversationId) {
        _currentConversation = null;
        _messages.clear();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('删除会话失败: $e');
    }
  }
}