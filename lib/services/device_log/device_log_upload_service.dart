import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:ada_app/repositories/device_log_repository.dart';
import 'package:ada_app/services/post/device_log_post_service.dart';
import 'package:ada_app/services/data/database_helper.dart';
import 'package:ada_app/services/api/auth_service.dart';
import 'package:ada_app/models/device_log.dart';
import 'package:ada_app/services/error_log/error_log_service.dart';
import 'package:ada_app/services/api/api_config_service.dart';
import 'package:ada_app/utils/logger.dart';

class DeviceLogUploadService {
  static Timer? _syncTimer;
  static bool _syncActivo = false;

  /// Sincroniza todos los device logs pendientes
  static Future<Map<String, int>> sincronizarDeviceLogsPendientes() async {
    try {
      AppLogger.i('Sincronización de device logs pendientes...');

      final db = await DatabaseHelper().database;
      final repository = DeviceLogRepository(db);
      final logsPendientes = await repository.obtenerNoSincronizados();

      if (logsPendientes.isEmpty) {
        AppLogger.i('No hay device logs pendientes');
        return {'exitosos': 0, 'fallidos': 0, 'total': 0};
      }

      AppLogger.i('Device logs a sincronizar: ${logsPendientes.length}');

      int exitosos = 0;
      int fallidos = 0;

      for (final log in logsPendientes) {
        try {
          // Obtener usuario actual para userId
          final currentUser = await AuthService().getCurrentUser();
          String? userIdFromAuth = currentUser?.id?.toString();

          // Fallback: Si no hay sesión activa, buscar el usuario por employeeId del log
          if (userIdFromAuth == null && log.employeeId != null) {
            userIdFromAuth = await obtenerUserIdPorEmployeeId(log.employeeId!);
          }

          // userId resuelto para envío

          // Usar el servicio unificado con logging automático
          final resultado = await DeviceLogPostService.enviarDeviceLog(
            log,
            userId: userIdFromAuth,
          );

          if (resultado['exito'] == true) {
            await repository.marcarComoSincronizado(log.id);
            exitosos++;
            AppLogger.i('Device log enviado');
          } else {
            fallidos++;
            AppLogger.e('Error enviando device log', resultado['mensaje']);
          }
        } catch (e) {
          AppLogger.e('Error enviando device log', e);
          fallidos++;
        }
      }

      AppLogger.i(
        'Sync device logs - Exitosos: $exitosos, Fallidos: $fallidos',
      );

      return {
        'exitosos': exitosos,
        'fallidos': fallidos,
        'total': logsPendientes.length,
      };
    } catch (e) {
      AppLogger.e('Error general en sync device logs', e);

      await ErrorLogService.logError(
        tableName: 'device_log',
        operation: 'sync_batch',
        errorMessage: 'Error general en sincronización: $e',
        errorType: 'sync',
      );

      return {'exitosos': 0, 'fallidos': 0, 'total': 0};
    }
  }

  /// Enviar múltiples device logs en batch
  static Future<Map<String, int>> enviarDeviceLogsBatch(
    List<DeviceLog> logs,
  ) async {
    try {
      AppLogger.i('Enviando batch de ${logs.length} device logs...');

      // Obtener userId del usuario actual (User.id)
      final currentUser = await AuthService().getCurrentUser();
      String? userId = currentUser?.id?.toString();

      // 🔄 Fallback: Si no hay sesión, buscar por el employeeId del primer log
      if (userId == null && logs.isNotEmpty && logs.first.employeeId != null) {
        userId = await obtenerUserIdPorEmployeeId(logs.first.employeeId!);
      }

      // ✅ Usar el servicio unificado
      final resultado = await DeviceLogPostService.enviarDeviceLogsBatch(
        logs,
        userId: userId, // 👈 FIX: Solo enviar si se encontró usuario válido
      );

      // 🔄 Marcar como sincronizados los exitosos
      if (resultado['exitosos']! > 0) {
        final db = await DatabaseHelper().database;
        final repository = DeviceLogRepository(db);

        int marcados = 0;
        for (final log in logs) {
          try {
            await repository.marcarComoSincronizado(log.id);
            marcados++;
          } catch (e) {
            AppLogger.e('Error marcando log como sincronizado', e);
          }
        }
        AppLogger.i('Marcados como sincronizados: $marcados');
      }

      return resultado;
    } catch (e) {
      AppLogger.e('Error en batch upload device logs', e);

      await ErrorLogService.logError(
        tableName: 'device_log',
        operation: 'batch_upload',
        errorMessage: 'Error en envío batch: $e',
        errorType: 'upload',
      );

      return {'exitosos': 0, 'fallidos': logs.length, 'total': logs.length};
    }
  }

  /// Limpiar logs antiguos ya sincronizados
  static Future<int> limpiarLogsSincronizadosAntiguos({
    int diasAntiguos = 7,
  }) async {
    try {
      AppLogger.i('Limpiando device logs antiguos (>$diasAntiguos días)...');

      final db = await DatabaseHelper().database;
      final repository = DeviceLogRepository(db);

      final eliminados = await repository.eliminarSincronizadosAntiguos(
        diasAntiguos: diasAntiguos,
      );

      AppLogger.i('Eliminados $eliminados logs antiguos');
      return eliminados;
    } catch (e) {
      AppLogger.e('Error limpiando logs antiguos', e);
      return 0;
    }
  }

