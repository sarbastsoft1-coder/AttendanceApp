import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/class_model.dart';
import '../services/api_service.dart';

class StudentManagementProvider with ChangeNotifier {
  final ApiService _api = ApiService();

  List<ClassModel> _classes = [];
  List<Student> _students = [];
  bool _isLoading = false;
  String? _error;

  List<ClassModel> get classes => _classes;
  List<Student> get students => _students;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchClasses() async {
    _error = null;
    _setLoading(true);
    try {
      final response = await _api.get(ApiConfig.classes);
      _classes = (response.data as List)
          .map((json) => ClassModel.fromJson(json))
          .toList();
      _setLoading(false);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
    }
  }

  Future<void> fetchClassStudents(int classId) async {
    _error = null;
    _setLoading(true);
    try {
      final response = await _api.get('${ApiConfig.classes}/$classId/students');
      _students = (response.data as List)
          .map((json) => Student.fromJson(json))
          .toList();
      _setLoading(false);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
    }
  }

  Future<bool> createClass(String name) async {
    _setLoading(true);
    try {
      await _api.post(ApiConfig.classes, data: {'name': name});
      await fetchClasses();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> deleteClass(int classId) async {
    _setLoading(true);
    try {
      await _api.delete('${ApiConfig.classes}/$classId');
      await fetchClasses();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> deleteStudent(int classId, int studentId) async {
    _setLoading(true);
    try {
      await _api.delete('${ApiConfig.classes}/$classId/students/$studentId');
      await fetchClassStudents(classId);
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
