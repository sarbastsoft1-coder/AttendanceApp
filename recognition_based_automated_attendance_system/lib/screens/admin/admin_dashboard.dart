import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../config/app_theme.dart';
import '../../localization/app_strings.dart';
import '../../localization/localization_extensions.dart';
import '../../models/class_model.dart';
import '../../models/supervisor_dashboard_model.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/supervision_provider.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/stats_card.dart';
import 'class_students_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  static const Duration _liveRefreshInterval = Duration(seconds: 12);

  DateTime _selectedDate = DateTime.now();
  SupervisorTrendRange _trendRange = SupervisorTrendRange.daily;
  String? _selectedRoom;
  int? _selectedClassId;
  bool _liveMode = true;
  String _tableSearch = '';
  int _sortColumnIndex = 6;
  bool _sortAscending = false;
  Timer? _liveRefreshTimer;

  String t(String text, {Map<String, String> params = const {}}) =>
      context.t(text, params: params);

  bool get _isTodaySelected {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboard(refreshClasses: true);
      context.read<SupervisionProvider>().fetchOverview();
      _syncLiveRefresh();
    });
  }

  @override
  void dispose() {
    _liveRefreshTimer?.cancel();
    super.dispose();
  }

  void _loadDashboard({bool refreshClasses = false}) {
    context.read<AttendanceProvider>().fetchSupervisorDashboard(
      selectedDate: _selectedDate,
      trendRange: _trendRange,
      roomFilter: _selectedRoom,
      classIdFilter: _selectedClassId,
      refreshClasses: refreshClasses,
    );
  }

  void _syncLiveRefresh() {
    _liveRefreshTimer?.cancel();
    if (!_liveMode || !_isTodaySelected) {
      return;
    }

    _liveRefreshTimer = Timer.periodic(_liveRefreshInterval, (_) {
      if (!mounted) {
        return;
      }
      _loadDashboard();
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDate: _selectedDate,
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _selectedDate = picked;
    });
    _syncLiveRefresh();
    _loadDashboard();
  }

  Future<void> _showCreateGroupDialog() async {
    final language = context.language;
    final supervision = context.read<SupervisionProvider>();
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    var isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(language.tr('createTeacherGroup')),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      enabled: !isSubmitting,
                      decoration: InputDecoration(
                        labelText: language.tr('groupName'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      enabled: !isSubmitting,
                      minLines: 3,
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: language.tr('groupDescription'),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: Text(language.tr('cancel')),
                ),
                FilledButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final trimmedName = nameController.text.trim();
                          if (trimmedName.length < 2) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  language.tr(
                                    'Name must be at least 2 characters',
                                  ),
                                ),
                                backgroundColor: AppTheme.errorColor,
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isSubmitting = true);
                          final createdGroup = await supervision.createGroup(
                            name: trimmedName,
                            description: descriptionController.text,
                          );
                          if (!mounted || !dialogContext.mounted) {
                            return;
                          }
                          if (createdGroup != null) {
                            Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(language.tr('groupCreated')),
                                backgroundColor: AppTheme.successColor,
                              ),
                            );
                          } else {
                            setDialogState(() => isSubmitting = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  supervision.error ??
                                      language.tr('operationFailed'),
                                ),
                                backgroundColor: AppTheme.errorColor,
                              ),
                            );
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(language.tr('createGroup')),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    descriptionController.dispose();
  }

  void _onTrendRangeChanged(SupervisorTrendRange value) {
    if (_trendRange == value) {
      return;
    }
    setState(() => _trendRange = value);
    _loadDashboard();
  }

  void _onRoomChanged(String? value, SupervisorDashboardData data) {
    final nextClassOptions = data.availableClasses.where((classObj) {
      if (value == null || value.isEmpty) {
        return true;
      }
      final room = classObj.room?.trim();
      return (room == null || room.isEmpty ? 'Room not assigned' : room) ==
          value;
    }).toList();

    setState(() {
      _selectedRoom = value;
      if (_selectedClassId != null &&
          nextClassOptions.every(
            (classObj) => classObj.id != _selectedClassId,
          )) {
        _selectedClassId = null;
      }
    });
    _loadDashboard();
  }

  void _onClassChanged(int? value) {
    setState(() => _selectedClassId = value);
    _loadDashboard();
  }

  void _onLiveModeChanged(bool value) {
    setState(() => _liveMode = value);
    _syncLiveRefresh();
    if (value && _isTodaySelected) {
      _loadDashboard();
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedDate = DateTime.now();
      _trendRange = SupervisorTrendRange.daily;
      _selectedRoom = null;
      _selectedClassId = null;
      _liveMode = true;
      _tableSearch = '';
      _sortColumnIndex = 6;
      _sortAscending = false;
    });
    _syncLiveRefresh();
    _loadDashboard(refreshClasses: true);
  }

  void _setSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  List<ClassAttendanceRow> _sortedRows(List<ClassAttendanceRow> rows) {
    final filteredRows = rows.where((row) {
      if (_tableSearch.trim().isEmpty) {
        return true;
      }

      final query = _tableSearch.trim().toLowerCase();
      return row.className.toLowerCase().contains(query) ||
          row.roomName.toLowerCase().contains(query);
    }).toList();

    int compareNumbers(num a, num b) => a.compareTo(b);

    filteredRows.sort((a, b) {
      final result = switch (_sortColumnIndex) {
        0 => a.className.toLowerCase().compareTo(b.className.toLowerCase()),
        1 => compareNumbers(a.totalStudents, b.totalStudents),
        2 => compareNumbers(a.present, b.present),
        3 => compareNumbers(a.absent, b.absent),
        4 => compareNumbers(a.late, b.late),
        5 => compareNumbers(a.attendancePercentage, b.attendancePercentage),
        6 => compareNumbers(a.proxyFlags, b.proxyFlags),
        _ => a.className.toLowerCase().compareTo(b.className.toLowerCase()),
      };
      return _sortAscending ? result : -result;
    });

    return filteredRows;
  }

  Future<void> _openClassDetails(ClassAttendanceRow row) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClassStudentsScreen(classObj: row.sourceClass),
      ),
    );
    if (!mounted) {
      return;
    }
    _loadDashboard(refreshClasses: true);
  }

  void _showSummaryDialog(
    String title,
    String description, {
    List<Widget> children = const [],
  }) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t(title)),
        content: SizedBox(
          width: ResponsiveLayout.dialogWidth(context, maxWidth: 520),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t(description),
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
                if (children.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ...children,
                ],
              ],
            ),
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

  void _showRoomDetails(RoomMonitorItem room, SupervisorDashboardData data) {
    final roomRows = data.classRows
        .where((row) => row.roomName == room.roomName)
        .toList();
    final roomLogs = data.recentLogs
        .where((log) => log.room == room.roomName)
        .toList();
    final roomAlerts = data.alerts
        .where((alert) => alert.roomName == room.roomName)
        .toList();

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(room.roomName),
        content: SizedBox(
          width: ResponsiveLayout.dialogWidth(context, maxWidth: 620),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _MetricPill(
                      label: 'Camera',
                      value: room.cameraStatus.toUpperCase(),
                      color: _statusColorForCamera(room.cameraStatus),
                    ),
                    _MetricPill(
                      label: 'Scan',
                      value: room.scanStatus.toUpperCase(),
                      color: _statusColorForScan(room.scanStatus),
                    ),
                    _MetricPill(
                      label: 'Accuracy',
                      value:
                          '${room.recognitionAccuracy.toStringAsFixed(room.recognitionAccuracy == 0 ? 0 : 1)}%',
                      color: AppTheme.secondaryColor,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  t('Classes in this room'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                ...roomRows.map(
                  (row) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _DetailLine(
                      title: row.className,
                      value:
                          '${row.present} present • ${row.late} late • ${row.absent} absent',
                    ),
                  ),
                ),
                if (roomLogs.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    t('Recent room activity'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...roomLogs
                      .take(4)
                      .map(
                        (log) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _DetailLine(
                            title:
                                '${DateFormat('HH:mm:ss').format(log.time)} • ${log.personLabel}',
                            value:
                                '${log.method} • ${_logResultLabel(log.result)}',
                          ),
                        ),
                      ),
                ],
                if (roomAlerts.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    t('Room alerts'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...roomAlerts.map(
                    (alert) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _DetailLine(
                        title: alert.title,
                        value: alert.description,
                      ),
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
            child: Text(t('Close')),
          ),
        ],
      ),
    );
  }

  Widget _buildAmbientBackground() {
    return Stack(
      children: [
        Positioned(
          top: -120,
          left: -40,
          child: IgnorePointer(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.secondaryColor.withValues(alpha: 0.16),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 180,
          right: -60,
          child: IgnorePointer(
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primaryColor.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -120,
          left: 220,
          child: IgnorePointer(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.accentColor.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = ResponsiveLayout.pagePadding(
      context,
      compact: 12,
      mobile: 16,
      tablet: 20,
      desktop: 24,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(t('Supervisor Dashboard')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            tooltip: t('Manual Refresh'),
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _loadDashboard(refreshClasses: true),
          ),
          IconButton(
            tooltip: t('Attendance Reports'),
            icon: const Icon(Icons.assessment_outlined),
            onPressed: () => Navigator.pushNamed(context, '/admin/reports'),
          ),
          IconButton(
            tooltip: t('Export Center'),
            icon: const Icon(Icons.download_for_offline_rounded),
            onPressed: () => Navigator.pushNamed(context, '/export-center'),
          ),
        ],
      ),
      body: Consumer<AttendanceProvider>(
        builder: (context, provider, _) {
          final data = provider.supervisorDashboard;

          if (provider.isSupervisorDashboardLoading && data == null) {
            return const _DashboardLoadingSkeleton();
          }

          if (provider.supervisorDashboardError != null && data == null) {
            return _DashboardErrorState(
              message: provider.supervisorDashboardError!,
              onRetry: () => _loadDashboard(refreshClasses: true),
            );
          }

          if (data == null) {
            return _DashboardErrorState(
              message: t('No dashboard data available.'),
              onRetry: () => _loadDashboard(refreshClasses: true),
            );
          }

          final classOptions =
              data.availableClasses.where((classObj) {
                if (_selectedRoom == null || _selectedRoom!.isEmpty) {
                  return true;
                }
                final room = classObj.room?.trim();
                return (room == null || room.isEmpty
                        ? 'Room not assigned'
                        : room) ==
                    _selectedRoom;
              }).toList()..sort(
                (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
              );

          final tableRows = _sortedRows(data.classRows);

          return Stack(
            children: [
              Positioned.fill(child: _buildAmbientBackground()),
              RefreshIndicator(
                onRefresh: () async => _loadDashboard(refreshClasses: true),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: padding,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: ResponsiveLayout.contentMaxWidth(context),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (provider.isSupervisorDashboardLoading)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 14),
                              child: LinearProgressIndicator(minHeight: 3),
                            ),
                          if (provider.supervisorDashboardError != null)
                            _InlineMessageBanner(
                              title: 'Dashboard refresh warning',
                              message: provider.supervisorDashboardError!,
                              color: AppTheme.warningColor,
                            ),
                          _buildHeader(data),
                          const SizedBox(height: 20),
                          _buildFiltersBar(data, classOptions),
                          const SizedBox(height: 20),
                          _buildSummaryGrid(data),
                          const SizedBox(height: 24),
                          _buildFeatureRolloutRow(data),
                          const SizedBox(height: 24),
                          _buildMainAnalyticsRow(data),
                          const SizedBox(height: 24),
                          _buildClassTableSection(tableRows),
                          const SizedBox(height: 24),
                          _buildReviewPanels(data),
                          const SizedBox(height: 36),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(SupervisorDashboardData data) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      runSpacing: 16,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('Facial Recognition Operations'),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ).animate().fadeIn(),
              const SizedBox(height: 8),
              Text(
                t(
                  'Monitor detection quality, room activity, attendance reliability, and flagged behavior across lecture halls.',
                ),
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ).animate().fadeIn(delay: 80.ms),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _MetricPill(
                    label: 'Snapshot',
                    value: DateFormat(
                      'EEEE, MMM d, yyyy',
                    ).format(_selectedDate),
                    color: AppTheme.secondaryColor,
                  ),
                  _MetricPill(
                    label: 'Last refresh',
                    value: DateFormat('HH:mm:ss').format(data.lastRefreshed),
                    color: AppTheme.successColor,
                  ),
                  if (data.usesDerivedSignals)
                    Tooltip(
                      message:
                          'This dashboard is currently synthesized from attendance, room scan, and class schedule signals.',
                      child: const _MetricPill(
                        label: 'Telemetry',
                        value: 'Derived live signals',
                        color: AppTheme.primaryLight,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            Consumer<SupervisionProvider>(
              builder: (context, supervision, _) {
                final canCreateGroups =
                    supervision.overview?.canCreateGroups ?? true;
                if (!canCreateGroups) {
                  return const SizedBox.shrink();
                }

                return FilledButton.icon(
                  onPressed: supervision.isSubmitting
                      ? null
                      : _showCreateGroupDialog,
                  icon: const Icon(Icons.groups_2_rounded),
                  label: Text(context.tr('createGroup')),
                );
              },
            ),
            OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/supervision'),
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text(context.tr('supervisorHub')),
            ),
            OutlinedButton.icon(
              onPressed: () =>
                  Navigator.pushNamed(context, '/admin/attendance'),
              icon: const Icon(Icons.fact_check_outlined),
              label: Text(t('Review Attendance')),
            ),
            OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/guardian-portal'),
              icon: const Icon(Icons.family_restroom_rounded),
              label: Text(context.tr('guardianPortal')),
            ),
            OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/export-center'),
              icon: const Icon(Icons.file_download_outlined),
              label: Text(t('Export Attendance')),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/admin/reports'),
              icon: const Icon(Icons.report_gmailerrorred_outlined),
              label: Text(t('Investigate Flags')),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFiltersBar(
    SupervisorDashboardData data,
    List<ClassModel> classOptions,
  ) {
    final liveEnabled = _isTodaySelected;
    final dashboardWidth = ResponsiveLayout.width(context);
    final roomFilterWidth = dashboardWidth >= 1600 ? 220.0 : 210.0;
    final classFilterWidth = dashboardWidth >= 1600 ? 250.0 : 230.0;
    final hasFilters =
        _selectedRoom != null ||
        _selectedClassId != null ||
        !_isTodaySelected ||
        _trendRange != SupervisorTrendRange.daily ||
        !_liveMode ||
        _tableSearch.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.cardDecoration(),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today_rounded, size: 18),
            label: Text(DateFormat('MMM d, yyyy').format(_selectedDate)),
          ),
          _TrendToggle(selected: _trendRange, onChanged: _onTrendRangeChanged),
          SizedBox(
            width: roomFilterWidth,
            child: _FilterDropdown<String>(
              label: 'Room',
              value: _selectedRoom,
              hint: 'All rooms',
              items: data.availableRooms,
              itemLabel: (value) => value,
              onChanged: (value) => _onRoomChanged(value, data),
            ),
          ),
          SizedBox(
            width: classFilterWidth,
            child: _FilterDropdown<int>(
              label: 'Class',
              value: _selectedClassId,
              hint: 'All classes',
              items: classOptions.map((classObj) => classObj.id).toList(),
              itemLabel: (value) => classOptions
                  .firstWhere((classObj) => classObj.id == value)
                  .name,
              onChanged: _onClassChanged,
            ),
          ),
          _LiveModeSwitch(
            enabled: liveEnabled,
            value: liveEnabled && _liveMode,
            onChanged: _onLiveModeChanged,
          ),
          if (hasFilters)
            TextButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.close_rounded),
              label: Text(t('Clear filters')),
            ),
        ],
      ),
    ).animate().fadeIn(delay: 120.ms).slideY(begin: -0.04, end: 0);
  }

  Widget _buildSummaryGrid(SupervisorDashboardData data) {
    final width = ResponsiveLayout.width(context);
    final crossAxisCount = width >= 1450
        ? 5
        : width >= 1080
        ? 3
        : width >= 680
        ? 2
        : 1;

    final cards = <_KpiConfig>[
      _KpiConfig(
        title: 'Total Faces Detected',
        value: '${data.summary.totalFacesDetected}',
        icon: Icons.groups_2_rounded,
        color: AppTheme.secondaryColor,
        onTap: () {
          _showSummaryDialog(
            'Total Faces Detected',
            'Estimated face detections synthesized from recognition telemetry in the selected dashboard scope.',
            children: data.roomMonitors
                .map(
                  (room) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _DetailLine(
                      title: room.roomName,
                      value: '${room.facesDetected} detections',
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
      _KpiConfig(
        title: 'Successfully Recognized',
        value: '${data.summary.successfullyRecognized}',
        icon: Icons.verified_user_rounded,
        color: AppTheme.successColor,
        onTap: () {
          _showSummaryDialog(
            'Successfully Recognized',
            'Recognized identities with acceptable confidence across face and room-scan attendance events.',
            children: data.roomMonitors
                .map(
                  (room) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _DetailLine(
                      title: room.roomName,
                      value: '${room.recognized} recognized',
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
      _KpiConfig(
        title: 'Unknown Faces',
        value: '${data.summary.unknownFaces}',
        icon: Icons.person_search_rounded,
        color: AppTheme.errorColor,
        onTap: () {
          final unknownLogs = data.recentLogs
              .where((log) => log.result == RecognitionLogResult.unknown)
              .toList();
          _showSummaryDialog(
            'Unknown Faces',
            unknownLogs.isEmpty
                ? 'No unknown-face events were detected in the current slice.'
                : 'Recent low-confidence or unmatched recognition events that need review.',
            children: unknownLogs
                .map(
                  (log) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _DetailLine(
                      title:
                          '${DateFormat('HH:mm:ss').format(log.time)} • ${log.personLabel}',
                      value:
                          '${log.className} • ${log.confidence == null ? 'N/A' : '${(log.confidence! * 100).toStringAsFixed(0)}%'}',
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
      _KpiConfig(
        title: 'Proxy Alerts',
        value: '${data.summary.proxyAlerts}',
        icon: Icons.warning_amber_rounded,
        color: AppTheme.accentColor,
        onTap: () {
          _showSummaryDialog(
            'Proxy Alerts',
            'Suspicious patterns include duplicate attempts, fallback methods, and high unknown-face ratios.',
            children: data.suspiciousActivities
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _DetailLine(
                      title: item.title,
                      value: item.description,
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
      _KpiConfig(
        title: 'Recognition Accuracy',
        value:
            '${data.summary.recognitionAccuracy.toStringAsFixed(data.summary.recognitionAccuracy == 0 ? 0 : 1)}%',
        icon: Icons.track_changes_rounded,
        color: AppTheme.primaryLight,
        onTap: () {
          _showSummaryDialog(
            'Recognition Accuracy',
            'Recognition accuracy is calculated as recognized detections divided by total detected face signals.',
            children: data.roomMonitors
                .map(
                  (room) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _DetailLine(
                      title: room.roomName,
                      value:
                          '${room.recognitionAccuracy.toStringAsFixed(room.recognitionAccuracy == 0 ? 0 : 1)}%',
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    ];

    final childAspectRatio = crossAxisCount == 1
        ? 2.3
        : crossAxisCount == 2
        ? 1.8
        : crossAxisCount == 3
        ? 1.35
        : 1.05;

    return GridView.builder(
      itemCount: cards.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: childAspectRatio,
      ),
      itemBuilder: (context, index) {
        final card = cards[index];
        return StatsCard(
          title: card.title,
          value: card.value,
          icon: card.icon,
          iconColor: card.color,
          onTap: card.onTap,
          animationIndex: index,
        );
      },
    );
  }

  Widget _buildFeatureRolloutRow(SupervisorDashboardData data) {
    final wideLayout = ResponsiveLayout.width(context) >= 1180;

    if (!wideLayout) {
      return Column(
        children: [
          _buildLiveStreamPanel(data),
          const SizedBox(height: 20),
          _buildFeatureLaunchpadPanel(),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 5, child: _buildLiveStreamPanel(data)),
        const SizedBox(width: 20),
        Expanded(flex: 7, child: _buildFeatureLaunchpadPanel()),
      ],
    );
  }

  Widget _buildLiveStreamPanel(SupervisorDashboardData data) {
    final isLiveActive = _isTodaySelected && _liveMode;

    return _DashboardPanel(
      title: 'liveStreamTitle',
      subtitle: isLiveActive
          ? context.tr(
              'liveStreamPollingFallback',
              params: {'seconds': '${_liveRefreshInterval.inSeconds}'},
            )
          : (_isTodaySelected
                ? context.tr('liveStreamPaused')
                : context.tr('liveStreamSelectToday')),
      useKeyTranslation: true,
      action: _MetricPill(
        label: 'Mode',
        value: isLiveActive ? 'Polling' : 'Paused',
        color: isLiveActive ? AppTheme.successColor : AppTheme.warningColor,
      ),
      height: 340,
      child: data.recentLogs.isEmpty
          ? _EmptyPanelState(
              icon: Icons.wifi_tethering_error_rounded,
              title: 'No recent recognition events',
              subtitle: context.tr('socketReadyFallback'),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.bgElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.glassBorder, width: 0.7),
                  ),
                  child: Text(
                    context.tr('socketReadyFallback'),
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: math.min(data.recentLogs.length, 5),
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final log = data.recentLogs[index];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.bgElevated,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.glassBorder,
                            width: 0.7,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ResultAvatar(result: log.result),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    log.personLabel,
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${log.className} • ${log.room}',
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              DateFormat('HH:mm:ss').format(log.time),
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    ).animate().fadeIn(delay: 160.ms);
  }

  Widget _buildFeatureLaunchpadPanel() {
    final language = context.read<LanguageProvider>();

    return _DashboardPanel(
      title: 'featureLaunchpad',
      subtitle: 'featureLaunchpadDescription',
      useKeyTranslation: true,
      height: 340,
      child: ListView(
        children: [
          _FeatureLaunchTile(
            icon: Icons.grid_view_rounded,
            title: context.tr('scheduleBuilder'),
            description: context.tr('scheduleBuilderDescription'),
            color: AppTheme.primaryColor,
            actionLabel: context.tr('openClassBuilder'),
            onPressed: () => Navigator.pushNamed(context, '/admin/classes'),
          ),
          const SizedBox(height: 12),
          _FeatureLaunchTile(
            icon: Icons.family_restroom_rounded,
            title: context.tr('guardianPortal'),
            description: context.tr('guardianPortalDescription'),
            color: AppTheme.secondaryColor,
            actionLabel: context.tr('openGuardianPreview'),
            onPressed: () => Navigator.pushNamed(context, '/guardian-portal'),
          ),
          const SizedBox(height: 12),
          _FeatureLaunchTile(
            icon: Icons.translate_rounded,
            title: context.tr('arabicSupport'),
            description: context.tr('arabicSupportDescription'),
            color: AppTheme.accentColor,
            actionLabel: language.isArabic
                ? context.tr('arabicActive')
                : context.tr('switchToArabic'),
            onPressed: language.isArabic
                ? null
                : () => context.read<LanguageProvider>().setLanguageCode(
                    AppStrings.arabicCode,
                  ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 210.ms);
  }

  Widget _buildMainAnalyticsRow(SupervisorDashboardData data) {
    final wideLayout = ResponsiveLayout.width(context) >= 1180;

    if (!wideLayout) {
      return Column(
        children: [
          _buildRoomMonitorPanel(data),
          const SizedBox(height: 20),
          _buildTrendPanel(data),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 5, child: _buildRoomMonitorPanel(data)),
        const SizedBox(width: 20),
        Expanded(flex: 7, child: _buildTrendPanel(data)),
      ],
    );
  }

  Widget _buildRoomMonitorPanel(SupervisorDashboardData data) {
    return _DashboardPanel(
      title: 'Live Room Monitor',
      subtitle: _isTodaySelected && _liveMode
          ? 'Auto-refreshing every ${_liveRefreshInterval.inSeconds}s while live mode is enabled.'
          : 'Room health snapshot for the selected date.',
      action: _MetricPill(
        label: 'Rooms',
        value: '${data.roomMonitors.length}',
        color: AppTheme.secondaryColor,
      ),
      height: 430,
      child: data.roomMonitors.isEmpty
          ? const _EmptyPanelState(
              icon: Icons.videocam_off_rounded,
              title: 'No active room data available',
              subtitle:
                  'Adjust the date or filters, or wait for new recognition activity.',
            )
          : ListView.separated(
              itemCount: data.roomMonitors.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final room = data.roomMonitors[index];
                return _RoomMonitorCard(
                  room: room,
                  onTap: () => _showRoomDetails(room, data),
                );
              },
            ),
    ).animate().fadeIn(delay: 180.ms);
  }

  Widget _buildTrendPanel(SupervisorDashboardData data) {
    final trend = data.trend;
    final maxY = [
      ...trend.map((point) => point.present),
      ...trend.map((point) => point.late),
      ...trend.map((point) => point.absent),
      1,
    ].reduce((a, b) => a > b ? a : b).toDouble();

    return _DashboardPanel(
      title: 'Attendance Trend Chart',
      subtitle:
          '${data.trendRange.label} attendance pattern for present, absent, and late activity.',
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          _LegendDot(label: 'Present', color: AppTheme.successColor),
          SizedBox(width: 10),
          _LegendDot(label: 'Late', color: AppTheme.accentColor),
          SizedBox(width: 10),
          _LegendDot(label: 'Absent', color: AppTheme.errorColor),
        ],
      ),
      height: 430,
      child:
          trend.every(
            (point) =>
                point.present == 0 && point.absent == 0 && point.late == 0,
          )
          ? const _EmptyPanelState(
              icon: Icons.show_chart_rounded,
              title: 'No attendance records for selected date',
              subtitle:
                  'Trend data will appear once class attendance is recorded.',
            )
          : LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY + 2,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: AppTheme.glassBorder, strokeWidth: 0.6),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= trend.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            trend[index].label,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipRoundedRadius: 12,
                    tooltipBgColor: AppTheme.bgElevated,
                    getTooltipItems: (spots) {
                      return spots.map((spot) {
                        final point = trend[spot.x.toInt()];
                        final series = spot.barIndex == 0
                            ? 'Present'
                            : spot.barIndex == 1
                            ? 'Late'
                            : 'Absent';
                        return LineTooltipItem(
                          '${point.label}\n$series: ${spot.y.toInt()}',
                          const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  _trendLine(
                    trend,
                    (point) => point.present.toDouble(),
                    AppTheme.successColor,
                  ),
                  _trendLine(
                    trend,
                    (point) => point.late.toDouble(),
                    AppTheme.accentColor,
                  ),
                  _trendLine(
                    trend,
                    (point) => point.absent.toDouble(),
                    AppTheme.errorColor,
                  ),
                ],
              ),
            ),
    ).animate().fadeIn(delay: 220.ms);
  }

  LineChartBarData _trendLine(
    List<TrendPoint> trend,
    double Function(TrendPoint point) valueFor,
    Color color,
  ) {
    return LineChartBarData(
      isCurved: true,
      curveSmoothness: 0.28,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
          radius: 2.5,
          color: color,
          strokeWidth: 1.2,
          strokeColor: AppTheme.bgBase,
        ),
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.02),
          ],
        ),
      ),
      spots: trend.asMap().entries.map((entry) {
        return FlSpot(entry.key.toDouble(), valueFor(entry.value));
      }).toList(),
    );
  }

  Widget _buildClassTableSection(List<ClassAttendanceRow> rows) {
    final isDesktop = ResponsiveLayout.width(context) >= 940;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('Class-wise Attendance Table'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t(
                      'Sortable attendance comparison by class, with risk emphasis on proxy flags and low performance.',
                    ),
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: TextField(
                  onChanged: (value) => setState(() => _tableSearch = value),
                  decoration: InputDecoration(
                    hintText: t('Search classes or rooms'),
                    prefixIcon: const Icon(Icons.search_rounded),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (rows.isEmpty)
            const _EmptyPanelState(
              icon: Icons.table_rows_outlined,
              title: 'No class attendance records for selected date',
              subtitle:
                  'Classes will appear here once the selected date has scheduled sessions or recorded attendance.',
            )
          else if (isDesktop)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                sortColumnIndex: _sortColumnIndex,
                sortAscending: _sortAscending,
                headingRowColor: WidgetStatePropertyAll(
                  AppTheme.bgElevated.withValues(alpha: 0.9),
                ),
                columns: [
                  DataColumn(label: Text(t('Class Name')), onSort: _setSort),
                  DataColumn(
                    numeric: true,
                    label: Text(t('Total Students')),
                    onSort: _setSort,
                  ),
                  DataColumn(
                    numeric: true,
                    label: Text(t('Present')),
                    onSort: _setSort,
                  ),
                  DataColumn(
                    numeric: true,
                    label: Text(t('Absent')),
                    onSort: _setSort,
                  ),
                  DataColumn(
                    numeric: true,
                    label: Text(t('Late')),
                    onSort: _setSort,
                  ),
                  DataColumn(
                    numeric: true,
                    label: Text(t('Attendance %')),
                    onSort: _setSort,
                  ),
                  DataColumn(
                    numeric: true,
                    label: Text(t('Proxy Flags')),
                    onSort: _setSort,
                  ),
                ],
                rows: rows.map((row) {
                  final highlightColor = row.proxyFlags > 0
                      ? AppTheme.errorColor.withValues(alpha: 0.08)
                      : row.attendancePercentage < 75
                      ? AppTheme.accentColor.withValues(alpha: 0.07)
                      : Colors.transparent;

                  return DataRow(
                    color: WidgetStatePropertyAll(highlightColor),
                    onSelectChanged: (_) => _openClassDetails(row),
                    cells: [
                      DataCell(
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row.className,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              row.roomName,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      DataCell(Text('${row.totalStudents}')),
                      DataCell(Text('${row.present}')),
                      DataCell(Text('${row.absent}')),
                      DataCell(Text('${row.late}')),
                      DataCell(
                        Text(
                          '${row.attendancePercentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: row.attendancePercentage < 75
                                ? AppTheme.accentColor
                                : AppTheme.successColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      DataCell(
                        _RiskBadge(
                          value: '${row.proxyFlags}',
                          color: row.proxyFlags > 0
                              ? AppTheme.errorColor
                              : AppTheme.successColor,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            )
          else
            Column(
              children: rows.map((row) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ClassAttendanceCard(
                    row: row,
                    onTap: () => _openClassDetails(row),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    ).animate().fadeIn(delay: 260.ms);
  }

  Widget _buildReviewPanels(SupervisorDashboardData data) {
    final wideLayout = ResponsiveLayout.width(context) >= 1350;
    final mediumLayout = ResponsiveLayout.width(context) >= 960;

    if (wideLayout) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildLogsPanel(data)),
          const SizedBox(width: 20),
          Expanded(child: _buildSuspiciousPanel(data)),
          const SizedBox(width: 20),
          Expanded(child: _buildAlertsPanel(data)),
        ],
      );
    }

    if (mediumLayout) {
      return Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildLogsPanel(data)),
              const SizedBox(width: 20),
              Expanded(child: _buildSuspiciousPanel(data)),
            ],
          ),
          const SizedBox(height: 20),
          _buildAlertsPanel(data),
        ],
      );
    }

    return Column(
      children: [
        _buildLogsPanel(data),
        const SizedBox(height: 20),
        _buildSuspiciousPanel(data),
        const SizedBox(height: 20),
        _buildAlertsPanel(data),
      ],
    );
  }

  Widget _buildLogsPanel(SupervisorDashboardData data) {
    return _DashboardPanel(
      title: 'Recent Recognition Logs',
      subtitle: 'Latest recognition events and their confidence outcome.',
      height: 360,
      child: data.recentLogs.isEmpty
          ? const _EmptyPanelState(
              icon: Icons.history_toggle_off_rounded,
              title: 'No recent recognition events',
              subtitle:
                  'Recognition logs will appear after room activity begins.',
            )
          : ListView.separated(
              itemCount: data.recentLogs.length,
              separatorBuilder: (_, _) => const Divider(height: 14),
              itemBuilder: (context, index) {
                final log = data.recentLogs[index];
                return InkWell(
                  onTap: () {
                    _showSummaryDialog(
                      'Recognition Log',
                      '${log.personLabel} • ${DateFormat('HH:mm:ss').format(log.time)}',
                      children: [
                        _DetailLine(title: 'Room', value: log.room),
                        _DetailLine(title: 'Class', value: log.className),
                        _DetailLine(
                          title: 'Result',
                          value: _logResultLabel(log.result),
                        ),
                        _DetailLine(title: 'Method', value: log.method),
                        _DetailLine(
                          title: 'Confidence',
                          value: log.confidence == null
                              ? 'N/A'
                              : '${(log.confidence! * 100).toStringAsFixed(0)}%',
                        ),
                        if (log.notes?.trim().isNotEmpty == true)
                          _DetailLine(title: 'Notes', value: log.notes!.trim()),
                      ],
                    );
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 6,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ResultAvatar(result: log.result),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                log.personLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${log.room} • ${log.method}',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              DateFormat('HH:mm:ss').format(log.time),
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              log.confidence == null
                                  ? _logResultLabel(log.result)
                                  : '${(log.confidence! * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 12,
                                color: _resultColor(log.result),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildSuspiciousPanel(SupervisorDashboardData data) {
    return _DashboardPanel(
      title: 'Suspicious Activity Panel',
      subtitle: 'Proxy-related, fallback, duplicate, and confidence anomalies.',
      height: 360,
      child: data.suspiciousActivities.isEmpty
          ? const _EmptyPanelState(
              icon: Icons.shield_outlined,
              title: 'No suspicious activity detected',
              subtitle:
                  'Flagged behavior will surface here when signals appear.',
            )
          : ListView.separated(
              itemCount: data.suspiciousActivities.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = data.suspiciousActivities[index];
                return _ActivityTile(
                  title: item.title,
                  description: item.description,
                  severity: item.severity,
                  timestamp: item.timestamp,
                  onTap: () {
                    _showSummaryDialog(
                      item.title,
                      item.description,
                      children: [
                        if (item.className != null)
                          _DetailLine(title: 'Class', value: item.className!),
                        if (item.roomName != null)
                          _DetailLine(title: 'Room', value: item.roomName!),
                        if (item.timestamp != null)
                          _DetailLine(
                            title: 'Time',
                            value: DateFormat(
                              'MMM d, HH:mm:ss',
                            ).format(item.timestamp!),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildAlertsPanel(SupervisorDashboardData data) {
    return _DashboardPanel(
      title: 'Notifications / Alerts',
      subtitle:
          'Operational health, room availability, and recognition quality alerts.',
      height: 360,
      child: ListView.separated(
        itemCount: data.alerts.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final alert = data.alerts[index];
          return _ActivityTile(
            title: alert.title,
            description: alert.description,
            severity: alert.severity,
            timestamp: alert.timestamp,
            onTap: () {
              _showSummaryDialog(
                alert.title,
                alert.description,
                children: [
                  if (alert.roomName != null)
                    _DetailLine(title: 'Room', value: alert.roomName!),
                  if (alert.timestamp != null)
                    _DetailLine(
                      title: 'Time',
                      value: DateFormat(
                        'MMM d, HH:mm:ss',
                      ).format(alert.timestamp!),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Color _statusColorForCamera(String status) {
    switch (status) {
      case 'online':
        return AppTheme.successColor;
      case 'error':
        return AppTheme.errorColor;
      default:
        return AppTheme.accentColor;
    }
  }

  Color _statusColorForScan(String status) {
    switch (status) {
      case 'scanning':
        return AppTheme.secondaryColor;
      case 'paused':
        return AppTheme.accentColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  Color _resultColor(RecognitionLogResult result) {
    switch (result) {
      case RecognitionLogResult.recognized:
        return AppTheme.successColor;
      case RecognitionLogResult.unknown:
        return AppTheme.errorColor;
      case RecognitionLogResult.flagged:
        return AppTheme.accentColor;
    }
  }

  String _logResultLabel(RecognitionLogResult result) {
    switch (result) {
      case RecognitionLogResult.recognized:
        return 'Recognized';
      case RecognitionLogResult.unknown:
        return 'Unknown';
      case RecognitionLogResult.flagged:
        return 'Flagged';
    }
  }
}

class _KpiConfig {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _KpiConfig({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _DashboardPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;
  final double? height;
  final bool useKeyTranslation;

  const _DashboardPanel({
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
    this.height,
    this.useKeyTranslation = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      useKeyTranslation ? context.tr(title) : context.t(title),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      useKeyTranslation
                          ? context.tr(subtitle)
                          : context.t(subtitle),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (action != null) ...[action!],
            ],
          ),
          const SizedBox(height: 18),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _FeatureLaunchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final String actionLabel;
  final VoidCallback? onPressed;

  const _FeatureLaunchTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.actionLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.glassBorder, width: 0.7),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: onPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: onPressed == null
                        ? AppTheme.bgBase
                        : color,
                    foregroundColor: onPressed == null
                        ? AppTheme.textMuted
                        : Colors.white,
                  ),
                  child: Text(actionLabel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final String hint;
  final List<T> items;
  final String Function(T value) itemLabel;
  final ValueChanged<T?> onChanged;

  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.hint,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: context.t(label),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
      ),
      hint: Text(context.t(hint)),
      items: items
          .map(
            (item) => DropdownMenuItem<T>(
              value: item,
              child: Text(itemLabel(item), overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _TrendToggle extends StatelessWidget {
  final SupervisorTrendRange selected;
  final ValueChanged<SupervisorTrendRange> onChanged;

  const _TrendToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.bgElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.glassBorder, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: SupervisorTrendRange.values.map((range) {
          final isSelected = range == selected;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: GestureDetector(
              onTap: () => onChanged(range),
              child: AnimatedContainer(
                duration: AppTheme.animFast,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  context.t(range.label),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _LiveModeSwitch extends StatelessWidget {
  final bool enabled;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _LiveModeSwitch({
    required this.enabled,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: AppTheme.animFast,
      opacity: enabled ? 1 : 0.55,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.bgElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.glassBorder, width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value ? Icons.sync_rounded : Icons.pause_circle_outline_rounded,
              size: 18,
              color: value ? AppTheme.secondaryColor : AppTheme.textSecondary,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('Live mode'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  enabled
                      ? context.t('Auto refresh room telemetry')
                      : context.t('Available only for today'),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Switch.adaptive(
              value: enabled && value,
              onChanged: enabled ? onChanged : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomMonitorCard extends StatelessWidget {
  final RoomMonitorItem room;
  final VoidCallback onTap;

  const _RoomMonitorCard({required this.room, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cameraColor = switch (room.cameraStatus) {
      'online' => AppTheme.successColor,
      'error' => AppTheme.errorColor,
      _ => AppTheme.accentColor,
    };
    final scanColor = switch (room.scanStatus) {
      'scanning' => AppTheme.secondaryColor,
      'paused' => AppTheme.accentColor,
      _ => AppTheme.textSecondary,
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.bgElevated.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: room.cameraStatus == 'error'
                ? AppTheme.errorColor.withValues(alpha: 0.35)
                : AppTheme.glassBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.roomName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      room.classNames.join(', '),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatusChip(label: room.cameraStatus, color: cameraColor),
                    _StatusChip(label: room.scanStatus, color: scanColor),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MetricPill(
                  label: 'Faces',
                  value: '${room.facesDetected}',
                  color: AppTheme.secondaryColor,
                ),
                _MetricPill(
                  label: 'Recognized',
                  value: '${room.recognized}',
                  color: AppTheme.successColor,
                ),
                _MetricPill(
                  label: 'Unknown',
                  value: '${room.unknown}',
                  color: AppTheme.errorColor,
                ),
                _MetricPill(
                  label: 'Alerts',
                  value: '${room.alerts}',
                  color: AppTheme.accentColor,
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: room.facesDetected == 0
                    ? 0
                    : room.recognitionAccuracy / 100,
                minHeight: 7,
                backgroundColor: AppTheme.bgCard,
                valueColor: AlwaysStoppedAnimation<Color>(
                  room.recognitionAccuracy >= 85
                      ? AppTheme.successColor
                      : room.recognitionAccuracy >= 70
                      ? AppTheme.accentColor
                      : AppTheme.errorColor,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              room.lastUpdated == null
                  ? context.t('No recent camera update')
                  : context.t(
                      'Last updated {time}',
                      params: {
                        'time': DateFormat(
                          'HH:mm:ss',
                        ).format(room.lastUpdated!),
                      },
                    ),
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        context.t(label[0].toUpperCase() + label.substring(1)),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendDot({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          context.t(label),
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '${context.t(label)}: ',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RiskBadge extends StatelessWidget {
  final String value;
  final Color color;

  const _RiskBadge({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        value,
        style: TextStyle(fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}

class _ClassAttendanceCard extends StatelessWidget {
  final ClassAttendanceRow row;
  final VoidCallback onTap;

  const _ClassAttendanceCard({required this.row, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final borderColor = row.proxyFlags > 0
        ? AppTheme.errorColor.withValues(alpha: 0.35)
        : row.attendancePercentage < 75
        ? AppTheme.accentColor.withValues(alpha: 0.28)
        : AppTheme.glassBorder;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.bgElevated.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              row.className,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              row.roomName,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MetricPill(
                  label: 'Students',
                  value: '${row.totalStudents}',
                  color: AppTheme.secondaryColor,
                ),
                _MetricPill(
                  label: 'Present',
                  value: '${row.present}',
                  color: AppTheme.successColor,
                ),
                _MetricPill(
                  label: 'Late',
                  value: '${row.late}',
                  color: AppTheme.accentColor,
                ),
                _MetricPill(
                  label: 'Absent',
                  value: '${row.absent}',
                  color: AppTheme.errorColor,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: row.totalStudents == 0
                          ? 0
                          : (row.present + row.late) / row.totalStudents,
                      minHeight: 7,
                      backgroundColor: AppTheme.bgCard,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        row.attendancePercentage < 75
                            ? AppTheme.accentColor
                            : AppTheme.successColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${row.attendancePercentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: row.attendancePercentage < 75
                        ? AppTheme.accentColor
                        : AppTheme.successColor,
                  ),
                ),
                const SizedBox(width: 10),
                _RiskBadge(
                  value: '${row.proxyFlags}',
                  color: row.proxyFlags > 0
                      ? AppTheme.errorColor
                      : AppTheme.successColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final String title;
  final String description;
  final DashboardSeverity severity;
  final DateTime? timestamp;
  final VoidCallback onTap;

  const _ActivityTile({
    required this.title,
    required this.description,
    required this.severity,
    required this.timestamp,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (severity) {
      DashboardSeverity.critical => AppTheme.errorColor,
      DashboardSeverity.warning => AppTheme.accentColor,
      DashboardSeverity.success => AppTheme.successColor,
      DashboardSeverity.info => AppTheme.secondaryColor,
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (timestamp != null) ...[
              const SizedBox(width: 10),
              Text(
                DateFormat('HH:mm').format(timestamp!),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultAvatar extends StatelessWidget {
  final RecognitionLogResult result;

  const _ResultAvatar({required this.result});

  @override
  Widget build(BuildContext context) {
    final color = switch (result) {
      RecognitionLogResult.recognized => AppTheme.successColor,
      RecognitionLogResult.unknown => AppTheme.errorColor,
      RecognitionLogResult.flagged => AppTheme.accentColor,
    };
    final icon = switch (result) {
      RecognitionLogResult.recognized => Icons.check_circle_rounded,
      RecognitionLogResult.unknown => Icons.person_search_rounded,
      RecognitionLogResult.flagged => Icons.warning_amber_rounded,
    };

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}

class _InlineMessageBanner extends StatelessWidget {
  final String title;
  final String message;
  final Color color;

  const _InlineMessageBanner({
    required this.title,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t(title),
                  style: TextStyle(fontWeight: FontWeight.w700, color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  final String title;
  final String value;

  const _DetailLine({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(color: AppTheme.textSecondary, height: 1.4),
        ),
      ],
    );
  }
}

class _EmptyPanelState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyPanelState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 44, color: AppTheme.textMuted),
            const SizedBox(height: 12),
            Text(
              context.t(title),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              context.t(subtitle),
              style: const TextStyle(
                color: AppTheme.textSecondary,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _DashboardErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: AppTheme.cardDecoration(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 52,
                  color: AppTheme.errorColor,
                ),
                const SizedBox(height: 16),
                Text(
                  context.t('Dashboard unavailable'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(context.t('Retry')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardLoadingSkeleton extends StatelessWidget {
  const _DashboardLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    final width = ResponsiveLayout.width(context);
    final crossAxisCount = width >= 1450
        ? 5
        : width >= 1080
        ? 3
        : width >= 680
        ? 2
        : 1;

    return Shimmer.fromColors(
      baseColor: AppTheme.bgElevated,
      highlightColor: AppTheme.glassHighlight.withValues(alpha: 0.9),
      child: SingleChildScrollView(
        padding: ResponsiveLayout.pagePadding(context),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: ResponsiveLayout.contentMaxWidth(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SkeletonBlock(width: 360, height: 34),
                const SizedBox(height: 12),
                const _SkeletonBlock(width: 620, height: 16),
                const SizedBox(height: 20),
                const _SkeletonBlock(height: 84),
                const SizedBox(height: 20),
                GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.4,
                  children: List.generate(
                    5,
                    (_) => const _SkeletonBlock(height: 150),
                  ),
                ),
                const SizedBox(height: 24),
                const _SkeletonBlock(height: 420),
                const SizedBox(height: 24),
                const _SkeletonBlock(height: 340),
                const SizedBox(height: 24),
                const _SkeletonBlock(height: 320),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  final double? width;
  final double height;

  const _SkeletonBlock({this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
    );
  }
}