  /// Obtener estadísticas de sincronización
  static Future<Map<String, int>> obtenerEstadisticasSincronizacion() async {
    try {
      final db = await DatabaseHelper().database;
      final repository = DeviceLogRepository(db);

      final stats = await repository.obtenerEstadisticas();

      return {
        'total': stats['total'] as int,
        'sincronizados': stats['sincronizados'] as int,
        'pendientes': stats['pendientes'] as int,
      };
    } catch (e) {
      AppLogger.e('Error obteniendo estadísticas', e);
      return {'total': 0, 'sincronizados': 0, 'pendientes': 0};
    }
  }

  // ==================== SINCRONIZACIÓN AUTOMÁTICA ====================

  static Future<void> iniciarSincronizacionAutomatica() async {
    if (_syncActivo) {
      AppLogger.w('Sincronización de device logs ya está activa');
      return;
    }

    _syncActivo = true;

    AppLogger.i(
      'Sincronización automática de device logs iniciada (cada 10 min)',
    );

    _syncTimer = Timer.periodic(Duration(minutes: 10), (timer) async {
      await _ejecutarSincronizacionAutomatica();
    });

    // Primera ejecución después de 1 minuto
    Timer(Duration(minutes: 1), () async {
      await _ejecutarSincronizacionAutomatica();
    });
  }

  static void detenerSincronizacionAutomatica() {
    if (_syncTimer != null) {
      _syncTimer!.cancel();
      _syncTimer = null;
      _syncActivo = false;
      AppLogger.i('Sincronización automática de device logs detenida');
    }
  }

  static Future<void> _ejecutarSincronizacionAutomatica() async {
    if (!_syncActivo) return;

    try {
      AppLogger.i('Ejecutando auto-sync device logs...');

      final resultado = await sincronizarDeviceLogsPendientes();

      if (resultado['total']! > 0) {
        AppLogger.i(
          'Auto-sync: ${resultado['exitosos']}/${resultado['total']} enviados',
        );

        final stats = await obtenerEstadisticasSincronizacion();
        AppLogger.i(
          'Estado: ${stats['sincronizados']} sync, ${stats['pendientes']} pendientes',
        );
      } else {
        AppLogger.i('No hay device logs pendientes');
      }
    } catch (e) {
      AppLogger.e('Error en auto-sync device logs', e);
    }
  }

  static bool get esSincronizacionActiva => _syncActivo;

  static Future<Map<String, int>?> forzarSincronizacion() async {
    if (!_syncActivo) {
      AppLogger.w('Sincronización automática no está activa');
      return null;
    }

    AppLogger.i('Forzando sincronización inmediata de device logs...');
    return await sincronizarDeviceLogsPendientes();
  }

  /// Verificar configuración actual del servicio
  static Future<Map<String, dynamic>> verificarConfiguracion() async {
    final baseUrl = await ApiConfigService.getBaseUrl();
    final fullUrl = await ApiConfigService.getFullUrl(
      '/appDeviceLog/insertAppDeviceLog',
    );
    final stats = await obtenerEstadisticasSincronizacion();

    return {
      'base_url': baseUrl,
      'full_url': fullUrl,
      'sync_activo': _syncActivo,
      'timer_activo': _syncTimer?.isActive ?? false,
      'estadisticas': stats,
    };
  }

  /// Método para debugging - mostrar configuración completa
  static Future<void> mostrarConfiguracion() async {
    if (!kDebugMode) return;
    final config = await verificarConfiguracion();
    final stats = config['estadisticas'] as Map<String, int>;
    AppLogger.i(
      'UploadService - Sync: ${config['sync_activo'] ? 'ACTIVO' : 'INACTIVO'}, Total: ${stats['total']}, Pendientes: ${stats['pendientes']}',
    );
  }

  /// Método de conveniencia para inicializar todo el servicio
  static Future<void> inicializar() async {
    try {
      AppLogger.i('Inicializando DeviceLogUploadService...');

      // Mostrar configuración actual
      await mostrarConfiguracion();

      // Iniciar sincronización automática
      await iniciarSincronizacionAutomatica();

      AppLogger.i('DeviceLogUploadService inicializado');
    } catch (e) {
      AppLogger.e('Error inicializando DeviceLogUploadService', e);
    }
  }

  /// 🔍 Busca el ID interno (Users.id) dado un employee_id
  static Future<String?> obtenerUserIdPorEmployeeId(String employeeId) async {
    try {
      final db = await DatabaseHelper().database;
      final result = await db.rawQuery(
        'SELECT id FROM Users WHERE employee_id = ? LIMIT 1',
        [employeeId],
      );

      if (result.isNotEmpty) {
        final id = result.first['id'];
        return id?.toString();
      } else {
        AppLogger.w('No se encontró usuario para el employeeId proporcionado');
      }
      return null;
    } catch (e) {
      AppLogger.e('Error buscando userId', e);
      return null;
    }
  }
}
