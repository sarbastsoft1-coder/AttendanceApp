class ClassModel {
  final int id;
  final String name;
  final int teacherId;
  final String? subject;
  final String? room;
  final String? startTime;
  final String? endTime;
  final List<String> meetingDays;
  final DateTime createdAt;
  final int studentCount;

  ClassModel({
    required this.id,
    required this.name,
    required this.teacherId,
    this.subject,
    this.room,
    this.startTime,
    this.endTime,
    this.meetingDays = const [],
    required this.createdAt,
    this.studentCount = 0,
  });

  factory ClassModel.fromJson(Map<String, dynamic> json) {
    return ClassModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      teacherId: json['teacher_id'] ?? 0,
      subject: json['subject'],
      room: json['room'],
      startTime: json['start_time'],
      endTime: json['end_time'],
      meetingDays:
          (json['meeting_days'] as List?)
              ?.map((item) => item.toString())
              .toList() ??
          const [],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      studentCount: json['student_count'] ?? 0,
    );
  }

  String get scheduleSummary {
    final parts = <String>[];
    if (subject != null && subject!.trim().isNotEmpty) {
      parts.add(subject!.trim());
    }
    if (room != null && room!.trim().isNotEmpty) {
      parts.add('Room ${room!.trim()}');
    }
    if (startTime != null &&
        startTime!.trim().isNotEmpty &&
        endTime != null &&
        endTime!.trim().isNotEmpty) {
      parts.add('${startTime!.trim()} - ${endTime!.trim()}');
    }
    if (meetingDays.isNotEmpty) {
      parts.add(meetingDays.join(', '));
    }
    return parts.join(' | ');
  }
}

class Student {
  final int id;
  final String name;
  final int classId;
  final int? linkedUserId;
  final bool hasRegisteredFace;
  final DateTime createdAt;

  Student({
    required this.id,
    required this.name,
    required this.classId,
    this.linkedUserId,
    required this.hasRegisteredFace,
    required this.createdAt,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      classId: json['class_id'] ?? 0,
      linkedUserId: json['linked_user_id'],
      hasRegisteredFace: json['has_registered_face'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }
}
