import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';

/// Animated collapsible sidebar navigation for desktop
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

class _SidebarNavigationState extends State<SidebarNavigation>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = true;
  late AnimationController _animController;
  late Animation<double> _widthAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: AppTheme.animNormal,
      vsync: this,
    );
    _widthAnimation =
        Tween<double>(
          begin: AppTheme.sidebarExpandedWidth,
          end: AppTheme.sidebarCollapsedWidth,
        ).animate(
          CurvedAnimation(
            parent: _animController,
            curve: Curves.easeInOutCubic,
          ),
        );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggleSidebar() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animController.reverse();
      } else {
        _animController.forward();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _widthAnimation,
      builder: (context, child) {
        return Container(
          width: _widthAnimation.value,
          decoration: BoxDecoration(
            color: AppTheme.bgSidebar,
            border: Border(
              right: BorderSide(color: AppTheme.glassBorder, width: 0.5),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 16),
              // ─── Logo ─────────────────────────
              _buildLogo(),
              const SizedBox(height: 32),
              // ─── Navigation Items ────────────
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _SidebarItem(
                        icon: Icons.dashboard_rounded,
                        label: 'Dashboard',
                        isSelected: widget.currentIndex == 0,
                        isExpanded: _isExpanded,
                        onTap: () => widget.onItemSelected(0),
                      ),
                      _SidebarItem(
                        icon: Icons.history_rounded,
                        label: 'History',
                        isSelected: widget.currentIndex == 1,
                        isExpanded: _isExpanded,
                        onTap: () => widget.onItemSelected(1),
                      ),
                      _SidebarItem(
                        icon: Icons.qr_code_scanner_rounded,
                        label: 'Room Scanner',
                        isSelected: widget.currentIndex == 2,
                        isExpanded: _isExpanded,
                        onTap: () => widget.onItemSelected(2),
                      ),
                      _SidebarItem(
                        icon: Icons.group_add_rounded,
                        label: 'Batch Register',
                        isSelected: widget.currentIndex == 3,
                        isExpanded: _isExpanded,
                        onTap: () => widget.onItemSelected(3),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Divider(
                          color: AppTheme.glassBorder,
                          thickness: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _SidebarItem(
                        icon: Icons.person_rounded,
                        label: 'Profile',
                        isSelected: widget.currentIndex == 4,
                        isExpanded: _isExpanded,
                        onTap: () => widget.onItemSelected(4),
                      ),
                      _SidebarItem(
                        icon: Icons.notifications_outlined,
                        label: 'Notifications',
                        isSelected: widget.currentIndex == 8,
                        isExpanded: _isExpanded,
                        onTap: () => widget.onItemSelected(8),
                      ),
                      _SidebarItem(
                        icon: Icons.event_note_rounded,
                        label: 'Leave Requests',
                        isSelected: widget.currentIndex == 9,
                        isExpanded: _isExpanded,
                        onTap: () => widget.onItemSelected(9),
                      ),
                      // Management section (visible to all)
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Divider(
                          color: AppTheme.glassBorder,
                          thickness: 0.5,
                        ),
                      ),
                      if (_isExpanded)
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 20,
                            top: 12,
                            bottom: 4,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'MANAGEMENT',
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
                        label: 'Edit Attendance',
                        isSelected: widget.currentIndex == 6,
                        isExpanded: _isExpanded,
                        onTap: () => widget.onItemSelected(6),
                      ),
                      _SidebarItem(
                        icon: Icons.class_rounded,
                        label: 'Classes',
                        isSelected: widget.currentIndex == 7,
                        isExpanded: _isExpanded,
                        onTap: () => widget.onItemSelected(7),
                      ),
                      // Admin section (admin-only)
                      Consumer<AuthProvider>(
                        builder: (context, auth, _) {
                          if (!auth.isAdmin) return const SizedBox.shrink();
                          return Column(
                            children: [
                              _SidebarItem(
                                icon: Icons.admin_panel_settings_rounded,
                                label: 'Admin Panel',
                                isSelected: widget.currentIndex == 5,
                                isExpanded: _isExpanded,
                                onTap: () => widget.onItemSelected(5),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              // ─── Collapse Toggle ──────────────
              _buildCollapseToggle(),
              const SizedBox(height: 8),
              // ─── User Info + Logout ───────────
              _buildUserSection(),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLogo() {
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
                  Text(
                    'FaceAttend',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    'Teacher Portal',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCollapseToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: InkWell(
        onTap: _toggleSidebar,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.glassHighlight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: _isExpanded
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              AnimatedRotation(
                turns: _isExpanded ? 0.0 : 0.5,
                duration: AppTheme.animNormal,
                child: const Icon(
                  Icons.keyboard_double_arrow_left_rounded,
                  color: AppTheme.textSecondary,
                  size: 20,
                ),
              ),
              if (_isExpanded) ...[
                const SizedBox(width: 10),
                const Text(
                  'Collapse',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserSection() {
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
                            user?.fullName ?? 'User',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Sign out',
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

/// Individual sidebar navigation item
class _SidebarItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isExpanded;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isSelected;
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
              vertical: 12,
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
                Icon(widget.icon, color: color, size: 22),
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
