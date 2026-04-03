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
import 'providers/language_provider.dart';
import 'providers/student_management_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/admin/class_management_screen.dart';

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
              return Directionality(
                textDirection: language.textDirection,
                child: child ?? const SizedBox.shrink(),
              );
            },
            initialRoute: '/',
            routes: {
              '/': (context) => const SplashScreen(),
              '/login': (context) => const LoginScreen(),
              '/register': (context) => const RegisterScreen(),
              '/face-capture': (context) => const FaceCaptureScreen(),
              '/home': (context) => const HomeScreen(),
              '/attendance': (context) => const AttendanceScreen(),
              '/history': (context) => const HistoryScreen(),
              '/profile': (context) => const ProfileScreen(),
              '/edit-profile': (context) => const EditProfileScreen(),
              '/change-password': (context) => const ChangePasswordScreen(),
              '/leave-requests': (context) => const LeaveRequestScreen(),
              '/notifications': (context) => const NotificationsScreen(),
              '/admin': (context) => const AdminDashboard(),
              '/admin/users': (context) => const AdminUsersScreen(),
              '/admin/reports': (context) => const AdminReportsScreen(),
              '/admin/attendance': (context) => const AdminAttendanceScreen(),
              '/room-scanner': (context) => const RoomScannerScreen(),
              '/batch-registration': (context) =>
                  const BatchStudentRegistrationScreen(),
              '/admin/classes': (context) => const ClassManagementScreen(),
            },
          );
        },
      ),
    );
  }
}
