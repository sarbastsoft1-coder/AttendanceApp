import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/attendance_provider.dart';
import '../models/attendance_model.dart';
import '../widgets/window_title_bar.dart';
import '../widgets/sidebar_navigation.dart';
import '../widgets/stats_card.dart';
import '../widgets/responsive_layout.dart';
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

  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final authProvider = context.read<AuthProvider>();
    final attendanceProvider = context.read<AttendanceProvider>();

    attendanceProvider.fetchTodayAttendance();

    if (authProvider.user != null) {
      attendanceProvider.fetchStats(
        authProvider.user!.id,
        month: DateTime.now().month,
        year: DateTime.now().year,
      );
    }

    if (authProvider.isAdmin) {
      attendanceProvider.fetchDashboardStats();
    }
  }

  void _onNavItemSelected(int index) {
    if (index == 2) {
      Navigator.pushNamed(context, '/room-scanner');
      return;
    }
    if (index == 3) {
      Navigator.pushNamed(context, '/batch-registration');
      return;
    }
    if (index == 5) {
      Navigator.pushNamed(context, '/admin');
      return;
    }
    if (index == 6) {
      Navigator.pushNamed(context, '/admin/attendance');
      return;
    }
    if (index == 7) {
      Navigator.pushNamed(context, '/admin/classes');
      return;
    }
    setState(() => _currentIndex = index);
  }

  void _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Sign Out'),
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
        );
      case 1:
        return const HistoryScreen(embedded: true);
      case 4:
        return const ProfileScreen(embedded: true);
      default:
        return _DashboardContent(
          onRefresh: _loadData,
          onHistoryTap: () => _onNavItemSelected(1),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDesktop) {
      return _buildMobileLayout();
    }
    return _buildDesktopLayout();
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      body: Column(
        children: [
          const WindowTitleBar(),
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
    return Scaffold(
      body: _buildCurrentPage(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex > 1 ? 0 : _currentIndex,
        onTap: (index) {
          if (index == 0) _onNavItemSelected(0);
          if (index == 1) _onNavItemSelected(1);
          if (index == 2) _onNavItemSelected(4);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/room-scanner'),
        child: const Icon(Icons.qr_code_scanner_rounded),
      ),
    );
  }
}

// ─── Dashboard Content ──────────────────────────────────────
class _DashboardContent extends StatelessWidget {
  final VoidCallback onRefresh;
  final VoidCallback onHistoryTap;

  const _DashboardContent({
    required this.onRefresh,
    required this.onHistoryTap,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header ─────────────────────────
            _buildHeader(context),
            const SizedBox(height: 28),
            // ─── Stat Cards ─────────────────────
            _buildStatCards(context),
            const SizedBox(height: 28),
            // ─── Quick Actions + Today Status ───
            _buildMainContent(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final name = auth.user?.fullName ?? 'Teacher';
        final greeting = _getGreeting();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting, $name 👋',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.02),
                const SizedBox(height: 4),
                Text(
                  _getDateString(),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ).animate().fadeIn(delay: 200.ms),
              ],
            ),
            Row(
              children: [
                _HeaderAction(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Refresh',
                  onTap: onRefresh,
                ),
                const SizedBox(width: 8),
                _HeaderAction(
                  icon: Icons.notifications_outlined,
                  tooltip: 'Notifications',
                  onTap: () {},
                  badge: 3,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCards(BuildContext context) {
    return Consumer<AttendanceProvider>(
      builder: (context, attendance, _) {
        final stats = attendance.stats;
        return GridView.count(
          crossAxisCount: ResponsiveLayout.isDesktop(context) ? 4 : 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: ResponsiveLayout.isDesktop(context) ? 1.6 : 1.4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            StatsCard(
              title: 'Total Present',
              value: '${stats?.presentDays ?? 0}',
              icon: Icons.check_circle_rounded,
              iconColor: AppTheme.successColor,
            ).animate().fadeIn(delay: 300.ms).scale(begin: const Offset(0.95, 0.95)),
            StatsCard(
              title: 'Total Late',
              value: '${stats?.lateDays ?? 0}',
              icon: Icons.access_time_rounded,
              iconColor: AppTheme.warningColor,
            ).animate().fadeIn(delay: 400.ms).scale(begin: const Offset(0.95, 0.95)),
            StatsCard(
              title: 'Total Absent',
              value: '${stats?.absentDays ?? 0}',
              icon: Icons.cancel_rounded,
              iconColor: AppTheme.errorColor,
            ).animate().fadeIn(delay: 500.ms).scale(begin: const Offset(0.95, 0.95)),
            StatsCard(
              title: 'Attendance Rate',
              value: _calcRate(stats),
              icon: Icons.trending_up_rounded,
              iconColor: AppTheme.secondaryColor,
            ).animate().fadeIn(delay: 600.ms).scale(begin: const Offset(0.95, 0.95)),
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
            child: _QuickActionsPanel(onHistoryTap: onHistoryTap),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 4,
            child: _TodayStatusPanel(),
          ),
        ],
      );
    }

    return Column(
      children: [
        _QuickActionsPanel(onHistoryTap: onHistoryTap),
        const SizedBox(height: 20),
        _TodayStatusPanel(),
      ],
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _getDateString() {
    final now = DateTime.now();
    final months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[now.weekday - 1]}, ${months[now.month]} ${now.day}, ${now.year}';
  }

  String _calcRate(AttendanceStats? stats) {
    if (stats == null) return '0%';
    return '${stats.attendancePercentage.toStringAsFixed(0)}%';
  }
}

// ─── Quick Actions Panel ────────────────────────────────────
class _QuickActionsPanel extends StatelessWidget {
  final VoidCallback onHistoryTap;

  const _QuickActionsPanel({required this.onHistoryTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
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
                label: 'Room Scanner',
                color: AppTheme.primaryColor,
                onTap: () => Navigator.pushNamed(context, '/room-scanner'),
              ),
              _ActionTile(
                icon: Icons.group_add_rounded,
                label: 'Batch Register',
                color: AppTheme.secondaryColor,
                onTap: () => Navigator.pushNamed(context, '/batch-registration'),
              ), 
              // AMA FUTURA 
              // _ActionTile(
              //   icon: Icons.assignment_rounded,
              //   label: 'Exam Proctor',
              //   color: AppTheme.accentColor,
              //   onTap: () => Navigator.pushNamed(context, '/exam-proctor'),
              // ),
              _ActionTile(
                icon: Icons.edit_note_rounded,
                label: 'Edit Attendance',
                color: AppTheme.infoColor,
                onTap: () => Navigator.pushNamed(context, '/admin/attendance'),
              ),
              _ActionTile(
                icon: Icons.class_rounded,
                label: 'Manage Classes',
                color: Colors.amber,
                onTap: () => Navigator.pushNamed(context, '/admin/classes'),
              ),
              _ActionTile(
                icon: Icons.history_rounded,
                label: 'Full History',
                color: Colors.purple,
                onTap: onHistoryTap,
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

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
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
          width: 145,
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
                  color: _isHovered ? AppTheme.textPrimary : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Today Status Panel ─────────────────────────────────────
class _TodayStatusPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.cardDecoration(),
      child: Consumer<AttendanceProvider>(
        builder: (context, attendance, _) {
          final todayRecords = attendance.todayAttendance;
          final todayRecord = todayRecords.isNotEmpty ? todayRecords.first : null;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Today's Status",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              if (todayRecord != null)
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
                      const Text(
                        'No attendance recorded today',
                        style: TextStyle(
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

// ─── Header Action Button ───────────────────────────────────
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
                  child: Icon(widget.icon, color: AppTheme.textSecondary, size: 20),
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
