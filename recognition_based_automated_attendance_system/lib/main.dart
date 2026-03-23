import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'config/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/attendance_provider.dart';
import 'services/storage_service.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/face_capture_screen.dart';
import 'screens/home_screen.dart';
import 'screens/attendance_screen.dart';
import 'screens/history_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/admin/admin_users_screen.dart';
import 'screens/admin/admin_reports_screen.dart';
import 'screens/admin/admin_attendance_screen.dart';
import 'screens/room_scanner_screen.dart';
import 'screens/batch_student_registration_screen.dart';
import 'providers/student_management_provider.dart';
import 'screens/admin/class_management_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize storage service
  await StorageService().init();
  
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
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        ChangeNotifierProvider(create: (_) => StudentManagementProvider()),
      ],
      child: MaterialApp(
        title: 'Face Attendance System',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
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
          '/admin': (context) => const AdminDashboard(),
          '/admin/users': (context) => const AdminUsersScreen(),
          '/admin/reports': (context) => const AdminReportsScreen(),
          '/admin/attendance': (context) => const AdminAttendanceScreen(),
          '/room-scanner': (context) => const RoomScannerScreen(),
          '/batch-registration': (context) => const BatchStudentRegistrationScreen(),
          '/admin/classes': (context) => const ClassManagementScreen(),
        },
      ),
    );
  }
}
