import 'dart:convert';
import '../models/dynamic_form/dynamic_form_template.dart';

/// Adaptador para convertir entre el formato del API y el formato local
class DynamicFormApiAdapter {

  // ==================== CONSTANTES ====================

  static const String _statusOk = 'OK';
  static const String _dataKey = 'data';
  static const String _statusKey = 'status';

  // ==================== PARSING DE RESPUESTAS ====================

  /// Parsea la respuesta completa del API de formularios
  static List<Map<String, dynamic>> parseFormsResponse(String jsonResponse) {
    return _parseApiResponse(jsonResponse, 'formularios');
  }

  /// Parsea la respuesta completa del API de detalles (preguntas)
  static List<Map<String, dynamic>> parseDetailsResponse(String jsonResponse) {
    return _parseApiResponse(jsonResponse, 'detalles');
  }

  /// Crea un DynamicFormTemplate completo desde los JSONs del API
  static DynamicFormTemplate createTemplateFromApi({
    required Map<String, dynamic> formJson,
    required List<Map<String, dynamic>> detailsJson,
  }) {
    return DynamicFormTemplate.fromApiJson(formJson, detailsJson);
  }

  // ==================== HELPERS PRIVADOS ====================

  /// Parser genérico para respuestas del API
  static List<Map<String, dynamic>> _parseApiResponse(
      String jsonResponse,
      String resourceName,
      ) {
    try {
      final Map<String, dynamic> response = jsonDecode(jsonResponse);

      // Validar status
      if (response[_statusKey] != _statusOk) {
        throw ApiResponseException(
          'Error en la respuesta del API de $resourceName: ${response[_statusKey]}',
          statusCode: response[_statusKey],
        );
      }

      // Validar que existe el campo data
      if (!response.containsKey(_dataKey)) {
        throw ApiResponseException(
          'Respuesta del API sin campo "$_dataKey"',
          statusCode: response[_statusKey],
        );
      }

      final data = response[_dataKey];

      // Parsear data (puede ser List o String con JSON)
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }

      if (data is String) {
        final decoded = jsonDecode(data);
        if (decoded is List) {
          return List<Map<String, dynamic>>.from(decoded);
        }
      }

      throw ApiResponseException(
        'Formato inesperado en campo "$_dataKey" para $resourceName',
        statusCode: response[_statusKey],
      );
    } on FormatException catch (e) {
      throw ApiResponseException(
        'JSON inválido: ${e.message}',
        originalException: e,
      );
    } on ApiResponseException {
      rethrow;
    } catch (e) {
      throw ApiResponseException(
        'Error parseando respuesta de $resourceName: $e',
        originalException: e,
      );
    }
  }

  // ==================== VALIDACIÓN ====================

  /// Valida que la respuesta tenga la estructura esperada
  static bool isValidApiResponse(String jsonResponse) {
    try {
      final response = jsonDecode(jsonResponse);
      return response is Map<String, dynamic> &&
          response.containsKey(_statusKey) &&
          response.containsKey(_dataKey);
    } catch (e) {
      return false;
    }
  }

  /// Valida que el status sea OK
  static bool hasSuccessStatus(String jsonResponse) {
    try {
      final response = jsonDecode(jsonResponse);
      return response[_statusKey] == _statusOk;
    } catch (e) {
      return false;
    }
  }
}

// ==================== EXCEPCIÓN PERSONALIZADA ====================

/// Excepción específica para errores del API
class ApiResponseException implements Exception {
  final String message;
  final String? statusCode;
  final dynamic originalException;

  ApiResponseException(
      this.message, {
        this.statusCode,
        this.originalException,
      });

  @override
  String toString() {
    final buffer = StringBuffer('ApiResponseException: $message');

    if (statusCode != null) {
      buffer.write(' (Status: $statusCode)');
    }

    if (originalException != null) {
      buffer.write('\nCaused by: $originalException');
    }

    return buffer.toString();
  }
}