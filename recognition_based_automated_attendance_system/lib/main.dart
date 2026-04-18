import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'config/api_config.dart';
import 'config/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/attendance_provider.dart';
import 'providers/leave_request_provider.dart';
import 'providers/notification_provider.dart';
import 'services/storage_service.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/face_capture_screen.dart';
import 'screens/home_screen.dart';
import 'screens/attendance_screen.dart';
import 'screens/history_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/change_password_screen.dart';
import 'screens/leave_request_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/admin/admin_users_screen.dart';
import 'screens/admin/admin_reports_screen.dart';
import 'screens/admin/admin_attendance_screen.dart';
import 'screens/room_scanner_screen.dart';
import 'screens/batch_student_registration_screen.dart';
import 'screens/check_out_screen.dart';
import 'screens/export_center_screen.dart';
import 'screens/exam_proctoring_screen.dart';
import 'screens/guardian_portal_screen.dart';
import 'screens/roll_call_screen.dart';
import 'providers/language_provider.dart';
import 'providers/student_management_provider.dart';
import 'providers/supervision_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/admin/class_management_screen.dart';
import 'screens/admin/analytics_screen.dart';
import 'screens/supervision_dashboard_screen.dart';
import 'widgets/live_notification_listener.dart';

typedef AppRouteWidgetFactory = Widget Function(RouteSettings settings);

int? _routeIntArgument(RouteSettings settings, String key) {
  final args = settings.arguments;
  if (args is int) {
    return args;
  }
  if (args is Map) {
    final value = args[key];
    if (value is int) {
      return value;
    }
  }
  return null;
}

@visibleForTesting
final Map<String, AppRouteWidgetFactory> appRouteBuilders =
    <String, AppRouteWidgetFactory>{
      '/': (_) => const SplashScreen(),
      '/login': (_) => const LoginScreen(),
      '/register': (_) => const RegisterScreen(),
      '/face-capture': (_) => const FaceCaptureScreen(),
      '/home': (_) => const HomeScreen(),
      '/attendance': (_) => const AttendanceScreen(),
      '/history': (_) => const HistoryScreen(),
      '/profile': (_) => const ProfileScreen(),
      '/edit-profile': (_) => const EditProfileScreen(),
      '/change-password': (_) => const ChangePasswordScreen(),
      '/leave-requests': (_) => const LeaveRequestScreen(),
      '/notifications': (_) => const NotificationsScreen(),
      '/admin': (_) => const AdminDashboard(),
      '/admin/users': (_) => const AdminUsersScreen(),
      '/admin/reports': (_) => const AdminReportsScreen(),
      '/admin/attendance': (_) => const AdminAttendanceScreen(),
      '/room-scanner': (_) => const RoomScannerScreen(),
      '/batch-registration': (_) => const BatchStudentRegistrationScreen(),
      '/check-out': (_) => const CheckOutScreen(),
      '/export-center': (_) => const ExportCenterScreen(),
      '/qr-attendance': (_) => const SplashScreen(),
      '/qr-scan': (_) => const SplashScreen(),
      '/exam-proctoring': (_) => const ExamProctoringScreen(),
      '/roll-call': (_) => const RollCallScreen(),
      '/guardian-portal': (_) => const GuardianPortalScreen(),
      '/admin/analytics': (_) => const AnalyticsScreen(),
      '/admin/classes': (_) => const ClassManagementScreen(),
      '/supervision': (settings) => SupervisionDashboardScreen(
        initialGroupId: _routeIntArgument(settings, 'groupId'),
      ),
    };

@visibleForTesting
Widget buildAppChild(RouteSettings settings) {
  final builder = appRouteBuilders[settings.name];
  return (builder ?? (_) => const SplashScreen())(settings);
}

@visibleForTesting
Route<dynamic> buildAppRoute(
  RouteSettings settings, {
  bool useTransition = true,
}) {
  final child = buildAppChild(settings);
  if (!useTransition) {
    return MaterialPageRoute(settings: settings, builder: (_) => child);
  }
  return AppPageRoute<dynamic>(settings: settings, child: child);
}

@visibleForTesting
Route<dynamic> buildUnknownRoute(RouteSettings settings) {
  return AppPageRoute<dynamic>(settings: settings, child: const SplashScreen());
}

class AppPageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;

  AppPageRoute({required this.child, super.settings})
    : super(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) => child,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final fade = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: fade,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.025, 0),
                end: Offset.zero,
              ).animate(fade),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.988, end: 1).animate(fade),
                child: child,
              ),
            ),
          );
        },
      );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize storage service
  await StorageService().init();
  await ApiConfig.loadBaseUrl();

  final themeProvider = ThemeProvider();
  await themeProvider.init();

  final languageProvider = LanguageProvider();
  await languageProvider.init();
  await initializeDateFormatting('en');
  await initializeDateFormatting('ar');

  // Windows desktop — configure window
  if (!kIsWeb && Platform.isWindows) {
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      size: Size(1280, 800),
      minimumSize: Size(960, 640),
      center: true,
      backgroundColor: Color(0xFF0A0E1A),
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      title: 'Face Attendance System',
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // Mobile-only: orientation lock and status bar styling
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppTheme.bgDeep,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  runApp(
    MyApp(themeProvider: themeProvider, languageProvider: languageProvider),
  );
}

String _resolveInitialRoute() {
  if (!kIsWeb) {
    return '/';
  }

  String? candidate;
  if (Uri.base.fragment.isNotEmpty) {
    candidate = Uri.base.fragment;
  } else if (Uri.base.path.isNotEmpty && Uri.base.path != '/') {
    candidate =
        '${Uri.base.path}${Uri.base.hasQuery ? '?${Uri.base.query}' : ''}';
  }

  if (candidate == null || candidate.isEmpty) {
    return '/';
  }

  final normalized = candidate.startsWith('/') ? candidate : '/$candidate';
  return Uri.parse(normalized).path;
}

class MyApp extends StatelessWidget {
  final ThemeProvider themeProvider;
  final LanguageProvider languageProvider;

  const MyApp({
    super.key,
    required this.themeProvider,
    required this.languageProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: languageProvider),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        ChangeNotifierProvider(create: (_) => StudentManagementProvider()),
        ChangeNotifierProvider(create: (_) => SupervisionProvider()),
        ChangeNotifierProvider(create: (_) => LeaveRequestProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: Consumer2<ThemeProvider, LanguageProvider>(
        builder: (context, theme, language, _) {
          Intl.defaultLocale = language.materialLocale.languageCode;
          return MaterialApp(
            title: language.tr('appTitle'),
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: theme.themeMode,
            locale: language.materialLocale,
            supportedLocales: const [Locale('en'), Locale('ar')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            builder: (context, child) {
              return LiveNotificationListener(
                child: Directionality(
                  textDirection: language.textDirection,
                  child: child ?? const SizedBox.shrink(),
                ),
              );
            },
            initialRoute: _resolveInitialRoute(),
            onGenerateInitialRoutes: (initialRoute) {
              return [
                buildAppRoute(
                  RouteSettings(name: initialRoute),
                  useTransition: false,
                ),
              ];
            },
            onGenerateRoute: buildAppRoute,
            onUnknownRoute: buildUnknownRoute,
          );
        },
      ),
    );
  }
}
