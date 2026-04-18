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

  final GlobalKey _selectorScopeKey = GlobalKey();
  final Map<int, GlobalKey> _itemKeys = <int, GlobalKey>{};

  double? _selectorTop;
  double? _selectorHeight;
  bool _selectorSyncQueued = false;

  GlobalKey _itemKeyFor(int index) {
    return _itemKeys.putIfAbsent(index, GlobalKey.new);
  }

  @override
  void didUpdateWidget(covariant SidebarNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _queueSelectorSync();
    }
  }

  void _queueSelectorSync() {
    if (_selectorSyncQueued) {
      return;
    }

    _selectorSyncQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _selectorSyncQueued = false;
      _syncSelector();
    });
  }

  void _syncSelector() {
    if (!mounted) {
      return;
    }

    final scopeBox =
        _selectorScopeKey.currentContext?.findRenderObject() as RenderBox?;
    final itemBox =
        _itemKeyFor(widget.currentIndex).currentContext?.findRenderObject()
            as RenderBox?;

    if (scopeBox == null || itemBox == null) {
      if (_selectorTop != null || _selectorHeight != null) {
        setState(() {
          _selectorTop = null;
          _selectorHeight = null;
        });
      }
      return;
    }

    final offset = itemBox.localToGlobal(Offset.zero, ancestor: scopeBox);
    final nextTop = offset.dy;
    final nextHeight = itemBox.size.height;

    final shouldUpdate =
        _selectorTop == null ||
        _selectorHeight == null ||
        (nextTop - _selectorTop!).abs() > 0.5 ||
        (nextHeight - _selectorHeight!).abs() > 0.5;

    if (shouldUpdate) {
      setState(() {
        _selectorTop = nextTop;
        _selectorHeight = nextHeight;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = context.language;
    final auth = context.watch<AuthProvider>();

    _queueSelectorSync();

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
                      _buildNavigationSection(language, auth, isCompactHeight),
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

  Widget _buildNavigationSection(
    dynamic language,
    AuthProvider auth,
    bool isCompactHeight,
  ) {
    final isSuperTeacher = auth.user?.isSuperTeacher == true;
    final mainItems = <_SidebarMenuItemData>[
      _SidebarMenuItemData(
        index: 0,
        icon: Icons.dashboard_rounded,
        label: language.tr('dashboard'),
      ),
      _SidebarMenuItemData(
        index: 1,
        icon: Icons.history_rounded,
        label: language.tr('history'),
      ),
      _SidebarMenuItemData(
        index: 2,
        icon: Icons.qr_code_scanner_rounded,
        label: language.tr('roomScanner'),
      ),
      _SidebarMenuItemData(
        index: 3,
        icon: Icons.group_add_rounded,
        label: language.tr('batchRegister'),
      ),
    ];

    final utilityItems = <_SidebarMenuItemData>[
      _SidebarMenuItemData(
        index: 4,
        icon: Icons.person_rounded,
        label: language.tr('profile'),
      ),
      _SidebarMenuItemData(
        index: 8,
        icon: Icons.notifications_outlined,
        label: language.tr('notifications'),
      ),
      _SidebarMenuItemData(
        index: 9,
        icon: Icons.event_note_rounded,
        label: language.tr('leaveRequests'),
      ),
    ];

    final managementItems = <_SidebarMenuItemData>[
      if (!isSuperTeacher)
        _SidebarMenuItemData(
          index: 6,
          icon: Icons.edit_note_rounded,
          label: language.tr('editAttendance'),
        ),
      _SidebarMenuItemData(
        index: 7,
        icon: Icons.class_rounded,
        label: language.tr('classes'),
      ),
      if (!isSuperTeacher &&
          (auth.user?.isAdmin == true || auth.user?.isTeacher == true))
        _SidebarMenuItemData(
          index: 13,
          icon: Icons.download_for_offline_rounded,
          label: language.tr('exportCenter'),
        ),
      if (!isSuperTeacher)
        _SidebarMenuItemData(
          index: 11,
          icon: Icons.fact_check_rounded,
          label: language.tr('rollCall'),
        ),
      if (auth.user?.isAdmin == true || auth.user?.isTeacher == true)
        _SidebarMenuItemData(
          index: 14,
          icon: Icons.groups_2_rounded,
          label: language.tr('supervisorHub'),
        ),
      if (auth.isAdmin)
        _SidebarMenuItemData(
          index: 5,
          icon: Icons.admin_panel_settings_rounded,
          label: language.tr('adminPanel'),
        ),
    ];

    return Stack(
      key: _selectorScopeKey,
      children: [
        if (_selectorTop != null && _selectorHeight != null)
          AnimatedPositioned(
            duration: AppTheme.animNormal,
            curve: Curves.easeOutCubic,
            left: 0,
            right: 0,
            top: _selectorTop!,
            height: _selectorHeight!,
            child: IgnorePointer(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 2,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: AlignmentDirectional.centerStart,
                      end: AlignmentDirectional.centerEnd,
                      colors: [
                        AppTheme.primaryColor.withValues(alpha: 0.18),
                        AppTheme.secondaryColor.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.18),
                      width: 0.7,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryGlow.withValues(alpha: 0.55),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Container(
                      width: 4,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.2),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        Column(
          children: [
            ...mainItems.map((item) => _buildNavItem(item, isCompactHeight)),
            SizedBox(height: isCompactHeight ? 4 : 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(color: AppTheme.glassBorder, thickness: 0.5),
            ),
            SizedBox(height: isCompactHeight ? 4 : 8),
            ...utilityItems.map((item) => _buildNavItem(item, isCompactHeight)),
            SizedBox(height: isCompactHeight ? 4 : 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(color: AppTheme.glassBorder, thickness: 0.5),
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
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ...managementItems.map(
              (item) => _buildNavItem(item, isCompactHeight),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNavItem(_SidebarMenuItemData item, bool isCompactHeight) {
    return _SidebarItem(
      key: _itemKeyFor(item.index),
      icon: item.icon,
      label: item.label,
      isSelected: widget.currentIndex == item.index,
      isExpanded: _isExpanded,
      onTap: () => widget.onItemSelected(item.index),
      compact: isCompactHeight,
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

class _SidebarMenuItemData {
  final int index;
  final IconData icon;
  final String label;

  const _SidebarMenuItemData({
    required this.index,
    required this.icon,
    required this.label,
  });
}

class _SidebarItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isExpanded;
  final VoidCallback onTap;
  final bool compact;

  const _SidebarItem({
    super.key,
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
    final iconColor = isActive
        ? AppTheme.primaryLight
        : _isHovered
        ? AppTheme.textPrimary
        : AppTheme.textSecondary;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: AnimatedScale(
            scale: _isHovered ? 1.012 : 1,
            duration: AppTheme.animFast,
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: AppTheme.animFast,
              padding: EdgeInsets.symmetric(
                horizontal: widget.isExpanded ? 14 : 0,
                vertical: verticalPadding,
              ),
              decoration: BoxDecoration(
                color: !isActive && _isHovered
                    ? AppTheme.glassHighlight
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: widget.isExpanded
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: AppTheme.animFast,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppTheme.primaryColor.withValues(alpha: 0.16)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(widget.icon, color: iconColor, size: iconSize),
                  ),
                  if (widget.isExpanded) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: AnimatedDefaultTextStyle(
                        duration: AppTheme.animFast,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isActive
                              ? AppTheme.textPrimary
                              : (_isHovered
                                    ? AppTheme.textPrimary
                                    : AppTheme.textSecondary),
                        ),
                        child: Text(widget.label),
                      ),
                    ),
                  ],
                  if (isActive && widget.isExpanded)
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryGlow.withValues(alpha: 0.8),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
