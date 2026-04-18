import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../config/app_theme.dart';
import '../localization/localization_extensions.dart';
import '../models/attendance_model.dart';
import '../models/class_model.dart';
import '../models/leave_request_model.dart';
import '../providers/attendance_provider.dart';
import '../services/api_service.dart';
import '../widgets/responsive_layout.dart';

class StudentProfileScreen extends StatefulWidget {
  final ClassModel classObj;
  final Student student;

  const StudentProfileScreen({
    super.key,
    required this.classObj,
    required this.student,
  });

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  final ApiService _api = ApiService();

  bool _isLoading = true;
  bool _isExporting = false;
  String? _error;
  List<Attendance> _attendanceRecords = [];
  List<LeaveRequest> _leaveHistory = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final attendance = await _loadAttendanceHistory();
      final leaves = await _loadLeaveHistory();

      if (!mounted) {
        return;
      }

      setState(() {
        _attendanceRecords = attendance;
        _leaveHistory = leaves;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<List<Attendance>> _loadAttendanceHistory() async {
    final recordsById = <int, Attendance>{};
    final linkedUserId = widget.student.linkedUserId;

    if (linkedUserId != null) {
      var page = 1;
      while (true) {
        final response = await _api.get(
          ApiConfig.attendanceHistory,
          queryParameters: {
            'user_id': linkedUserId,
            'page': page,
            'page_size': 200,
          },
        );

        final paginated = PaginatedAttendance.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );

        for (final record in paginated.items) {
          recordsById[record.id] = record;
        }

        if (page >= paginated.totalPages) {
          break;
        }
        page += 1;
      }
    }

    final classResponse = await _api.get(
      ApiConfig.classAttendance(widget.classObj.id),
    );
    final classRecords = (classResponse.data as List)
        .map((json) => Attendance.fromJson(json))
        .where(
          (record) =>
              record.studentId == widget.student.id ||
              (linkedUserId != null && record.userId == linkedUserId),
        )
        .toList();

    for (final record in classRecords) {
      recordsById[record.id] = record;
    }

    final records = recordsById.values.toList()
      ..sort(
        (a, b) => (b.checkInTime ?? b.date).compareTo(a.checkInTime ?? a.date),
      );
    return records;
  }

  Future<List<LeaveRequest>> _loadLeaveHistory() async {
    final response = await _api.get(
      ApiConfig.leaveRequests,
      queryParameters: {
        'student_id': widget.student.id,
        if (widget.student.linkedUserId != null)
          'user_id': widget.student.linkedUserId,
      },
    );

    final leaves =
        (response.data as List)
            .map((json) => LeaveRequest.fromJson(json))
            .toList()
          ..sort((a, b) => b.leaveDate.compareTo(a.leaveDate));
    return leaves;
  }

  Future<void> _exportAttendance() async {
    final tRead = context.tRead;
    final linkedUserId = widget.student.linkedUserId;
    if (linkedUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tRead('This student does not have a linked account yet.'),
          ),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    setState(() {
      _isExporting = true;
    });

    final path = await context.read<AttendanceProvider>().exportAttendance(
      userId: linkedUserId,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isExporting = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          path == null
              ? tRead('Failed to export attendance report')
              : tRead(
                  'Attendance report saved to {path}',
                  params: {'path': path},
                ),
        ),
        backgroundColor: path == null
            ? AppTheme.errorColor
            : AppTheme.successColor,
      ),
    );
  }

  int get _presentCount =>
      _attendanceRecords.where((record) => record.status == 'present').length;

  int get _lateCount =>
      _attendanceRecords.where((record) => record.status == 'late').length;

  int get _absentCount =>
      _attendanceRecords.where((record) => record.status == 'absent').length;

  int get _attendanceTotal => _attendanceRecords.length;

  String get _attendanceRate {
    if (_attendanceTotal == 0) {
      return '0%';
    }

    final attended = _presentCount + _lateCount;
    final percent = (attended / _attendanceTotal) * 100;
    return '${percent.toStringAsFixed(0)}%';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('Student Profile')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: context.t('Refresh'),
            onPressed: _loadData,
          ),
          IconButton(
            icon: _isExporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded),
            tooltip: context.t('Export Attendance CSV'),
            onPressed: _isExporting ? null : _exportAttendance,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _ErrorState(message: _error!, onRetry: _loadData)
            : SingleChildScrollView(
                padding: ResponsiveLayout.pagePadding(context),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: ResponsiveLayout.contentMaxWidth(context),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeaderCard(context),
                        const SizedBox(height: 20),
                        _buildSummaryGrid(context),
                        const SizedBox(height: 20),
                        _buildAttendanceSection(context),
                        const SizedBox(height: 20),
                        _buildLeaveSection(context),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    final createdAt = DateFormat(
      'MMM d, yyyy',
    ).format(widget.student.createdAt);
    final linkedUser =
        widget.student.linkedUserId?.toString() ?? context.t('Not provided');

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(ResponsiveLayout.isMobile(context) ? 20 : 24),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (compact) ...[
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppTheme.primaryColor.withValues(
                        alpha: 0.12,
                      ),
                      child: Text(
                        widget.student.name.isNotEmpty
                            ? widget.student.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!compact) ...[
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: AppTheme.primaryColor.withValues(
                            alpha: 0.12,
                          ),
                          child: Text(
                            widget.student.name.isNotEmpty
                                ? widget.student.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.student.name,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.classObj.name,
                              style: const TextStyle(
                                fontSize: 15,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            if (widget.classObj.scheduleSummary.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                widget.classObj.scheduleSummary,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _InfoChip(
                icon: widget.student.hasRegisteredFace
                    ? Icons.check_circle_rounded
                    : Icons.warning_amber_rounded,
                label: widget.student.hasRegisteredFace
                    ? context.t('Face Registered')
                    : context.t('No Face Data'),
                color: widget.student.hasRegisteredFace
                    ? AppTheme.successColor
                    : AppTheme.warningColor,
              ),
              _InfoChip(
                icon: Icons.badge_rounded,
                label: context.t(
                  'Student ID: {id}',
                  params: {'id': '${widget.student.id}'},
                ),
                color: AppTheme.infoColor,
              ),
              _InfoChip(
                icon: Icons.link_rounded,
                label: context.t(
                  'Linked Account: {id}',
                  params: {'id': linkedUser},
                ),
                color: AppTheme.primaryColor,
              ),
              _InfoChip(
                icon: Icons.event_available_rounded,
                label: context.t('Joined: {date}', params: {'date': createdAt}),
                color: Colors.teal,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid(BuildContext context) {
    final columns = ResponsiveLayout.gridColumns(
      context,
      compact: 1,
      mobile: 2,
      tablet: 2,
      desktop: 4,
      wide: 4,
    );

    return GridView.count(
      crossAxisCount: columns,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: columns == 1 ? 2.8 : 1.8,
      children: [
        _MetricTile(
          label: context.t('Present'),
          value: '$_presentCount',
          color: AppTheme.successColor,
          icon: Icons.check_circle_rounded,
        ),
        _MetricTile(
          label: context.t('Late'),
          value: '$_lateCount',
          color: AppTheme.warningColor,
          icon: Icons.access_time_rounded,
        ),
        _MetricTile(
          label: context.t('Absent'),
          value: '$_absentCount',
          color: AppTheme.errorColor,
          icon: Icons.cancel_rounded,
        ),
        _MetricTile(
          label: context.tr('attendanceRate'),
          value: _attendanceRate,
          color: AppTheme.secondaryColor,
          icon: Icons.trending_up_rounded,
        ),
      ],
    );
  }

  Widget _buildAttendanceSection(BuildContext context) {
    return _SectionCard(
      title: context.t('Attendance History'),
      subtitle: context.t(
        'Full attendance records for this student across all available dates.',
      ),
      child: _attendanceRecords.isEmpty
          ? _EmptySection(message: context.t('No attendance records found'))
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _attendanceRecords.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final record = _attendanceRecords[index];
                return _AttendanceHistoryCard(attendance: record);
              },
            ),
    );
  }

  Widget _buildLeaveSection(BuildContext context) {
    return _SectionCard(
      title: context.t('Leave Requests'),
      subtitle: context.t(
        'Review pending, approved, and rejected leave requests for this student.',
      ),
      child: _leaveHistory.isEmpty
          ? _EmptySection(message: context.t('No leave requests found'))
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _leaveHistory.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final leave = _leaveHistory[index];
                return _LeaveHistoryCard(leave: leave);
              },
            ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(ResponsiveLayout.isMobile(context) ? 20 : 24),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _AttendanceHistoryCard extends StatelessWidget {
  final Attendance attendance;

  const _AttendanceHistoryCard({required this.attendance});

  Color get _statusColor {
    switch (attendance.status) {
      case 'present':
        return AppTheme.successColor;
      case 'late':
        return AppTheme.warningColor;
      case 'absent':
        return AppTheme.errorColor;
      default:
        return AppTheme.infoColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('EEE, MMM d, yyyy').format(attendance.date);
    final method = attendance.method.replaceAll('_', ' ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgElevated,
        borderRadius: BorderRadius.circular(14),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (constraints.maxWidth < 380) ...[
              Text(
                dateLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              _StatusBadge(
                label: context.t(attendance.statusDisplay),
                color: _statusColor,
              ),
            ] else
              Row(
                children: [
                  Expanded(
                    child: Text(
                      dateLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  _StatusBadge(
                    label: context.t(attendance.statusDisplay),
                    color: _statusColor,
                  ),
                ],
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _MetaText(
                  icon: Icons.access_time_rounded,
                  text: attendance.formattedTime,
                ),
                _MetaText(
                  icon: Icons.touch_app_rounded,
                  text: toBeginningOfSentenceCase(method) ?? method,
                ),
                if ((attendance.className ?? '').trim().isNotEmpty)
                  _MetaText(
                    icon: Icons.class_rounded,
                    text: attendance.className!,
                  ),
              ],
            ),
            if ((attendance.notes ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                attendance.notes!,
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LeaveHistoryCard extends StatelessWidget {
  final LeaveRequest leave;

  const _LeaveHistoryCard({required this.leave});

  Color get _statusColor {
    if (leave.isApproved) {
      return AppTheme.successColor;
    }
    if (leave.isRejected) {
      return AppTheme.errorColor;
    }
    return AppTheme.warningColor;
  }

  @override
  Widget build(BuildContext context) {
    final leaveDate = DateFormat('EEE, MMM d, yyyy').format(leave.leaveDate);
    final submittedAt = DateFormat('MMM d, yyyy').format(leave.createdAt);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgElevated,
        borderRadius: BorderRadius.circular(14),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (constraints.maxWidth < 380) ...[
              Text(
                leaveDate,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              _StatusBadge(
                label: context.t(leave.statusDisplay),
                color: _statusColor,
              ),
            ] else
              Row(
                children: [
                  Expanded(
                    child: Text(
                      leaveDate,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  _StatusBadge(
                    label: context.t(leave.statusDisplay),
                    color: _statusColor,
                  ),
                ],
              ),
            const SizedBox(height: 10),
            Text(
              leave.reason,
              style: const TextStyle(color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _MetaText(
                  icon: Icons.schedule_rounded,
                  text: context.t(
                    'Submitted: {date}',
                    params: {'date': submittedAt},
                  ),
                ),
                if ((leave.reviewedByName ?? '').trim().isNotEmpty)
                  _MetaText(
                    icon: Icons.verified_user_rounded,
                    text:
                        '${context.t('Reviewed by')}: ${leave.reviewedByName!}',
                  ),
              ],
            ),
            if ((leave.reviewNote ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                context.t(
                  'Review note: {note}',
                  params: {'note': leave.reviewNote!},
                ),
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaText({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppTheme.textMuted),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: AppTheme.textSecondary)),
      ],
    );
  }
}

class _EmptySection extends StatelessWidget {
  final String message;

  const _EmptySection({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.bgElevated,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppTheme.textSecondary),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppTheme.errorColor,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.t('Retry')),
            ),
          ],
        ),
      ),
    );
  }
}
