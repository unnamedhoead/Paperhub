import 'package:flutter/material.dart';

import 'screens/auth/forgot_password_page.dart';
import 'screens/auth/login_page.dart';
import 'screens/auth/register_page.dart';
import 'screens/auth/reset_password_page.dart';
import 'screens/auth/verify_email_page.dart';
import 'screens/chat_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'theme.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Map<String, WidgetBuilder> buildAppRoutes({
  required ValueNotifier<ThemeMode> themeModeNotifier,
  required ValueChanged<ThemeMode> onThemeModeChanged,
  required VoidCallback onThemeToggle,
}) {
  Widget home(BuildContext ctx) => HomeScreen(
        themeModeNotifier: themeModeNotifier,
        onThemeModeChanged: onThemeModeChanged,
        onThemeToggle: onThemeToggle,
      );

  return {
    '/': home,
    '/login': (ctx) => Theme(data: PaperHubTheme.unauthLight, child: LoginPage()),
    '/register': (ctx) => Theme(data: PaperHubTheme.unauthLight, child: RegisterPage()),
    '/verify': (ctx) => Theme(data: PaperHubTheme.unauthLight, child: VerifyEmailPage()),
    '/forgot': (ctx) => Theme(data: PaperHubTheme.unauthLight, child: ForgotPasswordPage()),
    '/reset': (ctx) => Theme(data: PaperHubTheme.unauthLight, child: ResetPasswordPage()),
    '/home': home,
    '/me': (ctx) => const ProfilePage(isMainPage: true),
  };
}

Route<dynamic>? generateAppRoute(RouteSettings settings) {
  final name = settings.name ?? '';
  if (name.startsWith('/user/')) {
    final userId = name.substring('/user/'.length);
    return MaterialPageRoute(
      builder: (_) => ProfilePage(userId: userId),
      settings: settings,
    );
  }
  if (name.startsWith('/chat/')) {
    final conversationId = name.substring('/chat/'.length);
    return MaterialPageRoute(
      builder: (_) => ChatScreen(conversationId: conversationId),
      settings: settings,
    );
  }
  return null;
}
