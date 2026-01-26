import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ada_app/models/data_usage_record.dart';
import 'package:ada_app/services/data/data_usage_service.dart';
import 'package:flutter/foundation.dart';

/// Cliente HTTP que monitorea el consumo de datos
class MonitoredHttpClient {
  static final DataUsageService _dataUsageService = DataUsageService();

  /// Realiza una petición POST monitoreando el consumo de datos
  static Future<http.Response> post({
    required Uri url,
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    Duration? timeout,
  }) async {
    int bytesSent = 0;
    int bytesReceived = 0;
    int? statusCode;
    String? errorMessage;

    try {
      // Calcular bytes enviados (aproximado)
      bytesSent = _estimateRequestSize(url, headers, body);

      // Realizar la petición
      final request = timeout != null
          ? http
                .post(url, headers: headers, body: body, encoding: encoding)
                .timeout(timeout)
          : http.post(url, headers: headers, body: body, encoding: encoding);

      final response = await request;

      // Calcular bytes recibidos
      statusCode = response.statusCode;
      bytesReceived = _estimateResponseSize(response);

      // Registrar el uso de datos
      await _recordUsage(
        endpoint: url.toString(),
        operationType: 'post',
        bytesSent: bytesSent,
        bytesReceived: bytesReceived,
        statusCode: statusCode,
      );

      return response;
    } catch (e) {
      errorMessage = e.toString();

      // Registrar incluso si hay error
      await _recordUsage(
        endpoint: url.toString(),
        operationType: 'post',
        bytesSent: bytesSent,
        bytesReceived: bytesReceived,
        statusCode: statusCode,
        errorMessage: errorMessage,
      );

      rethrow;
    }
  }

  /// Realiza una petición GET monitoreando el consumo de datos
  static Future<http.Response> get({
    required Uri url,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    int bytesSent = 0;
    int bytesReceived = 0;
    int? statusCode;
    String? errorMessage;

    try {
      // Calcular bytes enviados (solo headers)
      bytesSent = _estimateRequestSize(url, headers, null);

      // Realizar la petición
      final request = timeout != null
          ? http.get(url, headers: headers).timeout(timeout)
          : http.get(url, headers: headers);

      final response = await request;

      // Calcular bytes recibidos
      statusCode = response.statusCode;
      bytesReceived = _estimateResponseSize(response);

      // Registrar el uso de datos
      await _recordUsage(
        endpoint: url.toString(),
        operationType: 'get',
        bytesSent: bytesSent,
        bytesReceived: bytesReceived,
        statusCode: statusCode,
      );

      return response;
    } catch (e) {
      errorMessage = e.toString();

      // Registrar incluso si hay error
      await _recordUsage(
        endpoint: url.toString(),
        operationType: 'get',
        bytesSent: bytesSent,
        bytesReceived: bytesReceived,
        statusCode: statusCode,
        errorMessage: errorMessage,
      );

      rethrow;
    }
  }

  /// Registrar el uso de datos
  static Future<void> _recordUsage({
    required String endpoint,
    required String operationType,
    required int bytesSent,
    required int bytesReceived,
    int? statusCode,
    String? errorMessage,
  }) async {
    try {
      final record = DataUsageRecord(
        timestamp: DateTime.now(),
        operationType: operationType,
        endpoint: endpoint,
        bytesSent: bytesSent,
        bytesReceived: bytesReceived,
        totalBytes: bytesSent + bytesReceived,
        statusCode: statusCode,
        errorMessage: errorMessage,
      );

      await _dataUsageService.recordUsage(record);
    } catch (e) {
      // No queremos que un error al registrar rompa la app
      debugPrint('Error registrando uso de datos: $e');
    }
  }

  /// Estimar tamaño de la petición
  static int _estimateRequestSize(
    Uri url,
    Map<String, String>? headers,
    Object? body,
  ) {
    int size = 0;

    // URL y método
    size += url.toString().length + 10; // "POST " o "GET " + URL

    // Headers (estimado)
    if (headers != null) {
      headers.forEach((key, value) {
        size += key.length + value.length + 4; // ": " + "\r\n"
      });
    }
    size += 50; // Headers estándar adicionales

    // Body
    if (body != null) {
      if (body is String) {
        size += body.length;
      } else if (body is List<int>) {
        size += body.length;
      } else {
        size += body.toString().length;
      }
    }

    return size;
  }

  /// Estimar tamaño de la respuesta
  static int _estimateResponseSize(http.Response response) {
    int size = 0;

    // Status line
    size += 15; // "HTTP/1.1 200 OK"

    // Headers (estimado)
    response.headers.forEach((key, value) {
      size += key.length + value.length + 4;
    });

    // Body
    size += response.bodyBytes.length;

    return size;
  }
}
