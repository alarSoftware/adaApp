// lib/services/post/base_post_service.dart

import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:ada_app/services/api_config_service.dart';

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
  }) async {
    try {
      final baseUrl = await ApiConfigService.getBaseUrl();
      final fullUrl = '$baseUrl$endpoint';

      final jsonBody = json.encode(body);

      logger.i('📤 POST a $fullUrl');
      logger.i('📦 Body size: ${jsonBody.length} caracteres');

      final response = await http.post(
        Uri.parse(fullUrl),
        headers: customHeaders ?? headers,
        body: jsonBody,
      ).timeout(timeout);

      logger.i('📥 Response: ${response.statusCode}');

      return _processResponse(response);

    } on http.ClientException catch (e) {
      return {
        'exito': false,
        'mensaje': 'Error de red: ${e.message}',
      };
    } on TimeoutException catch (_) {
      return {
        'exito': false,
        'mensaje': 'Tiempo de espera agotado',
      };
    } catch (e) {
      logger.e('❌ Error en POST: $e');
      return {
        'exito': false,
        'mensaje': 'Error de conexión: $e',
      };
    }
  }

  /// Procesar respuesta HTTP
  static Map<String, dynamic> _processResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _processSuccessResponse(response);
    } else {
      return {
        'exito': false,
        'mensaje': 'Error del servidor: ${response.statusCode}',
        'detalle': response.body,
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
}