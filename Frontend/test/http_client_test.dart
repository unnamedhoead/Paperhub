import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test/services/core/http_client.dart';
import 'package:test/services/local_storage.dart';

/// Whether the local test server is available.
bool serverAvailable = false;

/// Runs [body] only when the local test server bound successfully.
Future<void> serverRequired(Future<void> Function() body) async {
  if (!serverAvailable) return;
  await body();
}

void main() {
  // =========================================================================
  // parseResponse — pure function, no dependencies
  // =========================================================================
  group('parseResponse', () {
    test('decodes json body with status code', () {
      final result = HttpClient.instance.parseResponse(
        http.Response('{"message":"ok","value":1}', 200),
      );

      expect(result['statusCode'], 200);
      expect(result['body']['message'], 'ok');
      expect(result['body']['value'], 1);
    });

    test('handles empty 204 response', () {
      final result =
          HttpClient.instance.parseResponse(http.Response('', 204));

      expect(result['statusCode'], 204);
      expect(result['body']['message'], '操作成功');
    });

    test('handles empty non-204 response', () {
      final result =
          HttpClient.instance.parseResponse(http.Response('', 201));

      expect(result['statusCode'], 201);
      expect(result['body']['message'], '服务器返回空响应');
    });

    test('handles whitespace-only body', () {
      final result =
          HttpClient.instance.parseResponse(http.Response('  ', 500));

      expect(result['statusCode'], 500);
      expect(result['body']['message'], '服务器返回空响应');
    });

    test('handles invalid json response', () {
      final result = HttpClient.instance.parseResponse(
        http.Response('not-json', 500),
      );

      expect(result['statusCode'], 500);
      expect(result['body']['message'], '服务器响应格式错误');
    });

    test('handles valid json array response', () {
      final result = HttpClient.instance.parseResponse(
        http.Response('[1,2,3]', 200),
      );

      expect(result['statusCode'], 200);
      expect(result['body'], isA<List>());
      expect(result['body'], [1, 2, 3]);
    });
  });

  // =========================================================================
  // send() with mock RawRequest — core response-handling logic
  // =========================================================================
  group('send with mock RawRequest', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LocalStorage.instance.init();
      HttpClient.instance.onAuthFailed = null;
    });

    test('returns parsed result on 200', () async {
      final result = await HttpClient.instance.send(
        () async => http.Response('{"data":"ok"}', 200),
        '/api/test',
      );

      expect(result['statusCode'], 200);
      expect(result['body']['data'], 'ok');
    });

    test('returns parsed result on non-200, non-401', () async {
      final result = await HttpClient.instance.send(
        () async => http.Response('{"error":"not found"}', 404),
        '/api/items/1',
      );

      expect(result['statusCode'], 404);
      expect(result['body']['error'], 'not found');
    });

    test('does not retry when 401 on /auth/refresh path', () async {
      int callCount = 0;
      final result = await HttpClient.instance.send(
        () async {
          callCount++;
          return http.Response('{}', 401);
        },
        '/auth/refresh',
      );

      expect(result['statusCode'], 401);
      expect(callCount, 1);
    });

    test('propagates SocketException from requestFn', () async {
      expect(
        () => HttpClient.instance.send(
          () async => throw SocketException('Connection refused'),
          '/api/test',
        ),
        throwsA(isA<SocketException>()),
      );
    });

    test('propagates generic Exception from requestFn', () async {
      expect(
        () => HttpClient.instance.send(
          () async => throw Exception('network error'),
          '/api/test',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  // =========================================================================
  // 401 token refresh — failure paths (no server needed)
  // =========================================================================
  group('401 token refresh failure paths', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LocalStorage.instance.init();
      HttpClient.instance.onAuthFailed = null;
    });

    test('refresh fails when no refreshToken stored', () async {
      SharedPreferences.setMockInitialValues({
        'accessToken': 'old-access-token',
      });
      await LocalStorage.instance.init();

      final result = await HttpClient.instance.send(
        () async => http.Response('{}', 401),
        '/api/protected',
      );

      expect(result['statusCode'], 401);
      expect(result['body']['message'], '刷新Token失败，请重新登录');
    });

    test('refresh failure clears tokens and calls onAuthFailed', () async {
      SharedPreferences.setMockInitialValues({
        'accessToken': 'old-access-token',
      });
      await LocalStorage.instance.init();

      bool authFailedCalled = false;
      HttpClient.instance.onAuthFailed = () {
        authFailedCalled = true;
      };

      final result = await HttpClient.instance.send(
        () async => http.Response('{}', 401),
        '/api/protected',
      );

      expect(result['statusCode'], 401);
      expect(authFailedCalled, isTrue);
      expect(LocalStorage.instance.read('accessToken'), isNull);
      expect(LocalStorage.instance.read('refreshToken'), isNull);
    });

    test('refresh fails when server unreachable', () async {
      SharedPreferences.setMockInitialValues({
        'accessToken': 'old-access-token',
        'refreshToken': 'stale-refresh-token',
      });
      await LocalStorage.instance.init();

      bool authFailedCalled = false;
      HttpClient.instance.onAuthFailed = () {
        authFailedCalled = true;
      };

      // No server running → http.post to /auth/refresh throws.
      final result = await HttpClient.instance.send(
        () async => http.Response('{}', 401),
        '/api/protected',
      );

      expect(result['statusCode'], 401);
      expect(result['body']['message'], '刷新Token失败，请重新登录');
      expect(authFailedCalled, isTrue);
      expect(LocalStorage.instance.read('accessToken'), isNull);
      expect(LocalStorage.instance.read('refreshToken'), isNull);
    });
  });

  // =========================================================================
  // Integration tests — local server on 8080
  // =========================================================================
  group('HTTP methods with local server', () {
    late HttpServer server;

    setUpAll(() async {
      try {
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8080);
        serverAvailable = true;
      } on SocketException {
        serverAvailable = false;
        return;
      }

      server.listen((HttpRequest request) {
        final path = request.uri.path;
        final method = request.method;

        if (method == 'POST' && path == '/auth/refresh') {
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({
              'token': 'new-access-token-from-server',
              'refreshToken': 'new-refresh-token-from-server',
            }));
          request.response.close();
          return;
        }

        // Default: echo method + path
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({
            'ok': true,
            'method': method,
            'path': path,
          }));
        request.response.close();
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
      HttpClient.instance.onAuthFailed = null;
    });

    // -- get / post / put / delete -------------------------------------------

    test('get returns 200 on success', () => serverRequired(() async {
      final result = await HttpClient.instance.get('/api/test');
      expect(result['statusCode'], 200);
      expect(result['body']['ok'], true);
      expect(result['body']['method'], 'GET');
    }));

    test('post returns 200 on success', () => serverRequired(() async {
      final result = await HttpClient.instance.post('/api/items',
          body: {'name': 'test'});
      expect(result['statusCode'], 200);
      expect(result['body']['ok'], true);
      expect(result['body']['method'], 'POST');
    }));

    test('put returns 200 on success', () => serverRequired(() async {
      final result = await HttpClient.instance.put('/api/items/1',
          body: {'name': 'updated'});
      expect(result['statusCode'], 200);
      expect(result['body']['ok'], true);
      expect(result['body']['method'], 'PUT');
    }));

    test('delete returns 200 on success', () => serverRequired(() async {
      final result = await HttpClient.instance.delete('/api/items/1');
      expect(result['statusCode'], 200);
      expect(result['body']['ok'], true);
      expect(result['body']['method'], 'DELETE');
    }));

    // -- 401 → token refresh success ----------------------------------------

    test('401 triggers refresh, refresh succeeds, retried request gets 200',
        () => serverRequired(() async {
      // Use write() so both the in-memory cache and SharedPreferences are
      // updated — avoids stale state from repeated setMockInitialValues.
      await LocalStorage.instance.write('accessToken', 'expired-token');
      await LocalStorage.instance.write('refreshToken', 'valid-refresh-token');

      int callCount = 0;
      final result = await HttpClient.instance.send(
        () async {
          callCount++;
          if (callCount == 1) {
            return http.Response('{}', 401);
          }
          return http.Response('{"retried":true}', 200);
        },
        '/api/protected',
      );

      expect(result['statusCode'], 200);
      expect(result['body']['retried'], true);
      expect(callCount, 2);

      // Tokens updated from refresh response.
      expect(LocalStorage.instance.read('accessToken'),
          'new-access-token-from-server');
      expect(LocalStorage.instance.read('refreshToken'),
          'new-refresh-token-from-server');
    }));

    // -- Timeout / network error --------------------------------------------

    test('get with unreachable host throws SocketException',
        () => serverRequired(() async {
      expect(
        () => HttpClient.instance
            .get('http://127.0.0.1:1/timeout-test'),
        throwsA(isA<SocketException>()),
      );
    }));
  });
}
