import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:recognition_based_automated_attendance_system/models/leave_request_model.dart';
import 'package:recognition_based_automated_attendance_system/models/user_model.dart';
import 'package:recognition_based_automated_attendance_system/providers/auth_provider.dart';
import 'package:recognition_based_automated_attendance_system/providers/language_provider.dart';
import 'package:recognition_based_automated_attendance_system/providers/leave_request_provider.dart';
import 'package:recognition_based_automated_attendance_system/screens/leave_request_screen.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  Widget buildShell({
    required User user,
    required _TestLeaveRequestProvider provider,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LanguageProvider>(
          create: (_) => LanguageProvider(),
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => _TestAuthProvider(user),
        ),
        ChangeNotifierProvider<LeaveRequestProvider>.value(value: provider),
      ],
      child: const MaterialApp(home: LeaveRequestScreen()),
    );
  }

  LeaveRequest buildLeave({
    required int id,
    required int submittedById,
    required String status,
    String reason = 'Family matter',
  }) {
    return LeaveRequest(
      id: id,
      userId: submittedById,
      submittedById: submittedById,
      leaveDate: DateTime(2026, 4, 22, 8, 30),
      reason: reason,
      status: status,
      createdAt: DateTime(2026, 4, 20, 7, 15),
      updatedAt: DateTime(2026, 4, 20, 7, 15),
      userName: 'Student One',
      submittedByName: 'Student One',
    );
  }

  User buildUser() {
    return User(
      id: 7,
      email: 'student@example.com',
      fullName: 'Student One',
      role: 'student',
      hasRegisteredFace: true,
      isActive: true,
      isVerified: true,
      createdAt: DateTime(2026, 4, 1),
    );
  }

  User buildTeacherUser() {
    return User(
      id: 99,
      email: 'teacher@example.com',
      fullName: 'Teacher One',
      role: 'teacher',
      hasRegisteredFace: true,
      isActive: true,
      isVerified: true,
      createdAt: DateTime(2026, 4, 1),
    );
  }

  testWidgets('pending own request shows edit and delete actions', (
    tester,
  ) async {
    final provider = _TestLeaveRequestProvider([
      buildLeave(id: 1, submittedById: 7, status: 'pending'),
    ]);

    await tester.pumpWidget(
      buildShell(user: buildUser(), provider: provider),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edit Request'), findsOneWidget);
    expect(find.text('Delete Request'), findsOneWidget);
  });

  testWidgets('approved own request keeps visible locked owner actions', (
    tester,
  ) async {
    final provider = _TestLeaveRequestProvider([
      buildLeave(id: 2, submittedById: 7, status: 'approved'),
    ]);

    await tester.pumpWidget(
      buildShell(user: buildUser(), provider: provider),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit Request'));
    await tester.pump();

    expect(find.text('Reviewed requests cannot be edited.'), findsOneWidget);
    expect(find.text('Delete Request'), findsOneWidget);
  });

  testWidgets('teacher sees delete on reviewed requests from other users', (
    tester,
  ) async {
    final provider = _TestLeaveRequestProvider([
      buildLeave(id: 20, submittedById: 7, status: 'approved'),
    ]);

    await tester.pumpWidget(
      buildShell(user: buildTeacherUser(), provider: provider),
    );
    await tester.pumpAndSettle();

    expect(find.text('Delete Request'), findsOneWidget);
  });

  testWidgets('editing a pending request submits the updated values', (
    tester,
  ) async {
    final provider = _TestLeaveRequestProvider([
      buildLeave(id: 3, submittedById: 7, status: 'pending'),
    ]);

    await tester.pumpWidget(
      buildShell(user: buildUser(), provider: provider),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit Request'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Edit Leave Request'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField),
      'Updated leave reason for appointment',
    );
    await tester.tap(find.text('Save Changes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(provider.updatedLeaveId, 3);
    expect(provider.updatedReason, 'Updated leave reason for appointment');
  });
}

class _TestAuthProvider extends AuthProvider {
  _TestAuthProvider(this._user);

  final User _user;

  @override
  User? get user => _user;
}

class _TestLeaveRequestProvider extends LeaveRequestProvider {
  _TestLeaveRequestProvider(List<LeaveRequest> requests)
    : _requests = List<LeaveRequest>.from(requests);

  final List<LeaveRequest> _requests;
  final bool _isLoading = false;
  String? _error;

  int? updatedLeaveId;
  String? updatedReason;

  @override
  List<LeaveRequest> get leaveRequests => List<LeaveRequest>.unmodifiable(_requests);

  @override
  List<LeaveRequest> get pendingRequests =>
      _requests.where((request) => request.isPending).toList();

  @override
  bool get isLoading => _isLoading;

  @override
  String? get error => _error;

  @override
  Future<void> fetchLeaveRequests({String? statusFilter}) async {}

  @override
  Future<bool> updateLeaveRequest(
    int leaveId, {
    required DateTime leaveDate,
    required String reason,
  }) async {
    updatedLeaveId = leaveId;
    updatedReason = reason;

    final index = _requests.indexWhere((request) => request.id == leaveId);
    if (index == -1) {
      _error = 'Leave request not found';
      notifyListeners();
      return false;
    }

    final current = _requests[index];
    _requests[index] = LeaveRequest(
      id: current.id,
      userId: current.userId,
      studentId: current.studentId,
      submittedById: current.submittedById,
      leaveDate: leaveDate,
      reason: reason,
      status: current.status,
      reviewedById: current.reviewedById,
      reviewedAt: current.reviewedAt,
      reviewNote: current.reviewNote,
      createdAt: current.createdAt,
      updatedAt: DateTime(2026, 4, 21, 12, 0),
      userName: current.userName,
      studentName: current.studentName,
      submittedByName: current.submittedByName,
      reviewedByName: current.reviewedByName,
    );
    notifyListeners();
    return true;
  }

  @override
  Future<bool> deleteLeaveRequest(int leaveId) async {
    _requests.removeWhere((request) => request.id == leaveId);
    notifyListeners();
    return true;
  }
}
