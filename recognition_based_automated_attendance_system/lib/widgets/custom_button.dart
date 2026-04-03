import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../localization/localization_extensions.dart';

/// Premium Custom Button with hover glow and gradient support
class CustomButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double height;
  final double borderRadius;
  final bool useGradient;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height = 52,
    this.borderRadius = 12,
    this.useGradient = false,
  });

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final translatedText = context.t(widget.text);

    if (widget.isOutlined) {
      return MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: widget.onPressed != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: AnimatedContainer(
          duration: AppTheme.animFast,
          width: widget.width ?? double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            color: _isHovered
                ? AppTheme.primaryColor.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: widget.backgroundColor ?? AppTheme.primaryColor,
              width: 1.5,
            ),
            boxShadow: _isHovered
                ? [BoxShadow(color: AppTheme.primaryGlow, blurRadius: 12)]
                : [],
          ),
          child: OutlinedButton(
            onPressed: widget.isLoading ? null : widget.onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: widget.textColor ?? AppTheme.primaryLight,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(widget.borderRadius),
              ),
              padding: EdgeInsets.zero,
            ),
            child: _buildChild(context, translatedText),
          ),
        ),
      );
    }

    final bgColor = widget.backgroundColor ?? AppTheme.primaryColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onPressed != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: AnimatedContainer(
        duration: AppTheme.animFast,
        width: widget.width ?? double.infinity,
        height: widget.height,
        decoration: BoxDecoration(
          gradient: widget.useGradient || !widget.isLoading
              ? LinearGradient(
                  colors: [
                    bgColor,
                    Color.lerp(bgColor, Colors.black, 0.15) ?? bgColor,
                  ],
                )
              : null,
          color: widget.useGradient ? null : bgColor,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: _isHovered && !widget.isLoading
              ? [
                  BoxShadow(
                    color: bgColor.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: bgColor.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: ElevatedButton(
          onPressed: widget.isLoading ? null : widget.onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: widget.textColor ?? Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
            padding: EdgeInsets.zero,
            elevation: 0,
          ),
          child: _buildChild(context, translatedText),
        ),
      ),
    );
  }

  Widget _buildChild(BuildContext context, String translatedText) {
    if (widget.isLoading) {
      return const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    if (widget.icon != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(widget.icon, size: 20),
          const SizedBox(width: 10),
          Text(
            translatedText,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      );
    }

    return Text(
      translatedText,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    );
  }
}
