import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../config/app_theme.dart';
import '../../providers/attendance_provider.dart';
import '../../widgets/custom_button.dart';

/// Admin Reports Screen
class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String _reportType = 'summary';
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Report Type Selection
            const Text(
              'Select Report Type',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _buildReportTypeCard(
              'summary',
              'Attendance Summary',
              'Overview of attendance statistics',
              Icons.pie_chart,
            ),
            const SizedBox(height: 12),
            _buildReportTypeCard(
              'detailed',
              'Detailed Report',
              'Complete attendance records with timestamps',
              Icons.list_alt,
            ),
            const SizedBox(height: 12),
            _buildReportTypeCard(
              'absent',
              'Absent Report',
              'List of absent students/teachers',
              Icons.person_off,
            ),
            const SizedBox(height: 24),

            // Date Range Selection
            const Text(
              'Select Date Range',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDateSelector(
                    'Start Date',
                    _startDate,
                    (date) => setState(() => _startDate = date),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDateSelector(
                    'End Date',
                    _endDate,
                    (date) => setState(() => _endDate = date),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Generate Button
            CustomButton(
              text: 'Generate Report',
              isLoading: _isGenerating,
              onPressed: _generateReport,
              icon: Icons.download,
            ),
            const SizedBox(height: 24),

            // Quick Reports
            const Text(
              'Quick Reports',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildQuickReportCard(
                    'Today',
                    Icons.today,
                    () => _generateQuickReport(0),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickReportCard(
                    'This Week',
                    Icons.view_week,
                    () => _generateQuickReport(7),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickReportCard(
                    'This Month',
                    Icons.calendar_month,
                    () => _generateQuickReport(30),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportTypeCard(
    String type,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final isSelected = _reportType == type;
    return InkWell(
      onTap: () => setState(() => _reportType = type),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor.withValues(alpha: 0.2)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isSelected ? AppTheme.primaryColor : Colors.grey,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppTheme.primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector(
    String label,
    DateTime date,
    Function(DateTime) onSelect,
  ) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2024),
          lastDate: DateTime.now(),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: AppTheme.primaryColor,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          onSelect(picked);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('MMM d, yyyy').format(date),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickReportCard(
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primaryColor),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateQuickReport(int days) async {
    setState(() {
      _startDate = DateTime.now().subtract(Duration(days: days));
      _endDate = DateTime.now();
    });
    await _generateReport();
  }

  Future<void> _generateReport() async {
    setState(() => _isGenerating = true);

    try {
      final provider = context.read<AttendanceProvider>();
      await provider.fetchHistory(startDate: _startDate, endDate: _endDate);

      final history = provider.history;

      // Generate CSV content
      final buffer = StringBuffer();

      if (_reportType == 'summary') {
        buffer.writeln('Attendance Summary Report');
        buffer.writeln(
          'Period: ${DateFormat('MMM d, yyyy').format(_startDate)} - ${DateFormat('MMM d, yyyy').format(_endDate)}',
        );
        buffer.writeln('');
        buffer.writeln('Status,Count');

        final presentCount = history.where((a) => a.status == 'present').length;
        final lateCount = history.where((a) => a.status == 'late').length;
        final absentCount = history.where((a) => a.status == 'absent').length;

        buffer.writeln('Present,$presentCount');
        buffer.writeln('Late,$lateCount');
        buffer.writeln('Absent,$absentCount');
        buffer.writeln('Total,${history.length}');
      } else if (_reportType == 'detailed') {
        buffer.writeln(
          'Date,Name,Class,Email,Status,Check-In,Check-Out,Confidence',
        );
        for (final record in history) {
          buffer.writeln(
            '${DateFormat('yyyy-MM-dd').format(record.date)},'
            '${_csvCell(record.displayName)},'
            '${_csvCell(record.className ?? record.user?.department ?? "")},'
            '${_csvCell(record.user?.email ?? "")},'
            '${record.status},'
            '${record.checkInTime != null ? DateFormat('HH:mm').format(record.checkInTime!) : ""},'
            '${record.checkOutTime != null ? DateFormat('HH:mm').format(record.checkOutTime!) : ""},'
            '${record.confidence ?? ""}',
          );
        }
      } else {
        buffer.writeln('Absent Report');
        buffer.writeln(
          'Period: ${DateFormat('MMM d, yyyy').format(_startDate)} - ${DateFormat('MMM d, yyyy').format(_endDate)}',
        );
        buffer.writeln('');
        buffer.writeln('Date,Name,Class,Email');
        for (final record in history.where((a) => a.status == 'absent')) {
          buffer.writeln(
            '${DateFormat('yyyy-MM-dd').format(record.date)},'
            '${_csvCell(record.displayName)},'
            '${_csvCell(record.className ?? record.user?.department ?? "")},'
            '${_csvCell(record.user?.email ?? "")}',
          );
        }
      }

      // Save file
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          '${_reportType}_report_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File(path.join(directory.path, fileName));
      await file.writeAsString(buffer.toString());

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Report saved: $fileName'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate report: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    final needsQuotes =
        escaped.contains(',') ||
        escaped.contains('"') ||
        escaped.contains('\n') ||
        escaped.contains('\r');
    return needsQuotes ? '"$escaped"' : escaped;
  }
}
