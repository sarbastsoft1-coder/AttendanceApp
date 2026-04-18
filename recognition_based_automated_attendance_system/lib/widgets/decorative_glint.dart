import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A low-frequency decorative sweep used to add subtle premium motion.
class DecorativeGlint extends StatefulWidget {
  final BorderRadius borderRadius;
  final Color color;
  final double intensity;
  final double widthFactor;
  final Duration cycleDuration;
  final double angle;

  const DecorativeGlint({
    super.key,
    required this.borderRadius,
    this.color = Colors.white,
    this.intensity = 0.16,
    this.widthFactor = 0.34,
    this.cycleDuration = const Duration(milliseconds: 5600),
    this.angle = -0.34,
  });

  @override
  State<DecorativeGlint> createState() => _DecorativeGlintState();
}

class _DecorativeGlintState extends State<DecorativeGlint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.cycleDuration,
  )..repeat();

  @override
  void didUpdateWidget(covariant DecorativeGlint oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cycleDuration != widget.cycleDuration) {
      _controller.duration = widget.cycleDuration;
      _controller
        ..reset()
        ..repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ClipRRect(
        borderRadius: widget.borderRadius,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final progress = _controller.value;
            if (progress < 0.58) {
              return const SizedBox.expand();
            }

            final phase = ((progress - 0.58) / 0.42).clamp(0.0, 1.0);
            final eased = Curves.easeInOutCubic.transform(phase);
            final alignmentX = -1.6 + (3.2 * eased);
            final opacity = math.sin(math.pi * phase) * widget.intensity;

            return Align(
              alignment: Alignment(alignmentX, 0),
              child: Transform.rotate(
                angle: widget.angle,
                child: FractionallySizedBox(
                  widthFactor: widget.widthFactor,
                  heightFactor: 1.85,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.transparent,
                          widget.color.withValues(alpha: opacity * 0.45),
                          widget.color.withValues(alpha: opacity),
                          widget.color.withValues(alpha: opacity * 0.45),
                          Colors.transparent,
                        ],
                      ),
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
}
