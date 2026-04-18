import 'class_model.dart';

class TeacherGroupMember {
  final int id;
  final int teacherId;
  final String teacherName;
  final String teacherEmail;
  final String teacherRole;
  final DateTime joinedAt;

  const TeacherGroupMember({
    required this.id,
    required this.teacherId,
    required this.teacherName,
    required this.teacherEmail,
    required this.teacherRole,
    required this.joinedAt,
  });

  factory TeacherGroupMember.fromJson(Map<String, dynamic> json) {
    return TeacherGroupMember(
      id: json['id'] ?? 0,
      teacherId: json['teacher_id'] ?? 0,
      teacherName: json['teacher_name'] ?? '',
      teacherEmail: json['teacher_email'] ?? '',
      teacherRole: json['teacher_role'] ?? 'teacher',
      joinedAt: json['joined_at'] != null
          ? DateTime.parse(json['joined_at'])
          : DateTime.now(),
    );
  }

  bool get isSuperTeacher => teacherRole == 'super_teacher';
}

class TeacherGroupInvite {
  final int id;
  final int groupId;
  final String email;
  final int invitedById;
  final String? invitedByName;
  final int? teacherId;
  final String? teacherName;
  final String targetRole;
  final String status;
  final String? note;
  final DateTime createdAt;
  final DateTime? respondedAt;

  const TeacherGroupInvite({
    required this.id,
    required this.groupId,
    required this.email,
    required this.invitedById,
    this.invitedByName,
    this.teacherId,
    this.teacherName,
    required this.targetRole,
    required this.status,
    this.note,
    required this.createdAt,
    this.respondedAt,
  });

  factory TeacherGroupInvite.fromJson(Map<String, dynamic> json) {
    return TeacherGroupInvite(
      id: json['id'] ?? 0,
      groupId: json['group_id'] ?? 0,
      email: json['email'] ?? '',
      invitedById: json['invited_by_id'] ?? 0,
      invitedByName: json['invited_by_name'],
      teacherId: json['teacher_id'],
      teacherName: json['teacher_name'],
      targetRole: json['target_role'] ?? 'teacher',
      status: json['status'] ?? 'pending',
      note: json['note'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      respondedAt: json['responded_at'] != null
          ? DateTime.parse(json['responded_at'])
          : null,
    );
  }

  bool get isPending => status == 'pending';
}

class GroupSharedClass {
  final int id;
  final int groupId;
  final int classId;
  final String className;
  final int sharedById;
  final String? sharedByName;
  final DateTime createdAt;

  const GroupSharedClass({
    required this.id,
    required this.groupId,
    required this.classId,
    required this.className,
    required this.sharedById,
    this.sharedByName,
    required this.createdAt,
  });

  factory GroupSharedClass.fromJson(Map<String, dynamic> json) {
    return GroupSharedClass(
      id: json['id'] ?? 0,
      groupId: json['group_id'] ?? 0,
      classId: json['class_id'] ?? 0,
      className: json['class_name'] ?? '',
      sharedById: json['shared_by_id'] ?? 0,
      sharedByName: json['shared_by_name'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }
}

class TeacherGroup {
  final int id;
  final String name;
  final String? description;
  final int createdById;
  final String? createdByName;
  final bool canManage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<TeacherGroupMember> members;
  final List<TeacherGroupInvite> invitations;
  final List<GroupSharedClass> sharedClasses;

  const TeacherGroup({
    required this.id,
    required this.name,
    this.description,
    required this.createdById,
    this.createdByName,
    this.canManage = false,
    required this.createdAt,
    required this.updatedAt,
    this.members = const [],
    this.invitations = const [],
    this.sharedClasses = const [],
  });

  factory TeacherGroup.fromJson(Map<String, dynamic> json) {
    return TeacherGroup(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'],
      createdById: json['created_by_id'] ?? 0,
      createdByName: json['created_by_name'],
      canManage: json['can_manage'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      members: (json['members'] as List? ?? const [])
          .map(
            (item) => TeacherGroupMember.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      invitations: (json['invitations'] as List? ?? const [])
          .map(
            (item) => TeacherGroupInvite.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      sharedClasses: (json['shared_classes'] as List? ?? const [])
          .map(
            (item) => GroupSharedClass.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }

  int get pendingInviteCount =>
      invitations.where((invite) => invite.isPending).length;
}

class SupervisionOverview {
  final bool canCreateGroups;
  final bool canManageGroups;
  final bool canShareClasses;
  final int pendingLeaveCount;
  final List<TeacherGroup> groups;
  final List<TeacherGroupInvite> invitations;
  final List<ClassModel> shareableClasses;

  const SupervisionOverview({
    required this.canCreateGroups,
    required this.canManageGroups,
    required this.canShareClasses,
    required this.pendingLeaveCount,
    this.groups = const [],
    this.invitations = const [],
    this.shareableClasses = const [],
  });

  factory SupervisionOverview.fromJson(Map<String, dynamic> json) {
    return SupervisionOverview(
      canCreateGroups: json['can_create_groups'] ?? false,
      canManageGroups: json['can_manage_groups'] ?? false,
      canShareClasses: json['can_share_classes'] ?? false,
      pendingLeaveCount: json['pending_leave_count'] ?? 0,
      groups: (json['groups'] as List? ?? const [])
          .map(
            (item) =>
                TeacherGroup.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      invitations: (json['invitations'] as List? ?? const [])
          .map(
            (item) => TeacherGroupInvite.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      shareableClasses: (json['shareable_classes'] as List? ?? const [])
          .map(
            (item) =>
                ClassModel.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
    );
  }

  List<TeacherGroupInvite> get pendingInvitations =>
      invitations.where((invite) => invite.isPending).toList();
}
