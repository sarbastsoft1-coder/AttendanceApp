import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../localization/localization_extensions.dart';
import '../providers/auth_provider.dart';

/// Desktop sidebar navigation
class SidebarNavigation extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onItemSelected;
  final VoidCallback? onLogout;

  const SidebarNavigation({
    super.key,
    required this.currentIndex,
    required this.onItemSelected,
    this.onLogout,
  });

  @override
  State<SidebarNavigation> createState() => _SidebarNavigationState();
}

class _SidebarNavigationState extends State<SidebarNavigation> {
  static const bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final language = context.language;

    return Container(
      width: AppTheme.sidebarExpandedWidth,
      decoration: BoxDecoration(
        color: AppTheme.bgSidebar,
        border: Border(
          right: BorderSide(color: AppTheme.glassBorder, width: 0.5),
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompactHeight = constraints.maxHeight < 760;

            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      SizedBox(height: isCompactHeight ? 10 : 16),
                      _buildLogo(language),
                      SizedBox(height: isCompactHeight ? 20 : 32),
                      _buildNavigationSection(language, isCompactHeight),
                      const Spacer(),
                      _buildUserSection(language),
                      SizedBox(height: isCompactHeight ? 10 : 16),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNavigationSection(dynamic language, bool isCompactHeight) {
    return Column(
      children: [
        _SidebarItem(
          icon: Icons.dashboard_rounded,
          label: language.tr('dashboard'),
          isSelected: widget.currentIndex == 0,
          isExpanded: _isExpanded,
          onTap: () => widget.onItemSelected(0),
          compact: isCompactHeight,
        ),
        _SidebarItem(
          icon: Icons.history_rounded,
          label: language.tr('history'),
          isSelected: widget.currentIndex == 1,
          isExpanded: _isExpanded,
          onTap: () => widget.onItemSelected(1),
          compact: isCompactHeight,
        ),
        _SidebarItem(
          icon: Icons.qr_code_scanner_rounded,
          label: language.tr('roomScanner'),
          isSelected: widget.currentIndex == 2,
          isExpanded: _isExpanded,
          onTap: () => widget.onItemSelected(2),
          compact: isCompactHeight,
        ),
        _SidebarItem(
          icon: Icons.group_add_rounded,
          label: language.tr('batchRegister'),
          isSelected: widget.currentIndex == 3,
          isExpanded: _isExpanded,
          onTap: () => widget.onItemSelected(3),
          compact: isCompactHeight,
        ),
        SizedBox(height: isCompactHeight ? 4 : 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Divider(
            color: AppTheme.glassBorder,
            thickness: 0.5,
          ),
        ),
        SizedBox(height: isCompactHeight ? 4 : 8),
        _SidebarItem(
          icon: Icons.person_rounded,
          label: language.tr('profile'),
          isSelected: widget.currentIndex == 4,
          isExpanded: _isExpanded,
          onTap: () => widget.onItemSelected(4),
          compact: isCompactHeight,
        ),
        _SidebarItem(
          icon: Icons.notifications_outlined,
          label: language.tr('notifications'),
          isSelected: widget.currentIndex == 8,
          isExpanded: _isExpanded,
          onTap: () => widget.onItemSelected(8),
          compact: isCompactHeight,
        ),
        _SidebarItem(
          icon: Icons.event_note_rounded,
          label: language.tr('leaveRequests'),
          isSelected: widget.currentIndex == 9,
          isExpanded: _isExpanded,
          onTap: () => widget.onItemSelected(9),
          compact: isCompactHeight,
        ),
        SizedBox(height: isCompactHeight ? 4 : 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Divider(
            color: AppTheme.glassBorder,
            thickness: 0.5,
          ),
        ),
        if (_isExpanded)
          Padding(
            padding: EdgeInsets.only(
              left: 20,
              top: isCompactHeight ? 8 : 12,
              bottom: 4,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                language.tr('management'),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMuted,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        _SidebarItem(
          icon: Icons.edit_note_rounded,
          label: language.tr('editAttendance'),
          isSelected: widget.currentIndex == 6,
          isExpanded: _isExpanded,
          onTap: () => widget.onItemSelected(6),
          compact: isCompactHeight,
        ),
        _SidebarItem(
          icon: Icons.class_rounded,
          label: language.tr('classes'),
          isSelected: widget.currentIndex == 7,
          isExpanded: _isExpanded,
          onTap: () => widget.onItemSelected(7),
          compact: isCompactHeight,
        ),
        Consumer<AuthProvider>(
          builder: (context, auth, _) {
            if (!auth.isAdmin) return const SizedBox.shrink();
            return _SidebarItem(
              icon: Icons.admin_panel_settings_rounded,
              label: language.tr('adminPanel'),
              isSelected: widget.currentIndex == 5,
              isExpanded: _isExpanded,
              onTap: () => widget.onItemSelected(5),
              compact: isCompactHeight,
            );
          },
        ),
      ],
    );
  }

  Widget _buildLogo(dynamic language) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryGlow,
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.face_retouching_natural,
              color: Colors.white,
              size: 24,
            ),
          ),
          if (_isExpanded) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'FaceAttend',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    language.tr('teacherPortal'),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUserSection(dynamic language) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final user = auth.user;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: InkWell(
            onTap: widget.onLogout,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.glassHighlight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.glassBorder, width: 0.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Center(
                      child: Text(
                        user?.fullName.isNotEmpty == true
                            ? user!.fullName[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  if (_isExpanded) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.fullName ?? language.tr('user'),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            language.tr('signOut'),
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.errorColor.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.logout_rounded,
                      size: 16,
                      color: AppTheme.errorColor.withValues(alpha: 0.7),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SidebarItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isExpanded;
  final VoidCallback onTap;
  final bool compact;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isExpanded,
    required this.onTap,
    this.compact = false,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isSelected;
    final verticalPadding = widget.compact ? 10.0 : 12.0;
    final iconSize = widget.compact ? 20.0 : 22.0;
    final color = isActive
        ? AppTheme.primaryColor
        : _isHovered
        ? AppTheme.primaryLight
        : AppTheme.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: AppTheme.animFast,
            padding: EdgeInsets.symmetric(
              horizontal: widget.isExpanded ? 14 : 0,
              vertical: verticalPadding,
            ),
            decoration: BoxDecoration(
              color: isActive
                  ? AppTheme.primaryColor.withValues(alpha: 0.12)
                  : _isHovered
                  ? AppTheme.glassHighlight
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isActive
                  ? Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.2),
                      width: 0.5,
                    )
                  : null,
            ),
            child: Row(
              mainAxisAlignment: widget.isExpanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: color, size: iconSize),
                if (widget.isExpanded) ...[
                  const SizedBox(width: 12),
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      color: isActive ? AppTheme.textPrimary : color,
                    ),
                  ),
                ],
                if (isActive && widget.isExpanded) ...[
                  const Spacer(),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: AppTheme.primaryGlow, blurRadius: 6),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
