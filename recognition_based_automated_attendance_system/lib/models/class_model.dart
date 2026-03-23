
class ClassModel {
  final int id;
  final String name;
  final int teacherId;
  final DateTime createdAt;
  final int studentCount;

  ClassModel({
    required this.id,
    required this.name,
    required this.teacherId,
    required this.createdAt,
    this.studentCount = 0,
  });

  factory ClassModel.fromJson(Map<String, dynamic> json) {
    return ClassModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      teacherId: json['teacher_id'] ?? 0,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      studentCount: json['student_count'] ?? 0,
    );
  }
}

class Student {
  final int id;
  final String name;
  final int classId;
  final bool hasRegisteredFace;
  final DateTime createdAt;

  Student({
    required this.id,
    required this.name,
    required this.classId,
    required this.hasRegisteredFace,
    required this.createdAt,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      classId: json['class_id'] ?? 0,
      hasRegisteredFace: json['has_registered_face'] ?? false,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
    );
  }
}
