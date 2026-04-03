/// App Settings Model
class AppSettings {
  final int lateThresholdHour;
  final int lateThresholdMinute;
  final int minFaceImages;
  final int maxFaceImages;
  final double attendanceAlertPct;
  final int qrSessionMinutes;
  final bool allowManualEntry;
  final bool allowQrAttendance;
  final bool allowFaceAttendance;
  final String appName;

  const AppSettings({
    this.lateThresholdHour = 9,
    this.lateThresholdMinute = 0,
    this.minFaceImages = 2,
    this.maxFaceImages = 10,
    this.attendanceAlertPct = 75.0,
    this.qrSessionMinutes = 15,
    this.allowManualEntry = true,
    this.allowQrAttendance = true,
    this.allowFaceAttendance = true,
    this.appName = 'Face Attendance System',
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      lateThresholdHour:
          int.tryParse(json['late_threshold_hour']?.toString() ?? '9') ?? 9,
      lateThresholdMinute:
          int.tryParse(json['late_threshold_minute']?.toString() ?? '0') ?? 0,
      minFaceImages:
          int.tryParse(json['min_face_images']?.toString() ?? '2') ?? 2,
      maxFaceImages:
          int.tryParse(json['max_face_images']?.toString() ?? '10') ?? 10,
      attendanceAlertPct:
          double.tryParse(json['attendance_alert_pct']?.toString() ?? '75') ??
          75.0,
      qrSessionMinutes:
          int.tryParse(json['qr_session_minutes']?.toString() ?? '15') ?? 15,
      allowManualEntry: _parseBool(
        json['allow_manual_entry'],
        defaultValue: true,
      ),
      allowQrAttendance: _parseBool(
        json['allow_qr_attendance'],
        defaultValue: true,
      ),
      allowFaceAttendance: _parseBool(
        json['allow_face_attendance'],
        defaultValue: true,
      ),
      appName: json['app_name']?.toString() ?? 'Face Attendance System',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'late_threshold_hour': lateThresholdHour,
      'late_threshold_minute': lateThresholdMinute,
      'min_face_images': minFaceImages,
      'max_face_images': maxFaceImages,
      'attendance_alert_pct': attendanceAlertPct,
      'qr_session_minutes': qrSessionMinutes,
      'allow_manual_entry': allowManualEntry,
      'allow_qr_attendance': allowQrAttendance,
      'allow_face_attendance': allowFaceAttendance,
      'app_name': appName,
    };
  }

  /// Return settings as a flat Map for bulk update API
  Map<String, String> toBulkUpdateMap() {
    return {
      'late_threshold_hour': lateThresholdHour.toString(),
      'late_threshold_minute': lateThresholdMinute.toString(),
      'min_face_images': minFaceImages.toString(),
      'max_face_images': maxFaceImages.toString(),
      'attendance_alert_pct': attendanceAlertPct.toString(),
      'qr_session_minutes': qrSessionMinutes.toString(),
      'allow_manual_entry': allowManualEntry.toString(),
      'allow_qr_attendance': allowQrAttendance.toString(),
      'allow_face_attendance': allowFaceAttendance.toString(),
      'app_name': appName,
    };
  }

  AppSettings copyWith({
    int? lateThresholdHour,
    int? lateThresholdMinute,
    int? minFaceImages,
    int? maxFaceImages,
    double? attendanceAlertPct,
    int? qrSessionMinutes,
    bool? allowManualEntry,
    bool? allowQrAttendance,
    bool? allowFaceAttendance,
    String? appName,
  }) {
    return AppSettings(
      lateThresholdHour: lateThresholdHour ?? this.lateThresholdHour,
      lateThresholdMinute: lateThresholdMinute ?? this.lateThresholdMinute,
      minFaceImages: minFaceImages ?? this.minFaceImages,
      maxFaceImages: maxFaceImages ?? this.maxFaceImages,
      attendanceAlertPct: attendanceAlertPct ?? this.attendanceAlertPct,
      qrSessionMinutes: qrSessionMinutes ?? this.qrSessionMinutes,
      allowManualEntry: allowManualEntry ?? this.allowManualEntry,
      allowQrAttendance: allowQrAttendance ?? this.allowQrAttendance,
      allowFaceAttendance: allowFaceAttendance ?? this.allowFaceAttendance,
      appName: appName ?? this.appName,
    );
  }

  String get lateThresholdDisplay {
    final m = lateThresholdMinute.toString().padLeft(2, '0');
    final period = lateThresholdHour >= 12 ? 'PM' : 'AM';
    final displayHour = lateThresholdHour > 12
        ? lateThresholdHour - 12
        : (lateThresholdHour == 0 ? 12 : lateThresholdHour);
    return '${displayHour.toString().padLeft(2, '0')}:$m $period';
  }

  static bool _parseBool(dynamic value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    final s = value.toString().toLowerCase();
    return s == 'true' || s == '1' || s == 'yes';
  }
}

/// Single setting key-value
class SettingItem {
  final String key;
  final String value;
  final String? description;
  final DateTime updatedAt;

  SettingItem({
    required this.key,
    required this.value,
    this.description,
    required this.updatedAt,
  });

  factory SettingItem.fromJson(Map<String, dynamic> json) {
    return SettingItem(
      key: json['key'] ?? '',
      value: json['value'] ?? '',
      description: json['description'],
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
    );
  }
}

// ============================================================
// QR Session Model
// ============================================================

class QRSession {
  final int id;
  final int classId;
  final String? className;
  final String token;
  final DateTime expiresAt;
  final bool isActive;
  final DateTime sessionDate;
  final DateTime createdAt;
  final String? qrUrl;

