import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../localization/localization_extensions.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/student_management_provider.dart';
import '../../models/attendance_model.dart';

/// Admin All Attendance Screen
class AdminAttendanceScreen extends StatefulWidget {
  const AdminAttendanceScreen({super.key});

  @override
  State<AdminAttendanceScreen> createState() => _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends State<AdminAttendanceScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  String _statusFilter = 'all';

  String t(String text, {Map<String, String> params = const {}}) =>
      context.t(text, params: params);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadAttendance();
    });
  }

  void _loadAttendance() {
    final provider = context.read<AttendanceProvider>();
    provider.fetchAllAttendance(startDate: _startDate, endDate: _endDate);
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : DateTimeRange(
              start: DateTime.now().subtract(const Duration(days: 30)),
              end: DateTime.now(),
            ),
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
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadAttendance();
    }
  }

  void _clearFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _statusFilter = 'all';
    });
    _loadAttendance();
  }

  Future<void> _showManualEntryDialog() async {
    final attendanceProvider = context.read<AttendanceProvider>();
    final studentProvider = context.read<StudentManagementProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final language = context.languageRead;

    if (studentProvider.classes.isEmpty) {
      await studentProvider.fetchClasses();
    }
    if (!mounted) return;

    final classes = studentProvider.classes;
    if (classes.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(language.text('No classes available')),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    int? selectedClassId = classes.first.id;
    await studentProvider.fetchClassStudents(selectedClassId);
    if (!mounted) return;

    int? selectedStudentId = studentProvider.students.isNotEmpty
        ? studentProvider.students.first.id
        : null;
    var selectedDate = _endDate ?? DateTime.now();
    var selectedStatus = switch (_statusFilter) {
      'present' => 'present',
      'late' => 'late',
      'absent' => 'absent',
      _ => 'late',
    };
    var isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return Consumer<StudentManagementProvider>(
              builder: (dialogContext, studentsProvider, _) {
                final students = studentsProvider.students
                    .where((student) => student.classId == selectedClassId)
                    .toList();

                return AlertDialog(
                  title: Text(t('Manual Entry')),
                  content: SizedBox(
                    width: 420,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<int>(
                          key: ValueKey('class-$selectedClassId'),
                          initialValue: selectedClassId,
                          decoration: InputDecoration(
                            labelText: t('Select Class'),
                          ),
                          items: classes
                              .map(
                                (classObj) => DropdownMenuItem(
                                  value: classObj.id,
                                  child: Text(classObj.name),
                                ),
                              )
                              .toList(),
                          onChanged: isSaving
                              ? null
                              : (value) async {
                                  if (value == null || value == selectedClassId) {
                                    return;
                                  }
                                  setDialogState(() {
                                    selectedClassId = value;
                                    selectedStudentId = null;
                                  });
                                  await dialogContext
                                      .read<StudentManagementProvider>()
                                      .fetchClassStudents(value);
                                  if (!dialogContext.mounted) return;
                                  setDialogState(() {
                                    final reloadedStudents = dialogContext
                                        .read<StudentManagementProvider>()
                                        .students
                                        .where((student) => student.classId == value)
                                        .toList();
                                    selectedStudentId =
                                        reloadedStudents.isNotEmpty
                                        ? reloadedStudents.first.id
                                        : null;
                                  });
                                },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int>(
                          key: ValueKey(
                            'student-$selectedClassId-$selectedStudentId',
                          ),
                          initialValue: students.any(
                            (student) => student.id == selectedStudentId,
                          )
                              ? selectedStudentId
                              : null,
                          decoration: InputDecoration(
                            labelText: t('Student Name'),
                          ),
                          items: students
                              .map(
                                (student) => DropdownMenuItem(
                                  value: student.id,
                                  child: Text(student.name),
                                ),
                              )
                              .toList(),
                          onChanged: isSaving || students.isEmpty
                              ? null
                              : (value) {
                                  setDialogState(() {
                                    selectedStudentId = value;
                                  });
                                },
                        ),
                        if (students.isEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            t('No students found for this class'),
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          key: ValueKey('status-$selectedStatus'),
                          initialValue: selectedStatus,
                          decoration: InputDecoration(labelText: t('Status')),
                          items: const [
                            DropdownMenuItem(
                              value: 'present',
                              child: Text('Present'),
                            ),
                            DropdownMenuItem(
                              value: 'late',
                              child: Text('Late'),
                            ),
                            DropdownMenuItem(
                              value: 'absent',
                              child: Text('Absent'),
                            ),
                          ],
                          onChanged: isSaving
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  setDialogState(() {
                                    selectedStatus = value;
                                  });
                                },
                        ),
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: isSaving
                              ? null
                              : () async {
                                  final pickedDate = await showDatePicker(
                                    context: dialogContext,
                                    firstDate: DateTime(2024),
                                    lastDate: DateTime.now().add(
                                      const Duration(days: 365),
                                    ),
                                    initialDate: selectedDate,
                                  );
                                  if (pickedDate == null || !dialogContext.mounted) {
                                    return;
                                  }
                                  setDialogState(() {
                                    selectedDate = DateTime(
                                      pickedDate.year,
                                      pickedDate.month,
                                      pickedDate.day,
                                      selectedDate.hour,
                                      selectedDate.minute,
                                    );
                                  });
                                },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: t('Date'),
                              suffixIcon: const Icon(Icons.calendar_today_rounded),
                            ),
                            child: Text(
                              DateFormat('EEEE, MMM d, yyyy').format(selectedDate),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: isSaving
                          ? null
                          : () => Navigator.of(dialogContext).pop(),
                      child: Text(t('Cancel')),
                    ),
                    ElevatedButton.icon(
                      onPressed: isSaving || selectedStudentId == null
                          ? null
                          : () async {
                              setDialogState(() {
                                isSaving = true;
                              });
                              final attendance = await attendanceProvider
                                  .manualAttendance(
                                    studentId: selectedStudentId,
                                    classId: selectedClassId,
                                    status: selectedStatus,
                                    attendanceDate: selectedDate,
                                  );
                              if (!dialogContext.mounted) return;
                              setDialogState(() {
                                isSaving = false;
                              });
                              if (attendance == null) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      attendanceProvider.error ??
                                          language.text('Failed to add attendance'),
                                    ),
                                    backgroundColor: AppTheme.errorColor,
                                  ),
                                );
                                return;
                              }
                              Navigator.of(dialogContext).pop();
                              _loadAttendance();
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    language.text('Attendance saved successfully'),
                                  ),
                                  backgroundColor: AppTheme.successColor,
                                ),
                              );
                            },
                      icon: isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.person_add_alt_1_rounded),
                      label: Text(t('Save')),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('All Attendance')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _selectDateRange,
          ),
          if (_startDate != null || _statusFilter != 'all')
            IconButton(icon: const Icon(Icons.clear), onPressed: _clearFilters),
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: t('Export CSV'),
            onPressed: () => _exportCSV(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAttendance,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showManualEntryDialog,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text(t('Add Person')),
      ),
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.bgElevated,
            child: Column(
              children: [
                // Date Range Display
                if (_startDate != null && _endDate != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.date_range,
                          color: AppTheme.primaryColor,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${DateFormat('MMM d').format(_startDate!)} - ${DateFormat('MMM d, yyyy').format(_endDate!)}',
                          style: const TextStyle(
                            color: AppTheme.primaryDark,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Status Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', 'all'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Present', 'present'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Late', 'late'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Absent', 'absent'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Attendance List
          Expanded(
            child: Consumer<AttendanceProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                var records = provider.allAttendance;

                // Apply status filter
                if (_statusFilter != 'all') {
                  records = records
                      .where((a) => a.status == _statusFilter)
                      .toList();
                }

                if (records.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          t('No attendance records found'),
                          style: TextStyle(
                            fontSize: 16,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        if (_startDate != null || _statusFilter != 'all')
                          TextButton(
                            onPressed: _clearFilters,
                            child: Text(t('Clear filters')),
                          ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _loadAttendance(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: records.length,
                    itemBuilder: (context, index) {
                      return _AttendanceCard(
                        attendance: records[index],
                        onTap: () => _showStatusDialog(context, records[index]),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _statusFilter == value;
    return FilterChip(
      label: Text(t(label)),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _statusFilter = selected ? value : 'all';
        });
      },
      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
      checkmarkColor: AppTheme.primaryColor,
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  void _exportCSV(BuildContext context) async {
    final provider = context.read<AttendanceProvider>();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(t('Preparing CSV report...'))));
    final filePath = await provider.exportAttendance(
      start: _startDate,
      end: _endDate,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            filePath == null
                ? t('Failed to export attendance report')
                : t(
                    'Attendance report saved to {path}',
                    params: {'path': filePath},
                  ),
          ),
          backgroundColor: filePath == null
              ? AppTheme.errorColor
              : AppTheme.successColor,
        ),
      );
    }
  }

  void _showStatusDialog(BuildContext context, Attendance attendance) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('Update Status')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(t('Present')),
              leading: const Icon(
                Icons.check_circle,
                color: AppTheme.successColor,
              ),
              onTap: () => _updateStatus(context, attendance, 'present'),
            ),
            ListTile(
              title: Text(t('Late')),
              leading: const Icon(
                Icons.access_time,
                color: AppTheme.warningColor,
              ),
              onTap: () => _updateStatus(context, attendance, 'late'),
            ),
            ListTile(
              title: Text(t('Absent')),
              leading: const Icon(Icons.cancel, color: AppTheme.errorColor),
              onTap: () => _updateStatus(context, attendance, 'absent'),
            ),
          ],
        ),
      ),
    );
  }

  void _updateStatus(
    BuildContext context,
    Attendance attendance,
    String status,
  ) async {
    final provider = context.read<AttendanceProvider>();
    Navigator.of(context).pop(); // Close dialog

    final success = await provider.updateAttendanceStatus(
      attendance.id,
      status,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? t('Status updated successfully')
                : t('Failed to update status'),
          ),
          backgroundColor: success
              ? AppTheme.successColor
              : AppTheme.errorColor,
        ),
      );
    }
  }
}

