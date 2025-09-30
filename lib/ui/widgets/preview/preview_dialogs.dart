import 'package:flutter/material.dart';
import 'package:ada_app/ui/theme/colors.dart';

class PreviewDialogs {
  static Future<bool?> mostrarConfirmacion(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Confirmar Censo'),
        content: const Text(
          '¿Está seguro que desea confirmar este censo?\n\n'
              'Esta acción guardará el registro definitivamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  static void mostrarProcesoEnCurso(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Proceso en curso'),
        content: const Text(
          'Hay un proceso de guardado en curso.\n\n'
              'Por favor espere a que termine antes de continuar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  static Future<void> mostrarErrorConReintentar(
      BuildContext context,
      String error,
      VoidCallback onReintentar,
      ) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: AppColors.warning, size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Error en Confirmación',
                style: TextStyle(fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hubo un problema al procesar el registro:',
              style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            Text(
              error,
              style: TextStyle(fontSize: 14, color: AppColors.error),
              overflow: TextOverflow.visible,
              softWrap: true,
            ),
            const SizedBox(height: 16),
            _buildInfoContainer(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              onReintentar();
            },
            icon: const Icon(Icons.refresh, size: 20),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildInfoContainer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.infoContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info, color: AppColors.info, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Datos Protegidos',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Sus datos están guardados localmente y no se perderán. '
                'Puede reintentar el envío ahora o se sincronizarán '
                'automáticamente más tarde.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            overflow: TextOverflow.visible,
            softWrap: true,
          ),
        ],
      ),
    );
  }
}