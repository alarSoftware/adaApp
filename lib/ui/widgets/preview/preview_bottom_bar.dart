import 'package:flutter/material.dart';
import 'package:ada_app/ui/theme/colors.dart';

class PreviewBottomBar extends StatelessWidget {
  final bool esHistorial;
  final bool isSaving;
  final bool isConfirming; // NEW: Track when confirmation is in progress
  final String? statusMessage;
  final int cantidadImagenes;
  final VoidCallback? onVolver;
  final VoidCallback? onConfirmar;
  final VoidCallback? onReintentarEnvio; // NUEVO

  const PreviewBottomBar({
    super.key,
    required this.esHistorial,
    required this.isSaving,
    this.isConfirming = false, // NEW: Default to false
    this.statusMessage,
    required this.cantidadImagenes,
    this.onVolver,
    this.onConfirmar,
    this.onReintentarEnvio, // NUEVO
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowLight,
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: esHistorial
            ? _buildHistorialButtons(context)
            : _buildNormalButtons(context),
      ),
    );
  }

  Widget _buildHistorialButtons(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // BOTÓN DE REINTENTAR (si está disponible)
        if (onReintentarEnvio != null) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onReintentarEnvio,
              icon: const Icon(Icons.sync, size: 20),
              label: const Text('Reintentar Envío'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        // BOTÓN DE VOLVER
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: onVolver,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.arrow_back, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Volver al Historial',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNormalButtons(BuildContext context) {
    String textoBoton = 'Confirmar';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (statusMessage != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.infoContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: AppColors.info, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusMessage!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: (isSaving || isConfirming) ? null : onVolver,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Volver a Editar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: isSaving ? null : onConfirmar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: AppColors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: isSaving
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: AppColors.onPrimary,
                              strokeWidth: 2,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Flexible(
                            child: Text(
                              'Registrando...',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle, size: 20),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              textoBoton,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
