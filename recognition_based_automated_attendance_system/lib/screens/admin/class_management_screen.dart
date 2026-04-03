import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../localization/localization_extensions.dart';
import '../../models/class_model.dart';
import '../../providers/student_management_provider.dart';
import 'class_students_screen.dart';

class ClassManagementScreen extends StatefulWidget {
  const ClassManagementScreen({super.key});

  @override
  State<ClassManagementScreen> createState() => _ClassManagementScreenState();
}

class _ClassManagementScreenState extends State<ClassManagementScreen> {
  static const List<String> _meetingDayOptions = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
  ];

  String t(String text, {Map<String, String> params = const {}}) =>
      context.t(text, params: params);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StudentManagementProvider>().fetchClasses();
    });
  }

  Future<void> _showClassDialog({ClassModel? classObj}) async {
    final nameController = TextEditingController(text: classObj?.name ?? '');
    final subjectController = TextEditingController(
      text: classObj?.subject ?? '',
    );
    final roomController = TextEditingController(text: classObj?.room ?? '');
    final startController = TextEditingController(
      text: classObj?.startTime ?? '',
    );
    final endController = TextEditingController(text: classObj?.endTime ?? '');
    final selectedDays = <String>{...classObj?.meetingDays ?? const <String>[]};

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(t(classObj == null ? 'Create Class' : 'Edit Class')),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: t('Class Name'),
                        hintText: t('e.g. CS 101 - Section A'),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: subjectController,
                      decoration: InputDecoration(
                        labelText: t('Subject'),
                        hintText: t('e.g. Algorithms'),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: roomController,
                            decoration: InputDecoration(
                              labelText: t('Room'),
                              hintText: t('e.g. Lab 3'),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: startController,
                            decoration: InputDecoration(
                              labelText: t('Start Time'),
                              hintText: '09:00',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: endController,
                            decoration: InputDecoration(
                              labelText: t('End Time'),
                              hintText: '10:30',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      t('Meeting Days'),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _meetingDayOptions.map((day) {
                        final isSelected = selectedDays.contains(day);
                        return FilterChip(
                          label: Text(t(day)),
                          selected: isSelected,
                          onSelected: (selected) {
                            setDialogState(() {
                              if (selected) {
                                selectedDays.add(day);
                              } else {
                                selectedDays.remove(day);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(t('Cancel')),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) {
                    return;
                  }

                  final provider = context.read<StudentManagementProvider>();
                  final success = classObj == null
                      ? await provider.createClass(
                          name: name,
                          subject: subjectController.text,
                          room: roomController.text,
                          startTime: startController.text,
                          endTime: endController.text,
                          meetingDays: selectedDays.toList(),
                        )
                      : await provider.updateClass(
                          classId: classObj.id,
                          name: name,
                          subject: subjectController.text,
                          room: roomController.text,
                          startTime: startController.text,
                          endTime: endController.text,
                          meetingDays: selectedDays.toList(),
                        );

                  if (!context.mounted) {
                    return;
                  }

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? (classObj == null
                                  ? t('Class created successfully')
                                  : t('Class updated successfully'))
                            : (provider.error ??
                                  (classObj == null
                                      ? t('Failed to create class')
                                      : t('Failed to update class'))),
                      ),
                      backgroundColor: success
                          ? AppTheme.successColor
                          : AppTheme.errorColor,
                    ),
                  );
                },
                child: Text(t(classObj == null ? 'Create' : 'Save')),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteClassDialog(ClassModel classObj) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('Delete Class')),
        content: Text(
          t(
            'Delete "{name}" and all linked students? Existing attendance history will remain.',
            params: {'name': classObj.name},
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
                  .deleteClass(classObj.id);
              if (!context.mounted) {
                return;
              }
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? t('Class deleted successfully')
                        : t('Failed to delete class'),
                  ),
                  backgroundColor: success
                      ? AppTheme.successColor
                      : AppTheme.errorColor,
                ),
              );
            },
            child: Text(t('Delete')),
          ),
        ],
      ),
    );
  }

  Future<void> _exportClassCsv(ClassModel classObj) async {
    final result = await context
        .read<StudentManagementProvider>()
        .exportClassCsv(classObj: classObj);

    if (!mounted) {
      return;
    }

    if (result == null) {
      _showSnackBar(
        context.read<StudentManagementProvider>().error ??
            t('Failed to export class.'),
        isError: true,
      );
      return;
    }

    _showSnackBar(t('Class exported to {path}', params: {'path': result.path}));
  }

  Future<void> _importClassesCsv() async {
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
    final result = await provider.importClassesFromCsv(csvFile: File(filePath));

    if (!mounted) {
      return;
    }

    if (result == null) {
      _showSnackBar(provider.error ?? t('Class import failed.'), isError: true);
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

  Future<void> _openClass(ClassModel classObj) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClassStudentsScreen(classObj: classObj),
      ),
    );
    if (!mounted) {
      return;
    }
    context.read<StudentManagementProvider>().fetchClasses();
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
        title: Text(t('Class Management')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () =>
                context.read<StudentManagementProvider>().fetchClasses(),
          ),
        ],
      ),
      body: Consumer<StudentManagementProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.classes.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.classes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.class_outlined,
                    size: 64,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    t('No classes found'),
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _showClassDialog(),
                        icon: const Icon(Icons.add),
                        label: Text(t('Create First Class')),
                      ),
                      OutlinedButton.icon(
                        onPressed: _importClassesCsv,
                        icon: const Icon(Icons.upload_file_rounded),
                        label: Text(t('Import Classes')),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.classes.length,
            itemBuilder: (context, index) {
              final classObj = provider.classes[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _openClass(classObj),
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
                              child: const Icon(
                                Icons.class_rounded,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    classObj.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    t(
                                      '{count} students',
                                      params: {
                                        'count': '${classObj.studentCount}',
                                      },
                                    ),
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.download_rounded,
                                color: AppTheme.successColor,
                              ),
                              tooltip: t('Export Class'),
                              onPressed: () => _exportClassCsv(classObj),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: AppTheme.primaryColor,
                              ),
                              tooltip: t('Edit Class'),
                              onPressed: () =>
                                  _showClassDialog(classObj: classObj),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: AppTheme.errorColor,
                              ),
                              tooltip: t('Delete Class'),
                              onPressed: () => _showDeleteClassDialog(classObj),
                            ),
                          ],
                        ),
                        if (classObj.scheduleSummary.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            classObj.scheduleSummary,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'import_classes_fab',
            onPressed: _importClassesCsv,
            backgroundColor: AppTheme.successColor,
            tooltip: t('Import Classes'),
            child: const Icon(Icons.upload_file_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          FloatingActionButton(
            heroTag: 'add_class_fab',
            onPressed: () => _showClassDialog(),
            backgroundColor: AppTheme.primaryColor,
            tooltip: t('Add Class'),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
