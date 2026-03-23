/// Exam Proctoring Models
/// Contains models for exam cheating detection with ESP-style overlays
library;

/// Represents a detected object in the exam proctoring scan
class DetectedObject {
  final String type;
  final String label;
  final double confidence;
  final List<double> bbox; // [x1, y1, x2, y2] normalized 0-1
  final String color;

  DetectedObject({
    required this.type,
    required this.label,
    required this.confidence,
    required this.bbox,
    required this.color,
  });

  factory DetectedObject.fromJson(Map<String, dynamic> json) {
    return DetectedObject(
      type: json['type'] ?? '',
      label: json['label'] ?? '',
      confidence: (json['confidence'] ?? 0).toDouble(),
      bbox: (json['bbox'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [0, 0, 0, 0],
      color: json['color'] ?? 'red',
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'label': label,
        'confidence': confidence,
        'bbox': bbox,
        'color': color,
      };
}

/// Result of an exam proctoring scan
class ExamProctorResult {
  final bool studentVerified;
  final int? studentId;
  final String? studentName;
  final int faceCount;
  final String gazeDirection;
  final List<DetectedObject> detectedObjects;
  final double suspicionScore;
  final List<String> violations;
  final bool isCheating;
  final DateTime timestamp;
  final String message;

  ExamProctorResult({
    required this.studentVerified,
    this.studentId,
    this.studentName,
    required this.faceCount,
    required this.gazeDirection,
    required this.detectedObjects,
    required this.suspicionScore,
    required this.violations,
    required this.isCheating,
    required this.timestamp,
    required this.message,
  });

  factory ExamProctorResult.fromJson(Map<String, dynamic> json) {
    return ExamProctorResult(
      studentVerified: json['student_verified'] ?? false,
      studentId: json['student_id'],
      studentName: json['student_name'],
      faceCount: json['face_count'] ?? 0,
      gazeDirection: json['gaze_direction'] ?? 'unknown',
      detectedObjects: (json['detected_objects'] as List<dynamic>?)
              ?.map((e) => DetectedObject.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      suspicionScore: (json['suspicion_score'] ?? 0).toDouble(),
      violations:
          (json['violations'] as List<dynamic>?)?.cast<String>() ?? [],
      isCheating: json['is_cheating'] ?? false,
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      message: json['message'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'student_verified': studentVerified,
        'student_id': studentId,
        'student_name': studentName,
        'face_count': faceCount,
        'gaze_direction': gazeDirection,
        'detected_objects': detectedObjects.map((e) => e.toJson()).toList(),
        'suspicion_score': suspicionScore,
        'violations': violations,
        'is_cheating': isCheating,
        'timestamp': timestamp.toIso8601String(),
        'message': message,
      };
}
