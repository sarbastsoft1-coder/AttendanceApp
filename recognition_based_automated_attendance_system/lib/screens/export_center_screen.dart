import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../localization/localization_extensions.dart';
import '../models/class_model.dart';
import '../providers/attendance_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/student_management_provider.dart';
import '../widgets/responsive_layout.dart';

class ExportCenterScreen extends StatefulWidget {
  const ExportCenterScreen({super.key});

  @override
  State<ExportCenterScreen> createState() => _ExportCenterScreenState();
}

class _ExportCenterScreenState extends State<ExportCenterScreen> {
  DateTimeRange? _dateRange;
  int? _attendanceClassFilterId;
  int? _selectedClassId;
  String? _lastExportMessage;
  String? _activeExport;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadClasses();
    });
  }

  Future<void> _loadClasses() async {
    final provider = context.read<StudentManagementProvider>();
    if (provider.classes.isEmpty) {
      await provider.fetchClasses();
    }

    if (!mounted || provider.classes.isEmpty || _selectedClassId != null) {
      return;
    }

    setState(() {
      _selectedClassId = provider.classes.first.id;
    });
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      initialDateRange:
          _dateRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          ),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _dateRange = picked;
    });
  }

  void _clearDateRange() {
    setState(() {
      _dateRange = null;
    });
  }

  String _formatDateRange(BuildContext context) {
    final range = _dateRange;
    if (range == null) {
      return context.t('All Dates');
    }

    final formatter = DateFormat('MMM d, yyyy');
    return '${formatter.format(range.start)} - ${formatter.format(range.end)}';
  }

  ClassModel? _selectedClass(List<ClassModel> classes) {
    if (_selectedClassId == null) {
      return null;
    }

    for (final classObj in classes) {
      if (classObj.id == _selectedClassId) {
        return classObj;
      }
    }
    return null;
  }

  Future<void> _runExport({
    required String actionKey,
    required Future<String?> Function() exporter,
    required String successTemplate,
    String? fallbackError,
  }) async {
    final tRead = context.tRead;
    if (_activeExport != null) {
      return;
    }

    setState(() {
      _activeExport = actionKey;
    });

    final result = await exporter();
    if (!mounted) {
      return;
    }

    setState(() {
      _activeExport = null;
      _lastExportMessage = result == null
          ? (fallbackError ?? tRead('Failed to export file.'))
          : tRead(successTemplate, params: {'path': result});
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_lastExportMessage!),
        backgroundColor: result == null
            ? AppTheme.errorColor
            : AppTheme.successColor,
      ),
    );
  }

  Future<void> _exportAttendanceReport() async {
    final tRead = context.tRead;
    await _runExport(
      actionKey: 'attendance_report',
      exporter: () => context.read<AttendanceProvider>().exportAttendance(
        start: _dateRange?.start,
        end: _dateRange?.end,
        classId: _attendanceClassFilterId,
      ),
      successTemplate: 'Attendance report saved to {path}',
      fallbackError: tRead('Failed to export attendance report'),
    );
  }

  Future<void> _exportSelectedClassAttendance() async {
    final tRead = context.tRead;
    final selectedClass = _selectedClass(
      context.read<StudentManagementProvider>().classes,
    );
    if (selectedClass == null) {
      return;
    }

    await _runExport(
      actionKey: 'class_attendance',
      exporter: () async {
        final result = await context
            .read<StudentManagementProvider>()
            .exportClassAttendanceCsv(classObj: selectedClass);
        return result?.path;
      },
      successTemplate: 'Class attendance saved to {path}',
      fallbackError: tRead('Failed to export class attendance.'),
    );
  }

  Future<void> _exportStudentList() async {
    final tRead = context.tRead;
    final selectedClass = _selectedClass(
      context.read<StudentManagementProvider>().classes,
    );
    if (selectedClass == null) {
      return;
    }

    await _runExport(
      actionKey: 'student_list',
      exporter: () async {
        final result = await context
            .read<StudentManagementProvider>()
            .exportStudentsCsv(classObj: selectedClass);
        return result?.path;
      },
      successTemplate: 'Student list saved to {path}',
      fallbackError: tRead('Failed to export students.'),
    );
  }

  Future<void> _exportClassSnapshot() async {
    final tRead = context.tRead;
    final selectedClass = _selectedClass(
      context.read<StudentManagementProvider>().classes,
    );
    if (selectedClass == null) {
      return;
    }

    await _runExport(
      actionKey: 'class_snapshot',
      exporter: () async {
        final result = await context
            .read<StudentManagementProvider>()
            .exportClassCsv(classObj: selectedClass);
        return result?.path;
      },
      successTemplate: 'Class exported to {path}',
      fallbackError: tRead('Failed to export class.'),
    );
  }

  bool _isRunning(String actionKey) => _activeExport == actionKey;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isManagementUser =
        auth.user?.isAdmin == true || auth.user?.isTeacher == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('exportCenter')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: context.t('Refresh'),
            onPressed: _loadClasses,
          ),
        ],
      ),
      body: SafeArea(
        child: isManagementUser
            ? Consumer<StudentManagementProvider>(
                builder: (context, classesProvider, _) {
                  final classes = classesProvider.classes;
                  final selectedClass = _selectedClass(classes);

                  return SingleChildScrollView(
                    padding: ResponsiveLayout.pagePadding(
                      context,
                      compact: 12,
                      mobile: 16,
                      tablet: 20,
                      desktop: 24,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: ResponsiveLayout.contentMaxWidth(context),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(context),
                            const SizedBox(height: 20),
                            if (_lastExportMessage != null) ...[
                              _buildLastExportCard(context),
                              const SizedBox(height: 20),
                            ],
                            if (classesProvider.isLoading && classes.isEmpty)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(48),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else ...[
                              _buildAttendanceExportsCard(context, classes),
                              const SizedBox(height: 20),
                              _buildClassExportsCard(
                                context,
                                classes,
                                selectedClass,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              )
            : Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    context.t(
                      'Only users and admins can access the export center.',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(ResponsiveLayout.isMobile(context) ? 20 : 24),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('exportCenter'),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.t('Generate attendance reports and exports'),
            style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildLastExportCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.successColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppTheme.successColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _lastExportMessage!,
              style: const TextStyle(color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceExportsCard(
    BuildContext context,
    List<ClassModel> classes,
  ) {
    return Container(
      padding: EdgeInsets.all(ResponsiveLayout.isMobile(context) ? 20 : 24),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('Attendance Reports'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.t(
              'Export attendance records by date range and optional class filter.',
            ),
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<int?>(
            key: ValueKey(
              'attendance-filter-${_attendanceClassFilterId ?? 'all'}-${classes.length}',
            ),
            initialValue: _attendanceClassFilterId,
            decoration: InputDecoration(
              labelText: context.t('Select Class'),
              prefixIcon: const Icon(Icons.class_rounded),
            ),
            items: [
              DropdownMenuItem<int?>(
                value: null,
                child: Text(context.t('All Classes')),
              ),
              ...classes.map(
                (classObj) => DropdownMenuItem<int?>(
                  value: classObj.id,
                  child: Text(classObj.name),
                ),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _attendanceClassFilterId = value;
              });
            },
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final useColumn = constraints.maxWidth < 460;
              final clearButton = _dateRange != null
                  ? IconButton(
                      tooltip: context.t('Clear filters'),
                      onPressed: _clearDateRange,
                      icon: const Icon(Icons.clear_rounded),
                    )
                  : null;

              if (useColumn) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickDateRange,
                      icon: const Icon(Icons.date_range_rounded),
                      label: Text(_formatDateRange(context)),
                    ),
                    if (clearButton != null) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: clearButton,
                      ),
                    ],
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDateRange,
                      icon: const Icon(Icons.date_range_rounded),
                      label: Text(_formatDateRange(context)),
                    ),
                  ),
                  if (clearButton != null) ...[
                    const SizedBox(width: 12),
                    clearButton,
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isRunning('attendance_report')
                  ? null
                  : _exportAttendanceReport,
              icon: _isRunning('attendance_report')
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_rounded),
              label: Text(context.t('Export Attendance CSV')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassExportsCard(
    BuildContext context,
    List<ClassModel> classes,
    ClassModel? selectedClass,
  ) {
    return Container(
      padding: EdgeInsets.all(ResponsiveLayout.isMobile(context) ? 20 : 24),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('Class Data Exports'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.t(
              'Export the selected class roster, attendance CSV, or a full class snapshot.',
            ),
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 20),
          if (classes.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.bgElevated,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                context.t('No classes found'),
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            )
          else ...[
            DropdownButtonFormField<int>(
              key: ValueKey(
                'class-export-${_selectedClassId ?? 'none'}-${classes.length}',
              ),
              initialValue: _selectedClassId,
              decoration: InputDecoration(
                labelText: context.t('Select Class'),
                prefixIcon: const Icon(Icons.folder_copy_rounded),
              ),
              items: classes
                  .map(
                    (classObj) => DropdownMenuItem<int>(
                      value: classObj.id,
                      child: Text(classObj.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedClassId = value;
                });
              },
            ),
            if (selectedClass != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.bgElevated,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedClass.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (selectedClass.scheduleSummary.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        selectedClass.scheduleSummary,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      context.t(
                        'Students: {count}',
                        params: {'count': '${selectedClass.studentCount}'},
                      ),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _ExportActionButton(
                  icon: Icons.people_alt_rounded,
                  label: context.t('Export Student List'),
                  isLoading: _isRunning('student_list'),
                  onPressed: _exportStudentList,
                ),
                _ExportActionButton(
                  icon: Icons.fact_check_rounded,
                  label: context.t('Export Attendance CSV'),
                  isLoading: _isRunning('class_attendance'),
                  onPressed: _exportSelectedClassAttendance,
                ),
                _ExportActionButton(
                  icon: Icons.dataset_rounded,
                  label: context.t('Export Class'),
                  isLoading: _isRunning('class_snapshot'),
                  onPressed: _exportClassSnapshot,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ExportActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isLoading;
  final VoidCallback onPressed;

  const _ExportActionButton({
    required this.icon,
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final buttonWidth = width < 480
        ? width - 56
        : (ResponsiveLayout.isMobile(context) ? 240.0 : 220.0);

    return SizedBox(
      width: buttonWidth,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon),
        label: Text(label),
      ),
    );
  }
}
