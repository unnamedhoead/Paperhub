import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test/models/conversation_model.dart';
import 'package:test/models/message_model.dart';
import 'package:test/services/chat_service.dart';
import 'package:test/services/local_storage.dart';

/// chat_service.dart 单元测试。
///
/// ChatService 的写/读方法最终都经 ApiService -> HttpClient -> http.* 打到
/// AppEnv.apiBaseUrl（测试态默认 http://localhost:8080）。这里复用
/// http_client_test.dart 的本地 stub HttpServer 模式：在 8080 起一个回声服务器
/// 按路径/方法返回构造好的 JSON，从而在不引入新依赖、不改业务逻辑的前提下，
/// 对 ChatService 的会话/消息编排做真实端到端验证。
///
/// ChatService 是单例，状态跨用例保留，故每个用例在 setUp 里清空其暴露的列表。

/// 本地 stub 服务器是否成功绑定。
bool serverAvailable = false;

/// 仅当本地 stub 服务器可用时才执行 [body]。
Future<void> serverRequired(Future<void> Function() body) async {
  if (!serverAvailable) return;
  await body();
}

/// 构造一条符合后端形状的消息 JSON。
Map<String, dynamic> _msgJson(String id, String conversationId, String content,
    {String createdAt = '2024-01-01T00:00:00.000Z'}) {
  return {
    'id': id,
    'conversationId': conversationId,
    'senderId': 'other',
    'senderName': '对方',
    'senderAvatar': '',
    'content': content,
    'type': 'TEXT',
    'createdAt': createdAt,
    'status': 'sent',
    'isMe': false,
  };
}

