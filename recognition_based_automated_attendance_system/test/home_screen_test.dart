import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:recognition_based_automated_attendance_system/models/attendance_model.dart';
import 'package:recognition_based_automated_attendance_system/models/class_model.dart';
import 'package:recognition_based_automated_attendance_system/models/supervision_model.dart';
import 'package:recognition_based_automated_attendance_system/models/user_model.dart';
import 'package:recognition_based_automated_attendance_system/providers/attendance_provider.dart';
import 'package:recognition_based_automated_attendance_system/providers/auth_provider.dart';
import 'package:recognition_based_automated_attendance_system/providers/language_provider.dart';
import 'package:recognition_based_automated_attendance_system/providers/leave_request_provider.dart';
import 'package:recognition_based_automated_attendance_system/providers/notification_provider.dart';
import 'package:recognition_based_automated_attendance_system/providers/student_management_provider.dart';
import 'package:recognition_based_automated_attendance_system/providers/supervision_provider.dart';
import 'package:recognition_based_automated_attendance_system/screens/home_screen.dart';
import 'package:recognition_based_automated_attendance_system/screens/supervision_dashboard_screen.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  Widget buildShell({required SupervisionOverview overview}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LanguageProvider>(
          create: (_) => LanguageProvider(),
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => _TestAuthProvider(
            User(
              id: 7,
              email: 'teacher@example.com',
              fullName: 'Teacher One',
              role: 'teacher',
              hasRegisteredFace: true,
              isActive: true,
              isVerified: true,
              createdAt: DateTime(2026, 4, 21),
            ),
          ),
        ),
        ChangeNotifierProvider<AttendanceProvider>(
          create: (_) => _TestAttendanceProvider(),
        ),
        ChangeNotifierProvider<NotificationProvider>(
          create: (_) => _TestNotificationProvider(),
        ),
        ChangeNotifierProvider<StudentManagementProvider>(
          create: (_) => _TestStudentManagementProvider(),
        ),
        ChangeNotifierProvider<SupervisionProvider>(
          create: (_) => _TestSupervisionProvider(overview),
        ),
        ChangeNotifierProvider<LeaveRequestProvider>(
          create: (_) => _TestLeaveRequestProvider(),
        ),
      ],
      child: MaterialApp(
        home: const HomeScreen(),
        onGenerateRoute: (settings) {
          if (settings.name == '/supervision') {
            final args = settings.arguments;
            final openCreateGroupOnLoad =
                args is Map && args['openCreateGroupDialog'] == true;
            return MaterialPageRoute<void>(
              builder: (_) => SupervisionDashboardScreen(
                openCreateGroupOnLoad: openCreateGroupOnLoad,
              ),
              settings: settings,
            );
          }
          return null;
        },
      ),
    );
  }

  void setDesktopViewport(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 1200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'Home dashboard Create Group opens the supervision create-group dialog',
    (tester) async {
      setDesktopViewport(tester);

      await tester.pumpWidget(
        buildShell(
          overview: const SupervisionOverview(
            canCreateGroups: true,
            canManageGroups: true,
            canShareClasses: true,
            pendingLeaveCount: 0,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));

      await tester.tap(find.text('Create Group').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('Create User Group'), findsOneWidget);
    },
  );
}

class _TestAuthProvider extends AuthProvider {
  _TestAuthProvider(this._user);

  final User _user;

  @override
  User? get user => _user;
}

class _TestAttendanceProvider extends AttendanceProvider {
  @override
  List<Attendance> get todayAttendance => const [];

  @override
  AttendanceStats? get stats => null;

  @override
  Future<void> fetchTodayAttendance() async {}
}

class _TestNotificationProvider extends NotificationProvider {
  @override
  int get unreadCount => 0;

  @override
  Future<void> fetchUnreadCount() async {}
}

class _TestStudentManagementProvider extends StudentManagementProvider {
  @override
  List<ClassModel> get classes => const [];

  @override
  Future<void> fetchClasses() async {}
}

class _TestSupervisionProvider extends SupervisionProvider {
  _TestSupervisionProvider(this._overview);

  final SupervisionOverview _overview;

  @override
  SupervisionOverview? get overview => _overview;

  @override
  bool get isLoading => false;

  @override
  bool get isSubmitting => false;

  @override
  Future<void> fetchOverview() async {}
}

class _TestLeaveRequestProvider extends LeaveRequestProvider {
  @override
  Future<void> fetchLeaveRequests({String? statusFilter}) async {}
}
