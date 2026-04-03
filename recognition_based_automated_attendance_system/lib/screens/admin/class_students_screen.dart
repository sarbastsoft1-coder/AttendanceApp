import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../localization/localization_extensions.dart';
import '../../models/class_model.dart';
import '../../providers/student_management_provider.dart';
import '../batch_student_registration_screen.dart';
import 'class_attendance_screen.dart';

enum _ClassExportAction { students, attendance }

class ClassStudentsScreen extends StatefulWidget {
  final ClassModel classObj;

  const ClassStudentsScreen({super.key, required this.classObj});

  @override
  State<ClassStudentsScreen> createState() => _ClassStudentsScreenState();
}

class _ClassStudentsScreenState extends State<ClassStudentsScreen> {
  String t(String text, {Map<String, String> params = const {}}) =>
      context.t(text, params: params);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StudentManagementProvider>().fetchClassStudents(
        widget.classObj.id,
      );
    });
  }

  Future<void> _showEditStudentDialog(Student student) async {
    final controller = TextEditingController(text: student.name);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('Edit Student')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: t('Student Name'),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t('Cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) {
                return;
              }
              final success = await context
                  .read<StudentManagementProvider>()
                  .updateStudent(
                    classId: widget.classObj.id,
                    studentId: student.id,
                    name: newName,
                  );
              if (!context.mounted) {
                return;
              }
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? t('Student updated successfully')
                        : t('Failed to update student'),
                  ),
                  backgroundColor: success
                      ? AppTheme.successColor
                      : AppTheme.errorColor,
                ),
              );
            },
            child: Text(t('Save')),
          ),
        ],
      ),
    );
  }

  void _showDeleteStudentDialog(Student student) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('Delete Student')),
        content: Text(
          t(
            'Are you sure you want to delete "{name}" from this class? This action cannot be undone.',
            params: {'name': student.name},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t('Cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            onPressed: () async {
              final success = await context
                  .read<StudentManagementProvider>()
                  .deleteStudent(widget.classObj.id, student.id);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? t('Student deleted successfully')
                          : t('Failed to delete student'),
                    ),
                    backgroundColor: success
                        ? AppTheme.successColor
                        : AppTheme.errorColor,
                  ),
                );
              }
            },
            child: Text(
              t('Delete'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToAddStudent() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BatchStudentRegistrationScreen(
          initialClassId: widget.classObj.id,
          initialClassName: widget.classObj.name,
        ),
      ),
    );
    // Refresh student list after returning from registration
    if (!mounted) return;
    context.read<StudentManagementProvider>().fetchClassStudents(
      widget.classObj.id,
    );
  }

  Future<void> _importStudentsCsv() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      withData: false,
    );
    if (picked == null) {
      return;
    }

    final filePath = picked.files.single.path;
    if (filePath == null) {
      _showSnackBar(t('Selected file could not be read.'), isError: true);
      return;
    }

    if (!mounted) {
      return;
    }

    final provider = context.read<StudentManagementProvider>();
    final result = await provider.importStudentsFromCsv(
      classId: widget.classObj.id,
      csvFile: File(filePath),
    );

    if (!mounted) {
      return;
    }

    if (result == null) {
      _showSnackBar(
        provider.error ?? t('Student import failed.'),
        isError: true,
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('Import Complete')),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(result.message),
              const SizedBox(height: 12),
              Text(
                t(
                  'Imported: {count}',
                  params: {'count': '${result.successCount}'},
                ),
              ),
              Text(
                t(
                  'Skipped: {count}',
                  params: {'count': '${result.errorCount}'},
                ),
              ),
              if (result.errors.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  t('Details'),
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: SingleChildScrollView(
                    child: Text(result.errors.join('\n')),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t('Close')),
          ),
        ],
      ),
    );
  }

  Future<void> _exportStudentsCsv() async {
    final result = await context
        .read<StudentManagementProvider>()
        .exportStudentsCsv(classObj: widget.classObj);
    if (!mounted) {
      return;
    }

    if (result == null) {
      _showSnackBar(
        context.read<StudentManagementProvider>().error ??
            t('Failed to export students.'),
        isError: true,
      );
      return;
    }

    _showSnackBar(
      t('Student list saved to {path}', params: {'path': result.path}),
    );
  }

  Future<void> _exportAttendanceCsv() async {
    final result = await context
        .read<StudentManagementProvider>()
        .exportClassAttendanceCsv(classObj: widget.classObj);
    if (!mounted) {
      return;
    }

    if (result == null) {
      _showSnackBar(
        context.read<StudentManagementProvider>().error ??
            t('Failed to export class attendance.'),
        isError: true,
      );
      return;
    }

    _showSnackBar(
      t('Class attendance saved to {path}', params: {'path': result.path}),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.errorColor : AppTheme.successColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          t('{name} Students', params: {'name': widget.classObj.name}),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded),
            tooltip: t('Add Student'),
            onPressed: _navigateToAddStudent,
          ),
          IconButton(
            icon: const Icon(Icons.upload_file_rounded),
            tooltip: t('Import Students CSV'),
            onPressed: _importStudentsCsv,
          ),
          PopupMenuButton<_ClassExportAction>(
            tooltip: t('Export'),
            icon: const Icon(Icons.download_rounded),
            onSelected: (value) {
              if (value == _ClassExportAction.students) {
                _exportStudentsCsv();
              } else if (value == _ClassExportAction.attendance) {
                _exportAttendanceCsv();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _ClassExportAction.students,
                child: Text(t('Export Student List')),
              ),
              PopupMenuItem(
                value: _ClassExportAction.attendance,
                child: Text(t('Export Attendance CSV')),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: t('View Class Attendance'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ClassAttendanceScreen(classObj: widget.classObj),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<StudentManagementProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(
              child: Text(
                t('Error: {message}', params: {'message': provider.error!}),
              ),
            );
          }

          if (provider.students.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.people_outline,
                    size: 64,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    t('No students registered in this class'),
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _navigateToAddStudent,
                        icon: const Icon(Icons.person_add),
                        label: Text(t('Add First Student')),
                      ),
                      OutlinedButton.icon(
                        onPressed: _importStudentsCsv,
                        icon: const Icon(Icons.upload_file_rounded),
                        label: Text(t('Import CSV')),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.students.length,
            itemBuilder: (context, index) {
              final student = provider.students[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primaryColor.withValues(
                      alpha: 0.1,
                    ),
                    child: const Icon(
                      Icons.person,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  title: Text(
                    student.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    student.hasRegisteredFace
                        ? t('Face Registered')
                        : t('No Face Data'),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        student.hasRegisteredFace
                            ? Icons.check_circle
                            : Icons.warning_amber_rounded,
                        color: student.hasRegisteredFace
                            ? AppTheme.successColor
                            : AppTheme.warningColor,
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(
                          Icons.edit_outlined,
                          color: AppTheme.primaryColor,
                        ),
                        tooltip: t('Edit Student'),
                        onPressed: () => _showEditStudentDialog(student),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppTheme.errorColor,
                        ),
                        tooltip: t('Delete Student'),
                        onPressed: () => _showDeleteStudentDialog(student),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddStudent,
        backgroundColor: AppTheme.primaryColor,
        tooltip: t('Add Student'),
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
    );
  }
}