void main() {
  final chatService = ChatService();

  // 清空单例状态，避免用例间相互污染。
  void resetService() {
    chatService.conversations.clear();
    chatService.messages.clear();
  }

  // ==========================================================================
  // 纯逻辑：不需要服务器
  // ==========================================================================
  group('pure logic (no server)', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LocalStorage.instance.init();
      // 单例 LocalStorage 的 _prefs 可能已被其它用例固定，setMockInitialValues
      // 不一定能清掉已写入的 token，这里显式删除以确保走"无 token"守卫分支。
      await LocalStorage.instance.delete('accessToken');
      resetService();
    });

    test('searchConversations 空列表返回空', () {
      expect(chatService.searchConversations('张'), isEmpty);
    });

    test('loadConversations 无 token 时直接清空且不抛异常', () async {
      // 先塞一条脏数据，确认守卫分支会清掉它。
      chatService.conversations.add(Conversation(
        id: 'stale',
        name: 'stale',
        updatedAt: DateTime.now(),
      ));

      await chatService.loadConversations(); // 无 accessToken -> 守卫分支
      expect(chatService.conversations, isEmpty);
      expect(chatService.isLoadingConversations, isFalse);
    });
  });

  // ==========================================================================
  // 端到端：本地 stub 服务器（8080）
  // ==========================================================================
  group('with local stub server', () {
    late HttpServer server;

    setUpAll(() async {
      try {
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8080);
        serverAvailable = true;
      } on SocketException {
        serverAvailable = false;
        return;
      }

      server.listen((HttpRequest request) async {
        final path = request.uri.path;
        final method = request.method;

        void writeJson(Object body, [int status = 200]) {
          request.response
            ..statusCode = status
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(body));
          request.response.close();
        }

        // GET /api/conversations —— 故意乱序，验证 ChatService 按 updatedAt 降序排。
        if (method == 'GET' && path == '/api/conversations') {
          writeJson([
            {
              'id': '1',
              'displayName': '早会话',
              'updatedAt': '2024-01-01T00:00:00.000Z',
              'unreadCount': 3,
              'participants': [],
            },
            {
              'id': '2',
              'displayName': '新会话',
              'updatedAt': '2024-06-01T00:00:00.000Z',
              'unreadCount': 0,
              'participants': [],
            },
          ]);
          return;
        }

        // POST /api/conversations —— 创建/获取私聊会话。
        if (method == 'POST' && path == '/api/conversations') {
          writeJson({
            'id': '99',
            'displayName': '新建私聊',
            'displayAvatar': null,
            'unreadCount': 0,
            'updatedAt': '2024-07-01T00:00:00.000Z',
            'isOnline': true,
          });
          return;
        }

        // GET /api/conversations/{id}/messages —— 按 page 返回不同分页。
        final msgMatch =
            RegExp(r'^/api/conversations/(\w+)/messages$').firstMatch(path);
        if (method == 'GET' && msgMatch != null) {
          final page = request.uri.queryParameters['page'] ?? '0';
          if (page == '0') {
            // 后端按时间倒序返回（最新在前）。
            writeJson({
              'content': [
                _msgJson('m2', '1', '第二条',
                    createdAt: '2024-01-01T00:00:02.000Z'),
                _msgJson('m1', '1', '第一条',
                    createdAt: '2024-01-01T00:00:01.000Z'),
              ],
              'number': 0,
              'totalPages': 2,
            });
          } else {
            writeJson({
              'content': [
                _msgJson('m0', '1', '更早的历史',
                    createdAt: '2024-01-01T00:00:00.000Z'),
              ],
              'number': 1,
              'totalPages': 2,
            });
          }
          return;
        }

        // POST /api/conversations/{id}/messages —— 回声一条带服务器 id 的消息。
        final sendMatch =
            RegExp(r'^/api/conversations/(\w+)/messages$').firstMatch(path);
        if (method == 'POST' && sendMatch != null) {
          final raw = await utf8.decoder.bind(request).join();
          final body = jsonDecode(raw) as Map<String, dynamic>;
          writeJson({
            'id': 'server-id',
            'conversationId': sendMatch.group(1),
            'senderId': 'me',
            'senderName': '我',
            'senderAvatar': '',
            'content': body['content'] ?? '',
            'type': body['type'] ?? 'TEXT',
            'mediaUrls': body['mediaUrls'] ?? [],
            // 用接近"现在"的时间，让 ChatService 的"内容+时间(≤3s)"
            // 匹配逻辑能把本地临时消息替换掉，而非追加为新消息。
            'createdAt': DateTime.now().toUtc().toIso8601String(),
            'status': 'sent',
            'isMe': true,
          });
          return;
        }

        // PUT /api/conversations/{id}/read —— 标记已读。
        if (method == 'PUT' && path.endsWith('/read')) {
          writeJson({'message': 'ok'});
          return;
        }

        writeJson({'message': 'not-found'}, 404);
      });
    });

    tearDownAll(() async {
      if (serverAvailable) {
        await server.close();
      }
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LocalStorage.instance.init();
      // 用 write 而非 setMockInitialValues 写 token：单例 _prefs 已固定时，
      // 后者不一定生效，write 会同时更新内存缓存与 _prefs，确保守卫放行。
      await LocalStorage.instance.write('accessToken', 'test-token');
      resetService();
    });

    test('loadConversations 拉取并按 updatedAt 降序排序',
        () => serverRequired(() async {
      await chatService.loadConversations();

      expect(chatService.conversations.length, 2);
      // 新会话(2024-06) 应排在早会话(2024-01) 前面。
      expect(chatService.conversations.first.id, '2');
      expect(chatService.conversations.last.id, '1');
    }));

    test('searchConversations 按名称过滤已加载的会话',
        () => serverRequired(() async {
      await chatService.loadConversations();

      final hit = chatService.searchConversations('新会话');
      expect(hit.length, 1);
      expect(hit.first.id, '2');

      expect(chatService.searchConversations('不存在'), isEmpty);
      // 空查询返回全部。
      expect(chatService.searchConversations('').length, 2);
    }));

    test('loadMessages page0 替换列表并反转为时间升序',
        () => serverRequired(() async {
      await chatService.loadMessages('1', page: 0);

      expect(chatService.messages.length, 2);
      // 后端倒序 [m2, m1] 反转后应为升序 [m1, m2]。
      expect(chatService.messages.first.id, 'm1');
      expect(chatService.messages.last.id, 'm2');
      expect(chatService.currentPage, 0);
      expect(chatService.totalPages, 2);
      expect(chatService.hasMoreMessages, isTrue);
    }));

    test('loadMessages page1 把历史消息前插到列表开头',
        () => serverRequired(() async {
      await chatService.loadMessages('1', page: 0);
      await chatService.loadMessages('1', page: 1);

      expect(chatService.messages.length, 3);
      // 更早的历史 m0 应在最前。
      expect(chatService.messages.first.id, 'm0');
      expect(chatService.messages[1].id, 'm1');
      expect(chatService.messages.last.id, 'm2');
      expect(chatService.currentPage, 1);
      expect(chatService.hasMoreMessages, isFalse);
    }));

    test('sendMessage 用服务器消息替换本地临时消息',
        () => serverRequired(() async {
      await chatService.sendMessage(
        conversationId: '1',
        content: '你好',
      );

      // 临时消息被替换为服务器返回(带 server-id)，只剩一条。
      expect(chatService.messages.length, 1);
      expect(chatService.messages.first.id, 'server-id');
      expect(chatService.messages.first.content, '你好');
      expect(chatService.messages.first.status, MessageStatus.sent);
    }));

    test('sendMessageWithMedia 透传 mediaUrls 并替换为服务器消息',
        () => serverRequired(() async {
      await chatService.sendMessageWithMedia(
        conversationId: '1',
        mediaUrls: const ['https://example.com/a.png'],
        type: MessageType.image,
      );

      expect(chatService.messages.length, 1);
      final msg = chatService.messages.first;
      expect(msg.id, 'server-id');
      expect(msg.type, MessageType.image);
      expect(msg.mediaUrls, ['https://example.com/a.png']);
    }));

    test('markAsRead 把匹配会话的未读数清零',
        () => serverRequired(() async {
      await chatService.loadConversations();
      // 早会话(id=1) 初始 unreadCount=3。
      expect(
        chatService.conversations.firstWhere((c) => c.id == '1').unreadCount,
        3,
      );

      await chatService.markAsRead('1');

      expect(
        chatService.conversations.firstWhere((c) => c.id == '1').unreadCount,
        0,
      );
    }));

    test('createOrGetPrivateConversation 返回会话并加入列表',
        () => serverRequired(() async {
      final conv = await chatService.createOrGetPrivateConversation('99');

      expect(conv, isNotNull);
      expect(conv!.id, '99');
      expect(chatService.conversations.any((c) => c.id == '99'), isTrue);
    }));
  });
}
