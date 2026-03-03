import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:ada_app/services/api/api_config_service.dart';
import 'package:ada_app/services/network/monitored_http_client.dart';
import '../../utils/logger.dart';

import 'package:ada_app/config/constants/server_constants.dart';

class BasePostService {
  static const Duration defaultTimeout = Duration(seconds: 60);

  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// Método genérico para hacer POST
  static Future<Map<String, dynamic>> post({
    required String endpoint,
    required Map<String, dynamic> body,
    Duration timeout = defaultTimeout,
    Map<String, String>? customHeaders,
    String? tableName,
    String? registroId,
    String? userId,
  }) async {
    String? fullUrl;

    try {
      final baseUrl = await ApiConfigService.getBaseUrl();
      fullUrl = '$baseUrl$endpoint';

      final jsonBody = json.encode(body);

      debugPrint('POST request enviado');
      debugPrint('Body size: ${jsonBody.length} chars');

      final response = await MonitoredHttpClient.post(
        url: Uri.parse(fullUrl),
        headers: customHeaders ?? headers,
        body: jsonBody,
        timeout: timeout,
      );

      debugPrint('Response: ${response.statusCode}');

      // LOG: Imprimir snippet del body para depuración
      AppLogger.i(
        'BASE_POST_SERVICE: POST $endpoint -> status: ${response.statusCode}',
      );
      if (response.body.length > 200) {
        AppLogger.i(
          'BASE_POST_SERVICE: body snippet: ${response.body.substring(0, 200)}',
        );
      } else {
        AppLogger.i('BASE_POST_SERVICE: body: ${response.body}');
      }

      final result = _processResponse(response, fullUrl);

      // Si hubo error del servidor, loguear
      if (!result['exito'] && tableName != null) {
        // Usamos el status_code que devuelve el result si existe, sino el HTTP code
        // Usamos el status_code que devuelve el result si existe, sino el HTTP code

        // await ErrorLogService.logServerError(
        //   tableName: tableName,
        //   operation: 'POST',
        //   errorMessage: result['mensaje'] ?? 'Error del servidor',
        //   errorCode: errorCode,
        //   registroFailId: registroId,
        //   endpoint: fullUrl,
        //   userId: userId,
        // );
      }

      return result;
    } on SocketException catch (e) {
      debugPrint('Error de red: $e');

      // 🚨 LOG ERROR
      if (tableName != null) {
        // await ErrorLogService.logNetworkError(
        //   tableName: tableName,
        //   operation: 'POST',
        //   errorMessage: 'Sin conexión de red: $e',
        //   registroFailId: registroId,
        //   endpoint: fullUrl ?? endpoint,
        //   userId: userId,
        // );
      }

      return {
        'exito': false,
        'success': false,
        'mensaje': 'Sin conexión de red',
        'error': 'Sin conexión de red',
      };
    } on TimeoutException catch (e) {
      debugPrint('Timeout: $e');

      // 🚨 LOG ERROR
      if (tableName != null) {
        // await ErrorLogService.logNetworkError(
        //   tableName: tableName,
        //   operation: 'POST',
        //   errorMessage: 'Timeout de conexión: $e',
        //   registroFailId: registroId,
        //   endpoint: fullUrl ?? endpoint,
        //   userId: userId,
        // );
      }

      return {
        'exito': false,
        'success': false,
        'mensaje': 'Tiempo de espera agotado',
        'error': 'Tiempo de espera agotado',
      };
    } on http.ClientException catch (e) {
      debugPrint('Error de cliente HTTP: $e');

      // 🚨 LOG ERROR
      if (tableName != null) {
        // await ErrorLogService.logNetworkError(
        //   tableName: tableName,
        //   operation: 'POST',
        //   errorMessage: 'Error de red: ${e.message}',
        //   registroFailId: registroId,
        //   endpoint: fullUrl ?? endpoint,
        //   userId: userId,
        // );
      }

      return {
        'exito': false,
        'success': false,
        'mensaje': 'Error de red: ${e.message}',
        'error': e.message,
      };
    } catch (e) {
      debugPrint('Error general en POST: $e');

      // 🚨 LOG ERROR
      if (tableName != null) {
        // await ErrorLogService.logError(
        //   tableName: tableName,
        //   operation: 'POST',
        //   errorMessage: 'Error general: $e',
        //   errorType: 'unknown',
        //   errorCode: 'POST_FAILED',
        //   registroFailId: registroId,
        //   endpoint: fullUrl ?? endpoint,
        //   userId: userId,
        // );
      }

      return {
        'exito': false,
        'success': false,
        'mensaje': 'Error de conexión: $e',
        'error': e.toString(),
      };
    }
  }

