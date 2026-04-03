/// In-App Notification Model
class AppNotification {
  final int id;
  final int userId;
  final String title;
  final String message;
  final String type; // attendance, leave, system, alert
  final bool isRead;
  final String? relatedType;
  final int? relatedId;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    this.relatedType,
    this.relatedId,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: json['type'] ?? 'system',
      isRead: json['is_read'] ?? false,
      relatedType: json['related_type'],
      relatedId: json['related_id'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at']).toLocal()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'message': message,
      'type': type,
      'is_read': isRead,
      'related_type': relatedType,
      'related_id': relatedId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      userId: userId,
      title: title,
      message: message,
      type: type,
      isRead: isRead ?? this.isRead,
      relatedType: relatedType,
      relatedId: relatedId,
      createdAt: createdAt,
    );
  }
}

/// Unread notification count
class UnreadCount {
  final int count;

  const UnreadCount({required this.count});

  factory UnreadCount.fromJson(Map<String, dynamic> json) {
    return UnreadCount(count: json['count'] ?? 0);
  }
}
