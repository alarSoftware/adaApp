import 'package:flutter/foundation.dart';
import '../../utils/logger.dart';
import 'package:ada_app/models/device_log.dart';
import 'package:ada_app/services/post/base_post_service.dart';
import 'package:ada_app/services/api/api_config_service.dart';

/// Formatea DateTime sin 'T' ni 'Z' para el backend
/// Formato: "yyyy-MM-dd HH:mm:ss.SSSSSS"
String _formatTimestampForBackend(DateTime dt) {
  String year = dt.year.toString().padLeft(4, '0');
  String month = dt.month.toString().padLeft(2, '0');
  String day = dt.day.toString().padLeft(2, '0');
  String hour = dt.hour.toString().padLeft(2, '0');
  String minute = dt.minute.toString().padLeft(2, '0');
  String second = dt.second.toString().padLeft(2, '0');
  String microsecond = dt.microsecond.toString().padLeft(6, '0');

  return '$year-$month-$day $hour:$minute:$second.$microsecond';
}

class DeviceLogPostService {
  static const String _endpoint = '/appDeviceLog/insertAppDeviceLog';
  static const String _tableName = 'device_log';

  /// Enviar un device log individual
  static Future<Map<String, dynamic>> enviarDeviceLog(
    DeviceLog log, {
    String? userId,
  }) async {
    try {
      final Map<String, dynamic> body = log.toMap();
      body['userId'] = userId;

      // FIX: Formatear fecha para eliminar la 'T' ISO8601
      if (log.fechaRegistro.isNotEmpty) {
        try {
          debugPrint('DEBUG DATE: Original: ${log.fechaRegistro}');
          final fechaDt = DateTime.parse(log.fechaRegistro);
          body['fechaRegistro'] = _formatTimestampForBackend(fechaDt);
          debugPrint('DEBUG DATE: Formatted: ${body['fechaRegistro']}');
        } catch (e) {
          debugPrint('Error formateando fecha log: $e');
        }
      }

      debugPrint('Enviando DeviceLog Body: $body');

      final resultado = await BasePostService.post(
        endpoint: _endpoint,
        body: body,
        tableName: _tableName,
        registroId: log.id,
      );
      return resultado;
    } catch (e) { AppLogger.e("DEVICE_LOG_POST_SERVICE: Error", e); return {'exito': false, 'success': false, 'mensaje': 'Error: $e'}; }
  }

  /// Enviar múltiples device logs en batch
  static Future<Map<String, int>> enviarDeviceLogsBatch(
    List<DeviceLog> logs, {
    String? userId,
  }) async {
    int exitosos = 0;
    int fallidos = 0;
    for (final log in logs) {
      try {
        final resultado = await enviarDeviceLog(log, userId: userId);

        if (resultado['exito'] == true) {
          exitosos++;
        } else {
          fallidos++;
        }

        if ((exitosos + fallidos) % 10 == 0) {
          debugPrint('Progreso: ${exitosos + fallidos}/${logs.length}');
        }
      } catch (e) {
        debugPrint('Error enviando log ${log.id}: $e');
        fallidos++;
      }
    }
    return {'exitosos': exitosos, 'fallidos': fallidos, 'total': logs.length};
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

  /// Mostrar configuración en logs
  static Future<void> mostrarConfiguracion() async {
    await verificarConfiguracion();
  }

  /// Test rápido del servicio
  static Future<void> testearConexion() async {
    try {
      await mostrarConfiguracion();
      await verificarConfiguracion();
    } catch (e) {
      debugPrint('Error en el testeo: $e');
    }
  }
}
