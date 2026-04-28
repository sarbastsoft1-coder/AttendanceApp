import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../localization/localization_extensions.dart';
import '../models/attendance_model.dart';
import '../providers/attendance_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/window_title_bar.dart';

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadStudentData();
      }
    });
  }

  Future<void> _loadStudentData() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) {
      return;
    }

    final attendance = context.read<AttendanceProvider>();
    await attendance.fetchCompleteHistory(
      userId: user.id,
      statusFilter: 'Absent',
    );
    await attendance.fetchStats(user.id);
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) {
      return;
    }
    Navigator.pushReplacementNamed(context, '/gov-login-intro');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          if (ResponsiveLayout.isNativeDesktop()) const WindowTitleBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadStudentData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: ResponsiveLayout.pagePadding(context),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: ResponsiveLayout.contentMaxWidth(context),
                  ),
                  child: Consumer2<AuthProvider, AttendanceProvider>(
                    builder: (context, auth, attendance, _) {
                      final user = auth.user;
                      final absentRecords = attendance.history
                          .where((record) => record.status == 'absent')
                          .toList();
                      final classNames =
                          absentRecords
                              .map((record) => (record.className ?? '').trim())
                              .where((name) => name.isNotEmpty)
                              .toSet()
                              .toList()
                            ..sort();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _StudentDashboardHeader(
                            userName: user?.fullName ?? context.t('Student'),
                            onProfileTap: () =>
                                Navigator.pushNamed(context, '/profile'),
                            onLogoutTap: _logout,
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: _StudentStatCard(
                                  title: context.t('Absent Records'),
                                  value:
                                      '${attendance.stats?.absentDays ?? absentRecords.length}',
                                  icon: Icons.event_busy_rounded,
                                  color: AppTheme.errorColor,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _StudentStatCard(
                                  title: context.t('Classes With Absence'),
                                  value: '${classNames.length}',
                                  icon: Icons.class_rounded,
                                  color: AppTheme.warningColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _StudentSectionCard(
                            title: context.t('Classes'),
                            child: classNames.isEmpty
                                ? Text(
                                    context.t('No absent classes found'),
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                    ),
                                  )
                                : Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: classNames
                                        .map(
                                          (name) => Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 10,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppTheme.bgElevated,
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                              border: Border.all(
                                                color: AppTheme.glassBorder,
                                              ),
                                            ),
                                            child: Text(
                                              name,
                                              style: const TextStyle(
                                                color: AppTheme.textPrimary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                          ),
                          const SizedBox(height: 20),
                          _StudentSectionCard(
                            title: context.t('Absent Records'),
                            child: attendance.isLoading
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 24),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  )
                                : absentRecords.isEmpty
                                ? Text(
                                    attendance.error ??
                                        context.t(
                                          'No absence records are available.',
                                        ),
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                    ),
                                  )
                                : Column(
                                    children: absentRecords
                                        .map(
                                          (record) => Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 12,
                                            ),
                                            child: _AbsentRecordTile(
                                              record: record,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentDashboardHeader extends StatelessWidget {
  final String userName;
  final VoidCallback onProfileTap;
  final VoidCallback onLogoutTap;

  const _StudentDashboardHeader({
    required this.userName,
    required this.onProfileTap,
    required this.onLogoutTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('Student Dashboard'),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.t(
                        'See your absent classes and attendance records only.',
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                onSelected: (value) {
                  if (value == 'profile') {
                    onProfileTap();
                  } else if (value == 'logout') {
                    onLogoutTap();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'profile',
                    child: Text(context.t('Profile')),
                  ),
                  PopupMenuItem(
                    value: 'logout',
                    child: Text(context.t('Sign Out')),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            userName,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.95),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StudentStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentSectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _StudentSectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _AbsentRecordTile extends StatelessWidget {
  final Attendance record;

  const _AbsentRecordTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final className = (record.className ?? '').trim();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.errorColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.event_busy_rounded,
              color: AppTheme.errorColor,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  className.isEmpty ? context.t('Unassigned Class') : className,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM d, yyyy').format(record.date),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            context.t('Absent'),
            style: const TextStyle(
              color: AppTheme.errorColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
