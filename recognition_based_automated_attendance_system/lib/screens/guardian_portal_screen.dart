import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../localization/localization_extensions.dart';
import '../models/attendance_model.dart';
import '../models/class_model.dart';
import '../providers/attendance_provider.dart';
import '../providers/student_management_provider.dart';
import '../widgets/responsive_layout.dart';

class GuardianPortalScreen extends StatefulWidget {
  const GuardianPortalScreen({super.key});

  @override
  State<GuardianPortalScreen> createState() => _GuardianPortalScreenState();
}

class _GuardianPortalScreenState extends State<GuardianPortalScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<AttendanceProvider>().fetchTodayAttendance();
      context.read<StudentManagementProvider>().fetchClasses();
    });
  }

  @override
  Widget build(BuildContext context) {
    final padding = ResponsiveLayout.pagePadding(
      context,
      compact: 12,
      mobile: 16,
      tablet: 20,
      desktop: 24,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('guardianPortal')),
        actions: [
          IconButton(
            tooltip: context.tr('refresh'),
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              context.read<AttendanceProvider>().fetchTodayAttendance();
              context.read<StudentManagementProvider>().fetchClasses();
            },
          ),
        ],
      ),
      body: Consumer2<AttendanceProvider, StudentManagementProvider>(
        builder: (context, attendance, studentManagement, _) {
          final children = _buildPreviewChildren(
            context,
            attendance.todayAttendance,
            studentManagement.classes,
          );
          final alertCount = children.fold<int>(
            0,
            (sum, child) => sum + child.alertCount,
          );
          final confirmedCount = children
              .where((child) => child.status != 'absent')
              .length;
          final upcomingCount = studentManagement.classes
              .where(
                (classObj) => classObj.startTime?.trim().isNotEmpty == true,
              )
              .length;
          final isWide = ResponsiveLayout.width(context) >= 1120;

          return Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.bgBase,
                        AppTheme.bgDeep.withValues(alpha: 0.95),
                        AppTheme.bgCard.withValues(alpha: 0.82),
                      ],
                    ),
                  ),
                ),
              ),
              SingleChildScrollView(
                padding: padding,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: ResponsiveLayout.contentMaxWidth(context),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _GuardianHero(
                          linkedLearners: children.length,
                          alertCount: alertCount,
                          confirmedCount: confirmedCount,
                          upcomingCount: upcomingCount,
                        ),
                        const SizedBox(height: 20),
                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 6,
                                child: _LearnerOverviewPanel(
                                  children: children,
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                flex: 4,
                                child: _GuardianFeedPanel(
                                  children: children,
                                  classes: studentManagement.classes,
                                ),
                              ),
                            ],
                          )
                        else ...[
                          _LearnerOverviewPanel(children: children),
                          const SizedBox(height: 20),
                          _GuardianFeedPanel(
                            children: children,
                            classes: studentManagement.classes,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<_GuardianPreviewChild> _buildPreviewChildren(
    BuildContext context,
    List<Attendance> attendance,
    List<ClassModel> classes,
  ) {
    final children = <_GuardianPreviewChild>[];
    final seen = <String>{};

    for (final record in attendance) {
      final name = record.displayName.trim();
      ClassModel? classMatch;
      for (final item in classes) {
        if (item.id == record.classId) {
          classMatch = item;
          break;
        }
      }
      final classLabel = record.className?.trim().isNotEmpty == true
          ? record.className!.trim()
          : classMatch?.name ?? context.t('Class Name');
      final key = '$name|$classLabel';
      if (seen.contains(key) || name.isEmpty || name == 'Unknown') {
        continue;
      }
      seen.add(key);

      final attendanceRate = switch (record.status) {
        'present' => 0.96,
        'late' => 0.82,
        'half_day' => 0.74,
        'absent' => 0.58,
        _ => 0.8,
      };

      final alertCount = switch (record.status) {
        'absent' => 2,
        'late' => 1,
        _ => 0,
      };

      children.add(
        _GuardianPreviewChild(
          name: name,
          classLabel: classLabel,
          status: record.status,
          statusLabel: context.t(record.statusDisplay),
          roomLabel: classMatch?.room?.trim().isNotEmpty == true
              ? classMatch!.room!.trim()
              : (record.location?.trim().isNotEmpty == true
                    ? record.location!.trim()
                    : context.t('Room not assigned')),
          checkInLabel: record.checkInTime == null
              ? '--'
              : DateFormat('HH:mm').format(record.checkInTime!.toLocal()),
          scheduleLabel: _scheduleLabel(context, classMatch),
          attendanceRate: attendanceRate,
          alertCount: alertCount,
          confidenceLabel: record.confidence == null
              ? 'N/A'
              : '${(record.confidence! * 100).toStringAsFixed(0)}%',
        ),
      );
    }

    return children.take(4).toList();
  }

  String _scheduleLabel(BuildContext context, ClassModel? classObj) {
    if (classObj == null) {
      return context.tr('guardianPortalPreview');
    }

    final meetingDays = classObj.meetingDays.take(2).map(context.t).join(' • ');
    final start = classObj.startTime?.trim();
    final end = classObj.endTime?.trim();
    final timeRange =
        start != null && start.isNotEmpty && end != null && end.isNotEmpty
        ? '$start - $end'
        : context.t('Start Time');

    if (meetingDays.isEmpty) {
      return timeRange;
    }
    return '$meetingDays • $timeRange';
  }
}

class _GuardianHero extends StatelessWidget {
  final int linkedLearners;
  final int alertCount;
  final int confirmedCount;
  final int upcomingCount;

  const _GuardianHero({
    required this.linkedLearners,
    required this.alertCount,
    required this.confirmedCount,
    required this.upcomingCount,
  });

  @override
  Widget build(BuildContext context) {
    final stats = <_GuardianStat>[
      _GuardianStat(
        label: context.tr('linkedLearners'),
        value: '$linkedLearners',
        color: AppTheme.primaryColor,
        icon: Icons.people_alt_rounded,
      ),
      _GuardianStat(
        label: context.tr('familyAlerts'),
        value: '$alertCount',
        color: AppTheme.warningColor,
        icon: Icons.notifications_active_rounded,
      ),
      _GuardianStat(
        label: context.tr('attendanceConfirmed'),
        value: '$confirmedCount',
        color: AppTheme.successColor,
        icon: Icons.verified_rounded,
      ),
      _GuardianStat(
        label: context.tr('upcomingSessions'),
        value: '$upcomingCount',
        color: AppTheme.secondaryColor,
        icon: Icons.schedule_rounded,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.cardDecoration().copyWith(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.16),
            AppTheme.secondaryColor.withValues(alpha: 0.12),
            AppTheme.bgCard,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            runSpacing: 14,
            spacing: 14,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('guardianPortalPreview'),
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      context.tr('guardianPortalDescription'),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.bgElevated,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.glassBorder, width: 0.7),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.family_restroom_rounded,
                        color: AppTheme.primaryLight,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.tr('portalPreviewBanner'),
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: stats
                .map((stat) => _GuardianStatChip(stat: stat))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _LearnerOverviewPanel extends StatelessWidget {
  final List<_GuardianPreviewChild> children;

  const _LearnerOverviewPanel({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('linkedLearners'),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('guardianPortalDescription'),
            style: const TextStyle(color: AppTheme.textSecondary, height: 1.45),
          ),
          const SizedBox(height: 18),
          if (children.isEmpty)
            _GuardianEmptyState(
              icon: Icons.family_restroom_outlined,
              title: context.tr('guardianPortalEmpty'),
            )
          else
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: children
                  .map(
                    (child) => SizedBox(
                      width: 300,
                      child: _GuardianChildCard(child: child),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _GuardianFeedPanel extends StatelessWidget {
  final List<_GuardianPreviewChild> children;
  final List<ClassModel> classes;

  const _GuardianFeedPanel({required this.children, required this.classes});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('attendanceFeed'),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('socketReadyFallback'),
            style: const TextStyle(color: AppTheme.textSecondary, height: 1.45),
          ),
          const SizedBox(height: 18),
          if (children.isEmpty)
            _GuardianEmptyState(
              icon: Icons.timeline_rounded,
              title: context.tr('guardianPortalEmpty'),
            )
          else ...[
            ...children.map(
              (child) => _FeedTile(
                title: child.name,
                subtitle: '${child.statusLabel} • ${child.classLabel}',
                trailing: child.checkInLabel,
                color: _statusColor(child.status),
              ),
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Text(
              context.tr('upcomingSessions'),
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            ...classes
                .take(4)
                .map(
                  (classObj) => _FeedTile(
                    title: classObj.name,
                    subtitle: [
                      if (classObj.room?.trim().isNotEmpty == true)
                        classObj.room!.trim(),
                      if (classObj.meetingDays.isNotEmpty)
                        classObj.meetingDays.take(2).map(context.t).join(' • '),
                    ].join(' • '),
                    trailing: classObj.startTime?.trim().isNotEmpty == true
                        ? classObj.startTime!.trim()
                        : '--',
                    color: AppTheme.secondaryColor,
                  ),
                ),
          ],
        ],
      ),
    );
  }

  static Color _statusColor(String status) {
    return switch (status) {
      'present' => AppTheme.successColor,
      'late' => AppTheme.warningColor,
      'absent' => AppTheme.errorColor,
      _ => AppTheme.primaryColor,
    };
  }
}

class _GuardianChildCard extends StatelessWidget {
  final _GuardianPreviewChild child;

  const _GuardianChildCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final statusColor = _GuardianFeedPanel._statusColor(child.status);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.bgElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.28),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: statusColor.withValues(alpha: 0.16),
                child: Text(
                  child.name.isNotEmpty ? child.name[0] : '?',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child.name,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      child.classLabel,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              child.statusLabel,
              style: TextStyle(color: statusColor, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: child.attendanceRate,
              backgroundColor: AppTheme.glassBorder,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(child.attendanceRate * 100).toStringAsFixed(0)}%',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          _DetailRow(label: context.t('Room'), value: child.roomLabel),
          _DetailRow(label: context.t('Time'), value: child.checkInLabel),
          _DetailRow(
            label: context.tr('upcomingSessions'),
            value: child.scheduleLabel,
          ),
          _DetailRow(
            label: context.t('Confidence'),
            value: child.confidenceLabel,
          ),
          if (child.alertCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                '${context.tr('familyAlerts')}: ${child.alertCount}',
                style: const TextStyle(
                  color: AppTheme.warningColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GuardianStatChip extends StatelessWidget {
  final _GuardianStat stat;

  const _GuardianStatChip({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.glassBorder, width: 0.7),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: stat.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(stat.icon, color: stat.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stat.value,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  stat.label,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    height: 1.3,
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

class _FeedTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String trailing;
  final Color color;

  const _FeedTile({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.glassBorder, width: 0.7),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            trailing,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GuardianEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;

  const _GuardianEmptyState({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.glassBorder, width: 0.7),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.textSecondary, size: 38),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuardianStat {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _GuardianStat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
}

class _GuardianPreviewChild {
  final String name;
  final String classLabel;
  final String status;
  final String statusLabel;
  final String roomLabel;
  final String checkInLabel;
  final String scheduleLabel;
  final double attendanceRate;
  final int alertCount;
  final String confidenceLabel;

  const _GuardianPreviewChild({
    required this.name,
    required this.classLabel,
    required this.status,
    required this.statusLabel,
    required this.roomLabel,
    required this.checkInLabel,
    required this.scheduleLabel,
    required this.attendanceRate,
    required this.alertCount,
    required this.confidenceLabel,
  });
}
