import 'dart:convert';
import 'package:ada_app/config/constants/server_constants.dart';
import 'package:http/http.dart' as http;

class ServerResponse {
  final bool success;
  final String message;
  final int? serverAction;
  final dynamic resultId;
  final bool isDuplicate;
  final int httpStatusCode;
  final String? resultJson;

  ServerResponse({
    required this.success,
    required this.message,
    this.serverAction,
    this.resultId,
    this.isDuplicate = false,
    required this.httpStatusCode,
    this.resultJson,
  });

  /// Factory principal que convierte la respuesta HTTP cruda en un objeto tipado
  factory ServerResponse.fromHttp(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return ServerResponse(
        success: false,
        message: 'Error HTTP del servidor: ${response.statusCode}',
        httpStatusCode: response.statusCode,
      );
    }

    try {
      final body = json.decode(response.body);

      if (body is! Map) {
        return ServerResponse(
          success: false,
          message: 'Formato de respuesta inválido (no es un JSON válido)',
          httpStatusCode: response.statusCode,
        );
      }

      final serverAction = body['serverAction'] as int?;
      final resultMessage =
          body['resultMessage'] as String? ??
          body['resultError'] as String? ??
          '';
      final resultId = body['resultId'] ?? body['id'];

      String? resultJson;
      if (body['resultJson'] is Map) {
        resultJson = jsonEncode(body['resultJson']);
      } else if (body['resultJson'] is String) {
        resultJson = body['resultJson'];
      }

      if (serverAction == ServerConstants.SUCCESS_TRANSACTION) {
        return ServerResponse(
          success: true,
          message: resultMessage.isNotEmpty
              ? resultMessage
              : 'Procesado correctamente',
          serverAction: serverAction,
          resultId: resultId,
          resultJson: resultJson,
          httpStatusCode: response.statusCode,
        );
      } else if (serverAction == ServerConstants.ERROR) {
        final msgUpper = resultMessage.toUpperCase();
        final esDuplicado =
            msgUpper.contains('DUPLICADO') ||
            msgUpper.contains('UNIQUE CONSTRAINT') ||
            msgUpper.contains('ALREADY EXISTS');

        return ServerResponse(
          success: false,
          message: resultMessage.isNotEmpty
              ? resultMessage
              : 'Error de negocio',
          serverAction: serverAction,
          isDuplicate: esDuplicado,
          httpStatusCode: response.statusCode,
        );
      } else {
        return ServerResponse(
          success: false,
          message: resultMessage.isNotEmpty
              ? resultMessage
              : 'Acción rechazada por el servidor',
          serverAction: serverAction,
          httpStatusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ServerResponse(
        success: false,
        message: 'Error al interpretar respuesta: $e',
        httpStatusCode: response.statusCode,
      );
    }
  }
}
