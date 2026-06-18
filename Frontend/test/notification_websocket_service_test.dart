import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test/services/local_storage.dart';
import 'package:test/services/notification_websocket_service.dart';

/// Unit tests for [NotificationWebSocketService].
///
/// Strategy (local-stub / no new dependencies): we exercise the service's
/// public API on the paths that resolve to "no logged-in user", which make
/// [connect] return early WITHOUT opening any WebSocket or scheduling timers.
/// User identity is driven through the real [LocalStorage] backed by the
/// in-memory SharedPreferences mock. We deliberately avoid feeding a numeric
/// userId, since that path would attempt a real network connection.
///
/// Helper: build a JWT-shaped token whose payload is the given map. Padding is
/// stripped like a real JWT (the service re-pads on decode).
String buildJwt(Map<String, dynamic> payload) {
  String segment(Map<String, dynamic> map) {
    final encoded = base64Url.encode(utf8.encode(jsonEncode(map)));
    return encoded.replaceAll('=', '');
  }

  final header = segment({'alg': 'HS256', 'typ': 'JWT'});
  final body = segment(payload);
  const signature = 'sig';
  return '$header.$body.$signature';
}

void main() {
  final service = NotificationWebSocketService.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.instance.init();
    // Ensure a clean, disconnected baseline before every test.
    service.disconnect();
  });

  tearDown(() {
    // Never leave the shared singleton in a connected/timer-armed state.
    service.disconnect();
  });

  group('NotificationWebSocketService singleton', () {
    test('instance is a stable singleton', () {
      expect(
        identical(
          NotificationWebSocketService.instance,
          NotificationWebSocketService.instance,
        ),
        isTrue,
      );
    });

    test('initial state is disconnected with no current user', () {
      expect(service.isConnected, isFalse);
      expect(service.currentUserId, isNull);
    });
  });

  group('connect() early-return paths (no user → no socket)', () {
    test('does nothing when nothing is stored', () async {
      await service.connect();

      expect(service.isConnected, isFalse);
      expect(service.currentUserId, isNull);
    });

    test('does nothing when accessToken is malformed (not 3 parts)', () async {
      await LocalStorage.instance.write('accessToken', 'not-a-valid-jwt');

      await service.connect();

      expect(service.isConnected, isFalse);
      expect(service.currentUserId, isNull);
    });

    test('does nothing when JWT subject is a non-numeric email', () async {
      final token = buildJwt({'sub': 'user@example.com'});
      await LocalStorage.instance.write('accessToken', token);

      await service.connect();

      expect(service.isConnected, isFalse);
      expect(service.currentUserId, isNull);
    });

    test('does nothing when JWT payload has no id-like field', () async {
      final token = buildJwt({'role': 'USER', 'exp': 9999999999});
      await LocalStorage.instance.write('accessToken', token);

      await service.connect();

      expect(service.isConnected, isFalse);
      expect(service.currentUserId, isNull);
    });

    test('does nothing when cached userId is not a valid number', () async {
      // _getCurrentUserId tries LocalStorage 'userId' first; a non-numeric
      // value fails int.tryParse and falls through to the (absent) token.
      await LocalStorage.instance.write('userId', 'abc');

      await service.connect();

      expect(service.isConnected, isFalse);
      expect(service.currentUserId, isNull);
    });
  });

  group('lifecycle methods are safe without a live connection', () {
    test('disconnect() is idempotent when never connected', () {
      service.disconnect();
      service.disconnect();

      expect(service.isConnected, isFalse);
      expect(service.currentUserId, isNull);
    });

    test('refreshUnreadCounts() completes without throwing', () async {
      await expectLater(service.refreshUnreadCounts(), completes);
    });

    test('checkAndReconnect() with no user leaves state disconnected',
        () async {
      // Not connected + no user → connect() is attempted but early-returns.
      await service.checkAndReconnect();

      expect(service.isConnected, isFalse);
      expect(service.currentUserId, isNull);
    });
  });
}
