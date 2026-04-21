import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart' show PointerHoverEvent;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../localization/localization_extensions.dart';
import '../models/attendance_model.dart';
import '../models/supervision_model.dart';
import '../providers/attendance_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/student_management_provider.dart';
import '../providers/supervision_provider.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/sidebar_navigation.dart';
import '../widgets/stats_card.dart';
import '../widgets/window_title_bar.dart';
import 'history_screen.dart';
import 'profile_screen.dart';

/// Desktop Dashboard Home Screen with Sidebar Navigation
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadData();
      }
    });
  }

  void _loadData() {
    final authProvider = context.read<AuthProvider>();
    final attendanceProvider = context.read<AttendanceProvider>();
    final notificationProvider = context.read<NotificationProvider>();
    final studentManagementProvider = context.read<StudentManagementProvider>();
    final supervisionProvider = context.read<SupervisionProvider>();
    final user = authProvider.user;

    attendanceProvider.fetchTodayAttendance();
    notificationProvider.fetchUnreadCount();

    if (user == null) {
      return;
    }

    if (user.isTeacher || user.isAdmin) {
      studentManagementProvider.fetchClasses();
    } else {
      attendanceProvider.fetchStats(
        user.id,
        month: DateTime.now().month,
        year: DateTime.now().year,
      );
    }

    if (user.canUseGroups) {
      supervisionProvider.fetchOverview();
    }
  }

  Future<void> _openRouteAndRefresh(
    String routeName, {
    Object? arguments,
  }) async {
    await Navigator.pushNamed(context, routeName, arguments: arguments);
    if (mounted) {
      _loadData();
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.successColor),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.errorColor),
    );
  }

  Future<SupervisionOverview?> _ensureOverview() async {
    final supervision = context.read<SupervisionProvider>();
    if (supervision.overview == null) {
      await supervision.fetchOverview();
    }
    if (!mounted) {
      return null;
    }
    return supervision.overview;
  }

  Future<void> _showCreateGroupDialog() async {
    await _openRouteAndRefresh(
      '/supervision',
      arguments: {'openCreateGroupDialog': true},
    );
  }

  Future<void> _showInviteTeachersDialog() async {
    final language = context.language;
    final auth = context.read<AuthProvider>();
    final supervision = context.read<SupervisionProvider>();
    final overview = await _ensureOverview();
    if (!mounted || overview == null) {
      return;
    }
    final manageableGroups = overview.groups
        .where((group) => group.canManage)
        .toList();
    if (manageableGroups.isEmpty) {
      _showError(language.tr('noTeacherGroups'));
      return;
    }

    final emailsController = TextEditingController();
    final noteController = TextEditingController();
    final canAssignSuperTeacher =
        auth.user?.isAdmin == true || auth.user?.isSupervisor == true;
    var selectedRole = 'teacher';
    var selectedGroupId = manageableGroups.first.id;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(language.tr('inviteTeachers')),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: selectedGroupId,
                      items: manageableGroups
                          .map(
                            (group) => DropdownMenuItem(
                              value: group.id,
                              child: Text(group.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setDialogState(() => selectedGroupId = value);
                      },
                      decoration: InputDecoration(
                        labelText: language.tr('selectGroup'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailsController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: language.tr('emailAddresses'),
                        hintText: language.tr('emailAddressesHint'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
                      items: [
                        DropdownMenuItem(
                          value: 'teacher',
                          child: Text(language.tr('teacher')),
                        ),
                        if (canAssignSuperTeacher)
                          DropdownMenuItem(
                            value: 'super_teacher',
                            child: Text(language.tr('superTeacher')),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setDialogState(() => selectedRole = value);
                      },
                      decoration: InputDecoration(
                        labelText: language.tr('teacherRole'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: language.tr('noteOptional'),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(language.tr('cancel')),
                ),
                FilledButton(
                  onPressed: () async {
                    final emails = emailsController.text
                        .split(RegExp(r'[\s,;]+'))
                        .map((email) => email.trim())
                        .where((email) => email.isNotEmpty)
                        .toList();
                    if (emails.isEmpty) {
                      _showError(language.tr('enterAtLeastOneEmail'));
                      return;
                    }

                    final success = await supervision.inviteTeachers(
                      groupId: selectedGroupId,
                      emails: emails,
                      targetRole: selectedRole,
                      note: noteController.text,
                    );
                    if (!mounted || !dialogContext.mounted) {
                      return;
                    }
                    if (success) {
                      Navigator.pop(dialogContext);
                      _showMessage(language.tr('teachersInvited'));
                    } else {
                      _showError(
                        supervision.error ?? language.tr('operationFailed'),
                      );
                    }
                  },
                  child: Text(language.tr('sendInvite')),
                ),
              ],
            );
          },
        );
      },
    );

    emailsController.dispose();
    noteController.dispose();
  }

  Future<void> _showShareClassDialog() async {
    final language = context.language;
    final supervision = context.read<SupervisionProvider>();
    final overview = await _ensureOverview();
    if (!mounted || overview == null) {
      return;
    }
    if (overview.groups.isEmpty || overview.shareableClasses.isEmpty) {
      _showError(language.tr('selectGroupAndClass'));
      return;
    }

    var selectedGroupId = overview.groups.first.id;
    var selectedClassId = overview.shareableClasses.first.id;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(language.tr('shareClassWithGroup')),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: selectedGroupId,
                      items: overview.groups
                          .map(
                            (group) => DropdownMenuItem(
                              value: group.id,
                              child: Text(group.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setDialogState(() => selectedGroupId = value);
                      },
                      decoration: InputDecoration(
                        labelText: language.tr('selectGroup'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: selectedClassId,
                      items: overview.shareableClasses
                          .map(
                            (classObj) => DropdownMenuItem(
                              value: classObj.id,
                              child: Text(
                                classObj.scheduleSummary.isEmpty
                                    ? classObj.name
                                    : '${classObj.name}  ${classObj.scheduleSummary}',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setDialogState(() => selectedClassId = value);
                      },
                      decoration: InputDecoration(
                        labelText: language.tr('selectClass'),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(language.tr('cancel')),
                ),
                FilledButton.icon(
                  onPressed: () async {
                    final success = await supervision.shareClassWithGroup(
                      classId: selectedClassId,
                      groupId: selectedGroupId,
                    );
                    if (!mounted || !dialogContext.mounted) {
                      return;
                    }
                    if (success) {
                      Navigator.pop(dialogContext);
                      _showMessage(language.tr('classShared'));
                    } else {
                      _showError(
                        supervision.error ?? language.tr('operationFailed'),
                      );
                    }
                  },
                  icon: const Icon(Icons.share_rounded),
                  label: Text(language.tr('shareClass')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _onNavItemSelected(int index) {
    if (index == 2) {
      _openRouteAndRefresh('/room-scanner');
      return;
    }
    if (index == 3) {
      _openRouteAndRefresh('/batch-registration');
      return;
    }
    if (index == 5) {
      _openRouteAndRefresh('/admin');
      return;
    }
    if (index == 6) {
      _openRouteAndRefresh('/admin/attendance');
      return;
    }
    if (index == 7) {
      _openRouteAndRefresh('/admin/classes');
      return;
    }
    if (index == 8) {
      _openRouteAndRefresh('/notifications');
      return;
    }
    if (index == 9) {
      _openRouteAndRefresh('/leave-requests');
      return;
    }
    if (index == 11) {
      _openRouteAndRefresh('/roll-call');
      return;
    }
    if (index == 12) {
      _openRouteAndRefresh('/exam-proctoring');
      return;
    }
    if (index == 13) {
      _openRouteAndRefresh('/export-center');
      return;
    }
    if (index == 14) {
      _openRouteAndRefresh('/supervision');
      return;
    }
    setState(() => _currentIndex = index);
  }

  void _logout() async {
    final language = context.read<LanguageProvider>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(language.tr('signOutTitle')),
        content: Text(language.tr('signOutConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(language.tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: Text(language.tr('signOutTitle')),
          ),
        ],
      ),
    );
    if (confirm == true) {
      if (!mounted) return;
      await context.read<AuthProvider>().logout();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  Widget _buildCurrentPage() {
    switch (_currentIndex) {
      case 0:
        return _DashboardContent(
          key: const ValueKey('home-dashboard'),
          onRefresh: _loadData,
          onHistoryTap: () => _onNavItemSelected(1),
          onRoomScannerTap: () => _openRouteAndRefresh('/room-scanner'),
          onBatchRegisterTap: () => _openRouteAndRefresh('/batch-registration'),
          onEditAttendanceTap: () => _openRouteAndRefresh('/admin/attendance'),
          onClassesTap: () => _openRouteAndRefresh('/admin/classes'),
          onGuardianPortalTap: () => _openRouteAndRefresh('/guardian-portal'),
          onLeaveRequestsTap: () => _openRouteAndRefresh('/leave-requests'),
          onExportCenterTap: () => _openRouteAndRefresh('/export-center'),
          onCreateGroupTap: () {
            _showCreateGroupDialog();
          },
          onInviteTeachersTap: () {
            _showInviteTeachersDialog();
          },
          onShareClassTap: () {
            _showShareClassDialog();
          },
          onImportClassesTap: () => _openRouteAndRefresh('/admin/classes'),
          onSupervisionTap: () => _openRouteAndRefresh('/supervision'),
        );
      case 1:
        return const HistoryScreen(
          key: ValueKey('home-history'),
          embedded: true,
        );
      case 4:
        return const ProfileScreen(
          key: ValueKey('home-profile'),
          embedded: true,
        );
      default:
        return _DashboardContent(
          key: const ValueKey('home-fallback-dashboard'),
          onRefresh: _loadData,
          onHistoryTap: () => _onNavItemSelected(1),
          onRoomScannerTap: () => _openRouteAndRefresh('/room-scanner'),
          onBatchRegisterTap: () => _openRouteAndRefresh('/batch-registration'),
          onEditAttendanceTap: () => _openRouteAndRefresh('/admin/attendance'),
          onClassesTap: () => _openRouteAndRefresh('/admin/classes'),
          onGuardianPortalTap: () => _openRouteAndRefresh('/guardian-portal'),
          onLeaveRequestsTap: () => _openRouteAndRefresh('/leave-requests'),
          onExportCenterTap: () => _openRouteAndRefresh('/export-center'),
          onCreateGroupTap: () {
            _showCreateGroupDialog();
          },
          onInviteTeachersTap: () {
            _showInviteTeachersDialog();
          },
          onShareClassTap: () {
            _showShareClassDialog();
          },
          onImportClassesTap: () => _openRouteAndRefresh('/admin/classes'),
          onSupervisionTap: () => _openRouteAndRefresh('/supervision'),
        );
    }
  }

  Widget _buildAnimatedCurrentPage() {
    return AnimatedSwitcher(
      duration: AppTheme.animNormal,
      reverseDuration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          fit: StackFit.expand,
          children: [
            ...previousChildren,
            ...?currentChild == null ? null : [currentChild],
          ],
        );
      },
      transitionBuilder: (child, animation) {
        final fade = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: fade,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.02, 0),
              end: Offset.zero,
            ).animate(fade),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.992, end: 1).animate(fade),
              child: child,
            ),
          ),
        );
      },
      child: _buildCurrentPage(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!ResponsiveLayout.isDesktop(context)) {
      return _buildMobileLayout();
    }
    return _buildDesktopLayout();
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      body: Column(
        children: [
          if (ResponsiveLayout.isNativeDesktop()) const WindowTitleBar(),
          Expanded(
            child: Row(
              children: [
                SidebarNavigation(
                  currentIndex: _currentIndex,
                  onItemSelected: _onNavItemSelected,
                  onLogout: _logout,
                ),
                Expanded(
                  child: Container(
                    color: AppTheme.bgBase,
                    child: _buildAnimatedCurrentPage(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    final language = context.language;

    return Scaffold(
      body: _buildAnimatedCurrentPage(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex > 1 ? 0 : _currentIndex,
        onTap: (index) {
          if (index == 0) _onNavItemSelected(0);
          if (index == 1) _onNavItemSelected(1);
          if (index == 2) _onNavItemSelected(4);
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.dashboard_rounded),
            label: language.tr('dashboard'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.history_rounded),
            label: language.tr('history'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_rounded),
            label: language.tr('profile'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openRouteAndRefresh('/room-scanner'),
        child: const Icon(Icons.qr_code_scanner_rounded),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final VoidCallback onRefresh;
  final VoidCallback onHistoryTap;
  final VoidCallback onRoomScannerTap;
  final VoidCallback onBatchRegisterTap;
  final VoidCallback onEditAttendanceTap;
  final VoidCallback onClassesTap;
  final VoidCallback onGuardianPortalTap;
  final VoidCallback onLeaveRequestsTap;
  final VoidCallback onExportCenterTap;
  final VoidCallback onCreateGroupTap;
  final VoidCallback onInviteTeachersTap;
  final VoidCallback onShareClassTap;
  final VoidCallback onImportClassesTap;
  final VoidCallback onSupervisionTap;

  const _DashboardContent({
    super.key,
    required this.onRefresh,
    required this.onHistoryTap,
    required this.onRoomScannerTap,
    required this.onBatchRegisterTap,
    required this.onEditAttendanceTap,
    required this.onClassesTap,
    required this.onGuardianPortalTap,
    required this.onLeaveRequestsTap,
    required this.onExportCenterTap,
    required this.onCreateGroupTap,
    required this.onInviteTeachersTap,
    required this.onShareClassTap,
    required this.onImportClassesTap,
    required this.onSupervisionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: IgnorePointer(child: _DashboardAmbientBackground()),
        ),
        SingleChildScrollView(
          padding: ResponsiveLayout.pagePadding(context),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: ResponsiveLayout.contentMaxWidth(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 28),
                _buildStatCards(context),
                const SizedBox(height: 28),
                _buildMainContent(context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final language = context.language;
    final isMobile = ResponsiveLayout.isMobile(context);

    return Consumer2<AuthProvider, NotificationProvider>(
      builder: (context, auth, notifications, _) {
        final name = auth.user?.fullName ?? language.tr('user');
        final greeting = _getGreeting(language);
        final dateLabel = _getDateString(language);
        return Wrap(
          alignment: WrapAlignment.spaceBetween,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _MagneticGreeting(
              greeting: '$greeting, $name',
              dateLabel: dateLabel,
              isCompact: isMobile,
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _HeaderAction(
                  icon: Icons.refresh_rounded,
                  tooltip: language.tr('refresh'),
                  onTap: onRefresh,
                ),
                const SizedBox(width: 8),
                _HeaderAction(
                  icon: Icons.notifications_outlined,
                  tooltip: language.tr('notifications'),
                  onTap: () => Navigator.pushNamed(context, '/notifications'),
                  badge: notifications.unreadCount > 0
                      ? notifications.unreadCount
                      : null,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCards(BuildContext context) {
    final language = context.language;
    final crossAxisCount = ResponsiveLayout.gridColumns(
      context,
      compact: 1,
      mobile: 1,
      tablet: 2,
      desktop: 4,
      wide: 4,
    );

    return Consumer3<
      AttendanceProvider,
      AuthProvider,
      StudentManagementProvider
    >(
      builder: (context, attendance, auth, studentManagement, _) {
        final stats = attendance.stats;
        final user = auth.user;
        final isManagementUser =
            user?.isTeacher == true || user?.isAdmin == true;
        final managementRecords = attendance.todayAttendance
            .where(
              (record) =>
                  record.classId != null ||
                  record.studentId != null ||
                  (record.studentName?.trim().isNotEmpty ?? false),
            )
            .toList();
        final totalStudents = studentManagement.classes.fold<int>(
          0,
          (sum, classObj) => sum + classObj.studentCount,
        );
        final presentCount = managementRecords
            .where((record) => record.status == 'present')
            .length;
        final lateCount = managementRecords
            .where((record) => record.status == 'late')
            .length;
        final absentCount = isManagementUser
            ? (totalStudents - (presentCount + lateCount)).clamp(
                0,
                totalStudents,
              )
            : stats?.absentDays ?? 0;
        final rate = isManagementUser
            ? totalStudents > 0
                  ? '${(((presentCount + lateCount) / totalStudents) * 100).toStringAsFixed(0)}%'
                  : '0%'
            : _calcRate(stats);

        return GridView.count(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: crossAxisCount == 1
              ? (ResponsiveLayout.isCompact(context) ? 2.1 : 2.6)
              : 1.45,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            StatsCard(
              title: language.tr('totalPresent'),
              value: isManagementUser
                  ? '$presentCount'
                  : '${stats?.presentDays ?? 0}',
              icon: Icons.check_circle_rounded,
              iconColor: AppTheme.successColor,
              animationIndex: 0,
            ),
            StatsCard(
              title: language.tr('totalLate'),
              value: isManagementUser
                  ? '$lateCount'
                  : '${stats?.lateDays ?? 0}',
              icon: Icons.access_time_rounded,
              iconColor: AppTheme.warningColor,
              animationIndex: 1,
            ),
            StatsCard(
              title: language.tr('totalAbsent'),
              value: '$absentCount',
              icon: Icons.cancel_rounded,
              iconColor: AppTheme.errorColor,
              animationIndex: 2,
            ),
            StatsCard(
              title: language.tr('attendanceRate'),
              value: rate,
              icon: Icons.trending_up_rounded,
              iconColor: AppTheme.secondaryColor,
              animationIndex: 3,
            ),
          ],
        );
      },
    );
  }

  Widget _buildMainContent(BuildContext context) {
    final useSplitLayout = ResponsiveLayout.width(context) >= 1120;
    final groupPanel = Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final showGroupPanel = auth.user?.canUseGroups == true;
        if (!showGroupPanel) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: 20),
          child: _TeacherGroupsPanel(
            onCreateGroupTap: onCreateGroupTap,
            onInviteTeachersTap: onInviteTeachersTap,
            onShareClassTap: onShareClassTap,
            onImportClassesTap: onImportClassesTap,
            onExportCenterTap: onExportCenterTap,
            onSupervisionTap: onSupervisionTap,
          ),
        );
      },
    );

    if (useSplitLayout) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 6,
            child: Column(
              children: [
                _QuickActionsPanel(
                  onHistoryTap: onHistoryTap,
                  onRoomScannerTap: onRoomScannerTap,
                  onBatchRegisterTap: onBatchRegisterTap,
                  onEditAttendanceTap: onEditAttendanceTap,
                  onClassesTap: onClassesTap,
                  onGuardianPortalTap: onGuardianPortalTap,
                  onLeaveRequestsTap: onLeaveRequestsTap,
                  onExportCenterTap: onExportCenterTap,
                  onSupervisionTap: onSupervisionTap,
                ),
                groupPanel,
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(flex: 4, child: _TodayStatusPanel()),
        ],
      );
    }

    return Column(
      children: [
        _QuickActionsPanel(
          onHistoryTap: onHistoryTap,
          onRoomScannerTap: onRoomScannerTap,
          onBatchRegisterTap: onBatchRegisterTap,
          onEditAttendanceTap: onEditAttendanceTap,
          onClassesTap: onClassesTap,
          onGuardianPortalTap: onGuardianPortalTap,
          onLeaveRequestsTap: onLeaveRequestsTap,
          onExportCenterTap: onExportCenterTap,
          onSupervisionTap: onSupervisionTap,
        ),
        groupPanel,
        const SizedBox(height: 20),
        _TodayStatusPanel(),
      ],
    );
  }

  String _getGreeting(LanguageProvider language) {
    final hour = DateTime.now().hour;
    if (hour < 12) return language.tr('goodMorning');
    if (hour < 17) return language.tr('goodAfternoon');
    return language.tr('goodEvening');
  }

  String _getDateString(LanguageProvider language) {
    final now = DateTime.now();
    if (language.isArabic) {
      return DateFormat('EEEE، d MMMM y', 'ar').format(now);
    }
    if (language.isSorani) {
      const months = [
        '',
        'کانوونی دووەم',
        'شوبات',
        'ئادار',
        'نیسان',
        'ئایار',
        'حوزەیران',
        'تەمموز',
        'ئاب',
        'ئەیلوول',
        'تشرینی یەکەم',
        'تشرینی دووەم',
        'کانوونی یەکەم',
      ];
      const days = [
        'دووشەممە',
        'سێشەممە',
        'چوارشەممە',
        'پێنجشەممە',
        'هەینی',
        'شەممە',
        'یەکشەممە',
      ];
      return '${days[now.weekday - 1]}، ${now.day} ${months[now.month]} ${now.year}';
    }

    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[now.weekday - 1]}, ${months[now.month]} ${now.day}, ${now.year}';
  }

  String _calcRate(AttendanceStats? stats) {
    if (stats == null) return '0%';
    return '${stats.attendancePercentage.toStringAsFixed(0)}%';
  }
}

class _MagneticGreeting extends StatefulWidget {
  final String greeting;
  final String dateLabel;
  final bool isCompact;

  const _MagneticGreeting({
    required this.greeting,
    required this.dateLabel,
    required this.isCompact,
  });

  @override
  State<_MagneticGreeting> createState() => _MagneticGreetingState();
}

class _MagneticGreetingState extends State<_MagneticGreeting> {
  bool _isHovered = false;
  Offset _pointerOffset = Offset.zero;

  void _updatePointer(PointerHoverEvent event) {
    final box = context.findRenderObject() as RenderBox?;
    final size = box?.size;
    if (size == null || size.width == 0 || size.height == 0) {
      return;
    }

    final normalized = Offset(
      ((event.localPosition.dx / size.width) - 0.5) * 2,
      ((event.localPosition.dy / size.height) - 0.5) * 2,
    );

    setState(() {
      _pointerOffset = Offset(
        normalized.dx.clamp(-1.0, 1.0),
        normalized.dy.clamp(-1.0, 1.0),
      );
    });
  }

  void _resetMagnet() {
    setState(() {
      _isHovered = false;
      _pointerOffset = Offset.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    final greetingStyle = TextStyle(
      fontSize: widget.isCompact ? 22 : 28,
      fontWeight: FontWeight.bold,
      color: AppTheme.textPrimary,
      letterSpacing: -0.3,
    );
    final dateStyle = TextStyle(
      fontSize: widget.isCompact ? 13 : 14,
      color: AppTheme.textSecondary,
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onHover: _updatePointer,
      onExit: (_) => _resetMagnet(),
      child: TweenAnimationBuilder<Offset>(
        tween: Tween<Offset>(
          end: _isHovered
              ? Offset(_pointerOffset.dx * 12, _pointerOffset.dy * 10)
              : Offset.zero,
        ),
        duration: AppTheme.animNormal,
        curve: Curves.easeOutCubic,
        builder: (context, offset, child) {
          return Transform.translate(
            offset: offset,
            child: Transform.scale(scale: _isHovered ? 1.012 : 1, child: child),
          );
        },
        child: AnimatedContainer(
          duration: AppTheme.animNormal,
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      blurRadius: 18,
                      spreadRadius: 1,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : const [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.greeting,
                style: greetingStyle,
              ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.02),
              const SizedBox(height: 4),
              Text(
                widget.dateLabel,
                style: dateStyle,
              ).animate().fadeIn(delay: 200.ms),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardAmbientBackground extends StatefulWidget {
  const _DashboardAmbientBackground();

  @override
  State<_DashboardAmbientBackground> createState() =>
      _DashboardAmbientBackgroundState();
}

class _DashboardAmbientBackgroundState
    extends State<_DashboardAmbientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 18000),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = ResponsiveLayout.isCompact(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return RepaintBoundary(
          child: CustomPaint(
            painter: _DashboardOrbsPainter(
              progress: _controller.value,
              isCompact: isCompact,
            ),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }
}

class _DashboardOrbsPainter extends CustomPainter {
  final double progress;
  final bool isCompact;

  const _DashboardOrbsPainter({
    required this.progress,
    required this.isCompact,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final baseShader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        AppTheme.bgBase.withValues(alpha: 0),
        AppTheme.bgBase.withValues(alpha: 0.08),
        AppTheme.bgDeep.withValues(alpha: 0.14),
      ],
    ).createShader(bounds);

    canvas.drawRect(bounds, Paint()..shader = baseShader);

    final angle = progress * math.pi * 2;
    final shortest = size.shortestSide;
    final baseOpacity = isCompact ? 0.16 : 0.24;
    final blur = isCompact ? 54.0 : 74.0;

    _paintOrb(
      canvas,
      center: Offset(
        size.width * (0.8 + (math.sin(angle * 0.85) * 0.05)),
        size.height * (0.18 + (math.cos(angle * 0.6) * 0.04)),
      ),
      radius: shortest * (isCompact ? 0.18 : 0.24),
      color: AppTheme.primaryColor,
      opacity: baseOpacity,
      blurSigma: blur,
    );

    _paintOrb(
      canvas,
      center: Offset(
        size.width * (0.16 + (math.cos(angle * 0.75) * 0.05)),
        size.height * (0.44 + (math.sin(angle * 0.95) * 0.05)),
      ),
      radius: shortest * (isCompact ? 0.14 : 0.19),
      color: AppTheme.secondaryColor,
      opacity: baseOpacity * 0.95,
      blurSigma: blur * 0.88,
    );

    _paintOrb(
      canvas,
      center: Offset(
        size.width * (0.62 + (math.sin((angle + 1.4) * 0.65) * 0.04)),
        size.height * (0.82 + (math.cos((angle + 0.5) * 0.72) * 0.03)),
      ),
      radius: shortest * (isCompact ? 0.12 : 0.17),
      color: AppTheme.accentColor,
      opacity: baseOpacity * 0.7,
      blurSigma: blur * 0.72,
    );
  }

  void _paintOrb(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color color,
    required double opacity,
    required double blurSigma,
  }) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, blurSigma);

    canvas.drawCircle(center, radius, paint);

    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: opacity * 0.14)
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, blurSigma * 0.42);

    canvas.drawCircle(
      Offset(center.dx - (radius * 0.18), center.dy - (radius * 0.16)),
      radius * 0.34,
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DashboardOrbsPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isCompact != isCompact;
  }
}

class _QuickActionsPanel extends StatelessWidget {
  final VoidCallback onHistoryTap;
  final VoidCallback onRoomScannerTap;
  final VoidCallback onBatchRegisterTap;
  final VoidCallback onEditAttendanceTap;
  final VoidCallback onClassesTap;
  final VoidCallback onGuardianPortalTap;
  final VoidCallback onLeaveRequestsTap;
  final VoidCallback onExportCenterTap;
  final VoidCallback onSupervisionTap;

  const _QuickActionsPanel({
    required this.onHistoryTap,
    required this.onRoomScannerTap,
    required this.onBatchRegisterTap,
    required this.onEditAttendanceTap,
    required this.onClassesTap,
    required this.onGuardianPortalTap,
    required this.onLeaveRequestsTap,
    required this.onExportCenterTap,
    required this.onSupervisionTap,
  });

  @override
  Widget build(BuildContext context) {
    final language = context.language;
    final isMobile = ResponsiveLayout.isMobile(context);

    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final isManagementUser =
            auth.user?.isAdmin == true || auth.user?.isTeacher == true;
        final canUseGroups = auth.user?.canUseGroups == true;

        return Container(
          padding: EdgeInsets.all(isMobile ? 20 : 24),
          decoration: AppTheme.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                language.tr('quickActions'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _ActionTile(
                    icon: Icons.qr_code_scanner_rounded,
                    label: language.tr('roomScanner'),
                    color: AppTheme.primaryColor,
                    onTap: onRoomScannerTap,
                    isCompact: isMobile,
                  ),
                  _ActionTile(
                    icon: Icons.group_add_rounded,
                    label: language.tr('batchRegister'),
                    color: AppTheme.secondaryColor,
                    onTap: onBatchRegisterTap,
                    isCompact: isMobile,
                  ),
                  _ActionTile(
                    icon: Icons.edit_note_rounded,
                    label: language.tr('editAttendance'),
                    color: AppTheme.infoColor,
                    onTap: onEditAttendanceTap,
                    isCompact: isMobile,
                  ),
                  _ActionTile(
                    icon: Icons.class_rounded,
                    label: language.tr('manageClasses'),
                    color: Colors.amber,
                    onTap: onClassesTap,
                    isCompact: isMobile,
                  ),
                  if (isManagementUser)
                    _ActionTile(
                      icon: Icons.family_restroom_rounded,
                      label: language.tr('guardianPortal'),
                      color: AppTheme.accentColor,
                      onTap: onGuardianPortalTap,
                      isCompact: isMobile,
                    ),
                  _ActionTile(
                    icon: Icons.event_note_rounded,
                    label: language.tr('leaveRequests'),
                    color: Colors.teal,
                    onTap: onLeaveRequestsTap,
                    isCompact: isMobile,
                  ),
                  if (isManagementUser)
                    _ActionTile(
                      icon: Icons.download_for_offline_rounded,
                      label: language.tr('exportCenter'),
                      color: Colors.cyan,
                      onTap: onExportCenterTap,
                      isCompact: isMobile,
                    ),
                  if (canUseGroups)
                    _ActionTile(
                      icon: Icons.groups_2_rounded,
                      label: language.tr('supervisorHub'),
                      color: Colors.deepOrangeAccent,
                      onTap: onSupervisionTap,
                      isCompact: isMobile,
                    ),
                  _ActionTile(
                    icon: Icons.history_rounded,
                    label: language.tr('fullHistory'),
                    color: Colors.purple,
                    onTap: onHistoryTap,
                    isCompact: isMobile,
                  ),
                ],
              ),
            ],
          ),
        ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.03, end: 0);
      },
    );
  }
}

class _ActionTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isCompact;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isCompact = false,
  });

  @override
  State<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<_ActionTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final tileWidth = screenWidth < 420
        ? screenWidth - 72
        : (widget.isCompact ? 132.0 : 145.0);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppTheme.animFast,
          width: tileWidth,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _isHovered
                ? widget.color.withValues(alpha: 0.12)
                : AppTheme.bgElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isHovered
                  ? widget.color.withValues(alpha: 0.3)
                  : AppTheme.glassBorder,
              width: _isHovered ? 1 : 0.5,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Column(
            children: [
              Icon(widget.icon, color: widget.color, size: 28),
              const SizedBox(height: 10),
              Text(
                widget.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _isHovered
                      ? AppTheme.textPrimary
                      : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeacherGroupsPanel extends StatelessWidget {
  final VoidCallback onCreateGroupTap;
  final VoidCallback onInviteTeachersTap;
  final VoidCallback onShareClassTap;
  final VoidCallback onImportClassesTap;
  final VoidCallback onExportCenterTap;
  final VoidCallback onSupervisionTap;

  const _TeacherGroupsPanel({
    required this.onCreateGroupTap,
    required this.onInviteTeachersTap,
    required this.onShareClassTap,
    required this.onImportClassesTap,
    required this.onExportCenterTap,
    required this.onSupervisionTap,
  });

  @override
  Widget build(BuildContext context) {
    final language = context.language;
    final isMobile = ResponsiveLayout.isMobile(context);

    return Consumer<SupervisionProvider>(
      builder: (context, supervision, _) {
        final overview = supervision.overview;
        final groups = overview?.groups ?? const <TeacherGroup>[];
        final canInviteTeachers =
            overview?.groups.any((group) => group.canManage) ??
            (context.read<AuthProvider>().user?.isAdmin == true ||
                context.read<AuthProvider>().user?.isSupervisor == true);
        final canCreateGroups =
            overview?.canCreateGroups ??
            (context.read<AuthProvider>().user?.canUseGroups == true);
        final canShareClasses =
            overview?.canShareClasses ??
            (context.read<AuthProvider>().user?.isAdmin == true ||
                context.read<AuthProvider>().user?.isTeacher == true);
        final totalMembers = groups.fold<int>(
          0,
          (sum, group) => sum + group.members.length,
        );
        final totalSharedClasses = groups.fold<int>(
          0,
          (sum, group) => sum + group.sharedClasses.length,
        );
        final totalPendingInvites = groups.fold<int>(
          0,
          (sum, group) => sum + group.pendingInviteCount,
        );

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(isMobile ? 20 : 24),
          decoration: AppTheme.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        language.tr('teacherGroups'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _GroupStatChip(
                            icon: Icons.groups_2_rounded,
                            label:
                                '${groups.length} ${language.tr('teacherGroups')}',
                          ),
                          _GroupStatChip(
                            icon: Icons.person_add_alt_1_rounded,
                            label: '$totalMembers ${language.tr('members')}',
                          ),
                          _GroupStatChip(
                            icon: Icons.pending_actions_rounded,
                            label:
                                '$totalPendingInvites ${language.tr('pendingInvitations')}',
                          ),
                          _GroupStatChip(
                            icon: Icons.class_rounded,
                            label:
                                '$totalSharedClasses ${language.tr('classes')}',
                          ),
                        ],
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      if (canCreateGroups)
                        FilledButton.icon(
                          onPressed: onCreateGroupTap,
                          icon: const Icon(Icons.add_circle_outline_rounded),
                          label: Text(language.tr('createGroup')),
                        ),
                      if (canInviteTeachers)
                        OutlinedButton.icon(
                          onPressed: onInviteTeachersTap,
                          icon: const Icon(Icons.alternate_email_rounded),
                          label: Text(language.tr('inviteTeachers')),
                        ),
                      if (canShareClasses)
                        OutlinedButton.icon(
                          onPressed: onShareClassTap,
                          icon: const Icon(Icons.library_add_check_rounded),
                          label: Text(language.tr('shareClass')),
                        ),
                      OutlinedButton.icon(
                        onPressed: onImportClassesTap,
                        icon: const Icon(Icons.upload_file_rounded),
                        label: Text(context.t('Import Classes')),
                      ),
                      OutlinedButton.icon(
                        onPressed: onExportCenterTap,
                        icon: const Icon(Icons.download_for_offline_rounded),
                        label: Text(language.tr('exportCenter')),
                      ),
                      TextButton.icon(
                        onPressed: onSupervisionTap,
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: Text(language.tr('supervisorHub')),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (supervision.isLoading && overview == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (groups.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.bgElevated,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.glassBorder),
                  ),
                  child: Text(
                    language.tr('noTeacherGroups'),
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                )
              else
                Column(
                  children: groups
                      .map(
                        (group) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _TeacherGroupSummaryCard(group: group),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        ).animate().fadeIn(delay: 820.ms).slideY(begin: 0.03, end: 0);
      },
    );
  }
}

class _GroupStatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _GroupStatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgElevated,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherGroupSummaryCard extends StatelessWidget {
  final TeacherGroup group;

  const _TeacherGroupSummaryCard({required this.group});

  @override
  Widget build(BuildContext context) {
    final language = context.language;
    final memberEmails = group.members
        .take(3)
        .map((member) => member.teacherEmail)
        .where((email) => email.trim().isNotEmpty)
        .join('  •  ');
    final sharedClasses = group.sharedClasses
        .take(3)
        .map((classObj) => classObj.className)
        .where((name) => name.trim().isNotEmpty)
        .join('  •  ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.bgElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  group.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _GroupStatChip(
                    icon: Icons.people_alt_rounded,
                    label: '${group.members.length} ${language.tr('members')}',
                  ),
                  _GroupStatChip(
                    icon: Icons.pending_actions_rounded,
                    label:
                        '${group.pendingInviteCount} ${language.tr('pendingInvitations')}',
                  ),
                  _GroupStatChip(
                    icon: Icons.class_rounded,
                    label:
                        '${group.sharedClasses.length} ${language.tr('classes')}',
                  ),
                ],
              ),
            ],
          ),
          if (group.description?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 10),
            Text(
              group.description!.trim(),
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.alternate_email_rounded,
                size: 18,
                color: AppTheme.secondaryColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  memberEmails.isEmpty
                      ? language.tr('noMembersYet')
                      : memberEmails,
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.library_books_rounded,
                size: 18,
                color: AppTheme.accentColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  sharedClasses.isEmpty
                      ? language.tr('noSharedClasses')
                      : sharedClasses,
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodayStatusPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final language = context.language;
    final isMobile = ResponsiveLayout.isMobile(context);

    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      decoration: AppTheme.cardDecoration(),
      child:
          Consumer3<
            AttendanceProvider,
            AuthProvider,
            StudentManagementProvider
          >(
            builder: (context, attendance, auth, studentManagement, _) {
              final user = auth.user;
              final isManagementUser =
                  user?.isTeacher == true || user?.isAdmin == true;
              final todayRecords = attendance.todayAttendance;
              final managementRecords = todayRecords
                  .where(
                    (record) =>
                        record.classId != null ||
                        record.studentId != null ||
                        (record.studentName?.trim().isNotEmpty ?? false),
                  )
                  .toList();
              final todayRecord = isManagementUser
                  ? null
                  : todayRecords.isNotEmpty
                  ? todayRecords.first
                  : null;
              final totalStudents = studentManagement.classes.fold<int>(
                0,
                (sum, classObj) => sum + classObj.studentCount,
              );
              final presentCount = managementRecords
                  .where((record) => record.status == 'present')
                  .length;
              final lateCount = managementRecords
                  .where((record) => record.status == 'late')
                  .length;
              final absentCount = (totalStudents - (presentCount + lateCount))
                  .clamp(0, totalStudents);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    language.tr('todaysStatus'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (isManagementUser)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.bgElevated,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.glassBorder,
                          width: 0.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            totalStudents > 0
                                ? '$presentCount / $totalStudents'
                                : '0 / 0',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            managementRecords.isNotEmpty
                                ? 'Students recorded today'
                                : 'No class attendance recorded today',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final columns = constraints.maxWidth >= 420
                                  ? 3
                                  : constraints.maxWidth >= 280
                                  ? 2
                                  : 1;
                              final itemWidth =
                                  (constraints.maxWidth -
                                      ((columns - 1) * 10)) /
                                  columns;

                              return Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  SizedBox(
                                    width: itemWidth,
                                    child: _SummaryMetric(
                                      label: language.tr('totalPresent'),
                                      value: '$presentCount',
                                      color: AppTheme.successColor,
                                    ),
                                  ),
                                  SizedBox(
                                    width: itemWidth,
                                    child: _SummaryMetric(
                                      label: language.tr('totalLate'),
                                      value: '$lateCount',
                                      color: AppTheme.warningColor,
                                    ),
                                  ),
                                  SizedBox(
                                    width: itemWidth,
                                    child: _SummaryMetric(
                                      label: language.tr('totalAbsent'),
                                      value: '$absentCount',
                                      color: AppTheme.errorColor,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    )
                  else if (todayRecord != null)
                    AttendanceStatusCard(
                      status: todayRecord.status,
                      time: todayRecord.formattedTime,
                      confidence: todayRecord.confidence,
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: AppTheme.bgElevated,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.glassBorder,
                          width: 0.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.event_available_rounded,
                            color: AppTheme.textMuted,
                            size: 40,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            language.tr('noAttendanceToday'),
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
    ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.03, end: 0);
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _HeaderAction extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final int? badge;

  const _HeaderAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badge,
  });

  @override
  State<_HeaderAction> createState() => _HeaderActionState();
}

class _HeaderActionState extends State<_HeaderAction> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: AppTheme.animFast,
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _isHovered ? AppTheme.bgElevated : AppTheme.bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _isHovered
                    ? AppTheme.primaryColor.withValues(alpha: 0.2)
                    : AppTheme.glassBorder,
                width: 0.5,
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    widget.icon,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                ),
                if (widget.badge != null)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.bgCard, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          '${widget.badge}',
                          style: const TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
