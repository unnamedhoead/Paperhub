import 'package:flutter/material.dart';

import 'constants/app_colors.dart';

ThemeMode parseThemeMode(String? raw) {
  switch ((raw ?? '').toLowerCase()) {
    case 'dark':
      return ThemeMode.dark;
    case 'light':
      return ThemeMode.light;
    case 'system':
    default:
      return ThemeMode.system;
  }
}

class PaperHubTheme {
  static ThemeData get unauthLight {
    final base = ThemeData.light();
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primary,
        onPrimary: AppColors.textOnPrimary,
        onSurface: AppColors.textPrimary,
        onBackground: AppColors.textPrimary,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: AppColors.primaryLighter.withOpacity(0.6),
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        labelStyle: const TextStyle(color: AppColors.textPrimary),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.textPrimary,
        selectionHandleColor: AppColors.primary,
      ),
    );
  }

  static ThemeData get light => ThemeData(
        brightness: Brightness.light,
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.backgroundLight,
        fontFamily: 'NotoSansSC',
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontFamily: 'NotoSansSC'),
          bodyMedium: TextStyle(fontFamily: 'NotoSansSC'),
          bodySmall: TextStyle(fontFamily: 'NotoSansSC'),
          titleLarge: TextStyle(fontFamily: 'NotoSansSC'),
          titleMedium: TextStyle(fontFamily: 'NotoSansSC'),
          titleSmall: TextStyle(fontFamily: 'NotoSansSC'),
        ),
        colorScheme: ColorScheme.light(
          primary: AppColors.primary,
          secondary: AppColors.primaryLight,
          surface: AppColors.background,
          onPrimary: AppColors.textOnPrimary,
          onSurface: AppColors.textPrimary,
        ),
      );

  static ThemeData get dark {
    const bg = Color(0xFF0B1220);
    const surface = Color(0xFF111827);
    const card = Color(0xFF1F2937);
    const onSurface = Color(0xFFE5E7EB);
    final base = ThemeData(
      brightness: Brightness.dark,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: bg,
      fontFamily: 'NotoSansSC',
      colorScheme: ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.primaryLight,
        surface: surface,
        background: bg,
        onPrimary: AppColors.textOnPrimary,
        onSurface: onSurface,
        onBackground: onSurface,
      ),
      cardColor: card,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: onSurface,
        displayColor: onSurface,
        fontFamily: 'NotoSansSC',
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        elevation: 0,
        iconTheme: const IconThemeData(color: onSurface),
        titleTextStyle: base.textTheme.titleLarge?.copyWith(color: onSurface),
      ),
      iconTheme: const IconThemeData(color: onSurface),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: card,
        hintStyle: TextStyle(color: onSurface.withOpacity(0.6)),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: onSurface.withOpacity(0.15)),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.primary),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      dividerColor: onSurface.withOpacity(0.12),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          side: BorderSide(color: onSurface.withOpacity(0.4)),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: card,
        labelStyle: TextStyle(color: onSurface),
        secondarySelectedColor: AppColors.primary,
      ),
    );
  }
}