  /// Procesar respuesta HTTP
  static Map<String, dynamic> _processResponse(
    http.Response response,
    String? url,
  ) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _processSuccessResponse(response);
    } else {
      debugPrint('Error del servidor: ${response.statusCode}');

      // Verificar si el cuerpo del error indica duplicado (ej: HTTP 409 Conflict)
      final bodyLower = response.body.toLowerCase();
      final esDuplicado =
          bodyLower.contains('duplicate') ||
          bodyLower.contains('already exists') ||
          bodyLower.contains('unique constraint') ||
          bodyLower.contains('dataintegrityviolationexception') ||
          bodyLower.contains('duplicatekey') ||
          bodyLower.contains('ya existe');

      if (esDuplicado) {
        debugPrint(
          'ID duplicado detectado en error HTTP ${response.statusCode} - tratando como éxito idempotente',
        );
        return {
          'exito': true,
          'success': true,
          'mensaje': 'Registro ya existe en el servidor (idempotente)',
          'status_code': response.statusCode,
          'idempotente': true,
        };
      }

      return {
        'exito': false,
        'success': false,
        'mensaje': 'Error del servidor: ${response.statusCode}',
        'error': 'Error del servidor: ${response.statusCode}',
        'detalle': response.body,
        'status_code': response.statusCode,
      };
    }
  }

  /// Procesar respuesta exitosa (CORREGIDO PARA VALIDACIÓN SERVER ACTION)
  static Map<String, dynamic> _processSuccessResponse(http.Response response) {
    // 1. Intentar decodificar JSON
    try {
      final responseBody = json.decode(response.body);

      // 2. CHECK ESTRICTO DEL FORMATO GROOVY (serverAction)
      if (responseBody is Map && responseBody.containsKey('serverAction')) {
        final serverAction = responseBody['serverAction'] as int?;

        if (serverAction == ServerConstants.SUCCESS_TRANSACTION) {
          // 100
          // Éxito Lógico confirmado
          final servidorId = responseBody['resultId'] ?? responseBody['id'];
          return {
            'exito': true,
            'success': true,
            'mensaje': responseBody['resultMessage'] ?? 'Operación exitosa',
            'serverAction': serverAction,
            'servidor_id': servidorId,
            'id': servidorId,
          };
        } else {
          // Error Lógico (-501, 205, etc.), aun con HTTP 200
          debugPrint('Falso Negativo detectado. Action: $serverAction');
          debugPrint(
            'Server resultError: ${responseBody['resultError']} | resultMessage: ${responseBody['resultMessage']}',
          );

          final errorMsg =
              (responseBody['resultError'] ??
                      responseBody['resultMessage'] ??
                      '')
                  .toString()
                  .toLowerCase();

          // Si el error es por ID duplicado, el dato YA está en el servidor.
          // Tratarlo como éxito idempotente para evitar reintentos infinitos.
          final esDuplicado =
              errorMsg.contains('duplicate') ||
              errorMsg.contains('already exists') ||
              errorMsg.contains('unique constraint') ||
              errorMsg.contains('dataintegrityviolationexception') ||
              errorMsg.contains('duplicatekey') ||
              errorMsg.contains('ya existe');

          if (esDuplicado) {
            debugPrint(
              'ID duplicado detectado - tratando como éxito idempotente',
            );
            return {
              'exito': true,
              'success': true,
              'mensaje': 'Registro ya existe en el servidor (idempotente)',
              'serverAction': serverAction,
              'idempotente': true,
            };
          }

          return {
            'exito': false,
            'success': false,
            'mensaje':
                responseBody['resultError'] ??
                responseBody['resultMessage'] ??
                'Error de lógica del servidor',
            'serverAction': serverAction,
            'resultError': responseBody['resultError'],
            'status_code': response.statusCode,
          };
        }
      }

      // 3. Fallback genérico (si no tiene serverAction)
      dynamic servidorId = responseBody['id'] ?? responseBody['insertId'];
      String mensaje =
          responseBody['message'] ?? 'Operación exitosa (Formato Genérico)';

      return {
        'exito': true,
        'success': true,
        'id': servidorId,
        'servidor_id': servidorId,
        'mensaje': mensaje,
      };
    } catch (e) {
      debugPrint('Error al parsear respuesta del servidor');
      // Si falla el parseo, pero el status es 2xx, asumimos éxito simple
      return {
        'exito': true,
        'success': true,
        'mensaje': 'Éxito: Respuesta plana o ilegible.',
        'body': response.body,
      };
    }
  }

  /// Método de conveniencia para logs
  static Future<void> logRequest({
    required String endpoint,
    required Map<String, dynamic> body,
    String? additionalInfo,
  }) async {
    if (!kDebugMode) return;
    debugPrint('═══════════════════════════════════════');
    debugPrint('REQUEST POST');
    debugPrint('Endpoint: $endpoint');
    if (additionalInfo != null) {
      debugPrint('Info: $additionalInfo');
    }
    debugPrint('Body keys: ${body.keys.toList()}');
    debugPrint('═══════════════════════════════════════');
  }

  /// Helper para obtener baseUrl
  static Future<String> getBaseUrl() async {
    return await ApiConfigService.getBaseUrl();
  }
}
