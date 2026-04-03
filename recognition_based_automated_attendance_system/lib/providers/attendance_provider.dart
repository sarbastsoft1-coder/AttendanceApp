import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../config/api_config.dart';
import '../models/captured_image.dart';
import '../models/attendance_model.dart';
import '../models/settings_model.dart';
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
  bool _isLoading = false;
  String? _error;
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
  bool get isLoading => _isLoading;
  String? get error => _error;
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

      // Refresh today's attendance records since multiple might have been marked
      await fetchTodayAttendance();

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
    notifyListeners();
  }

  void _upsertAttendanceRecord(List<Attendance> records, Attendance attendance) {
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

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
