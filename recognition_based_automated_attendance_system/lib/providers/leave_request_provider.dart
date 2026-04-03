import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/leave_request_model.dart';
import '../services/api_service.dart';

/// Leave Request Provider — manages leave request CRUD
class LeaveRequestProvider with ChangeNotifier {
  final ApiService _api = ApiService();

  List<LeaveRequest> _leaveRequests = [];
  bool _isLoading = false;
  String? _error;

  List<LeaveRequest> get leaveRequests => _leaveRequests;
  List<LeaveRequest> get pendingRequests =>
      _leaveRequests.where((r) => r.isPending).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Fetch leave requests (own for student, all for teacher/admin)
  Future<void> fetchLeaveRequests({String? statusFilter}) async {
    _setLoading(true);
    _error = null;

    try {
      final response = await _api.get(
        ApiConfig.leaveRequests,
        queryParameters: {
          // ignore: use_null_aware_elements
          if (statusFilter != null) 'status_filter': statusFilter,
        },
      );

      _leaveRequests = (response.data as List)
          .map((json) => LeaveRequest.fromJson(json))
          .toList();

      _setLoading(false);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
    }
  }

  /// Submit a new leave request
  Future<bool> submitLeaveRequest({
    int? userId,
    int? studentId,
    required DateTime leaveDate,
    required String reason,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      final response = await _api.post(
        ApiConfig.leaveRequests,
        data: {
          // ignore: use_null_aware_elements
          if (userId != null) 'user_id': userId,
          // ignore: use_null_aware_elements
          if (studentId != null) 'student_id': studentId,
          'leave_date': leaveDate.toIso8601String(),
          'reason': reason,
        },
      );

      final newLeave = LeaveRequest.fromJson(response.data);
      _leaveRequests.insert(0, newLeave);

      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  /// Approve or reject a leave request (teacher/admin)
  Future<bool> reviewLeaveRequest(
    int leaveId, {
    required String status, // 'approved' or 'rejected'
    String? reviewNote,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      final response = await _api.patch(
        ApiConfig.leaveRequestById(leaveId),
        data: {
          'status': status,
          if (reviewNote != null && reviewNote.isNotEmpty)
            'review_note': reviewNote,
        },
      );

      final updated = LeaveRequest.fromJson(response.data);
      final index = _leaveRequests.indexWhere((r) => r.id == leaveId);
      if (index != -1) {
        _leaveRequests[index] = updated;
      }

      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  /// Delete a pending leave request
  Future<bool> deleteLeaveRequest(int leaveId) async {
    _setLoading(true);
    _error = null;

    try {
      await _api.delete(ApiConfig.leaveRequestById(leaveId));
      _leaveRequests.removeWhere((r) => r.id == leaveId);
      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
