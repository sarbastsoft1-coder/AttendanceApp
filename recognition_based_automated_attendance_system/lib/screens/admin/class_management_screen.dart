import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../localization/localization_extensions.dart';
import '../../models/class_model.dart';
import '../../providers/student_management_provider.dart';
import '../../widgets/responsive_layout.dart';
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
  String tRead(String text, {Map<String, String> params = const {}}) =>
      context.tRead(text, params: params);
  String tr(String key, {Map<String, String> params = const {}}) =>
      context.tr(key, params: params);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StudentManagementProvider>().fetchClasses();
    });
  }

  Future<void> _showClassDialog({ClassModel? classObj}) async {
    final draft = await showDialog<_ClassDraft>(
      context: context,
      builder: (context) => _ClassEditorDialog(
        classObj: classObj,
        meetingDayOptions: _meetingDayOptions,
      ),
    );

    if (draft == null || !mounted) {
      return;
    }

    final provider = context.read<StudentManagementProvider>();
    final success = classObj == null
        ? await provider.createClass(
            name: draft.name,
            subject: draft.subject,
            room: draft.room,
            startTime: draft.startTime,
            endTime: draft.endTime,
            meetingDays: draft.meetingDays,
          )
        : await provider.updateClass(
            classId: classObj.id,
            name: draft.name,
            subject: draft.subject,
            room: draft.room,
            startTime: draft.startTime,
            endTime: draft.endTime,
            meetingDays: draft.meetingDays,
          );

    if (!mounted) {
      return;
    }

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
        backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
      ),
    );
  }

  void _showDeleteClassDialog(ClassModel classObj) {
    showDialog<void>(
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
                        ? tRead('Class deleted successfully')
                        : tRead('Failed to delete class'),
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
            tRead('Failed to export class.'),
        isError: true,
      );
      return;
    }

    _showSnackBar(
      tRead('Class exported to {path}', params: {'path': result.path}),
    );
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
      _showSnackBar(tRead('Selected file could not be read.'), isError: true);
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
      _showSnackBar(
        provider.error ?? tRead('Class import failed.'),
        isError: true,
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('Import Complete')),
        content: SizedBox(
          width: ResponsiveLayout.dialogWidth(context, maxWidth: 420),
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
                  style: const TextStyle(fontWeight: FontWeight.w600),
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
    final padding = ResponsiveLayout.pagePadding(
      context,
      compact: 12,
      mobile: 16,
      tablet: 20,
      desktop: 20,
    );

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
        builder: (context, provider, _) {
          if (provider.isLoading && provider.classes.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.classes.isEmpty) {
            return Center(
              child: Padding(
                padding: padding,
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
                      style: const TextStyle(color: AppTheme.textSecondary),
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
              ),
            );
          }

          return ListView(
            padding: padding,
            children: [
              _BuilderHeroCard(
                title: tr('visualScheduleBuilder'),
                description: tr('visualScheduleBuilderDescription'),
                helper: tr('scheduleBuilderHint'),
                onCreateClass: () => _showClassDialog(),
                onImport: _importClassesCsv,
              ),
              const SizedBox(height: 18),
              ...provider.classes.map(
                (classObj) => _ClassListCard(
                  classObj: classObj,
                  translate: t,
                  onOpen: () => _openClass(classObj),
                  onEdit: () => _showClassDialog(classObj: classObj),
                  onDelete: () => _showDeleteClassDialog(classObj),
                  onExport: () => _exportClassCsv(classObj),
                ),
              ),
            ],
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

class _BuilderHeroCard extends StatelessWidget {
  final String title;
  final String description;
  final String helper;
  final VoidCallback onCreateClass;
  final VoidCallback onImport;

  const _BuilderHeroCard({
    required this.title,
    required this.description,
    required this.helper,
    required this.onCreateClass,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: AppTheme.cardDecoration().copyWith(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.16),
            AppTheme.secondaryColor.withValues(alpha: 0.1),
            AppTheme.bgCard,
          ],
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 16,
        spacing: 20,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  helper,
                  style: const TextStyle(
                    color: AppTheme.primaryLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: onCreateClass,
                icon: const Icon(Icons.add_box_rounded),
                label: Text(context.t('Create Class')),
              ),
              OutlinedButton.icon(
                onPressed: onImport,
                icon: const Icon(Icons.upload_file_rounded),
                label: Text(context.t('Import Classes')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClassListCard extends StatelessWidget {
  final ClassModel classObj;
  final String Function(String text, {Map<String, String> params}) translate;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onExport;

  const _ClassListCard({
    required this.classObj,
    required this.translate,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (classObj.subject?.trim().isNotEmpty == true)
        _InfoChip(
          icon: Icons.menu_book_rounded,
          label: classObj.subject!.trim(),
        ),
      if (classObj.room?.trim().isNotEmpty == true)
        _InfoChip(
          icon: Icons.meeting_room_rounded,
          label: classObj.room!.trim(),
        ),
      if (classObj.startTime?.trim().isNotEmpty == true &&
          classObj.endTime?.trim().isNotEmpty == true)
        _InfoChip(
          icon: Icons.schedule_rounded,
          label: '${classObj.startTime!.trim()} - ${classObj.endTime!.trim()}',
        ),
      ...classObj.meetingDays.map(
        (day) => _InfoChip(
          icon: Icons.calendar_today_rounded,
          label: translate(day),
        ),
      ),
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final actions = Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.download_rounded,
                          color: AppTheme.successColor,
                        ),
                        tooltip: translate('Export Class'),
                        onPressed: onExport,
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.edit_outlined,
                          color: AppTheme.primaryColor,
                        ),
                        tooltip: translate('Edit Class'),
                        onPressed: onEdit,
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppTheme.errorColor,
                        ),
                        tooltip: translate('Delete Class'),
                        onPressed: onDelete,
                      ),
                    ],
                  );

                  final titleBlock = Row(
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
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              translate(
                                '{count} students',
                                params: {'count': '${classObj.studentCount}'},
                              ),
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );

                  if (constraints.maxWidth < 540) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        titleBlock,
                        const SizedBox(height: 8),
                        actions,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: titleBlock),
                      const SizedBox(width: 12),
                      actions,
                    ],
                  );
                },
              ),
              if (chips.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(spacing: 8, runSpacing: 8, children: chips),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.bgElevated,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.glassBorder, width: 0.7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.primaryLight),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassDraft {
  final String name;
  final String subject;
  final String room;
  final String startTime;
  final String endTime;
  final List<String> meetingDays;

  const _ClassDraft({
    required this.name,
    required this.subject,
    required this.room,
    required this.startTime,
    required this.endTime,
    required this.meetingDays,
  });
}

