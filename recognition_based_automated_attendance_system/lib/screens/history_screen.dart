import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../localization/localization_extensions.dart';
import '../providers/auth_provider.dart';
import '../providers/attendance_provider.dart';
import '../widgets/stats_card.dart';

/// History Screen — Desktop data table + filter bar
class HistoryScreen extends StatefulWidget {
  final bool embedded;

  const HistoryScreen({super.key, this.embedded = false});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTimeRange? _selectedDateRange;
  String _filterStatus = 'All';

  String t(String text, {Map<String, String> params = const {}}) =>
      context.t(text, params: params);

  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    final authProvider = context.read<AuthProvider>();
    final attendanceProvider = context.read<AttendanceProvider>();

    if (authProvider.user != null) {
      attendanceProvider.fetchHistory(
        userId: authProvider.user!.id,
        startDate: _selectedDateRange?.start,
        endDate: _selectedDateRange?.end,
      );
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryColor,
              surface: AppTheme.bgCard,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDateRange = picked);
      _loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent();

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text(t('Attendance History')),
              leading: _isDesktop
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => Navigator.of(context).maybePop(),
                    )
                  : null,
            ),
      body: content,
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              t('Attendance History'),
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
                letterSpacing: -0.3,
              ),
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 4),
            Text(
              t('View and filter your past attendance records'),
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ).animate().fadeIn(delay: 150.ms),
            const SizedBox(height: 24),

            // Filter Bar
            _buildFilterBar(),
            const SizedBox(height: 24),

            // Records
            _buildRecords(),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(borderRadius: 14),
      child: Row(
        children: [
          // Date Range Picker
          _FilterChip(
            icon: Icons.calendar_today_rounded,
            label: _selectedDateRange != null
                ? '${DateFormat('MMM d').format(_selectedDateRange!.start)} - ${DateFormat('MMM d').format(_selectedDateRange!.end)}'
                : t('All Dates'),
            isActive: _selectedDateRange != null,
            onTap: _pickDateRange,
          ),
          const SizedBox(width: 10),
          // Status Filter
          ...['All', 'Present', 'Late', 'Absent'].map((status) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _FilterChip(
                label: status,
                isActive: _filterStatus == status,
                onTap: () {
                  setState(() => _filterStatus = status);
                },
              ),
            );
          }),
          const Spacer(),
          if (_selectedDateRange != null || _filterStatus != 'All')
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDateRange = null;
                    _filterStatus = 'All';
                  });
                  _loadHistory();
                },
                child: Row(
                  children: [
                    const Icon(
                      Icons.clear_rounded,
                      color: AppTheme.textMuted,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      t('Clear Filters'),
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildRecords() {
    return Consumer<AttendanceProvider>(
      builder: (context, attendance, _) {
        if (attendance.isLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            ),
          );
        }

        var records = attendance.history;

        // Apply status filter
        if (_filterStatus != 'All') {
          records = records
              .where(
                (r) => r.status.toLowerCase() == _filterStatus.toLowerCase(),
              )
              .toList();
        }

        if (records.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(48),
            decoration: AppTheme.cardDecoration(),
            child: Column(
              children: [
                Icon(
                  attendance.error != null
                      ? Icons.error_outline_rounded
                      : Icons.event_busy_rounded,
                  color: attendance.error != null
                      ? AppTheme.errorColor
                      : AppTheme.textMuted,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  attendance.error != null
                      ? t('Failed to load history')
                      : t('No records found'),
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  attendance.error ?? t('Try adjusting your filters'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textMuted,
                  ),
                ),
                if (attendance.error != null) ...[
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _loadHistory,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(t('Retry')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        // Desktop — Data Table
        if (_isDesktop) {
          return Container(
            decoration: AppTheme.cardDecoration(),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStatePropertyAll(AppTheme.bgElevated),
                  dataRowColor: WidgetStatePropertyAll(Colors.transparent),
                  columns: [
                    DataColumn(
                      label: Text(
                        t('Date'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        t('Day'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        t('Status'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        t('Time'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        t('Confidence'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                  rows: records.map((record) {
                    Color statusColor;
                    switch (record.status.toLowerCase()) {
                      case 'present':
                        statusColor = AppTheme.successColor;
                        break;
                      case 'late':
                        statusColor = AppTheme.warningColor;
                        break;
                      case 'absent':
                        statusColor = AppTheme.errorColor;
                        break;
                      default:
                        statusColor = AppTheme.textSecondary;
                    }

                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            DateFormat('MMM d, yyyy').format(record.date),
                            style: const TextStyle(color: AppTheme.textPrimary),
                          ),
                        ),
                        DataCell(
                          Text(
                            DateFormat('EEEE').format(record.date),
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              t(record.statusDisplay),
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            record.formattedTime,
                            style: const TextStyle(color: AppTheme.textPrimary),
                          ),
                        ),
                        DataCell(
                          Text(
                            record.confidence != null
                                ? '${(record.confidence! * 100).toStringAsFixed(0)}%'
                                : '—',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ).animate().fadeIn(delay: 300.ms);
        }

        // Mobile — Card List
        return Column(
          children: records.map((record) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AttendanceStatusCard(
                status: record.status,
                time: record.formattedTime,
                confidence: record.confidence,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ─── Filter Chip ────────────────────────────────────────────
class _FilterChip extends StatefulWidget {
  final String label;
  final IconData? icon;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isActive
                ? AppTheme.primaryColor.withValues(alpha: 0.15)
                : _isHovered
                ? AppTheme.glassHighlight
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isActive
                  ? AppTheme.primaryColor.withValues(alpha: 0.3)
                  : AppTheme.glassBorder,
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: 14,
                  color: widget.isActive
                      ? AppTheme.primaryLight
                      : AppTheme.textSecondary,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                context.t(widget.label),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: widget.isActive
                      ? FontWeight.w600
                      : FontWeight.w400,
                  color: widget.isActive
                      ? AppTheme.primaryLight
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
