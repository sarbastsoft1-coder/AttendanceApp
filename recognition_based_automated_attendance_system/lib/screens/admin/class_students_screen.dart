import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/student_management_provider.dart';
import '../../models/class_model.dart';
import '../batch_student_registration_screen.dart';
import 'admin_attendance_screen.dart';

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
      context.read<StudentManagementProvider>().fetchClassStudents(widget.classObj.id);
    });
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
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Student deleted successfully'
                        : 'Failed to delete student'),
                    backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
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

  void _navigateToAddStudent() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BatchStudentRegistrationScreen(
          initialClassId: widget.classObj.id,
          initialClassName: widget.classObj.name,
        ),
      ),
    ).then((_) {
      // Refresh student list after returning from registration
      context.read<StudentManagementProvider>().fetchClassStudents(widget.classObj.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.classObj.name} Students'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'View Class Attendance',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminAttendanceScreen(),
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
                  const Icon(Icons.people_outline, size: 64, color: AppTheme.textSecondary),
                  const SizedBox(height: 16),
                  const Text(
                    'No students registered in this class',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _navigateToAddStudent,
                    icon: const Icon(Icons.person_add),
                    label: const Text('Add First Student'),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                    child: const Icon(Icons.person, color: AppTheme.primaryColor),
                  ),
                  title: Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(student.hasRegisteredFace ? 'Face Registered' : 'No Face Data'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        student.hasRegisteredFace ? Icons.check_circle : Icons.warning_amber_rounded,
                        color: student.hasRegisteredFace ? AppTheme.successColor : AppTheme.warningColor,
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
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
