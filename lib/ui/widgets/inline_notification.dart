// ui/widgets/inline_notification.dart
import 'package:flutter/material.dart';
import 'package:ada_app/ui/theme/colors.dart';

enum InlineNotificationType { success, error, warning, info }

class InlineNotification extends StatelessWidget {
  final String message;
  final InlineNotificationType type;
  final bool visible;
  final VoidCallback? onDismiss;

  const InlineNotification({
    super.key,
    required this.message,
    required this.type,
    this.visible = true,
    this.onDismiss,
  });

  Color _getBackgroundColor() {
    switch (type) {
      case InlineNotificationType.success:
        return AppColors.success.withValues(alpha: 0.1);
      case InlineNotificationType.error:
        return AppColors.error.withValues(alpha: 0.1);
      case InlineNotificationType.warning:
        return AppColors.warning.withValues(alpha: 0.1);
      case InlineNotificationType.info:
        return AppColors.info.withValues(alpha: 0.1);
    }
  }

  Color _getBorderColor() {
    switch (type) {
      case InlineNotificationType.success:
        return AppColors.success;
      case InlineNotificationType.error:
        return AppColors.error;
      case InlineNotificationType.warning:
        return AppColors.warning;
      case InlineNotificationType.info:
        return AppColors.info;
    }
  }

  Color _getIconColor() {
    return _getBorderColor();
  }

  IconData _getIcon() {
    switch (type) {
      case InlineNotificationType.success:
        return Icons.check_circle_outline;
      case InlineNotificationType.error:
        return Icons.error_outline;
      case InlineNotificationType.warning:
        return Icons.warning_amber_rounded;
      case InlineNotificationType.info:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: visible
            ? Container(
                margin: const EdgeInsets.only(top: 8, bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _getBackgroundColor(),
                  border: Border.all(color: _getBorderColor(), width: 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_getIcon(), color: _getIconColor(), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        message,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                    if (onDismiss != null) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: onDismiss,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
