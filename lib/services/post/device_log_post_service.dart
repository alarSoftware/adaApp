// lib/services/post/device_log_post_service.dart

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
      print('Enviando device log a: $fullUrl');
      print('Log ID: ${log.id}');

      // Crear body desde el log
      final Map<String, dynamic> bodyConUserId = Map.from(log.toMap());

      // Establecer userId (puede ser null)
      bodyConUserId['userId'] = userId;

      // Mapear employeeId al typo esperado por el servidor "emplyedId"
      if (log.employeeId != null) {
        bodyConUserId['emplyedId'] = log.employeeId;
      }

      // CRÍTICO: Eliminar la clave original 'employeeId' para evitar duplicidad o errores,
      // ya que enviamos 'emplyedId'
      bodyConUserId.remove('employeeId');

      // DEBUG
      print('Datos a enviar:');
      print('   userId: $userId');
      print('   emplyedId (mapped): ${bodyConUserId['emplyedId']}');
      print(
        '   employeeId removido: ${!bodyConUserId.containsKey('employeeId')}',
      );

      final resultado = await BasePostService.post(
        endpoint: _endpoint,
        body: bodyConUserId,
        tableName: _tableName,
        registroId: log.id,
      );

      if (resultado['exito'] == true) {
        print('Device log enviado: ${log.id}');
      } else {
        print('Error enviando device log: ${resultado['mensaje']}');
      }

      return resultado;
    } catch (e) {
      print('Error en enviarDeviceLog: $e');
      return {'exito': false, 'success': false, 'mensaje': 'Error: $e'};
    }
  }

  /// Enviar múltiples device logs en batch
  static Future<Map<String, int>> enviarDeviceLogsBatch(
    List<DeviceLog> logs, {
    String? userId,
  }) async {
    int exitosos = 0;
    int fallidos = 0;

    print('Enviando batch de ${logs.length} device logs...');

    final fullUrl = await ApiConfigService.getFullUrl(_endpoint);
    print('URL destino: $fullUrl');
    print('userId para batch: $userId');

    for (final log in logs) {
      try {
        final resultado = await enviarDeviceLog(log, userId: userId);

        if (resultado['exito'] == true) {
          exitosos++;
        } else {
          fallidos++;
        }

        // Log progreso cada 10 logs
        if ((exitosos + fallidos) % 10 == 0) {
          print('Progreso: ${exitosos + fallidos}/${logs.length}');
        }
      } catch (e) {
        print('Error enviando log ${log.id}: $e');
        fallidos++;
      }
    }

    print('Batch completado - Exitosos: $exitosos, Fallidos: $fallidos');

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

  /// Método para debugging - mostrar configuración
  static Future<void> mostrarConfiguracion() async {
    final config = await verificarConfiguracion();
    print(
      "Device Log Service Config: Base=${config['base_url']}, Endpoint=${config['endpoint']}",
    );
  }

  /// Método de conveniencia para testing
  static Future<void> testearConexion() async {
    try {
      print("Probando conexión del servicio...");
      await mostrarConfiguracion();

      final config = await verificarConfiguracion();
      print("Configuración obtenida correctamente");
      print("Listo para enviar device logs a: ${config['full_url']}");
    } catch (e) {
      print("Error probando conexión: $e");
    }
  }
}
