import 'dart:convert';
import 'dart:async'; // 🆕 AGREGAR
import 'dart:io'; // 🆕 AGREGAR
import 'package:http/http.dart' as http;
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/services/error_log/error_log_service.dart'; // 🆕 AGREGAR

class EquiposPendientesApiService {
  static const String _tableName = 'equipos_pendientes'; // 🆕 AGREGAR
  static const String _endpoint = '/edfEquipoPendiente/insertEquipoPendiente'; // 🆕 AGREGAR

  static Future<Map<String, dynamic>> enviarEquipoPendiente({
    required String equipoId,
    required int clienteId,
    required String edfVendedorId,
  }) async {
    String? fullEndpoint;

    try {
      BaseSyncService.logger.i('💡 Enviando equipo pendiente...');

      final payload = _construirPayload(equipoId, clienteId, edfVendedorId);

      BaseSyncService.logger.i('📦 Payload completo: $payload');
      print(jsonEncode(payload));

      final baseUrl = await BaseSyncService.getBaseUrl();
      fullEndpoint = '$baseUrl$_endpoint';

      final response = await http.post(
        Uri.parse(fullEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(BaseSyncService.timeout);

      BaseSyncService.logger.i('📥 Respuesta HTTP: ${response.statusCode}');
      BaseSyncService.logger.i('📄 Body respuesta: ${response.body}');

      final result = _procesarRespuesta(response);

      // 🚨 LOG: Si hubo error del servidor
      if (!result['exito'] && response.statusCode >= 400) {
        await ErrorLogService.logServerError(
          tableName: _tableName,
          operation: 'POST',
          errorMessage: result['mensaje'],
          errorCode: response.statusCode.toString(),
          registroFailId: equipoId,
          endpoint: fullEndpoint,
          userId: edfVendedorId,
        );
      }

      return result;

    } on TimeoutException catch (e) {
      BaseSyncService.logger.e('⏰ Timeout: $e');

      // 🚨 LOG: Timeout
      await ErrorLogService.logNetworkError(
        tableName: _tableName,
        operation: 'POST',
        errorMessage: 'Timeout al enviar equipo pendiente: $e',
        registroFailId: equipoId,
        endpoint: fullEndpoint ?? _endpoint,
        userId: edfVendedorId,
      );

      return {
        'exito': false,
        'mensaje': 'Tiempo de espera agotado'
      };

    } on SocketException catch (e) {
      BaseSyncService.logger.e('📡 Error de red: $e');

      // 🚨 LOG: Error de red
      await ErrorLogService.logNetworkError(
        tableName: _tableName,
        operation: 'POST',
        errorMessage: 'Sin conexión de red: $e',
        registroFailId: equipoId,
        endpoint: fullEndpoint ?? _endpoint,
        userId: edfVendedorId,
      );

      return {
        'exito': false,
        'mensaje': 'Sin conexión de red'
      };

    } on http.ClientException catch (e) {
      BaseSyncService.logger.e('🌐 Error de cliente HTTP: $e');

      // 🚨 LOG: Error de cliente HTTP
      await ErrorLogService.logNetworkError(
        tableName: _tableName,
        operation: 'POST',
        errorMessage: 'Error de cliente HTTP: ${e.message}',
        registroFailId: equipoId,
        endpoint: fullEndpoint ?? _endpoint,
        userId: edfVendedorId,
      );

      return {
        'exito': false,
        'mensaje': 'Error de red: ${e.message}'
      };

    } on FormatException catch (e) {
      BaseSyncService.logger.e('📄 Error de formato JSON: $e');

      // 🚨 LOG: Error de formato
      await ErrorLogService.logError(
        tableName: _tableName,
        operation: 'POST',
        errorMessage: 'Error de formato en payload: $e',
        errorType: 'format',
        errorCode: 'FORMAT_ERROR',
        registroFailId: equipoId,
        endpoint: fullEndpoint ?? _endpoint,
        userId: edfVendedorId,
      );

      return {
        'exito': false,
        'mensaje': 'Error de formato en la petición'
      };

    } catch (e) {
      BaseSyncService.logger.e('❌ Error general: $e');

      // 🚨 LOG: Error general
      await ErrorLogService.logError(
        tableName: _tableName,
        operation: 'POST',
        errorMessage: 'Error general al enviar equipo pendiente: $e',
        errorType: 'unknown',
        errorCode: 'POST_FAILED',
        registroFailId: equipoId,
        endpoint: fullEndpoint ?? _endpoint,
        userId: edfVendedorId,
      );

      return {
        'exito': false,
        'mensaje': 'Error de conexión: $e'
      };
    }
  }

  static Map<String, dynamic> _construirPayload(
      String equipoId,
      int clienteId,
      String edfVendedorId,
      ) {
    return {
      'equipoId': equipoId,
      'clienteId': clienteId.toString(),
      'appId': DateTime.now().millisecondsSinceEpoch.toString(),
      'vendedorSucursalId': edfVendedorId,
    };
  }

  static Map<String, dynamic> _procesarRespuesta(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return {
        'exito': false,
        'mensaje': 'Error del servidor: ${response.statusCode}'
      };
    }

    final body = response.body;
    if (body.contains('REGISTRADO')) {
      return {'exito': true, 'mensaje': 'Equipo pendiente registrado'};
    } else if (body.contains('ya fue registrado')) {
      return {'exito': true, 'mensaje': 'Equipo ya estaba registrado'};
    } else {
      return {'exito': false, 'mensaje': body};
    }
  }

  /// 🆕 Método para reintentar envío
  static Future<Map<String, dynamic>> reintentarEnvio({
    required String equipoId,
    required int clienteId,
    required String edfVendedorId,
    int intentoNumero = 1,
  }) async {
    BaseSyncService.logger.i('🔁 Reintentando equipo pendiente: $equipoId (Intento #$intentoNumero)');

    final result = await enviarEquipoPendiente(
      equipoId: equipoId,
      clienteId: clienteId,
      edfVendedorId: edfVendedorId,
    );

    // Loguear reintento fallido
    if (!result['exito']) {
      await ErrorLogService.logError(
        tableName: _tableName,
        operation: 'RETRY_POST',
        errorMessage: 'Reintento #$intentoNumero falló: ${result['mensaje']}',
        errorType: 'retry_failed',
        registroFailId: equipoId,
        syncAttempt: intentoNumero,
        userId: edfVendedorId,
      );
    }

    return result;
  }
}