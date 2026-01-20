import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:ada_app/config/constants/server_response.dart';

import 'package:ada_app/repositories/producto_repository.dart';
import 'package:http/http.dart' as http;

import 'package:ada_app/services/api/api_config_service.dart';
import 'package:ada_app/services/error_log/error_log_service.dart';

import 'package:ada_app/models/operaciones_comerciales/operacion_comercial.dart';
import 'package:ada_app/models/operaciones_comerciales/operacion_comercial_detalle.dart';
import 'package:ada_app/models/operaciones_comerciales/enums/tipo_operacion.dart';

class OperacionesComercialesPostService {
  static const String _endpoint =
      '/operacionComercial/insertOperacionComercial';
  static const String _tableName = 'operacion_comercial';

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
        if (resultObject.isDuplicate) {
          // Log duplicado pero NO lanzar excepción
          await ErrorLogService.logServerError(
            tableName: _tableName,
            operation: 'enviar_operacion',
            errorMessage: 'ID duplicado: ${resultObject.message}',
            errorCode: 'DUPLICATE_ID',
            endpoint: fullUrl,
            registroFailId: operacion.id,
          );
          // Retornar sin lanzar excepción
        } else if (resultObject.message != '') {
          // Log error del servidor y lanzar excepción
          await ErrorLogService.logServerError(
            tableName: _tableName,
            operation: 'enviar_operacion',
            errorMessage: resultObject.message,
            errorCode: response.statusCode.toString(),
            endpoint: fullUrl,
            registroFailId: operacion.id,
          );
          throw Exception(resultObject.message);
        }
      }

      return resultObject;
    } catch (e) {
      await ErrorLogService.manejarExcepcion(
        e,
        operacion.id,
        fullUrl,
        operacion.usuarioId,
        _tableName,
      );
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

  static Map<String, String?> parsearRespuestaJson(String? resultJson) {
    String? odooName;
    String? adaSequence;

    if (resultJson != null) {
      try {
        final jsonMap = jsonDecode(resultJson);
        odooName = jsonMap['name'] as String? ?? jsonMap['odooName'] as String?;

        adaSequence =
            jsonMap['sequence'] as String? ??
            jsonMap['adaSequence'] as String? ??
            jsonMap['ada_sequence'] as String?;
      } catch (e) {
        debugPrint('Error al analizar el JSON: $e');
      }
    }

    return {'odooName': odooName, 'adaSequence': adaSequence};
  }
}
