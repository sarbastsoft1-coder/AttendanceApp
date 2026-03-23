import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/exam_proctor_model.dart';
import '../services/api_service.dart';

/// Provider for exam proctoring state management
class ExamProctorProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  bool _isLoading = false;
  bool _isMonitoring = false;
  ExamProctorResult? _lastResult;
  final List<ExamProctorResult> _scanHistory = [];
  String? _error;
  int? _selectedStudentId;
  int? _selectedClassId;

  // Getters
  bool get isLoading => _isLoading;
  bool get isMonitoring => _isMonitoring;
  ExamProctorResult? get lastResult => _lastResult;
  List<ExamProctorResult> get scanHistory => _scanHistory;
  String? get error => _error;
  int? get selectedStudentId => _selectedStudentId;
  int? get selectedClassId => _selectedClassId;

  /// Set the selected student to monitor
  void setSelectedStudent(int? studentId) {
    _selectedStudentId = studentId;
    notifyListeners();
  }

  /// Set the selected class to monitor
  void setSelectedClass(int? classId) {
    _selectedClassId = classId;
    notifyListeners();
  }

  /// Start monitoring session
  void startMonitoring() {
    _isMonitoring = true;
    _scanHistory.clear();
    _error = null;
    notifyListeners();
  }

  /// Stop monitoring session
  void stopMonitoring() {
    _isMonitoring = false;
    notifyListeners();
  }

  /// Perform a single proctor scan
  Future<ExamProctorResult?> performProctorScan(File imageFile) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final multipartFile = await MultipartFile.fromFile(
        imageFile.path,
        filename: 'exam_scan_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      final response = await _apiService.uploadExamProctorImage(
        '/api/exam-proctor',
        file: multipartFile,
        studentId: _selectedStudentId,
        classId: _selectedClassId,
      );

      if (response.statusCode == 200) {
        final result = ExamProctorResult.fromJson(response.data);
        _lastResult = result;
        _scanHistory.add(result);
        
        // Keep only last 100 scans in history
        if (_scanHistory.length > 100) {
          _scanHistory.removeAt(0);
        }
        
        _isLoading = false;
        notifyListeners();
        return result;
      } else {
        throw Exception('Failed to perform proctor scan');
      }
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Clear scan history
  void clearHistory() {
    _scanHistory.clear();
    _lastResult = null;
    notifyListeners();
  }

  /// Get the color for suspicion score display
  static String getSuspicionColor(double score) {
    if (score >= 70) return 'red';
    if (score >= 40) return 'orange';
    if (score >= 20) return 'yellow';
    return 'green';
  }

  /// Get stats from scan history
  Map<String, dynamic> getSessionStats() {
    if (_scanHistory.isEmpty) {
      return {
        'totalScans': 0,
        'cheatingDetected': 0,
        'averageSuspicion': 0.0,
        'violations': <String>[],
      };
    }

    final cheatingCount = _scanHistory.where((r) => r.isCheating).length;
    final avgSuspicion = _scanHistory.fold<double>(
          0,
          (sum, r) => sum + r.suspicionScore,
        ) /
        _scanHistory.length;
    
    // Collect unique violations
    final allViolations = <String>{};
    for (final result in _scanHistory) {
      allViolations.addAll(result.violations);
    }

    return {
      'totalScans': _scanHistory.length,
      'cheatingDetected': cheatingCount,
      'averageSuspicion': avgSuspicion,
      'violations': allViolations.toList(),
    };
  }
}