class _ClassEditorDialog extends StatefulWidget {
  final ClassModel? classObj;
  final List<String> meetingDayOptions;

  const _ClassEditorDialog({
    required this.classObj,
    required this.meetingDayOptions,
  });

  @override
  State<_ClassEditorDialog> createState() => _ClassEditorDialogState();
}

class _ClassEditorDialogState extends State<_ClassEditorDialog> {
  static const int _startHour = 8;
  static const int _endHour = 19;
  static const int _slotsPerHour = 2;
  static const double _slotHeight = 22;
  static const double _columnWidth = 124;

  late final TextEditingController _nameController;
  late final TextEditingController _subjectController;
  late final TextEditingController _roomController;

  late Set<String> _selectedDays;
  int? _startSlot;
  int? _endSlot;
  int? _dragAnchorSlot;
  String? _validationMessage;

  int get _slotCount => (_endHour - _startHour) * _slotsPerHour;

  String tr(String key, {Map<String, String> params = const {}}) =>
      context.tr(key, params: params);
  String t(String text, {Map<String, String> params = const {}}) =>
      context.t(text, params: params);

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.classObj?.name ?? '');
    _subjectController = TextEditingController(
      text: widget.classObj?.subject ?? '',
    );
    _roomController = TextEditingController(text: widget.classObj?.room ?? '');
    _selectedDays = {...widget.classObj?.meetingDays ?? const <String>[]};
    _startSlot = _parseTimeToSlot(widget.classObj?.startTime, roundUp: false);
    _endSlot = _parseTimeToSlot(widget.classObj?.endTime, roundUp: true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _subjectController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  int? _parseTimeToSlot(String? time, {required bool roundUp}) {
    if (time == null || time.trim().isEmpty) {
      return null;
    }

    final parts = time.split(':');
    if (parts.length != 2) {
      return null;
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }

    final rawSlot = ((hour - _startHour) * _slotsPerHour) + (minute / 30);
    if (roundUp) {
      return rawSlot.ceil().clamp(1, _slotCount);
    }
    return rawSlot.floor().clamp(0, _slotCount - 1);
  }

  String _formatSlot(int slot) {
    final totalMinutes = (_startHour * 60) + (slot * 30);
    final hour = totalMinutes ~/ 60;
    final minute = totalMinutes % 60;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  int _slotForDy(double dy) {
    final maxHeight = _slotCount * _slotHeight;
    final clamped = dy.clamp(0.0, maxHeight - 1);
    return (clamped / _slotHeight).floor().clamp(0, _slotCount - 1);
  }

  void _startDrag(String day, double dy) {
    final slot = _slotForDy(dy);
    setState(() {
      _validationMessage = null;
      _dragAnchorSlot = slot;
      _startSlot = slot;
      _endSlot = slot + 1;
      _selectedDays.add(day);
    });
  }

  void _updateDrag(double dy) {
    if (_dragAnchorSlot == null) {
      return;
    }

    final currentSlot = _slotForDy(dy);
    final start = math.min(_dragAnchorSlot!, currentSlot);
    final end = math.max(_dragAnchorSlot!, currentSlot) + 1;
    setState(() {
      _startSlot = start;
      _endSlot = end.clamp(1, _slotCount);
    });
  }

  void _endDrag() {
    setState(() {
      _dragAnchorSlot = null;
    });
  }

  void _toggleDay(String day) {
    setState(() {
      _validationMessage = null;
      if (_selectedDays.contains(day)) {
        _selectedDays.remove(day);
      } else {
        _selectedDays.add(day);
      }
    });
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _validationMessage = tr('classNameRequired'));
      return;
    }

    if (_selectedDays.isEmpty || _startSlot == null || _endSlot == null) {
      setState(() => _validationMessage = tr('scheduleRequired'));
      return;
    }

    Navigator.of(context).pop(
      _ClassDraft(
        name: name,
        subject: _subjectController.text.trim(),
        room: _roomController.text.trim(),
        startTime: _formatSlot(_startSlot!),
        endTime: _formatSlot(_endSlot!),
        meetingDays: widget.meetingDayOptions
            .where(_selectedDays.contains)
            .toList(growable: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dialogWidth = ResponsiveLayout.dialogWidth(context, maxWidth: 980);
    final dayColumnsWidth = widget.meetingDayOptions.length * _columnWidth;

    return AlertDialog(
      title: Text(t(widget.classObj == null ? 'Create Class' : 'Edit Class')),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFormFields(),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.bgElevated,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.glassBorder, width: 0.7),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('visualScheduleBuilder'),
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr('visualScheduleBuilderDescription'),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      tr('scheduleBuilderHint'),
                      style: const TextStyle(
                        color: AppTheme.primaryLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      tr('repeatOnDays'),
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.meetingDayOptions.map((day) {
                        final selected = _selectedDays.contains(day);
                        return FilterChip(
                          selected: selected,
                          label: Text(t(day)),
                          onSelected: (_) => _toggleDay(day),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: 72 + dayColumnsWidth,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 72,
                              child: Column(
                                children: [
                                  const SizedBox(height: 44),
                                  for (var slot = 0; slot < _slotCount; slot++)
                                    SizedBox(
                                      height: _slotHeight,
                                      child: Align(
                                        alignment: Alignment.topCenter,
                                        child: slot.isEven
                                            ? Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 2,
                                                ),
                                                child: Text(
                                                  _formatSlot(slot),
                                                  style: const TextStyle(
                                                    color: AppTheme.textMuted,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              )
                                            : const SizedBox.shrink(),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            ...widget.meetingDayOptions.map(
                              (day) => Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: _ScheduleDayColumn(
                                  dayLabel: t(day),
                                  width: _columnWidth - 10,
                                  height: _slotCount * _slotHeight,
                                  isSelected: _selectedDays.contains(day),
                                  startSlot: _startSlot,
                                  endSlot: _endSlot,
                                  slotCount: _slotCount,
                                  slotHeight: _slotHeight,
                                  onTapHeader: () => _toggleDay(day),
                                  onPanStart: (details) =>
                                      _startDrag(day, details.localPosition.dy),
                                  onPanUpdate: (details) =>
                                      _updateDrag(details.localPosition.dy),
                                  onPanEnd: (_) => _endDrag(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildSchedulePreview(),
              if (_validationMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _validationMessage!,
                  style: const TextStyle(
                    color: AppTheme.errorColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t('Cancel')),
        ),
        ElevatedButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined),
          label: Text(t(widget.classObj == null ? 'Create' : 'Save')),
        ),
      ],
    );
  }

  Widget _buildFormFields() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final fieldWidth = wide
            ? (constraints.maxWidth - 16) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: fieldWidth,
              child: TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: t('Class Name'),
                  hintText: t('e.g. CS 101 - Section A'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(
              width: fieldWidth,
              child: TextField(
                controller: _subjectController,
                decoration: InputDecoration(
                  labelText: t('Subject'),
                  hintText: t('e.g. Algorithms'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(
              width: fieldWidth,
              child: TextField(
                controller: _roomController,
                decoration: InputDecoration(
                  labelText: t('Room'),
                  hintText: t('e.g. Lab 3'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSchedulePreview() {
    final scheduleReady =
        _selectedDays.isNotEmpty && _startSlot != null && _endSlot != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.glassBorder, width: 0.7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('schedulePreview'),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (!scheduleReady)
            Text(
              tr('scheduleBuilderHint'),
              style: const TextStyle(
                color: AppTheme.textSecondary,
                height: 1.45,
              ),
            )
          else ...[
            Text(
              '${_formatSlot(_startSlot!)} - ${_formatSlot(_endSlot!)}',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.meetingDayOptions
                  .where(_selectedDays.contains)
                  .map(
                    (day) => _InfoChip(
                      icon: Icons.event_repeat_rounded,
                      label: t(day),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScheduleDayColumn extends StatelessWidget {
  final String dayLabel;
  final double width;
  final double height;
  final bool isSelected;
  final int? startSlot;
  final int? endSlot;
  final int slotCount;
  final double slotHeight;
  final VoidCallback onTapHeader;
  final GestureDragStartCallback onPanStart;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;

  const _ScheduleDayColumn({
    required this.dayLabel,
    required this.width,
    required this.height,
    required this.isSelected,
    required this.startSlot,
    required this.endSlot,
    required this.slotCount,
    required this.slotHeight,
    required this.onTapHeader,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  @override
  Widget build(BuildContext context) {
    final hasBlock = isSelected && startSlot != null && endSlot != null;
    final blockHeight = hasBlock
        ? math.max(((endSlot! - startSlot!) * slotHeight) - 8, 18).toDouble()
        : 0.0;

    return Column(
      children: [
        InkWell(
          onTap: onTapHeader,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: width,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryColor.withValues(alpha: 0.14)
                  : AppTheme.bgBase,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? AppTheme.primaryColor.withValues(alpha: 0.3)
                    : AppTheme.glassBorder,
                width: 0.8,
              ),
            ),
            child: Center(
              child: Text(
                dayLabel,
                style: TextStyle(
                  color: isSelected
                      ? AppTheme.primaryLight
                      : AppTheme.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onPanStart: onPanStart,
          onPanUpdate: onPanUpdate,
          onPanEnd: onPanEnd,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: AppTheme.bgBase,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? AppTheme.primaryColor.withValues(alpha: 0.22)
                    : AppTheme.glassBorder,
                width: 0.8,
              ),
            ),
            child: Stack(
              children: [
                Column(
                  children: List.generate(
                    slotCount,
                    (slot) => Container(
                      height: slotHeight,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: slot.isEven
                                ? AppTheme.glassBorder
                                : AppTheme.glassBorder.withValues(alpha: 0.35),
                            width: slot.isEven ? 0.8 : 0.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (hasBlock)
                  Positioned(
                    left: 8,
                    right: 8,
                    top: (startSlot! * slotHeight) + 4,
                    height: blockHeight,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.primaryColor.withValues(alpha: 0.82),
                              AppTheme.secondaryColor.withValues(alpha: 0.72),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withValues(
                                alpha: 0.18,
                              ),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(10),
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            context.tr('scheduleBuilder'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
