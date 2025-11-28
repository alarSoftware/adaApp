import 'package:flutter/material.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/services/battery_optimization/battery_optimization_service.dart';

class BatteryOptimizationDialog {

  /// Muestra el diálogo principal de optimización de batería
  static Future<bool?> showBatteryOptimizationDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // No se puede cerrar tocando fuera
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.battery_alert,
                color: AppColors.warning,
                size: 28,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Optimización de Batería',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Para que la aplicación funcione correctamente, es necesario deshabilitar la optimización de batería.',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: AppColors.error, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Sin esta configuración, la app no funcionará correctamente.',
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.info.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: AppColors.info, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Esto permite que la app:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.info,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Padding(
                        padding: EdgeInsets.only(left: 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('• Sincronice datos automáticamente', style: _benefitTextStyle()),
                            Text('• Mantenga la conectividad activa', style: _benefitTextStyle()),
                            Text('• Registre actividad del dispositivo', style: _benefitTextStyle()),
                            Text('• Funcione correctamente en background', style: _benefitTextStyle()),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: AppColors.warning, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Sin esto, la app puede cerrarse inesperadamente y perder datos.',
                          style: TextStyle(
                            color: AppColors.warning,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: Icon(Icons.settings),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              label: Text('Configurar Ahora'),
            ),
          ],
        );
      },
    );
  }

  /// Muestra un diálogo de confirmación después de configurar
  static Future<void> showSuccessDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: 28,
              ),
              SizedBox(width: 12),
              Text(
                '¡Configurado!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          content: Text(
            'AdaApp ahora puede funcionar correctamente en segundo plano.',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: AppColors.onPrimary,
              ),
              child: Text('Entendido'),
            ),
          ],
        );
      },
    );
  }

  /// Muestra diálogo cuando el usuario rechaza o no puede configurar
  static Future<void> showWarningDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning,
                color: AppColors.warning,
                size: 28,
              ),
              SizedBox(width: 12),
              Text(
                'Configuración Pendiente',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'La optimización de batería sigue activa. Esto puede afectar el funcionamiento de la app.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Puedes configurarlo más tarde desde el menú de configuración.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Entendido',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _handleBatteryOptimizationRequest(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: AppColors.onPrimary,
              ),
              child: Text('Configurar Ahora'),
            ),
          ],
        );
      },
    );
  }

  /// Maneja la solicitud de optimización de batería
  static Future<void> _handleBatteryOptimizationRequest(BuildContext context) async {
    try {
      final bool result = await BatteryOptimizationService.requestIgnoreBatteryOptimizations();

      if (result) {
        await showSuccessDialog(context);
      } else {
        await showWarningDialog(context);
      }
    } catch (e) {
      // Mostrar error genérico
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error configurando optimización de batería'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  /// Función principal que maneja todo el flujo - PERSISTENTE
  static Future<void> checkAndRequestBatteryOptimization(BuildContext context) async {
    try {
      bool isConfigured = false;
      int attempts = 0;
      const maxAttempts = 3; // Máximo 3 intentos antes de continuar

      while (!isConfigured && attempts < maxAttempts) {
        attempts++;

        // Verificar si ya está configurado
        final bool isIgnoring = await BatteryOptimizationService.isIgnoringBatteryOptimizations();

        if (isIgnoring) {
          isConfigured = true;
          return; // ✅ Ya está configurado
        }

        // Mostrar diálogo explicativo
        await showBatteryOptimizationDialog(context);

        // Intentar configurar
        final bool result = await BatteryOptimizationService.requestIgnoreBatteryOptimizations();

        if (result) {
          isConfigured = true;
          await showSuccessDialog(context);
        } else {
          // Si falla, mostrar advertencia y dar opción de reintentar
          if (attempts < maxAttempts) {
            final bool? retry = await _showRetryDialog(context, attempts, maxAttempts);
            if (retry != true) {
              // Usuario decidió no reintentar
              break;
            }
          }
        }
      }

      // Si no se pudo configurar después de varios intentos
      if (!isConfigured) {
        await _showFinalWarningDialog(context);
      }

    } catch (e) {
      print('Error configurando optimización de batería: $e');
      // Continuar con la app aunque falle la configuración
    }
  }

  /// Diálogo para reintentar configuración
  static Future<bool?> _showRetryDialog(BuildContext context, int attempt, int maxAttempts) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.refresh, color: AppColors.warning, size: 28),
              SizedBox(width: 12),
              Text(
                'Configuración Pendiente',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'La optimización de batería no se ha deshabilitado todavía.',
                style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
              ),
              SizedBox(height: 16),
              Text(
                'Intento $attempt de $maxAttempts',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
            ],
          ),
          actions: [
            if (attempt >= maxAttempts - 1)
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Continuar Sin Configurar', style: TextStyle(color: AppColors.error)),
              ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
              ),
              child: Text('Reintentar'),
            ),
          ],
        );
      },
    );
  }

  /// Diálogo final de advertencia
  static Future<void> _showFinalWarningDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning_amber, color: AppColors.error, size: 28),
              SizedBox(width: 12),
              Text(
                '⚠️ Configuración Incompleta',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'La app funcionará con limitaciones:',
                style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• Sincronización puede fallar', style: _warningTextStyle()),
                    Text('• Datos pueden perderse', style: _warningTextStyle()),
                    Text('• Funcionalidad reducida', style: _warningTextStyle()),
                  ],
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Puedes configurarlo más tarde desde Configuración → Batería.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.onPrimary,
              ),
              child: Text('Continuar Anyway'),
            ),
          ],
        );
      },
    );
  }

  static TextStyle _warningTextStyle() => TextStyle(
    color: AppColors.error,
    fontSize: 13,
    height: 1.3,
  );

  static TextStyle _benefitTextStyle() => TextStyle(
    color: AppColors.info,
    fontSize: 13,
    height: 1.3,
  );
}