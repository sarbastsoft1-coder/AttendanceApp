import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../localization/localization_extensions.dart';
import '../models/leave_request_model.dart';
import '../providers/auth_provider.dart';
import '../providers/leave_request_provider.dart';
import '../widgets/custom_button.dart';
import '../widgets/responsive_layout.dart';

/// Leave Request Screen — students submit leave; teachers/admins review
class LeaveRequestScreen extends StatefulWidget {
  const LeaveRequestScreen({super.key});

  @override
  State<LeaveRequestScreen> createState() => _LeaveRequestScreenState();
}

class _LeaveRequestScreenState extends State<LeaveRequestScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String t(String text, {Map<String, String> params = const {}}) =>
      context.t(text, params: params);

  @override
  void initState() {
    super.initState();
    final isTeacherOrAdmin =
        context.read<AuthProvider>().user?.role != 'student';
    _tabController = TabController(
      length: isTeacherOrAdmin ? 3 : 2,
      vsync: this,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LeaveRequestProvider>().fetchLeaveRequests();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await context.read<LeaveRequestProvider>().fetchLeaveRequests();
  }

  void _showSubmitDialog() {
    final screenContext = context;
    showDialog(
      context: context,
      builder: (context) => _SubmitLeaveDialog(
        onSubmit: ({required DateTime date, required String reason}) async {
          final provider = screenContext.read<LeaveRequestProvider>();
          final auth = screenContext.read<AuthProvider>();
          final success = await provider.submitLeaveRequest(
            userId: auth.user?.id,
            leaveDate: date,
            reason: reason,
          );
          if (!screenContext.mounted) return;
          if (success) {
            Navigator.of(screenContext).pop();
          }
          ScaffoldMessenger.of(screenContext).showSnackBar(
            SnackBar(
              content: Text(
                success
                    ? screenContext.tRead('Leave request submitted!')
                    : (provider.error ??
                          screenContext.tRead('Failed to submit')),
              ),
              backgroundColor: success
                  ? AppTheme.successColor
                  : AppTheme.errorColor,
            ),
          );
          if (success) _refresh();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final isTeacherOrAdmin = user?.role == 'teacher' || user?.role == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: Text(t('Leave Requests')),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryLight,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: [
            Tab(text: t('All')),
            Tab(text: t('Pending')),
            if (isTeacherOrAdmin) Tab(text: t('Reviewed')),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refresh,
          ),
        ],
      ),
      body: Consumer<LeaveRequestProvider>(
        builder: (context, provider, _) {
          final reviewedRequests = provider.leaveRequests
              .where((request) => !request.isPending)
              .toList();

          if (provider.isLoading && provider.leaveRequests.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            );
          }

          if (provider.error != null && provider.leaveRequests.isEmpty) {
            return _LeaveLoadError(message: provider.error!, onRetry: _refresh);
          }

          return Column(
            children: [
              _LeaveSummaryStrip(requests: provider.leaveRequests),
              if (provider.error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _LeaveErrorBanner(
                    message: provider.error!,
                    onRetry: _refresh,
                  ),
                ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _LeaveList(
                      requests: provider.leaveRequests,
                      onRefresh: _refresh,
                      isTeacherOrAdmin: isTeacherOrAdmin,
                      currentUserId: user?.id,
                      isBusy: provider.isLoading,
                    ),
                    _LeaveList(
                      requests: provider.pendingRequests,
                      onRefresh: _refresh,
                      isTeacherOrAdmin: isTeacherOrAdmin,
                      currentUserId: user?.id,
                      isBusy: provider.isLoading,
                    ),
                    if (isTeacherOrAdmin)
                      _LeaveList(
                        requests: reviewedRequests,
                        onRefresh: _refresh,
                        isTeacherOrAdmin: isTeacherOrAdmin,
                        currentUserId: user?.id,
                        isBusy: provider.isLoading,
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showSubmitDialog,
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          t('New Request'),
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ─── Leave List ───────────────────────────────────────────────

class _LeaveSummaryStrip extends StatelessWidget {
  final List<LeaveRequest> requests;

  const _LeaveSummaryStrip({required this.requests});

  @override
  Widget build(BuildContext context) {
    final approvedCount = requests
        .where((request) => request.isApproved)
        .length;
    final rejectedCount = requests
        .where((request) => request.isRejected)
        .length;
    final pendingCount = requests.where((request) => request.isPending).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _LeaveSummaryCard(
            label: 'All',
            count: requests.length,
            icon: Icons.inbox_rounded,
            color: AppTheme.primaryColor,
          ),
          _LeaveSummaryCard(
            label: 'Pending',
            count: pendingCount,
            icon: Icons.hourglass_top_rounded,
            color: AppTheme.warningColor,
          ),
          _LeaveSummaryCard(
            label: 'Approved',
            count: approvedCount,
            icon: Icons.check_circle_rounded,
            color: AppTheme.successColor,
          ),
          _LeaveSummaryCard(
            label: 'Rejected',
            count: rejectedCount,
            icon: Icons.cancel_rounded,
            color: AppTheme.errorColor,
          ),
        ],
      ),
    );
  }
}

class _LeaveSummaryCard extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;

  const _LeaveSummaryCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = ResponsiveLayout.isCompact(context)
        ? ((screenWidth - 44) / 2).clamp(132.0, 160.0)
        : 160.0;

    return SizedBox(
      width: cardWidth,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.cardDecoration(),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.t(label),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaveLoadError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _LeaveLoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 56,
              color: AppTheme.errorColor.withValues(alpha: 0.8),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                onRetry();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.t('Retry')),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaveErrorBanner extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _LeaveErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: AppTheme.errorColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: () {
              onRetry();
            },
            child: Text(context.t('Retry')),
          ),
        ],
      ),
    );
  }
}

