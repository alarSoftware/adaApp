import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:ada_app/config/constants/server_response.dart';
import 'package:ada_app/repositories/operacion_comercial_repository.dart';
import 'package:http/http.dart' as http;

import 'package:ada_app/services/api_config_service.dart';
import 'package:ada_app/config/constants/server_constants.dart';
import 'package:ada_app/services/error_log/error_log_service.dart';
import 'package:ada_app/models/operaciones_comerciales/operacion_comercial.dart';
import 'package:ada_app/models/operaciones_comerciales/operacion_comercial_detalle.dart';
import 'package:ada_app/models/operaciones_comerciales/enums/tipo_operacion.dart';

class OperacionesComercialesPostService {
  static const String _endpoint =
      '/operacionComercial/insertOperacionComercial';

  static Future<void> enviarOperacion(
      OperacionComercial operacion, {
        int timeoutSegundos = 60,
      }) async {
    String? fullUrl;
    try {
      if (operacion.id == null || operacion.id!.isEmpty) {
        throw Exception('ID de operación es requerido');
      }
      if (operacion.detalles.isEmpty) {
        throw Exception('La operación debe tener al menos un detalle');
      }

      final payload = _construirPayload(operacion);
      final baseUrl = await ApiConfigService.getBaseUrl();
      final cleanBaseUrl = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;
      fullUrl = '$cleanBaseUrl$_endpoint';

      final response = await http
          .post(
        Uri.parse(fullUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode(payload),
      )
          .timeout(Duration(seconds: timeoutSegundos));

      ServerResponse resultObject = ServerResponse.fromHttp(response);

      if (!resultObject.success) {
        if (!resultObject.isDuplicate && resultObject.message != '') {
          throw Exception(resultObject.message);
        }
      }

      // Éxito
      if (resultObject.success || resultObject.isDuplicate) {
      }
    } catch (e) {
      //TODO escalar error
      rethrow;
    }
  }
  static Map<String, dynamic> _construirPayload(OperacionComercial operacion) {
    final operacionComercialData = {
      'id': operacion.id,
      'clienteId': operacion.clienteId,
      'tipoOperacion': operacion.tipoOperacion.valor,
      'fechaCreacion': operacion.fechaCreacion.toIso8601String(),
      'fechaRetiro': operacion.fechaRetiro?.toIso8601String(),
      'usuarioId': operacion.usuarioId,
      'totalProductos': operacion.totalProductos,
    };

    final detalles = operacion.detalles
        .map((d) => _construirDetalle(d, operacion.tipoOperacion))
        .toList();

    return {
      'operacionComercial': operacionComercialData,
      ...operacionComercialData,
      'detalles': detalles,
    };
  }

  static Map<String, dynamic> _construirDetalle(
    OperacionComercialDetalle detalle,
    TipoOperacion tipoOperacion,
  ) {
    final detalleBase = {
      'productoCodigo': detalle.productoCodigo,
      'productoDescripcion': detalle.productoDescripcion,
      'productoCategoria': detalle.productoCategoria,
      'productoId': detalle.productoId,
      'cantidad': detalle.cantidad,
      'unidadMedida': detalle.unidadMedida,
    };

    if (tipoOperacion == TipoOperacion.notaRetiroDiscontinuos &&
        detalle.productoReemplazoId != null) {
      detalleBase['productoIntercambio'] = [
        {
          'productoId': detalle.productoReemplazoId,
          'productoCodigo': detalle.productoReemplazoCodigo,
          'productoDescripcion': detalle.productoReemplazoDescripcion,
          'productoCategoria': detalle.productoReemplazoCategoria,
          'cantidad': detalle.cantidad,
        },
      ];
    }

    return detalleBase;
  }

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

      if (responseBody is Map && responseBody.containsKey('serverAction')) {
        final serverAction = responseBody['serverAction'];
        final mensaje = responseBody['resultMessage'] ?? '';
        final error = responseBody['resultError'] ?? '';

        if (serverAction == ServerConstants.SUCCESS_TRANSACTION) {
          return {
            'exito': true,
            'mensaje': mensaje.isNotEmpty
                ? mensaje
                : 'Operación procesada correctamente',
            'serverAction': serverAction,
            'id': responseBody['resultId'],
          };
        } else if (_esDuplicado(mensaje) || _esDuplicado(error)) {
          return {
            'exito': true,
            'duplicado': true,
            'mensaje': mensaje.isNotEmpty ? mensaje : error,
            'serverAction': serverAction,
          };
        } else {
          return {
            'exito': false,
            'mensaje': error.isNotEmpty
                ? error
                : mensaje.isNotEmpty
                ? mensaje
                : 'Error del servidor',
            'serverAction': serverAction,
          };
        }
      }

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

  static bool _esDuplicado(String mensaje) {
    if (mensaje.isEmpty) return false;

    final mensajeLower = mensaje.toLowerCase();
    return mensajeLower.contains('duplicado') ||
        mensajeLower.contains('duplicate') ||
        mensajeLower.contains('ya existe') ||
        mensajeLower.contains('already exists');
  }

  static String _obtenerMensajeUsuario(dynamic excepcion) {
    if (excepcion is SocketException || excepcion is http.ClientException) {
      return 'Error de conexión. Verifique su internet.';
    } else if (excepcion is TimeoutException) {
      return 'El servidor tardó demasiado en responder.';
    }
    return 'Error interno al enviar operación';
  }
}
