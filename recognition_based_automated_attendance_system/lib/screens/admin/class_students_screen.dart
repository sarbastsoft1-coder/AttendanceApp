import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
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
        title: const Text('Edit Student'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Student Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
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
                        ? 'Student updated successfully'
                        : 'Failed to update student',
                  ),
                  backgroundColor: success
                      ? AppTheme.successColor
                      : AppTheme.errorColor,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteStudentDialog(Student student) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Student'),
        content: Text(
          'Are you sure you want to delete "${student.name}" from this class? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
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
                          ? 'Student deleted successfully'
                          : 'Failed to delete student',
                    ),
                    backgroundColor: success
                        ? AppTheme.successColor
                        : AppTheme.errorColor,
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
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
      _showSnackBar('Selected file could not be read.', isError: true);
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
      _showSnackBar(provider.error ?? 'Student import failed.', isError: true);
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Complete'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(result.message),
              const SizedBox(height: 12),
              Text('Imported: ${result.successCount}'),
              Text('Skipped: ${result.errorCount}'),
              if (result.errors.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Details',
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
            child: const Text('Close'),
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
            'Failed to export students.',
        isError: true,
      );
      return;
    }

    _showSnackBar('Student list saved to ${result.path}');
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
            'Failed to export class attendance.',
        isError: true,
      );
      return;
    }

    _showSnackBar('Class attendance saved to ${result.path}');
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
        title: Text('${widget.classObj.name} Students'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded),
            tooltip: 'Add Student',
            onPressed: _navigateToAddStudent,
          ),
          IconButton(
            icon: const Icon(Icons.upload_file_rounded),
            tooltip: 'Import Students CSV',
            onPressed: _importStudentsCsv,
          ),
          PopupMenuButton<_ClassExportAction>(
            tooltip: 'Export',
            icon: const Icon(Icons.download_rounded),
            onSelected: (value) {
              if (value == _ClassExportAction.students) {
                _exportStudentsCsv();
              } else if (value == _ClassExportAction.attendance) {
                _exportAttendanceCsv();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _ClassExportAction.students,
                child: Text('Export Student List'),
              ),
              PopupMenuItem(
                value: _ClassExportAction.attendance,
                child: Text('Export Attendance CSV'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'View Class Attendance',
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
            return Center(child: Text('Error: ${provider.error}'));
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
                  const Text(
                    'No students registered in this class',
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
                        label: const Text('Add First Student'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _importStudentsCsv,
                        icon: const Icon(Icons.upload_file_rounded),
                        label: const Text('Import CSV'),
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
                        ? 'Face Registered'
                        : 'No Face Data',
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
                        tooltip: 'Edit Student',
                        onPressed: () => _showEditStudentDialog(student),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppTheme.errorColor,
                        ),
                        tooltip: 'Delete Student',
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
        tooltip: 'Add Student',
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
    );
  }
}