class _LeaveList extends StatelessWidget {
  final List<LeaveRequest> requests;
  final Future<void> Function() onRefresh;
  final bool isTeacherOrAdmin;
  final int? currentUserId;
  final bool isBusy;

  const _LeaveList({
    required this.requests,
    required this.onRefresh,
    required this.isTeacherOrAdmin,
    required this.currentUserId,
    required this.isBusy,
  });

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        color: AppTheme.primaryColor,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 96),
            Column(
              children: [
                Icon(
                  Icons.beach_access_outlined,
                  size: 64,
                  color: AppTheme.textMuted,
                ),
                const SizedBox(height: 16),
                Text(
                  context.t('No leave requests found'),
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppTheme.primaryColor,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: requests.length,
        itemBuilder: (context, index) {
          return _LeaveCard(
            leave: requests[index],
            isTeacherOrAdmin: isTeacherOrAdmin,
            currentUserId: currentUserId,
            isBusy: isBusy,
          );
        },
      ),
    );
  }
}

// ─── Leave Card ───────────────────────────────────────────────

class _LeaveCard extends StatelessWidget {
  final LeaveRequest leave;
  final bool isTeacherOrAdmin;
  final int? currentUserId;
  final bool isBusy;

  const _LeaveCard({
    required this.leave,
    required this.isTeacherOrAdmin,
    required this.currentUserId,
    required this.isBusy,
  });

  bool get _canReview => isTeacherOrAdmin && leave.isPending;

  bool get _isOwner =>
      currentUserId != null && leave.submittedById == currentUserId;

  bool get _canEdit => leave.isPending && _isOwner;

  bool get _canDelete =>
      isTeacherOrAdmin ||
      (leave.isPending &&
          (currentUserId != null && leave.submittedById == currentUserId));

  bool get _showEditAction => _isOwner;

  bool get _showDeleteAction => isTeacherOrAdmin || _isOwner;

  Color get _statusColor {
    switch (leave.status) {
      case 'approved':
        return AppTheme.successColor;
      case 'rejected':
        return AppTheme.errorColor;
      default:
        return AppTheme.warningColor;
    }
  }

  IconData get _statusIcon {
    switch (leave.status) {
      case 'approved':
        return Icons.check_circle_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      default:
        return Icons.hourglass_empty_rounded;
    }
  }

