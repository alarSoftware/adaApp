// lib/services/device_log/device_log_upload_service.dart

import 'dart:async';
import 'package:logger/logger.dart';
import 'package:sqflite/sqflite.dart';
import 'package:ada_app/repositories/device_log_repository.dart';
import 'package:ada_app/services/post/device_log_post_service.dart';
import 'package:ada_app/services/database_helper.dart';
import 'package:ada_app/models/device_log.dart';

class DeviceLogUploadService {
  final Logger _logger = Logger();

  // Variables para sincronización automática
  static Timer? _syncTimer;
  static bool _syncActivo = false;

  /// Sincroniza todos los device logs pendientes (SOLO UPLOAD)
  static Future<Map<String, int>> sincronizarDeviceLogsPendientes() async {
    final logger = Logger();

    try {
      logger.i('🔄 Sincronización de device logs pendientes...');

      // Obtener BD y repositorio
      final db = await DatabaseHelper().database;
      final repository = DeviceLogRepository(db);

      // Obtener logs no sincronizados
      final logsPendientes = await repository.obtenerNoSincronizados();

      if (logsPendientes.isEmpty) {
        logger.i('✅ No hay device logs pendientes');
        return {'exitosos': 0, 'fallidos': 0, 'total': 0};
      }

      logger.i('📋 Total a sincronizar: ${logsPendientes.length}');

      int exitosos = 0;
      int fallidos = 0;

      // Enviar cada log al servidor
      for (final log in logsPendientes) {
        try {
          final resultado = await DeviceLogPostService.enviarDeviceLog(log);

          if (resultado['exito'] == true) {
            await repository.marcarComoSincronizado(log.id);
            exitosos++;
            logger.i('✅ Device log ${log.id} enviado');
          } else {
            fallidos++;
            logger.w('⚠️ Error enviando ${log.id}: ${resultado['mensaje']}');
          }
        } catch (e) {
          logger.e('❌ Error enviando ${log.id}: $e');
          fallidos++;
        }
      }

      logger.i('✅ Completado - Exitosos: $exitosos, Fallidos: $fallidos');

      return {
        'exitosos': exitosos,
        'fallidos': fallidos,
        'total': logsPendientes.length,
      };
    } catch (e) {
      logger.e('💥 Error en sincronización: $e');
      return {'exitosos': 0, 'fallidos': 0, 'total': 0};
    }
  }

  /// Enviar múltiples device logs en batch
  static Future<Map<String, int>> enviarDeviceLogsBatch(List<DeviceLog> logs) async {
    final logger = Logger();

    try {
      logger.i('📤 Enviando batch de ${logs.length} device logs...');

      final resultado = await DeviceLogPostService.enviarDeviceLogsBatch(logs);

      // Marcar exitosos como sincronizados
      if (resultado['exitosos']! > 0) {
        final db = await DatabaseHelper().database;
        final repository = DeviceLogRepository(db);

        for (final log in logs) {
          try {
            await repository.marcarComoSincronizado(log.id);
          } catch (e) {
            logger.w('⚠️ Error marcando ${log.id} como sincronizado: $e');
          }
        }
      }

      return resultado;
    } catch (e) {
      logger.e('❌ Error en batch: $e');
      return {
        'exitosos': 0,
        'fallidos': logs.length,
        'total': logs.length,
      };
    }
  }

  /// Limpiar logs antiguos ya sincronizados
  static Future<int> limpiarLogsSincronizadosAntiguos({int diasAntiguos = 7}) async {
    final logger = Logger();

    try {
      logger.i('🧹 Limpiando device logs sincronizados antiguos...');

      final db = await DatabaseHelper().database;
      final repository = DeviceLogRepository(db);

      final eliminados = await repository.eliminarSincronizadosAntiguos(
        diasAntiguos: diasAntiguos,
      );

      logger.i('✅ Eliminados $eliminados logs antiguos');
      return eliminados;
    } catch (e) {
      logger.e('❌ Error limpiando logs: $e');
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
      Logger().e('❌ Error obteniendo estadísticas: $e');
      return {
        'total': 0,
        'sincronizados': 0,
        'pendientes': 0,
      };
    }
  }

  // ==================== SINCRONIZACIÓN AUTOMÁTICA ====================

  static void iniciarSincronizacionAutomatica() {
    if (_syncActivo) {
      Logger().i('⚠️ Sincronización de device logs ya está activa');
      return;
    }

    _syncActivo = true;

    Logger().i('🚀 Iniciando sincronización automática de device logs cada 10 minutos...');

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
      Logger().i('⏹️ Sincronización automática de device logs detenida');
    }
  }

  static Future<void> _ejecutarSincronizacionAutomatica() async {
    if (!_syncActivo) return;

    try {
      final logger = Logger();
      logger.i('🔄 Ejecutando sincronización automática de device logs...');

      final resultado = await sincronizarDeviceLogsPendientes();

      if (resultado['total']! > 0) {
        logger.i('✅ Auto-sync device logs: ${resultado['exitosos']}/${resultado['total']}');
      }
    } catch (e) {
      Logger().e('❌ Error en auto-sync device logs: $e');
    }
  }

  static bool get esSincronizacionActiva => _syncActivo;

  static Future<Map<String, int>?> forzarSincronizacion() async {
    if (!_syncActivo) {
      Logger().w('⚠️ No se puede forzar sincronización de device logs');
      return null;
    }

    Logger().i('⚡ Forzando sincronización de device logs...');
    return await sincronizarDeviceLogsPendientes();
  }
}