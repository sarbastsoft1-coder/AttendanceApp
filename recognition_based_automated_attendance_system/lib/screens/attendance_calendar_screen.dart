import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../config/app_theme.dart';
import '../localization/localization_extensions.dart';
import '../models/attendance_model.dart';
import '../providers/auth_provider.dart';
import '../providers/attendance_provider.dart';

/// Attendance Calendar Screen — visual month calendar with color-coded days
class AttendanceCalendarScreen extends StatefulWidget {
  final bool embedded;

  const AttendanceCalendarScreen({super.key, this.embedded = false});

  @override
  State<AttendanceCalendarScreen> createState() =>
      _AttendanceCalendarScreenState();
}

class _AttendanceCalendarScreenState extends State<AttendanceCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  // Map of date-string → attendance record
  final Map<String, Attendance> _attendanceMap = {};
  bool _isLoading = false;

  String t(String text, {Map<String, String> params = const {}}) =>
      context.t(text, params: params);

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _loadMonth(_focusedDay),
    );
  }

  String _dateKey(DateTime dt) => DateFormat('yyyy-MM-dd').format(dt);

  Future<void> _loadMonth(DateTime month) async {
    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final attendanceProvider = context.read<AttendanceProvider>();

    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);

    await attendanceProvider.fetchHistory(
      userId: authProvider.user?.id,
      startDate: firstDay,
      endDate: lastDay,
      page: 1,
    );

    if (mounted) {
      final records = attendanceProvider.history;
      _attendanceMap.clear();
      for (final record in records) {
        final key = _dateKey(record.date);
        _attendanceMap[key] = record;
      }
      setState(() => _isLoading = false);
    }
  }

  Color? _dayColor(DateTime day) {
    final record = _attendanceMap[_dateKey(day)];
    if (record == null) return null;
    switch (record.status) {
      case 'present':
        return AppTheme.successColor;
      case 'late':
        return AppTheme.warningColor;
      case 'absent':
        return AppTheme.errorColor;
      case 'half_day':
        return AppTheme.infoColor;
      default:
        return null;
    }
  }

  Attendance? _selectedAttendance() {
    if (_selectedDay == null) return null;
    return _attendanceMap[_dateKey(_selectedDay!)];
  }

  Widget _buildLegend() {
    final items = [
      ('Present', AppTheme.successColor),
      ('Late', AppTheme.warningColor),
      ('Absent', AppTheme.errorColor),
      ('Half Day', AppTheme.infoColor),
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: items.map((item) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: item.$2, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              t(item.$1),
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildSelectedDayCard(Attendance? attendance) {
    final day = _selectedDay ?? DateTime.now();
    final isWeekend =
        day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.calendar_today_rounded,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, MMMM d, yyyy').format(day),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (isWeekend)
                      Text(
                        t('Weekend'),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppTheme.glassBorder, height: 1),
          const SizedBox(height: 16),
          if (attendance == null) ...[
            Row(
              children: [
                Icon(
                  isWeekend ? Icons.weekend_outlined : Icons.event_busy_rounded,
                  size: 20,
                  color: AppTheme.textMuted,
                ),
                const SizedBox(width: 8),
                Text(
                  isWeekend
                      ? t('No attendance on weekends')
                      : t('No attendance record'),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ] else ...[
            _AttendanceDetailRow(
              icon: Icons.circle,
              label: 'Status',
              value: t(attendance.statusDisplay),
              valueColor: _dayColor(day) ?? AppTheme.textSecondary,
            ),
            const SizedBox(height: 10),
            _AttendanceDetailRow(
              icon: Icons.login_rounded,
              label: 'Check In',
              value: attendance.checkInTime != null
                  ? DateFormat('hh:mm a').format(attendance.checkInTime!)
                  : t('N/A'),
            ),
            if (attendance.checkOutTime != null) ...[
              const SizedBox(height: 10),
              _AttendanceDetailRow(
                icon: Icons.logout_rounded,
                label: 'Check Out',
                value: DateFormat('hh:mm a').format(attendance.checkOutTime!),
              ),
              const SizedBox(height: 10),
              _AttendanceDetailRow(
                icon: Icons.timer_outlined,
                label: 'Duration',
                value: _duration(
                  attendance.checkInTime!,
                  attendance.checkOutTime!,
                ),
              ),
            ],
            const SizedBox(height: 10),
            _AttendanceDetailRow(
              icon: Icons.fingerprint_rounded,
              label: 'Method',
              value: _methodLabel(attendance.method),
            ),
            if (attendance.confidence != null) ...[
              const SizedBox(height: 10),
              _AttendanceDetailRow(
                icon: Icons.bar_chart_rounded,
                label: 'Confidence',
                value: attendance.confidencePercentage,
              ),
            ],
            if (attendance.notes != null && attendance.notes!.isNotEmpty) ...[
              const SizedBox(height: 10),
              _AttendanceDetailRow(
                icon: Icons.notes_rounded,
                label: 'Notes',
                value: attendance.notes!,
              ),
            ],
          ],
        ],
      ),
    );
  }

  String _duration(DateTime checkIn, DateTime checkOut) {
    final diff = checkOut.difference(checkIn);
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  String _methodLabel(String method) {
    switch (method) {
      case 'face':
        return t('Face Recognition');
      case 'manual':
        return t('Manual Entry');
      case 'qr_code':
        return t('QR Code');
      case 'room_scan':
        return t('Room Scan');
      default:
        return method;
    }
  }

  Widget _buildStats() {
    final total = _attendanceMap.length;
    final present = _attendanceMap.values
        .where((a) => a.status == 'present')
        .length;
    final late = _attendanceMap.values.where((a) => a.status == 'late').length;
    final absent = _attendanceMap.values
        .where((a) => a.status == 'absent')
        .length;
    final pct = total > 0 ? ((present + late) / total * 100) : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMMM yyyy').format(_focusedDay),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: pct >= 75
                      ? AppTheme.successColor.withValues(alpha: 0.15)
                      : AppTheme.warningColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${pct.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: pct >= 75
                        ? AppTheme.successColor
                        : AppTheme.warningColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatPill(
                count: present,
                label: 'Present',
                color: AppTheme.successColor,
              ),
              const SizedBox(width: 8),
              _StatPill(
                count: late,
                label: 'Late',
                color: AppTheme.warningColor,
              ),
              const SizedBox(width: 8),
              _StatPill(
                count: absent,
                label: 'Absent',
                color: AppTheme.errorColor,
              ),
              const SizedBox(width: 8),
              _StatPill(
                count: total,
                label: 'Total',
                color: AppTheme.primaryColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent();

    if (widget.embedded) return content;

    return Scaffold(
      appBar: AppBar(
        title: Text(t('Attendance Calendar')),
        actions: [
          IconButton(
            icon: const Icon(Icons.today_rounded),
            tooltip: t('Go to today'),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime.now();
                _selectedDay = DateTime.now();
              });
              _loadMonth(DateTime.now());
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: t('Refresh'),
            onPressed: () => _loadMonth(_focusedDay),
          ),
        ],
      ),
      body: content,
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Calendar
        Container(
          margin: const EdgeInsets.all(12),
          decoration: AppTheme.cardDecoration(),
          child: _isLoading
              ? const SizedBox(
                  height: 340,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                    ),
                  ),
                )
              : TableCalendar(
                  locale: context.language.materialLocale.languageCode,
                  firstDay: DateTime(2024, 1, 1),
                  lastDay: DateTime.now().add(const Duration(days: 365)),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selected, focused) {
                    setState(() {
                      _selectedDay = selected;
                      _focusedDay = focused;
                    });
                  },
                  onFormatChanged: (format) {
                    setState(() => _calendarFormat = format);
                  },
                  onPageChanged: (focusedDay) {
                    _focusedDay = focusedDay;
                    _loadMonth(focusedDay);
                  },
                  calendarStyle: CalendarStyle(
                    outsideDaysVisible: false,
                    defaultTextStyle: const TextStyle(
                      color: AppTheme.textPrimary,
                    ),
                    weekendTextStyle: const TextStyle(
                      color: AppTheme.textSecondary,
                    ),
                    todayDecoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: const BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    todayTextStyle: const TextStyle(
                      color: AppTheme.primaryLight,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: true,
                    titleCentered: true,
                    titleTextStyle: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    leftChevronIcon: Icon(
                      Icons.chevron_left,
                      color: AppTheme.textPrimary,
                    ),
                    rightChevronIcon: Icon(
                      Icons.chevron_right,
                      color: AppTheme.textPrimary,
                    ),
                    formatButtonTextStyle: TextStyle(
                      color: AppTheme.primaryLight,
                      fontSize: 12,
                    ),
                    formatButtonDecoration: BoxDecoration(
                      border: Border.fromBorderSide(
                        BorderSide(color: AppTheme.primaryColor, width: 1),
                      ),
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                  ),
                  daysOfWeekStyle: const DaysOfWeekStyle(
                    weekdayStyle: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                    weekendStyle: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, day, focusedDay) {
                      final color = _dayColor(day);
                      if (color == null) return null;
                      return Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: color.withValues(alpha: 0.6),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),

        // Legend
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: _buildLegend(),
        ),

        const SizedBox(height: 4),

        // Scrollable bottom section
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Monthly stats
                _buildStats(),

                // Selected day details
                _buildSelectedDayCard(_selectedAttendance()),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Helper Widgets ──────────────────────────────────────────

class _AttendanceDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _AttendanceDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textMuted),
        const SizedBox(width: 10),
        SizedBox(
          width: 80,
          child: Text(
            context.t(label),
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  final int count;
  final String label;
  final Color color;

  const _StatPill({
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              context.t(label),
              style: const TextStyle(
                fontSize: 10,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
