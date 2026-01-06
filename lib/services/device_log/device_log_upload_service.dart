import 'dart:async';

import 'package:ada_app/repositories/device_log_repository.dart';
import 'package:ada_app/services/post/device_log_post_service.dart';
import 'package:ada_app/services/data/database_helper.dart';
import 'package:ada_app/services/api/auth_service.dart';
import 'package:ada_app/models/device_log.dart';
import 'package:ada_app/services/error_log/error_log_service.dart';
import 'package:ada_app/services/api/api_config_service.dart';

class DeviceLogUploadService {
  static Timer? _syncTimer;
  static bool _syncActivo = false;

  /// Sincroniza todos los device logs pendientes
  static Future<Map<String, int>> sincronizarDeviceLogsPendientes() async {
    try {
      // Mostrar configuración actual para debugging
      final urlActual = await ApiConfigService.getBaseUrl();
      print('Sincronización de device logs pendientes...');
      print('URL configurada: $urlActual');

      final db = await DatabaseHelper().database;
      final repository = DeviceLogRepository(db);
      final logsPendientes = await repository.obtenerNoSincronizados();

      if (logsPendientes.isEmpty) {
        print('No hay device logs pendientes');
        return {'exitosos': 0, 'fallidos': 0, 'total': 0};
      }

      print('Total a sincronizar: ${logsPendientes.length}');

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

          print('Debug UserId:');
          print('   currentUser: ${currentUser?.username}');
          print('   currentUser.id: ${currentUser?.id}');
          print('   log.employeeId: ${log.employeeId}');
          print('   userId a enviar: ${userIdFromAuth ?? log.employeeId}');

          // Usar el servicio unificado con logging automático
          final resultado = await DeviceLogPostService.enviarDeviceLog(
            log,
            userId: userIdFromAuth,
          );

          if (resultado['exito'] == true) {
            await repository.marcarComoSincronizado(log.id);
            exitosos++;
            print('Device log ${log.id} enviado');
          } else {
            fallidos++;
            print('Error enviando ${log.id}: ${resultado['mensaje']}');
          }
        } catch (e) {
          print('Error enviando ${log.id}: $e');
          fallidos++;
        }
      }

      print(
        'Sincronización completada - Exitosos: $exitosos, Fallidos: $fallidos',
      );

      return {
        'exitosos': exitosos,
        'fallidos': fallidos,
        'total': logsPendientes.length,
      };
    } catch (e) {
      print('Error general en sincronización: $e');

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
      // 🔍 Mostrar URL para debugging
      final urlCompleta = await ApiConfigService.getFullUrl(
        '/appDeviceLog/insertAppDeviceLog',
      );
      print('📤 Enviando batch de ${logs.length} device logs...');
      print('🌐 URL destino: $urlCompleta');

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
            print('⚠️ Error marcando ${log.id} como sincronizado: $e');
          }
        }
        print('🔄 Marcados como sincronizados: $marcados');
      }

      return resultado;
    } catch (e) {
      print('❌ Error en batch upload: $e');

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
      print(
        '🧹 Limpiando device logs sincronizados antiguos (>${diasAntiguos} días)...',
      );

      final db = await DatabaseHelper().database;
      final repository = DeviceLogRepository(db);

      final eliminados = await repository.eliminarSincronizadosAntiguos(
        diasAntiguos: diasAntiguos,
      );

      print('✅ Eliminados $eliminados logs antiguos sincronizados');
      return eliminados;
    } catch (e) {
      print('❌ Error limpiando logs antiguos: $e');
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
      print('❌ Error obteniendo estadísticas: $e');
      return {'total': 0, 'sincronizados': 0, 'pendientes': 0};
    }
  }

  // ==================== SINCRONIZACIÓN AUTOMÁTICA ====================

  static Future<void> iniciarSincronizacionAutomatica() async {
    if (_syncActivo) {
      print('⚠️ Sincronización de device logs ya está activa');
      return;
    }

    _syncActivo = true;
    final urlActual = await ApiConfigService.getBaseUrl();

    print(
      '🚀 Iniciando sincronización automática de device logs cada 10 minutos...',
    );
    print('🌐 Sincronizando con: $urlActual');

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
      print('⏹️ Sincronización automática de device logs detenida');
    }
  }

  static Future<void> _ejecutarSincronizacionAutomatica() async {
    if (!_syncActivo) return;

    try {
      print('🔄 Ejecutando sincronización automática de device logs...');

      final resultado = await sincronizarDeviceLogsPendientes();

      if (resultado['total']! > 0) {
        print(
          '✅ Auto-sync completado: ${resultado['exitosos']}/${resultado['total']} enviados',
        );

        // 📊 Mostrar estadísticas después de la sincronización
        final stats = await obtenerEstadisticasSincronizacion();
        print(
          '📊 Estado actual: ${stats['sincronizados']} sync, ${stats['pendientes']} pendientes',
        );
      } else {
        print('💤 No hay device logs pendientes para sincronizar');
      }
    } catch (e) {
      print('❌ Error en auto-sync device logs: $e');
    }
  }

  static bool get esSincronizacionActiva => _syncActivo;

  static Future<Map<String, int>?> forzarSincronizacion() async {
    if (!_syncActivo) {
      print('⚠️ Sincronización automática no está activa');
      return null;
    }

    print('⚡ Forzando sincronización inmediata de device logs...');
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
    final config = await verificarConfiguracion();

    print("CONFIGURACIÓN UPLOAD SERVICE");
    print("Base URL: ${config['base_url']}");
    print("URL Completa: ${config['full_url']}");
    print("Sync Automático: ${config['sync_activo'] ? 'ACTIVO' : 'INACTIVO'}");
    print("Timer Activo: ${config['timer_activo'] ? 'SÍ' : 'NO'}");
    print("Estadísticas:");
    final stats = config['estadisticas'] as Map<String, int>;
    print("   - Total: ${stats['total']}");
    print("   - Sincronizados: ${stats['sincronizados']}");
    print("   - Pendientes: ${stats['pendientes']}");
  }

  /// Método de conveniencia para inicializar todo el servicio
  static Future<void> inicializar() async {
    try {
      print("Inicializando DeviceLogUploadService...");

      // Mostrar configuración actual
      await mostrarConfiguracion();

      // Iniciar sincronización automática
      await iniciarSincronizacionAutomatica();

      print("DeviceLogUploadService inicializado correctamente");
    } catch (e) {
      print("Error inicializando DeviceLogUploadService: $e");
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
        print('No se encontró usuario con employee_id "$employeeId".');
        final allUsers = await db.rawQuery(
          'SELECT id, employee_id, username FROM Users',
        );
        print('Dump de tabla Users (${allUsers.length} registros):');
        for (final u in allUsers) {
          print(
            '   User: id=${u['id']}, empId=${u['employee_id']}, user=${u['username']}',
          );
        }
      }
      return null;
    } catch (e) {
      print('Error buscando userId para employeeId $employeeId: $e');
      return null;
    }
  }
}
