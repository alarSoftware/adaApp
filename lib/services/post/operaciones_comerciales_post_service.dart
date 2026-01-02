import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:ada_app/config/constants/server_response.dart';

import 'package:ada_app/repositories/producto_repository.dart';
import 'package:http/http.dart' as http;

import 'package:ada_app/services/api/api_config_service.dart';
import 'package:ada_app/config/constants/server_constants.dart';

import 'package:ada_app/models/operaciones_comerciales/operacion_comercial.dart';
import 'package:ada_app/models/operaciones_comerciales/operacion_comercial_detalle.dart';
import 'package:ada_app/models/operaciones_comerciales/enums/tipo_operacion.dart';

class OperacionesComercialesPostService {
  static const String _endpoint =
      '/operacionComercial/insertOperacionComercial';

  static Future<ServerResponse> enviarOperacion(
    OperacionComercial operacion, {
    int timeoutSegundos = 60,
    ProductoRepository? productoRepository,
  }) async {
    String? fullUrl;
    try {
      if (operacion.id == null || operacion.id!.isEmpty) {
        throw Exception('ID de operación es requerido');
      }
      if (operacion.detalles.isEmpty) {
        throw Exception('La operación debe tener al menos un detalle');
      }

      final repo = productoRepository ?? ProductoRepositoryImpl();
      final payload = await _construirPayload(operacion, repo);

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

      return resultObject;
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> _construirPayload(
    OperacionComercial operacion,
    ProductoRepository productoRepository,
  ) async {
    final operacionComercialData = {
      'id': operacion.id,
      'clienteId': operacion.clienteId,
      'tipoOperacion': operacion.tipoOperacion.valor,
      'fechaCreacion': operacion.fechaCreacion.toIso8601String(),
      'fechaRetiro': operacion.fechaRetiro?.toIso8601String(),
      if (operacion.snc != null) 'snc': operacion.snc,
      'usuarioId': operacion.usuarioId,
      'totalProductos': operacion.totalProductos,
      'employeeId': operacion.employeeId,
      'latitud': operacion.latitud,
      'longitud': operacion.longitud,
    };

    final detalles = await Future.wait(
      operacion.detalles.map(
        (d) =>
            _construirDetalle(d, operacion.tipoOperacion, productoRepository),
      ),
    );

    return {
      'operacionComercial': operacionComercialData,
      ...operacionComercialData,
      'detalles': detalles,
    };
  }

  static Future<Map<String, dynamic>> _construirDetalle(
    OperacionComercialDetalle detalle,
    TipoOperacion tipoOperacion,
    ProductoRepository productoRepository,
  ) async {
    final producto = await productoRepository.obtenerProductoPorId(
      detalle.productoId!,
    );

    if (producto == null) {
      throw Exception('Producto con ID ${detalle.productoId} no encontrado');
    }

    final detalleBase = {
      'productoCodigo': producto.codigo,
      'productoDescripcion': producto.nombre,
      'productoCategoria': producto.categoria,
      'productoId': detalle.productoId,
      'cantidad': detalle.cantidad,
      'unidadMedida': producto.unidadMedida,
    };

    if (tipoOperacion == TipoOperacion.notaRetiroDiscontinuos &&
        detalle.productoReemplazoId != null) {
      final productoReemplazo = await productoRepository.obtenerProductoPorId(
        detalle.productoReemplazoId!,
      );

      if (productoReemplazo != null) {
        detalleBase['productoIntercambio'] = [
          {
            'productoId': detalle.productoReemplazoId,
            'productoCodigo': productoReemplazo.codigo,
            'productoDescripcion': productoReemplazo.nombre,
            'productoCategoria': productoReemplazo.categoria,
            'cantidad': detalle.cantidad,
          },
        ];
      }
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
