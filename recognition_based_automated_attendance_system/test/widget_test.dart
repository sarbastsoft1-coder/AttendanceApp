// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:recognition_based_automated_attendance_system/main.dart';
import 'package:recognition_based_automated_attendance_system/providers/language_provider.dart';
import 'package:recognition_based_automated_attendance_system/providers/theme_provider.dart';

void main() {
  test('App shell can be created', () {
    final themeProvider = ThemeProvider();
    final languageProvider = LanguageProvider();

    expect(
      MyApp(themeProvider: themeProvider, languageProvider: languageProvider),
      isA<MyApp>(),
    );
  });
}
