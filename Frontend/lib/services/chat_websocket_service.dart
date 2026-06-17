/// Chat WebSocket Service — 聊天消息实时推送
///
/// 连接到后端 `/ws/chat/{userId}` 端点，接收新消息推送。
/// 替代原有的 2s Timer 轮询机制。
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/app_env.dart';
import '../models/message_model.dart';
import 'local_storage.dart';

class ChatWebSocketService extends ChangeNotifier {
  static final ChatWebSocketService _instance =
      ChatWebSocketService._internal();
  factory ChatWebSocketService() => _instance;
  ChatWebSocketService._internal();

  WebSocketChannel? _channel;
  bool _isConnected = false;
  int? _currentUserId;

  /// 当前订阅的会话 ID
  String? _currentConversationId;

  /// 接收到的新消息列表（从 WebSocket 推送）
  final StreamController<Message> _newMessageController =
      StreamController<Message>.broadcast();

  /// 新消息流，供 UI 订阅
  Stream<Message> get newMessageStream => _newMessageController.stream;

  bool get isConnected => _isConnected;

  // 重连管理
  Timer? _reconnectTimer;
  static const Duration _reconnectInterval = Duration(seconds: 5);
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;

  // 心跳保活
  Timer? _heartbeatTimer;
  static const Duration _heartbeatInterval = Duration(seconds: 30);

  /// 连接到聊天 WebSocket
  Future<void> connect() async {
    if (_isConnected && _channel != null) return;

    try {
      final userId = await _getCurrentUserId();
      if (userId == null) {
        debugPrint('[ChatWS] 未登录，不连接聊天 WebSocket');
        return;
      }
      _currentUserId = userId;

      final wsUrl = '${AppEnv.wsBaseUrl}/ws/chat/$userId';
      debugPrint('[ChatWS] 连接: $wsUrl');

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDone,
      );

      _isConnected = true;
      _reconnectAttempts = 0;
      debugPrint('[ChatWS] 连接成功');

      _startHeartbeat();
    } catch (e) {
      debugPrint('[ChatWS] 连接失败: $e');
      _isConnected = false;
      _scheduleReconnect();
    }
  }

  /// 断开连接
  void disconnect() {
    _stopHeartbeat();
    _stopReconnectTimer();
    if (_channel != null) {
      _channel!.sink.close();
      _channel = null;
    }
    _isConnected = false;
    _currentConversationId = null;
  }

  /// 设置当前监听的会话 ID
  void setConversationId(String conversationId) {
    _currentConversationId = conversationId;
  }

  /// 处理 WebSocket 消息
  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      final type = data['type'] as String?;

      if (type == null) return;

      switch (type) {
        case 'NEW_MESSAGE':
          _handleNewMessage(data);
          break;
        case 'CONVERSATION_UPDATE':
          // 会话更新（最后消息等），由 ChatService 处理
          break;
        case 'pong':
          // 心跳响应
          break;
        default:
          debugPrint('[ChatWS] 未知消息类型: $type');
      }
    } catch (e) {
      debugPrint('[ChatWS] 解析消息失败: $e');
    }
  }

  /// 处理新消息推送
  void _handleNewMessage(Map<String, dynamic> data) {
    try {
      final messageData = data['message'] as Map<String, dynamic>?;
      if (messageData == null) return;

      final message = Message.fromJson(messageData);

      // 只处理当前会话的消息
      if (_currentConversationId != null &&
          message.conversationId == _currentConversationId) {
        _newMessageController.add(message);
      }

      // 无论是否当前会话，都通知 ChatService 更新会话列表
      notifyListeners();
    } catch (e) {
      debugPrint('[ChatWS] 处理新消息失败: $e');
    }
  }

  void _handleError(dynamic error) {
    debugPrint('[ChatWS] 错误: $error');
    _isConnected = false;
    _scheduleReconnect();
  }

  void _handleDone() {
    debugPrint('[ChatWS] 连接关闭');
    _isConnected = false;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _stopReconnectTimer();

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('[ChatWS] 已达到最大重连次数');
      return;
    }

    _reconnectAttempts++;
    debugPrint(
        '[ChatWS] 调度重连，尝试 $_reconnectAttempts/$_maxReconnectAttempts');

    _reconnectTimer = Timer(_reconnectInterval, () => connect());
  }

  void _stopReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (timer) {
      if (_isConnected && _channel != null) {
        try {
          final heartbeat = jsonEncode({
            'type': 'ping',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
          _channel!.sink.add(heartbeat);
        } catch (e) {
          debugPrint('[ChatWS] 心跳发送失败: $e');
          _isConnected = false;
          _scheduleReconnect();
        }
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<int?> _getCurrentUserId() async {
    final cachedUserId = LocalStorage.instance.read('userId');
    if (cachedUserId != null && cachedUserId.isNotEmpty) {
      final int? id = int.tryParse(cachedUserId);
      if (id != null) return id;
    }
    return null;
  }

  @override
  void dispose() {
    disconnect();
    _newMessageController.close();
    super.dispose();
  }
}
