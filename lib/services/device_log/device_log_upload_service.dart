import 'dart:async';
import 'package:logger/logger.dart';
import 'package:sqflite/sqflite.dart';
import 'package:ada_app/repositories/device_log_repository.dart';
import 'package:ada_app/services/post/device_log_post_service.dart';
import 'package:ada_app/services/database_helper.dart';
import 'package:ada_app/models/device_log.dart';
import 'package:ada_app/services/error_log/error_log_service.dart';
import 'package:ada_app/services/api_config_service.dart'; // 🆕 AGREGAR

class DeviceLogUploadService {
  final Logger _logger = Logger();

  static Timer? _syncTimer;
  static bool _syncActivo = false;

  /// Sincroniza todos los device logs pendientes
  static Future<Map<String, int>> sincronizarDeviceLogsPendientes() async {
    final logger = Logger();

    try {
      // 🔍 Mostrar configuración actual para debugging
      final urlActual = await ApiConfigService.getBaseUrl();
      logger.i('🔄 Sincronización de device logs pendientes...');
      logger.i('🌐 URL configurada: $urlActual');

      final db = await DatabaseHelper().database;
      final repository = DeviceLogRepository(db);
      final logsPendientes = await repository.obtenerNoSincronizados();

      if (logsPendientes.isEmpty) {
        logger.i('✅ No hay device logs pendientes');
        return {'exitosos': 0, 'fallidos': 0, 'total': 0};
      }

      logger.i('📋 Total a sincronizar: ${logsPendientes.length}');

      int exitosos = 0;
      int fallidos = 0;

      for (final log in logsPendientes) {
        try {
          // ✅ Usar el servicio unificado con logging automático
          final resultado = await DeviceLogPostService.enviarDeviceLog(
            log,
            userId: log.edfVendedorId,
          );

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

          // 🔥 Log adicional solo si no fue capturado por BasePostService
          await ErrorLogService.logError(
            tableName: 'device_log',
            operation: 'sync_batch',
            errorMessage: 'Error en sincronización batch: $e',
            errorType: 'upload',
            registroFailId: log.id,
            userId: log.edfVendedorId,
          );

          fallidos++;
        }
      }

      logger.i('✅ Sincronización completada - Exitosos: $exitosos, Fallidos: $fallidos');

      return {
        'exitosos': exitosos,
        'fallidos': fallidos,
        'total': logsPendientes.length,
      };
    } catch (e) {
      logger.e('💥 Error general en sincronización: $e');

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
  static Future<Map<String, int>> enviarDeviceLogsBatch(List<DeviceLog> logs) async {
    final logger = Logger();

    try {
      // 🔍 Mostrar URL para debugging
      final urlCompleta = await ApiConfigService.getFullUrl('/appDeviceLog/insertAppDeviceLog');
      logger.i('📤 Enviando batch de ${logs.length} device logs...');
      logger.i('🌐 URL destino: $urlCompleta');

      // Obtener userId del primer log (asumiendo que todos son del mismo usuario)
      final userId = logs.isNotEmpty ? logs.first.edfVendedorId : null;

      // ✅ Usar el servicio unificado
      final resultado = await DeviceLogPostService.enviarDeviceLogsBatch(
        logs,
        userId: userId,
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
            logger.w('⚠️ Error marcando ${log.id} como sincronizado: $e');
          }
        }
        logger.i('🔄 Marcados como sincronizados: $marcados');
      }

      return resultado;
    } catch (e) {
      logger.e('❌ Error en batch upload: $e');

      await ErrorLogService.logError(
        tableName: 'device_log',
        operation: 'batch_upload',
        errorMessage: 'Error en envío batch: $e',
        errorType: 'upload',
      );

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
      logger.i('🧹 Limpiando device logs sincronizados antiguos (>${diasAntiguos} días)...');

      final db = await DatabaseHelper().database;
      final repository = DeviceLogRepository(db);

      final eliminados = await repository.eliminarSincronizadosAntiguos(
        diasAntiguos: diasAntiguos,
      );

      logger.i('✅ Eliminados $eliminados logs antiguos sincronizados');
      return eliminados;
    } catch (e) {
      logger.e('❌ Error limpiando logs antiguos: $e');
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

  static Future<void> iniciarSincronizacionAutomatica() async {
    if (_syncActivo) {
      Logger().i('⚠️ Sincronización de device logs ya está activa');
      return;
    }

    _syncActivo = true;
    final urlActual = await ApiConfigService.getBaseUrl();

    Logger().i('🚀 Iniciando sincronización automática de device logs cada 10 minutos...');
    Logger().i('🌐 Sincronizando con: $urlActual');

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
        logger.i('✅ Auto-sync completado: ${resultado['exitosos']}/${resultado['total']} enviados');

        // 📊 Mostrar estadísticas después de la sincronización
        final stats = await obtenerEstadisticasSincronizacion();
        logger.i('📊 Estado actual: ${stats['sincronizados']} sync, ${stats['pendientes']} pendientes');
      } else {
        logger.i('💤 No hay device logs pendientes para sincronizar');
      }
    } catch (e) {
      Logger().e('❌ Error en auto-sync device logs: $e');
    }
  }

  static bool get esSincronizacionActiva => _syncActivo;

  static Future<Map<String, int>?> forzarSincronizacion() async {
    if (!_syncActivo) {
      Logger().w('⚠️ Sincronización automática no está activa');
      return null;
    }

    Logger().i('⚡ Forzando sincronización inmediata de device logs...');
    return await sincronizarDeviceLogsPendientes();
  }

  /// Verificar configuración actual del servicio
  static Future<Map<String, dynamic>> verificarConfiguracion() async {
    final baseUrl = await ApiConfigService.getBaseUrl();
    final fullUrl = await ApiConfigService.getFullUrl('/appDeviceLog/insertAppDeviceLog');
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
    final config = await verificarConfiguracion();
    final logger = Logger();

    logger.i("═══════════════════════════════════════");
    logger.i("🔧 CONFIGURACIÓN UPLOAD SERVICE");
    logger.i("═══════════════════════════════════════");
    logger.i("🌐 Base URL: ${config['base_url']}");
    logger.i("🔗 URL Completa: ${config['full_url']}");
    logger.i("🔄 Sync Automático: ${config['sync_activo'] ? 'ACTIVO' : 'INACTIVO'}");
    logger.i("⏰ Timer Activo: ${config['timer_activo'] ? 'SÍ' : 'NO'}");
    logger.i("📊 Estadísticas:");
    final stats = config['estadisticas'] as Map<String, int>;
    logger.i("   • Total: ${stats['total']}");
    logger.i("   • Sincronizados: ${stats['sincronizados']}");
    logger.i("   • Pendientes: ${stats['pendientes']}");
    logger.i("═══════════════════════════════════════");
  }

  /// Método de conveniencia para inicializar todo el servicio
  static Future<void> inicializar() async {
    final logger = Logger();

    try {
      logger.i("🚀 Inicializando DeviceLogUploadService...");

      // Mostrar configuración actual
      await mostrarConfiguracion();

      // Iniciar sincronización automática
      await iniciarSincronizacionAutomatica();

      logger.i("✅ DeviceLogUploadService inicializado correctamente");
    } catch (e) {
      logger.e("💥 Error inicializando DeviceLogUploadService: $e");
    }
  }
}