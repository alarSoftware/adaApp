import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:logger/logger.dart';

var logger = Logger();

class BatteryOptimizationService {
  static const MethodChannel _channel = MethodChannel('battery_optimization');

  /// Verifica si la app está en la whitelist de optimización de batería
  static Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      final bool result = await _channel.invokeMethod('isIgnoringBatteryOptimizations');
      logger.i('¿App ignora optimización de batería?: $result');
      return result;
    } catch (e) {
      logger.e('Error verificando optimización de batería: $e');
      return false;
    }
  }

  /// Solicita al usuario que deshabilite la optimización de batería
  static Future<bool> requestIgnoreBatteryOptimizations() async {
    try {
      // Primero verificar si ya está deshabilitada
      final bool isAlreadyIgnoring = await isIgnoringBatteryOptimizations();
      if (isAlreadyIgnoring) {
        logger.i('La app ya ignora la optimización de batería');
        return true;
      }

      // Solicitar al usuario que la deshabilite
      logger.i('Solicitando deshabilitar optimización de batería...');
      final bool result = await _channel.invokeMethod('requestIgnoreBatteryOptimizations');

      if (result) {
        logger.i('Usuario aceptó deshabilitar optimización de batería');
      } else {
        logger.w(' Usuario rechazó deshabilitar optimización de batería');
      }

      return result;
    } catch (e) {
      logger.e('Error solicitando deshabilitar optimización de batería: $e');
      return false;
    }
  }

  /// Abre directamente la configuración de optimización de batería
  static Future<bool> openBatteryOptimizationSettings() async {
    try {
      logger.i('Abriendo configuración de optimización de batería...');
      final bool result = await _channel.invokeMethod('openBatteryOptimizationSettings');
      return result;
    } catch (e) {
      logger.e('Error abriendo configuración de optimización: $e');
      return false;
    }
  }

  /// Verifica y solicita permisos relacionados con background
  static Future<bool> checkAndRequestBackgroundPermissions() async {
    try {
      logger.i('Verificando permisos de background...');

      // Lista de permisos a verificar
      Map<Permission, PermissionStatus> permissions = await [
        Permission.ignoreBatteryOptimizations,
        Permission.systemAlertWindow, // Para mostrar notificaciones sobre otras apps
      ].request();

      bool allGranted = true;
      permissions.forEach((permission, status) {
        logger.i('Permiso $permission: $status');
        if (status != PermissionStatus.granted) {
          allGranted = false;
        }
      });

      return allGranted;
    } catch (e) {
      logger.e('Error verificando permisos de background: $e');
      return false;
    }
  }
}

/// Resultado de la verificación de optimización de batería
class BatteryOptimizationResult {
  final bool isOptimized;
  final bool shouldRequest;
  final String message;

  BatteryOptimizationResult({
    required this.isOptimized,
    required this.shouldRequest,
    required this.message,
  });

  static BatteryOptimizationResult optimized() => BatteryOptimizationResult(
    isOptimized: true,
    shouldRequest: true,
    message: 'La app está siendo optimizada por Android. Esto puede afectar la sincronización en background.',
  );

  static BatteryOptimizationResult notOptimized() => BatteryOptimizationResult(
    isOptimized: false,
    shouldRequest: false,
    message: 'La app está configurada correctamente para funcionar en background.',
  );

  static BatteryOptimizationResult error(String errorMessage) => BatteryOptimizationResult(
    isOptimized: true, // Assumir que está optimizada por seguridad
    shouldRequest: true,
    message: 'No se pudo verificar la configuración: $errorMessage',
  );
}