import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show PointerHoverEvent;
import 'package:flutter_animate/flutter_animate.dart';

import '../config/app_theme.dart';
import '../localization/localization_extensions.dart';
import 'decorative_glint.dart';

/// Premium Statistics Card with glassmorphic design and hover effects
class StatsCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? iconColor;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final int animationIndex;
  final bool enableGlint;

  const StatsCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.iconColor,
    this.backgroundColor,
    this.onTap,
    this.animationIndex = 0,
    this.enableGlint = true,
  });

  @override
  State<StatsCard> createState() => _StatsCardState();
}

class _StatsCardState extends State<StatsCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  Offset _pointerOffset = Offset.zero;

  late final AnimationController _hoverGlowController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  void _handlePointerHover(PointerHoverEvent event) {
    final box = context.findRenderObject() as RenderBox?;
    final size = box?.size;
    if (size == null || size.width == 0 || size.height == 0) {
      return;
    }

    final normalizedX = ((event.localPosition.dx / size.width) - 0.5) * 2;
    final normalizedY = ((event.localPosition.dy / size.height) - 0.5) * 2;

    setState(() {
      _pointerOffset = Offset(
        normalizedX.clamp(-1.0, 1.0),
        normalizedY.clamp(-1.0, 1.0),
      );
    });
  }

  void _setHovered(bool value) {
    if (_isHovered == value && value == false) {
      return;
    }

    setState(() {
      _isHovered = value;
      if (!value) {
        _pointerOffset = Offset.zero;
      }
    });

    if (value) {
      _hoverGlowController.repeat(reverse: true);
    } else {
      _hoverGlowController
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _hoverGlowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.iconColor ?? AppTheme.primaryColor;
    final translatedTitle = context.t(widget.title);
    final borderRadius = BorderRadius.circular(16);

    final card = AnimatedBuilder(
      animation: _hoverGlowController,
      builder: (context, _) {
        final glowPulse = _isHovered
            ? 0.7 + (_hoverGlowController.value * 0.3)
            : 0.0;

        return TweenAnimationBuilder<Offset>(
          tween: Tween<Offset>(
            end: _isHovered ? _pointerOffset : Offset.zero,
          ),
          duration: AppTheme.animNormal,
          curve: Curves.easeOutCubic,
          builder: (context, tilt, child) {
            final transform = Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateX(-tilt.dy * 0.12)
              ..rotateY(tilt.dx * 0.12)
              ..translateByDouble(tilt.dx * 3, tilt.dy * 3, 0, 1);

            return Transform(
              alignment: Alignment.center,
              transform: transform,
              child: child,
            );
          },
          child: MouseRegion(
            onEnter: (_) => _setHovered(true),
            onHover: _handlePointerHover,
            onExit: (_) => _setHovered(false),
            cursor: widget.onTap != null
                ? SystemMouseCursors.click
                : MouseCursor.defer,
            child: GestureDetector(
              onTap: widget.onTap,
              child: AnimatedScale(
                scale: _isHovered ? 1.02 : 1,
                duration: AppTheme.animFast,
                curve: Curves.easeOutCubic,
                child: AnimatedContainer(
                  duration: AppTheme.animFast,
                  decoration: BoxDecoration(
                    color: widget.backgroundColor ?? AppTheme.bgCard,
                    borderRadius: borderRadius,
                    border: Border.all(
                      color: _isHovered
                          ? color.withValues(alpha: 0.34)
                          : AppTheme.glassBorder,
                      width: _isHovered ? 1 : 0.5,
                    ),
                    boxShadow: _isHovered
                        ? [
                            BoxShadow(
                              color: color.withValues(
                                alpha: 0.16 + (glowPulse * 0.08),
                              ),
                              blurRadius: 18 + (glowPulse * 16),
                              spreadRadius: 0.8 + (glowPulse * 1.6),
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.16),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_isHovered)
                        Align(
                          alignment: Alignment(
                            _pointerOffset.dx * 0.72,
                            _pointerOffset.dy * 0.72,
                          ),
                          child: FractionallySizedBox(
                            widthFactor: 0.82,
                            heightFactor: 0.82,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    color.withValues(alpha: 0.2 + (glowPulse * 0.08)),
                                    color.withValues(alpha: 0.04),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(widget.icon, color: color, size: 20),
                            ),
                            const SizedBox(height: 8),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                widget.value,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              translatedTitle,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (widget.enableGlint)
                        DecorativeGlint(
                          borderRadius: borderRadius,
                          color: Colors.white,
                          intensity: _isHovered ? 0.18 : 0.12,
                          cycleDuration: Duration(
                            milliseconds: 5200 + (widget.animationIndex * 240),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    return card
        .animate(delay: Duration(milliseconds: 220 + (widget.animationIndex * 90)))
        .fadeIn(duration: AppTheme.animSlow)
        .slideY(begin: 0.05, end: 0)
        .scale(
          begin: const Offset(0.97, 0.97),
          end: const Offset(1, 1),
          curve: Curves.easeOutBack,
        );
  }
}

/// Attendance Status Card with glassmorphic design
class AttendanceStatusCard extends StatefulWidget {
  final String status;
  final String time;
  final double? confidence;
  final VoidCallback? onTap;

  const AttendanceStatusCard({
    super.key,
    required this.status,
    required this.time,
    this.confidence,
    this.onTap,
  });

  @override
  State<AttendanceStatusCard> createState() => _AttendanceStatusCardState();
}

class _AttendanceStatusCardState extends State<AttendanceStatusCard> {
  bool _isHovered = false;

  Color get _statusColor {
    switch (widget.status.toLowerCase()) {
      case 'present':
        return AppTheme.successColor;
      case 'late':
        return AppTheme.warningColor;
      case 'absent':
        return AppTheme.errorColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  IconData get _statusIcon {
    switch (widget.status.toLowerCase()) {
      case 'present':
        return Icons.check_circle_rounded;
      case 'late':
        return Icons.access_time_rounded;
      case 'absent':
        return Icons.cancel_rounded;
      default:
        return Icons.help_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final normalizedStatus =
        widget.status[0].toUpperCase() +
        widget.status.substring(1).toLowerCase();

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppTheme.animFast,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _statusColor.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isHovered
                  ? _statusColor.withValues(alpha: 0.4)
                  : _statusColor.withValues(alpha: 0.15),
              width: 1,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: _statusColor.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(_statusIcon, color: _statusColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t(normalizedStatus).toUpperCase(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _statusColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.t(
                        'Checked in at {time}',
                        params: {'time': widget.time},
                      ),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.confidence != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.15),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    '${(widget.confidence! * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryLight,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
