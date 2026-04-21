import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:recognition_based_automated_attendance_system/models/supervision_model.dart';
import 'package:recognition_based_automated_attendance_system/models/user_model.dart';
import 'package:recognition_based_automated_attendance_system/providers/auth_provider.dart';
import 'package:recognition_based_automated_attendance_system/providers/language_provider.dart';
import 'package:recognition_based_automated_attendance_system/providers/leave_request_provider.dart';
import 'package:recognition_based_automated_attendance_system/providers/supervision_provider.dart';
import 'package:recognition_based_automated_attendance_system/screens/supervision_dashboard_screen.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  Widget buildShell({
    required SupervisionOverview overview,
    String userRole = 'admin',
    Map<String, WidgetBuilder> routes = const {},
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LanguageProvider>(
          create: (_) => LanguageProvider(),
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => _TestAuthProvider(
            User(
              id: 7,
              email: 'rvgs@example.com',
              fullName: 'rvgs',
              role: userRole,
              hasRegisteredFace: true,
              isActive: true,
              isVerified: true,
              createdAt: DateTime(2026, 4, 18),
            ),
          ),
        ),
        ChangeNotifierProvider<SupervisionProvider>(
          create: (_) => _TestSupervisionProvider(overview),
        ),
        ChangeNotifierProvider<LeaveRequestProvider>(
          create: (_) => _TestLeaveRequestProvider(),
        ),
      ],
      child: MaterialApp(
        home: const SupervisionDashboardScreen(),
        routes: routes,
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
    'Add Users By Email opens the create-group dialog when no groups exist',
    (tester) async {
      setDesktopViewport(tester);

      await tester.pumpWidget(
        buildShell(
          userRole: 'teacher',
          overview: const SupervisionOverview(
            canCreateGroups: true,
            canManageGroups: false,
            canShareClasses: true,
            pendingLeaveCount: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Users By Email').first);
      await tester.pumpAndSettle();

      expect(find.text('Create User Group'), findsOneWidget);
    },
  );

  testWidgets(
    'Add Class To Group sends the user to batch registration when classes are missing',
    (tester) async {
      setDesktopViewport(tester);

      await tester.pumpWidget(
        buildShell(
          overview: SupervisionOverview(
            canCreateGroups: true,
            canManageGroups: true,
            canShareClasses: true,
            pendingLeaveCount: 0,
            groups: [
              TeacherGroup(
                id: 10,
                name: 'Science Team',
                createdById: 7,
                canManage: true,
                createdAt: DateTime(2026, 4, 18),
                updatedAt: DateTime(2026, 4, 18),
              ),
            ],
          ),
          routes: {
            '/batch-registration': (_) => const Scaffold(
              body: Center(child: Text('Batch Registration Route')),
            ),
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Class To Group').first);
      await tester.pumpAndSettle();

      expect(find.text('Batch Registration Route'), findsOneWidget);
    },
  );

  testWidgets('Teacher-owned groups still expose Add Users By Email', (
    tester,
  ) async {
    setDesktopViewport(tester);

    await tester.pumpWidget(
      buildShell(
        userRole: 'teacher',
        overview: SupervisionOverview(
          canCreateGroups: true,
          canManageGroups: false,
          canShareClasses: true,
          pendingLeaveCount: 0,
          groups: [
            TeacherGroup(
              id: 15,
              name: 'Owner Group',
              createdById: 7,
              canManage: true,
              createdAt: DateTime(2026, 4, 18),
              updatedAt: DateTime(2026, 4, 18),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add Users By Email'), findsWidgets);
  });

  testWidgets(
    'The empty share panel exposes next-step actions instead of a dead-end message',
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
      await tester.pumpAndSettle();

      expect(find.text('Create Group'), findsWidgets);
      expect(find.text('Open Batch Register'), findsOneWidget);
    },
  );

  testWidgets('Users without group creation access see setup guidance', (
    tester,
  ) async {
    setDesktopViewport(tester);

    await tester.pumpWidget(
      buildShell(
        userRole: 'student',
        overview: const SupervisionOverview(
          canCreateGroups: false,
          canManageGroups: false,
          canShareClasses: true,
          pendingLeaveCount: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Managed student accounts cannot create user groups. Ask an administrator to convert this account before using the group workspace.',
      ),
      findsWidgets,
    );
  });

  testWidgets(
    'Create Group explains the missing permission instead of staying a dead-end',
    (tester) async {
      setDesktopViewport(tester);

      await tester.pumpWidget(
        buildShell(
          userRole: 'student',
          overview: const SupervisionOverview(
            canCreateGroups: false,
            canManageGroups: false,
            canShareClasses: true,
            pendingLeaveCount: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create Group').first);
      await tester.pump();

      expect(
        find.text(
          'Managed student accounts cannot create user groups. Ask an administrator to convert this account before using the group workspace.',
        ),
        findsWidgets,
      );
    },
  );
}

class _TestAuthProvider extends AuthProvider {
  _TestAuthProvider(this._user);

  final User _user;

  @override
  User? get user => _user;
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
