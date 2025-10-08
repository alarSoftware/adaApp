import 'dart:convert';
import '../models/dynamic_form/dynamic_form_template.dart';

/// Adaptador para convertir entre el formato del API y el formato local
class DynamicFormApiAdapter {
  /// Parsea la respuesta completa del API de formularios
  static List<Map<String, dynamic>> parseFormsResponse(String jsonResponse) {
    final Map<String, dynamic> response = jsonDecode(jsonResponse);

    if (response['status'] != 'OK') {
      throw Exception('Error en la respuesta del API: ${response['status']}');
    }

    return List<Map<String, dynamic>>.from(response['data'] as List);
  }

  /// Parsea la respuesta completa del API de detalles (preguntas)
  static List<Map<String, dynamic>> parseDetailsResponse(String jsonResponse) {
    final Map<String, dynamic> response = jsonDecode(jsonResponse);

    if (response['status'] != 'OK') {
      throw Exception('Error en la respuesta del API: ${response['status']}');
    }

    return List<Map<String, dynamic>>.from(response['data'] as List);
  }

  /// Crea un DynamicFormTemplate completo desde los JSONs del API
  static DynamicFormTemplate createTemplateFromApi({
    required Map<String, dynamic> formJson,
    required List<Map<String, dynamic>> detailsJson,
  }) {
    return DynamicFormTemplate.fromApiJson(formJson, detailsJson);
  }
}