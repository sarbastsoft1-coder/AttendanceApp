import 'class_model.dart';

enum SupervisorTrendRange { daily, weekly, monthly }

extension SupervisorTrendRangeX on SupervisorTrendRange {
  String get label {
    switch (this) {
      case SupervisorTrendRange.daily:
        return 'Daily';
      case SupervisorTrendRange.weekly:
        return 'Weekly';
      case SupervisorTrendRange.monthly:
        return 'Monthly';
    }
  }
}

enum DashboardSeverity { info, success, warning, critical }

enum RecognitionLogResult { recognized, unknown, flagged }

class SupervisorDashboardSummary {
  final int totalFacesDetected;
  final int successfullyRecognized;
  final int unknownFaces;
  final int proxyAlerts;
  final double recognitionAccuracy;

  const SupervisorDashboardSummary({
    required this.totalFacesDetected,
    required this.successfullyRecognized,
    required this.unknownFaces,
    required this.proxyAlerts,
    required this.recognitionAccuracy,
  });
}

class RoomMonitorItem {
  final String id;
  final String roomName;
  final String cameraStatus;
  final String scanStatus;
  final int facesDetected;
  final int recognized;
  final int unknown;
  final int alerts;
  final DateTime? lastUpdated;
  final double recognitionAccuracy;
  final List<int> classIds;
  final List<String> classNames;

  const RoomMonitorItem({
    required this.id,
    required this.roomName,
    required this.cameraStatus,
    required this.scanStatus,
    required this.facesDetected,
    required this.recognized,
    required this.unknown,
    required this.alerts,
    required this.lastUpdated,
    required this.recognitionAccuracy,
    required this.classIds,
    required this.classNames,
  });
}

class TrendPoint {
  final String label;
  final int present;
  final int absent;
  final int late;

  const TrendPoint({
    required this.label,
    required this.present,
    required this.absent,
    required this.late,
  });
}

class ClassAttendanceRow {
  final String classId;
  final String className;
  final int totalStudents;
  final int present;
  final int absent;
  final int late;
  final double attendancePercentage;
  final int proxyFlags;
  final String roomName;
  final bool scheduled;
  final ClassModel sourceClass;

  const ClassAttendanceRow({
    required this.classId,
    required this.className,
    required this.totalStudents,
    required this.present,
    required this.absent,
    required this.late,
    required this.attendancePercentage,
    required this.proxyFlags,
    required this.roomName,
    required this.scheduled,
    required this.sourceClass,
  });
}

class RecognitionLogEntry {
  final String id;
  final DateTime time;
  final String personLabel;
  final String room;
  final String className;
  final RecognitionLogResult result;
  final double? confidence;
  final String method;
  final String? notes;

  const RecognitionLogEntry({
    required this.id,
    required this.time,
    required this.personLabel,
    required this.room,
    required this.className,
    required this.result,
    required this.confidence,
    required this.method,
    required this.notes,
  });
}

class SuspiciousActivityItem {
  final String id;
  final String title;
  final String description;
  final DashboardSeverity severity;
  final DateTime? timestamp;
  final String? roomName;
  final String? className;

  const SuspiciousActivityItem({
    required this.id,
    required this.title,
    required this.description,
    required this.severity,
    required this.timestamp,
    this.roomName,
    this.className,
  });
}

class DashboardAlertItem {
  final String id;
  final String title;
  final String description;
  final DashboardSeverity severity;
  final DateTime? timestamp;
  final String? roomName;

  const DashboardAlertItem({
    required this.id,
    required this.title,
    required this.description,
    required this.severity,
    required this.timestamp,
    this.roomName,
  });
}

class SupervisorDashboardData {
  final DateTime selectedDate;
  final DateTime lastRefreshed;
  final SupervisorTrendRange trendRange;
  final String? roomFilter;
  final int? classFilterId;
  final List<ClassModel> availableClasses;
  final List<String> availableRooms;
  final SupervisorDashboardSummary summary;
  final List<RoomMonitorItem> roomMonitors;
  final List<TrendPoint> trend;
  final List<ClassAttendanceRow> classRows;
  final List<RecognitionLogEntry> recentLogs;
  final List<SuspiciousActivityItem> suspiciousActivities;
  final List<DashboardAlertItem> alerts;
  final bool usesDerivedSignals;

  const SupervisorDashboardData({
    required this.selectedDate,
    required this.lastRefreshed,
    required this.trendRange,
    required this.roomFilter,
    required this.classFilterId,
    required this.availableClasses,
    required this.availableRooms,
    required this.summary,
    required this.roomMonitors,
    required this.trend,
    required this.classRows,
    required this.recentLogs,
    required this.suspiciousActivities,
    required this.alerts,
    this.usesDerivedSignals = true,
  });
}
