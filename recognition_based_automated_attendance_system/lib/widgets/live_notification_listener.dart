import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../localization/localization_extensions.dart';
import '../models/notification_model.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../utils/notification_text.dart';

class LiveNotificationListener extends StatefulWidget {
  final Widget child;

  const LiveNotificationListener({super.key, required this.child});

  @override
  State<LiveNotificationListener> createState() =>
      _LiveNotificationListenerState();
}

class _LiveNotificationListenerState extends State<LiveNotificationListener> {
  Timer? _pollTimer;
  int? _activeUserId;
  final Set<int> _knownUnreadIds = <int>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pollNotifications();
      _pollTimer = Timer.periodic(
        const Duration(seconds: 20),
        (_) => _pollNotifications(),
      );
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _pollNotifications() async {
    if (!mounted) {
      return;
    }

    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) {
      _activeUserId = null;
      _knownUnreadIds.clear();
      return;
    }

    final provider = context.read<NotificationProvider>();
    final unreadNotifications = await provider.fetchLatestUnreadNotifications();

    if (!mounted) {
      return;
    }

    await provider.fetchUnreadCount();

    if (_activeUserId != user.id) {
      _activeUserId = user.id;
      _knownUnreadIds
        ..clear()
        ..addAll(unreadNotifications.map((notification) => notification.id));
      return;
    }

    final newNotifications = unreadNotifications
        .where((notification) => !_knownUnreadIds.contains(notification.id))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    for (final notification in newNotifications) {
      _knownUnreadIds.add(notification.id);
      _showNotification(notification);
    }
  }

  void _showNotification(AppNotification notification) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }

    final typeColor = _colorFor(notification.type);
    final timestamp = notificationTimeOnlyLabel(context, notification.createdAt);
    final message = localizedNotificationMessage(context, notification);

    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.bgCard,
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_iconFor(notification.type), color: typeColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timestamp,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: context.tRead('Notifications'),
          textColor: AppTheme.primaryLight,
          onPressed: () {
            Navigator.of(context).pushNamed('/notifications');
          },
        ),
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'attendance':
        return Icons.how_to_reg_rounded;
      case 'leave':
        return Icons.beach_access_rounded;
      case 'alert':
        return Icons.warning_amber_rounded;
      case 'system':
      default:
        return Icons.notifications_active_outlined;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'attendance':
        return AppTheme.successColor;
      case 'leave':
        return AppTheme.infoColor;
      case 'alert':
        return AppTheme.warningColor;
      case 'system':
      default:
        return AppTheme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
