import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class BatteryOptimizationService {
  static const MethodChannel _channel = MethodChannel('battery_optimization');

  /// Verifica si la app está en la whitelist de optimización de batería
  static Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      final bool result = await _channel.invokeMethod(
        'isIgnoringBatteryOptimizations',
      );
      debugPrint('¿App ignora optimización de batería?: $result');
      return result;
    } catch (e) {
      debugPrint('Error verificando optimización de batería: $e');
      return false;
    }
  }

  /// Solicita al usuario que deshabilite la optimización de batería
  static Future<bool> requestIgnoreBatteryOptimizations() async {
    try {
      // Primero verificar si ya está deshabilitada
      final bool isAlreadyIgnoring = await isIgnoringBatteryOptimizations();
      if (isAlreadyIgnoring) {
        debugPrint('La app ya ignora la optimización de batería');
        return true;
      }

      // Solicitar al usuario que la deshabilite
      debugPrint('Solicitando deshabilitar optimización de batería...');
      final bool result = await _channel.invokeMethod(
        'requestIgnoreBatteryOptimizations',
      );

      if (result) {
        debugPrint('Usuario aceptó deshabilitar optimización de batería');
      } else {
        debugPrint(' Usuario rechazó deshabilitar optimización de batería');
      }

      return result;
    } catch (e) {
      debugPrint('Error solicitando deshabilitar optimización de batería: $e');
      return false;
    }
  }

  /// Abre directamente la configuración de optimización de batería
  static Future<bool> openBatteryOptimizationSettings() async {
    try {
      debugPrint('Abriendo configuración de optimización de batería...');
      final bool result = await _channel.invokeMethod(
        'openBatteryOptimizationSettings',
      );
      return result;
    } catch (e) {
      debugPrint('Error abriendo configuración de optimización: $e');
      return false;
    }
  }

  /// Verifica y solicita permisos relacionados con background
  static Future<bool> checkAndRequestBackgroundPermissions() async {
    try {
      debugPrint('Verificando permisos de background...');

      // Lista de permisos a verificar
      Map<Permission, PermissionStatus> permissions = await [
        Permission.ignoreBatteryOptimizations,
        Permission
            .systemAlertWindow, // Para mostrar notificaciones sobre otras apps
      ].request();

      bool allGranted = true;
      permissions.forEach((permission, status) {
        debugPrint('Permiso $permission: $status');
        if (status != PermissionStatus.granted) {
          allGranted = false;
        }
      });

      return allGranted;
    } catch (e) {
      debugPrint('Error verificando permisos de background: $e');
      return false;
    }
  }

  /// Obtiene el fabricante del dispositivo
  static Future<String> getDeviceManufacturer() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.manufacturer.toUpperCase();
    } catch (e) {
      debugPrint('Error obteniendo fabricante: $e');
      return 'UNKNOWN';
    }
  }

  /// Verifica si el fabricante es conocido por tener gestión de energía agresiva
  static bool isAggressiveManufacturer(String manufacturer) {
    final aggressiveBrands = [
      'HONOR',
      'XIAOMI',
      'HUAWEI',
      'REALME',
      'OPPO',
      'VIVO',
      'SAMSUNG',
    ];
    return aggressiveBrands.contains(manufacturer.toUpperCase());
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
    message:
        'La app está siendo optimizada por Android. Esto puede afectar la sincronización en background.',
  );

  static BatteryOptimizationResult notOptimized() => BatteryOptimizationResult(
    isOptimized: false,
    shouldRequest: false,
    message:
        'La app está configurada correctamente para funcionar en background.',
  );

  static BatteryOptimizationResult error(String errorMessage) =>
      BatteryOptimizationResult(
        isOptimized: true, // Assumir que está optimizada por seguridad
        shouldRequest: true,
        message: 'No se pudo verificar la configuración: $errorMessage',
      );
}
