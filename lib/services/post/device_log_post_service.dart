// lib/services/post/device_log_post_service.dart

import 'package:ada_app/models/device_log.dart';
import 'package:ada_app/services/post/base_post_service.dart';
import 'package:ada_app/services/api_config_service.dart';
import 'package:logger/logger.dart';

class DeviceLogPostService {
  static final Logger _logger = Logger();
  static const String _endpoint = '/appDeviceLog/insertAppDeviceLog';  // 🔥 ENDPOINT CORRECTO
  static const String _tableName = 'device_log';

  /// Enviar un device log individual
  static Future<Map<String, dynamic>> enviarDeviceLog(
      DeviceLog log, {
        String? userId,
      }) async {
    try {
      // 🔍 MOSTRAR URL COMPLETA para debugging
      final fullUrl = await ApiConfigService.getFullUrl(_endpoint);
      _logger.i('📤 Enviando device log a: $fullUrl');
      _logger.i('📦 Log ID: ${log.id}');

      final resultado = await BasePostService.post(
        endpoint: _endpoint,
        body: log.toMap(),
        tableName: _tableName,                           // ✅ Activa el logging de errores
        registroId: log.id,                              // ✅ Para tracking
        userId: userId ?? log.edfVendedorId,             // ✅ Para logging
      );

      if (resultado['exito'] == true) {
        _logger.i('✅ Device log enviado: ${log.id}');
      } else {
        _logger.w('⚠️ Error enviando device log: ${resultado['mensaje']}');
      }

      return resultado;
    } catch (e) {
      _logger.e('❌ Error en enviarDeviceLog: $e');
      return {
        'exito': false,
        'success': false,
        'mensaje': 'Error: $e',
      };
    }
  }

  /// Enviar múltiples device logs en batch
  static Future<Map<String, int>> enviarDeviceLogsBatch(
      List<DeviceLog> logs, {
        String? userId,
      }) async {
    int exitosos = 0;
    int fallidos = 0;

    _logger.i('📤 Enviando batch de ${logs.length} device logs...');

    // 🔍 Mostrar URL para el batch
    final fullUrl = await ApiConfigService.getFullUrl(_endpoint);
    _logger.i('🌐 URL destino: $fullUrl');

    for (final log in logs) {
      try {
        final resultado = await enviarDeviceLog(log, userId: userId);

        if (resultado['exito'] == true) {
          exitosos++;
        } else {
          fallidos++;
        }

        // 📊 Log progreso cada 10 logs
        if ((exitosos + fallidos) % 10 == 0) {
          _logger.i('📊 Progreso: ${exitosos + fallidos}/${logs.length}');
        }
      } catch (e) {
        _logger.e('❌ Error enviando log ${log.id}: $e');
        fallidos++;
      }
    }

    _logger.i('✅ Batch completado - Exitosos: $exitosos, Fallidos: $fallidos');

    return {
      'exitosos': exitosos,
      'fallidos': fallidos,
      'total': logs.length,
    };
  }

  /// Verificar configuración actual del servicio
  static Future<Map<String, dynamic>> verificarConfiguracion() async {
    final baseUrl = await ApiConfigService.getBaseUrl();
    final fullUrl = await ApiConfigService.getFullUrl(_endpoint);

    return {
      'base_url': baseUrl,
      'endpoint': _endpoint,
      'full_url': fullUrl,
      'tabla': _tableName,
    };
  }

  /// Método para debugging - mostrar configuración
  static Future<void> mostrarConfiguracion() async {
    final config = await verificarConfiguracion();
    _logger.i("═══════════════════════════════════════");
    _logger.i("🔧 CONFIGURACIÓN DEVICE LOG SERVICE");
    _logger.i("═══════════════════════════════════════");
    _logger.i("🌐 Base URL: ${config['base_url']}");
    _logger.i("📍 Endpoint: ${config['endpoint']}");
    _logger.i("🔗 URL Completa: ${config['full_url']}");
    _logger.i("🗃️ Tabla: ${config['tabla']}");
    _logger.i("═══════════════════════════════════════");
  }

  /// Método de conveniencia para testing
  static Future<void> testearConexion() async {
    try {
      _logger.i("🧪 Probando conexión del servicio...");
      await mostrarConfiguracion();

      final config = await verificarConfiguracion();
      _logger.i("✅ Configuración obtenida correctamente");
      _logger.i("🎯 Listo para enviar device logs a: ${config['full_url']}");
    } catch (e) {
      _logger.e("❌ Error probando conexión: $e");
    }
  }
}