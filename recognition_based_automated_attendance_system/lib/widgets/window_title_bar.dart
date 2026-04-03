import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../config/app_theme.dart';
import '../providers/language_provider.dart';

/// Custom Windows title bar with drag-to-move and window controls
class WindowTitleBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;

  const WindowTitleBar({super.key, this.title});

  @override
  Size get preferredSize => const Size.fromHeight(38);

  @override
  Widget build(BuildContext context) {
    final resolvedTitle =
        title ?? context.watch<LanguageProvider>().tr('appTitle');

    return Container(
      height: 38,
      decoration: const BoxDecoration(
        color: AppTheme.bgDeep,
        border: Border(
          bottom: BorderSide(color: AppTheme.glassBorder, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // ─── App Icon + Title (draggable) ────────
          Expanded(
            child: GestureDetector(
              onPanStart: (_) => windowManager.startDragging(),
              onDoubleTap: () async {
                final isMaximized = await windowManager.isMaximized();
                if (isMaximized) {
                  windowManager.unmaximize();
                } else {
                  windowManager.maximize();
                }
              },
              child: Container(
                color: Colors.transparent,
                padding: const EdgeInsets.only(left: 14),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Icon(
                        Icons.face_retouching_natural,
                        color: Colors.white,
                        size: 13,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      resolvedTitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ─── Window Controls ──────────────────────
          _WindowButton(
            icon: Icons.remove_rounded,
            onTap: () => windowManager.minimize(),
            hoverColor: AppTheme.bgElevated,
          ),
          _WindowButton(
            icon: Icons.crop_square_rounded,
            iconSize: 14,
            onTap: () async {
              final isMaximized = await windowManager.isMaximized();
              if (isMaximized) {
                windowManager.unmaximize();
              } else {
                windowManager.maximize();
              }
            },
            hoverColor: AppTheme.bgElevated,
          ),
          _WindowButton(
            icon: Icons.close_rounded,
            onTap: () => windowManager.close(),
            hoverColor: AppTheme.errorColor,
            hoverIconColor: Colors.white,
          ),
        ],
      ),
    );
  }
}

class _WindowButton extends StatefulWidget {
  final IconData icon;
  final double iconSize;
  final VoidCallback onTap;
  final Color hoverColor;
  final Color? hoverIconColor;

  const _WindowButton({
    required this.icon,
    this.iconSize = 16,
    required this.onTap,
    required this.hoverColor,
    this.hoverIconColor,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppTheme.animFast,
          width: 46,
          height: 38,
          color: _isHovered ? widget.hoverColor : Colors.transparent,
          child: Center(
            child: Icon(
              widget.icon,
              size: widget.iconSize,
              color: _isHovered
                  ? (widget.hoverIconColor ?? AppTheme.textPrimary)
                  : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
