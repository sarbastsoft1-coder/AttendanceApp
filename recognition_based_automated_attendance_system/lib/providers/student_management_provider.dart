import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../config/api_config.dart';
import '../models/class_model.dart';
import '../services/api_service.dart';
import '../utils/download_text_file_stub.dart'
    if (dart.library.html) '../utils/download_text_file_web.dart'
    as download_text_file;

class StudentImportResult {
  final int successCount;
  final int errorCount;
  final List<String> errors;
  final String message;

  const StudentImportResult({
    required this.successCount,
    required this.errorCount,
    required this.errors,
    required this.message,
  });

  factory StudentImportResult.fromJson(Map<String, dynamic> json) {
    return StudentImportResult(
      successCount: json['success_count'] ?? 0,
      errorCount: json['error_count'] ?? 0,
      errors: ((json['errors'] as List?) ?? const [])
          .map((item) => item.toString())
          .toList(),
      message: json['message']?.toString() ?? 'Import completed.',
    );
  }
}

class ExportFileResult {
  final String fileName;
  final String path;

  const ExportFileResult({required this.fileName, required this.path});
}

class ClassImportResult {
  final int successCount;
  final int errorCount;
  final List<String> errors;
  final String message;

  const ClassImportResult({
    required this.successCount,
    required this.errorCount,
    required this.errors,
    required this.message,
  });
}

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
      _classes = await _fetchClassesInternal();
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
      _students = await _fetchClassStudentsInternal(classId);
      _setLoading(false);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
    }
  }

  Future<bool> createClass({
    required String name,
    String? subject,
    String? room,
    String? startTime,
    String? endTime,
    List<String>? meetingDays,
  }) async {
    _setLoading(true);
    try {
      await _api.post(
        ApiConfig.classes,
        data: _buildClassPayload(
          name: name,
          subject: subject,
          room: room,
          startTime: startTime,
          endTime: endTime,
          meetingDays: meetingDays,
        ),
      );
      await fetchClasses();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> updateClass({
    required int classId,
    required String name,
    String? subject,
    String? room,
    String? startTime,
    String? endTime,
    List<String>? meetingDays,
  }) async {
    _setLoading(true);
    try {
      await _api.put(
        ApiConfig.classById(classId),
        data: _buildClassPayload(
          name: name,
          subject: subject,
          room: room,
          startTime: startTime,
          endTime: endTime,
          meetingDays: meetingDays,
        ),
      );
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

  Future<bool> updateStudent({
    required int classId,
    required int studentId,
    required String name,
  }) async {
    _setLoading(true);
    try {
      final formData = FormData();
      formData.fields.add(MapEntry('name', name.trim()));
      await _api.put(
        ApiConfig.deleteStudent(classId, studentId),
        data: formData,
      );
      await fetchClassStudents(classId);
      await fetchClasses();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  Future<StudentImportResult?> importStudentsFromCsv({
    required int classId,
    required File csvFile,
  }) async {
    _error = null;
    _setLoading(true);

    try {
      final formData = FormData();
      formData.fields.add(MapEntry('class_id', classId.toString()));
      formData.files.add(
        MapEntry(
          'csv_file',
          await MultipartFile.fromFile(
            csvFile.path,
            filename: path.basename(csvFile.path),
          ),
        ),
      );

      final response = await _api.post(
        ApiConfig.bulkImportStudents,
        data: formData,
      );
      final result = StudentImportResult.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );

      _students = await _fetchClassStudentsInternal(classId);
      _classes = await _fetchClassesInternal();
      _setLoading(false);
      return result;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
      return null;
    }
  }

  Future<ExportFileResult?> exportStudentsCsv({
    required ClassModel classObj,
  }) async {
    _error = null;
    _setLoading(true);

    try {
      final students = await _fetchClassStudentsInternal(classObj.id);
      _students = students;

      final fileName =
          'students_${_safeFileName(classObj.name)}_${DateTime.now().millisecondsSinceEpoch}.csv';
      final buffer = StringBuffer()
        ..writeln('id,name,class_id,has_registered_face,created_at');

      for (final student in students) {
        buffer.writeln(
          '${student.id},${_escapeCsv(student.name)},${student.classId},${student.hasRegisteredFace},${student.createdAt.toIso8601String()}',
        );
      }

      if (kIsWeb) {
        await download_text_file.downloadTextFile(fileName, buffer.toString());
        _setLoading(false);
        return ExportFileResult(fileName: fileName, path: fileName);
      }

      final directory = await _getExportDirectory();
      final file = File(path.join(directory.path, fileName));
      await file.writeAsString(buffer.toString());
      _setLoading(false);
      return ExportFileResult(fileName: fileName, path: file.path);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
      return null;
    }
  }

  Future<ExportFileResult?> exportClassAttendanceCsv({
    required ClassModel classObj,
  }) async {
    _error = null;
    _setLoading(true);

    try {
      final response = await _api.getPlainText(
        ApiConfig.exportAttendance,
        queryParameters: {'class_id': classObj.id},
      );

      final fileName =
          'attendance_${_safeFileName(classObj.name)}_${DateTime.now().millisecondsSinceEpoch}.csv';
      final content = response.data ?? '';

      if (kIsWeb) {
        await download_text_file.downloadTextFile(fileName, content);
        _setLoading(false);
        return ExportFileResult(fileName: fileName, path: fileName);
      }

      final directory = await _getExportDirectory();
      final file = File(path.join(directory.path, fileName));
      await file.writeAsString(content);
      _setLoading(false);
      return ExportFileResult(fileName: fileName, path: file.path);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
      return null;
    }
  }

  Future<ExportFileResult?> exportClassCsv({
    required ClassModel classObj,
  }) async {
    _error = null;
    _setLoading(true);

    try {
      final students = await _fetchClassStudentsInternal(classObj.id);
      _students = students;

      final fileName =
          'class_${_safeFileName(classObj.name)}_${DateTime.now().millisecondsSinceEpoch}.csv';

      final buffer = StringBuffer()
        ..write('\uFEFF')
        ..writeln(
          'class_id,class_name,subject,room,start_time,end_time,meeting_days,student_count,class_created_at,student_id,student_name,linked_user_id,has_registered_face,student_created_at',
        );

      if (students.isEmpty) {
        buffer.writeln(
          '${classObj.id},'
          '${_escapeCsv(classObj.name)},'
          '${_escapeCsv(classObj.subject ?? '')},'
          '${_escapeCsv(classObj.room ?? '')},'
          '${_escapeCsv(classObj.startTime ?? '')},'
          '${_escapeCsv(classObj.endTime ?? '')},'
          '${_escapeCsv(classObj.meetingDays.join(" | "))},'
          '${classObj.studentCount},'
          '${_formatCsvDateTime(classObj.createdAt)},'
          ',,,,',
        );
      } else {
        for (final student in students) {
          buffer.writeln(
            '${classObj.id},'
            '${_escapeCsv(classObj.name)},'
            '${_escapeCsv(classObj.subject ?? '')},'
            '${_escapeCsv(classObj.room ?? '')},'
            '${_escapeCsv(classObj.startTime ?? '')},'
            '${_escapeCsv(classObj.endTime ?? '')},'
            '${_escapeCsv(classObj.meetingDays.join(" | "))},'
            '${classObj.studentCount},'
            '${_formatCsvDateTime(classObj.createdAt)},'
            '${student.id},'
            '${_escapeCsv(student.name)},'
            '${student.linkedUserId ?? ''},'
            '${student.hasRegisteredFace},'
            '${_formatCsvDateTime(student.createdAt)}',
          );
        }
      }

      if (kIsWeb) {
        await download_text_file.downloadTextFile(fileName, buffer.toString());
        _setLoading(false);
        return ExportFileResult(fileName: fileName, path: fileName);
      }

      final directory = await _getExportDirectory();
      final file = File(path.join(directory.path, fileName));
      await file.writeAsString(buffer.toString());
      _setLoading(false);
      return ExportFileResult(fileName: fileName, path: file.path);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
      return null;
    }
  }

  Future<ClassImportResult?> importClassesFromCsv({
    required File csvFile,
  }) async {
    _error = null;
    _setLoading(true);

    try {
      final content = await csvFile.readAsString();
      final rows = _readCsvRows(content);
      if (rows.isEmpty) {
        throw Exception('CSV file is empty.');
      }

      final headers = rows.first.map(_normalizeCsvHeader).toList();
      final nameIndex = _findHeaderIndex(headers, [
        'name',
        'class_name',
        'class',
      ]);
      if (nameIndex == -1) {
        throw Exception(
          'CSV must include a "name" column. Optional columns: subject, room, start_time, end_time, meeting_days.',
        );
      }

      final subjectIndex = _findHeaderIndex(headers, ['subject']);
      final roomIndex = _findHeaderIndex(headers, ['room']);
      final startTimeIndex = _findHeaderIndex(headers, [
        'start_time',
        'starttime',
      ]);
      final endTimeIndex = _findHeaderIndex(headers, ['end_time', 'endtime']);
      final meetingDaysIndex = _findHeaderIndex(headers, [
        'meeting_days',
        'meetingdays',
        'days',
      ]);

      var successCount = 0;
      final errors = <String>[];

      for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
        final row = rows[rowIndex];
        if (row.every((value) => value.trim().isEmpty)) {
          continue;
        }

        final name = _csvCellValue(row, nameIndex).trim();
        if (name.isEmpty) {
          errors.add('Row ${rowIndex + 1}: missing class name.');
          continue;
        }

        final payload = _buildClassPayload(
          name: name,
          subject: _csvCellValue(row, subjectIndex),
          room: _csvCellValue(row, roomIndex),
          startTime: _csvCellValue(row, startTimeIndex),
          endTime: _csvCellValue(row, endTimeIndex),
          meetingDays: _parseMeetingDays(_csvCellValue(row, meetingDaysIndex)),
        );

        try {
          await _api.post(ApiConfig.classes, data: payload);
          successCount++;
        } catch (e) {
          errors.add(
            'Row ${rowIndex + 1}: ${e.toString().replaceFirst('Exception: ', '')}',
          );
        }
      }

      _classes = await _fetchClassesInternal();
      _setLoading(false);

      return ClassImportResult(
        successCount: successCount,
        errorCount: errors.length,
        errors: errors,
        message: errors.isEmpty
            ? 'Classes imported successfully.'
            : 'Class import completed with some skipped rows.',
      );
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
      return null;
    }
  }

  Future<List<ClassModel>> _fetchClassesInternal() async {
    final response = await _api.get(ApiConfig.classes);
    return (response.data as List)
        .map((json) => ClassModel.fromJson(json))
        .toList();
  }

  Future<List<Student>> _fetchClassStudentsInternal(int classId) async {
    final response = await _api.get(ApiConfig.classStudents(classId));
    return (response.data as List)
        .map((json) => Student.fromJson(json))
        .toList();
  }

  Future<Directory> _getExportDirectory() async {
    if (!kIsWeb) {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) {
        return downloads;
      }
    }
    return getApplicationDocumentsDirectory();
  }

  String _safeFileName(String input) {
    final trimmed = input.trim().toLowerCase();
    final normalized = trimmed.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final collapsed = normalized.replaceAll(RegExp(r'_+'), '_');
    return collapsed.replaceAll(RegExp(r'^_|_$'), '').isEmpty
        ? 'class'
        : collapsed.replaceAll(RegExp(r'^_|_$'), '');
  }

  String _escapeCsv(String value) {
    final escaped = value.replaceAll('"', '""');
    final needsQuotes =
        escaped.contains(',') ||
        escaped.contains('"') ||
        escaped.contains('\n') ||
        escaped.contains('\r');
    return needsQuotes ? '"$escaped"' : escaped;
  }

  String _formatCsvDateTime(DateTime value) {
    final local = value.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute:$second';
  }

  List<List<String>> _readCsvRows(String content) {
    final normalized = content.replaceFirst('\ufeff', '');
    final lines = const LineSplitter().convert(normalized);
    return lines.map(_parseCsvLine).toList();
  }

  List<String> _parseCsvLine(String line) {
    final values = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        final isEscapedQuote =
            inQuotes && i + 1 < line.length && line[i + 1] == '"';
        if (isEscapedQuote) {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
        continue;
      }

      if (char == ',' && !inQuotes) {
        values.add(buffer.toString());
        buffer.clear();
        continue;
      }

      buffer.write(char);
    }

    values.add(buffer.toString());
    return values;
  }

  String _normalizeCsvHeader(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  int _findHeaderIndex(List<String> headers, List<String> candidates) {
    for (final candidate in candidates) {
      final index = headers.indexOf(candidate);
      if (index != -1) {
        return index;
      }
    }
    return -1;
  }

  String _csvCellValue(List<String> row, int index) {
    if (index < 0 || index >= row.length) {
      return '';
    }
    return row[index].trim();
  }

  List<String> _parseMeetingDays(String rawValue) {
    if (rawValue.trim().isEmpty) {
      return const [];
    }

    return rawValue
        .split(RegExp(r'\s*(?:\||;|/|,)\s*'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
  }

  Map<String, dynamic> _buildClassPayload({
    required String name,
    String? subject,
    String? room,
    String? startTime,
    String? endTime,
    List<String>? meetingDays,
  }) {
    return {
      'name': name.trim(),
      'subject': subject?.trim().isEmpty == true ? null : subject?.trim(),
      'room': room?.trim().isEmpty == true ? null : room?.trim(),
      'start_time': startTime?.trim().isEmpty == true
          ? null
          : startTime?.trim(),
      'end_time': endTime?.trim().isEmpty == true ? null : endTime?.trim(),
      'meeting_days': meetingDays ?? const <String>[],
    };
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
