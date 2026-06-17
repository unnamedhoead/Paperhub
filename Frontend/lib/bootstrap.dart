import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'services/api_service.dart';
import 'services/local_storage.dart';
import 'theme.dart';

void bootstrapPaperHub() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    try {
      await LocalStorage.instance.init();
    } catch (e, s) {
      debugPrint('LocalStorage.init failed: $e\n$s');
    }

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('FlutterError.onError: ${details.exception}\n${details.stack}');
    };

    final storedTheme = LocalStorage.instance.read('themeMode');
    final initialThemeMode = parseThemeMode(storedTheme);
    final initialRoute = await determineInitialRoute();

    runApp(PaperHubApp(
      initialThemeMode: initialThemeMode,
      initialRoute: initialRoute,
    ));
  }, (error, stack) {
    debugPrint('=== TOP LEVEL ERROR ===');
    debugPrint(error.toString());
    debugPrint(stack.toString());
  });
}

Future<String> determineInitialRoute() async {
  final token = LocalStorage.instance.read('accessToken');
  final refreshToken = LocalStorage.instance.read('refreshToken');

  debugPrint('启动路由判断: accessToken=${token != null && token.isNotEmpty ? "present" : "missing"}, refreshToken=${refreshToken != null && refreshToken.isNotEmpty ? "present" : "missing"}');

  if (token == null || token.isEmpty) {
    return '/login';
  }

  if (refreshToken != null && refreshToken.isNotEmpty) {
    try {
      final resp = await ApiService.refreshToken();
      if (resp['statusCode'] == 200) {
        final body = resp['body'] as Map<String, dynamic>?;
        final newToken = body?['token'] as String? ?? '';
        final newRefresh = body?['refreshToken'] as String? ?? '';

        if (newToken.isNotEmpty && newRefresh.isNotEmpty) {
          await LocalStorage.instance.write('accessToken', newToken);
          await LocalStorage.instance.write('refreshToken', newRefresh);
          return '/home';
        }
      }
    } catch (e) {
      debugPrint('启动时刷新Token异常: $e');
    }
  }

  await LocalStorage.instance.delete('accessToken');
  await LocalStorage.instance.delete('refreshToken');
  return '/login';
}
