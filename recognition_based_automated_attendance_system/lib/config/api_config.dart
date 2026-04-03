import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// API Configuration
/// Base URL is runtime-configurable (saved in SharedPreferences).
/// Web builds can inject API_BASE_URL at compile time, while desktop keeps a
/// localhost default for local development.
class ApiConfig {
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  static const String _desktopDefaultBaseUrl = 'http://localhost:8000';
  static const String _baseUrlKey = 'api_base_url';

  static final String _defaultBaseUrl = _resolveDefaultBaseUrl();
  static String _runtimeBaseUrl = _defaultBaseUrl;

  static String _normalizeBaseUrl(String url) {
    return url.trim().replaceAll(RegExp(r'/$'), '');
  }

  static String _resolveDefaultBaseUrl() {
    if (_configuredBaseUrl.trim().isNotEmpty) {
      return _normalizeBaseUrl(_configuredBaseUrl);
    }
    if (kIsWeb) {
      return _normalizeBaseUrl(Uri.base.origin);
    }
    return _desktopDefaultBaseUrl;
  }

  /// The currently active base URL (may differ per-run if user changed it)
  static String get baseUrl => _runtimeBaseUrl;

  /// Load saved base URL from SharedPreferences (call once at startup)
  static Future<void> loadBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_baseUrlKey);
    _runtimeBaseUrl = saved == null || saved.trim().isEmpty
        ? _defaultBaseUrl
        : _normalizeBaseUrl(saved);
  }

  /// Persist a new base URL and update the runtime value
  static Future<void> setBaseUrl(String url) async {
    _runtimeBaseUrl = _normalizeBaseUrl(url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, _runtimeBaseUrl);
  }

  /// Reset base URL to the default
  static Future<void> resetBaseUrl() async {
    await setBaseUrl(_defaultBaseUrl);
  }

  static String get defaultBaseUrl => _defaultBaseUrl;

  // ─── Timeouts ────────────────────────────────────────────────────────────────
  static const int connectionTimeout = 120000; // 2 minutes
  static const int receiveTimeout = 120000;

  // ─── Auth ────────────────────────────────────────────────────────────────────
  static const String authRegister = '/api/auth/register';
  static const String authLogin = '/api/auth/login-json';
  static const String authVerify = '/api/auth/verify';
  static const String authMe = '/api/auth/me';
  static const String authDeleteAccount = '/api/auth/me';
  static const String forgotPassword = '/api/auth/forgot-password';
  static const String resetPassword = '/api/auth/reset-password';
  static const String changePassword = '/api/auth/change-password';
  static String verifyEmail(String token) => '/api/auth/verify-email/$token';

  // ─── Users ───────────────────────────────────────────────────────────────────
  static const String users = '/api/users';
  static String userById(int id) => '/api/users/$id';
  static const String registerFace = '/api/users/register-face';
  static const String removeFace = '/api/users/remove-face';

  // ─── Attendance ──────────────────────────────────────────────────────────────
  static const String markAttendance = '/api/attendance/mark';
  static const String checkOut = '/api/attendance/check-out';
  static const String manualAttendance = '/api/attendance/manual';
  static const String rollCall = '/api/attendance/roll-call';
  static const String todayAttendance = '/api/attendance/today';
  static const String attendanceHistory = '/api/attendance/history';
  static const String roomScan = '/api/attendance/room-scan';
  static const String exportAttendance = '/api/attendance/export';
  static String attendanceStats(int userId) => '/api/attendance/stats/$userId';
  static String updateAttendance(int id) => '/api/attendance/$id';

  // ─── Admin ───────────────────────────────────────────────────────────────────
  static const String adminDashboard = '/api/admin/dashboard';
  static const String adminReports = '/api/admin/reports';
  static const String adminAttendance = '/api/admin/attendance';
  static const String adminAnalytics = '/api/admin/analytics';
  static const String auditLog = '/api/admin/audit-log';

  // ─── Settings ────────────────────────────────────────────────────────────────
  static const String settings = '/api/settings';
  static const String appSettings = '/api/settings/app';
  static const String settingsBulk = '/api/settings/bulk';
  static String settingByKey(String key) => '/api/settings/$key';

  // ─── Leave Requests ──────────────────────────────────────────────────────────
  static const String leaveRequests = '/api/leave';
  static String leaveRequestById(int id) => '/api/leave/$id';

  // ─── Notifications ───────────────────────────────────────────────────────────
  static const String notifications = '/api/notifications';
  static const String notificationsUnreadCount =
      '/api/notifications/unread-count';
  static const String notificationsMarkRead = '/api/notifications/mark-read';
  static String notificationById(int id) => '/api/notifications/$id';

  // ─── Classes & Students ──────────────────────────────────────────────────────
  static const String classes = '/api/classes';
  static String classById(int id) => '/api/classes/$id';
  static String classStudents(int classId) => '/api/classes/$classId/students';
  static String classAttendance(int classId) =>
      '/api/classes/$classId/attendance';
  static String deleteStudent(int classId, int studentId) =>
      '/api/classes/$classId/students/$studentId';
  static const String registerStudent = '/api/students/register';
  static const String bulkImportStudents = '/api/students/bulk-import';

  // ─── QR Attendance ───────────────────────────────────────────────────────────
  static const String createQrSession = '/api/qr/create-session';
  static String activeQrSession(int classId) => '/api/qr/session/$classId';
  static String scanQr(String token) => '/api/qr/scan/$token';
  static String deactivateQrSession(int sessionId) =>
      '/api/qr/session/$sessionId';

  // ─── Exam Proctoring ─────────────────────────────────────────────────────────
  static const String examProctor = '/api/exam-proctor';
}
