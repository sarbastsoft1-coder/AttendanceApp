import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../localization/localization_extensions.dart';
import '../providers/student_management_provider.dart';
import '../providers/attendance_provider.dart';
import '../widgets/custom_button.dart';
import '../widgets/responsive_layout.dart';

class RollCallScreen extends StatefulWidget {
  const RollCallScreen({super.key});

  @override
  State<RollCallScreen> createState() => _RollCallScreenState();
}

class _RollCallScreenState extends State<RollCallScreen> {
  int? _selectedClassId;
  Map<int, String> _studentStatus = {};
  DateTime _selectedDate = DateTime.now();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadClasses();
    });
  }

  void _loadClasses() {
    final studentProvider = context.read<StudentManagementProvider>();
    if (studentProvider.classes.isEmpty) {
      studentProvider.fetchClasses();
    }
  }

  void _selectClass(int classId) {
    setState(() {
      _selectedClassId = classId;
      _studentStatus = {};
    });
    _loadStudentsForClass(classId);
  }

  void _loadStudentsForClass(int classId) {
    final studentProvider = context.read<StudentManagementProvider>();
    studentProvider.fetchClassStudents(classId);
  }

  Future<void> _submitRollCall() async {
    if (_selectedClassId == null) return;
    final successMessage = context.trRead('rollCallComplete');
    final failureMessage = context.tRead('Failed to save roll call');

    setState(() {
      _isSubmitting = true;
    });

    final attendanceProvider = context.read<AttendanceProvider>();
    final studentProvider = context.read<StudentManagementProvider>();
    final students = studentProvider.students;

    final entries = students.map((student) {
      return {
        'student_id': student.id,
        'status': _studentStatus[student.id] ?? 'absent',
      };
    }).toList();

    final success = await attendanceProvider.submitRollCall(
      classId: _selectedClassId!,
      attendanceDate: _selectedDate,
      entries: entries,
    );

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? successMessage : failureMessage),
        backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
      ),
    );
    if (success) {
      Navigator.pop(context);
    }
  }

  void _markAll(String status) {
    final studentProvider = context.read<StudentManagementProvider>();
    final students = studentProvider.students;

    setState(() {
      for (var student in students) {
        _studentStatus[student.id] = status;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final tr = context.tr;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('rollCall')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
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
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppTheme.cardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('rollCallDescription'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Consumer<StudentManagementProvider>(
                        builder: (context, provider, child) {
                          final classes = provider.classes;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t('Select Class'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<int>(
                                initialValue: _selectedClassId,
                                decoration: InputDecoration(
                                  hintText: t('Select Class'),
                                  prefixIcon: const Icon(Icons.class_rounded),
                                ),
                                items: classes.map((c) {
                                  return DropdownMenuItem(
                                    value: c.id,
                                    child: Text(c.name),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    _selectClass(value);
                                  }
                                },
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_today),
                        title: Text(t('Select Date')),
                        subtitle: Text(
                          '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                        ),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 30),
                            ),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() {
                              _selectedDate = date;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
                if (_selectedClassId != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: AppTheme.cardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              t('Students'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Wrap(
                              spacing: 4,
                              children: [
                                TextButton(
                                  onPressed: () => _markAll('present'),
                                  child: Text(tr('selectAll')),
                                ),
                                TextButton(
                                  onPressed: () => _markAll('absent'),
                                  child: Text(tr('deselectAll')),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Divider(),
                        Consumer<StudentManagementProvider>(
                          builder: (context, provider, child) {
                            final students = provider.students;
                            if (students.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    t('No students found for this class'),
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                              );
                            }
                            return ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: students.length,
                              itemBuilder: (context, index) {
                                final student = students[index];
                                return LayoutBuilder(
                                  builder: (context, constraints) {
                                    final selector = DropdownButton<String>(
                                      value:
                                          _studentStatus[student.id] ??
                                          'absent',
                                      items: [
                                        DropdownMenuItem(
                                          value: 'present',
                                          child: Text(t('Present')),
                                        ),
                                        DropdownMenuItem(
                                          value: 'late',
                                          child: Text(t('Late')),
                                        ),
                                        DropdownMenuItem(
                                          value: 'absent',
                                          child: Text(t('Absent')),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          _studentStatus[student.id] =
                                              value ?? 'absent';
                                        });
                                      },
                                    );

                                    if (constraints.maxWidth < 420) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(student.name),
                                            const SizedBox(height: 8),
                                            Align(
                                              alignment: AlignmentDirectional
                                                  .centerEnd,
                                              child: selector,
                                            ),
                                          ],
                                        ),
                                      );
                                    }

                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(student.name),
                                      trailing: selector,
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        CustomButton(
                          text: tr('submitRollCall'),
                          isLoading: _isSubmitting,
                          onPressed: _submitRollCall,
                          icon: Icons.save,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
