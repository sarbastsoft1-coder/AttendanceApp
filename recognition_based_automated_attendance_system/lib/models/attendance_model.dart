import 'user_model.dart';

/// Attendance Model
class Attendance {
  final int id;
  final int? userId;
  final int? studentId;
  final int? classId;
  final DateTime date;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final double? confidence;
  final String method;
  final String status;
  final String? location;
  final String? notes;
  final DateTime createdAt;
  final User? user;
  final String? studentName;
  final String? className;

  Attendance({
    required this.id,
    this.userId,
    this.studentId,
    this.classId,
    required this.date,
    this.checkInTime,
    this.checkOutTime,
    this.confidence,
    required this.method,
    required this.status,
    this.location,
    this.notes,
    required this.createdAt,
    this.user,
    this.studentName,
    this.className,
  });

  factory Attendance.fromJson(Map<String, dynamic> json) {
    return Attendance(
      id: json['id'] ?? 0,
      userId: json['user_id'],
      studentId: json['student_id'],
      classId: json['class_id'],
      date: json['date'] != null
          ? DateTime.parse(json['date'])
          : DateTime.now(),
      checkInTime: json['check_in_time'] != null
          ? DateTime.parse(json['check_in_time'])
          : null,
      checkOutTime: json['check_out_time'] != null
          ? DateTime.parse(json['check_out_time'])
          : null,
      confidence: json['confidence'] != null
          ? (json['confidence'] as num).toDouble()
          : null,
      method: json['method'] ?? 'face',
      status: json['status'] ?? 'present',
      location: json['location'],
      notes: json['notes'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      studentName: json['student_name'],
      className: json['class_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'student_id': studentId,
      'class_id': classId,
      'date': date.toIso8601String(),
      'check_in_time': checkInTime?.toIso8601String(),
      'check_out_time': checkOutTime?.toIso8601String(),
      'confidence': confidence,
      'method': method,
      'status': status,
      'location': location,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'student_name': studentName,
      'class_name': className,
    };
  }

  bool get isPresent => status == 'present';
  bool get isLate => status == 'late';
  bool get isAbsent => status == 'absent';

  String get statusDisplay {
    switch (status) {
      case 'present':
        return 'Present';
      case 'late':
        return 'Late';
      case 'absent':
        return 'Absent';
      case 'half_day':
        return 'Half Day';
      default:
        return status;
    }
  }

  String get confidencePercentage {
    if (confidence == null) return 'N/A';
    return '${(confidence! * 100).toStringAsFixed(1)}%';
  }

  String get formattedTime {
    final source = checkInTime ?? date;
    final hour = source.hour > 12
        ? source.hour - 12
        : (source.hour == 0 ? 12 : source.hour);
    final minute = source.minute.toString().padLeft(2, '0');
    final period = source.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String get displayName {
    if (studentName != null && studentName!.trim().isNotEmpty) {
      return studentName!.trim();
    }
    if (user != null && user!.fullName.trim().isNotEmpty) {
      return user!.fullName.trim();
    }
    return 'Unknown';
  }
}

/// Paginated attendance response
class PaginatedAttendance {
  final List<Attendance> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  PaginatedAttendance({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory PaginatedAttendance.fromJson(Map<String, dynamic> json) {
    return PaginatedAttendance(
      items:
          (json['items'] as List?)
              ?.map((e) => Attendance.fromJson(e))
              .toList() ??
          [],
      total: json['total'] ?? 0,
      page: json['page'] ?? 1,
      pageSize: json['page_size'] ?? 20,
      totalPages: json['total_pages'] ?? 1,
    );
  }
}

/// Attendance Statistics
class AttendanceStats {
  final int userId;
  final int totalDays;
  final int presentDays;
  final int lateDays;
  final int absentDays;
  final double attendancePercentage;
  final bool belowThreshold;
  final double threshold;

  AttendanceStats({
    required this.userId,
    required this.totalDays,
    required this.presentDays,
    required this.lateDays,
    required this.absentDays,
    required this.attendancePercentage,
    this.belowThreshold = false,
    this.threshold = 75.0,
  });

  factory AttendanceStats.fromJson(Map<String, dynamic> json) {
    return AttendanceStats(
      userId: json['user_id'] ?? 0,
      totalDays: json['total_days'] ?? 0,
      presentDays: json['present_days'] ?? 0,
      lateDays: json['late_days'] ?? 0,
      absentDays: json['absent_days'] ?? 0,
      attendancePercentage:
          (json['attendance_percentage'] as num?)?.toDouble() ?? 0.0,
      belowThreshold: json['below_threshold'] ?? false,
      threshold: (json['threshold'] as num?)?.toDouble() ?? 75.0,
    );
  }
}

/// Dashboard Statistics (Admin)
class DashboardStats {
  final int totalUsers;
  final int activeUsers;
  final int presentToday;
  final int lateToday;
  final int absentToday;
  final int registeredFaces;
  final int pendingLeaves;
  final int unreadNotifications;

  DashboardStats({
    required this.totalUsers,
    required this.activeUsers,
    required this.presentToday,
    required this.lateToday,
    required this.absentToday,
    required this.registeredFaces,
    this.pendingLeaves = 0,
    this.unreadNotifications = 0,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalUsers: json['total_users'] ?? 0,
      activeUsers: json['active_users'] ?? 0,
      presentToday: json['present_today'] ?? 0,
      lateToday: json['late_today'] ?? 0,
      absentToday: json['absent_today'] ?? 0,
      registeredFaces: json['registered_faces'] ?? 0,
      pendingLeaves: json['pending_leaves'] ?? 0,
      unreadNotifications: json['unread_notifications'] ?? 0,
    );
  }
}

/// Result of a group/room scan
class RoomScanResult {
  final int presentCount;
  final int absentCount;
  final int totalStudents;
  final List<User> presentUsers;
  final List<User> absentUsers;
  final String message;

  RoomScanResult({
    required this.presentCount,
    required this.absentCount,
    required this.totalStudents,
    required this.presentUsers,
    required this.absentUsers,
    required this.message,
  });

  factory RoomScanResult.fromJson(Map<String, dynamic> json) {
    return RoomScanResult(
      presentCount: json['present_count'] ?? 0,
      absentCount: json['absent_count'] ?? 0,
      totalStudents: json['total_students'] ?? 0,
      presentUsers:
          (json['present_users'] as List?)
              ?.map((u) => User.fromJson(u))
              .toList() ??
          [],
      absentUsers:
          (json['absent_users'] as List?)
              ?.map((u) => User.fromJson(u))
              .toList() ??
          [],
      message: json['message'] ?? '',
    );
  }
}
