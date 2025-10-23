import 'package:flutter/material.dart';
import 'package:ada_app/ui/theme/colors.dart';

class AppNotification {
  static void show(
      BuildContext context, {
        required String message,
        NotificationType type = NotificationType.info,
        Duration duration = const Duration(seconds: 3),
        String? action,
        VoidCallback? onAction,
      }) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _MinimalNotificationWidget(
        message: message,
        type: type,
        duration: duration,
        action: action,
        onAction: onAction,
        onDismiss: () => overlayEntry.remove(),
      ),
    );

    overlay.insert(overlayEntry);
  }
}

class _MinimalNotificationWidget extends StatefulWidget {
  final String message;
  final NotificationType type;
  final Duration duration;
  final String? action;
  final VoidCallback? onAction;
  final VoidCallback onDismiss;

  const _MinimalNotificationWidget({
    required this.message,
    required this.type,
    required this.duration,
    this.action,
    this.onAction,
    required this.onDismiss,
  });

  @override
  State<_MinimalNotificationWidget> createState() =>
      _MinimalNotificationWidgetState();
}

class _MinimalNotificationWidgetState
    extends State<_MinimalNotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();

    Future.delayed(widget.duration, () {
      if (mounted) _dismiss();
    });
  }

  void _dismiss() {
    _controller.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = _getConfig(widget.type);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Material(
              color: Colors.transparent,
              child: GestureDetector(
                onTap: _dismiss,
                onVerticalDragEnd: (details) {
                  if (details.primaryVelocity! < -300) _dismiss();
                },
                child: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: config.isDark
                        ? const Color(0xFF1C1C1E)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: config.isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.08),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Dot indicator minimalista
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: config.color,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: config.color.withOpacity(0.4),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Mensaje
                      Expanded(
                        child: Text(
                          widget.message,
                          style: TextStyle(
                            color: config.isDark
                                ? Colors.white
                                : const Color(0xFF1C1C1E),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      // Acción opcional
                      if (widget.action != null) ...[
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () {
                            widget.onAction?.call();
                            _dismiss();
                          },
                          child: Text(
                            widget.action!,
                            style: TextStyle(
                              color: config.color,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  _MinimalConfig _getConfig(NotificationType type) {
    switch (type) {
      case NotificationType.success:
        return _MinimalConfig(
          color: AppColors.success,
          isDark: false,
        );
      case NotificationType.error:
        return _MinimalConfig(
          color: AppColors.error,
          isDark: false,
        );
      case NotificationType.warning:
        return _MinimalConfig(
          color: AppColors.warning,
          isDark: false,
        );
      case NotificationType.info:
        return _MinimalConfig(
          color: AppColors.info,
          isDark: false,
        );
    }
  }
}

class _MinimalConfig {
  final Color color;
  final bool isDark;

  _MinimalConfig({
    required this.color,
    required this.isDark,
  });
}

// Reutilizar el enum existente
enum NotificationType {
  success,
  error,
  warning,
  info,
}