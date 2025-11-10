// lib/services/post/dynamic_form_post_service.dart

import 'package:ada_app/services/post/base_post_service.dart';

class DynamicFormPostService {
  static const String _endpoint = '/api/insertDynamicFormResponse';

  /// Enviar respuesta de formulario dinámico
  static Future<Map<String, dynamic>> enviarRespuestaFormulario({
    required Map<String, dynamic> respuesta,
    bool incluirLog = false,
  }) async {
    if (incluirLog) {
      await BasePostService.logRequest(
        endpoint: _endpoint,
        body: respuesta,
        additionalInfo: 'Response ID: ${respuesta['id']}',
      );
    }

    return await BasePostService.post(
      endpoint: _endpoint,
      body: respuesta,
      timeout: const Duration(seconds: 90),
    );
  }

  /// Reintentar envío de respuesta fallida
  static Future<Map<String, dynamic>> reintentarEnvioRespuesta({
    required String responseId,
    required Map<String, dynamic> respuesta,
  }) async {
    BasePostService.logger.i('🔁 Reintentando respuesta: $responseId');

    return await enviarRespuestaFormulario(
      respuesta: respuesta,
      incluirLog: true,
    );
  }
}