  QRSession({
    required this.id,
    required this.classId,
    this.className,
    required this.token,
    required this.expiresAt,
    required this.isActive,
    required this.sessionDate,
    required this.createdAt,
    this.qrUrl,
  });

  factory QRSession.fromJson(Map<String, dynamic> json) {
    return QRSession(
      id: json['id'] ?? 0,
      classId: json['class_id'] ?? 0,
      className: json['class_name'],
      token: json['token'] ?? '',
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'])
          : DateTime.now(),
      isActive: json['is_active'] ?? false,
      sessionDate: json['session_date'] != null
          ? DateTime.parse(json['session_date'])
          : DateTime.now(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      qrUrl: json['qr_url'],
    );
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Duration get timeRemaining {
    final remaining = expiresAt.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  String get timeRemainingDisplay {
    final r = timeRemaining;
    if (r == Duration.zero) return 'Expired';
    if (r.inMinutes >= 1) return '${r.inMinutes}m ${r.inSeconds % 60}s';
    return '${r.inSeconds}s';
  }

  /// The content to encode into the QR code (the token itself)
  String get qrData => token;
}

// ============================================================
// Audit Log Model
// ============================================================

class AuditLog {
  final int id;
  final int? actorId;
  final String? actorName;
  final String action;
  final String? targetType;
  final int? targetId;
  final String? detail;
  final String? ipAddress;
  final DateTime createdAt;

  AuditLog({
    required this.id,
    this.actorId,
    this.actorName,
    required this.action,
    this.targetType,
    this.targetId,
    this.detail,
    this.ipAddress,
    required this.createdAt,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: json['id'] ?? 0,
      actorId: json['actor_id'],
      actorName: json['actor_name'],
      action: json['action'] ?? '',
      targetType: json['target_type'],
      targetId: json['target_id'],
      detail: json['detail'],
      ipAddress: json['ip_address'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  String get actionDisplay {
    return action
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : w)
        .join(' ');
  }
}

/// Paginated audit log response
class PaginatedAuditLog {
  final List<AuditLog> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  PaginatedAuditLog({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory PaginatedAuditLog.fromJson(Map<String, dynamic> json) {
    return PaginatedAuditLog(
      items:
          (json['items'] as List?)?.map((e) => AuditLog.fromJson(e)).toList() ??
          [],
      total: json['total'] ?? 0,
      page: json['page'] ?? 1,
      pageSize: json['page_size'] ?? 50,
      totalPages: json['total_pages'] ?? 1,
    );
  }
}

// ============================================================
// Analytics Model
// ============================================================

class AnalyticsSummary {
  final int total;
  final int present;
  final int late;
  final int absent;
  final double attendanceRate;

  AnalyticsSummary({
    required this.total,
    required this.present,
    required this.late,
    required this.absent,
    required this.attendanceRate,
  });

  factory AnalyticsSummary.fromJson(Map<String, dynamic> json) {
    return AnalyticsSummary(
      total: json['total'] ?? 0,
      present: json['present'] ?? 0,
      late: json['late'] ?? 0,
      absent: json['absent'] ?? 0,
      attendanceRate: (json['attendance_rate'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DailyTrend {
  final String date;
  final int present;
  final int late;
  final int absent;

  DailyTrend({
    required this.date,
    required this.present,
    required this.late,
    required this.absent,
  });

  factory DailyTrend.fromJson(Map<String, dynamic> json) {
    return DailyTrend(
      date: json['date'] ?? '',
      present: json['present'] ?? 0,
      late: json['late'] ?? 0,
      absent: json['absent'] ?? 0,
    );
  }

  int get total => present + late + absent;
}

class DepartmentBreakdown {
  final String department;
  final int total;
  final int present;
  final double percentage;

  DepartmentBreakdown({
    required this.department,
    required this.total,
    required this.present,
    required this.percentage,
  });

  factory DepartmentBreakdown.fromJson(Map<String, dynamic> json) {
    return DepartmentBreakdown(
      department: json['department'] ?? '',
      total: json['total'] ?? 0,
      present: json['present'] ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class MethodBreakdown {
  final String method;
  final int count;

  MethodBreakdown({required this.method, required this.count});

  factory MethodBreakdown.fromJson(Map<String, dynamic> json) {
    return MethodBreakdown(
      method: json['method'] ?? '',
      count: json['count'] ?? 0,
    );
  }

  String get methodDisplay {
    switch (method) {
      case 'face':
        return 'Face Recognition';
      case 'manual':
        return 'Manual Entry';
      case 'qr_code':
        return 'QR Code';
      case 'room_scan':
        return 'Room Scan';
      default:
        return method;
    }
  }
}

class AnalyticsData {
  final int periodDays;
  final AnalyticsSummary summary;
  final List<DailyTrend> dailyTrend;
  final List<DepartmentBreakdown> departmentBreakdown;
  final List<MethodBreakdown> methodBreakdown;

  AnalyticsData({
    required this.periodDays,
    required this.summary,
    required this.dailyTrend,
    required this.departmentBreakdown,
    required this.methodBreakdown,
  });

  factory AnalyticsData.fromJson(Map<String, dynamic> json) {
    return AnalyticsData(
      periodDays: json['period_days'] ?? 30,
      summary: AnalyticsSummary.fromJson(json['summary'] ?? {}),
      dailyTrend:
          (json['daily_trend'] as List?)
              ?.map((e) => DailyTrend.fromJson(e))
              .toList() ??
          [],
      departmentBreakdown:
          (json['department_breakdown'] as List?)
              ?.map((e) => DepartmentBreakdown.fromJson(e))
              .toList() ??
          [],
      methodBreakdown:
          (json['method_breakdown'] as List?)
              ?.map((e) => MethodBreakdown.fromJson(e))
              .toList() ??
          [],
    );
  }
}
