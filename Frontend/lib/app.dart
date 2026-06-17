import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'router.dart';
import 'services/api_service.dart';
import 'services/local_storage.dart';
import 'theme.dart';

class PaperHubApp extends StatefulWidget {
  const PaperHubApp({
    super.key,
    required this.initialThemeMode,
    required this.initialRoute,
  });

  final ThemeMode initialThemeMode;
  final String initialRoute;

  @override
  State<PaperHubApp> createState() => _PaperHubAppState();
}

class _PaperHubAppState extends State<PaperHubApp> {
  late final ValueNotifier<ThemeMode> _themeModeNotifier =
      ValueNotifier(widget.initialThemeMode);

  @override
  void initState() {
    super.initState();
    ApiService.onAuthFailed = () {
      debugPrint('检测到认证失败，跳转到登录页');
      final navigator = navigatorKey.currentState;
      if (navigator != null) {
        navigator.pushNamedAndRemoveUntil('/login', (route) => false);
      }
    };
  }

  @override
  void dispose() {
    ApiService.onAuthFailed = null;
    _themeModeNotifier.dispose();
    super.dispose();
  }

  void _setThemeMode(ThemeMode mode) {
    _themeModeNotifier.value = mode;
    LocalStorage.instance.write('themeMode', mode.name);
  }

  void _toggleTheme() {
    final current = _themeModeNotifier.value;
    final next = current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    _setThemeMode(next);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeModeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'PaperHub (Mock Demo)',
          themeMode: mode,
          theme: PaperHubTheme.light,
          darkTheme: PaperHubTheme.dark,
          initialRoute: widget.initialRoute,
          routes: buildAppRoutes(
            themeModeNotifier: _themeModeNotifier,
            onThemeModeChanged: _setThemeMode,
            onThemeToggle: _toggleTheme,
          ),
          onGenerateRoute: generateAppRoute,
        );
      },
    );
  }
}
