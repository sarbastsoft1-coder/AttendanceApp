import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:recognition_based_automated_attendance_system/main.dart';
import 'package:recognition_based_automated_attendance_system/providers/language_provider.dart';
import 'package:recognition_based_automated_attendance_system/providers/theme_provider.dart';
import 'package:recognition_based_automated_attendance_system/screens/login_screen.dart';
import 'package:recognition_based_automated_attendance_system/screens/splash_screen.dart';
import 'package:recognition_based_automated_attendance_system/widgets/custom_button.dart';
import 'package:recognition_based_automated_attendance_system/widgets/loading_widget.dart';

void main() {
  Widget buildTestShell(Widget child) {
    return ChangeNotifierProvider(
      create: (_) => LanguageProvider(),
      child: MaterialApp(
        home: Scaffold(body: Center(child: child)),
      ),
    );
  }

  test('App shell can be created', () {
    final themeProvider = ThemeProvider();
    final languageProvider = LanguageProvider();

    expect(
      MyApp(themeProvider: themeProvider, languageProvider: languageProvider),
      isA<MyApp>(),
    );
  });

  test('buildAppRoute resolves login screen and preserves arguments', () {
    const redirectArgs = {
      'route': '/home',
      'arguments': {'from': 'test'},
    };

    final route = buildAppRoute(
      const RouteSettings(name: '/login', arguments: redirectArgs),
    );

    expect(route, isA<AppPageRoute<dynamic>>());
    expect((route as AppPageRoute<dynamic>).child, isA<LoginScreen>());
    expect(route.settings.name, '/login');
    expect(route.settings.arguments, same(redirectArgs));
  });

  test('buildUnknownRoute falls back to splash screen', () {
    final route = buildUnknownRoute(
      const RouteSettings(name: '/does-not-exist'),
    );

    expect(route, isA<AppPageRoute<dynamic>>());
    expect((route as AppPageRoute<dynamic>).child, isA<SplashScreen>());
  });

  testWidgets('CustomButton disables action and shows branded spinner while loading', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestShell(
        const CustomButton(
          text: 'Confirm',
          isLoading: true,
        ),
      ),
    );

    expect(find.byType(BrandedSpinner), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
  });

  testWidgets('LoadingWidget renders branded spinner and message', (tester) async {
    await tester.pumpWidget(
      buildTestShell(
        const LoadingWidget(message: 'Initializing camera...'),
      ),
    );

    expect(find.byType(BrandedSpinner), findsOneWidget);
    expect(find.text('Initializing camera...'), findsOneWidget);
  });
}
