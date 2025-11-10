// lib/services/post/device_log_post_service.dart

import 'package:ada_app/services/post/base_post_service.dart';
import 'package:ada_app/models/device_log.dart';

class DeviceLogPostService {
  static const String _endpoint = '/api/device-logs';

  /// Enviar un device log al servidor
  static Future<Map<String, dynamic>> enviarDeviceLog(DeviceLog log) async {
    return await BasePostService.post(
      endpoint: _endpoint,
      body: log.toMap(),
      timeout: const Duration(seconds: 10),
    );
  }

  /// Enviar múltiples device logs
  static Future<Map<String, int>> enviarDeviceLogsBatch(
      List<DeviceLog> logs,
      ) async {
    int exitosos = 0;
    int fallidos = 0;

    for (final log in logs) {
      final resultado = await enviarDeviceLog(log);

      if (resultado['exito'] == true) {
        exitosos++;
      } else {
        fallidos++;
      }
    }

    return {
      'exitosos': exitosos,
      'fallidos': fallidos,
      'total': logs.length,
    };
  }
}