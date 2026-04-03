import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../localization/localization_extensions.dart';
import '../models/leave_request_model.dart';
import '../providers/auth_provider.dart';
import '../providers/leave_request_provider.dart';
import '../widgets/custom_button.dart';

/// Leave Request Screen — students submit leave; teachers/admins review
class LeaveRequestScreen extends StatefulWidget {
  const LeaveRequestScreen({super.key});

  @override
  State<LeaveRequestScreen> createState() => _LeaveRequestScreenState();
}

class _LeaveRequestScreenState extends State<LeaveRequestScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final String _statusFilter = 'all';

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
    await context.read<LeaveRequestProvider>().fetchLeaveRequests(
      statusFilter: _statusFilter == 'all' ? null : _statusFilter,
    );
  }

  void _showSubmitDialog() {
    showDialog(
      context: context,
      builder: (context) => _SubmitLeaveDialog(
        onSubmit: ({required DateTime date, required String reason}) async {
          final provider = context.read<LeaveRequestProvider>();
          final auth = context.read<AuthProvider>();
          final success = await provider.submitLeaveRequest(
            userId: auth.user?.id,
            leaveDate: date,
            reason: reason,
          );
          if (!context.mounted) return;
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                success
                    ? context.t('Leave request submitted!')
                    : (provider.error ?? context.t('Failed to submit')),
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
          if (provider.isLoading && provider.leaveRequests.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _LeaveList(
                requests: provider.leaveRequests,
                onRefresh: _refresh,
                isTeacherOrAdmin: isTeacherOrAdmin,
              ),
              _LeaveList(
                requests: provider.pendingRequests,
                onRefresh: _refresh,
                isTeacherOrAdmin: isTeacherOrAdmin,
              ),
              if (isTeacherOrAdmin)
                _LeaveList(
                  requests: provider.leaveRequests
                      .where((r) => !r.isPending)
                      .toList(),
                  onRefresh: _refresh,
                  isTeacherOrAdmin: isTeacherOrAdmin,
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

class _LeaveList extends StatelessWidget {
  final List<LeaveRequest> requests;
  final Future<void> Function() onRefresh;
  final bool isTeacherOrAdmin;

  const _LeaveList({
    required this.requests,
    required this.onRefresh,
    required this.isTeacherOrAdmin,
  });

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.beach_access_outlined,
              size: 64,
              color: AppTheme.textMuted,
            ),
            SizedBox(height: 16),
            Text(
              context.t('No leave requests found'),
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppTheme.primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: requests.length,
        itemBuilder: (context, index) {
          return _LeaveCard(
            leave: requests[index],
            isTeacherOrAdmin: isTeacherOrAdmin,
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

  const _LeaveCard({required this.leave, required this.isTeacherOrAdmin});

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

  void _showReviewDialog(BuildContext context) {
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
                          '${context.t('Date')}: ${DateFormat('MMM d, yyyy').format(leave.leaveDate)}',
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
                            if (!context.mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  success
                                      ? context.t(
                                          'Leave request {status}',
                                          params: {
                                            'status': context.t(
                                              selectedStatus == 'approved'
                                                  ? 'Approved'
                                                  : 'Rejected',
                                            ),
                                          },
                                        )
                                      : (provider.error ?? context.t('Failed')),
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
                      DateFormat('EEEE, MMM d, yyyy').format(leave.leaveDate),
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
          Row(
            children: [
              const Icon(Icons.schedule, size: 13, color: AppTheme.textMuted),
              const SizedBox(width: 4),
              Text(
                context.t(
                  'Submitted {date}',
                  params: {
                    'date': DateFormat('MMM d, yyyy').format(leave.createdAt),
                  },
                ),
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
              if (leave.reviewedByName != null) ...[
                const SizedBox(width: 12),
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
            ],
          ),

          // Teacher/Admin action
          if (isTeacherOrAdmin && leave.isPending) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showReviewDialog(context),
                icon: const Icon(Icons.rate_review_rounded, size: 16),
                label: Text(context.t('Review Request')),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
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

  const _SubmitLeaveDialog({required this.onSubmit});

  @override
  State<_SubmitLeaveDialog> createState() => _SubmitLeaveDialogState();
}

class _SubmitLeaveDialogState extends State<_SubmitLeaveDialog> {
  final _reasonController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

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
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.t('Submit Leave Request')),
      content: Form(
        key: _formKey,
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
              text: 'Submit',
              isLoading: provider.isLoading,
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  widget.onSubmit(
                    date: _selectedDate,
                    reason: _reasonController.text.trim(),
                  );
                }
              },
              icon: Icons.send_rounded,
            );
          },
        ),
      ],
    );
  }
}
