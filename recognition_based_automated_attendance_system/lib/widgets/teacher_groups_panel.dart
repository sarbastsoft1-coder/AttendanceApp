import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../config/app_theme.dart';
import '../localization/localization_extensions.dart';
import '../models/supervision_model.dart';
import '../providers/auth_provider.dart';
import '../providers/supervision_provider.dart';
import '../widgets/responsive_layout.dart';

class TeacherGroupsPanel extends StatelessWidget {
  final VoidCallback onCreateGroupTap;
  final VoidCallback onInviteTeachersTap;
  final VoidCallback onShareClassTap;
  final VoidCallback onImportClassesTap;
  final VoidCallback onExportCenterTap;
  final VoidCallback onSupervisionTap;

  const TeacherGroupsPanel({
    super.key,
    required this.onCreateGroupTap,
    required this.onInviteTeachersTap,
    required this.onShareClassTap,
    required this.onImportClassesTap,
    required this.onExportCenterTap,
    required this.onSupervisionTap,
  });

  @override
  Widget build(BuildContext context) {
    final language = context.language;
    final isMobile = ResponsiveLayout.isMobile(context);

    return Consumer<SupervisionProvider>(
      builder: (context, supervision, _) {
        final overview = supervision.overview;
        final groups = overview?.groups ?? const <TeacherGroup>[];
        final canInviteTeachers =
            overview?.groups.any((group) => group.canManage) ??
            (context.read<AuthProvider>().user?.isAdmin == true ||
                context.read<AuthProvider>().user?.isSupervisor == true);
        final canCreateGroups =
            overview?.canCreateGroups ??
            (context.read<AuthProvider>().user?.canUseGroups == true);
        final canShareClasses =
            overview?.canShareClasses ??
            (context.read<AuthProvider>().user?.isAdmin == true ||
                context.read<AuthProvider>().user?.isTeacher == true);
        final totalMembers = groups.fold<int>(
          0,
          (sum, group) => sum + group.members.length,
        );
        final totalSharedClasses = groups.fold<int>(
          0,
          (sum, group) => sum + group.sharedClasses.length,
        );
        final totalPendingInvites = groups.fold<int>(
          0,
          (sum, group) => sum + group.pendingInviteCount,
        );

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(isMobile ? 20 : 24),
          decoration: AppTheme.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        language.tr('teacherGroups'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          GroupStatChip(
                            icon: Icons.groups_2_rounded,
                            label:
                                '${groups.length} ${language.tr('teacherGroups')}',
                          ),
                          GroupStatChip(
                            icon: Icons.person_add_alt_1_rounded,
                            label: '$totalMembers ${language.tr('members')}',
                          ),
                          GroupStatChip(
                            icon: Icons.pending_actions_rounded,
                            label:
                                '$totalPendingInvites ${language.tr('pendingInvitations')}',
                          ),
                          GroupStatChip(
                            icon: Icons.class_rounded,
                            label:
                                '$totalSharedClasses ${language.tr('classes')}',
                          ),
                        ],
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      if (canCreateGroups)
                        FilledButton.icon(
                          onPressed: onCreateGroupTap,
                          icon: const Icon(Icons.add_circle_outline_rounded),
                          label: Text(language.tr('createGroup')),
                        ),
                      if (canInviteTeachers)
                        OutlinedButton.icon(
                          onPressed: onInviteTeachersTap,
                          icon: const Icon(Icons.alternate_email_rounded),
                          label: Text(language.tr('inviteTeachers')),
                        ),
                      if (canShareClasses)
                        OutlinedButton.icon(
                          onPressed: onShareClassTap,
                          icon: const Icon(Icons.library_add_check_rounded),
                          label: Text(language.tr('shareClass')),
                        ),
                      OutlinedButton.icon(
                        onPressed: onImportClassesTap,
                        icon: const Icon(Icons.upload_file_rounded),
                        label: Text(context.t('Import Classes')),
                      ),
                      OutlinedButton.icon(
                        onPressed: onExportCenterTap,
                        icon: const Icon(Icons.download_for_offline_rounded),
                        label: Text(language.tr('exportCenter')),
                      ),
                      TextButton.icon(
                        onPressed: onSupervisionTap,
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: Text(language.tr('supervisorHub')),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (supervision.isLoading && overview == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (groups.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.bgElevated,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.glassBorder),
                  ),
                  child: Text(
                    language.tr('noTeacherGroups'),
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                )
              else
                Column(
                  children: groups
                      .map(
                        (group) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TeacherGroupSummaryCard(group: group),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.02, end: 0);
      },
    );
  }
}

class GroupStatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const GroupStatChip({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgElevated,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class TeacherGroupSummaryCard extends StatelessWidget {
  final TeacherGroup group;

  const TeacherGroupSummaryCard({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    final language = context.language;
    final memberEmails = group.members
        .take(3)
        .map((member) => member.teacherEmail)
        .where((email) => email.trim().isNotEmpty)
        .join('  •  ');
    final sharedClasses = group.sharedClasses
        .take(3)
        .map((classObj) => classObj.className)
        .where((name) => name.trim().isNotEmpty)
        .join('  •  ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.bgElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  group.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  GroupStatChip(
                    icon: Icons.people_alt_rounded,
                    label: '${group.members.length} ${language.tr('members')}',
                  ),
                  GroupStatChip(
                    icon: Icons.pending_actions_rounded,
                    label:
                        '${group.pendingInviteCount} ${language.tr('pendingInvitations')}',
                  ),
                  GroupStatChip(
                    icon: Icons.class_rounded,
                    label:
                        '${group.sharedClasses.length} ${language.tr('classes')}',
                  ),
                ],
              ),
            ],
          ),
          if (group.description?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 10),
            Text(
              group.description!.trim(),
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.alternate_email_rounded,
                size: 18,
                color: AppTheme.secondaryColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  memberEmails.isEmpty
                      ? language.tr('noMembersYet')
                      : memberEmails,
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.library_books_rounded,
                size: 18,
                color: AppTheme.accentColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  sharedClasses.isEmpty
                      ? language.tr('noSharedClasses')
                      : sharedClasses,
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
