import 'dart:convert';
import '../../utils/logger.dart';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:ada_app/services/api/api_config_service.dart';
import 'package:ada_app/services/network/monitored_http_client.dart';

abstract class BaseSyncService {
  static const Duration timeout = Duration(minutes: 2);

  static Future<String> getBaseUrl() async {
    return await ApiConfigService.getBaseUrl();
  }

  static Map<String, String> get headers => {
    'Content-Type': 'application/json; charset=UTF-8',
    'Accept': 'application/json',
    'ngrok-skip-browser-warning': 'true',
  };

  static List<dynamic> parseResponse(String responseBody) {
    try {
      final responseData = jsonDecode(responseBody.trim());

      if (responseData is Map<String, dynamic>) {
        if (responseData.containsKey('data')) {
          final data = responseData['data'];

          if (data is String) {
            final decodedData = jsonDecode(data);
            if (decodedData is List) {
              return decodedData;
            }
          }

          if (data is List) {
            return data;
          }

          if (data is Map<String, dynamic>) {
            final knownFields = [
              'equipos',
              'asignaciones',
              'clientes',
              'estados',
            ];
            for (final field in knownFields) {
              if (data.containsKey(field) && data[field] is List) {
                return data[field] as List;
              }
            }

            for (final entry in data.entries) {
              if (entry.value is List) {
                return entry.value as List;
              }
            }
          }
        }
        return [];
      }

      if (responseData is List) {
        return responseData;
      }

      return [];
    } catch (e) { AppLogger.e("BASE_SYNC_SERVICE: Error", e); return []; }
  }

  static String extractErrorMessage(http.Response response) {
    try {
      if (response.body.trim().isEmpty) {
        return 'Error del servidor (${response.statusCode})';
      }

      final errorData = jsonDecode(response.body) as Map<String, dynamic>;
      return errorData['message'] ??
          errorData['error'] ??
          errorData['mensaje'] ??
          'Error del servidor (${response.statusCode})';
    } catch (e) { AppLogger.e("BASE_SYNC_SERVICE: Error", e); return 'Error del servidor (${response.statusCode}): ${response.body.length > 100 ? '${response.body.substring(0, 100)}...' : response.body}'; }
  }

  static String getErrorMessage(dynamic error) {
    if (error is SocketException) {
      return 'Sin conexión al servidor. Verifica que estés en la misma red WiFi.';
    } else if (error is TimeoutException) {
      return 'Tiempo de espera agotado. Verifica que el servidor esté ejecutándose.';
    } else if (error is HttpException) {
      return 'Error en la comunicación con el servidor.';
    } else {
      return 'Error inesperado: ${error.toString()}';
    }
  }

  static Future<ApiResponse> testConnection() async {
    try {
      final baseUrl = await getBaseUrl();

      final response = await MonitoredHttpClient.get(
        url: Uri.parse('$baseUrl/api/getPing'),
        headers: headers,
        timeout: const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        Map<String, dynamic>? serverInfo;

        try {
          if (response.body.trim().isNotEmpty) {
            final responseData = jsonDecode(response.body);
            serverInfo = {
              'status': responseData['status'] ?? 'OK',
              'endpoint': 'getPing',
              'hasData': responseData['data'] != null,
            };
          }
        } catch (e) { AppLogger.e("BASE_SYNC_SERVICE: Error", e); }

        return ApiResponse(
          exito: true,
          mensaje: 'Conexión exitosa con el servidor ($baseUrl)',
          datos: serverInfo,
        );
      } else {
        return ApiResponse(
          exito: false,
          mensaje: 'Servidor no disponible (${response.statusCode})',
          codigoEstado: response.statusCode,
        );
      }
    } catch (e) { AppLogger.e("BASE_SYNC_SERVICE: Error", e); return ApiResponse(exito: false, mensaje: getErrorMessage(e)); }
  }
}

// Clases de resultado reutilizables
class SyncResult {
  final bool exito;
  final String mensaje;
  final int itemsSincronizados;
  final int totalEnAPI;

  SyncResult({
    required this.exito,
    required this.mensaje,
    required this.itemsSincronizados,
    this.totalEnAPI = 0,
  });

  @override
  String toString() {
    return 'SyncResult(exito: $exito, mensaje: $mensaje, sincronizados: $itemsSincronizados, total: $totalEnAPI)';
  }
}

class ApiResponse {
  final bool exito;
  final String mensaje;
  final Map<String, dynamic>? datos;
  final int? codigoEstado;

  ApiResponse({
    required this.exito,
    required this.mensaje,
    this.datos,
    this.codigoEstado,
  });

  @override
  String toString() {
    return 'ApiResponse(exito: $exito, mensaje: $mensaje, codigo: $codigoEstado)';
  }
}

// Agregar esta clase a base_sync_service.dart
class SyncResultWithData {
  final bool exito;
  final String mensaje;
  final int itemsSincronizados;
  final int totalEnAPI;
  final dynamic data; // Los datos obtenidos

  SyncResultWithData({
    required this.exito,
    required this.mensaje,
    required this.itemsSincronizados,
    this.totalEnAPI = 0,
    this.data,
  });

  @override
  String toString() {
    return 'SyncResultWithData(exito: $exito, mensaje: $mensaje, sincronizados: $itemsSincronizados, total: $totalEnAPI)';
  }
}
