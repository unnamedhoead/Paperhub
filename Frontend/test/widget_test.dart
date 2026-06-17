import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:test/theme.dart';

void main() {
  test('parseThemeMode maps persisted values', () {
    expect(parseThemeMode('dark'), ThemeMode.dark);
    expect(parseThemeMode('light'), ThemeMode.light);
    expect(parseThemeMode('system'), ThemeMode.system);
    expect(parseThemeMode(null), ThemeMode.system);
  });

  test('PaperHubTheme exposes light and dark themes', () {
    expect(PaperHubTheme.light.brightness, Brightness.light);
    expect(PaperHubTheme.dark.brightness, Brightness.dark);
  });
}
