import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/services/error_log/error_log_service.dart';

class EquipoPostService {
  static const String _tableName = 'equipo';
  static const String _endpoint = '/edfEquipo/insertEquipo';
  static const _uuid = Uuid();

  static Future<Map<String, dynamic>> enviarEquipoNuevo({
    required String equipoId,
    required String codigoBarras,
    required int marcaId,
    required int modeloId,
    required int logoId,
    String? numeroSerie,
    String? clienteId,
    required String edfVendedorId,
  }) async {
    String? fullEndpoint;

    try {
      BaseSyncService.logger.i('💡 Enviando equipo nuevo...');

      final payload = _construirPayload(
        equipoId: equipoId,
        codigoBarras: codigoBarras,
        marcaId: marcaId,
        modeloId: modeloId,
        logoId: logoId,
        numeroSerie: numeroSerie,
        clienteId: clienteId,
        edfVendedorId: edfVendedorId,
      );

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
        errorMessage: 'Timeout al enviar equipo nuevo: $e',
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
        errorMessage: 'Error general al enviar equipo nuevo: $e',
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

  static Map<String, dynamic> _construirPayload({
    required String equipoId,
    required String codigoBarras,
    required int marcaId,
    required int modeloId,
    required int logoId,
    String? numeroSerie,
    String? clienteId,
    required String edfVendedorId,
  }) {
    return {
      'id': equipoId,
      'cod_barras': codigoBarras,
      'marca_id': marcaId,
      'modelo_id': modeloId,
      'logo_id': logoId,
      'numero_serie': numeroSerie,
      'cliente_id': clienteId,
      'app_insert': 1,
      'appId': _uuid.v4(),
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

    try {
      final body = jsonDecode(response.body);

      // Ajustar según la respuesta de tu backend Grails
      if (body is Map && body['success'] == true) {
        return {
          'exito': true,
          'mensaje': 'Equipo registrado correctamente',
          'data': body
        };
      } else if (response.body.contains('REGISTRADO') ||
          response.body.contains('éxito')) {
        return {
          'exito': true,
          'mensaje': 'Equipo registrado correctamente'
        };
      } else if (response.body.contains('ya existe') ||
          response.body.contains('duplicado')) {
        return {
          'exito': true,
          'mensaje': 'Equipo ya estaba registrado'
        };
      } else {
        return {
          'exito': false,
          'mensaje': response.body
        };
      }
    } catch (e) {
      // Si no es JSON, procesar como texto
      final body = response.body;
      if (body.contains('REGISTRADO') || body.contains('éxito')) {
        return {
          'exito': true,
          'mensaje': 'Equipo registrado correctamente'
        };
      } else {
        return {
          'exito': false,
          'mensaje': body
        };
      }
    }
  }

  /// 🆕 Método para reintentar envío
  static Future<Map<String, dynamic>> reintentarEnvio({
    required String equipoId,
    required String codigoBarras,
    required int marcaId,
    required int modeloId,
    required int logoId,
    String? numeroSerie,
    String? clienteId,
    required String edfVendedorId,
    int intentoNumero = 1,
  }) async {
    BaseSyncService.logger.i('🔁 Reintentando equipo: $equipoId (Intento #$intentoNumero)');

    final result = await enviarEquipoNuevo(
      equipoId: equipoId,
      codigoBarras: codigoBarras,
      marcaId: marcaId,
      modeloId: modeloId,
      logoId: logoId,
      numeroSerie: numeroSerie,
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

  /// 🆕 Verificar si un equipo ya existe en el servidor
  static Future<Map<String, dynamic>> verificarEquipoExiste(
      String codigoBarras,
      ) async {
    String? fullEndpoint;

    try {
      final baseUrl = await BaseSyncService.getBaseUrl();
      fullEndpoint = '$baseUrl/edfEquipo/existe/$codigoBarras';

      final response = await http.get(
        Uri.parse(fullEndpoint),
        headers: {'Content-Type': 'application/json'},
      ).timeout(BaseSyncService.timeout);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return {
          'exito': true,
          'existe': body['existe'] ?? false,
          'data': body
        };
      }

      return {
        'exito': false,
        'mensaje': 'Error verificando equipo: ${response.statusCode}'
      };

    } catch (e) {
      BaseSyncService.logger.e('❌ Error verificando equipo: $e');
      return {
        'exito': false,
        'mensaje': 'Error de conexión: $e'
      };
    }
  }

  /// 🆕 Obtener equipo del servidor por código
  static Future<Map<String, dynamic>> obtenerEquipoPorCodigo(
      String codigoBarras,
      ) async {
    String? fullEndpoint;

    try {
      final baseUrl = await BaseSyncService.getBaseUrl();
      fullEndpoint = '$baseUrl/edfEquipo/buscar/$codigoBarras';

      final response = await http.get(
        Uri.parse(fullEndpoint),
        headers: {'Content-Type': 'application/json'},
      ).timeout(BaseSyncService.timeout);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return {
          'exito': true,
          'equipo': body,
        };
      }

      return {
        'exito': false,
        'mensaje': 'Equipo no encontrado'
      };

    } catch (e) {
      BaseSyncService.logger.e('❌ Error obteniendo equipo: $e');
      return {
        'exito': false,
        'mensaje': 'Error de conexión: $e'
      };
    }
  }
}