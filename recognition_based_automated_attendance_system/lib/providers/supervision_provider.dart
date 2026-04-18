import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import '../models/supervision_model.dart';
import '../services/api_service.dart';

class SupervisionProvider with ChangeNotifier {
  final ApiService _api = ApiService();

  SupervisionOverview? _overview;
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _error;

  SupervisionOverview? get overview => _overview;
  List<TeacherGroup> get groups => _overview?.groups ?? const [];
  List<TeacherGroupInvite> get invitations =>
      _overview?.invitations ?? const [];
  bool get canCreateGroups => _overview?.canCreateGroups ?? false;
  bool get canManageGroups => _overview?.canManageGroups ?? false;
  bool get canShareClasses => _overview?.canShareClasses ?? false;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get error => _error;

  Future<void> fetchOverview() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.get(ApiConfig.supervisionOverview);
      _overview = SupervisionOverview.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createGroup({required String name, String? description}) async {
    return _submit(() async {
      await _api.post(
        ApiConfig.supervisionGroups,
        data: {
          'name': name.trim(),
          if (description != null && description.trim().isNotEmpty)
            'description': description.trim(),
        },
      );
      await fetchOverview();
    });
  }

  Future<bool> inviteTeachers({
    required int groupId,
    required List<String> emails,
    String targetRole = 'teacher',
    String? note,
  }) async {
    return _submit(() async {
      await _api.post(
        ApiConfig.supervisionGroupInvites(groupId),
        data: {
          'emails': emails,
          'target_role': targetRole,
          if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        },
      );
      await fetchOverview();
    });
  }

  Future<bool> respondToInvitation({
    required int inviteId,
    required String status,
  }) async {
    return _submit(() async {
      await _api.patch(
        ApiConfig.supervisionInvitationById(inviteId),
        data: {'status': status},
      );
      await fetchOverview();
    });
  }

  Future<bool> updateMemberRole({
    required int groupId,
    required int teacherId,
    required String role,
  }) async {
    return _submit(() async {
      await _api.patch(
        ApiConfig.supervisionGroupMember(groupId, teacherId),
        data: {'role': role},
      );
      await fetchOverview();
    });
  }

  Future<bool> shareClassWithGroup({
    required int classId,
    required int groupId,
  }) async {
    return _submit(() async {
      await _api.post(
        ApiConfig.supervisionClassShares,
        data: {'class_id': classId, 'group_id': groupId},
      );
      await fetchOverview();
    });
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<bool> _submit(Future<void> Function() task) async {
    _isSubmitting = true;
    _error = null;
    notifyListeners();

    try {
      await task();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
