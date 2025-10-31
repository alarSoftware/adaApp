import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/services/database_helper.dart';

/// Servicio para sincronización de imágenes de censos
/// Simplificado para solo traer fotos del API y guardarlas
class CensusImageSyncService extends BaseSyncService {

  /// Método principal: Obtiene y guarda fotos de censos
  static Future<SyncResult> obtenerFotosCensos({
    String? edfVendedorId,
    int? censoActivoId,
    String? uuid,
    int? limit,
    int? offset,
    bool incluirBase64 = true,
  }) async {
    try {
      final queryParams = _buildQueryParams(
        edfVendedorId: edfVendedorId,
        censoActivoId: censoActivoId,
        uuid: uuid,
        limit: limit,
        offset: offset,
        incluirBase64: incluirBase64,
      );

      final response = await _makeHttpRequest(queryParams);

      if (!_isSuccessStatusCode(response.statusCode)) {
        return _handleErrorResponse(response);
      }

      final imagenesData = await _parseImageResponse(response);
      final processedResult = await _processAndSaveImages(imagenesData, incluirBase64);

      return SyncResult(
        exito: true,
        mensaje: 'Fotos obtenidas correctamente',
        itemsSincronizados: processedResult.length,
        totalEnAPI: processedResult.length,
      );

    } catch (e) {
      BaseSyncService.logger.e('Error obteniendo imágenes de censos: $e');
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
    String? edfVendedorId,
    int? censoActivoId,
    String? uuid,
    int? limit,
    int? offset,
    bool incluirBase64 = true,
  }) {
    final Map<String, String> queryParams = {};

    if (edfVendedorId != null) queryParams['edfvendedorId'] = edfVendedorId;
    if (censoActivoId != null) queryParams['censoActivoId'] = censoActivoId.toString();
    if (limit != null) queryParams['limit'] = limit.toString();
    if (offset != null) queryParams['offset'] = offset.toString();
    if (uuid != null) queryParams['uuid'] = uuid;
    if (incluirBase64) queryParams['includeBase64'] = 'true';

    return queryParams;
  }

  /// Realizar petición HTTP
  static Future<http.Response> _makeHttpRequest(Map<String, String> queryParams) async {
    final baseUrl = await BaseSyncService.getBaseUrl();
    final uri = Uri.parse('$baseUrl/api/getCensoActivoFoto')
        .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    return await http.get(
      uri,
      headers: BaseSyncService.headers,
    ).timeout(BaseSyncService.timeout);
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
  static Future<List<dynamic>> _parseImageResponse(http.Response response) async {
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
            BaseSyncService.logger.e('Error parseando data como JSON: $e');
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
      BaseSyncService.logger.e('Error parseando respuesta: $e');
      throw Exception('Error parseando respuesta del servidor: $e');
    }
  }

  /// Procesar y guardar imágenes en la tabla censo_activo_foto
  static Future<List<Map<String, dynamic>>> _processAndSaveImages(
      List<dynamic> imagenesData,
      bool incluirBase64,
      ) async {
    if (imagenesData.isEmpty) return [];

    // Convertir datos del API al formato local
    final imagenesParaGuardar = <Map<String, dynamic>>[];

    for (final imagen in imagenesData) {
      if (imagen is Map<String, dynamic>) {
        try {
          final imagenParaGuardar = _mapApiToLocalFormat(imagen, incluirBase64);
          imagenesParaGuardar.add(imagenParaGuardar);
        } catch (e) {
          BaseSyncService.logger.e('Error procesando imagen ID ${imagen['id']}: $e');
        }
      }
    }

    // Vaciar tabla e insertar todas las imágenes
    final dbHelper = DatabaseHelper();
    await dbHelper.vaciarEInsertar('censo_activo_foto', imagenesParaGuardar);

    return imagenesParaGuardar;
  }

  /// Mapear campos del API al formato de la tabla local censo_activo_foto
  static Map<String, dynamic> _mapApiToLocalFormat(Map<String, dynamic> apiImage, bool incluirBase64) {
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
      } catch (e) {
        return null;
      }
    }
    return null;
  }
}