import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:ada_app/services/api_config_service.dart';
import 'package:ada_app/config/constants/server_constants.dart';
import 'package:ada_app/services/error_log/error_log_service.dart';

class EquipoPostService {
  static final Logger _logger = Logger();
  static const String _tableName = 'equipments'; // Para el log
  static const String _endpoint = '/edfEquipo/insertEdfEquipo/';

  /// Enviar equipo nuevo al servidor
  static Future<Map<String, dynamic>> enviarEquipoNuevo({
    required String equipoId,
    required String codigoBarras,
    required int marcaId,
    required int modeloId,
    required int logoId,
    String? numeroSerie,
    String? clienteId,
    required String edfVendedorId,
  }) async {
    String? fullUrl;

    try {
      _logger.i('📤 === INICIANDO ENVÍO DE EQUIPO ===');

      // 1. Validación Local
      if (codigoBarras.isEmpty) {
        await ErrorLogService.logValidationError(
          tableName: _tableName,
          operation: 'POST_VALIDATION',
          errorMessage: 'El código de barras está vacío',
          registroFailId: equipoId,
        );
        return {
          'exito': false,
          'mensaje': 'El código de barras no puede estar vacío',
        };
      }

      // 2. Construcción del Payload (Tu lógica probada)
      final payload = _construirPayload(
        equipoId: equipoId,
        codigoBarras: codigoBarras,
        marcaId: marcaId,
        modeloId: modeloId,
        logoId: logoId,
        numeroSerie: numeroSerie,
        clienteId: clienteId,
        edfVendedorId: edfVendedorId,
      );

      final jsonPayload = jsonEncode(payload);

      // 3. Envío HTTP
      final baseUrl = await ApiConfigService.getBaseUrl();
      fullUrl = '$baseUrl$_endpoint';

      _logger.i('🌐 Enviando a: $fullUrl');

      final response = await http.post(
        Uri.parse(fullUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonPayload,
      ).timeout(const Duration(seconds: 60)); // Timeout generoso para equipos

      _logger.i('📥 Status Code: ${response.statusCode}');

      // ===============================================================
      // 🛡️ VALIDACIÓN ESTRICTA (Lógica del Jefe)
      // ===============================================================

      // A. Intentar decodificar JSON
      Map<String, dynamic> responseBody = {};
      try {
        responseBody = jsonDecode(response.body);
      } catch (e) {
        // Si falla el JSON, es un error grave del servidor (HTML, texto, etc.)
        await ErrorLogService.logServerError(
          tableName: _tableName,
          operation: 'POST_FORMAT_ERROR',
          errorMessage: 'Respuesta no es JSON válido: ${response.body}',
          errorCode: response.statusCode.toString(),
          registroFailId: equipoId,
          endpoint: fullUrl,
        );
        return {
          'exito': false,
          'mensaje': 'Error de formato en respuesta del servidor',
        };
      }

      final serverAction = responseBody['serverAction'] as int? ?? -999;
      final resultError = responseBody['resultError'];
      final resultMessage = responseBody['resultMessage'];

      // B. Evaluar ServerAction
      if (serverAction == ServerConstants.SUCCESS_TRANSACTION) {
        // ✅ ÉXITO (100)
        _logger.i('✅ Equipo registrado correctamente (Action 100)');
        return {
          'exito': true,
          'mensaje': resultMessage ?? 'Equipo registrado correctamente',
          'servidor_id': responseBody['resultId'],
          'server_action': serverAction,
        };
      } else {
        // ❌ ERROR LÓGICO (-501, 205, etc)
        final errorMsg = resultError ?? resultMessage ?? 'Error desconocido ($serverAction)';
        _logger.e('❌ Servidor rechazó equipo: $errorMsg');

        await ErrorLogService.logServerError(
          tableName: _tableName,
          operation: 'POST_LOGIC_FAIL',
          errorMessage: errorMsg,
          errorCode: serverAction.toString(),
          registroFailId: equipoId,
          endpoint: fullUrl,
          userId: edfVendedorId,
        );

        return {
          'exito': false,
          'mensaje': errorMsg,
          'server_action': serverAction,
          'error': 'server_logic_error'
        };
      }

    } on SocketException catch (e) {
      _logger.e('📡 Sin conexión: $e');
      // Opcional: Loguear NetworkError si quieres traquear fallos de conectividad
      return {
        'exito': false,
        'mensaje': 'Sin conexión a internet',
        'error': 'no_connection',
      };

    } on TimeoutException catch (e) {
      _logger.e('⏰ Timeout: $e');
      await ErrorLogService.logNetworkError(
        tableName: _tableName,
        operation: 'POST_TIMEOUT',
        errorMessage: 'Tiempo de espera agotado (60s)',
        registroFailId: equipoId,
        endpoint: fullUrl,
      );
      return {
        'exito': false,
        'mensaje': 'El servidor tardó demasiado en responder',
        'error': 'timeout',
      };

    } catch (e, stackTrace) {
      _logger.e('❌ Error inesperado: $e');
      await ErrorLogService.logError(
        tableName: _tableName,
        operation: 'POST_EXCEPTION',
        errorMessage: e.toString(),
        errorType: 'crash',
        registroFailId: equipoId,
      );
      return {
        'exito': false,
        'mensaje': 'Error interno de la aplicación: $e',
        'error': 'unknown',
      };
    }
  }

  /// Construir payload compatible con el backend Groovy
  /// FLAGS COMO ENTEROS (0 o 1) - Mantenemos tu lógica exacta
  static Map<String, dynamic> _construirPayload({
    required String equipoId,
    required String codigoBarras,
    required int marcaId,
    required int modeloId,
    required int logoId,
    String? numeroSerie,
    String? clienteId,
    required String edfVendedorId,
  }) {
    final now = DateTime.now().toIso8601String();

    // 🔥 CONVERSIÓN DE BOOLEANOS A ENTEROS (0 o 1)
    final int appInsertInt = 1;
    final int esActivoInt = 1;
    final int esAplicaCensoInt = 1;
    final int esDisponibleInt = (clienteId == null || clienteId.isEmpty) ? 1 : 0;

    return {
      'id': codigoBarras,
      'equipoId': codigoBarras,
      'equipo_id': codigoBarras,
      'codigoBarras': codigoBarras,
      'codigo_barras': codigoBarras,
      'edfModeloId': modeloId,
      'edf_modelo_id': modeloId,
      'marcaId': marcaId.toString(),
      'marca_id': marcaId.toString(),
    };
  }
}