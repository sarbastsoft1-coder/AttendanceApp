import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../localization/localization_extensions.dart';

/// Premium Loading Widget with branded spinner
class LoadingWidget extends StatelessWidget {
  final String? message;
  final Color? color;
  final double size;

  const LoadingWidget({super.key, this.message, this.color, this.size = 36});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          BrandedSpinner(
            size: size,
            color: color ?? AppTheme.primaryColor,
            strokeWidth: size < 28 ? 2.2 : 3,
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              context.t(message!),
              style: TextStyle(
                color: color ?? AppTheme.textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Shared branded spinner used across loading surfaces and buttons.
class BrandedSpinner extends StatefulWidget {
  final Color color;
  final double size;
  final double strokeWidth;

  const BrandedSpinner({
    super.key,
    required this.color,
    this.size = 36,
    this.strokeWidth = 3,
  });

  @override
  State<BrandedSpinner> createState() => _BrandedSpinnerState();
}

class _BrandedSpinnerState extends State<BrandedSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final pulse =
            (math.sin(_controller.value * math.pi * 2) + 1) / 2;

        return CustomPaint(
          size: Size.square(widget.size),
          painter: _BrandedSpinnerPainter(
            color: widget.color,
            progress: _controller.value,
            pulse: pulse,
            strokeWidth: widget.strokeWidth,
          ),
        );
      },
    );
  }
}

class _BrandedSpinnerPainter extends CustomPainter {
  final Color color;
  final double progress;
  final double pulse;
  final double strokeWidth;

  const _BrandedSpinnerPainter({
    required this.color,
    required this.progress,
    required this.pulse,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide / 2) - strokeWidth;
    final arcRect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = color.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    final sweepPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.18 + (pulse * 0.10))
      ..style = PaintingStyle.fill;

    final startAngle = (-math.pi / 2) + (progress * math.pi * 2);
    final sweepAngle = math.pi * (1.05 + (pulse * 0.5));

    canvas.drawCircle(center, size.shortestSide * (0.14 + (pulse * 0.03)), glowPaint);
    canvas.drawArc(arcRect, 0, math.pi * 2, false, trackPaint);
    canvas.drawArc(arcRect, startAngle, sweepAngle, false, sweepPaint);
    canvas.drawCircle(
      center,
      size.shortestSide * (0.08 + (pulse * 0.018)),
      Paint()..color = color.withValues(alpha: 0.88),
    );
  }

  @override
  bool shouldRepaint(covariant _BrandedSpinnerPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.progress != progress ||
        oldDelegate.pulse != pulse ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

/// Full screen glassmorphic loading overlay with blur backdrop
class LoadingOverlay extends StatelessWidget {
  final String? message;
  final Widget child;
  final bool isLoading;

  const LoadingOverlay({
    super.key,
    this.message,
    required this.child,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: AppTheme.bgDeep.withValues(alpha: 0.7),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: AppTheme.glassDecoration(borderRadius: 20),
                child: LoadingWidget(message: message, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}
