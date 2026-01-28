import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:ada_app/config/constants/server_response.dart';

import 'package:ada_app/repositories/producto_repository.dart';

import 'package:ada_app/services/api/api_config_service.dart';
import 'package:ada_app/services/error_log/error_log_service.dart';
import 'package:ada_app/services/network/monitored_http_client.dart';

import 'package:ada_app/models/operaciones_comerciales/operacion_comercial.dart';
import 'package:ada_app/models/operaciones_comerciales/operacion_comercial_detalle.dart';
import 'package:ada_app/models/operaciones_comerciales/enums/tipo_operacion.dart';
import 'package:ada_app/repositories/operacion_comercial_detalle_repository.dart';

/// Formatea DateTime sin 'T' ni 'Z' para el backend
/// Formato: "yyyy-MM-dd HH:mm:ss.SSSSSS"
String _formatTimestampForBackend(DateTime dt) {
  String year = dt.year.toString().padLeft(4, '0');
  String month = dt.month.toString().padLeft(2, '0');
  String day = dt.day.toString().padLeft(2, '0');
  String hour = dt.hour.toString().padLeft(2, '0');
  String minute = dt.minute.toString().padLeft(2, '0');
  String second = dt.second.toString().padLeft(2, '0');
  String microsecond = dt.microsecond.toString().padLeft(6, '0');

  return '$year-$month-$day $hour:$minute:$second.$microsecond';
}

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
      //TODO cargar objeto operacion.detalles desde una consulta a operacon_detalles where operacion_id = operacion.id
      // Re-cargar detalles desde BD para asegurar consistencia
      final detallesDesdeDB = await OperacionComercialDetalleRepositoryImpl()
          .obtenerDetallesPorOperacionId(operacion.id!);

      // Crear nueva instancia con detalles recargados
      operacion = operacion.copyWith(detalles: detallesDesdeDB);

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

      final jsonBody = jsonEncode(payload);
      debugPrint('DEBUG OPERACION TIMESTAMP - Payload: $jsonBody');

      final response = await MonitoredHttpClient.post(
        url: Uri.parse(fullUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonBody,
        timeout: Duration(seconds: timeoutSegundos),
      );

      ServerResponse resultObject = ServerResponse.fromHttp(response);

      if (!resultObject.success) {
        if (resultObject.isDuplicate) {
          // Retornar sin lanzar excepción para duplicados
          return resultObject;
        } else if (resultObject.message != '') {
          // Lanzar excepción para que el catch la maneje
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
      'fechaCreacion': _formatTimestampForBackend(operacion.fechaCreacion),
      'fechaRetiro': operacion.fechaRetiro != null
          ? _formatTimestampForBackend(operacion.fechaRetiro!)
          : null,
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
