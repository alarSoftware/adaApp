import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/repositories/dynamic_form_repository.dart';
import 'package:ada_app/services/error_log/error_log_service.dart';

class DynamicFormSyncService extends BaseSyncService {

  static const String _getDynamicFormEndpoint = '/api/getDynamicForm';
  static const String _getDynamicFormDetailEndpoint = '/api/getDynamicFormDetail';
  static const String _getDynamicFormResponseEndpoint = '/api/getDynamicFormResponse';
  static const String _getDynamicFormResponseImageEndpoint = '/api/getDynamicFormResponseImage';

  static Future<SyncResult> obtenerFormulariosDinamicos({
    String? estado,
    int? limit,
    int? offset,
  }) async {
    String? currentEndpoint;

    try {
      final formulariosData = await _fetchFormularios(estado, limit, offset);

      if (formulariosData == null) {
        return SyncResult(
          exito: false,
          mensaje: 'Error obteniendo formularios del servidor',
          itemsSincronizados: 0,
        );
      }

      if (formulariosData.isEmpty) {
        return SyncResult(
          exito: true,
          mensaje: 'No hay formularios disponibles',
          itemsSincronizados: 0,
        );
      }

      try {
        final repo = DynamicFormRepository();
        final guardados = await repo.templates.saveTemplatesFromServer(formulariosData);
      } catch (dbError) {
        await ErrorLogService.logDatabaseError(
          tableName: 'dynamic_form',
          operation: 'bulk_insert',
          errorMessage: 'Error guardando formularios: $dbError',
        );
      }

      final detallesGuardados = await _syncDetalles(DynamicFormRepository());

      return SyncResult(
        exito: true,
        mensaje: 'Formularios y detalles obtenidos correctamente',
        itemsSincronizados: formulariosData.length,
        totalEnAPI: formulariosData.length,
      );

    } catch (e) {
      await ErrorLogService.logError(
        tableName: 'dynamic_form',
        operation: 'sync_from_server',
        errorMessage: 'Error general: $e',
        errorType: 'unknown',
        errorCode: 'GENERAL_ERROR',
      );

      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

  static Future<SyncResult> obtenerFormularioPorId(int formId) async {
    String? currentEndpoint;

    try {
      final baseUrl = await BaseSyncService.getBaseUrl();
      currentEndpoint = '$baseUrl/api/getFormularios/$formId';

      final response = await http.get(
        Uri.parse(currentEndpoint),
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

        try {
          final repo = DynamicFormRepository();
          await repo.templates.saveTemplatesFromServer([formData]);
        } catch (dbError) {
          await ErrorLogService.logDatabaseError(
            tableName: 'dynamic_form',
            operation: 'save_single',
            errorMessage: 'Error guardando formulario: $dbError',
            registroFailId: formId.toString(),
          );
        }

        return SyncResult(
          exito: true,
          mensaje: 'Formulario obtenido correctamente',
          itemsSincronizados: 1,
        );
      } else {
        final mensaje = BaseSyncService.extractErrorMessage(response);

        await ErrorLogService.logServerError(
          tableName: 'dynamic_form',
          operation: 'get_by_id',
          errorMessage: mensaje,
          errorCode: response.statusCode.toString(),
          endpoint: currentEndpoint,
          registroFailId: formId.toString(),
        );

        return SyncResult(
          exito: false,
          mensaje: 'Formulario no encontrado: $mensaje',
          itemsSincronizados: 0,
        );
      }

    } on TimeoutException catch (timeoutError) {
      await ErrorLogService.logNetworkError(
        tableName: 'dynamic_form',
        operation: 'get_by_id',
        errorMessage: 'Timeout: $timeoutError',
        endpoint: currentEndpoint,
        registroFailId: formId.toString(),
      );

      return SyncResult(
        exito: false,
        mensaje: 'Timeout de conexión',
        itemsSincronizados: 0,
      );

    } on SocketException catch (socketError) {
      await ErrorLogService.logNetworkError(
        tableName: 'dynamic_form',
        operation: 'get_by_id',
        errorMessage: 'Sin conexión: $socketError',
        endpoint: currentEndpoint,
        registroFailId: formId.toString(),
      );

      return SyncResult(
        exito: false,
        mensaje: 'Sin conexión de red',
        itemsSincronizados: 0,
      );

    } catch (e) {
      await ErrorLogService.logError(
        tableName: 'dynamic_form',
        operation: 'get_by_id',
        errorMessage: 'Error: $e',
        errorType: 'unknown',
        endpoint: currentEndpoint,
        registroFailId: formId.toString(),
      );

      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

  static Future<SyncResult> obtenerDetallesFormulario(String formId) async {
    String? currentEndpoint;

    try {
      final baseUrl = await BaseSyncService.getBaseUrl();
      currentEndpoint = '$baseUrl$_getDynamicFormDetailEndpoint?dynamicFormId=$formId';

      final response = await http.get(
        Uri.parse(currentEndpoint),
        headers: BaseSyncService.headers,
      ).timeout(BaseSyncService.timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final detallesData = _parseListResponse(response.body);

        if (detallesData == null) {
          await ErrorLogService.logError(
            tableName: 'dynamic_form_detail',
            operation: 'parse_response',
            errorMessage: 'Error parseando detalles',
            errorType: 'server',
            errorCode: 'PARSE_ERROR',
            endpoint: currentEndpoint,
          );

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

        try {
          final repo = DynamicFormRepository();
          final guardados = await repo.templates.saveDetailsFromServer(detallesData);

          return SyncResult(
            exito: true,
            mensaje: 'Detalles obtenidos correctamente',
            itemsSincronizados: guardados,
          );
        } catch (dbError) {
          await ErrorLogService.logDatabaseError(
            tableName: 'dynamic_form_detail',
            operation: 'bulk_insert',
            errorMessage: 'Error guardando detalles: $dbError',
          );

          return SyncResult(
            exito: true,
            mensaje: 'Detalles descargados pero con error al guardar',
            itemsSincronizados: 0,
          );
        }
      } else {
        final mensaje = BaseSyncService.extractErrorMessage(response);

        await ErrorLogService.logServerError(
          tableName: 'dynamic_form_detail',
          operation: 'sync_from_server',
          errorMessage: mensaje,
          errorCode: response.statusCode.toString(),
          endpoint: currentEndpoint,
        );

        return SyncResult(
          exito: false,
          mensaje: 'Error del servidor: $mensaje',
          itemsSincronizados: 0,
        );
      }

    } on TimeoutException catch (timeoutError) {
      await ErrorLogService.logNetworkError(
        tableName: 'dynamic_form_detail',
        operation: 'sync_from_server',
        errorMessage: 'Timeout: $timeoutError',
        endpoint: currentEndpoint,
      );

      return SyncResult(
        exito: false,
        mensaje: 'Timeout de conexión',
        itemsSincronizados: 0,
      );

    } on SocketException catch (socketError) {
      await ErrorLogService.logNetworkError(
        tableName: 'dynamic_form_detail',
        operation: 'sync_from_server',
        errorMessage: 'Sin conexión: $socketError',
        endpoint: currentEndpoint,
      );

      return SyncResult(
        exito: false,
        mensaje: 'Sin conexión de red',
        itemsSincronizados: 0,
      );

    } catch (e) {
      await ErrorLogService.logError(
        tableName: 'dynamic_form_detail',
        operation: 'sync_from_server',
        errorMessage: 'Error: $e',
        errorType: 'unknown',
        endpoint: currentEndpoint,
      );

      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

  static Future<SyncResult> sincronizarTodosLosDetalles() async {
    String? currentEndpoint;

    try {
      final baseUrl = await BaseSyncService.getBaseUrl();
      final uri = Uri.parse('$baseUrl$_getDynamicFormDetailEndpoint');
      currentEndpoint = uri.toString();

      final response = await http.get(
        uri,
        headers: BaseSyncService.headers,
      ).timeout(BaseSyncService.timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final detallesData = _parseListResponse(response.body);

        if (detallesData == null) {
          await ErrorLogService.logError(
            tableName: 'dynamic_form_detail',
            operation: 'parse_response',
            errorMessage: 'Error parseando respuesta',
            errorType: 'server',
            errorCode: 'PARSE_ERROR',
            endpoint: currentEndpoint,
          );

          return SyncResult(
            exito: false,
            mensaje: 'Error parseando respuesta del servidor',
            itemsSincronizados: 0,
          );
        }

        if (detallesData.isEmpty) {
          return SyncResult(
            exito: true,
            mensaje: 'No hay detalles disponibles',
            itemsSincronizados: 0,
          );
        }

        try {
          final repo = DynamicFormRepository();
          final guardados = await repo.templates.saveDetailsFromServer(detallesData);

          return SyncResult(
            exito: true,
            mensaje: 'Detalles sincronizados correctamente',
            itemsSincronizados: guardados,
            totalEnAPI: detallesData.length,
          );
        } catch (dbError) {
          await ErrorLogService.logDatabaseError(
            tableName: 'dynamic_form_detail',
            operation: 'bulk_insert',
            errorMessage: 'Error guardando detalles: $dbError',
          );

          return SyncResult(
            exito: true,
            mensaje: 'Detalles descargados pero con error al guardar',
            itemsSincronizados: 0,
          );
        }
      } else {
        final mensaje = BaseSyncService.extractErrorMessage(response);

        await ErrorLogService.logServerError(
          tableName: 'dynamic_form_detail',
          operation: 'sync_all',
          errorMessage: mensaje,
          errorCode: response.statusCode.toString(),
          endpoint: currentEndpoint,
        );

        return SyncResult(
          exito: false,
          mensaje: 'Error del servidor: $mensaje',
          itemsSincronizados: 0,
        );
      }

    } on TimeoutException catch (timeoutError) {
      await ErrorLogService.logNetworkError(
        tableName: 'dynamic_form_detail',
        operation: 'sync_all',
        errorMessage: 'Timeout: $timeoutError',
        endpoint: currentEndpoint,
      );

      return SyncResult(
        exito: false,
        mensaje: 'Timeout de conexión',
        itemsSincronizados: 0,
      );

    } on SocketException catch (socketError) {
      await ErrorLogService.logNetworkError(
        tableName: 'dynamic_form_detail',
        operation: 'sync_all',
        errorMessage: 'Sin conexión: $socketError',
        endpoint: currentEndpoint,
      );

      return SyncResult(
        exito: false,
        mensaje: 'Sin conexión de red',
        itemsSincronizados: 0,
      );

    } catch (e) {
      await ErrorLogService.logError(
        tableName: 'dynamic_form_detail',
        operation: 'sync_all',
        errorMessage: 'Error: $e',
        errorType: 'unknown',
        endpoint: currentEndpoint,
      );

      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

  static Future<SyncResult> obtenerRespuestasFormularios({
    String? contactoId,
    String? dynamicFormId,
    String? estado,
    String? edfvendedorId,
  }) async {
    String? currentEndpoint;

    try {
      final queryParams = _buildQueryParams(
        contactoId: contactoId,
        dynamicFormId: dynamicFormId,
        estado: estado,
        edfvendedorId: edfvendedorId,
      );

      final baseUrl = await BaseSyncService.getBaseUrl();
      final uri = Uri.parse('$baseUrl$_getDynamicFormResponseEndpoint')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
      currentEndpoint = uri.toString();

      final response = await http.get(
        uri,
        headers: BaseSyncService.headers,
      ).timeout(BaseSyncService.timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responsesData = _parseListResponse(response.body);

        if (responsesData == null) {
          return SyncResult(
            exito: false,
            mensaje: 'Error parseando respuesta del servidor',
            itemsSincronizados: 0,
          );
        }

        if (responsesData.isEmpty) {
          return SyncResult(
            exito: true,
            mensaje: 'No hay respuestas disponibles',
            itemsSincronizados: 0,
          );
        }

        try {
          final repo = DynamicFormRepository();
          final guardados = await repo.responses.saveResponsesFromServer(responsesData);

          return SyncResult(
            exito: true,
            mensaje: 'Respuestas descargadas correctamente',
            itemsSincronizados: guardados,
            totalEnAPI: responsesData.length,
          );
        } catch (dbError) {
          await ErrorLogService.logDatabaseError(
            tableName: 'dynamic_form_response',
            operation: 'bulk_insert',
            errorMessage: 'Error guardando respuestas: $dbError',
          );

          return SyncResult(
            exito: true,
            mensaje: 'Respuestas descargadas pero con error al guardar',
            itemsSincronizados: 0,
          );
        }
      } else {
        final mensaje = BaseSyncService.extractErrorMessage(response);

        return SyncResult(
          exito: false,
          mensaje: 'Error del servidor: $mensaje',
          itemsSincronizados: 0,
        );
      }

    } on TimeoutException {
      return SyncResult(
        exito: false,
        mensaje: 'Timeout de conexión',
        itemsSincronizados: 0,
      );

    } on SocketException {
      return SyncResult(
        exito: false,
        mensaje: 'Sin conexión de red',
        itemsSincronizados: 0,
      );

    } catch (e) {
      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

  static Future<SyncResult> obtenerImagenesRespuestasFormularios({
    String? edfvendedorId,
    String? contactoId,
    String? dynamicFormId,
    String? dynamicFormResponseId,
  }) async {
    String? currentEndpoint;

    try {
      final queryParams = _buildQueryParams(
        edfvendedorId: edfvendedorId,
        contactoId: contactoId,
        dynamicFormId: dynamicFormId,
        dynamicFormResponseId: dynamicFormResponseId,
      );

      final baseUrl = await BaseSyncService.getBaseUrl();
      final uri = Uri.parse('$baseUrl$_getDynamicFormResponseImageEndpoint')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
      currentEndpoint = uri.toString();

      final response = await http.get(
        uri,
        headers: BaseSyncService.headers,
      ).timeout(BaseSyncService.timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final imagenesData = _parseListResponse(response.body);

        if (imagenesData == null) {
          return SyncResult(
            exito: false,
            mensaje: 'Error parseando respuesta del servidor',
            itemsSincronizados: 0,
          );
        }

        if (imagenesData.isEmpty) {
          return SyncResult(
            exito: true,
            mensaje: 'No hay imágenes disponibles',
            itemsSincronizados: 0,
          );
        }

        try {
          final repo = DynamicFormRepository();
          final guardados = await repo.responses.saveResponseImagesFromServer(imagenesData);

          return SyncResult(
            exito: true,
            mensaje: 'Imágenes descargadas correctamente',
            itemsSincronizados: guardados,
            totalEnAPI: imagenesData.length,
          );
        } catch (dbError) {
          await ErrorLogService.logDatabaseError(
            tableName: 'dynamic_form_response_image',
            operation: 'bulk_insert',
            errorMessage: 'Error guardando imágenes: $dbError',
          );

          return SyncResult(
            exito: true,
            mensaje: 'Imágenes descargadas pero con error al guardar',
            itemsSincronizados: 0,
          );
        }
      } else {
        final mensaje = BaseSyncService.extractErrorMessage(response);

        return SyncResult(
          exito: false,
          mensaje: 'Error del servidor: $mensaje',
          itemsSincronizados: 0,
        );
      }

    } on TimeoutException {
      return SyncResult(
        exito: false,
        mensaje: 'Timeout de conexión',
        itemsSincronizados: 0,
      );

    } on SocketException {
      return SyncResult(
        exito: false,
        mensaje: 'Sin conexión de red',
        itemsSincronizados: 0,
      );

    } catch (e) {
      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

  static Future<SyncResult> obtenerRespuestasPorVendedor(String edfvendedorId) {
    return obtenerRespuestasFormularios(edfvendedorId: edfvendedorId);
  }

  static Future<SyncResult> obtenerImagenesPorVendedor(String edfvendedorId) {
    return obtenerImagenesRespuestasFormularios(edfvendedorId: edfvendedorId);
  }

  static Future<SyncResult> obtenerImagenesFormularios({
    String? edfVendedorId,
  }) {
    return obtenerImagenesRespuestasFormularios(edfvendedorId: edfVendedorId);
  }

  static Future<SyncResult> obtenerRespuestasCompletadas({String? edfvendedorId}) {
    return obtenerRespuestasFormularios(
      edfvendedorId: edfvendedorId,
      estado: 'completed',
    );
  }

  static Future<SyncResult> obtenerFormulariosActivos() {
    return obtenerFormulariosDinamicos(estado: 'ACTIVO');
  }

  static Future<SyncResult> obtenerFormulariosBorrador() {
    return obtenerFormulariosDinamicos(estado: 'BORRADOR');
  }

  static Future<List<Map<String, dynamic>>?> _fetchFormularios(
      String? estado,
      int? limit,
      int? offset,
      ) async {
    String? currentEndpoint;

    try {
      final queryParams = _buildQueryParams(
        estado: estado,
        limit: limit?.toString(),
        offset: offset?.toString(),
      );

      final baseUrl = await BaseSyncService.getBaseUrl();
      final uri = Uri.parse('$baseUrl$_getDynamicFormEndpoint')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
      currentEndpoint = uri.toString();

      final response = await http.get(
        uri,
        headers: BaseSyncService.headers,
      ).timeout(BaseSyncService.timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return _parseListResponse(response.body);
      } else {
        final mensaje = BaseSyncService.extractErrorMessage(response);

        await ErrorLogService.logServerError(
          tableName: 'dynamic_form',
          operation: 'fetch_forms',
          errorMessage: mensaje,
          errorCode: response.statusCode.toString(),
          endpoint: currentEndpoint,
        );

        return null;
      }

    } on TimeoutException catch (timeoutError) {
      await ErrorLogService.logNetworkError(
        tableName: 'dynamic_form',
        operation: 'fetch_forms',
        errorMessage: 'Timeout: $timeoutError',
        endpoint: currentEndpoint,
      );
      return null;

    } on SocketException catch (socketError) {
      await ErrorLogService.logNetworkError(
        tableName: 'dynamic_form',
        operation: 'fetch_forms',
        errorMessage: 'Sin conexión: $socketError',
        endpoint: currentEndpoint,
      );
      return null;

    } catch (e) {
      await ErrorLogService.logError(
        tableName: 'dynamic_form',
        operation: 'fetch_forms',
        errorMessage: 'Error: $e',
        errorType: 'unknown',
        endpoint: currentEndpoint,
      );
      return null;
    }
  }

  static Future<int> _syncDetalles(DynamicFormRepository repo) async {
    String? currentEndpoint;

    try {
      final baseUrl = await BaseSyncService.getBaseUrl();
      final uriDetalles = Uri.parse('$baseUrl$_getDynamicFormDetailEndpoint');
      currentEndpoint = uriDetalles.toString();

      final responseDetalles = await http.get(
        uriDetalles,
        headers: BaseSyncService.headers,
      ).timeout(BaseSyncService.timeout);

      if (responseDetalles.statusCode >= 200 && responseDetalles.statusCode < 300) {
        final detallesData = _parseListResponse(responseDetalles.body);

        if (detallesData != null && detallesData.isNotEmpty) {
          try {
            final detallesGuardados = await repo.templates.saveDetailsFromServer(detallesData);
            return detallesGuardados;
          } catch (dbError) {
            await ErrorLogService.logDatabaseError(
              tableName: 'dynamic_form_detail',
              operation: 'save_from_forms',
              errorMessage: 'Error guardando detalles: $dbError',
            );
            return 0;
          }
        }
      } else {
        await ErrorLogService.logServerError(
          tableName: 'dynamic_form_detail',
          operation: 'sync_from_forms',
          errorMessage: BaseSyncService.extractErrorMessage(responseDetalles),
          errorCode: responseDetalles.statusCode.toString(),
          endpoint: currentEndpoint,
        );
      }

      return 0;

    } on TimeoutException catch (timeoutError) {
      await ErrorLogService.logNetworkError(
        tableName: 'dynamic_form_detail',
        operation: 'sync_from_forms',
        errorMessage: 'Timeout: $timeoutError',
        endpoint: currentEndpoint,
      );
      return 0;

    } on SocketException catch (socketError) {
      await ErrorLogService.logNetworkError(
        tableName: 'dynamic_form_detail',
        operation: 'sync_from_forms',
        errorMessage: 'Sin conexión: $socketError',
        endpoint: currentEndpoint,
      );
      return 0;

    } catch (e) {
      await ErrorLogService.logError(
        tableName: 'dynamic_form_detail',
        operation: 'sync_from_forms',
        errorMessage: 'Error: $e',
        errorType: 'unknown',
        endpoint: currentEndpoint,
      );
      return 0;
    }
  }

  static List<Map<String, dynamic>>? _parseListResponse(String responseBody) {
    try {
      final parsed = jsonDecode(responseBody);

      if (parsed is List) {
        return parsed.cast<Map<String, dynamic>>();
      }

      if (parsed is Map && parsed.containsKey('data')) {
        final dataValue = parsed['data'];

        if (dataValue is String) {
          final decoded = jsonDecode(dataValue);
          if (decoded is List) {
            return decoded.cast<Map<String, dynamic>>();
          }
        }

        if (dataValue is List) {
          return dataValue.cast<Map<String, dynamic>>();
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

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