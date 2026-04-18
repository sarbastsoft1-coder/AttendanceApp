import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../localization/localization_extensions.dart';
import '../models/notification_model.dart';

String _localizedNotificationRole(BuildContext context, String rawRole) {
  final normalized = rawRole.trim().toLowerCase().replaceAll('_', ' ');
  switch (normalized) {
    case 'teacher':
    case 'user':
      return context.tr('teacher');
    case 'super teacher':
    case 'super user':
      return context.tr('superTeacher');
    case 'admin':
      return context.tr('admin');
    case 'super admin':
      return context.tr('superAdmin');
    default:
      return rawRole;
  }
}

String localizedNotificationTitle(
  BuildContext context,
  AppNotification notification,
) {
  switch (notification.title) {
    case 'Teacher Group Invitation':
    case 'User Group Invitation':
      return context.tr('userGroupInvitationTitle');
    case 'Teacher Invitation Accepted':
    case 'User Invitation Accepted':
      return context.tr('userInvitationAcceptedTitle');
    case 'Teacher Invitation Rejected':
    case 'User Invitation Rejected':
      return context.tr('userInvitationRejectedTitle');
    case 'Supervisor Access Updated':
      return context.tr('supervisorAccessUpdatedTitle');
    default:
      return context.t(notification.title);
  }
}

String notificationTimestampLabel(BuildContext context, DateTime dt) {
  final localTime = dt.toLocal();
  final now = DateTime.now();
  final locale = Localizations.localeOf(context).toLanguageTag();
  final timeFormat = DateFormat('h:mm a', locale);
  final sameYearDateTimeFormat = DateFormat('MMM d, h:mm a', locale);
  final fullDateTimeFormat = DateFormat('MMM d, yyyy, h:mm a', locale);

  final startOfToday = DateTime(now.year, now.month, now.day);
  final notificationDate = DateTime(
    localTime.year,
    localTime.month,
    localTime.day,
  );

  if (notificationDate == startOfToday) {
    return timeFormat.format(localTime);
  }

  if (localTime.year == now.year) {
    return sameYearDateTimeFormat.format(localTime);
  }

  return fullDateTimeFormat.format(localTime);
}

String notificationTimeOnlyLabel(BuildContext context, DateTime dt) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  return DateFormat('h:mm a', locale).format(dt.toLocal());
}

String localizedNotificationMessage(
  BuildContext context,
  AppNotification notification,
) {
  final message = notification.message;

  final lateCheckInMatch = RegExp(
    r'^You have been marked late today at ([0-9]{2}:[0-9]{2})\.$',
  ).firstMatch(message);
  if (lateCheckInMatch != null) {
    return context.t(
      'You have been marked late today at {time}.',
      params: {
        'time': notificationTimeOnlyLabel(context, notification.createdAt),
      },
    );
  }

  final lowAttendanceMatch = RegExp(
    r'^Your attendance is ([0-9]+(?:\.[0-9]+)?)%, which is below the ([0-9]+(?:\.[0-9]+)?)% threshold\.$',
  ).firstMatch(message);
  if (lowAttendanceMatch != null) {
    return context.t(
      'Your attendance is {percent}%, which is below the {threshold}% threshold.',
      params: {
        'percent': lowAttendanceMatch.group(1)!,
        'threshold': lowAttendanceMatch.group(2)!,
      },
    );
  }

  final newLeaveRequestMatch = RegExp(
    r'^(.+?) submitted a leave request for (.+?)\.$',
  ).firstMatch(message);
  if (newLeaveRequestMatch != null) {
    return context.t(
      '{name} submitted a leave request for {date}.',
      params: {
        'name': newLeaveRequestMatch.group(1)!,
        'date': newLeaveRequestMatch.group(2)!,
      },
    );
  }

  final leaveDecisionMatch = RegExp(
    r'^Your leave request for (.+?) was (approved|rejected)\.(?: Note: (.+))?$',
  ).firstMatch(message);
  if (leaveDecisionMatch != null) {
    final status = leaveDecisionMatch.group(2)!.toLowerCase() == 'approved'
        ? context.t('Approved')
        : context.t('Rejected');
    final params = {'date': leaveDecisionMatch.group(1)!, 'status': status};
    final note = leaveDecisionMatch.group(3);
    if (note != null && note.isNotEmpty) {
      return context.t(
        'Your leave request for {date} was {status}. Note: {note}',
        params: {...params, 'note': note},
      );
    }
    return context.t(
      'Your leave request for {date} was {status}.',
      params: params,
    );
  }

  final groupInviteMatch = RegExp(
    r'^You were invited to join (.+?) as (.+?)\.$',
  ).firstMatch(message);
  if (groupInviteMatch != null) {
    return context.t(
      'You were invited to join {group} as {role}.',
      params: {
        'group': groupInviteMatch.group(1)!,
        'role': _localizedNotificationRole(context, groupInviteMatch.group(2)!),
      },
    );
  }

  final groupJoinedMatch = RegExp(
    r'^(.+?) joined (.+?)\.$',
  ).firstMatch(message);
  if (groupJoinedMatch != null) {
    return context.t(
      '{name} joined {group}.',
      params: {
        'name': groupJoinedMatch.group(1)!,
        'group': groupJoinedMatch.group(2)!,
      },
    );
  }

  final groupRejectedMatch = RegExp(
    r'^(.+?) rejected the invitation to (.+?)\.$',
  ).firstMatch(message);
  if (groupRejectedMatch != null) {
    return context.t(
      '{name} rejected the invitation to {group}.',
      params: {
        'name': groupRejectedMatch.group(1)!,
        'group': groupRejectedMatch.group(2)!,
      },
    );
  }

  final roleUpdatedMatch = RegExp(
    r'^Your supervision role in (.+?) is now (.+?)\.$',
  ).firstMatch(message);
  if (roleUpdatedMatch != null) {
    return context.t(
      'Your supervision role in {group} is now {role}.',
      params: {
        'group': roleUpdatedMatch.group(1)!,
        'role': _localizedNotificationRole(context, roleUpdatedMatch.group(2)!),
      },
    );
  }

  return context.t(message);
}
