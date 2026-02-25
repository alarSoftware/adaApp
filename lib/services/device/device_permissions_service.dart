import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class DevicePermissionsService {
  /// Retorna TRUE si se tienen los permisos necesarios
  /// Retorna FALSE si el usuario rechazó explícitamente el permiso de NOTIFICACIONES
  static Future<bool> checkAndRequestCriticalPermissions() async {
    try {
      // 1. Notificaciones (Android 13+) - CRITICO PARA BACKGROUND
      var notifStatus = await Permission.notification.status;
      debugPrint('DEBUG PERMISOS: Status inicial Notificaciones: $notifStatus');

      if (notifStatus.isDenied) {
        debugPrint('DEBUG PERMISOS: Solicitando permiso...');
        notifStatus = await Permission.notification.request();
        debugPrint('DEBUG PERMISOS: Status post-request: $notifStatus');
      }

      // Si despues de pedirlo sigue denegado o esta permanentemente denegado: BLOQUEAR
      if (notifStatus.isDenied || notifStatus.isPermanentlyDenied) {
        debugPrint('DEBUG PERMISOS: Acceso DENEGADO (Bloqueando login)');
        return false;
      }

      debugPrint('DEBUG PERMISOS: Notificaciones OK');

      // 2. Ubicación
      var locStatus = await Permission.location.status;
      if (!locStatus.isGranted) {
        locStatus = await Permission.location.request();
      }

      // Si se concedió ubicación básica, intentar 'locationAlways' para background
      if (locStatus.isGranted) {
        if (await Permission.locationAlways.isDenied) {
          await Permission.locationAlways.request();
        }
      }

      // 3. Optimización de batería
      if (await Permission.ignoreBatteryOptimizations.isDenied) {
        await Permission.ignoreBatteryOptimizations.request();
      }

      return true;
    } catch (e) {
      debugPrint('Error solicitando permisos: $e');
      return true; // En caso de error técnico, dejamos pasar para no bloquear al usuario
    }
  }
}
