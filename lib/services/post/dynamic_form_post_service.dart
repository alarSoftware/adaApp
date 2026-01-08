import 'package:flutter/foundation.dart';
import 'package:ada_app/services/post/base_post_service.dart';

class DynamicFormPostService {
  static const String _endpoint =
      '/dynamicFormResponse/insertDynamicFormResponse';
  static const String _tableName = 'dynamic_form_response';

  /// Enviar respuesta de formulario dinámico
  static Future<Map<String, dynamic>> enviarRespuestaFormulario({
    required Map<String, dynamic> respuesta,
    bool incluirLog = false,
    String? userId,
  }) async {
    final responseId = respuesta['id']?.toString();

    if (incluirLog) {
      await BasePostService.logRequest(
        endpoint: _endpoint,
        body: respuesta,
        additionalInfo: 'Response ID: $responseId',
      );
    }

    // BasePostService ya maneja TODOS los errores y logging
    return await BasePostService.post(
      endpoint: _endpoint,
      body: respuesta,
      timeout: const Duration(seconds: 90),
      tableName: _tableName, // Activa el logging automático
      registroId: responseId,
      userId: userId,
    );
  }

  /// Reintentar envío de respuesta fallida
  static Future<Map<String, dynamic>> reintentarEnvioRespuesta({
    required String responseId,
    required Map<String, dynamic> respuesta,
    int intentoNumero = 1,
    String? userId,
  }) async {
    debugPrint('Reintentando: $responseId (Intento #$intentoNumero)');

    final result = await enviarRespuestaFormulario(
      respuesta: respuesta,
      incluirLog: true,
      userId: userId,
    );

    // Solo loguear el reintento específicamente si falló
    if (result['success'] == false || result['exito'] == false) {}

    return result;
  }
}
