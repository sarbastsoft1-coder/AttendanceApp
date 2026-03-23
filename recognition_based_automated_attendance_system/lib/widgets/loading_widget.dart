import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// Premium Loading Widget with branded spinner
class LoadingWidget extends StatelessWidget {
  final String? message;
  final Color? color;
  final double size;

  const LoadingWidget({
    super.key,
    this.message,
    this.color,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                color ?? AppTheme.primaryColor,
              ),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
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
                child: LoadingWidget(
                  message: message,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
