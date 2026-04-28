import 'package:dio/dio.dart';
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
  static const String _desktopDefaultBaseUrl = 'http://127.0.0.1:8000';
  static const List<String> _desktopFallbackBaseUrls = [
    'http://localhost:8000',
    'http://127.0.0.1:8001',
    'http://localhost:8001',
    'http://127.0.0.1:8010',
    'http://localhost:8010',
    'http://127.0.0.1:8011',
    'http://localhost:8011',
  ];
  static const String _baseUrlKey = 'api_base_url';

  static final String _defaultBaseUrl = _resolveDefaultBaseUrl();
  static String _runtimeBaseUrl = _defaultBaseUrl;

  static String _normalizeBaseUrl(String url) {
    return url.trim().replaceAll(RegExp(r'/$'), '');
  }

  static List<String> get _desktopDiscoveryBaseUrls => [
    _desktopDefaultBaseUrl,
    ..._desktopFallbackBaseUrls,
  ];

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
    final normalizedSaved = saved == null || saved.trim().isEmpty
        ? null
        : _normalizeBaseUrl(saved);

    final preferred = normalizedSaved ?? _defaultBaseUrl;
    final resolved = kIsWeb
        ? await _resolveWebBaseUrl(preferred)
        : await _resolveDesktopBaseUrl(preferred);
    _runtimeBaseUrl = resolved;

    if (normalizedSaved != resolved) {
      await prefs.setString(_baseUrlKey, resolved);
    }
  }

  /// Persist a new base URL and update the runtime value
  static Future<void> setBaseUrl(String url) async {
    final normalizedUrl = _normalizeBaseUrl(url);
    _runtimeBaseUrl = normalizedUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, normalizedUrl);
  }

  /// Reset base URL to the default
  static Future<String> resetBaseUrl() async {
    final resolved = kIsWeb
        ? await _resolveWebBaseUrl(_defaultBaseUrl)
        : await _resolveDesktopBaseUrl(_defaultBaseUrl);
    await setBaseUrl(resolved);
    return _runtimeBaseUrl;
  }

  static String get defaultBaseUrl => _defaultBaseUrl;

  static Future<String> _resolveDesktopBaseUrl(String preferred) async {
    final candidates = <String>[];
    final seen = <String>{};

    void addCandidate(String url) {
      final normalized = _normalizeBaseUrl(url);
      if (normalized.isEmpty || seen.contains(normalized)) {
        return;
      }
      seen.add(normalized);
      candidates.add(normalized);
    }

    addCandidate(preferred);
    for (final candidate in _desktopDiscoveryBaseUrls) {
      addCandidate(candidate);
    }

    for (final candidate in candidates) {
      if (await _isHealthyBaseUrl(candidate)) {
        return candidate;
      }
    }

    return preferred;
  }

  static Future<String> _resolveWebBaseUrl(String preferred) async {
    final candidates = <String>[];
    final seen = <String>{};

    void addCandidate(String url) {
      final normalized = _normalizeBaseUrl(url);
      if (normalized.isEmpty || seen.contains(normalized)) {
        return;
      }
      seen.add(normalized);
      candidates.add(normalized);
    }

    addCandidate(preferred);
    for (final candidate in _webDiscoveryBaseUrls) {
      addCandidate(candidate);
    }

    for (final candidate in candidates) {
      if (await _isHealthyBaseUrl(candidate)) {
        return candidate;
      }
    }

    return preferred;
  }

  static List<String> get _webDiscoveryBaseUrls {
    final origin = _normalizeBaseUrl(Uri.base.origin);
    final host = Uri.base.host.toLowerCase();
    final scheme = Uri.base.scheme.isEmpty ? 'http' : Uri.base.scheme;
    final isLocalHost =
        host == 'localhost' || host == '127.0.0.1' || host == '0.0.0.0';

    if (!isLocalHost) {
      return [origin];
    }

    final hosts = <String>[
      host,
      if (host != '127.0.0.1') '127.0.0.1',
      if (host != 'localhost') 'localhost',
    ];
    final ports = <int>[8000, 8001, 8010, 8011];
    final urls = <String>[];

    for (final candidateHost in hosts) {
      for (final port in ports) {
        urls.add('$scheme://$candidateHost:$port');
      }
    }

    urls.add(origin);
    return urls;
  }

  static Future<bool> isAttendanceBackend(String url) async {
    return _isHealthyBaseUrl(_normalizeBaseUrl(url));
  }

  static Future<String> resolveDesktopBaseUrl([String? preferred]) async {
    final candidate = preferred == null || preferred.trim().isEmpty
        ? _runtimeBaseUrl
        : preferred;
    return _resolveDesktopBaseUrl(candidate);
  }

  static Future<bool> _isHealthyBaseUrl(String url) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: url,
        connectTimeout: const Duration(milliseconds: 1200),
        receiveTimeout: const Duration(milliseconds: 1200),
        validateStatus: (_) => true,
      ),
    );

    try {
      final response = await dio.get('/health');
      if (response.statusCode != 200) {
        return false;
      }

      final data = response.data;
      if (data is! Map || data['status'] != 'healthy') {
        return false;
      }

      final openApi = await dio.get('/openapi.json');
      if (openApi.statusCode != 200 || openApi.data is! Map) {
        return false;
      }

      final openApiData = openApi.data as Map;
      final info = openApiData['info'];
      final paths = openApiData['paths'];
      if (info is! Map || paths is! Map) {
        return false;
      }

      return info['title'] == 'Recognition Based Automated Attendance System' &&
          paths.containsKey('/api/auth/register') &&
          paths.containsKey('/api/auth/login-json');
    } catch (_) {
      return false;
    } finally {
      dio.close(force: true);
    }
  }

  // ─── Timeouts ────────────────────────────────────────────────────────────────
  static const int connectionTimeout = 120000; // 2 minutes
  static const int receiveTimeout = 120000;

  // ─── Auth ────────────────────────────────────────────────────────────────────
  static const String authRegister = '/api/auth/register';
  static const String authLogin = '/api/auth/login-json';
  static const String studentFaceLogin = '/api/auth/student-face-login';
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
  static const String supervisionOverview = '/api/supervision/overview';
  static const String supervisionGroups = '/api/supervision/groups';
  static String supervisionGroupInvites(int groupId) =>
      '/api/supervision/groups/$groupId/invites';
  static String supervisionInvitationById(int inviteId) =>
      '/api/supervision/invitations/$inviteId';
  static String supervisionGroupMember(int groupId, int teacherId) =>
      '/api/supervision/groups/$groupId/members/$teacherId';
  static const String supervisionClassShares = '/api/supervision/class-shares';

  static const String examProctor = '/api/exam-proctor';
}
