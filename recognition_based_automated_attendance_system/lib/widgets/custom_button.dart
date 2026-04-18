import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../localization/localization_extensions.dart';
import 'decorative_glint.dart';
import 'loading_widget.dart';

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
  final bool enableGlint;
  final bool enablePressAnimation;

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
    this.enableGlint = true,
    this.enablePressAnimation = true,
  });

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  bool get _isEnabled => widget.onPressed != null && !widget.isLoading;
  bool get _shouldShowGlint =>
      widget.enableGlint &&
      _isEnabled &&
      !widget.isOutlined;

  double get _scale {
    if (!widget.enablePressAnimation || !_isEnabled) {
      return 1;
    }
    return _isPressed ? 0.975 : 1;
  }

  @override
  Widget build(BuildContext context) {
    final translatedText = context.t(widget.text);
    final borderRadius = BorderRadius.circular(widget.borderRadius);

    return Listener(
      onPointerDown: _isEnabled ? (_) => setState(() => _isPressed = true) : null,
      onPointerUp: _isEnabled ? (_) => setState(() => _isPressed = false) : null,
      onPointerCancel: _isEnabled ? (_) => setState(() => _isPressed = false) : null,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: _isEnabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: AnimatedScale(
          scale: _scale,
          duration: AppTheme.animFast,
          curve: Curves.easeOutCubic,
          child: widget.isOutlined
              ? _buildOutlinedButton(translatedText, borderRadius)
              : _buildFilledButton(translatedText, borderRadius),
        ),
      ),
    );
  }

  Widget _buildOutlinedButton(String translatedText, BorderRadius borderRadius) {
    return AnimatedContainer(
      duration: AppTheme.animFast,
      width: widget.width ?? double.infinity,
      height: widget.height,
      decoration: BoxDecoration(
        color: _isHovered
            ? AppTheme.primaryColor.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: borderRadius,
        border: Border.all(
          color: widget.backgroundColor ?? AppTheme.primaryColor,
          width: 1.5,
        ),
        boxShadow: _isHovered
            ? [BoxShadow(color: AppTheme.primaryGlow, blurRadius: 12)]
            : [],
      ),
      child: OutlinedButton(
        onPressed: _isEnabled ? widget.onPressed : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: widget.textColor ?? AppTheme.primaryLight,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
          padding: EdgeInsets.zero,
        ),
        child: _buildChild(translatedText),
      ),
    );
  }

  Widget _buildFilledButton(String translatedText, BorderRadius borderRadius) {
    final bgColor = widget.backgroundColor ?? AppTheme.primaryColor;

    return AnimatedContainer(
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
        borderRadius: borderRadius,
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
      child: Stack(
        fit: StackFit.expand,
        children: [
          ElevatedButton(
            onPressed: _isEnabled ? widget.onPressed : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: widget.textColor ?? Colors.white,
              shape: RoundedRectangleBorder(borderRadius: borderRadius),
              padding: EdgeInsets.zero,
              elevation: 0,
            ),
            child: _buildChild(translatedText),
          ),
          if (_shouldShowGlint)
            DecorativeGlint(
              borderRadius: borderRadius,
              color: widget.textColor ?? Colors.white,
              intensity: 0.18,
            ),
        ],
      ),
    );
  }

  Widget _buildChild(String translatedText) {
    if (widget.isLoading) {
      return SizedBox(
        width: 22,
        height: 22,
        child: BrandedSpinner(
          size: 22,
          color: widget.textColor ?? Colors.white,
          strokeWidth: 2.5,
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
