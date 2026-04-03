import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../localization/localization_extensions.dart';
import '../models/attendance_model.dart';
import '../providers/attendance_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/student_management_provider.dart';
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
  }

  Future<void> _openRouteAndRefresh(String routeName) async {
    await Navigator.pushNamed(context, routeName);
    if (mounted) {
      _loadData();
    }
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
          onRefresh: _loadData,
          onHistoryTap: () => _onNavItemSelected(1),
          onRoomScannerTap: () => _openRouteAndRefresh('/room-scanner'),
          onBatchRegisterTap: () => _openRouteAndRefresh('/batch-registration'),
          onEditAttendanceTap: () => _openRouteAndRefresh('/admin/attendance'),
          onClassesTap: () => _openRouteAndRefresh('/admin/classes'),
          onLeaveRequestsTap: () => _openRouteAndRefresh('/leave-requests'),
        );
      case 1:
        return const HistoryScreen(embedded: true);
      case 4:
        return const ProfileScreen(embedded: true);
      default:
        return _DashboardContent(
          onRefresh: _loadData,
          onHistoryTap: () => _onNavItemSelected(1),
          onRoomScannerTap: () => _openRouteAndRefresh('/room-scanner'),
          onBatchRegisterTap: () => _openRouteAndRefresh('/batch-registration'),
          onEditAttendanceTap: () => _openRouteAndRefresh('/admin/attendance'),
          onClassesTap: () => _openRouteAndRefresh('/admin/classes'),
          onLeaveRequestsTap: () => _openRouteAndRefresh('/leave-requests'),
        );
    }
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
                    child: _buildCurrentPage(),
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
      body: _buildCurrentPage(),
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
  final VoidCallback onLeaveRequestsTap;

  const _DashboardContent({
    required this.onRefresh,
    required this.onHistoryTap,
    required this.onRoomScannerTap,
    required this.onBatchRegisterTap,
    required this.onEditAttendanceTap,
    required this.onClassesTap,
    required this.onLeaveRequestsTap,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.isMobile(context);

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 20 : 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
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
    );
  }

  Widget _buildHeader(BuildContext context) {
    final language = context.language;
    final isMobile = ResponsiveLayout.isMobile(context);

    return Consumer2<AuthProvider, NotificationProvider>(
      builder: (context, auth, notifications, _) {
        final name = auth.user?.fullName ?? language.tr('user');
        final greeting = _getGreeting(language);
        return Wrap(
          alignment: WrapAlignment.spaceBetween,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting، $name 👋',
                  style: TextStyle(
                    fontSize: isMobile ? 22 : 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.02),
                const SizedBox(height: 4),
                Text(
                  _getDateString(language),
                  style: TextStyle(
                    fontSize: isMobile ? 13 : 14,
                    color: AppTheme.textSecondary,
                  ),
                ).animate().fadeIn(delay: 200.ms),
              ],
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
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 1200
        ? 4
        : width >= 700
        ? 2
        : 1;

    return Consumer3<AttendanceProvider, AuthProvider, StudentManagementProvider>(
      builder: (context, attendance, auth, studentManagement, _) {
        final stats = attendance.stats;
        final user = auth.user;
        final isManagementUser = user?.isTeacher == true || user?.isAdmin == true;
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
            ? (totalStudents - (presentCount + lateCount)).clamp(0, totalStudents)
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
          childAspectRatio: crossAxisCount == 1 ? 2.8 : 1.45,
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
                )
                .animate()
                .fadeIn(delay: 300.ms)
                .scale(begin: const Offset(0.95, 0.95)),
            StatsCard(
                  title: language.tr('totalLate'),
                  value: isManagementUser ? '$lateCount' : '${stats?.lateDays ?? 0}',
                  icon: Icons.access_time_rounded,
                  iconColor: AppTheme.warningColor,
                )
                .animate()
                .fadeIn(delay: 400.ms)
                .scale(begin: const Offset(0.95, 0.95)),
            StatsCard(
                  title: language.tr('totalAbsent'),
                  value: '$absentCount',
                  icon: Icons.cancel_rounded,
                  iconColor: AppTheme.errorColor,
                )
                .animate()
                .fadeIn(delay: 500.ms)
                .scale(begin: const Offset(0.95, 0.95)),
            StatsCard(
                  title: language.tr('attendanceRate'),
                  value: rate,
                  icon: Icons.trending_up_rounded,
                  iconColor: AppTheme.secondaryColor,
                )
                .animate()
                .fadeIn(delay: 600.ms)
                .scale(begin: const Offset(0.95, 0.95)),
          ],
        );
      },
    );
  }

  Widget _buildMainContent(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 6,
            child: _QuickActionsPanel(
              onHistoryTap: onHistoryTap,
              onRoomScannerTap: onRoomScannerTap,
              onBatchRegisterTap: onBatchRegisterTap,
              onEditAttendanceTap: onEditAttendanceTap,
              onClassesTap: onClassesTap,
              onLeaveRequestsTap: onLeaveRequestsTap,
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
          onLeaveRequestsTap: onLeaveRequestsTap,
        ),
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

class _QuickActionsPanel extends StatelessWidget {
  final VoidCallback onHistoryTap;
  final VoidCallback onRoomScannerTap;
  final VoidCallback onBatchRegisterTap;
  final VoidCallback onEditAttendanceTap;
  final VoidCallback onClassesTap;
  final VoidCallback onLeaveRequestsTap;

  const _QuickActionsPanel({
    required this.onHistoryTap,
    required this.onRoomScannerTap,
    required this.onBatchRegisterTap,
    required this.onEditAttendanceTap,
    required this.onClassesTap,
    required this.onLeaveRequestsTap,
  });

  @override
  Widget build(BuildContext context) {
    final language = context.language;
    final isMobile = ResponsiveLayout.isMobile(context);

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
              _ActionTile(
                icon: Icons.event_note_rounded,
                label: language.tr('leaveRequests'),
                color: Colors.teal,
                onTap: onLeaveRequestsTap,
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
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppTheme.animFast,
          width: widget.isCompact ? 132 : 145,
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

class _TodayStatusPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final language = context.language;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.cardDecoration(),
      child: Consumer3<AttendanceProvider, AuthProvider, StudentManagementProvider>(
        builder: (context, attendance, auth, studentManagement, _) {
          final user = auth.user;
          final isManagementUser = user?.isTeacher == true || user?.isAdmin == true;
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
                    border: Border.all(color: AppTheme.glassBorder, width: 0.5),
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
                      Row(
                        children: [
                          Expanded(
                            child: _SummaryMetric(
                              label: language.tr('totalPresent'),
                              value: '$presentCount',
                              color: AppTheme.successColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _SummaryMetric(
                              label: language.tr('totalLate'),
                              value: '$lateCount',
                              color: AppTheme.warningColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _SummaryMetric(
                              label: language.tr('totalAbsent'),
                              value: '$absentCount',
                              color: AppTheme.errorColor,
                            ),
                          ),
                        ],
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
                    border: Border.all(color: AppTheme.glassBorder, width: 0.5),
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
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
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
