import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../localization/localization_extensions.dart';
import '../../models/class_model.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/student_management_provider.dart';

class ClassAttendanceScreen extends StatefulWidget {
  final ClassModel classObj;

  const ClassAttendanceScreen({super.key, required this.classObj});

  @override
  State<ClassAttendanceScreen> createState() => _ClassAttendanceScreenState();
}

class _ClassAttendanceScreenState extends State<ClassAttendanceScreen> {
  static const List<String> _statuses = [
    'present',
    'late',
    'absent',
    'half_day',
  ];

  DateTime _selectedDate = DateTime.now();
  final Map<int, String> _statusByStudentId = {};

  String t(String text, {Map<String, String> params = const {}}) =>
      context.t(text, params: params);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final studentProvider = context.read<StudentManagementProvider>();
    final attendanceProvider = context.read<AttendanceProvider>();

    await studentProvider.fetchClassStudents(widget.classObj.id);
    await attendanceProvider.fetchClassAttendance(
      widget.classObj.id,
      date: _selectedDate,
    );

    if (!mounted) {
      return;
    }

    final recordsByStudent = <int, String>{};
    for (final record in attendanceProvider.classAttendance) {
      if (record.studentId != null) {
        recordsByStudent[record.studentId!] = record.status;
      }
    }

    setState(() {
      _statusByStudentId
        ..clear()
        ..addEntries(
          studentProvider.students.map(
            (student) =>
                MapEntry(student.id, recordsByStudent[student.id] ?? 'absent'),
          ),
        );
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) {
      return;
    }
    setState(() => _selectedDate = picked);
    await _loadData();
  }

  void _markAllPresent() {
    final students = context.read<StudentManagementProvider>().students;
    setState(() {
      for (final student in students) {
        _statusByStudentId[student.id] = 'present';
      }
    });
  }

  Future<void> _saveRollCall() async {
    final attendanceProvider = context.read<AttendanceProvider>();
    final students = context.read<StudentManagementProvider>().students;

    final entries = students
        .map(
          (student) => {
            'student_id': student.id,
            'status': _statusByStudentId[student.id] ?? 'absent',
          },
        )
        .toList();

    final success = await attendanceProvider.submitRollCall(
      classId: widget.classObj.id,
      attendanceDate: _selectedDate,
      entries: entries,
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? t(
                  'Roll call saved for {date}',
                  params: {
                    'date': DateFormat('MMM d, yyyy').format(_selectedDate),
                  },
                )
              : (attendanceProvider.error ?? t('Failed to save roll call')),
        ),
        backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
      ),
    );

    if (success) {
      await _loadData();
    }
  }

  Future<void> _exportAttendance() async {
    final provider = context.read<StudentManagementProvider>();
    final result = await provider.exportClassAttendanceCsv(
      classObj: widget.classObj,
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == null
              ? (provider.error ?? t('Failed to export attendance'))
              : t(
                  'Attendance exported to {path}',
                  params: {'path': result.path},
                ),
        ),
        backgroundColor: result == null
            ? AppTheme.errorColor
            : AppTheme.successColor,
      ),
    );
  }

  int _countStatus(String status) {
    return _statusByStudentId.values.where((value) => value == status).length;
  }

  @override
  Widget build(BuildContext context) {
    final students = context.watch<StudentManagementProvider>().students;
    final isLoading =
        context.watch<StudentManagementProvider>().isLoading ||
        context.watch<AttendanceProvider>().isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          t('{name} Attendance', params: {'name': widget.classObj.name}),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range_rounded),
            tooltip: t('Select Date'),
            onPressed: _pickDate,
          ),
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: t('Export Attendance'),
            onPressed: _exportAttendance,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: t('Refresh'),
            onPressed: _loadData,
          ),
        ],
      ),
      body: isLoading && students.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeaderCard(),
                _buildSummaryRow(),
                Expanded(
                  child: students.isEmpty
                      ? Center(
                          child: Text(
                            t('No students found for this class.'),
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: students.length,
                          itemBuilder: (context, index) {
                            final student = students[index];
                            final value =
                                _statusByStudentId[student.id] ?? 'absent';
                            return _StudentAttendanceCard(
                              student: student,
                              value: value,
                              onChanged: (nextValue) {
                                setState(() {
                                  _statusByStudentId[student.id] = nextValue;
                                });
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _markAllPresent,
                icon: const Icon(Icons.done_all_rounded),
                label: Text(t('Mark All Present')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: students.isEmpty ? null : _saveRollCall,
                icon: const Icon(Icons.save_rounded),
                label: Text(t('Save Roll Call')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    final schedule = widget.classObj.scheduleSummary;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.classObj.name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            DateFormat('EEEE, MMM d, yyyy').format(_selectedDate),
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          if (schedule.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              schedule,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _SummaryPill(
            label: 'Present',
            count: _countStatus('present'),
            color: AppTheme.successColor,
          ),
          const SizedBox(width: 8),
          _SummaryPill(
            label: 'Late',
            count: _countStatus('late'),
            color: AppTheme.warningColor,
          ),
          const SizedBox(width: 8),
          _SummaryPill(
            label: 'Absent',
            count: _countStatus('absent'),
            color: AppTheme.errorColor,
          ),
          const SizedBox(width: 8),
          _SummaryPill(
            label: 'Half Day',
            count: _countStatus('half_day'),
            color: AppTheme.infoColor,
          ),
        ],
      ),
    );
  }
}

class _StudentAttendanceCard extends StatelessWidget {
  final Student student;
  final String value;
  final ValueChanged<String> onChanged;

  const _StudentAttendanceCard({
    required this.student,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primaryColor.withValues(
                    alpha: 0.12,
                  ),
                  child: Text(
                    student.name.isNotEmpty
                        ? student.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        student.hasRegisteredFace
                            ? context.t('Face registered')
                            : context.t('No face data'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: value,
              decoration: InputDecoration(
                labelText: context.t('Attendance Status'),
                border: OutlineInputBorder(),
              ),
              items: _ClassAttendanceScreenState._statuses
                  .map(
                    (status) => DropdownMenuItem(
                      value: status,
                      child: Text(_labelForStatus(context, status)),
                    ),
                  )
                  .toList(),
              onChanged: (nextValue) {
                if (nextValue != null) {
                  onChanged(nextValue);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  String _labelForStatus(BuildContext context, String status) {
    switch (status) {
      case 'present':
        return context.t('Present');
      case 'late':
        return context.t('Late');
      case 'absent':
        return context.t('Absent');
      case 'half_day':
        return context.t('Half Day');
      default:
        return context.t(status);
    }
  }
}

class _SummaryPill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SummaryPill({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.24)),
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
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
