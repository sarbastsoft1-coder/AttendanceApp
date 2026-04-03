import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/notification_model.dart';
import '../services/api_service.dart';

/// Notification Provider — manages in-app notifications
class NotificationProvider with ChangeNotifier {
  final ApiService _api = ApiService();

  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _error;

  List<AppNotification> get notifications => _notifications;
  List<AppNotification> get unread =>
      _notifications.where((n) => !n.isRead).toList();
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasUnread => _unreadCount > 0;

  /// Fetch all notifications for the current user
  Future<void> fetchNotifications({bool unreadOnly = false}) async {
    _setLoading(true);
    _error = null;

    try {
      final response = await _api.get(
        ApiConfig.notifications,
        queryParameters: {if (unreadOnly) 'unread_only': true, 'limit': 50},
      );

      _notifications = (response.data as List)
          .map((json) => AppNotification.fromJson(json))
          .toList();

      // Update local unread count
      _unreadCount = _notifications.where((n) => !n.isRead).length;
      _setLoading(false);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
    }
  }

  /// Fetch only the unread count (lightweight poll)
  Future<void> fetchUnreadCount() async {
    try {
      final response = await _api.get(ApiConfig.notificationsUnreadCount);
      final count = UnreadCount.fromJson(response.data);
      if (_unreadCount != count.count) {
        _unreadCount = count.count;
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) print('Error fetching unread count: $e');
    }
  }

  /// Fetch a small unread snapshot for live in-app banners.
  Future<List<AppNotification>> fetchLatestUnreadNotifications({
    int limit = 10,
  }) async {
    try {
      final response = await _api.get(
        ApiConfig.notifications,
        queryParameters: {'unread_only': true, 'limit': limit},
      );

      return (response.data as List)
          .map((json) => AppNotification.fromJson(json))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching latest unread notifications: $e');
      }
      return const [];
    }
  }

  /// Mark specific notifications (or all) as read
  Future<bool> markAsRead({List<int>? ids}) async {
    try {
      await _api.post(
        ApiConfig.notificationsMarkRead,
        data: ids != null ? {'notification_ids': ids} : {},
      );

      // Update local state
      if (ids == null) {
        _notifications = _notifications
            .map((n) => n.copyWith(isRead: true))
            .toList();
        _unreadCount = 0;
      } else {
        _notifications = _notifications.map((n) {
          if (ids.contains(n.id)) return n.copyWith(isRead: true);
          return n;
        }).toList();
        _unreadCount = _notifications.where((n) => !n.isRead).length;
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Mark a single notification as read
  Future<bool> markOneAsRead(int notificationId) async {
    return markAsRead(ids: [notificationId]);
  }

  /// Mark all notifications as read
  Future<bool> markAllAsRead() async {
    return markAsRead();
  }

  /// Delete a notification
  Future<bool> deleteNotification(int notificationId) async {
    try {
      await _api.delete(ApiConfig.notificationById(notificationId));

      _notifications.removeWhere((n) => n.id == notificationId);
      _unreadCount = _notifications.where((n) => !n.isRead).length;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Clear all notifications locally (does not call API)
  void clearLocal() {
    _notifications = [];
    _unreadCount = 0;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
