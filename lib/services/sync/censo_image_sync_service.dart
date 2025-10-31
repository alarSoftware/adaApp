import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/services/database_helper.dart';

/// Servicio optimizado para sincronización de imágenes de censos
/// Adaptado al formato específico del API: {"data": "[...]", "status": "OK"}
class CensusImageSyncService extends BaseSyncService {

  // ========== MÉTODO PRINCIPAL OPTIMIZADO ==========
  /// Obtiene fotos de censos con parámetros flexibles
  static Future<SyncResult> obtenerFotosCensos({
    String? edfVendedorId,
    int? censoActivoId,
    String? uuid,
    int? limit,
    int? offset,
    bool incluirBase64 = true,
  }) async {
    try {
      BaseSyncService.logger.i('🖼️ Obteniendo fotos de censos desde el servidor...');

      // Construir parámetros de consulta
      final queryParams = _buildQueryParams(
        edfVendedorId: edfVendedorId,
        censoActivoId: censoActivoId,
        uuid: uuid,
        limit: limit,
        offset: offset,
        incluirBase64: incluirBase64,
      );

      // Realizar petición HTTP
      final response = await _makeHttpRequest(queryParams);

      if (!_isSuccessStatusCode(response.statusCode)) {
        return _handleErrorResponse(response);
      }

      // Parsear respuesta con el formato específico de tu API
      final imagenesData = await _parseImageResponse(response);

      // Procesar y guardar imágenes en la tabla censo_activo_foto
      final processedResult = await _processAndSaveImages(imagenesData, incluirBase64);

      return SyncResult(
        exito: true,
        mensaje: 'Fotos obtenidas correctamente',
        itemsSincronizados: processedResult.length,
        totalEnAPI: processedResult.length,
      );

    } catch (e) {
      BaseSyncService.logger.e('💥 Error obteniendo imágenes de censos: $e');
      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

  // ========== MÉTODOS ESPECÍFICOS SIMPLIFICADOS ==========

  /// Obtener fotos de un censo específico
  static Future<SyncResult> obtenerFotosDeCenso(
      int censoActivoId, {
        String? edfVendedorId,
        bool incluirBase64 = true,
      }) async {
    BaseSyncService.logger.i('📸 Obteniendo fotos del censo ID: $censoActivoId');

    return await obtenerFotosCensos(
      censoActivoId: censoActivoId,
      edfVendedorId: edfVendedorId,
      incluirBase64: incluirBase64,
    );
  }

  /// Obtener foto específica por UUID
  static Future<SyncResult> obtenerFotoPorUuid(
      String uuid, {
        String? edfVendedorId,
        bool incluirBase64 = true,
      }) async {
    BaseSyncService.logger.i('🔍 Obteniendo foto con UUID: $uuid');

    return await obtenerFotosCensos(
      uuid: uuid,
      edfVendedorId: edfVendedorId,
      incluirBase64: incluirBase64,
    );
  }

  /// Obtener fotos con paginación
  static Future<SyncResult> obtenerFotosPaginadas({
    String? edfVendedorId,
    int limit = 50,
    int offset = 0,
    bool incluirBase64 = true,
  }) async {
    BaseSyncService.logger.i('📄 Obteniendo fotos paginadas: limit=$limit, offset=$offset');

    return await obtenerFotosCensos(
      limit: limit,
      offset: offset,
      edfVendedorId: edfVendedorId,
      incluirBase64: incluirBase64,
    );
  }

  /// Obtener solo metadatos (sin Base64) - Optimizado para listar
  static Future<SyncResult> obtenerMetadatosFotos({
    String? edfVendedorId,
    int? censoActivoId,
    int? limit,
    int? offset,
  }) async {
    BaseSyncService.logger.i('📋 Obteniendo solo metadatos de fotos...');

    return await obtenerFotosCensos(
      edfVendedorId: edfVendedorId,
      censoActivoId: censoActivoId,
      limit: limit,
      offset: offset,
      incluirBase64: false, // 🔥 Clave: no incluir Base64 para mejor performance
    );
  }

  /// Obtener fotos por vendedor específico
  static Future<SyncResult> obtenerFotosPorVendedor(
      String edfVendedorId, {
        bool incluirBase64 = true,
        int? limit,
      }) async {
    BaseSyncService.logger.i('👤 Obteniendo fotos del vendedor: $edfVendedorId');

    return await obtenerFotosCensos(
      edfVendedorId: edfVendedorId,
      incluirBase64: incluirBase64,
      limit: limit,
    );
  }

  // ========== MÉTODOS PRIVADOS HELPER ==========

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

    BaseSyncService.logger.i('📡 Llamando a: ${uri.toString()}');

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
    BaseSyncService.logger.e('❌ Error del servidor: $mensaje');

    return SyncResult(
      exito: false,
      mensaje: 'Error del servidor: $mensaje',
      itemsSincronizados: 0,
    );
  }

  /// Parsear respuesta de imágenes - ADAPTADO A TU FORMATO ESPECÍFICO
  static Future<List<dynamic>> _parseImageResponse(http.Response response) async {
    BaseSyncService.logger.i('📥 Respuesta getCensoActivoFoto: ${response.statusCode}');
    BaseSyncService.logger.i('📄 Body respuesta: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}...');

    try {
      final responseBody = jsonDecode(response.body);
      BaseSyncService.logger.i('📊 Tipo de respuesta: ${responseBody.runtimeType}');

      // 🔥 PARSING ESPECÍFICO PARA TU FORMATO: {"data": "[...]", "status": "OK"}
      if (responseBody is Map<String, dynamic>) {

        // Verificar estado
        final status = responseBody['status'];
        if (status != 'OK') {
          BaseSyncService.logger.e('❌ Estado del API no es OK: $status');
          return [];
        }

        // Obtener data
        final dataValue = responseBody['data'];
        if (dataValue == null) {
          BaseSyncService.logger.w('⚠️ Campo data es null');
          return [];
        }

        BaseSyncService.logger.i('📊 Tipo de data: ${dataValue.runtimeType}');

        if (dataValue is String) {
          // 🔥 TU CASO: data es un string JSON que necesita decodificarse
          try {
            final parsed = jsonDecode(dataValue) as List;
            BaseSyncService.logger.i('✅ Formato: data como string JSON, ${parsed.length} imágenes');
            return parsed;
          } catch (e) {
            BaseSyncService.logger.e('❌ Error parseando data como JSON: $e');
            return [];
          }
        } else if (dataValue is List) {
          // data es directamente un array
          BaseSyncService.logger.i('✅ Formato: data como array directo, ${dataValue.length} imágenes');
          return dataValue;
        } else {
          BaseSyncService.logger.w('⚠️ Formato de data no reconocido: ${dataValue.runtimeType}');
          return [];
        }

      } else if (responseBody is List) {
        // Formato directo de array (fallback)
        BaseSyncService.logger.i('✅ Formato: Array directo con ${responseBody.length} imágenes');
        return responseBody;
      } else {
        BaseSyncService.logger.e('❌ Formato de respuesta desconocido: ${responseBody.runtimeType}');
        return [];
      }
    } catch (e) {
      BaseSyncService.logger.e('❌ Error parseando respuesta: $e');
      throw Exception('Error parseando respuesta del servidor: $e');
    }
  }

  /// Procesar y guardar imágenes en la tabla censo_activo_foto
  static Future<List<Map<String, dynamic>>> _processAndSaveImages(
      List<dynamic> imagenesData,
      bool incluirBase64,
      ) async {
    BaseSyncService.logger.i('📊 Total imágenes parseadas: ${imagenesData.length}');

    if (imagenesData.isEmpty) {
      BaseSyncService.logger.w('⚠️ No se encontraron imágenes en la respuesta');
      return [];
    }

    // ANÁLISIS DETALLADO DE LAS IMÁGENES (solo primeras 3 para evitar spam de logs)
    // _logImageAnalysis(imagenesData);

    // ESTADÍSTICAS DE LAS IMÁGENES
    // _logImageStatistics(imagenesData);

    // PROCESAR Y GUARDAR IMÁGENES
    final imagenesValidas = <Map<String, dynamic>>[];
    int savedCount = 0;

    for (final imagen in imagenesData) {
      if (imagen is Map<String, dynamic>) {
        try {
          // Mapear campos del API a la tabla local
          final imagenParaGuardar = _mapApiToLocalFormat(imagen, incluirBase64);

          // Guardar en base de datos
          await _saveImageToDatabase(imagenParaGuardar);

          imagenesValidas.add(imagenParaGuardar);
          savedCount++;
        } catch (e) {
          BaseSyncService.logger.e('❌ Error procesando imagen ID ${imagen['id']}: $e');
        }
      }
    }

    BaseSyncService.logger.i('✅ Imágenes guardadas en BD: $savedCount de ${imagenesData.length}');

    return imagenesValidas;
  }

  /// Mapear campos del API al formato de la tabla local censo_activo_foto
  static Map<String, dynamic> _mapApiToLocalFormat(Map<String, dynamic> apiImage, bool incluirBase64) {
    final censoActivo = apiImage['censoActivo'] as Map<String, dynamic>?;
    final censoActivoId = censoActivo?['id']?.toString();

    // 🔥 USAR UUID COMO ID (con fallback al ID numérico)

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

  /// Guardar imagen en la base de datos local
  static Future<void> _saveImageToDatabase(Map<String, dynamic> imagen) async {
    try {
      final dbHelper = DatabaseHelper();

      // ✅ USAR INSERT OR REPLACE:
      await dbHelper.insertarOReemplazar('censo_activo_foto', imagen);

      BaseSyncService.logger.d('💾 Imagen guardada: ID=${imagen['id']}');
    } catch (e) {
      BaseSyncService.logger.e('❌ Error guardando imagen ID ${imagen['id']} en BD: $e');
      rethrow;
    }
  }

  /// Registrar análisis detallado de imágenes
  static void _logImageAnalysis(List<dynamic> imagenesData) {
    BaseSyncService.logger.i('🔍 Analizando imágenes obtenidas...');

    final maxAnalysis = imagenesData.length > 3 ? 3 : imagenesData.length;

    for (int i = 0; i < maxAnalysis; i++) {
      final imagen = imagenesData[i];
      BaseSyncService.logger.i('🖼️ Imagen ${i + 1}:');

      if (imagen is Map<String, dynamic>) {
        _logSingleImageDetails(imagen);
      } else {
        BaseSyncService.logger.w('   ⚠️ Imagen no es Map: $imagen');
      }
    }
  }

  /// Registrar detalles de una sola imagen
  static void _logSingleImageDetails(Map<String, dynamic> imagen) {
    BaseSyncService.logger.i('   ID: ${imagen['id']}');
    BaseSyncService.logger.i('   UUID: ${imagen['uuid']}');
    BaseSyncService.logger.i('   Censo Activo ID: ${imagen['censoActivo']?['id']}');
    BaseSyncService.logger.i('   Tamaño imagen: ${imagen['imageSize']} bytes');
    BaseSyncService.logger.i('   Ruta imagen: ${imagen['imagenPath']}');

    final hasBase64 = imagen['imageBase64'] != null && imagen['imageBase64'].toString().isNotEmpty;
    BaseSyncService.logger.i('   Tiene Base64: ${hasBase64 ? 'SÍ' : 'NO'}');

    if (hasBase64) {
      final base64Length = imagen['imageBase64'].toString().length;
      BaseSyncService.logger.i('   Longitud Base64: $base64Length caracteres');
    }

    // Verificar estructura del objeto censoActivo
    final censoActivo = imagen['censoActivo'];
    if (censoActivo is Map<String, dynamic>) {
      BaseSyncService.logger.i('   CensoActivo keys: ${censoActivo.keys.toList()}');
    }

    BaseSyncService.logger.i('   Llaves disponibles: ${imagen.keys.join(', ')}');
  }

  /// Registrar estadísticas de las imágenes
  static void _logImageStatistics(List<dynamic> imagenesData) {
    final imagenesConBase64 = imagenesData.where((img) =>
    img is Map && img['imageBase64'] != null && img['imageBase64'].toString().isNotEmpty).length;
    final imagenesConUuid = imagenesData.where((img) =>
    img is Map && img['uuid'] != null).length;
    final imagenesConCensoId = imagenesData.where((img) =>
    img is Map && img['censoActivo'] != null && img['censoActivo']['id'] != null).length;

    BaseSyncService.logger.i('📊 Estadísticas de imágenes:');
    BaseSyncService.logger.i('   Total: ${imagenesData.length}');
    BaseSyncService.logger.i('   Con Base64: $imagenesConBase64');
    BaseSyncService.logger.i('   Con UUID: $imagenesConUuid');
    BaseSyncService.logger.i('   Con Censo ID: $imagenesConCensoId');
  }

  // ========== MÉTODOS PARA INTEGRACIÓN CON EL SISTEMA GENERAL ==========

  /// Sincronizar imágenes de censos por vendedor (para integrar en FullSyncService)
  static Future<SyncResult> sincronizarImagenesPorVendedor(String edfVendedorId) async {
    try {
      BaseSyncService.logger.i('🔄 Sincronizando imágenes para vendedor: $edfVendedorId');

      // ✅ OBTENER IMÁGENES CON BASE64
      final imagenesResult = await obtenerFotosCensos(
        edfVendedorId: edfVendedorId,
        incluirBase64: true,  // 🔥 CAMBIAR A TRUE
        limit: 100,
      );

      if (!imagenesResult.exito) {
        return imagenesResult;
      }

      BaseSyncService.logger.i('✅ Imágenes sincronizadas: ${imagenesResult.itemsSincronizados}');

      return imagenesResult;

    } catch (e) {
      BaseSyncService.logger.e('❌ Error: $e');
      return SyncResult(
        exito: false,
        mensaje: 'Error sincronizando imágenes: $e',
        itemsSincronizados: 0,
      );
    }
  }

  // ========== MÉTODOS DE CONSULTA LOCAL ==========

  /// Obtener imágenes de un censo desde la base de datos local
  static Future<List<Map<String, dynamic>>> obtenerImagenesLocalPorCenso(String censoActivoId) async {
    try {
      final dbHelper = DatabaseHelper();
      return await dbHelper.consultarPersonalizada(
        'SELECT * FROM censo_activo_foto WHERE censo_activo_id = ? ORDER BY orden, id',
        [censoActivoId],
      );
    } catch (e) {
      BaseSyncService.logger.e('❌ Error obteniendo imágenes locales: $e');
      return [];
    }
  }

  /// Contar imágenes en la base de datos local
  static Future<int> contarImagenesLocales() async {
    try {
      final dbHelper = DatabaseHelper();
      final result = await dbHelper.consultarPersonalizada(
        'SELECT COUNT(*) as total FROM censo_activo_foto',
        [],
      );
      return result.isNotEmpty ? (result.first['total'] as int? ?? 0) : 0;
    } catch (e) {
      BaseSyncService.logger.e('❌ Error contando imágenes locales: $e');
      return 0;
    }
  }
}