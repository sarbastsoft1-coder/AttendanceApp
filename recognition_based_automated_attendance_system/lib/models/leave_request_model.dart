/// Leave Request Model
class LeaveRequest {
  final int id;
  final int? userId;
  final int? studentId;
  final int submittedById;
  final DateTime leaveDate;
  final String reason;
  final String status; // pending, approved, rejected
  final int? reviewedById;
  final DateTime? reviewedAt;
  final String? reviewNote;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Display names
  final String? userName;
  final String? studentName;
  final String? submittedByName;
  final String? reviewedByName;

  LeaveRequest({
    required this.id,
    this.userId,
    this.studentId,
    required this.submittedById,
    required this.leaveDate,
    required this.reason,
    required this.status,
    this.reviewedById,
    this.reviewedAt,
    this.reviewNote,
    required this.createdAt,
    required this.updatedAt,
    this.userName,
    this.studentName,
    this.submittedByName,
    this.reviewedByName,
  });

  factory LeaveRequest.fromJson(Map<String, dynamic> json) {
    return LeaveRequest(
      id: json['id'] ?? 0,
      userId: json['user_id'],
      studentId: json['student_id'],
      submittedById: json['submitted_by_id'] ?? 0,
      leaveDate: json['leave_date'] != null
          ? DateTime.parse(json['leave_date'])
          : DateTime.now(),
      reason: json['reason'] ?? '',
      status: json['status'] ?? 'pending',
      reviewedById: json['reviewed_by_id'],
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'])
          : null,
      reviewNote: json['review_note'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      userName: json['user_name'],
      studentName: json['student_name'],
      submittedByName: json['submitted_by_name'],
      reviewedByName: json['reviewed_by_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'student_id': studentId,
      'submitted_by_id': submittedById,
      'leave_date': leaveDate.toIso8601String(),
      'reason': reason,
      'status': status,
      'reviewed_by_id': reviewedById,
      'reviewed_at': reviewedAt?.toIso8601String(),
      'review_note': reviewNote,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  String get statusDisplay {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }

  String get displayName => userName ?? studentName ?? submittedByName ?? 'Unknown';
}
