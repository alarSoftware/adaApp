import 'package:ada_app/models/device_log.dart';
import 'package:ada_app/services/post/base_post_service.dart';
import 'package:ada_app/services/api/api_config_service.dart';

class DeviceLogPostService {
  static const String _endpoint = '/appDeviceLog/insertAppDeviceLog';
  static const String _tableName = 'device_log';

  /// Enviar un device log individual
  static Future<Map<String, dynamic>> enviarDeviceLog(
      DeviceLog log, {
        String? userId,
      }) async {
    try {
      final fullUrl = await ApiConfigService.getFullUrl(_endpoint);
      final Map<String, dynamic> body = log.toMap();
      // Establecer userId (puede ser null)
      body['userId'] = userId;
      final resultado = await BasePostService.post(
        endpoint: _endpoint,
        body: body,
        tableName: _tableName,
        registroId: log.id,
      );
      return resultado;
    } catch (e) {
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
    for (final log in logs) {
      try {
        final resultado = await enviarDeviceLog(log, userId: userId);

        if (resultado['exito'] == true) {
          exitosos++;
        } else {
          fallidos++;
        }

        if ((exitosos + fallidos) % 10 == 0) {
          print('Progreso: ${exitosos + fallidos}/${logs.length}');
        }
      } catch (e) {
        print('Error enviando log ${log.id}: $e');
        fallidos++;
      }
    }
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

  /// Mostrar configuración en logs
  static Future<void> mostrarConfiguracion() async {
    final config = await verificarConfiguracion();
  }

  /// Test rápido del servicio
  static Future<void> testearConexion() async {
    try {
      await mostrarConfiguracion();
      final config = await verificarConfiguracion();
    } catch (e) {
      print('Error en el testeo: $e');
    }
  }
}
