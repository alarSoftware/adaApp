// lib/services/post/equipo_post_service.dart

import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:ada_app/services/api_config_service.dart';

class EquipoPostService {
  static final Logger _logger = Logger();
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
    try {
      _logger.i('📤 Enviando equipo: $equipoId');

      // ✅ Construir payload que coincide con EdfEquipo.groovy
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

      _logger.i('📦 Payload:');
      _logger.i(jsonEncode(payload));

      // Obtener URL completa
      final baseUrl = await ApiConfigService.getBaseUrl();
      final fullUrl = '$baseUrl$_endpoint';

      _logger.i('🌐 URL: $fullUrl');

      // Enviar al servidor
      final response = await http.post(
        Uri.parse(fullUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(Duration(seconds: 60));

      _logger.i('📥 Response Status: ${response.statusCode}');
      _logger.i('📄 Response Body: ${response.body}');

      // Procesar respuesta
      return _procesarRespuesta(response);

    } on TimeoutException catch (e) {
      _logger.e('⏰ Timeout: $e');
      return {
        'exito': false,
        'mensaje': 'Tiempo de espera agotado',
        'error': e.toString(),
      };

    } on SocketException catch (e) {
      _logger.e('📡 Sin conexión: $e');
      return {
        'exito': false,
        'mensaje': 'Sin conexión de red',
        'error': e.toString(),
      };

    } catch (e) {
      _logger.e('❌ Error: $e');
      return {
        'exito': false,
        'mensaje': 'Error: $e',
        'error': e.toString(),
      };
    }
  }

  /// ✅ Construir payload según tu clase EdfEquipo.groovy
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

    // Según tu clase Groovy EdfEquipo:
    return {
      // IDs principales
      'id': equipoId,                      // id (text)
      'equipoId': equipoId,                // equipoId (text)

      // IDs de relaciones (según Groovy)
      'marcaId': marcaId.toString(),       // marcaId (text en Groovy)
      'edfModeloId': modeloId,             // edfModeloId (Long)
      'edfLogoId': logoId,                 // edfLogoId (Long)

      // Campos de texto
      'codigoBarras': codigoBarras,        // codigoBarras (nuevo campo)
      'numSerie': numeroSerie,             // numSerie (text)
      'equipo': codigoBarras,              // equipo (text) - descripción

      // Cliente
      'clienteId': clienteId,              // clienteId (text)

      // Flags booleanos
      'appInsert': true,                   // appInsert (Boolean)
      'esActivo': true,                    // esActivo (Boolean)
      'esDisponible': true,                // esDisponible (Boolean)
      'esAplicaCenso': true,               // esAplicaCenso (Boolean)

      // Fechas
      'fecha': now,                        // fecha (Date)

      // Metadata
      'vendedorSucursalId': edfVendedorId, // Para tracking
      'version': 0,                        // version de GORM
    };
  }

  /// Procesar respuesta del servidor
  static Map<String, dynamic> _procesarRespuesta(http.Response response) {
    // Si el status no es 2xx
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return {
        'exito': false,
        'mensaje': 'Error del servidor: ${response.statusCode}',
        'status_code': response.statusCode,
      };
    }

    try {
      // Intentar parsear como JSON
      final body = jsonDecode(response.body);

      // Si viene con serverAction
      if (body is Map && body.containsKey('serverAction')) {
        final serverAction = body['serverAction'];

        if (serverAction == 100) {
          return {
            'exito': true,
            'mensaje': body['resultMessage'] ?? 'Equipo registrado',
            'servidor_id': body['resultId'],
            'server_action': serverAction,
          };
        } else {
          return {
            'exito': false,
            'mensaje': body['resultError'] ?? body['resultMessage'] ?? 'Error del servidor',
            'server_action': serverAction,
          };
        }
      }

      // Si es otro formato JSON
      if (body is Map && body['success'] == true) {
        return {
          'exito': true,
          'mensaje': 'Equipo registrado correctamente',
          'data': body,
        };
      }

    } catch (e) {
      _logger.w('⚠️ No es JSON, procesando como texto: $e');
    }

    // Procesar como texto plano
    final bodyText = response.body.toLowerCase();

    if (bodyText.contains('registrado') ||
        bodyText.contains('éxito') ||
        bodyText.contains('success')) {
      return {
        'exito': true,
        'mensaje': 'Equipo registrado correctamente',
      };
    }

    if (bodyText.contains('ya existe') || bodyText.contains('duplicado')) {
      return {
        'exito': true,
        'mensaje': 'Equipo ya estaba registrado',
      };
    }

    return {
      'exito': false,
      'mensaje': response.body,
    };
  }
}