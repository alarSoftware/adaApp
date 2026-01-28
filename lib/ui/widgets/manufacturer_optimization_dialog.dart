import 'package:flutter/material.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/services/battery_optimization/battery_optimization_service.dart';

class ManufacturerOptimizationDialog extends StatelessWidget {
  final String manufacturer;
  final VoidCallback onConfigured;

  const ManufacturerOptimizationDialog({
    super.key,
    required this.manufacturer,
    required this.onConfigured,
  });

  static Future<void> show(BuildContext context, String manufacturer) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ManufacturerOptimizationDialog(
        manufacturer: manufacturer,
        onConfigured: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: _buildHeader(),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildManufacturerWarning(),
            const SizedBox(height: 20),
            Text(
              'Sigue estos pasos para asegurar que AdaApp funcione correctamente:',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ..._buildInstructions(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Lo haré luego',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        FilledButton.icon(
          onPressed: () async {
            await BatteryOptimizationService.openBatteryOptimizationSettings();
            onConfigured();
          },
          icon: const Icon(Icons.settings, size: 18),
          label: const Text('Ir a Ajustes'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.warning_amber_rounded,
            color: AppColors.warning,
            size: 28,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ajuste Requerido',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                manufacturer,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildManufacturerWarning() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Text(
        'Los dispositivos $manufacturer tienen una gestión de energía muy agresiva que cierra aplicaciones en segundo plano automáticamente.',
        style: TextStyle(fontSize: 13, color: AppColors.error, height: 1.4),
      ),
    );
  }

  List<Widget> _buildInstructions() {
    final String m = manufacturer.toUpperCase();
    if (m.contains('HONOR') || m.contains('HUAWEI')) {
      return [
        _buildStep(1, 'Abre los Ajustes del dispositivo.'),
        _buildStep(2, 'Ve a Aplicaciones -> Inicio de aplicaciones.'),
        _buildStep(
          3,
          'Busca "AdaApp" y desactiva "Gestionar automáticamente".',
        ),
        _buildStep(
          4,
          'Asegúrate que "Inicio automático", "Inicio secundario" y "Ejecutar en segundo plano" estén ACTIVOS.',
        ),
      ];
    } else if (m.contains('XIAOMI') ||
        m.contains('REDMI') ||
        m.contains('POCO')) {
      return [
        _buildStep(1, 'Abre Ajustes -> Aplicaciones -> Permisos.'),
        _buildStep(2, 'Selecciona "Inicio automático" y activa AdaApp.'),
        _buildStep(3, 'Vuelve a Ajustes de batería -> AdaApp.'),
        _buildStep(
          4,
          'Selecciona "Sin restricciones" en el modo de ahorro de batería.',
        ),
      ];
    } else if (m.contains('SAMSUNG')) {
      return [
        _buildStep(1, 'Abre Ajustes -> Aplicaciones.'),
        _buildStep(2, 'Busca AdaApp -> Batería.'),
        _buildStep(3, 'Selecciona la opción "No restringida".'),
      ];
    } else {
      return [
        _buildStep(1, 'Abre Ajustes de batería.'),
        _buildStep(2, 'Busca AdaApp.'),
        _buildStep(
          3,
          'Desactiva cualquier optimización de batería o restricción de segundo plano.',
        ),
      ];
    }
  }

  Widget _buildStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
