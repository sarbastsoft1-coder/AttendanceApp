import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../config/api_config.dart';
import '../models/captured_image.dart';
import '../models/attendance_model.dart';
import '../models/class_model.dart';
import '../models/settings_model.dart';
import '../models/supervisor_dashboard_model.dart';
import '../services/api_service.dart';
import '../models/user_model.dart';
import '../utils/download_text_file_stub.dart'
    if (dart.library.html) '../utils/download_text_file_web.dart'
    as download_text_file;

/// Attendance Provider - Handles attendance marking and history
class AttendanceProvider with ChangeNotifier {
  final ApiService _api = ApiService();

  List<Attendance> _todayAttendance = [];
  List<Attendance> _history = [];
  List<Attendance> _allAttendance = [];
  List<Attendance> _classAttendance = [];
  List<User> _allUsers = [];
  AttendanceStats? _stats;
  DashboardStats? _dashboardStats;
  AnalyticsData? _analyticsData;
  SupervisorDashboardData? _supervisorDashboard;
  List<ClassModel> _supervisorDashboardClasses = [];
  bool _isLoading = false;
  bool _isSupervisorDashboardLoading = false;
  String? _error;
  String? _supervisorDashboardError;
  Attendance? _lastMarkedAttendance;

  // Pagination state for history
  int _historyPage = 1;
  int _historyTotalPages = 1;
  int _historyTotal = 0;
  static const int _historyPageSize = 20;

  // Getters
  List<Attendance> get todayAttendance => _todayAttendance;
  List<Attendance> get history => _history;
  List<Attendance> get allAttendance => _allAttendance;
  List<Attendance> get classAttendance => _classAttendance;
  List<User> get allUsers => _allUsers;
  AttendanceStats? get stats => _stats;
  DashboardStats? get dashboardStats => _dashboardStats;
  AnalyticsData? get analyticsData => _analyticsData;
  SupervisorDashboardData? get supervisorDashboard => _supervisorDashboard;
  bool get isLoading => _isLoading;
  bool get isSupervisorDashboardLoading => _isSupervisorDashboardLoading;
  String? get error => _error;
  String? get supervisorDashboardError => _supervisorDashboardError;
  Attendance? get lastMarkedAttendance => _lastMarkedAttendance;

  // Pagination getters
  int get historyPage => _historyPage;
  int get historyTotalPages => _historyTotalPages;
  int get historyTotal => _historyTotal;
  bool get hasMoreHistory => _historyPage < _historyTotalPages;

