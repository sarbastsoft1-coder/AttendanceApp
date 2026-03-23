import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_button.dart';

/// Premium Profile Screen — Two-column layout for desktop
class ProfileScreen extends StatefulWidget {
  final bool embedded;

  const ProfileScreen({super.key, this.embedded = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  @override
  Widget build(BuildContext context) {
    final content = _buildContent();

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      appBar: _isDesktop
          ? null
          : AppBar(title: const Text('Profile')),
      body: content,
    );
  }

  Widget _buildContent() {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final user = auth.user;
        if (user == null) {
          return const Center(
            child: Text('Not logged in', style: TextStyle(color: AppTheme.textSecondary)),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: _isDesktop
                ? _buildDesktopProfile(auth, user)
                : _buildMobileProfile(auth, user),
          ),
        );
      },
    );
  }

  Widget _buildDesktopProfile(AuthProvider auth, dynamic user) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column — Avatar & Info
        SizedBox(
          width: 320,
          child: _buildProfileCard(auth, user),
        ),
        const SizedBox(width: 24),
        // Right Column — Actions & Settings
        Expanded(
          child: _buildActionsPanel(auth),
        ),
      ],
    );
  }

  Widget _buildMobileProfile(AuthProvider auth, dynamic user) {
    return Column(
      children: [
        _buildProfileCard(auth, user),
        const SizedBox(height: 24),
        _buildActionsPanel(auth),
      ],
    );
  }

  Widget _buildProfileCard(AuthProvider auth, dynamic user) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryGlow,
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Text(
                user.fullName.isNotEmpty
                    ? user.fullName[0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ).animate().fadeIn(delay: 100.ms).scale(begin: const Offset(0.9, 0.9)),
          const SizedBox(height: 20),
          Text(
            user.fullName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 4),
          Text(
            user.email,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ).animate().fadeIn(delay: 250.ms),
          const SizedBox(height: 6),
          // Role Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: auth.isAdmin
                  ? AppTheme.accentColor.withValues(alpha: 0.12)
                  : AppTheme.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: auth.isAdmin
                    ? AppTheme.accentColor.withValues(alpha: 0.2)
                    : AppTheme.primaryColor.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
            child: Text(
              auth.isAdmin ? 'Admin' : 'Teacher',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: auth.isAdmin ? AppTheme.accentColor : AppTheme.primaryLight,
              ),
            ),
          ).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 24),
          const Divider(color: AppTheme.glassBorder),
          const SizedBox(height: 16),

          // Info rows
          if (user.phone != null && user.phone!.isNotEmpty)
            _InfoRow(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: user.phone!,
            ),
          if (user.department != null && user.department!.isNotEmpty)
            _InfoRow(
              icon: Icons.business_outlined,
              label: 'Department',
              value: user.department!,
            ),
          _InfoRow(
            icon: Icons.face_retouching_natural,
            label: 'Face Registered',
            value: auth.hasRegisteredFace ? 'Yes' : 'No',
            valueColor: auth.hasRegisteredFace
                ? AppTheme.successColor
                : AppTheme.errorColor,
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.03, end: 0);
  }

  Widget _buildActionsPanel(AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        const Text(
          'Account',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
            letterSpacing: -0.3,
          ),
        ).animate().fadeIn(delay: 200.ms),
        const SizedBox(height: 6),
        const Text(
          'Manage your profile and settings',
          style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
        ).animate().fadeIn(delay: 250.ms),
        const SizedBox(height: 24),

        // Actions Grid
        Container(
          padding: const EdgeInsets.all(24),
          decoration: AppTheme.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Actions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _ActionItem(
                icon: Icons.edit_rounded,
                label: 'Edit Profile',
                subtitle: 'Update your name, phone, and department',
                color: AppTheme.primaryColor,
                onTap: () {
                  // TODO: Navigate to edit profile
                },
              ),
              const SizedBox(height: 10),
              _ActionItem(
                icon: Icons.face_retouching_natural,
                label: 'Re-register Face',
                subtitle: 'Update your facial recognition data',
                color: AppTheme.secondaryColor,
                onTap: () =>
                    Navigator.pushNamed(context, '/face-capture'),
              ),
              if (auth.isAdmin) ...[
                const SizedBox(height: 10),
                _ActionItem(
                  icon: Icons.admin_panel_settings_rounded,
                  label: 'Admin Dashboard',
                  subtitle: 'Manage users, reports, and settings',
                  color: AppTheme.accentColor,
                  onTap: () => Navigator.pushNamed(context, '/admin'),
                ),
              ],
            ],
          ),
        ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.03, end: 0),

        const SizedBox(height: 20),

        // Sign Out
        Container(
          padding: const EdgeInsets.all(24),
          decoration: AppTheme.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Session',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              CustomButton(
                text: 'Sign Out',
                icon: Icons.logout_rounded,
                backgroundColor: AppTheme.errorColor,
                onPressed: () => _logout(),
              ),
            ],
          ),
        ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.03, end: 0),
      ],
    );
  }

  void _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await context.read<AuthProvider>().logout();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }
}

// ─── Profile Info Row ───────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.bgElevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: AppTheme.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: valueColor ?? AppTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Action Item ────────────────────────────────────────────
class _ActionItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ActionItem> createState() => _ActionItemState();
}

class _ActionItemState extends State<_ActionItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppTheme.animFast,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _isHovered
                ? widget.color.withValues(alpha: 0.08)
                : AppTheme.bgElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovered
                  ? widget.color.withValues(alpha: 0.2)
                  : AppTheme.glassBorder,
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.icon, color: widget.color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: _isHovered
                    ? widget.color
                    : AppTheme.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
