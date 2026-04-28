/// User Model
class User {
  final int id;
  final String email;
  final String fullName;
  final String? phone;
  final String? department;
  final String role;
  final bool hasRegisteredFace;
  final bool isActive;
  final bool isVerified;
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    this.department,
    required this.role,
    required this.hasRegisteredFace,
    required this.isActive,
    required this.isVerified,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      email: json['email'] ?? '',
      fullName: json['full_name'] ?? '',
      phone: json['phone'],
      department: json['department'],
      role: json['role'] ?? 'student',
      hasRegisteredFace: json['has_registered_face'] ?? false,
      isActive: json['is_active'] ?? true,
      isVerified: json['is_verified'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'phone': phone,
      'department': department,
      'role': role,
      'has_registered_face': hasRegisteredFace,
      'is_active': isActive,
      'is_verified': isVerified,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isAdmin => role == 'admin' || role == 'super_admin';
  bool get isTeacher => role == 'teacher' || role == 'super_teacher';
  bool get isStudent => role == 'student' || role == 'managed_student';
  bool get isManagedStudent => role == 'managed_student';
  bool get isSuperAdmin => role == 'super_admin';
  bool get isSuperTeacher => role == 'super_teacher';
  bool get isSupervisor => isSuperAdmin || isSuperTeacher;
  bool get canUseGroups => !isManagedStudent;

  User copyWith({
    int? id,
    String? email,
    String? fullName,
    String? phone,
    String? department,
    String? role,
    bool? hasRegisteredFace,
    bool? isActive,
    bool? isVerified,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      department: department ?? this.department,
      role: role ?? this.role,
      hasRegisteredFace: hasRegisteredFace ?? this.hasRegisteredFace,
      isActive: isActive ?? this.isActive,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
