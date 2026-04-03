import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../localization/localization_extensions.dart';
import '../models/notification_model.dart';
import '../providers/notification_provider.dart';
import '../utils/notification_text.dart';

/// Notifications Screen — displays all in-app notifications with read/unread state
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _showUnreadOnly = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().fetchNotifications();
    });
  }

  Future<void> _refresh() async {
    await context.read<NotificationProvider>().fetchNotifications();
  }

  void _markAllRead() async {
    final provider = context.read<NotificationProvider>();
    await provider.markAllAsRead();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tRead('All notifications marked as read')),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Consumer<NotificationProvider>(
          builder: (context, provider, _) {
            final unread = provider.unreadCount;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.t('Notifications')),
                if (unread > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$unread',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        actions: [
          // Filter toggle
          Consumer<NotificationProvider>(
            builder: (context, provider, _) {
              return IconButton(
                icon: Icon(
                  _showUnreadOnly
                      ? Icons.mark_email_unread
                      : Icons.mark_email_read_outlined,
                  color: _showUnreadOnly
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondary,
                ),
                tooltip: _showUnreadOnly
                    ? context.t('Show All')
                    : context.t('Show Unread Only'),
                onPressed: () {
                  setState(() => _showUnreadOnly = !_showUnreadOnly);
                },
              );
            },
          ),
          // Mark all read
          Consumer<NotificationProvider>(
            builder: (context, provider, _) {
              if (!provider.hasUnread) return const SizedBox.shrink();
              return TextButton(
                onPressed: _markAllRead,
                child: Text(
                  context.t('Mark all as read'),
                  style: TextStyle(color: AppTheme.primaryColor, fontSize: 13),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.notifications.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            );
          }

          final notifications = _showUnreadOnly
              ? provider.unread
              : provider.notifications;

          if (notifications.isEmpty) {
            return _EmptyState(showUnreadOnly: _showUnreadOnly);
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            color: AppTheme.primaryColor,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return _NotificationCard(
                  notification: notification,
                  onTap: () => _onNotificationTap(notification),
                  onDismiss: () => _onDismiss(notification),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _onNotificationTap(AppNotification notification) async {
    final provider = context.read<NotificationProvider>();

    // Mark as read
    if (!notification.isRead) {
      await provider.markOneAsRead(notification.id);
    }

    if (!mounted) return;

    // Navigate based on related type
    if (notification.relatedType == 'leave_request') {
      Navigator.pushNamed(context, '/leave-requests');
    }
  }

  Future<void> _onDismiss(AppNotification notification) async {
    final provider = context.read<NotificationProvider>();
    await provider.deleteNotification(notification.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tRead('Notification removed')),
          action: SnackBarAction(
            label: context.tRead('Undo'),
            onPressed: () {
              // Refresh to show it again (simple undo via re-fetch)
              provider.fetchNotifications();
            },
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

// ─── Empty State ─────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool showUnreadOnly;

  const _EmptyState({required this.showUnreadOnly});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            showUnreadOnly
                ? Icons.mark_email_read_outlined
                : Icons.notifications_none_rounded,
            size: 64,
            color: AppTheme.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            showUnreadOnly
                ? context.t('No unread notifications')
                : context.t('No notifications yet'),
            style: const TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            showUnreadOnly
                ? context.t("You're all caught up!")
                : context.t(
                    'Notifications about attendance, leaves, and system events will appear here.',
                  ),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}

// ─── Notification Card ───────────────────────────────────────

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

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
        return Icons.info_outline_rounded;
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

  String _typeLabel(BuildContext context, String type) {
    switch (type) {
      case 'attendance':
        return context.t('Attendance');
      case 'leave':
        return context.t('Leave');
      case 'alert':
        return context.t('Alert');
      case 'system':
      default:
        return context.t('System');
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = _colorFor(notification.type);
    final isUnread = !notification.isRead;

    return Dismissible(
      key: Key('notif_${notification.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppTheme.errorColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
      ),
      onDismissed: (_) => onDismiss(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isUnread
                ? AppTheme.bgCard
                : AppTheme.bgElevated.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isUnread
                  ? typeColor.withValues(alpha: 0.3)
                  : AppTheme.glassBorder,
              width: isUnread ? 1.5 : 0.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _iconFor(notification.type),
                  color: typeColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.t(notification.title),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isUnread
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          notificationTimestampLabel(
                            context,
                            notification.createdAt,
                          ),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      localizedNotificationMessage(context, notification),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Type chip
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _typeLabel(context, notification.type),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: typeColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (isUnread)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: typeColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
