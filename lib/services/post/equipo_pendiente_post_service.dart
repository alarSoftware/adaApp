import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/services/error_log/error_log_service.dart';

class EquiposPendientesApiService {
  static const String _tableName = 'equipos_pendientes';
  static const String _endpoint = '/edfEquipoPendiente/insertEquipoPendiente';

  static Future<Map<String, dynamic>> enviarEquipoPendiente({
    required String equipoId,
    required int clienteId,
    required String edfVendedorId,
    String? appId, // UUID local del registro
  }) async {
    String? fullEndpoint;

    try {
      BaseSyncService.logger.i('💡 Enviando equipo pendiente...');
      BaseSyncService.logger.i('📱 AppId recibido: $appId');

      final payload = _construirPayload(
        equipoId,
        clienteId,
        edfVendedorId,
        appId,
      );

      BaseSyncService.logger.i('📦 Payload completo: $payload');
      BaseSyncService.logger.i('📤 JSON a enviar:\n${JsonEncoder.withIndent('  ').convert(payload)}');

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
      String? appId,
      ) {
    // Si no se proporciona appId, generar uno nuevo
    final uuidValue = appId ?? Uuid().v4();

    BaseSyncService.logger.i('🔑 UUID generado/usado: $uuidValue');

    // Extraer vendedorId y sucursalId del edfVendedorId (formato: "vendedorId_sucursalId")
    final partes = edfVendedorId.split('_');
    final vendedorIdValue = partes.isNotEmpty ? partes[0] : edfVendedorId;

    // ✅ IMPORTANTE: sucursalId debe ser Long/int, no String
    int? sucursalIdValue;
    if (partes.length > 1) {
      sucursalIdValue = int.tryParse(partes[1]);
    }

    BaseSyncService.logger.i('📊 Datos parseados:');
    BaseSyncService.logger.i('   - VendedorId: $vendedorIdValue');
    BaseSyncService.logger.i('   - SucursalId: $sucursalIdValue');

    // ✅ Usar Map<String, dynamic> para permitir diferentes tipos
    final Map<String, dynamic> payload = {
      'edfEquipoId': equipoId,                      // String
      'edfClienteId': clienteId.toString(),         // String
      'uuid': uuidValue,                            // String
      'edfVendedorSucursalId': edfVendedorId,       // String
      'edfVendedorId': vendedorIdValue,             // String
      'estado': 'pendiente',                        // String
    };

    // ✅ Agregar sucursalId si existe (como int, no String)
    if (sucursalIdValue != null) {
      payload['edfSucursalId'] = sucursalIdValue;   // int
    }

    return payload;
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

  static Future<Map<String, dynamic>> reintentarEnvio({
    required String equipoId,
    required int clienteId,
    required String edfVendedorId,
    String? appId,
    int intentoNumero = 1,
  }) async {
    BaseSyncService.logger.i('🔁 Reintentando equipo pendiente: $equipoId (Intento #$intentoNumero)');

    final result = await enviarEquipoPendiente(
      equipoId: equipoId,
      clienteId: clienteId,
      edfVendedorId: edfVendedorId,
      appId: appId,
    );

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