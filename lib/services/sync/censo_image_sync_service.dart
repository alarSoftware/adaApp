import 'dart:convert';
import '../../utils/logger.dart';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/services/data/database_helper.dart';
import 'package:ada_app/services/error_log/error_log_service.dart';

/// Servicio para sincronización de imágenes de censos
/// Simplificado para solo traer fotos del API y guardarlas
class CensusImageSyncService extends BaseSyncService {
  /// Método principal: Obtiene y guarda fotos de censos
  static Future<SyncResult> obtenerFotosCensos({
    String? employeeId,
    int? censoActivoId,
    String? uuid,
    int? limit,
    int? offset,
    bool incluirBase64 = true,
  }) async {
    String? currentEndpoint;

    try {
      final queryParams = _buildQueryParams(
        employeeId: employeeId,
        censoActivoId: censoActivoId,
        uuid: uuid,
        limit: limit,
        offset: offset,
        incluirBase64: incluirBase64,
      );

      final response = await _makeHttpRequest(queryParams);
      currentEndpoint = response.request?.url.toString();

      if (!_isSuccessStatusCode(response.statusCode)) {
        // 🚨 LOG ERROR: Error del servidor
        // await ErrorLogService.logServerError(
        //   tableName: 'censo_activo_foto',
        //   operation: 'sync_from_server',
        //   errorMessage: BaseSyncService.extractErrorMessage(response),
        //   errorCode: response.statusCode.toString(),
        //   endpoint: currentEndpoint,
        //   userId: edfVendedorId,
        // );

        return _handleErrorResponse(response);
      }

      final imagenesData = await _parseImageResponse(response);
      final processedResult = await _processAndSaveImages(
        imagenesData,
        incluirBase64,
      );

      return SyncResult(
        exito: true,
        mensaje: 'Fotos obtenidas correctamente',
        itemsSincronizados: processedResult.length,
        totalEnAPI: processedResult.length,
      );
    } on TimeoutException catch (timeoutError) {
      // LOG ERROR: Timeout
      // await ErrorLogService.logNetworkError(
      //   tableName: 'censo_activo_foto',
      //   operation: 'sync_from_server',
      //   errorMessage: 'Timeout de conexión: $timeoutError',
      //   endpoint: currentEndpoint,
      //   userId: edfVendedorId,
      // );

      return SyncResult(
        exito: false,
        mensaje: 'Timeout de conexión al servidor',
        itemsSincronizados: 0,
      );
    } on SocketException catch (socketError) {
      // LOG ERROR: Sin conexión de red
      // await ErrorLogService.logNetworkError(
      //   tableName: 'censo_activo_foto',
      //   operation: 'sync_from_server',
      //   errorMessage: 'Sin conexión de red: $socketError',
      //   endpoint: currentEndpoint,
      //   userId: edfVendedorId,
      // );

      return SyncResult(
        exito: false,
        mensaje: 'Sin conexión de red',
        itemsSincronizados: 0,
      );
    } catch (e) {
      // LOG ERROR: Error general
      // await ErrorLogService.logError(
      //   tableName: 'censo_activo_foto',
      //   operation: 'sync_from_server',
      //   errorMessage: 'Error general: $e',
      //   errorType: 'unknown',
      //   errorCode: 'GENERAL_ERROR',
      //   endpoint: currentEndpoint,
      //   userId: edfVendedorId,
      // );

      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

  // ========== MÉTODOS PRIVADOS ==========

  /// Construir parámetros de consulta
  static Map<String, String> _buildQueryParams({
    String? employeeId,
    int? censoActivoId,
    String? uuid,
    int? limit,
    int? offset,
    bool incluirBase64 = true,
  }) {
    final Map<String, String> queryParams = {};

    if (employeeId != null) queryParams['employeeId'] = employeeId;
    if (censoActivoId != null)
      queryParams['censoActivoId'] = censoActivoId.toString();
    if (limit != null) queryParams['limit'] = limit.toString();
    if (offset != null) queryParams['offset'] = offset.toString();
    if (uuid != null) queryParams['uuid'] = uuid;
    if (incluirBase64) queryParams['includeBase64'] = 'true';

    return queryParams;
  }

  /// Realizar petición HTTP
  static Future<http.Response> _makeHttpRequest(
    Map<String, String> queryParams,
  ) async {
    final baseUrl = await BaseSyncService.getBaseUrl();
    final uri = Uri.parse(
      '$baseUrl/api/getCensoActivoFoto',
    ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    return await http
        .get(uri, headers: BaseSyncService.headers)
        .timeout(BaseSyncService.timeout);
  }

  /// Verificar si el código de estado es exitoso
  static bool _isSuccessStatusCode(int statusCode) {
    return statusCode >= 200 && statusCode < 300;
  }

  /// Manejar respuesta de error
  static SyncResult _handleErrorResponse(http.Response response) {
    final mensaje = BaseSyncService.extractErrorMessage(response);
    return SyncResult(
      exito: false,
      mensaje: 'Error del servidor: $mensaje',
      itemsSincronizados: 0,
    );
  }

  /// Parsear respuesta de imágenes
  static Future<List<dynamic>> _parseImageResponse(
    http.Response response,
  ) async {
    try {
      final responseBody = jsonDecode(response.body);

      if (responseBody is Map<String, dynamic>) {
        final status = responseBody['status'];
        if (status != 'OK') {
          return [];
        }

        final dataValue = responseBody['data'];
        if (dataValue == null) return [];

        if (dataValue is String) {
          try {
            final parsed = jsonDecode(dataValue) as List;
            return parsed;
          } catch (e) {
            // LOG ERROR: Error de parsing
            await ErrorLogService.logError(
              tableName: 'censo_activo_foto',
              operation: 'parse_response',
              errorMessage: 'Error parseando data string: $e',
              errorType: 'server',
              errorCode: 'PARSE_ERROR',
            );

            return [];
          }
        } else if (dataValue is List) {
          return dataValue;
        }

        return [];
      } else if (responseBody is List) {
        return responseBody;
      }

      return [];
    } catch (e) {
      // LOG ERROR: Error de parsing general
      await ErrorLogService.logError(
        tableName: 'censo_activo_foto',
        operation: 'parse_response',
        errorMessage: 'Error parseando respuesta del servidor: $e',
        errorType: 'server',
        errorCode: 'PARSE_ERROR',
      );

      throw Exception('Error parseando respuesta del servidor: $e');
    }
  }

  /// Procesar y guardar imágenes en la tabla censo_activo_foto
  static Future<List<Map<String, dynamic>>> _processAndSaveImages(
    List<dynamic> imagenesData,
    bool incluirBase64,
  ) async {
    // Convertir datos del API al formato local
    final imagenesParaGuardar = <Map<String, dynamic>>[];
    final idsProcesados = <String>{}; // Para evitar duplicados de ID

    if (imagenesData.isNotEmpty) {
      for (final imagen in imagenesData) {
        if (imagen is Map<String, dynamic>) {
          try {
            final imagenParaGuardar = _mapApiToLocalFormat(
              imagen,
              incluirBase64,
            );

            final id = imagenParaGuardar['id']?.toString();
            if (id != null) {
              if (idsProcesados.contains(id)) {
                continue;
              }
              idsProcesados.add(id);
            }

            imagenesParaGuardar.add(imagenParaGuardar);
          } catch (e) {
            // LOG ERROR: Error procesando imagen individual
            await ErrorLogService.logError(
              tableName: 'censo_activo_foto',
              operation: 'process_item',
              errorMessage: 'Error procesando imagen: $e',
              errorType: 'database',
              registroFailId: imagen['id']?.toString(),
            );
          }
        }
      }
    }

    // Vaciar tabla e insertar todas las imágenes (incluso si está vacía, para limpiar)
    try {
      final dbHelper = DatabaseHelper();

      await dbHelper.vaciarEInsertar('censo_activo_foto', imagenesParaGuardar);
    } catch (e) {
      // LOG ERROR: Error de base de datos local
      await ErrorLogService.logDatabaseError(
        tableName: 'censo_activo_foto',
        operation: 'bulk_insert',
        errorMessage: 'Error en vaciarEInsertar: $e',
      );

      // No lanzar excepción, los datos se obtuvieron correctamente del servidor
    }

    return imagenesParaGuardar;
  }

  /// Mapear campos del API al formato de la tabla local censo_activo_foto
  static Map<String, dynamic> _mapApiToLocalFormat(
    Map<String, dynamic> apiImage,
    bool incluirBase64,
  ) {
    final censoActivo = apiImage['censoActivo'] as Map<String, dynamic>?;
    final censoActivoId = censoActivo?['id']?.toString();

    return {
      'id': apiImage['id']?.toString(),
      'censo_activo_id': censoActivoId,
      'imagen_path': apiImage['imagenPath'],
      'imagen_base64': incluirBase64 ? apiImage['imageBase64'] : null,
      'imagen_tamano': _parseIntSafely(apiImage['imageSize']),
      'orden': 1,
      'fecha_creacion': DateTime.now().toIso8601String(),
      'sincronizado': 1,
    };
  }

  /// Helper para parsear enteros de forma segura
  static int? _parseIntSafely(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      try {
        return int.parse(value);
      } catch (e) { AppLogger.e("CENSO_IMAGE_SYNC_SERVICE: Error", e); return null; }
    }
    return null;
  }
}