class _AttendanceCard extends StatelessWidget {
  final Attendance attendance;
  final VoidCallback? onTap;

  const _AttendanceCard({required this.attendance, this.onTap});

  Color get _statusColor {
    switch (attendance.status.toLowerCase()) {
      case 'present':
        return AppTheme.successColor;
      case 'late':
        return AppTheme.warningColor;
      case 'absent':
        return AppTheme.errorColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  IconData get _statusIcon {
    switch (attendance.status.toLowerCase()) {
      case 'present':
        return Icons.check_circle;
      case 'late':
        return Icons.access_time;
      case 'absent':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // User Avatar
            CircleAvatar(
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
              child: Text(
                attendance.displayName.isNotEmpty
                    ? attendance.displayName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attendance.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (attendance.className?.trim().isNotEmpty == true)
                    Text(
                      attendance.className!.trim(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('EEEE, MMM d, yyyy').format(attendance.date),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.login,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            attendance.checkInTime != null
                                ? DateFormat(
                                    'hh:mm a',
                                  ).format(attendance.checkInTime!)
                                : context.t('N/A'),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      if (attendance.checkOutTime != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.logout,
                              size: 14,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat(
                                'hh:mm a',
                              ).format(attendance.checkOutTime!),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_statusIcon, size: 14, color: _statusColor),
                  const SizedBox(width: 4),
                  Text(
                    context.t(attendance.statusDisplay),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _statusColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
