// lib/services/post/device_log_post_service.dart

import 'package:ada_app/models/device_log.dart';
import 'package:ada_app/services/post/base_post_service.dart';
import 'package:logger/logger.dart';

class DeviceLogPostService {
  static final Logger _logger = Logger();
  static const String _endpoint = '/api/device-logs';
  static const String _tableName = 'device_log';  // 🆕 AGREGAR

  /// Enviar un device log individual
  static Future<Map<String, dynamic>> enviarDeviceLog(
      DeviceLog log, {
        String? userId,
      }) async {
    try {
      _logger.i('📤 Enviando device log: ${log.id}');

      final resultado = await BasePostService.post(
        endpoint: _endpoint,
        body: log.toMap(),
        tableName: _tableName,                           // 🆕 AGREGAR - Activa el logging
        registroId: log.id,                              // 🆕 AGREGAR
        userId: userId ?? log.edfVendedorId,             // 🆕 AGREGAR
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

    for (final log in logs) {
      try {
        final resultado = await enviarDeviceLog(log, userId: userId);

        if (resultado['exito'] == true) {
          exitosos++;
        } else {
          fallidos++;
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
}