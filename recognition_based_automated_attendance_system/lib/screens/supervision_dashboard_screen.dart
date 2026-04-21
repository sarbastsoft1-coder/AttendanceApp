import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../localization/localization_extensions.dart';
import '../models/leave_request_model.dart';
import '../models/supervision_model.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../providers/leave_request_provider.dart';
import '../providers/supervision_provider.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/sidebar_navigation.dart';
import '../widgets/window_title_bar.dart';

class SupervisionDashboardScreen extends StatefulWidget {
  final int? initialGroupId;
  final bool openCreateGroupOnLoad;

  const SupervisionDashboardScreen({
    super.key,
    this.initialGroupId,
    this.openCreateGroupOnLoad = false,
  });

  @override
  State<SupervisionDashboardScreen> createState() =>
      _SupervisionDashboardScreenState();
}

class _SupervisionDashboardScreenState
    extends State<SupervisionDashboardScreen> {
  int? _selectedGroupId;
  int? _selectedClassId;

  @override
  void initState() {
    super.initState();
    _selectedGroupId = widget.initialGroupId;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      await _refresh();
      if (!mounted || !widget.openCreateGroupOnLoad) {
        return;
      }

      final overview = context.read<SupervisionProvider>().overview;
      final canCreateGroups =
          overview?.canCreateGroups ??
          (context.read<AuthProvider>().user?.canUseGroups == true);
      if (canCreateGroups) {
        await _showCreateGroupDialog();
      } else {
        _showCreateGroupPermissionMessage();
      }
    });
  }

  Future<void> _refresh() async {
    final supervision = context.read<SupervisionProvider>();
    final auth = context.read<AuthProvider>();
    final leaveRequests = context.read<LeaveRequestProvider>();
    await supervision.fetchOverview();
    if (!mounted) {
      return;
    }
    if (auth.user?.isSupervisor == true || auth.user?.isAdmin == true) {
      await leaveRequests.fetchLeaveRequests(statusFilter: 'pending');
    }
  }

  String _createGroupPermissionMessage() {
    return context.tRead(
      'Managed student accounts cannot create user groups. Ask an administrator to convert this account before using the group workspace.',
    );
  }

  void _showCreateGroupPermissionMessage() {
    _showError(_createGroupPermissionMessage());
  }

  String _inviteTeachersPermissionMessage() {
    return context.tRead('You can only invite users to groups you manage.');
  }

  bool _canAssignSuperTeacherInvite() {
    final user = context.read<AuthProvider>().user;
    return user?.isAdmin == true || user?.isSupervisor == true;
  }

  Future<void> _showCreateGroupDialog() async {
    final language = context.languageRead;
    final supervision = context.read<SupervisionProvider>();
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    var isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(language.tr('createTeacherGroup')),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      enabled: !isSubmitting,
                      decoration: InputDecoration(
                        labelText: language.tr('groupName'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      enabled: !isSubmitting,
                      minLines: 3,
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: language.tr('groupDescription'),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: Text(language.tr('cancel')),
                ),
                FilledButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final trimmedName = nameController.text.trim();
                          if (trimmedName.length < 2) {
                            _showError(
                              language.tr(
                                'Name must be at least 2 characters',
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isSubmitting = true);
                          final createdGroup = await supervision.createGroup(
                            name: trimmedName,
                            description: descriptionController.text,
                          );
                          if (!mounted || !dialogContext.mounted) {
                            return;
                          }
                          if (createdGroup != null) {
                            setState(
                              () => _selectedGroupId = createdGroup.id,
                            );
                            Navigator.pop(dialogContext);
                            _showMessage(language.tr('groupCreated'));
                          } else {
                            setDialogState(() => isSubmitting = false);
                            _showError(
                              supervision.error ??
                                  language.tr('operationFailed'),
                            );
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(language.tr('createGroup')),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    descriptionController.dispose();
  }

  Future<void> _showInviteTeachersDialog(TeacherGroup group) async {
    final language = context.languageRead;
    final supervision = context.read<SupervisionProvider>();
    if (!group.canManage) {
      _showError(_inviteTeachersPermissionMessage());
      return;
    }
    final emailsController = TextEditingController();
    final noteController = TextEditingController();
    final canAssignSuperTeacher = _canAssignSuperTeacherInvite();
    String selectedRole = 'teacher';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(language.tr('inviteTeachers')),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: emailsController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: language.tr('emailAddresses'),
                        hintText: language.tr('emailAddressesHint'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
                      items: [
                        DropdownMenuItem(
                          value: 'teacher',
                          child: Text(language.tr('teacher')),
                        ),
                        if (canAssignSuperTeacher)
                          DropdownMenuItem(
                            value: 'super_teacher',
                            child: Text(language.tr('superTeacher')),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setDialogState(() => selectedRole = value);
                      },
                      decoration: InputDecoration(
                        labelText: language.tr('teacherRole'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: language.tr('noteOptional'),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(language.tr('cancel')),
                ),
                FilledButton(
                  onPressed: () async {
                    final emails = emailsController.text
                        .split(RegExp(r'[\s,;]+'))
                        .map((email) => email.trim())
                        .where((email) => email.isNotEmpty)
                        .toList();
                    if (emails.isEmpty) {
                      _showError(language.tr('enterAtLeastOneEmail'));
                      return;
                    }

                    final success = await supervision.inviteTeachers(
                      groupId: group.id,
                      emails: emails,
                      targetRole: selectedRole,
                      note: noteController.text,
                    );
                    if (!mounted || !dialogContext.mounted) {
                      return;
                    }
                    if (success) {
                      Navigator.pop(dialogContext);
                      _showMessage(language.tr('teachersInvited'));
                    } else {
                      _showError(
                        supervision.error ?? language.tr('operationFailed'),
                      );
                    }
                  },
                  child: Text(language.tr('sendInvite')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _shareSelectedClass() async {
    final language = context.languageRead;
    final supervision = context.read<SupervisionProvider>();
    final overview = supervision.overview;
    final activeGroupId = overview != null
        ? _resolvedSelectedGroupId(overview)
        : null;
    final activeClassId = overview != null
        ? _resolvedSelectedClassId(overview)
        : null;
    if (activeClassId == null || activeGroupId == null) {
      _showError(language.tr('selectGroupAndClass'));
      return;
    }

    final success = await supervision.shareClassWithGroup(
      classId: activeClassId,
      groupId: activeGroupId,
    );
    if (!mounted) {
      return;
    }
    if (success) {
      setState(() {
        _selectedGroupId = activeGroupId;
        _selectedClassId = activeClassId;
      });
      _showMessage(language.tr('classShared'));
    } else {
      _showError(supervision.error ?? language.tr('operationFailed'));
    }
  }

  TeacherGroup? _resolvedSelectedGroup(SupervisionOverview overview) {
    if (overview.groups.isEmpty) {
      return null;
    }

    for (final group in overview.groups) {
      if (group.id == _selectedGroupId) {
        return group;
      }
    }

    return overview.groups.first;
  }

  int? _resolvedSelectedGroupId(SupervisionOverview overview) {
    return _resolvedSelectedGroup(overview)?.id;
  }

  int? _resolvedSelectedClassId(SupervisionOverview overview) {
    if (overview.shareableClasses.isEmpty) {
      return null;
    }

    for (final classObj in overview.shareableClasses) {
      if (classObj.id == _selectedClassId) {
        return classObj.id;
      }
    }

    return overview.shareableClasses.first.id;
  }

  TeacherGroup? _firstManageableGroup(SupervisionOverview overview) {
    for (final group in overview.groups) {
      if (group.canManage) {
        return group;
      }
    }
    return null;
  }

  Future<void> _showShareClassDialog(SupervisionOverview overview) async {
    final language = context.languageRead;
    final supervision = context.read<SupervisionProvider>();
    var selectedGroupId = _resolvedSelectedGroupId(overview);
    var selectedClassId = _resolvedSelectedClassId(overview);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(language.tr('shareClassWithGroup')),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: selectedGroupId,
                      items: overview.groups
                          .map(
                            (group) => DropdownMenuItem(
                              value: group.id,
                              child: Text(group.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() => selectedGroupId = value);
                      },
                      decoration: InputDecoration(
                        labelText: language.tr('selectGroup'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: selectedClassId,
                      items: overview.shareableClasses
                          .map(
                            (classObj) => DropdownMenuItem(
                              value: classObj.id,
                              child: Text(
                                classObj.scheduleSummary.isEmpty
                                    ? classObj.name
                                    : '${classObj.name}  ${classObj.scheduleSummary}',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() => selectedClassId = value);
                      },
                      decoration: InputDecoration(
                        labelText: language.tr('selectClass'),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(language.tr('cancel')),
                ),
                FilledButton.icon(
                  onPressed: () async {
                    if (selectedGroupId == null || selectedClassId == null) {
                      _showError(language.tr('selectGroupAndClass'));
                      return;
                    }

                    final success = await supervision.shareClassWithGroup(
                      classId: selectedClassId!,
                      groupId: selectedGroupId!,
                    );
                    if (!mounted || !dialogContext.mounted) {
                      return;
                    }

                    if (success) {
                      setState(() {
                        _selectedGroupId = selectedGroupId;
                        _selectedClassId = selectedClassId;
                      });
                      Navigator.pop(dialogContext);
                      _showMessage(language.tr('classShared'));
                    } else {
                      _showError(
                        supervision.error ?? language.tr('operationFailed'),
                      );
                    }
                  },
                  icon: const Icon(Icons.share_rounded),
                  label: Text(language.tr('shareClass')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openInviteTeachersForActiveGroup(
    SupervisionOverview overview,
  ) async {
    final group =
        _resolvedSelectedGroup(overview) ?? _firstManageableGroup(overview);
    if (group == null) {
      _showError(context.trRead('noTeacherGroups'));
      return;
    }
    if (!group.canManage) {
      _showError(_inviteTeachersPermissionMessage());
      return;
    }
    await _showInviteTeachersDialog(group);
  }

  Future<void> _handleInviteTeachersAction(SupervisionOverview overview) async {
    if (overview.groups.isEmpty) {
      if (overview.canCreateGroups) {
        await _showCreateGroupDialog();
      } else {
        _showCreateGroupPermissionMessage();
      }
      return;
    }

    if (!overview.groups.any((group) => group.canManage)) {
      _showError(_inviteTeachersPermissionMessage());
      return;
    }

    await _openInviteTeachersForActiveGroup(overview);
  }

  Future<void> _handleShareClassAction(SupervisionOverview overview) async {
    if (overview.groups.isEmpty) {
      if (overview.canCreateGroups) {
        await _showCreateGroupDialog();
      } else {
        _showCreateGroupPermissionMessage();
      }
      return;
    }

    if (overview.shareableClasses.isEmpty) {
      await _openRouteAndRefresh('/batch-registration');
      return;
    }

    if (!overview.canShareClasses) {
      _showError(context.trRead('operationFailed'));
      return;
    }

    await _showShareClassDialog(overview);
  }

  Widget _buildShareClassEmptyState(SupervisionOverview overview) {
    final language = context.language;
    final showCreateGroupHelp =
        overview.groups.isEmpty && !overview.canCreateGroups;
    final actions = <Widget>[
      if (overview.groups.isEmpty && overview.canCreateGroups)
        FilledButton.icon(
          onPressed: _showCreateGroupDialog,
          icon: const Icon(Icons.groups_2_rounded),
          label: Text(language.tr('createGroup')),
        ),
      if (overview.shareableClasses.isEmpty && overview.canShareClasses)
        OutlinedButton.icon(
          onPressed: () => _openRouteAndRefresh('/batch-registration'),
          icon: const Icon(Icons.group_add_rounded),
          label: Text(context.t('Open Batch Register')),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _EmptyState(
          text: context.t(
            'Create a group and at least one class to start linking classes.',
          ),
        ),
        if (showCreateGroupHelp) ...[
          const SizedBox(height: 12),
          _InfoNotice(text: _createGroupPermissionMessage()),
        ],
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 10, children: actions),
        ],
      ],
    );
  }

  Future<void> _openRouteAndRefresh(String routeName) async {
    await Navigator.pushNamed(context, routeName);
    if (mounted) {
      _refresh();
    }
  }

  void _replaceRoute(String routeName) {
    if (ModalRoute.of(context)?.settings.name == routeName) {
      return;
    }
    Navigator.pushReplacementNamed(context, routeName);
  }

  void _onNavItemSelected(int index) {
    switch (index) {
      case 0:
        _replaceRoute('/home');
        return;
      case 1:
        _replaceRoute('/history');
        return;
      case 2:
        _replaceRoute('/room-scanner');
        return;
      case 3:
        _replaceRoute('/batch-registration');
        return;
      case 4:
        _replaceRoute('/profile');
        return;
      case 5:
        _replaceRoute('/admin');
        return;
      case 6:
        _replaceRoute('/admin/attendance');
        return;
      case 7:
        _replaceRoute('/admin/classes');
        return;
      case 8:
        _replaceRoute('/notifications');
        return;
      case 9:
        _replaceRoute('/leave-requests');
        return;
      case 11:
        _replaceRoute('/roll-call');
        return;
      case 12:
        _replaceRoute('/exam-proctoring');
        return;
      case 13:
        _replaceRoute('/export-center');
        return;
      case 14:
        return;
    }
  }

  Future<void> _logout() async {
    final language = context.read<LanguageProvider>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(language.tr('signOutTitle')),
        content: Text(language.tr('signOutConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(language.tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: Text(language.tr('signOutTitle')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) {
        return;
      }
      await context.read<AuthProvider>().logout();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  String _formatHeaderDate(LanguageProvider language) {
    final now = DateTime.now();
    if (language.isArabic) {
      return DateFormat('EEEE، d MMMM y', 'ar').format(now);
    }
    return DateFormat('EEE, MMM d, y').format(now);
  }

  Future<void> _respondToInvitation(
    TeacherGroupInvite invite,
    String status,
  ) async {
    final language = context.languageRead;
    final supervision = context.read<SupervisionProvider>();
    final success = await supervision.respondToInvitation(
      inviteId: invite.id,
      status: status,
    );
    if (!mounted) {
      return;
    }
    if (success) {
      _showMessage(
        status == 'accepted'
            ? language.tr('invitationAccepted')
            : language.tr('invitationRejected'),
      );
    } else {
      _showError(supervision.error ?? language.tr('operationFailed'));
    }
  }

  Future<void> _toggleMemberRole(
    TeacherGroup group,
    TeacherGroupMember member,
  ) async {
    final language = context.languageRead;
    final nextRole = member.isSuperTeacher ? 'teacher' : 'super_teacher';
    final supervision = context.read<SupervisionProvider>();
    final success = await supervision.updateMemberRole(
      groupId: group.id,
      teacherId: member.teacherId,
      role: nextRole,
    );
    if (!mounted) {
      return;
    }
    if (success) {
      _showMessage(language.tr('roleUpdated'));
    } else {
      _showError(supervision.error ?? language.tr('operationFailed'));
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.errorColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (ResponsiveLayout.isDesktop(context)) {
      return _buildDesktopLayout();
    }
    return _buildMobileLayout();
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      body: Column(
        children: [
          if (ResponsiveLayout.isNativeDesktop()) const WindowTitleBar(),
          Expanded(
            child: Row(
              children: [
                SidebarNavigation(
                  currentIndex: 14,
                  onItemSelected: _onNavItemSelected,
                  onLogout: _logout,
                ),
                Expanded(child: _buildDashboardBody(showHeaderActions: true)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    final language = context.language;
    return Scaffold(
      backgroundColor: AppTheme.bgBase,
      appBar: AppBar(
        title: Text(language.tr('supervisorHub')),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            onPressed: () => _openRouteAndRefresh('/batch-registration'),
            icon: const Icon(Icons.group_add_rounded),
          ),
        ],
      ),
      body: _buildDashboardBody(showHeaderActions: false),
    );
  }

  Widget _buildDashboardBody({required bool showHeaderActions}) {
    return Consumer3<SupervisionProvider, LeaveRequestProvider, AuthProvider>(
      builder: (context, supervision, leaveRequests, auth, _) {
        final language = context.language;
        if (supervision.isLoading && supervision.overview == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final overview = supervision.overview;
        if (overview == null) {
          return Center(
            child: Text(
              supervision.error ?? language.tr('noSupervisionData'),
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          );
        }

        final activeGroup = _resolvedSelectedGroup(overview);
        final activeGroupCanManage = activeGroup?.canManage == true;
        final activeGroupId = _resolvedSelectedGroupId(overview);
        final activeClassId = _resolvedSelectedClassId(overview);
        final pendingGroupInvites =
            activeGroup?.invitations
                .where((invite) => invite.isPending)
                .toList() ??
            const <TeacherGroupInvite>[];
        final canGuideInviteAction =
            overview.groups.any((group) => group.canManage) ||
            (overview.groups.isEmpty && overview.canCreateGroups);
        final canGuideShareAction =
            overview.canShareClasses ||
            (overview.groups.isEmpty && overview.canCreateGroups);
        final createGroupHelpText =
            overview.groups.isEmpty && !overview.canCreateGroups
            ? _createGroupPermissionMessage()
            : null;
        final totalMembers = overview.groups.fold<int>(
          0,
          (sum, group) => sum + group.members.length,
        );
        final totalSharedClasses = overview.groups.fold<int>(
          0,
          (sum, group) => sum + group.sharedClasses.length,
        );
        final showLeavePanel =
            auth.user?.isSuperTeacher == true || auth.user?.isAdmin == true;
        final useWideLayout = ResponsiveLayout.width(context) >= 1320;

        final rightRailPanels = <Widget>[
          if (overview.canShareClasses)
            _SectionCard(
              title: language.tr('shareClassWithGroup'),
              child:
                  overview.groups.isEmpty || overview.shareableClasses.isEmpty
                  ? _buildShareClassEmptyState(overview)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.t(
                            'Pick a group and class to link them without leaving the dashboard.',
                          ),
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int>(
                          key: ValueKey(
                            'share-group-${activeGroupId ?? 'none'}-${overview.groups.length}',
                          ),
                          initialValue: activeGroupId,
                          items: overview.groups
                              .map(
                                (group) => DropdownMenuItem(
                                  value: group.id,
                                  child: Text(group.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() => _selectedGroupId = value);
                          },
                          decoration: InputDecoration(
                            labelText: language.tr('selectGroup'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          key: ValueKey(
                            'share-class-${activeClassId ?? 'none'}-${overview.shareableClasses.length}',
                          ),
                          initialValue: activeClassId,
                          items: overview.shareableClasses
                              .map(
                                (classObj) => DropdownMenuItem(
                                  value: classObj.id,
                                  child: Text(
                                    classObj.scheduleSummary.isEmpty
                                        ? classObj.name
                                        : '${classObj.name}  ${classObj.scheduleSummary}',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() => _selectedClassId = value);
                          },
                          decoration: InputDecoration(
                            labelText: language.tr('selectClass'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: FilledButton.icon(
                            onPressed: supervision.isSubmitting
                                ? null
                                : _shareSelectedClass,
                            icon: const Icon(Icons.share_rounded),
                            label: Text(language.tr('shareClass')),
                          ),
                        ),
                      ],
                    ),
            ),
          if (activeGroup != null)
            _SectionCard(
              title: context.t('Pending Email Invites'),
              action: activeGroupCanManage
                  ? OutlinedButton.icon(
                      onPressed: () =>
                          _openInviteTeachersForActiveGroup(overview),
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: Text(context.t('Add Users By Email')),
                    )
                  : null,
              child: pendingGroupInvites.isEmpty
                  ? _EmptyState(text: context.t('No pending email invites'))
                  : Column(
                      children: pendingGroupInvites
                          .take(5)
                          .map(
                            (invite) => _GroupInviteStatusTile(invite: invite),
                          )
                          .toList(),
                    ),
            ),
          if (overview.pendingInvitations.isNotEmpty)
            _SectionCard(
              title: language.tr('yourInvitations'),
              child: Column(
                children: overview.pendingInvitations
                    .map(
                      (invite) => _InvitationTile(
                        invite: invite,
                        onAccept: () =>
                            _respondToInvitation(invite, 'accepted'),
                        onReject: () =>
                            _respondToInvitation(invite, 'rejected'),
                      ),
                    )
                    .toList(),
              ),
            ),
          if (showLeavePanel)
            _SectionCard(
              title: language.tr('pendingLeaves'),
              action: TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, '/leave-requests'),
                child: Text(language.tr('openLeaveRequests')),
              ),
              child: leaveRequests.pendingRequests.isEmpty
                  ? _EmptyState(text: language.tr('noPendingLeaves'))
                  : Column(
                      children: leaveRequests.pendingRequests
                          .take(5)
                          .map((leave) => _LeaveTile(leave: leave))
                          .toList(),
                    ),
            ),
        ];

        if (rightRailPanels.isEmpty) {
          rightRailPanels.add(
            _SectionCard(
              title: context.t('Action Center'),
              child: _EmptyState(
                text: context.t('No pending requests right now'),
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: Stack(
            children: [
              const Positioned.fill(
                child: IgnorePointer(child: _SupervisorBackdrop()),
              ),
              ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: ResponsiveLayout.pagePadding(context),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: ResponsiveLayout.contentMaxWidth(context),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SupervisorHeroHeader(
                            title:
                                '${context.t('Welcome back')}, ${auth.user?.fullName ?? language.tr('user')}',
                            subtitle: context.t(
                              'Manage batch registration, user groups, linked classes, and email invites from one workspace.',
                            ),
                            dateLabel: _formatHeaderDate(language),
                            showActions: showHeaderActions,
                            onRefresh: _refresh,
                            onBatchRegisterTap: () =>
                                _openRouteAndRefresh('/batch-registration'),
                          ),
                          const SizedBox(height: 28),
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              _MetricCard(
                                title: context.t('Groups Managed'),
                                value: overview.groups.length.toString(),
                                icon: Icons.groups_2_rounded,
                                color: AppTheme.primaryColor,
                              ),
                              _MetricCard(
                                title: context.t('Team Members'),
                                value: totalMembers.toString(),
                                icon: Icons.people_alt_rounded,
                                color: AppTheme.secondaryColor,
                              ),
                              _MetricCard(
                                title: language.tr('sharedClasses'),
                                value: totalSharedClasses.toString(),
                                icon: Icons.class_rounded,
                                color: AppTheme.accentColor,
                              ),
                              _MetricCard(
                                title: language.tr('pendingInvitations'),
                                value:
                                    (overview.pendingInvitations.length +
                                            pendingGroupInvites.length)
                                        .toString(),
                                icon: Icons.mark_email_unread_rounded,
                                color: AppTheme.warningColor,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _SupervisorQuickActionsPanel(
                            onBatchRegisterTap: () =>
                                _openRouteAndRefresh('/batch-registration'),
                            onCreateGroupTap: overview.canCreateGroups
                                ? _showCreateGroupDialog
                                : null,
                            onCreateGroupUnavailableTap:
                                createGroupHelpText == null
                                ? null
                                : _showCreateGroupPermissionMessage,
                            createGroupDisabledMessage: createGroupHelpText,
                            onInviteTeachersTap: canGuideInviteAction
                                ? () => _handleInviteTeachersAction(overview)
                                : null,
                            onShareClassTap: canGuideShareAction
                                ? () => _handleShareClassAction(overview)
                                : null,
                            onManageClassesTap: () =>
                                _openRouteAndRefresh('/admin/classes'),
                          ),
                          const SizedBox(height: 24),
                          if (useWideLayout)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 6,
                                  child: _SectionCard(
                                    title: context.t('Group Workspace'),
                                    action: overview.canCreateGroups
                                        ? FilledButton.icon(
                                            onPressed: supervision.isSubmitting
                                                ? null
                                                : _showCreateGroupDialog,
                                            icon: const Icon(Icons.add_rounded),
                                            label: Text(
                                              language.tr('createGroup'),
                                            ),
                                          )
                                        : null,
                                    child: _GroupWorkspaceSection(
                                      overview: overview,
                                      activeGroup: activeGroup,
                                      canCreateGroups: overview.canCreateGroups,
                                      canInviteTeachers: activeGroupCanManage,
                                      canManageRoles: overview.canManageGroups,
                                      createGroupHelpText: createGroupHelpText,
                                      onCreateGroupTap: overview.canCreateGroups
                                          ? _showCreateGroupDialog
                                          : null,
                                      onSelectGroup: (groupId) {
                                        setState(
                                          () => _selectedGroupId = groupId,
                                        );
                                      },
                                      onBatchRegisterTap: () =>
                                          _openRouteAndRefresh(
                                            '/batch-registration',
                                          ),
                                      onInviteTeachersTap: activeGroup == null
                                          ? null
                                          : () =>
                                                _openInviteTeachersForActiveGroup(
                                                  overview,
                                                ),
                                      onShareClassTap:
                                          overview.canShareClasses &&
                                              overview
                                                  .shareableClasses
                                                  .isNotEmpty
                                          ? () =>
                                                _showShareClassDialog(overview)
                                          : null,
                                      onToggleMemberRole: activeGroup == null
                                          ? null
                                          : (member) => _toggleMemberRole(
                                              activeGroup,
                                              member,
                                            ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  flex: 4,
                                  child: Column(
                                    children: [
                                      for (
                                        var i = 0;
                                        i < rightRailPanels.length;
                                        i++
                                      ) ...[
                                        rightRailPanels[i],
                                        if (i != rightRailPanels.length - 1)
                                          const SizedBox(height: 20),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            )
                          else ...[
                            _SectionCard(
                              title: context.t('Group Workspace'),
                              action: overview.canCreateGroups
                                  ? FilledButton.icon(
                                      onPressed: supervision.isSubmitting
                                          ? null
                                          : _showCreateGroupDialog,
                                      icon: const Icon(Icons.add_rounded),
                                      label: Text(language.tr('createGroup')),
                                    )
                                  : null,
                              child: _GroupWorkspaceSection(
                                overview: overview,
                                activeGroup: activeGroup,
                                canCreateGroups: overview.canCreateGroups,
                                canInviteTeachers: activeGroupCanManage,
                                canManageRoles: overview.canManageGroups,
                                createGroupHelpText: createGroupHelpText,
                                onCreateGroupTap: overview.canCreateGroups
                                    ? _showCreateGroupDialog
                                    : null,
                                onSelectGroup: (groupId) {
                                  setState(() => _selectedGroupId = groupId);
                                },
                                onBatchRegisterTap: () =>
                                    _openRouteAndRefresh('/batch-registration'),
                                onInviteTeachersTap: activeGroup == null
                                    ? null
                                    : () => _openInviteTeachersForActiveGroup(
                                        overview,
                                      ),
                                onShareClassTap:
                                    overview.canShareClasses &&
                                        overview.shareableClasses.isNotEmpty
                                    ? () => _showShareClassDialog(overview)
                                    : null,
                                onToggleMemberRole: activeGroup == null
                                    ? null
                                    : (member) => _toggleMemberRole(
                                        activeGroup,
                                        member,
                                      ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            for (
                              var i = 0;
                              i < rightRailPanels.length;
                              i++
                            ) ...[
                              rightRailPanels[i],
                              if (i != rightRailPanels.length - 1)
                                const SizedBox(height: 20),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SupervisorBackdrop extends StatelessWidget {
  const _SupervisorBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: AppTheme.bgBase),
        Positioned(
          top: -140,
          right: -90,
          child: _GlowOrb(
            size: 340,
            color: AppTheme.primaryColor.withValues(alpha: 0.18),
          ),
        ),
        Positioned(
          left: -110,
          top: MediaQuery.sizeOf(context).height * 0.28,
          child: _GlowOrb(
            size: 280,
            color: AppTheme.secondaryColor.withValues(alpha: 0.14),
          ),
        ),
        Positioned(
          right: 120,
          bottom: -110,
          child: _GlowOrb(
            size: 260,
            color: AppTheme.accentColor.withValues(alpha: 0.12),
          ),
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0.08), Colors.transparent],
          ),
        ),
      ),
    );
  }
}

class _SupervisorHeroHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String dateLabel;
  final bool showActions;
  final VoidCallback onRefresh;
  final VoidCallback onBatchRegisterTap;

  const _SupervisorHeroHeader({
    required this.title,
    required this.subtitle,
    required this.dateLabel,
    required this.showActions,
    required this.onRefresh,
    required this.onBatchRegisterTap,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      runSpacing: 16,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: ResponsiveLayout.isCompact(context) ? 24 : 32,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 15,
                height: 1.45,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppTheme.glassBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 16,
                    color: AppTheme.primaryLight,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dateLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (showActions)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _HeroActionButton(
                icon: Icons.refresh_rounded,
                tooltip: 'Refresh',
                onTap: onRefresh,
              ),
              const SizedBox(width: 10),
              _HeroActionButton(
                icon: Icons.group_add_rounded,
                tooltip: 'Batch Register',
                onTap: onBatchRegisterTap,
              ),
            ],
          ),
      ],
    );
  }
}

class _HeroActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HeroActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.glassBorder),
          ),
          child: Icon(icon, color: AppTheme.textPrimary),
        ),
      ),
    );
  }
}

class _SupervisorQuickActionsPanel extends StatelessWidget {
  final VoidCallback onBatchRegisterTap;
  final VoidCallback? onCreateGroupTap;
  final VoidCallback? onCreateGroupUnavailableTap;
  final String? createGroupDisabledMessage;
  final VoidCallback? onInviteTeachersTap;
  final VoidCallback? onShareClassTap;
  final VoidCallback? onManageClassesTap;

  const _SupervisorQuickActionsPanel({
    required this.onBatchRegisterTap,
    required this.onCreateGroupTap,
    required this.onCreateGroupUnavailableTap,
    required this.createGroupDisabledMessage,
    required this.onInviteTeachersTap,
    required this.onShareClassTap,
    required this.onManageClassesTap,
  });

  @override
  Widget build(BuildContext context) {
    final language = context.language;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            language.tr('quickActions'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.t(
              'Launch batch registration, create groups, link classes, and invite users without leaving this dashboard.',
            ),
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _SupervisorActionTile(
                icon: Icons.group_add_rounded,
                label: language.tr('batchRegister'),
                color: AppTheme.secondaryColor,
                onTap: onBatchRegisterTap,
              ),
              _SupervisorActionTile(
                icon: Icons.groups_2_rounded,
                label: language.tr('createGroup'),
                color: AppTheme.primaryColor,
                onTap: onCreateGroupTap,
                onDisabledTap: onCreateGroupUnavailableTap,
                disabledMessage: createGroupDisabledMessage,
              ),
              _SupervisorActionTile(
                icon: Icons.alternate_email_rounded,
                label: context.t('Add Users By Email'),
                color: AppTheme.infoColor,
                onTap: onInviteTeachersTap,
              ),
              _SupervisorActionTile(
                icon: Icons.share_rounded,
                label: context.t('Add Class To Group'),
                color: AppTheme.accentColor,
                onTap: onShareClassTap,
              ),
              _SupervisorActionTile(
                icon: Icons.class_rounded,
                label: context.t('Manage Classes'),
                color: Colors.tealAccent,
                onTap: onManageClassesTap,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SupervisorActionTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final VoidCallback? onDisabledTap;
  final String? disabledMessage;

  const _SupervisorActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.onDisabledTap,
    this.disabledMessage,
  });

  @override
  State<_SupervisorActionTile> createState() => _SupervisorActionTileState();
}

class _SupervisorActionTileState extends State<_SupervisorActionTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null;
    final tapHandler = widget.onTap ?? widget.onDisabledTap;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final width = screenWidth < 480 ? screenWidth - 56 : 170.0;
    final child = MouseRegion(
      onEnter: disabled ? null : (_) => setState(() => _isHovered = true),
      onExit: disabled ? null : (_) => setState(() => _isHovered = false),
      cursor: tapHandler == null
          ? SystemMouseCursors.basic
          : disabled
          ? SystemMouseCursors.help
          : SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: tapHandler,
          child: AnimatedContainer(
            duration: AppTheme.animFast,
            width: width,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: disabled
                  ? AppTheme.bgElevated.withValues(alpha: 0.42)
                  : _isHovered
                  ? widget.color.withValues(alpha: 0.12)
                  : AppTheme.bgElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: disabled
                    ? AppTheme.glassBorder.withValues(alpha: 0.35)
                    : _isHovered
                    ? widget.color.withValues(alpha: 0.32)
                    : AppTheme.glassBorder,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.icon,
                  size: 28,
                  color: disabled ? AppTheme.textMuted : widget.color,
                ),
                const SizedBox(height: 12),
                Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: disabled ? AppTheme.textMuted : AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final tooltipMessage = widget.disabledMessage;
    if (tooltipMessage == null || tooltipMessage.trim().isEmpty) {
      return child;
    }

    return Tooltip(message: tooltipMessage, child: child);
  }
}

class _GroupWorkspaceSection extends StatelessWidget {
  final SupervisionOverview overview;
  final TeacherGroup? activeGroup;
  final bool canCreateGroups;
  final bool canInviteTeachers;
  final bool canManageRoles;
  final String? createGroupHelpText;
  final VoidCallback? onCreateGroupTap;
  final ValueChanged<int> onSelectGroup;
  final VoidCallback onBatchRegisterTap;
  final VoidCallback? onInviteTeachersTap;
  final VoidCallback? onShareClassTap;
  final ValueChanged<TeacherGroupMember>? onToggleMemberRole;

  const _GroupWorkspaceSection({
    required this.overview,
    required this.activeGroup,
    required this.canCreateGroups,
    required this.canInviteTeachers,
    required this.canManageRoles,
    required this.createGroupHelpText,
    required this.onCreateGroupTap,
    required this.onSelectGroup,
    required this.onBatchRegisterTap,
    required this.onInviteTeachersTap,
    required this.onShareClassTap,
    required this.onToggleMemberRole,
  });

  @override
  Widget build(BuildContext context) {
    final group = activeGroup;
    if (group == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t(
              'Create a group first, then invite users by email and attach classes to it.',
            ),
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          if (createGroupHelpText != null) ...[
            const SizedBox(height: 16),
            _InfoNotice(text: createGroupHelpText!),
          ],
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (canCreateGroups)
                FilledButton.icon(
                  onPressed: onCreateGroupTap,
                  icon: const Icon(Icons.groups_2_rounded),
                  label: Text(context.t('Create your first group')),
                ),
              OutlinedButton.icon(
                onPressed: onBatchRegisterTap,
                icon: const Icon(Icons.group_add_rounded),
                label: Text(context.language.tr('batchRegister')),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _EmptyState(text: context.language.tr('noTeacherGroups')),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t(
            'Use one workspace to manage members, email invites, and linked classes for the selected group.',
          ),
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 18),
        _SupervisorGroupSelector(
          groups: overview.groups,
          selectedGroupId: group.id,
          onSelectGroup: onSelectGroup,
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (canInviteTeachers)
              OutlinedButton.icon(
                onPressed: onInviteTeachersTap,
                icon: const Icon(Icons.alternate_email_rounded),
                label: Text(context.t('Add Users By Email')),
              ),
            if (overview.canShareClasses)
              FilledButton.icon(
                onPressed: onShareClassTap,
                icon: const Icon(Icons.share_rounded),
                label: Text(context.t('Add Class To Group')),
              ),
            OutlinedButton.icon(
              onPressed: onBatchRegisterTap,
              icon: const Icon(Icons.group_add_rounded),
              label: Text(context.language.tr('batchRegister')),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _GroupCard(
          group: group,
          canInviteTeachers: canInviteTeachers,
          canManageRoles: canManageRoles,
          onInviteTeachers: onInviteTeachersTap ?? () {},
          onToggleMemberRole: onToggleMemberRole ?? (_) {},
        ),
      ],
    );
  }
}

class _SupervisorGroupSelector extends StatelessWidget {
  final List<TeacherGroup> groups;
  final int selectedGroupId;
  final ValueChanged<int> onSelectGroup;

  const _SupervisorGroupSelector({
    required this.groups,
    required this.selectedGroupId,
    required this.onSelectGroup,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: groups
          .map(
            (group) => _GroupSelectorChip(
              label: group.name,
              selected: group.id == selectedGroupId,
              onTap: () => onSelectGroup(group.id),
            ),
          )
          .toList(),
    );
  }
}

class _GroupSelectorChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _GroupSelectorChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppTheme.animFast,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryColor.withValues(alpha: 0.16)
              : AppTheme.bgElevated,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : AppTheme.glassBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: selected ? AppTheme.textPrimary : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _GroupInviteStatusTile extends StatelessWidget {
  final TeacherGroupInvite invite;

  const _GroupInviteStatusTile({required this.invite});

  @override
  Widget build(BuildContext context) {
    final language = context.language;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgDeep,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            invite.email,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${language.tr('teacherRole')}: ${invite.targetRole == 'super_teacher' ? language.tr('superTeacher') : language.tr('teacher')}',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            '${context.t('Status')}: ${invite.status}',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          if ((invite.note ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              invite.note!,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(title, style: const TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? action;

  const _SectionCard({required this.title, required this.child, this.action});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              ...switch (action) {
                null => const <Widget>[],
                final value => <Widget>[value],
              },
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final TeacherGroup group;
  final bool canInviteTeachers;
  final bool canManageRoles;
  final VoidCallback onInviteTeachers;
  final ValueChanged<TeacherGroupMember> onToggleMemberRole;

  const _GroupCard({
    required this.group,
    required this.canInviteTeachers,
    required this.canManageRoles,
    required this.onInviteTeachers,
    required this.onToggleMemberRole,
  });

  @override
  Widget build(BuildContext context) {
    final language = context.language;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgDeep,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if ((group.description ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        group.description!,
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              if (canInviteTeachers)
                OutlinedButton.icon(
                  onPressed: onInviteTeachers,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: Text(language.tr('inviteTeachers')),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Pill(
                label: '${language.tr('members')}: ${group.members.length}',
              ),
              _Pill(
                label:
                    '${language.tr('pendingInvitations')}: ${group.pendingInviteCount}',
              ),
              _Pill(
                label:
                    '${language.tr('sharedClasses')}: ${group.sharedClasses.length}',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            language.tr('members'),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          if (group.members.isEmpty)
            _EmptyState(text: language.tr('noMembersYet'))
          else
            ...group.members.map(
              (member) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.teacherName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${member.teacherEmail}  •  ${member.isSuperTeacher ? context.language.tr('superTeacher') : context.language.tr('teacher')}',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (canManageRoles)
                      TextButton(
                        onPressed: () => onToggleMemberRole(member),
                        child: Text(
                          member.isSuperTeacher
                              ? language.tr('setAsTeacher')
                              : language.tr('makeSuperTeacher'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            language.tr('sharedClasses'),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          if (group.sharedClasses.isEmpty)
            _EmptyState(text: language.tr('noSharedClasses'))
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: group.sharedClasses
                  .map((shared) => _Pill(label: shared.className))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _InvitationTile extends StatelessWidget {
  final TeacherGroupInvite invite;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _InvitationTile({
    required this.invite,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final language = context.language;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgDeep,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            invite.email,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${language.tr('teacherRole')}: ${invite.targetRole == 'super_teacher' ? language.tr('superTeacher') : language.tr('teacher')}',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          if ((invite.invitedByName ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              language.tr(
                'invitedBy',
                params: {'name': invite.invitedByName!.trim()},
              ),
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ],
          if ((invite.note ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              invite.note!,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton(
                onPressed: onAccept,
                child: Text(language.tr('accept')),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: onReject,
                child: Text(language.tr('reject')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LeaveTile extends StatelessWidget {
  final LeaveRequest leave;

  const _LeaveTile({required this.leave});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgDeep,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            leave.displayName,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat.yMMMd().add_jm().format(leave.leaveDate),
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            leave.reason,
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;

  const _Pill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String text;

  const _EmptyState({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(text, style: const TextStyle(color: AppTheme.textSecondary)),
    );
  }
}

class _InfoNotice extends StatelessWidget {
  final String text;

  const _InfoNotice({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.warningColor.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: AppTheme.warningColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