  void _showActionMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.warningColor,
      ),
    );
  }

  Future<void> _handleEditTap(BuildContext context) async {
    if (!_isOwner) {
      return;
    }
    if (!leave.isPending) {
      _showActionMessage(
        context,
        context.tRead('Reviewed requests cannot be edited.'),
      );
      return;
    }

    final screenContext = context;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _SubmitLeaveDialog(
        titleText: 'Edit Leave Request',
        submitButtonText: 'Save Changes',
        submitIcon: Icons.save_rounded,
        initialDate: leave.leaveDate,
        initialReason: leave.reason,
        onSubmit: ({required DateTime date, required String reason}) async {
          final provider = screenContext.read<LeaveRequestProvider>();
          final success = await provider.updateLeaveRequest(
            leave.id,
            leaveDate: date,
            reason: reason,
          );
          if (!screenContext.mounted) {
            return;
          }
          if (success) {
            Navigator.of(screenContext).pop();
          }
          ScaffoldMessenger.of(screenContext).showSnackBar(
            SnackBar(
              content: Text(
                success
                    ? screenContext.tRead('Leave request updated')
                    : (provider.error ?? screenContext.tRead('Failed to update')),
              ),
              backgroundColor: success
                  ? AppTheme.successColor
                  : AppTheme.errorColor,
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleDeleteTap(BuildContext context) async {
    if (!_canDelete) {
      _showActionMessage(
        context,
        context.tRead('Reviewed requests cannot be deleted.'),
      );
      return;
    }
    await _confirmDelete(context);
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final screenContext = context;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.t('Delete')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${dialogContext.t('Date')}: ${DateFormat('MMM d, yyyy - hh:mm a').format(leave.leaveDate)}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${dialogContext.t('Reason')}: ${leave.reason}',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.t('Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: Text(
              dialogContext.t('Delete'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !screenContext.mounted) {
      return;
    }

    final provider = screenContext.read<LeaveRequestProvider>();
    final success = await provider.deleteLeaveRequest(leave.id);

    if (!screenContext.mounted) {
      return;
    }

    ScaffoldMessenger.of(screenContext).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? screenContext.tRead('Leave request deleted')
              : (provider.error ?? screenContext.tRead('Failed')),
        ),
        backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
      ),
    );
  }

  void _showReviewDialog(BuildContext context) {
    final screenContext = context;
    final noteController = TextEditingController();
    String selectedStatus = 'approved';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(
              context.t('Review: {name}', params: {'name': leave.displayName}),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Request summary
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.bgElevated,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${context.t('Date')}: ${DateFormat('MMM d, yyyy - hh:mm a').format(leave.leaveDate)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${context.t('Reason')}: ${leave.reason}',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Decision
                  Text(
                    context.t('Decision'),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _DecisionButton(
                          label: 'Approve',
                          icon: Icons.check_circle_rounded,
                          color: AppTheme.successColor,
                          isSelected: selectedStatus == 'approved',
                          onTap: () =>
                              setDialogState(() => selectedStatus = 'approved'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DecisionButton(
                          label: 'Reject',
                          icon: Icons.cancel_rounded,
                          color: AppTheme.errorColor,
                          isSelected: selectedStatus == 'rejected',
                          onTap: () =>
                              setDialogState(() => selectedStatus = 'rejected'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Note
                  Text(
                    context.t('Note (optional)'),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: context.t('Write an optional note...'),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.t('Cancel')),
              ),
              Consumer<LeaveRequestProvider>(
                builder: (context, provider, _) {
                  return ElevatedButton(
                    onPressed: provider.isLoading
                        ? null
                        : () async {
                            final success = await provider.reviewLeaveRequest(
                              leave.id,
                              status: selectedStatus,
                              reviewNote: noteController.text.trim().isEmpty
                                  ? null
                                  : noteController.text.trim(),
                            );
                            if (!screenContext.mounted) return;
                            if (success) {
                              Navigator.of(screenContext).pop();
                            }
                            ScaffoldMessenger.of(screenContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  success
                                      ? screenContext.tRead(
                                          'Leave request {status}',
                                          params: {
                                            'status': screenContext.tRead(
                                              selectedStatus == 'approved'
                                                  ? 'Approved'
                                                  : 'Rejected',
                                            ),
                                          },
                                        )
                                      : (provider.error ??
                                            screenContext.tRead('Failed')),
                                ),
                                backgroundColor: success
                                    ? AppTheme.successColor
                                    : AppTheme.errorColor,
                              ),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedStatus == 'approved'
                          ? AppTheme.successColor
                          : AppTheme.errorColor,
                    ),
                    child: provider.isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            context.t(
                              selectedStatus == 'approved'
                                  ? 'Approve'
                                  : 'Reject',
                            ),
                            style: const TextStyle(color: Colors.white),
                          ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              // Avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    leave.displayName.isNotEmpty
                        ? leave.displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      leave.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      DateFormat(
                        'EEEE, MMM d, yyyy - hh:mm a',
                      ).format(leave.leaveDate),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_statusIcon, size: 13, color: _statusColor),
                    const SizedBox(width: 4),
                    Text(
                      context.t(leave.statusDisplay),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Reason
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.bgElevated,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.notes_rounded,
                  size: 16,
                  color: AppTheme.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    leave.reason,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Review note
          if (leave.reviewNote != null && leave.reviewNote!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _statusColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _statusColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.reply_rounded, size: 14, color: _statusColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      leave.reviewNote!,
                      style: TextStyle(
                        fontSize: 12,
                        color: _statusColor,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Submitted date
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.schedule,
                    size: 13,
                    color: AppTheme.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    context.t(
                      'Submitted {date} at {time}',
                      params: {
                        'date': DateFormat(
                          'MMM d, yyyy',
                        ).format(leave.createdAt),
                        'time': DateFormat('hh:mm a').format(leave.createdAt),
                      },
                    ),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
              if (leave.reviewedByName != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 13,
                      color: AppTheme.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      context.t(
                        'Reviewed by {name}',
                        params: {'name': leave.reviewedByName ?? ''},
                      ),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          if (_canReview || _showEditAction || _showDeleteAction) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (_canReview)
                  OutlinedButton.icon(
                    onPressed: isBusy ? null : () => _showReviewDialog(context),
                    icon: const Icon(Icons.rate_review_rounded, size: 16),
                    label: Text(context.t('Review Request')),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                if (_showEditAction)
                  OutlinedButton.icon(
                    onPressed: isBusy ? null : () => _handleEditTap(context),
                    icon: Icon(
                      _canEdit
                          ? Icons.edit_outlined
                          : Icons.lock_outline_rounded,
                      size: 16,
                    ),
                    label: Text(context.t('Edit Request')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _canEdit
                          ? AppTheme.primaryLight
                          : AppTheme.textMuted,
                      side: BorderSide(
                        color: _canEdit
                            ? AppTheme.primaryColor.withValues(alpha: 0.35)
                            : AppTheme.glassBorder,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                if (_showDeleteAction)
                  OutlinedButton.icon(
                    onPressed: isBusy ? null : () => _handleDeleteTap(context),
                    icon: Icon(
                      _canDelete
                          ? Icons.delete_outline_rounded
                          : Icons.lock_outline_rounded,
                      size: 16,
                    ),
                    label: Text(context.t('Delete Request')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _canDelete
                          ? AppTheme.errorColor
                          : AppTheme.textMuted,
                      side: BorderSide(
                        color: _canDelete
                            ? AppTheme.errorColor.withValues(alpha: 0.35)
                            : AppTheme.glassBorder,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Decision Button ─────────────────────────────────────────

class _DecisionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _DecisionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : AppTheme.bgElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : AppTheme.glassBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : AppTheme.textMuted,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              context.t(label),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? color : AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Submit Leave Dialog ─────────────────────────────────────

class _SubmitLeaveDialog extends StatefulWidget {
  final void Function({required DateTime date, required String reason})
  onSubmit;
  final String titleText;
  final String submitButtonText;
  final IconData submitIcon;
  final DateTime? initialDate;
  final String? initialReason;

  const _SubmitLeaveDialog({
    required this.onSubmit,
    this.titleText = 'Submit Leave Request',
    this.submitButtonText = 'Submit',
    this.submitIcon = Icons.send_rounded,
    this.initialDate,
    this.initialReason,
  });

  @override
  State<_SubmitLeaveDialog> createState() => _SubmitLeaveDialogState();
}

class _SubmitLeaveDialogState extends State<_SubmitLeaveDialog> {
  final _reasonController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  final _formKey = GlobalKey<FormState>();
  bool _attemptedSubmit = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    _reasonController.text = widget.initialReason ?? '';
    _reasonController.addListener(_handleReasonChanged);
  }

  @override
  void dispose() {
    _reasonController.removeListener(_handleReasonChanged);
    _reasonController.dispose();
    super.dispose();
  }

  void _handleReasonChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  bool get _canSubmit => _reasonController.text.trim().length >= 5;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryColor,
              surface: AppTheme.bgCard,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDate.hour,
          _selectedDate.minute,
        );
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryColor,
              surface: AppTheme.bgCard,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.t(widget.titleText)),
      content: Form(
        key: _formKey,
        autovalidateMode: _attemptedSubmit
            ? AutovalidateMode.always
            : AutovalidateMode.onUserInteraction,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date picker
              Text(
                context.t('Leave Date'),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.bgElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.glassBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 18,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('EEEE, MMM d, yyyy').format(_selectedDate),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.arrow_drop_down,
                        color: AppTheme.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                context.t('Time'),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickTime,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.bgElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.glassBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 18,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('hh:mm a').format(_selectedDate),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.arrow_drop_down,
                        color: AppTheme.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Reason
              Text(
                context.t('Reason'),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _reasonController,
                maxLines: 4,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: context.t('Explain the reason for your leave...'),
                  helperText: context.t(
                    'Please provide a reason (min 5 characters)',
                  ),
                  counterStyle: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 5) {
                    return context.t(
                      'Please provide a reason (min 5 characters)',
                    );
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.t('Cancel')),
        ),
        Consumer<LeaveRequestProvider>(
          builder: (context, provider, _) {
            return CustomButton(
              text: widget.submitButtonText,
              isLoading: provider.isLoading,
              onPressed: provider.isLoading || !_canSubmit
                  ? null
                  : () {
                      setState(() {
                        _attemptedSubmit = true;
                      });
                      if (_formKey.currentState!.validate()) {
                        widget.onSubmit(
                          date: _selectedDate,
                          reason: _reasonController.text.trim(),
                        );
                      }
                    },
              icon: widget.submitIcon,
            );
          },
        ),
      ],
    );
  }
}
