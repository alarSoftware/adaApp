import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:ada_app/services/api_config_service.dart';
import 'package:ada_app/config/constants/server_constants.dart';
import 'package:ada_app/services/error_log/error_log_service.dart';
import 'package:ada_app/models/operaciones_comerciales/operacion_comercial.dart';
import 'package:ada_app/models/operaciones_comerciales/operacion_comercial_detalle.dart';
import 'package:ada_app/models/operaciones_comerciales/enums/tipo_operacion.dart';

class OperacionesComercialesPostService {
  static final Logger _logger = Logger();
  static const String _tableName = 'operaciones_comerciales';
  // Endpoint solicitado por el usuario
  static const String _endpoint = '/insertOperacionesComerciales';

  static Future<Map<String, dynamic>> enviarOperacion(OperacionComercial operacion) async {
    String? fullUrl;
    String? operacionId = operacion.id;

    try {
      _logger.i('📤 === ENVIANDO OPERACIÓN COMERCIAL ===');
      _logger.i('   - Cliente ID: ${operacion.clienteId}');
      _logger.i('   - Tipo: ${operacion.tipoOperacion.valor}');

      final payload = _construirPayload(operacion);

      _logger.i('📦 Payload size: ${jsonEncode(payload).length} caracteres');

      // Obtener URL base
      final baseUrl = await ApiConfigService.getBaseUrl();
      // Asegurar que no haya doble slash si baseUrl termina en /
      final cleanBaseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
      fullUrl = '$cleanBaseUrl$_endpoint';

      _logger.i('🌐 Enviando a: $fullUrl');

      // Envío HTTP
      final response = await http.post(
        Uri.parse(fullUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 60));

      _logger.i('📥 Response: ${response.statusCode}');

      // Procesar respuesta
      final result = _procesarRespuesta(response);

      if (!result['exito']) {
        await _manejarErrorServidor(result, operacionId, fullUrl, operacion.usuarioId?.toString());
      }

      return result;

    } catch (e, stackTrace) {
      _logger.e('❌ Error en envío de operación comercial: $e', stackTrace: stackTrace);
      return await _manejarExcepcion(e, operacionId, fullUrl, operacion.usuarioId?.toString());
    }
  }

  // =================================================================
  // CONSTRUCCIÓN DEL PAYLOAD
  // =================================================================

  static Map<String, dynamic> _construirPayload(OperacionComercial operacion) {
    return {
      'operacionComercial': {
        'id': operacion.id,
        'clienteId': operacion.clienteId,
        'tipoOperacion': operacion.tipoOperacion.valor,
        'fechaCreacion': operacion.fechaCreacion.toIso8601String(),
        'fechaRetiro': operacion.fechaRetiro?.toIso8601String(),
        'usuarioId': operacion.usuarioId,
        'totalProductos': operacion.totalProductos,
        'detalles': operacion.detalles.map((d) => _construirDetalle(d, operacion.tipoOperacion)).toList(),
      }
    };
  }

  static Map<String, dynamic> _construirDetalle(
    OperacionComercialDetalle detalle,
    TipoOperacion tipoOperacion,
  ) {
    // Estructura base del detalle
    final detalleBase = {
      'productoCodigo': detalle.productoCodigo,
      'productoDescripcion': detalle.productoDescripcion,
      'productoCategoria': detalle.productoCategoria,
      'productoId': detalle.productoId,
      'cantidad': detalle.cantidad,
      'unidadMedida': detalle.unidadMedida,
    };

    // Si es producto discontinuo (intercambio), usar estructura anidada con array
    if (tipoOperacion == TipoOperacion.notaRetiroDiscontinuos) {
      // Solo agregar productoIntercambio si hay datos de reemplazo
      if (detalle.productoReemplazoId != null) {
        detalleBase['productoIntercambio'] = [
          {
            'productoId': detalle.productoReemplazoId,
            'productoCodigo': detalle.productoReemplazoCodigo,
            'productoDescripcion': detalle.productoReemplazoDescripcion,
            'productoCategoria': detalle.productoReemplazoCategoria,
            'cantidad': detalle.cantidad,
          }
        ];
      }
    }
    // Para otros tipos (NOTA_RETIRO, NOTA_REPOSICION), no se incluyen datos de reemplazo
    
    return detalleBase;
  }

  // =================================================================
  // MANEJO DE RESPUESTAS Y ERRORES
  // =================================================================

  static Map<String, dynamic> _procesarRespuesta(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return {
        'exito': false,
        'mensaje': 'Error del servidor: ${response.statusCode}',
        'status_code': response.statusCode,
      };
    }

    try {
      final responseBody = json.decode(response.body);

      // Si el backend devuelve una estructura estándar con serverAction
      if (responseBody is Map && responseBody.containsKey('serverAction')) {
        final serverAction = responseBody['serverAction'];
        
        if (serverAction == ServerConstants.SUCCESS_TRANSACTION) {
          return {
            'exito': true,
            'mensaje': responseBody['resultMessage'] ?? 'Operación procesada correctamente',
            'serverAction': serverAction,
            'id': responseBody['resultId'],
          };
        } else {
          return {
            'exito': false,
            'mensaje': responseBody['resultError'] ?? responseBody['resultMessage'] ?? 'Error del servidor',
            'serverAction': serverAction,
          };
        }
      }

      // Fallback genérico
      return {
        'exito': true,
        'mensaje': 'Operación enviada correctamente',
        'data': responseBody,
      };

    } catch (e) {
      return {
        'exito': false,
        'mensaje': 'Error al procesar respuesta del servidor',
      };
    }
  }

  static Future<void> _manejarErrorServidor(
      Map<String, dynamic> result,
      String? operacionId,
      String? fullUrl,
      String? userId,
      ) async {
    final errorCode = result['serverAction']?.toString() ?? 'UNKNOWN';
    final errorMessage = result['mensaje'] ?? 'Error del servidor';

    await ErrorLogService.logServerError(
      tableName: _tableName,
      operation: 'POST_OPERACION_COMERCIAL_ERROR',
      errorMessage: 'ServerAction $errorCode: $errorMessage',
      errorCode: 'SERVER_ERROR_$errorCode',
      registroFailId: operacionId,
      endpoint: fullUrl,
      userId: userId,
    );
  }

  static Future<Map<String, dynamic>> _manejarExcepcion(
      dynamic excepcion,
      String? operacionId,
      String? fullUrl,
      String? userId,
      ) async {
    
    String tipoError = 'crash';
    String codigoError = 'UNEXPECTED_EXCEPTION';
    String mensajeUsuario = 'Error interno al enviar operación';

    if (excepcion is SocketException || excepcion is http.ClientException) {
      tipoError = 'network';
      codigoError = 'NETWORK_ERROR';
      mensajeUsuario = 'Error de conexión. Verifique su internet.';
    } else if (excepcion is TimeoutException) {
      tipoError = 'network';
      codigoError = 'TIMEOUT_ERROR';
      mensajeUsuario = 'El servidor tardó demasiado en responder.';
    }

    await ErrorLogService.logError(
      tableName: _tableName,
      operation: 'POST_OPERACION_COMERCIAL_EXCEPTION',
      errorMessage: excepcion.toString(),
      errorType: tipoError,
      errorCode: codigoError,
      registroFailId: operacionId,
      endpoint: fullUrl,
      userId: userId,
    );

    return {
      'exito': false,
      'mensaje': mensajeUsuario,
      'error': excepcion.toString(),
    };
  }
}
