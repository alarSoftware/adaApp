import 'package:flutter/material.dart';
import 'package:ada_app/ui/theme/colors.dart';

class ExitConfirmationDialog {
  static Future<bool?> show({
    required BuildContext context,
    required double progress,
    Future<void> Function()? onSave,
    String? title,
    String? message,
    String? exitButtonText,
    String? saveButtonText,
  }) async {
    // Si no hay progreso, permitir salir sin mostrar diálogo
    if (progress == 0) return true;

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false, // No cerrar al tocar fuera
      builder: (context) => _ExitConfirmationDialogContent(
        progress: progress,
        onSave: onSave,
        title: title,
        message: message,
        exitButtonText: exitButtonText,
        saveButtonText: saveButtonText,
      ),
    );
  }
}

class _ExitConfirmationDialogContent extends StatefulWidget {
  final double progress;
  final Future<void> Function()? onSave;
  final String? title;
  final String? message;
  final String? exitButtonText;
  final String? saveButtonText;

  const _ExitConfirmationDialogContent({
    required this.progress,
    this.onSave,
    this.title,
    this.message,
    this.exitButtonText,
    this.saveButtonText,
  });

  @override
  State<_ExitConfirmationDialogContent> createState() =>
      _ExitConfirmationDialogContentState();
}

class _ExitConfirmationDialogContentState
    extends State<_ExitConfirmationDialogContent> {
  bool _isSaving = false;

  Future<void> _handleSave() async {
    if (widget.onSave == null) {
      Navigator.pop(context, true);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.onSave!();
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        // Mostrar error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final progressPercent = (widget.progress * 100).toInt();

    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: AppColors.warning,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.title ?? '¿Salir sin guardar?',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.message ??
                'Tienes cambios sin guardar. ¿Deseas guardar el progreso antes de salir?',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          // Indicador de progreso
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: widget.progress,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$progressPercent%',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        // Botón: Salir sin guardar
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, true),
          child: Text(
            widget.exitButtonText ?? 'Salir sin guardar',
            style: TextStyle(
              color: _isSaving ? AppColors.textSecondary : AppColors.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Botón: Guardar progreso
        if (widget.onSave != null)
          ElevatedButton(
            onPressed: _isSaving ? null : _handleSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              elevation: 2,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isSaving
                ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.onPrimary,
                ),
              ),
            )
                : Text(
              widget.saveButtonText ?? 'Guardar progreso',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}