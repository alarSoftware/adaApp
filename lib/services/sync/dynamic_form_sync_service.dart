import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/repositories/dynamic_form_repository.dart';

class DynamicFormSyncService extends BaseSyncService {

  // ==================== CONSTANTES ====================

  static const String _getDynamicFormEndpoint = '/api/getDynamicForm';
  static const String _getDynamicFormDetailEndpoint = '/api/getDynamicFormDetail';
  static const String _getDynamicFormResponseEndpoint = '/api/getDynamicFormResponse';
  static const String _getDynamicFormResponseImageEndpoint = '/api/getDynamicFormResponseImage';

  // ==================== FORMULARIOS Y DETALLES ====================

  /// Obtener todos los formularios dinámicos (con sus detalles)
  static Future<SyncResult> obtenerFormulariosDinamicos({
    String? estado,
    int? limit,
    int? offset,
  }) async {
    try {
      BaseSyncService.logger.i('📋 Obteniendo formularios dinámicos desde el servidor...');

      // 1. OBTENER FORMULARIOS
      final formulariosData = await _fetchFormularios(estado, limit, offset);
      if (formulariosData == null) {
        return SyncResult(
          exito: false,
          mensaje: 'Error obteniendo formularios del servidor',
          itemsSincronizados: 0,
        );
      }

      if (formulariosData.isEmpty) {
        BaseSyncService.logger.w('⚠️ No se encontraron formularios en la respuesta');
        return SyncResult(
          exito: true,
          mensaje: 'No hay formularios disponibles',
          itemsSincronizados: 0,
        );
      }

      BaseSyncService.logger.i('✅ Formularios parseados: ${formulariosData.length}');

      // 2. GUARDAR FORMULARIOS EN BD LOCAL
      final repo = DynamicFormRepository();
      final guardados = await repo.templates.saveTemplatesFromServer(formulariosData);
      BaseSyncService.logger.i('💾 Formularios guardados en BD local: $guardados');

      // 3. OBTENER Y GUARDAR DETALLES
      final detallesGuardados = await _syncDetalles(repo);

      return SyncResult(
        exito: true,
        mensaje: 'Formularios y detalles obtenidos correctamente',
        itemsSincronizados: guardados,
        totalEnAPI: formulariosData.length,
      );
    } catch (e) {
      BaseSyncService.logger.e('💥 Error obteniendo formularios: $e');
      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

  /// Obtener formulario específico por ID
  static Future<SyncResult> obtenerFormularioPorId(int formId) async {
    try {
      BaseSyncService.logger.i('📋 Obteniendo formulario ID: $formId');

      final baseUrl = await BaseSyncService.getBaseUrl();

      final response = await http.get(
        Uri.parse('$baseUrl/api/getFormularios/$formId'),
        headers: BaseSyncService.headers,
      ).timeout(BaseSyncService.timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = jsonDecode(response.body);

        Map<String, dynamic> formData;
        if (responseData is Map<String, dynamic>) {
          formData = responseData.containsKey('data')
              ? responseData['data']
              : responseData;
        } else {
          throw 'Formato de respuesta inesperado';
        }

        // Guardar en BD usando nueva API
        final repo = DynamicFormRepository();
        await repo.templates.saveTemplatesFromServer([formData]);

        BaseSyncService.logger.i('✅ Formulario obtenido: ID ${formData['id']}');

        return SyncResult(
          exito: true,
          mensaje: 'Formulario obtenido correctamente',
          itemsSincronizados: 1,
        );
      } else {
        final mensaje = BaseSyncService.extractErrorMessage(response);
        return SyncResult(
          exito: false,
          mensaje: 'Formulario no encontrado: $mensaje',
          itemsSincronizados: 0,
        );
      }
    } catch (e) {
      BaseSyncService.logger.e('❌ Error obteniendo formulario por ID: $e');
      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

  /// Obtener detalles de un formulario específico
  static Future<SyncResult> obtenerDetallesFormulario(String formId) async {
    try {
      BaseSyncService.logger.i('📋 Obteniendo detalles del formulario ID: $formId');

      final baseUrl = await BaseSyncService.getBaseUrl();

      final response = await http.get(
        Uri.parse('$baseUrl$_getDynamicFormDetailEndpoint?dynamicFormId=$formId'),
        headers: BaseSyncService.headers,
      ).timeout(BaseSyncService.timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final detallesData = _parseListResponse(response.body);

        if (detallesData == null) {
          return SyncResult(
            exito: false,
            mensaje: 'Error parseando detalles del servidor',
            itemsSincronizados: 0,
          );
        }

        if (detallesData.isEmpty) {
          return SyncResult(
            exito: true,
            mensaje: 'No hay detalles disponibles para este formulario',
            itemsSincronizados: 0,
          );
        }

        // Guardar usando nueva API
        final repo = DynamicFormRepository();
        final guardados = await repo.templates.saveDetailsFromServer(detallesData);

        BaseSyncService.logger.i('✅ Detalles guardados: $guardados');

        return SyncResult(
          exito: true,
          mensaje: 'Detalles obtenidos correctamente',
          itemsSincronizados: guardados,
        );
      } else {
        final mensaje = BaseSyncService.extractErrorMessage(response);
        return SyncResult(
          exito: false,
          mensaje: 'Error del servidor: $mensaje',
          itemsSincronizados: 0,
        );
      }
    } catch (e) {
      BaseSyncService.logger.e('❌ Error obteniendo detalles: $e');
      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

  /// Sincronizar todos los detalles de formularios
  static Future<SyncResult> sincronizarTodosLosDetalles() async {
    try {
      BaseSyncService.logger.i('📋 Sincronizando todos los detalles de formularios...');

      final baseUrl = await BaseSyncService.getBaseUrl();
      final uri = Uri.parse('$baseUrl$_getDynamicFormDetailEndpoint');

      BaseSyncService.logger.i('📡 Llamando a: ${uri.toString()}');

      final response = await http.get(
        uri,
        headers: BaseSyncService.headers,
      ).timeout(BaseSyncService.timeout);

      BaseSyncService.logger.i('📥 Respuesta: ${response.statusCode}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final detallesData = _parseListResponse(response.body);

        if (detallesData == null) {
          return SyncResult(
            exito: false,
            mensaje: 'Error parseando respuesta del servidor',
            itemsSincronizados: 0,
          );
        }

        BaseSyncService.logger.i('✅ Detalles parseados: ${detallesData.length}');

        if (detallesData.isEmpty) {
          return SyncResult(
            exito: true,
            mensaje: 'No hay detalles disponibles',
            itemsSincronizados: 0,
          );
        }

        // Guardar usando nueva API
        final repo = DynamicFormRepository();
        final guardados = await repo.templates.saveDetailsFromServer(detallesData);
        BaseSyncService.logger.i('💾 Detalles guardados en BD local: $guardados');

        return SyncResult(
          exito: true,
          mensaje: 'Detalles sincronizados correctamente',
          itemsSincronizados: guardados,
          totalEnAPI: detallesData.length,
        );
      } else {
        final mensaje = BaseSyncService.extractErrorMessage(response);
        return SyncResult(
          exito: false,
          mensaje: 'Error del servidor: $mensaje',
          itemsSincronizados: 0,
        );
      }
    } catch (e) {
      BaseSyncService.logger.e('💥 Error sincronizando detalles: $e');
      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

  // ==================== RESPUESTAS ====================

  /// Obtener respuestas de formularios dinámicos desde el servidor
  static Future<SyncResult> obtenerRespuestasFormularios({
    String? contactoId,
    String? dynamicFormId,
    String? estado,
    String? edfvendedorId,
  }) async {
    try {
      BaseSyncService.logger.i('📥 Obteniendo respuestas de formularios desde el servidor...');

      final queryParams = _buildQueryParams(
        contactoId: contactoId,
        dynamicFormId: dynamicFormId,
        estado: estado,
        edfvendedorId: edfvendedorId,
      );

      final baseUrl = await BaseSyncService.getBaseUrl();
      final uri = Uri.parse('$baseUrl$_getDynamicFormResponseEndpoint')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      BaseSyncService.logger.i('📡 Llamando a: ${uri.toString()}');

      final response = await http.get(
        uri,
        headers: BaseSyncService.headers,
      ).timeout(BaseSyncService.timeout);

      BaseSyncService.logger.i('📥 Respuesta getDynamicFormResponse: ${response.statusCode}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responsesData = _parseListResponse(response.body);

        if (responsesData == null) {
          return SyncResult(
            exito: false,
            mensaje: 'Error parseando respuesta del servidor',
            itemsSincronizados: 0,
          );
        }

        BaseSyncService.logger.i('✅ Respuestas parseadas: ${responsesData.length}');

        if (responsesData.isEmpty) {
          BaseSyncService.logger.w('⚠️ No se encontraron respuestas en la respuesta');
          return SyncResult(
            exito: true,
            mensaje: 'No hay respuestas disponibles',
            itemsSincronizados: 0,
          );
        }

        // Guardar usando nueva API
        final repo = DynamicFormRepository();
        final guardados = await repo.responses.saveResponsesFromServer(responsesData);
        BaseSyncService.logger.i('💾 Respuestas guardadas en BD local: $guardados');

        return SyncResult(
          exito: true,
          mensaje: 'Respuestas descargadas correctamente',
          itemsSincronizados: guardados,
          totalEnAPI: responsesData.length,
        );
      } else {
        final mensaje = BaseSyncService.extractErrorMessage(response);
        BaseSyncService.logger.e('❌ Error del servidor: $mensaje');
        return SyncResult(
          exito: false,
          mensaje: 'Error del servidor: $mensaje',
          itemsSincronizados: 0,
        );
      }
    } catch (e) {
      BaseSyncService.logger.e('💥 Error obteniendo respuestas: $e');
      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

  /// Obtener imágenes de respuestas de formularios dinámicos desde el servidor
  static Future<SyncResult> obtenerImagenesRespuestasFormularios({
    String? edfvendedorId,
    String? contactoId,
    String? dynamicFormId,
    String? dynamicFormResponseId,
  }) async {
    try {
      BaseSyncService.logger.i('🖼️ Obteniendo imágenes de respuestas de formularios desde el servidor...');

      final queryParams = _buildQueryParams(
        edfvendedorId: edfvendedorId,
        contactoId: contactoId,
        dynamicFormId: dynamicFormId,
        dynamicFormResponseId: dynamicFormResponseId,
      );

      final baseUrl = await BaseSyncService.getBaseUrl();
      final uri = Uri.parse('$baseUrl$_getDynamicFormResponseImageEndpoint')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      BaseSyncService.logger.i('📡 Llamando a: ${uri.toString()}');

      final response = await http.get(
        uri,
        headers: BaseSyncService.headers,
      ).timeout(BaseSyncService.timeout);

      BaseSyncService.logger.i('📥 Respuesta getDynamicFormResponseImage: ${response.statusCode}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final imagenesData = _parseListResponse(response.body);

        for (final f in imagenesData! ) {
          var foto = f["id"];
          print ('ID DE LA FOTO $foto');
        }

        if (imagenesData == null) {
          return SyncResult(
            exito: false,
            mensaje: 'Error parseando respuesta del servidor',
            itemsSincronizados: 0,
          );
        }

        BaseSyncService.logger.i('✅ Imágenes parseadas: ${imagenesData.length}');

        if (imagenesData.isEmpty) {
          BaseSyncService.logger.w('⚠️ No se encontraron imágenes en la respuesta');
          return SyncResult(
            exito: true,
            mensaje: 'No hay imágenes disponibles',
            itemsSincronizados: 0,
          );
        }

        // Guardar usando nueva API del repositorio
        final repo = DynamicFormRepository();
        final guardados = await repo.responses.saveResponseImagesFromServer(imagenesData);
        BaseSyncService.logger.i('💾 Imágenes guardadas en BD local: $guardados');

        return SyncResult(
          exito: true,
          mensaje: 'Imágenes descargadas correctamente',
          itemsSincronizados: guardados,
          totalEnAPI: imagenesData.length,
        );
      } else {
        final mensaje = BaseSyncService.extractErrorMessage(response);
        BaseSyncService.logger.e('❌ Error del servidor: $mensaje');
        return SyncResult(
          exito: false,
          mensaje: 'Error del servidor: $mensaje',
          itemsSincronizados: 0,
        );
      }
    } catch (e) {
      BaseSyncService.logger.e('💥 Error obteniendo imágenes: $e');
      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

  /// Método de conveniencia para obtener respuestas por vendedor
  static Future<SyncResult> obtenerRespuestasPorVendedor(String edfvendedorId) {
    return obtenerRespuestasFormularios(edfvendedorId: edfvendedorId);
  }

  /// Método de conveniencia para obtener imágenes por vendedor
  static Future<SyncResult> obtenerImagenesPorVendedor(String edfvendedorId) {
    return obtenerImagenesRespuestasFormularios(edfvendedorId: edfvendedorId);
  }

  /// 🆕 MÉTODO FALTANTE: Obtener imágenes de formularios por vendedor
  static Future<SyncResult> obtenerImagenesFormularios({
    String? edfVendedorId,
  }) {
    return obtenerImagenesRespuestasFormularios(edfvendedorId: edfVendedorId);
  }

  /// Obtener todas las respuestas completadas
  static Future<SyncResult> obtenerRespuestasCompletadas({String? edfvendedorId}) {
    return obtenerRespuestasFormularios(
      edfvendedorId: edfvendedorId,
      estado: 'completed',
    );
  }

  // ==================== MÉTODOS DE CONVENIENCIA ====================

  static Future<SyncResult> obtenerFormulariosActivos() {
    return obtenerFormulariosDinamicos(estado: 'ACTIVO');
  }

  static Future<SyncResult> obtenerFormulariosBorrador() {
    return obtenerFormulariosDinamicos(estado: 'BORRADOR');
  }

  // ==================== MÉTODOS PRIVADOS - HELPERS ====================

  /// Obtiene los formularios del servidor
  static Future<List<Map<String, dynamic>>?> _fetchFormularios(
      String? estado,
      int? limit,
      int? offset,
      ) async {
    final queryParams = _buildQueryParams(
      estado: estado,
      limit: limit?.toString(),
      offset: offset?.toString(),
    );

    final baseUrl = await BaseSyncService.getBaseUrl();
    final uri = Uri.parse('$baseUrl$_getDynamicFormEndpoint')
        .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    BaseSyncService.logger.i('📡 Llamando a: ${uri.toString()}');

    final response = await http.get(
      uri,
      headers: BaseSyncService.headers,
    ).timeout(BaseSyncService.timeout);

    BaseSyncService.logger.i('📥 Respuesta getDynamicForm: ${response.statusCode}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _parseListResponse(response.body);
    } else {
      final mensaje = BaseSyncService.extractErrorMessage(response);
      BaseSyncService.logger.e('❌ Error del servidor: $mensaje');
      return null;
    }
  }

  /// Sincroniza los detalles después de obtener los formularios
  static Future<int> _syncDetalles(DynamicFormRepository repo) async {
    BaseSyncService.logger.i('📋 Obteniendo detalles de formularios...');

    final baseUrl = await BaseSyncService.getBaseUrl();
    final uriDetalles = Uri.parse('$baseUrl$_getDynamicFormDetailEndpoint');

    final responseDetalles = await http.get(
      uriDetalles,
      headers: BaseSyncService.headers,
    ).timeout(BaseSyncService.timeout);

    BaseSyncService.logger.i('📥 Respuesta getDynamicFormDetail: ${responseDetalles.statusCode}');

    if (responseDetalles.statusCode >= 200 && responseDetalles.statusCode < 300) {
      final detallesData = _parseListResponse(responseDetalles.body);

      if (detallesData != null && detallesData.isNotEmpty) {
        BaseSyncService.logger.i('✅ Detalles parseados: ${detallesData.length}');

        final detallesGuardados = await repo.templates.saveDetailsFromServer(detallesData);
        BaseSyncService.logger.i('💾 Detalles guardados en BD local: $detallesGuardados');

        return detallesGuardados;
      }
    }

    return 0;
  }

  /// Parse genérico para respuestas tipo lista del servidor
  static List<Map<String, dynamic>>? _parseListResponse(String responseBody) {
    try {
      final parsed = jsonDecode(responseBody);

      // Caso 1: Respuesta directa como lista
      if (parsed is List) {
        return parsed.cast<Map<String, dynamic>>();
      }

      // Caso 2: Respuesta con campo 'data'
      if (parsed is Map && parsed.containsKey('data')) {
        final dataValue = parsed['data'];

        // data es un string JSON
        if (dataValue is String) {
          final decoded = jsonDecode(dataValue);
          if (decoded is List) {
            return decoded.cast<Map<String, dynamic>>();
          }
        }

        // data es una lista directa
        if (dataValue is List) {
          return dataValue.cast<Map<String, dynamic>>();
        }
      }
      //Imprimir un log para ver la id


      BaseSyncService.logger.w('⚠️ Formato de respuesta no reconocido');
      return null;
    } catch (e) {
      BaseSyncService.logger.e('❌ Error parseando respuesta: $e');
      return null;
    }
  }

  /// Construye query parameters filtrando valores nulos
  static Map<String, String> _buildQueryParams({
    String? contactoId,
    String? dynamicFormId,
    String? dynamicFormResponseId,
    String? estado,
    String? edfvendedorId,
    String? limit,
    String? offset,
  }) {
    final params = <String, String>{};

    if (contactoId != null) params['contactoId'] = contactoId;
    if (dynamicFormId != null) params['dynamicFormId'] = dynamicFormId;
    if (dynamicFormResponseId != null) params['dynamicFormResponseId'] = dynamicFormResponseId;
    if (estado != null) params['estado'] = estado;
    if (edfvendedorId != null) params['edfvendedorId'] = edfvendedorId;
    if (limit != null) params['limit'] = limit;
    if (offset != null) params['offset'] = offset;

    return params;
  }
}