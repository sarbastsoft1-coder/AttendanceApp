import 'dart:math' as math;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// Responsive layout that switches between sidebar (desktop) and
/// bottom navigation (mobile/tablet).
class ResponsiveLayout extends StatelessWidget {
  final Widget child;

  const ResponsiveLayout({super.key, required this.child});

  static bool isNativeDesktop() {
    return !kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1024;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 768 && width < 1024;
  }

  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 768;
  }

  static bool isCompact(BuildContext context) {
    return MediaQuery.of(context).size.width < 480;
  }

  static double width(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  /// Content max-width for readability on very wide screens
  static double contentMaxWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1800) return 1440;
    if (width > 1500) return 1320;
    if (width > 1200) return 1120;
    return width;
  }

  static EdgeInsets pagePadding(
    BuildContext context, {
    double compact = 12,
    double mobile = 16,
    double tablet = 20,
    double desktop = 28,
  }) {
    final width = MediaQuery.of(context).size.width;
    final value = width < 480
        ? compact
        : width < 768
        ? mobile
        : width < 1024
        ? tablet
        : desktop;
    return EdgeInsets.all(value);
  }

  static double adaptiveValue(
    BuildContext context, {
    required double compact,
    required double mobile,
    required double tablet,
    required double desktop,
  }) {
    final width = MediaQuery.of(context).size.width;
    if (width < 480) return compact;
    if (width < 768) return mobile;
    if (width < 1024) return tablet;
    return desktop;
  }

  static int gridColumns(
    BuildContext context, {
    int compact = 1,
    int mobile = 1,
    int tablet = 2,
    int desktop = 3,
    int wide = 4,
  }) {
    final width = MediaQuery.of(context).size.width;
    if (width < 480) return compact;
    if (width < 768) return mobile;
    if (width < 1024) return tablet;
    if (width < 1440) return desktop;
    return wide;
  }

  static double dialogWidth(
    BuildContext context, {
    double maxWidth = 520,
    double outerPadding = 32,
  }) {
    final availableWidth = MediaQuery.of(context).size.width - outerPadding;
    return math.max(280, math.min(maxWidth, availableWidth));
  }

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

/// A container that centers and constrains content width on desktop
class DesktopContentContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;

  const DesktopContentContainer({
    super.key,
    required this.child,
    this.maxWidth = 1200,
    this.padding = const EdgeInsets.all(24),
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Glassmorphic container widget
class GlassCard extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final Color? borderColor;
  final bool hoverEffect;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.padding,
    this.backgroundColor,
    this.borderColor,
    this.hoverEffect = false,
    this.onTap,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: widget.hoverEffect
          ? (_) => setState(() => _isHovered = true)
          : null,
      onExit: widget.hoverEffect
          ? (_) => setState(() => _isHovered = false)
          : null,
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppTheme.animFast,
          padding: widget.padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _isHovered
                ? (widget.backgroundColor ?? AppTheme.glassBg).withValues(
                    alpha: 0.2,
                  )
                : widget.backgroundColor ?? AppTheme.glassBg,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: _isHovered
                  ? AppTheme.primaryColor.withValues(alpha: 0.3)
                  : widget.borderColor ?? AppTheme.glassBorder,
              width: 1,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: AppTheme.primaryGlow,
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
