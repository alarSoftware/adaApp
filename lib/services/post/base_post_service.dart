// lib/services/post/base_post_service.dart

import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:ada_app/services/api_config_service.dart';
import 'package:ada_app/services/error_log/error_log_service.dart';

class BasePostService {
  static final Logger logger = Logger();

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

      logger.i('📤 POST a $fullUrl');
      logger.i('📦 Body size: ${jsonBody.length} caracteres');

      final response = await http.post(
        Uri.parse(fullUrl),
        headers: customHeaders ?? headers,
        body: jsonBody,
      ).timeout(timeout);

      logger.i('📥 Response: ${response.statusCode}');

      final result = _processResponse(response, fullUrl);

      // 🚨 Si hubo error del servidor, loguear
      if (!result['exito'] && tableName != null) {
        await ErrorLogService.logServerError(
          tableName: tableName,
          operation: 'POST',
          errorMessage: result['mensaje'] ?? 'Error del servidor',
          errorCode: response.statusCode.toString(),
          registroFailId: registroId,
          endpoint: fullUrl,
          userId: userId,
        );
      }

      return result;

    } on SocketException catch (e) {
      logger.e('📡 Error de red: $e');

      // 🚨 LOG ERROR
      if (tableName != null) {
        await ErrorLogService.logNetworkError(
          tableName: tableName,
          operation: 'POST',
          errorMessage: 'Sin conexión de red: $e',
          registroFailId: registroId,
          endpoint: fullUrl ?? endpoint,
          userId: userId,
        );
      }

      return {
        'exito': false,
        'success': false,
        'mensaje': 'Sin conexión de red',
        'error': 'Sin conexión de red',
      };

    } on TimeoutException catch (e) {
      logger.e('⏰ Timeout: $e');

      // 🚨 LOG ERROR
      if (tableName != null) {
        await ErrorLogService.logNetworkError(
          tableName: tableName,
          operation: 'POST',
          errorMessage: 'Timeout de conexión: $e',
          registroFailId: registroId,
          endpoint: fullUrl ?? endpoint,
          userId: userId,
        );
      }

      return {
        'exito': false,
        'success': false,
        'mensaje': 'Tiempo de espera agotado',
        'error': 'Tiempo de espera agotado',
      };

    } on http.ClientException catch (e) {
      logger.e('🌐 Error de cliente HTTP: $e');

      // 🚨 LOG ERROR
      if (tableName != null) {
        await ErrorLogService.logNetworkError(
          tableName: tableName,
          operation: 'POST',
          errorMessage: 'Error de red: ${e.message}',
          registroFailId: registroId,
          endpoint: fullUrl ?? endpoint,
          userId: userId,
        );
      }

      return {
        'exito': false,
        'success': false,
        'mensaje': 'Error de red: ${e.message}',
        'error': e.message,
      };

    } catch (e) {
      logger.e('❌ Error general en POST: $e');

      // 🚨 LOG ERROR
      if (tableName != null) {
        await ErrorLogService.logError(
          tableName: tableName,
          operation: 'POST',
          errorMessage: 'Error general: $e',
          errorType: 'unknown',
          errorCode: 'POST_FAILED',
          registroFailId: registroId,
          endpoint: fullUrl ?? endpoint,
          userId: userId,
        );
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
  static Map<String, dynamic> _processResponse(http.Response response, String? url) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _processSuccessResponse(response);
    } else {
      logger.e('❌ Error del servidor: ${response.statusCode}');

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

  /// Procesar respuesta exitosa
  static Map<String, dynamic> _processSuccessResponse(http.Response response) {
    dynamic servidorId;
    String mensaje = 'Operación exitosa';

    try {
      final responseBody = json.decode(response.body);

      servidorId = responseBody['estado']?['id'] ??
          responseBody['id'] ??
          responseBody['insertId'];

      if (responseBody['message'] != null) {
        mensaje = responseBody['message'].toString();
      }
    } catch (e) {
      logger.w('⚠️ No se pudo parsear response body: $e');
    }

    return {
      'exito': true,
      'success': true,
      'id': servidorId,
      'servidor_id': servidorId,
      'mensaje': mensaje,
    };
  }

  /// Método de conveniencia para logs
  static Future<void> logRequest({
    required String endpoint,
    required Map<String, dynamic> body,
    String? additionalInfo,
  }) async {
    logger.i('═══════════════════════════════════════');
    logger.i('🚀 REQUEST POST');
    logger.i('📍 Endpoint: $endpoint');
    if (additionalInfo != null) {
      logger.i('ℹ️  Info: $additionalInfo');
    }
    logger.i('📦 Body: ${json.encode(body)}');
    logger.i('═══════════════════════════════════════');
  }

  /// Helper para obtener baseUrl
  static Future<String> getBaseUrl() async {
    return await ApiConfigService.getBaseUrl();
  }
}