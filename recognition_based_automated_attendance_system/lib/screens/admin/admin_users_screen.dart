import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../localization/localization_extensions.dart';
import '../../models/user_model.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/input_validators.dart';
import '../../widgets/responsive_layout.dart';

/// Admin Users Management Screen
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  String t(String text, {Map<String, String> params = const {}}) =>
      context.t(text, params: params);

  String _roleLabel(String role) {
    final language = context.language;
    switch (role) {
      case 'super_admin':
        return language.tr('superAdmin');
      case 'admin':
        return language.tr('admin');
      case 'super_teacher':
        return language.tr('superTeacher');
      case 'teacher':
        return language.tr('teacher');
      default:
        return role;
    }
  }

  bool _isAdminRole(String role) => role == 'admin' || role == 'super_admin';

  bool _canManageUser(User user) {
    final currentUser = context.read<AuthProvider>().user;
    return currentUser?.isSuperAdmin == true || user.role != 'super_admin';
  }

  List<DropdownMenuItem<String>> _buildRoleItems() {
    final language = context.language;
    final currentUser = context.read<AuthProvider>().user;
    final items = <DropdownMenuItem<String>>[
      DropdownMenuItem(value: 'teacher', child: Text(language.tr('teacher'))),
      DropdownMenuItem(
        value: 'super_teacher',
        child: Text(language.tr('superTeacher')),
      ),
      DropdownMenuItem(value: 'admin', child: Text(language.tr('admin'))),
    ];

    if (currentUser?.isSuperAdmin == true) {
      items.add(
        DropdownMenuItem(
          value: 'super_admin',
          child: Text(language.tr('superAdmin')),
        ),
      );
    }

    return items;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadUsers();
      }
    });
  }

  void _loadUsers() {
    final attendanceProvider = context.read<AttendanceProvider>();
    attendanceProvider.fetchAllUsers();
  }

  List<User> _filteredUsers(List<User> users) {
    if (_searchQuery.isEmpty) {
      return users;
    }

    return users.where((user) {
      return user.fullName.toLowerCase().contains(_searchQuery) ||
          user.email.toLowerCase().contains(_searchQuery) ||
          _roleLabel(user.role).toLowerCase().contains(_searchQuery);
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final padding = ResponsiveLayout.pagePadding(
      context,
      compact: 12,
      mobile: 16,
      tablet: 20,
      desktop: 24,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(t('Manage Users')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            onPressed: _showCreateUserDialog,
            tooltip: t('Create Account'),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadUsers),
        ],
      ),
      body: SafeArea(
        child: Consumer<AttendanceProvider>(
          builder: (context, provider, child) {
            final users = _filteredUsers(provider.allUsers);
            final adminCount = users
                .where((user) => _isAdminRole(user.role))
                .length;
            final teacherCount = users.length - adminCount;
            final faceCount = users
                .where((user) => user.hasRegisteredFace)
                .length;

            return RefreshIndicator(
              onRefresh: () async => _loadUsers(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: padding,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: ResponsiveLayout.contentMaxWidth(context),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: AppTheme.cardDecoration(),
                          child: Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 620,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t('Manage Users'),
                                      style: const TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      t(
                                        'Admins create user and admin accounts here. Public registration stays limited to user accounts.',
                                      ),
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        height: 1.45,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _loadUsers,
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: Text(t('Refresh')),
                                  ),
                                  FilledButton.icon(
                                    onPressed: _showCreateUserDialog,
                                    icon: const Icon(
                                      Icons.person_add_alt_1_rounded,
                                    ),
                                    label: Text(t('Create Account')),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: [
                            _buildMetricCard(
                              label: t('Total Users'),
                              value: '${users.length}',
                              icon: Icons.groups_rounded,
                              color: AppTheme.primaryColor,
                            ),
                            _buildMetricCard(
                              label: t('Admin Accounts'),
                              value: '$adminCount',
                              icon: Icons.admin_panel_settings_rounded,
                              color: AppTheme.secondaryColor,
                            ),
                            _buildMetricCard(
                              label: t('User Accounts'),
                              value: '$teacherCount',
                              icon: Icons.school_rounded,
                              color: Colors.amber,
                            ),
                            _buildMetricCard(
                              label: t('Faces Registered'),
                              value: '$faceCount',
                              icon: Icons.face_rounded,
                              color: AppTheme.successColor,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: AppTheme.cardDecoration(),
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: t('Search by name, email, or role...'),
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                            ),
                            onChanged: (value) {
                              setState(
                                () => _searchQuery = value.trim().toLowerCase(),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: AppTheme.cardDecoration(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (provider.isLoading) ...[
                                const LinearProgressIndicator(minHeight: 3),
                                const SizedBox(height: 16),
                              ],
                              if (!provider.isLoading && users.isEmpty)
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 36,
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.people_outline_rounded,
                                          size: 56,
                                          color: AppTheme.textMuted,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          _searchQuery.isEmpty
                                              ? t('No users found')
                                              : t('No users match your search'),
                                          style: const TextStyle(
                                            fontSize: 15,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: users.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final user = users[index];
                                    return _buildUserCard(user);
                                  },
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final width = ResponsiveLayout.width(context) < 540
        ? double.infinity
        : 220.0;

    return Container(
      width: width,
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildUserCard(User user) {
    final canManageUser = _canManageUser(user);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final chipColor = _isAdminRole(user.role)
            ? AppTheme.primaryColor
            : AppTheme.textSecondary;

        final chips = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _InfoChip(
              icon: Icons.badge_outlined,
              label: _roleLabel(user.role),
              color: chipColor,
            ),
            _InfoChip(
              icon: user.hasRegisteredFace
                  ? Icons.face_rounded
                  : Icons.face_outlined,
              label: user.hasRegisteredFace
                  ? t('Face Registered')
                  : t('Face Pending'),
              color: user.hasRegisteredFace
                  ? AppTheme.successColor
                  : AppTheme.warningColor,
            ),
            if (user.department?.trim().isNotEmpty ?? false)
              _InfoChip(
                icon: Icons.business_outlined,
                label: user.department!.trim(),
                color: AppTheme.secondaryColor,
              ),
          ],
        );

        final actions = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _showUserDetails(user),
              icon: const Icon(Icons.visibility_outlined),
              label: Text(t('View Details')),
            ),
            if (canManageUser)
              OutlinedButton.icon(
                onPressed: () => _confirmDeleteUser(user),
                icon: const Icon(Icons.delete_outline_rounded),
                label: Text(t('Delete')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.errorColor,
                ),
              ),
          ],
        );

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.bgElevated,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.glassBorder),
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _UserIdentity(user: user),
                    const SizedBox(height: 14),
                    chips,
                    const SizedBox(height: 14),
                    actions,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _UserIdentity(user: user),
                          const SizedBox(height: 14),
                          chips,
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    actions,
                  ],
                ),
        );
      },
    );
  }

  Future<void> _showCreateUserDialog() async {
    final genericCreateError = t('Failed to create user');
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final adminAccessKeyController = TextEditingController();
    final phoneController = TextEditingController();
    final departmentController = TextEditingController();
    final roleItems = _buildRoleItems();
    var selectedRole = roleItems.first.value!;
    var isSubmitting = false;
    String? dialogError;

    final createdUser = await showDialog<User?>(
      context: context,
      builder: (dialogContext) {
        InputDecoration decoration(String label) {
          return InputDecoration(
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: AppTheme.bgElevated,
          );
        }

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> submit() async {
              if (!formKey.currentState!.validate()) {
                return;
              }

              setDialogState(() {
                isSubmitting = true;
                dialogError = null;
              });

              final provider = context.read<AttendanceProvider>();
              final user = await provider.createUser(
                email: emailController.text.trim(),
                fullName: nameController.text.trim(),
                password: passwordController.text,
                role: selectedRole,
                adminAccessKey:
                    selectedRole == 'admin' || selectedRole == 'super_admin'
                    ? adminAccessKeyController.text.trim()
                    : null,
                phone: phoneController.text.trim().isEmpty
                    ? null
                    : phoneController.text.trim(),
                department: departmentController.text.trim().isEmpty
                    ? null
                    : departmentController.text.trim(),
              );

              if (!mounted || !dialogContext.mounted) {
                return;
              }

              if (user != null) {
                Navigator.pop(dialogContext, user);
                return;
              }

              setDialogState(() {
                isSubmitting = false;
                dialogError = provider.error ?? genericCreateError;
              });
            }

            return AlertDialog(
              title: Text(t('Create Account')),
              content: SizedBox(
                width: ResponsiveLayout.dialogWidth(context, maxWidth: 560),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          t(
                            'Create user and admin accounts here. Public registration remains limited to user accounts.',
                          ),
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: nameController,
                          textInputAction: TextInputAction.next,
                          decoration: decoration(t('Full Name')),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return t('Name is required');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: decoration(t('Email')),
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            if (email.isEmpty) {
                              return t('Please enter your email');
                            }
                            if (!isValidEmailAddress(email)) {
                              return t('Please enter a valid email');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: selectedRole,
                          decoration: decoration(t('Role')),
                          items: roleItems,
                          onChanged: isSubmitting
                              ? null
                              : (value) {
                                  if (value == null) {
                                    return;
                                  }
                                  setDialogState(() => selectedRole = value);
                                },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: passwordController,
                          obscureText: true,
                          textInputAction: TextInputAction.next,
                          decoration: decoration(t('Password')),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return t('Password is required');
                            }
                            if (value.length < 6) {
                              return t(
                                'Password must be at least 6 characters',
                              );
                            }
                            return null;
                          },
                        ),
                        if (selectedRole == 'admin' ||
                            selectedRole == 'super_admin') ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: adminAccessKeyController,
                            obscureText: true,
                            textInputAction: TextInputAction.next,
                            decoration: decoration(t('Admin Access Key')),
                            validator: (value) {
                              final key = value?.trim() ?? '';
                              if (selectedRole != 'admin' &&
                                  selectedRole != 'super_admin') {
                                return null;
                              }
                              if (key.isEmpty) {
                                return t('Admin access key is required');
                              }
                              if (key.length < 4) {
                                return t(
                                  'Admin access key must be at least 4 characters',
                                );
                              }
                              return null;
                            },
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          decoration: decoration(t('Phone Number')),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: departmentController,
                          textInputAction: TextInputAction.done,
                          decoration: decoration(t('Department')),
                          onFieldSubmitted: (_) => submit(),
                        ),
                        if (dialogError != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            dialogError!,
                            style: const TextStyle(color: AppTheme.errorColor),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: Text(t('Cancel')),
                ),
                ElevatedButton.icon(
                  onPressed: isSubmitting ? null : submit,
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.person_add_alt_1),
                  label: Text(t('Create')),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    adminAccessKeyController.dispose();
    phoneController.dispose();
    departmentController.dispose();

    if (!mounted || createdUser == null) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          t(
            'Account created for {name}',
            params: {'name': createdUser.fullName},
          ),
        ),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  void _showUserDetails(User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user.fullName),
        content: SizedBox(
          width: ResponsiveLayout.dialogWidth(context, maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Email', user.email),
              _buildDetailRow('Role', _roleLabel(user.role)),
              _buildDetailRow('Phone', user.phone ?? t('Not provided')),
              _buildDetailRow(
                'Department',
                user.department ?? t('Not provided'),
              ),
              _buildDetailRow(
                'Face Registered',
                user.hasRegisteredFace ? t('Yes') : t('No'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t('Close')),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '${context.t(label)}:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _confirmDeleteUser(User user) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t('Delete User')),
        content: Text(
          t(
            'Are you sure you want to delete {name}?',
            params: {'name': user.fullName},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(t('Cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              final provider = context.read<AttendanceProvider>();
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              Navigator.pop(dialogContext);
              final success = await provider.deleteUser(user.id);
              if (!mounted) {
                return;
              }
              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? t('User deleted')
                        : provider.error ?? t('Failed to delete user'),
                  ),
                  backgroundColor: success
                      ? AppTheme.successColor
                      : AppTheme.errorColor,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: Text(t('Delete')),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserIdentity extends StatelessWidget {
  final User user;

  const _UserIdentity({required this.user});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.14),
          child: Text(
            user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.fullName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user.email,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
              if (user.phone?.trim().isNotEmpty ?? false) ...[
                const SizedBox(height: 4),
                Text(
                  user.phone!.trim(),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
