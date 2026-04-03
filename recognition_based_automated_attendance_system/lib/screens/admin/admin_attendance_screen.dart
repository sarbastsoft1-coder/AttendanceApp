import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../localization/localization_extensions.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/student_management_provider.dart';
import '../../models/attendance_model.dart';
import '../../widgets/responsive_layout.dart';

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

  bool _isMobile(BuildContext context) => ResponsiveLayout.isMobile(context);

  double _dialogWidth(BuildContext context, double maxWidth) {
    final availableWidth = MediaQuery.sizeOf(context).width - 48;
    return availableWidth.clamp(280.0, maxWidth).toDouble();
  }

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

  Future<T?> _pickDialogOption<T>({
    required BuildContext context,
    required String title,
    required List<_DialogOption<T>> options,
  }) async {
    if (options.isEmpty) return null;

    return showDialog<T>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: _dialogWidth(context, 360),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: options.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final option = options[index];
              return ListTile(
                title: Text(option.label),
                onTap: () => Navigator.of(context).pop(option.value),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSelectorField({
    required String label,
    required String value,
    required VoidCallback? onTap,
    IconData trailingIcon = Icons.arrow_drop_down_rounded,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: Icon(trailingIcon),
        ),
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
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

    var availableStudents = studentProvider.students
        .where((student) => student.classId == selectedClassId)
        .toList();
    int? selectedStudentId = availableStudents.isNotEmpty
        ? availableStudents.first.id
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
            final selectedClass = classes.firstWhere(
              (classObj) => classObj.id == selectedClassId,
              orElse: () => classes.first,
            );
            final hasSelectedStudent = availableStudents.any(
              (student) => student.id == selectedStudentId,
            );
            final selectedStudent = hasSelectedStudent
                ? availableStudents.firstWhere(
                    (student) => student.id == selectedStudentId,
                  )
                : null;

            return AlertDialog(
              title: Text(t('Manual Entry')),
              content: SizedBox(
                width: _dialogWidth(dialogContext, 420),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    _buildSelectorField(
                      label: language.text('Select Class'),
                      value: selectedClass.name,
                      onTap: isSaving
                          ? null
                          : () async {
                              final pickedClassId = await _pickDialogOption<int>(
                                context: dialogContext,
                                title: language.text('Select Class'),
                                options: classes
                                    .map(
                                      (classObj) => _DialogOption(
                                        value: classObj.id,
                                        label: classObj.name,
                                      ),
                                    )
                                    .toList(),
                              );
                              if (pickedClassId == null ||
                                  pickedClassId == selectedClassId) {
                                return;
                              }
                              await studentProvider.fetchClassStudents(
                                pickedClassId,
                              );
                              if (!dialogContext.mounted) return;
                              final reloadedStudents = studentProvider.students
                                  .where(
                                    (student) => student.classId == pickedClassId,
                                  )
                                  .toList();
                              setDialogState(() {
                                selectedClassId = pickedClassId;
                                availableStudents = reloadedStudents;
                                selectedStudentId = reloadedStudents.isNotEmpty
                                    ? reloadedStudents.first.id
                                    : null;
                              });
                            },
                    ),
                    const SizedBox(height: 16),
                    _buildSelectorField(
                      label: language.text('Student Name'),
                      value: selectedStudent?.name ??
                          (availableStudents.isEmpty
                              ? language.text('No students found for this class')
                              : language.text('Student Name')),
                      onTap: isSaving || availableStudents.isEmpty
                          ? null
                          : () async {
                              final pickedStudentId = await _pickDialogOption<int>(
                                context: dialogContext,
                                title: language.text('Student Name'),
                                options: availableStudents
                                    .map(
                                      (student) => _DialogOption(
                                        value: student.id,
                                        label: student.name,
                                      ),
                                    )
                                    .toList(),
                              );
                              if (pickedStudentId == null) return;
                              setDialogState(() {
                                selectedStudentId = pickedStudentId;
                              });
                            },
                    ),
                    if (availableStudents.isEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        language.text('No students found for this class'),
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _buildSelectorField(
                      label: language.text('Status'),
                      value: language.text(
                        switch (selectedStatus) {
                          'present' => 'Present',
                          'late' => 'Late',
                          'absent' => 'Absent',
                          _ => 'Present',
                        },
                      ),
                      onTap: isSaving
                          ? null
                          : () async {
                              final pickedStatus = await _pickDialogOption<String>(
                                context: dialogContext,
                                title: language.text('Status'),
                                options: [
                                  _DialogOption(
                                    value: 'present',
                                    label: language.text('Present'),
                                  ),
                                  _DialogOption(
                                    value: 'late',
                                    label: language.text('Late'),
                                  ),
                                  _DialogOption(
                                    value: 'absent',
                                    label: language.text('Absent'),
                                  ),
                                ],
                              );
                              if (pickedStatus == null) return;
                              setDialogState(() {
                                selectedStatus = pickedStatus;
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
                          labelText: language.text('Date'),
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
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: Text(language.text('Cancel')),
                ),
                ElevatedButton.icon(
                  onPressed: isSaving || selectedStudentId == null
                      ? null
                      : () async {
                          final hadExistingRecord = attendanceProvider
                              .allAttendance
                              .any(
                                (record) =>
                                    record.studentId == selectedStudentId &&
                                    record.date.year == selectedDate.year &&
                                    record.date.month == selectedDate.month &&
                                    record.date.day == selectedDate.day,
                              );
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
                                language.text(
                                  hadExistingRecord
                                      ? 'Attendance updated for selected date'
                                      : 'Attendance saved successfully',
                                ),
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
                  label: Text(language.text('Save')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = _isMobile(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(t('All Attendance')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: _buildAppBarActions(context, isMobile),
      ),
      floatingActionButton: isMobile
          ? FloatingActionButton(
              onPressed: _showManualEntryDialog,
              tooltip: t('Add Person'),
              child: const Icon(Icons.person_add_alt_1_rounded),
            )
          : FloatingActionButton.extended(
              onPressed: _showManualEntryDialog,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: Text(t('Add Person')),
            ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              color: AppTheme.bgElevated,
              child: Column(
                children: [
                  if (_startDate != null && _endDate != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Icon(
                            Icons.date_range,
                            color: AppTheme.primaryColor,
                            size: 18,
                          ),
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
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: SingleChildScrollView(
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
                  ),
                ],
              ),
            ),
            Expanded(
              child: Consumer<AttendanceProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  var records = provider.allAttendance;
                  if (_statusFilter != 'all') {
                    records = records
                        .where((a) => a.status == _statusFilter)
                        .toList();
                  }

                  if (records.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
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
                              textAlign: TextAlign.center,
                            ),
                            if (_startDate != null || _statusFilter != 'all')
                              TextButton(
                                onPressed: _clearFilters,
                                child: Text(t('Clear filters')),
                              ),
                          ],
                        ),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async => _loadAttendance(),
                    child: ListView.builder(
                      padding: EdgeInsets.all(isMobile ? 12 : 16),
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

  List<Widget> _buildAppBarActions(BuildContext context, bool isMobile) {
    if (!isMobile) {
      return [
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
      ];
    }

    return [
      IconButton(
        icon: const Icon(Icons.refresh),
        tooltip: t('Refresh'),
        onPressed: _loadAttendance,
      ),
      PopupMenuButton<_AttendanceMenuAction>(
        onSelected: (action) => _handleMenuAction(context, action),
        itemBuilder: (context) => [
          PopupMenuItem(
            value: _AttendanceMenuAction.filter,
            child: Text(t('Filter')),
          ),
          if (_startDate != null || _statusFilter != 'all')
            PopupMenuItem(
              value: _AttendanceMenuAction.clear,
              child: Text(t('Clear filters')),
            ),
          PopupMenuItem(
            value: _AttendanceMenuAction.export,
            child: Text(t('Export CSV')),
          ),
        ],
      ),
    ];
  }

  void _handleMenuAction(
    BuildContext context,
    _AttendanceMenuAction action,
  ) {
    switch (action) {
      case _AttendanceMenuAction.filter:
        _selectDateRange();
        break;
      case _AttendanceMenuAction.clear:
        _clearFilters();
        break;
      case _AttendanceMenuAction.export:
        _exportCSV(context);
        break;
    }
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

class _DialogOption<T> {
  final T value;
  final String label;

  const _DialogOption({required this.value, required this.label});
}

enum _AttendanceMenuAction { filter, clear, export }

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
    final isMobile = MediaQuery.sizeOf(context).width < 640;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(isMobile ? 14 : 16),
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
        child: isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: AppTheme.primaryColor.withValues(
                          alpha: 0.1,
                        ),
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
                      Expanded(child: _AttendanceDetails(attendance: attendance)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: _AttendanceStatusBadge(
                      statusColor: _statusColor,
                      statusIcon: _statusIcon,
                      label: context.t(attendance.statusDisplay),
                    ),
                  ),
                ],
              )
            : Row(
                children: [
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
                  Expanded(child: _AttendanceDetails(attendance: attendance)),
                  _AttendanceStatusBadge(
                    statusColor: _statusColor,
                    statusIcon: _statusIcon,
                    label: context.t(attendance.statusDisplay),
                  ),
                ],
              ),
      ),
    );
  }
}

class _AttendanceDetails extends StatelessWidget {
  final Attendance attendance;

  const _AttendanceDetails({required this.attendance});

  @override
  Widget build(BuildContext context) {
    return Column(
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
                      ? DateFormat('hh:mm a').format(attendance.checkInTime!)
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
                    DateFormat('hh:mm a').format(attendance.checkOutTime!),
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
    );
  }
}

class _AttendanceStatusBadge extends StatelessWidget {
  final Color statusColor;
  final IconData statusIcon;
  final String label;

  const _AttendanceStatusBadge({
    required this.statusColor,
    required this.statusIcon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 14, color: statusColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }
}