  /// Mark attendance using face recognition
  Future<bool> markAttendance(CapturedImage image, {String? location}) async {
    _setLoading(true);
    _error = null;
    _lastMarkedAttendance = null;

    try {
      final multipartFile = MultipartFile.fromBytes(
        image.bytes,
        filename: image.filename,
      );

      final response = await _api.uploadSingleFile(
        ApiConfig.markAttendance,
        file: multipartFile,
        fieldName: 'image',
        additionalFields: {
          if (location != null && location.isNotEmpty) 'location': location,
        },
      );

      _lastMarkedAttendance = Attendance.fromJson(response.data);

      // Refresh today's attendance
      await fetchTodayAttendance();

      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  /// Check out using face recognition
  Future<bool> checkOut(CapturedImage image) async {
    _setLoading(true);
    _error = null;

    try {
      final multipartFile = MultipartFile.fromBytes(
        image.bytes,
        filename: image.filename,
      );

      await _api.uploadSingleFile(
        ApiConfig.checkOut,
        file: multipartFile,
        fieldName: 'image',
      );

      // Refresh today's attendance
      await fetchTodayAttendance();

      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  /// Fetch today's attendance
  Future<void> fetchTodayAttendance() async {
    try {
      final response = await _api.get(ApiConfig.todayAttendance);
      _todayAttendance = (response.data as List)
          .map((json) => Attendance.fromJson(json))
          .toList();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching today attendance: $e');
      }
    }
  }

  /// Fetch attendance history (paginated)
  Future<void> fetchHistory({
    DateTime? startDate,
    DateTime? endDate,
    int? userId,
    String? statusFilter,
    int page = 1,
    bool append = false,
  }) async {
    _setLoading(true);

    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'page_size': _historyPageSize,
      };
      if (startDate != null) {
        queryParams['start_date'] = startDate.toIso8601String().split('T')[0];
      }
      if (endDate != null) {
        queryParams['end_date'] = endDate.toIso8601String().split('T')[0];
      }
      if (userId != null) {
        queryParams['user_id'] = userId;
      }
      if (statusFilter != null && statusFilter != 'All') {
        queryParams['status_filter'] = statusFilter.toLowerCase();
      }

      final response = await _api.get(
        ApiConfig.attendanceHistory,
        queryParameters: queryParams,
      );

      final paginated = PaginatedAttendance.fromJson(response.data);
      _historyPage = paginated.page;
      _historyTotalPages = paginated.totalPages;
      _historyTotal = paginated.total;

      if (append && page > 1) {
        _history = [..._history, ...paginated.items];
      } else {
        _history = paginated.items;
      }

      _setLoading(false);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
    }
  }

  /// Load the next page of history (for infinite scroll / load more)
  Future<void> fetchNextHistoryPage({
    DateTime? startDate,
    DateTime? endDate,
    int? userId,
    String? statusFilter,
  }) async {
    if (!hasMoreHistory || _isLoading) return;
    await fetchHistory(
      startDate: startDate,
      endDate: endDate,
      userId: userId,
      statusFilter: statusFilter,
      page: _historyPage + 1,
      append: true,
    );
  }

  /// Fetch attendance statistics
  Future<void> fetchStats(int userId, {int? month, int? year}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (month != null) queryParams['month'] = month;
      if (year != null) queryParams['year'] = year;

      final response = await _api.get(
        ApiConfig.attendanceStats(userId),
        queryParameters: queryParams,
      );

      _stats = AttendanceStats.fromJson(response.data);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching stats: $e');
      }
    }
  }

  /// Fetch dashboard stats (admin only)
  Future<void> fetchDashboardStats() async {
    try {
      final response = await _api.get(ApiConfig.adminDashboard);
      _dashboardStats = DashboardStats.fromJson(response.data);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching dashboard stats: $e');
      }
    }
  }

  Future<void> fetchSupervisorDashboard({
    DateTime? selectedDate,
    SupervisorTrendRange trendRange = SupervisorTrendRange.daily,
    String? roomFilter,
    int? classIdFilter,
    bool refreshClasses = false,
  }) async {
    final targetDate = _normalizeDate(selectedDate ?? DateTime.now());
    final trimmedRoomFilter = roomFilter?.trim();
    final effectiveRoomFilter =
        trimmedRoomFilter == null || trimmedRoomFilter.isEmpty
        ? null
        : trimmedRoomFilter;

    _setSupervisorDashboardLoading(true);
    _supervisorDashboardError = null;

    try {
      if (refreshClasses || _supervisorDashboardClasses.isEmpty) {
        final classesResponse = await _api.get(ApiConfig.classes);
        _supervisorDashboardClasses =
            (classesResponse.data as List)
                .map((json) => ClassModel.fromJson(json))
                .toList()
              ..sort(
                (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
              );
      }

      final availableRooms =
          _supervisorDashboardClasses
              .map(_roomNameForClass)
              .where((room) => room.trim().isNotEmpty)
              .toSet()
              .toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      final filteredClasses =
          _supervisorDashboardClasses.where((classObj) {
            final matchesRoom = effectiveRoomFilter == null
                ? true
                : _roomNameForClass(classObj) == effectiveRoomFilter;
            final matchesClass = classIdFilter == null
                ? true
                : classObj.id == classIdFilter;
            return matchesRoom && matchesClass;
          }).toList()..sort((a, b) {
            final roomCompare = _roomNameForClass(
              a,
            ).toLowerCase().compareTo(_roomNameForClass(b).toLowerCase());
            if (roomCompare != 0) {
              return roomCompare;
            }
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });

      final trendWindow = _trendWindowFor(targetDate, trendRange);
      final attendanceByClassId = <int, List<Attendance>>{};

      if (filteredClasses.isNotEmpty) {
        final classResponses = await Future.wait(
          filteredClasses.map((classObj) async {
            final response = await _api.get(
              ApiConfig.classAttendance(classObj.id),
              queryParameters: {
                'start_date': _formatDate(trendWindow.start),
                'end_date': _formatDate(trendWindow.end),
              },
            );

            final records =
                (response.data as List)
                    .map((json) => Attendance.fromJson(json))
                    .toList()
                  ..sort(
                    (a, b) =>
                        _recordTimestamp(b).compareTo(_recordTimestamp(a)),
                  );

            return MapEntry(classObj.id, records);
          }),
        );

        attendanceByClassId.addEntries(classResponses);
      }

      final attendanceIndex = <int, Map<String, List<Attendance>>>{};
      for (final entry in attendanceByClassId.entries) {
        final recordsByDate = <String, List<Attendance>>{};
        for (final record in entry.value) {
          final dateKey = _formatDate(_normalizeDate(record.date));
          recordsByDate.putIfAbsent(dateKey, () => <Attendance>[]).add(record);
        }
        attendanceIndex[entry.key] = recordsByDate;
      }

      final forceIncludeClass =
          effectiveRoomFilter != null || classIdFilter != null;
      final selectedDayKey = _formatDate(targetDate);
      final telemetryByClassId = <int, _ClassTelemetry>{};
      final classRows = <ClassAttendanceRow>[];

      for (final classObj in filteredClasses) {
        final dayRecords =
            attendanceIndex[classObj.id]?[selectedDayKey] ??
            const <Attendance>[];
        final telemetry = _buildClassTelemetry(
          classObj,
          dayRecords,
          targetDate,
          forceInclude: forceIncludeClass,
        );
        telemetryByClassId[classObj.id] = telemetry;

        if (!telemetry.visible) {
          continue;
        }

        classRows.add(
          ClassAttendanceRow(
            classId: classObj.id.toString(),
            className: classObj.name,
            totalStudents: classObj.studentCount,
            present: telemetry.presentCount,
            absent: telemetry.absentCount,
            late: telemetry.lateCount,
            attendancePercentage: telemetry.attendancePercentage,
            proxyFlags: telemetry.proxyFlags,
            roomName: _roomNameForClass(classObj),
            scheduled: telemetry.scheduled,
            sourceClass: classObj,
          ),
        );
      }

      final selectedDayRecords =
          filteredClasses
              .expand(
                (classObj) =>
                    attendanceIndex[classObj.id]?[selectedDayKey] ??
                    const <Attendance>[],
              )
              .toList()
            ..sort(
              (a, b) => _recordTimestamp(b).compareTo(_recordTimestamp(a)),
            );

      final classesById = <int, ClassModel>{
        for (final classObj in filteredClasses) classObj.id: classObj,
      };

      final trend = _buildTrend(
        filteredClasses,
        attendanceIndex,
        targetDate,
        trendRange,
      );
      final recentLogs = _buildRecognitionLogs(selectedDayRecords, classesById);
      final suspiciousActivities = _buildSuspiciousActivities(
        selectedDayRecords,
        classRows,
        telemetryByClassId,
      );
      final summary = _buildSupervisorSummary(
        telemetryByClassId,
        suspiciousActivities,
      );
      final roomMonitors = _buildRoomMonitors(
        classRows,
        telemetryByClassId,
        targetDate,
        DateTime.now(),
      );
      final alerts = _buildDashboardAlerts(summary, roomMonitors, targetDate);

      _supervisorDashboard = SupervisorDashboardData(
        selectedDate: targetDate,
        lastRefreshed: DateTime.now(),
        trendRange: trendRange,
        roomFilter: effectiveRoomFilter,
        classFilterId: classIdFilter,
        availableClasses: List<ClassModel>.unmodifiable(
          _supervisorDashboardClasses,
        ),
        availableRooms: List<String>.unmodifiable(availableRooms),
        summary: summary,
        roomMonitors: List<RoomMonitorItem>.unmodifiable(roomMonitors),
        trend: List<TrendPoint>.unmodifiable(trend),
        classRows: List<ClassAttendanceRow>.unmodifiable(classRows),
        recentLogs: List<RecognitionLogEntry>.unmodifiable(recentLogs),
        suspiciousActivities: List<SuspiciousActivityItem>.unmodifiable(
          suspiciousActivities,
        ),
        alerts: List<DashboardAlertItem>.unmodifiable(alerts),
      );

      _isSupervisorDashboardLoading = false;
      notifyListeners();
    } catch (e) {
      _supervisorDashboardError = e.toString().replaceFirst('Exception: ', '');
      _isSupervisorDashboardLoading = false;
      notifyListeners();
    }
  }

  /// Check if user has already marked attendance today
  bool hasMarkedToday(int userId) {
    return _todayAttendance.any((a) => a.userId == userId);
  }

  /// Get user's today attendance
  Attendance? getUserTodayAttendance(int userId) {
    try {
      return _todayAttendance.firstWhere((a) => a.userId == userId);
    } catch (e) {
      return null;
    }
  }

  /// Perform group room scan to identify multiple students
  Future<RoomScanResult?> performRoomScan(
    CapturedImage image, {
    String? department,
    int? classId,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      final multipartFile = MultipartFile.fromBytes(
        image.bytes,
        filename: image.filename,
      );

      final Map<String, dynamic> additionalFields = {};
      if (department != null && department.isNotEmpty) {
        additionalFields['department'] = department;
      }
      if (classId != null) {
        additionalFields['class_id'] = classId.toString();
      }

      final response = await _api.uploadSingleFile(
        ApiConfig.roomScan,
        file: multipartFile,
        fieldName: 'image',
        additionalFields: additionalFields,
      );

      final result = RoomScanResult.fromJson(response.data);

      // Keep the scan result even if the secondary refresh fails.
      try {
        await fetchTodayAttendance();
      } catch (_) {}

      _setLoading(false);
      return result;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
      return null;
    }
  }

  /// Fetch all users (admin only)
  Future<void> fetchAllUsers() async {
    _setLoading(true);
    try {
      final response = await _api.get(ApiConfig.users);
      _allUsers = (response.data as List)
          .map((json) => User.fromJson(json))
          .toList();
      _setLoading(false);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
    }
  }

  Future<User?> createUser({
    required String email,
    required String fullName,
    required String password,
    required String role,
    String? phone,
    String? department,
    String? adminAccessKey,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      final response = await _api.post(
        ApiConfig.users,
        data: {
          'email': email,
          'full_name': fullName,
          'password': password,
          'phone': phone,
          'department': department,
          'role': role,
          if (adminAccessKey != null && adminAccessKey.trim().isNotEmpty)
            'admin_access_key': adminAccessKey.trim(),
        },
      );
      final createdUser = User.fromJson(response.data);
      _allUsers = [createdUser, ..._allUsers];
      _setLoading(false);
      return createdUser;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
      return null;
    }
  }

  /// Fetch all attendance records (admin only, paginated)
  Future<void> fetchAllAttendance({
    DateTime? startDate,
    DateTime? endDate,
    String? statusFilter,
    int page = 1,
  }) async {
    _setLoading(true);
    try {
      final queryParams = <String, dynamic>{'page': page, 'page_size': 50};
      if (startDate != null) {
        queryParams['start_date'] = startDate.toIso8601String().split('T')[0];
      }
      if (endDate != null) {
        queryParams['end_date'] = endDate.toIso8601String().split('T')[0];
      }
      if (statusFilter != null && statusFilter != 'all') {
        queryParams['status_filter'] = statusFilter;
      }

      final response = await _api.get(
        ApiConfig.attendanceHistory,
        queryParameters: queryParams,
      );

      final paginated = PaginatedAttendance.fromJson(response.data);
      _allAttendance = paginated.items;

      _setLoading(false);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
    }
  }

  /// Update attendance status manually (admin only)
  Future<bool> updateAttendanceStatus(
    int attendanceId,
    String status, {
    String? notes,
  }) async {
    _setLoading(true);
    try {
      final Map<String, dynamic> body = {'status': status};
      if (notes != null && notes.isNotEmpty) body['notes'] = notes;

      final response = await _api.patch(
        ApiConfig.updateAttendance(attendanceId),
        data: body,
      );

      // Update local state
      final updatedAttendance = Attendance.fromJson(response.data);

      int index = _history.indexWhere((a) => a.id == attendanceId);
      if (index != -1) _history[index] = updatedAttendance;

      index = _todayAttendance.indexWhere((a) => a.id == attendanceId);
      if (index != -1) _todayAttendance[index] = updatedAttendance;

      index = _allAttendance.indexWhere((a) => a.id == attendanceId);
      if (index != -1) _allAttendance[index] = updatedAttendance;

      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  /// Fetch attendance for a specific class
  Future<void> fetchClassAttendance(int classId, {DateTime? date}) async {
    _setLoading(true);
    try {
      final queryParams = <String, dynamic>{};
      if (date != null) {
        final formatted = date.toIso8601String().split('T')[0];
        queryParams['start_date'] = formatted;
        queryParams['end_date'] = formatted;
      }
      final response = await _api.get(
        ApiConfig.classAttendance(classId),
        queryParameters: queryParams,
      );
      _classAttendance = (response.data as List)
          .map((json) => Attendance.fromJson(json))
          .toList();
      _setLoading(false);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
    }
  }

  Future<bool> submitRollCall({
    required int classId,
    required DateTime attendanceDate,
    required List<Map<String, dynamic>> entries,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      await _api.post(
        ApiConfig.rollCall,
        data: {
          'class_id': classId,
          'attendance_date': attendanceDate.toIso8601String(),
          'entries': entries,
        },
      );
      await fetchClassAttendance(classId, date: attendanceDate);
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  /// Export attendance to CSV — returns the CSV content as a String
  Future<String?> exportAttendance({
    DateTime? start,
    DateTime? end,
    int? classId,
    int? userId,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      final queryParams = <String, dynamic>{};
      if (start != null) {
        queryParams['start_date'] = start.toIso8601String().split('T')[0];
      }
      if (end != null) {
        queryParams['end_date'] = end.toIso8601String().split('T')[0];
      }
      if (classId != null) queryParams['class_id'] = classId;
      if (userId != null) queryParams['user_id'] = userId;

      final response = await _api.getPlainText(
        ApiConfig.exportAttendance,
        queryParameters: queryParams,
      );
      final content = response.data ?? '';

      if (kIsWeb) {
        final fileName =
            'attendance_export_${DateTime.now().millisecondsSinceEpoch}.csv';
        await download_text_file.downloadTextFile(fileName, content);
        _setLoading(false);
        return fileName;
      }

      final downloads = !kIsWeb ? await getDownloadsDirectory() : null;
      final directory = downloads ?? await getApplicationDocumentsDirectory();
      final fileName =
          'attendance_export_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File(path.join(directory.path, fileName));
      await file.writeAsString(content);

      _setLoading(false);
      return file.path;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
      return null;
    }
  }

  /// Manual attendance entry (teacher/admin)
  Future<Attendance?> manualAttendance({
    int? userId,
    int? studentId,
    int? classId,
    required String status,
    DateTime? attendanceDate,
    String? notes,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      final data = <String, dynamic>{'status': status};
      if (userId != null) {
        data['user_id'] = userId;
      }
      if (studentId != null) {
        data['student_id'] = studentId;
      }
      if (classId != null) {
        data['class_id'] = classId;
      }
      if (attendanceDate != null) {
        data['attendance_date'] = attendanceDate.toIso8601String();
      }
      if (notes != null && notes.isNotEmpty) {
        data['notes'] = notes;
      }

      final response = await _api.post(ApiConfig.manualAttendance, data: data);
      final attendance = Attendance.fromJson(response.data);
      _upsertAttendanceRecord(_allAttendance, attendance);
      _upsertAttendanceRecord(_history, attendance);

      final isToday = _isSameCalendarDay(attendance.date, DateTime.now());
      if (isToday) {
        _upsertAttendanceRecord(_todayAttendance, attendance);
      } else {
        _todayAttendance.removeWhere((record) => record.id == attendance.id);
      }

      _setLoading(false);
      return attendance;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
      return null;
    }
  }

  /// Fetch analytics data (admin only)
  Future<void> fetchAnalytics({int days = 30}) async {
    _setLoading(true);
    _error = null;
    try {
      final response = await _api.get(
        ApiConfig.adminAnalytics,
        queryParameters: {'days': days},
      );
      _analyticsData = AnalyticsData.fromJson(response.data);
      _setLoading(false);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
    }
  }

  /// Delete user (admin only)
  Future<bool> deleteUser(int userId) async {
    try {
      await _api.delete('${ApiConfig.users}/$userId');
      _allUsers.removeWhere((u) => u.id == userId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    _supervisorDashboardError = null;
    notifyListeners();
  }

  List<TrendPoint> _buildTrend(
    List<ClassModel> classes,
    Map<int, Map<String, List<Attendance>>> attendanceIndex,
    DateTime selectedDate,
    SupervisorTrendRange trendRange,
  ) {
    final window = _trendWindowFor(selectedDate, trendRange);
    final points = <TrendPoint>[];

    switch (trendRange) {
      case SupervisorTrendRange.daily:
        for (var offset = 0; offset < 7; offset++) {
          final day = _normalizeDate(window.start.add(Duration(days: offset)));
          final counts = _aggregateCountsForDay(classes, attendanceIndex, day);
          points.add(
            TrendPoint(
              label: DateFormat('EEE').format(day),
              present: counts.present,
              absent: counts.absent,
              late: counts.late,
            ),
          );
        }
        break;
      case SupervisorTrendRange.weekly:
        for (var offset = 0; offset < 8; offset++) {
          final bucketStart = _normalizeDate(
            window.start.add(Duration(days: offset * 7)),
          );
          final bucketEnd = _normalizeDate(
            bucketStart.add(const Duration(days: 6)),
          );
          final counts = _aggregateCountsForDateRange(
            classes,
            attendanceIndex,
            bucketStart,
            bucketEnd,
          );
          points.add(
            TrendPoint(
              label: DateFormat('MMM d').format(bucketStart),
              present: counts.present,
              absent: counts.absent,
              late: counts.late,
            ),
          );
        }
        break;
      case SupervisorTrendRange.monthly:
        final firstMonth = DateTime(window.start.year, window.start.month, 1);
        for (var offset = 0; offset < 6; offset++) {
          final monthStart = DateTime(
            firstMonth.year,
            firstMonth.month + offset,
            1,
          );
          final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 0);
          final counts = _aggregateCountsForDateRange(
            classes,
            attendanceIndex,
            monthStart,
            monthEnd,
          );
          points.add(
            TrendPoint(
              label: DateFormat('MMM').format(monthStart),
              present: counts.present,
              absent: counts.absent,
              late: counts.late,
            ),
          );
        }
        break;
    }

    return points;
  }

  List<RecognitionLogEntry> _buildRecognitionLogs(
    List<Attendance> dayRecords,
    Map<int, ClassModel> classesById,
  ) {
    final duplicateKeys = _duplicatePersonKeys(dayRecords);

    return dayRecords.take(12).map((record) {
      final classObj = record.classId != null
          ? classesById[record.classId!]
          : null;
      final roomName = classObj != null
          ? _roomNameForClass(classObj)
          : 'Room not assigned';

      return RecognitionLogEntry(
        id: 'log-${record.id}',
        time: _recordTimestamp(record),
        personLabel: record.displayName,
        room: roomName,
        className: record.className ?? classObj?.name ?? 'Unknown class',
        result: _recognitionResultForRecord(
          record,
          isDuplicate: duplicateKeys.contains(_personKey(record)),
        ),
        confidence: record.confidence,
        method: _methodLabel(record.method),
        notes: record.notes,
      );
    }).toList();
  }

  List<SuspiciousActivityItem> _buildSuspiciousActivities(
    List<Attendance> dayRecords,
    List<ClassAttendanceRow> classRows,
    Map<int, _ClassTelemetry> telemetryByClassId,
  ) {
    final items = <SuspiciousActivityItem>[];
    final duplicateGroups = <String, List<Attendance>>{};

    for (final record in dayRecords) {
      final personKey = _personKey(record);
      duplicateGroups.putIfAbsent(personKey, () => <Attendance>[]).add(record);
    }

    for (final entry in duplicateGroups.entries) {
      if (entry.value.length < 2) {
        continue;
      }

      final latest = entry.value.first;
      items.add(
        SuspiciousActivityItem(
          id: 'duplicate-${entry.key}',
          title: 'Duplicate attendance attempt',
          description:
              '${latest.displayName} was recorded ${entry.value.length} times for the same attendance window.',
          severity: DashboardSeverity.critical,
          timestamp: _recordTimestamp(latest),
          roomName: latest.className,
          className: latest.className,
        ),
      );
    }

    for (final row in classRows) {
      final telemetry = telemetryByClassId[row.sourceClass.id];
      if (telemetry == null) {
        continue;
      }

      final facesDetected = telemetry.recognizedCount + telemetry.unknownCount;

      if (telemetry.lowConfidenceCount > 0) {
        items.add(
          SuspiciousActivityItem(
            id: 'low-confidence-${row.classId}',
            title: 'Low-confidence recognition',
            description:
                '${telemetry.lowConfidenceCount} scan event(s) in ${row.className} need manual review.',
            severity: telemetry.lowConfidenceCount > 2
                ? DashboardSeverity.critical
                : DashboardSeverity.warning,
            timestamp: telemetry.lastUpdated,
            roomName: row.roomName,
            className: row.className,
          ),
        );
      }

      if (telemetry.fallbackMethodCount > 0) {
        items.add(
          SuspiciousActivityItem(
            id: 'fallback-${row.classId}',
            title: 'Attendance captured outside facial scan',
            description:
                '${telemetry.fallbackMethodCount} record(s) in ${row.className} used manual or QR fallback.',
            severity: DashboardSeverity.warning,
            timestamp: telemetry.lastUpdated,
            roomName: row.roomName,
            className: row.className,
          ),
        );
      }

      if (facesDetected > 0 && telemetry.unknownCount / facesDetected >= 0.25) {
        items.add(
          SuspiciousActivityItem(
            id: 'unknown-ratio-${row.classId}',
            title: 'High unknown face ratio',
            description:
                '${row.className} has ${telemetry.unknownCount} unknown face signal(s) from ${facesDetected} detections.',
            severity: DashboardSeverity.critical,
            timestamp: telemetry.lastUpdated,
            roomName: row.roomName,
            className: row.className,
          ),
        );
      }
    }

    items.sort((a, b) {
      final severityCompare = _severityWeight(
        b.severity,
      ).compareTo(_severityWeight(a.severity));
      if (severityCompare != 0) {
        return severityCompare;
      }
      final aTime = a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    return items.take(10).toList();
  }

  SupervisorDashboardSummary _buildSupervisorSummary(
    Map<int, _ClassTelemetry> telemetryByClassId,
    List<SuspiciousActivityItem> suspiciousActivities,
  ) {
    var recognizedCount = 0;
    var unknownCount = 0;

    for (final telemetry in telemetryByClassId.values) {
      if (!telemetry.visible) {
        continue;
      }

      recognizedCount += telemetry.recognizedCount;
      unknownCount += telemetry.unknownCount;
    }

    final totalFacesDetected = recognizedCount + unknownCount;
    final recognitionAccuracy = totalFacesDetected > 0
        ? (recognizedCount / totalFacesDetected) * 100
        : 0.0;

    return SupervisorDashboardSummary(
      totalFacesDetected: totalFacesDetected,
      successfullyRecognized: recognizedCount,
      unknownFaces: unknownCount,
      proxyAlerts: suspiciousActivities.length,
      recognitionAccuracy: recognitionAccuracy,
    );
  }

  List<RoomMonitorItem> _buildRoomMonitors(
    List<ClassAttendanceRow> classRows,
    Map<int, _ClassTelemetry> telemetryByClassId,
    DateTime selectedDate,
    DateTime now,
  ) {
    final groupedRows = <String, List<ClassAttendanceRow>>{};

    for (final row in classRows) {
      groupedRows
          .putIfAbsent(row.roomName, () => <ClassAttendanceRow>[])
          .add(row);
    }

    final isTodaySnapshot = _isSameCalendarDay(selectedDate, now);
    final monitors = <RoomMonitorItem>[];

    for (final entry in groupedRows.entries) {
      final roomRows = entry.value;
      final telemetry = roomRows
          .map((row) => telemetryByClassId[row.sourceClass.id])
          .whereType<_ClassTelemetry>()
          .toList();

      var recognizedCount = 0;
      var unknownCount = 0;
      var alertsCount = 0;
      DateTime? lastUpdated;

      for (final item in telemetry) {
        recognizedCount += item.recognizedCount;
        unknownCount += item.unknownCount;
        alertsCount += item.proxyFlags;
        final itemLastUpdated = item.lastUpdated;
        if (itemLastUpdated != null &&
            (lastUpdated == null || itemLastUpdated.isAfter(lastUpdated))) {
          lastUpdated = itemLastUpdated;
        }
      }

      final facesDetected = recognizedCount + unknownCount;
      final recognitionAccuracy = facesDetected > 0
          ? (recognizedCount / facesDetected) * 100
          : 0.0;
      final unknownRatio = facesDetected > 0
          ? unknownCount / facesDetected
          : 0.0;
      final hasCriticalSignals =
          telemetry.any((item) => item.lowConfidenceCount > 0) ||
          unknownRatio >= 0.25;

      final cameraStatus = hasCriticalSignals
          ? 'error'
          : lastUpdated != null &&
                (!isTodaySnapshot ||
                    now.difference(lastUpdated).inMinutes <= 15)
          ? 'online'
          : 'offline';

      final hasScheduledClasses = roomRows.any((row) => row.scheduled);
      final scanStatus = !hasScheduledClasses
          ? 'idle'
          : isTodaySnapshot &&
                lastUpdated != null &&
                now.difference(lastUpdated).inMinutes <= 10
          ? 'scanning'
          : lastUpdated != null
          ? 'paused'
          : 'idle';

      monitors.add(
        RoomMonitorItem(
          id: 'room-${entry.key.toLowerCase().replaceAll(' ', '-')}',
          roomName: entry.key,
          cameraStatus: cameraStatus,
          scanStatus: scanStatus,
          facesDetected: facesDetected,
          recognized: recognizedCount,
          unknown: unknownCount,
          alerts: alertsCount,
          lastUpdated: lastUpdated,
          recognitionAccuracy: recognitionAccuracy,
          classIds: roomRows.map((row) => row.sourceClass.id).toList(),
          classNames: roomRows.map((row) => row.className).toList(),
        ),
      );
    }

    monitors.sort((a, b) {
      final aWeight = _severityWeight(_roomSeverity(a));
      final bWeight = _severityWeight(_roomSeverity(b));
      if (aWeight != bWeight) {
        return bWeight.compareTo(aWeight);
      }
      return a.roomName.toLowerCase().compareTo(b.roomName.toLowerCase());
    });

    return monitors;
  }

  List<DashboardAlertItem> _buildDashboardAlerts(
    SupervisorDashboardSummary summary,
    List<RoomMonitorItem> roomMonitors,
    DateTime selectedDate,
  ) {
    final alerts = <DashboardAlertItem>[];
    final isTodaySnapshot = _isSameCalendarDay(selectedDate, DateTime.now());

    if (summary.totalFacesDetected == 0) {
      alerts.add(
        DashboardAlertItem(
          id: 'alert-no-telemetry',
          title: 'No active room data available',
          description:
              'No recognition telemetry was captured for the selected date.',
          severity: DashboardSeverity.info,
          timestamp: null,
        ),
      );
    } else if (summary.recognitionAccuracy < 85) {
      alerts.add(
        DashboardAlertItem(
          id: 'alert-accuracy',
          title: 'Recognition rate dropped',
          description:
              'Recognition accuracy is ${summary.recognitionAccuracy.toStringAsFixed(1)}%, below the review threshold.',
          severity: summary.recognitionAccuracy < 70
              ? DashboardSeverity.critical
              : DashboardSeverity.warning,
          timestamp: DateTime.now(),
        ),
      );
    }

    if (summary.proxyAlerts > 0) {
      alerts.add(
        DashboardAlertItem(
          id: 'alert-proxy',
          title: 'Proxy attendance review required',
          description:
              '${summary.proxyAlerts} suspicious signal(s) were detected across the supervised rooms.',
          severity: DashboardSeverity.critical,
          timestamp: DateTime.now(),
        ),
      );
    }

    for (final room in roomMonitors.take(4)) {
      if (room.cameraStatus == 'error') {
        alerts.add(
          DashboardAlertItem(
            id: 'alert-room-error-${room.id}',
            title: '${room.roomName} needs review',
            description:
                'Unknown face ratio or confidence anomalies were detected in this room.',
            severity: DashboardSeverity.critical,
            timestamp: room.lastUpdated,
            roomName: room.roomName,
          ),
        );
      } else if (isTodaySnapshot && room.cameraStatus == 'offline') {
        alerts.add(
          DashboardAlertItem(
            id: 'alert-room-offline-${room.id}',
            title: '${room.roomName} camera disconnected',
            description:
                'No recent recognition updates were received from this room.',
            severity: DashboardSeverity.warning,
            timestamp: room.lastUpdated,
            roomName: room.roomName,
          ),
        );
      } else if (isTodaySnapshot && room.scanStatus == 'paused') {
        alerts.add(
          DashboardAlertItem(
            id: 'alert-room-paused-${room.id}',
            title: '${room.roomName} scan paused',
            description:
                'This room has attendance data, but the live scan is no longer updating.',
            severity: DashboardSeverity.info,
            timestamp: room.lastUpdated,
            roomName: room.roomName,
          ),
        );
      }
    }

    if (alerts.isEmpty) {
      alerts.add(
        DashboardAlertItem(
          id: 'alert-healthy',
          title: 'No suspicious activity detected',
          description:
              'Current room telemetry and attendance signals look healthy.',
          severity: DashboardSeverity.success,
          timestamp: DateTime.now(),
        ),
      );
    }

    alerts.sort((a, b) {
      final severityCompare = _severityWeight(
        b.severity,
      ).compareTo(_severityWeight(a.severity));
      if (severityCompare != 0) {
        return severityCompare;
      }
      final aTime = a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    return alerts.take(6).toList();
  }

  _ClassTelemetry _buildClassTelemetry(
    ClassModel classObj,
    List<Attendance> dayRecords,
    DateTime targetDate, {
    required bool forceInclude,
  }) {
    final sessionExpected =
        dayRecords.isNotEmpty || _isClassScheduledOnDate(classObj, targetDate);
    final visible = forceInclude || sessionExpected;
    final presentCount = dayRecords.where((record) {
      return _isPresentLikeStatus(record.status);
    }).length;
    final lateCount = dayRecords
        .where((record) => record.status == 'late')
        .length;
    final explicitAbsentCount = dayRecords
        .where((record) => record.status == 'absent')
        .length;
    final inferredAbsentCount = sessionExpected
        ? (classObj.studentCount - presentCount - lateCount).clamp(
            0,
            classObj.studentCount,
          )
        : 0;
    final absentCount = explicitAbsentCount > inferredAbsentCount
        ? explicitAbsentCount
        : inferredAbsentCount;
    final recognizedCount = dayRecords.where(_isRecognizedAttendance).length;
    final unknownCount = dayRecords.where(_isUnknownRecognitionSignal).length;
    final lowConfidenceCount = unknownCount;
    final fallbackMethodCount = dayRecords.where((record) {
      return _isAlternativeMethod(record.method) &&
          (_isPresentLikeStatus(record.status) || record.status == 'late');
    }).length;
    final duplicateAttempts = _countDuplicateAttempts(dayRecords);
    final attendancePercentage = classObj.studentCount > 0 && sessionExpected
        ? ((presentCount + lateCount) / classObj.studentCount) * 100
        : 0.0;

    DateTime? lastUpdated;
    for (final record in dayRecords) {
      final timestamp = _recordTimestamp(record);
      if (lastUpdated == null || timestamp.isAfter(lastUpdated)) {
        lastUpdated = timestamp;
      }
    }

    return _ClassTelemetry(
      visible: visible,
      scheduled: sessionExpected,
      presentCount: presentCount,
      lateCount: lateCount,
      absentCount: absentCount,
      recognizedCount: recognizedCount,
      unknownCount: unknownCount,
      lowConfidenceCount: lowConfidenceCount,
      fallbackMethodCount: fallbackMethodCount,
      duplicateAttempts: duplicateAttempts,
      attendancePercentage: attendancePercentage,
      lastUpdated: lastUpdated,
    );
  }

  _TrendCounts _aggregateCountsForDay(
    List<ClassModel> classes,
    Map<int, Map<String, List<Attendance>>> attendanceIndex,
    DateTime day,
  ) {
    var presentCount = 0;
    var lateCount = 0;
    var absentCount = 0;
    final dayKey = _formatDate(day);

    for (final classObj in classes) {
      final dayRecords =
          attendanceIndex[classObj.id]?[dayKey] ?? const <Attendance>[];
      final telemetry = _buildClassTelemetry(
        classObj,
        dayRecords,
        day,
        forceInclude: false,
      );

      if (!telemetry.scheduled) {
        continue;
      }

      presentCount += telemetry.presentCount;
      lateCount += telemetry.lateCount;
      absentCount += telemetry.absentCount;
    }

    return _TrendCounts(
      present: presentCount,
      late: lateCount,
      absent: absentCount,
    );
  }

  _TrendCounts _aggregateCountsForDateRange(
    List<ClassModel> classes,
    Map<int, Map<String, List<Attendance>>> attendanceIndex,
    DateTime start,
    DateTime end,
  ) {
    var combined = const _TrendCounts(present: 0, late: 0, absent: 0);
    var current = _normalizeDate(start);
    final normalizedEnd = _normalizeDate(end);

    while (!current.isAfter(normalizedEnd)) {
      combined =
          combined + _aggregateCountsForDay(classes, attendanceIndex, current);
      current = current.add(const Duration(days: 1));
    }

    return combined;
  }

  _TrendWindow _trendWindowFor(
    DateTime selectedDate,
    SupervisorTrendRange trendRange,
  ) {
    switch (trendRange) {
      case SupervisorTrendRange.daily:
        return _TrendWindow(
          start: _normalizeDate(selectedDate.subtract(const Duration(days: 6))),
          end: _normalizeDate(selectedDate),
        );
      case SupervisorTrendRange.weekly:
        final weekStart = _startOfWeek(selectedDate);
        return _TrendWindow(
          start: _normalizeDate(
            weekStart.subtract(const Duration(days: 7 * 7)),
          ),
          end: _normalizeDate(weekStart.add(const Duration(days: 6))),
        );
      case SupervisorTrendRange.monthly:
        final monthStart = DateTime(
          selectedDate.year,
          selectedDate.month - 5,
          1,
        );
        final monthEnd = DateTime(selectedDate.year, selectedDate.month + 1, 0);
        return _TrendWindow(
          start: _normalizeDate(monthStart),
          end: _normalizeDate(monthEnd),
        );
    }
  }

  DateTime _startOfWeek(DateTime date) {
    final normalized = _normalizeDate(date);
    final weekdayFromSunday = normalized.weekday % 7;
    return normalized.subtract(Duration(days: weekdayFromSunday));
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  String _roomNameForClass(ClassModel classObj) {
    final room = classObj.room?.trim();
    if (room == null || room.isEmpty) {
      return 'Room not assigned';
    }
    return room;
  }

  bool _isClassScheduledOnDate(ClassModel classObj, DateTime date) {
    if (classObj.meetingDays.isEmpty) {
      return false;
    }

    final weekday = _weekdayName(date).toLowerCase();
    return classObj.meetingDays.any(
      (day) => day.trim().toLowerCase() == weekday,
    );
  }

  String _weekdayName(DateTime date) {
    const weekdayNames = <String>[
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return weekdayNames[date.weekday - 1];
  }

  DateTime _recordTimestamp(Attendance record) {
    return record.checkInTime ?? record.date;
  }

  bool _isPresentLikeStatus(String status) {
    return status == 'present' || status == 'half_day';
  }

  bool _isRecognitionMethod(String method) {
    return method == 'face' || method == 'room_scan';
  }

  bool _isAlternativeMethod(String method) {
    return method == 'manual' || method == 'qr_code';
  }

  bool _isRecognizedAttendance(Attendance record) {
    if (!_isRecognitionMethod(record.method) || record.status == 'absent') {
      return false;
    }

    return !_isUnknownRecognitionSignal(record);
  }

  bool _isUnknownRecognitionSignal(Attendance record) {
    if (!_isRecognitionMethod(record.method) || record.status == 'absent') {
      return false;
    }

    if (_containsKeyword(record.notes, const [
      'unknown',
      'unmatched',
      'not recognized',
    ])) {
      return true;
    }

    final confidence = record.confidence;
    return confidence != null && confidence < 0.72;
  }

  bool _containsKeyword(String? source, List<String> keywords) {
    final normalized = source?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return false;
    }
    return keywords.any(normalized.contains);
  }

  int _countDuplicateAttempts(List<Attendance> records) {
    final counts = <String, int>{};

    for (final record in records) {
      if (record.status == 'absent') {
        continue;
      }
      final key = _personKey(record);
      counts.update(key, (value) => value + 1, ifAbsent: () => 1);
    }

    var duplicates = 0;
    for (final count in counts.values) {
      if (count > 1) {
        duplicates += count - 1;
      }
    }
    return duplicates;
  }

  Set<String> _duplicatePersonKeys(List<Attendance> records) {
    final counts = <String, int>{};

    for (final record in records) {
      if (record.status == 'absent') {
        continue;
      }
      final key = _personKey(record);
      counts.update(key, (value) => value + 1, ifAbsent: () => 1);
    }

    return counts.entries
        .where((entry) => entry.value > 1)
        .map((entry) => entry.key)
        .toSet();
  }

  String _personKey(Attendance record) {
    if (record.studentId != null) {
      return 'student:${record.studentId}';
    }
    if (record.userId != null) {
      return 'user:${record.userId}';
    }
    return '${record.displayName.toLowerCase()}:${record.classId ?? 0}';
  }

  RecognitionLogResult _recognitionResultForRecord(
    Attendance record, {
    required bool isDuplicate,
  }) {
    if (_isUnknownRecognitionSignal(record)) {
      return RecognitionLogResult.unknown;
    }

    if (isDuplicate ||
        _isAlternativeMethod(record.method) ||
        record.status == 'absent') {
      return RecognitionLogResult.flagged;
    }

    if (_isRecognizedAttendance(record)) {
      return RecognitionLogResult.recognized;
    }

    return RecognitionLogResult.flagged;
  }

  String _methodLabel(String method) {
    switch (method) {
      case 'face':
        return 'Face recognition';
      case 'room_scan':
        return 'Room scan';
      case 'manual':
        return 'Manual entry';
      case 'qr_code':
        return 'QR attendance';
      default:
        return method.replaceAll('_', ' ');
    }
  }

  DashboardSeverity _roomSeverity(RoomMonitorItem room) {
    if (room.cameraStatus == 'error') {
      return DashboardSeverity.critical;
    }
    if (room.cameraStatus == 'offline') {
      return DashboardSeverity.warning;
    }
    if (room.scanStatus == 'scanning') {
      return DashboardSeverity.success;
    }
    return DashboardSeverity.info;
  }

  int _severityWeight(DashboardSeverity severity) {
    switch (severity) {
      case DashboardSeverity.critical:
        return 4;
      case DashboardSeverity.warning:
        return 3;
      case DashboardSeverity.success:
        return 2;
      case DashboardSeverity.info:
        return 1;
    }
  }

  void _upsertAttendanceRecord(
    List<Attendance> records,
    Attendance attendance,
  ) {
    final index = records.indexWhere((record) => record.id == attendance.id);
    if (index == -1) {
      records.insert(0, attendance);
    } else {
      records[index] = attendance;
    }
    records.sort(
      (a, b) => (b.checkInTime ?? b.date).compareTo(a.checkInTime ?? a.date),
    );
  }

  bool _isSameCalendarDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _setSupervisorDashboardLoading(bool value) {
    _isSupervisorDashboardLoading = value;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}

class _TrendWindow {
  final DateTime start;
  final DateTime end;

  const _TrendWindow({required this.start, required this.end});
}

class _TrendCounts {
  final int present;
  final int late;
  final int absent;

  const _TrendCounts({
    required this.present,
    required this.late,
    required this.absent,
  });

  _TrendCounts operator +(_TrendCounts other) {
    return _TrendCounts(
      present: present + other.present,
      late: late + other.late,
      absent: absent + other.absent,
    );
  }
}

class _ClassTelemetry {
  final bool visible;
  final bool scheduled;
  final int presentCount;
  final int lateCount;
  final int absentCount;
  final int recognizedCount;
  final int unknownCount;
  final int lowConfidenceCount;
  final int fallbackMethodCount;
  final int duplicateAttempts;
  final double attendancePercentage;
  final DateTime? lastUpdated;

  const _ClassTelemetry({
    required this.visible,
    required this.scheduled,
    required this.presentCount,
    required this.lateCount,
    required this.absentCount,
    required this.recognizedCount,
    required this.unknownCount,
    required this.lowConfidenceCount,
    required this.fallbackMethodCount,
    required this.duplicateAttempts,
    required this.attendancePercentage,
    required this.lastUpdated,
  });

  int get proxyFlags =>
      lowConfidenceCount + fallbackMethodCount + duplicateAttempts;
}
