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
      _logger.i('📤 === INICIANDO ENVÍO DE EQUIPO ===');
      _logger.i('   - equipoId (local): $equipoId');
      _logger.i('   - codigoBarras (backend): "$codigoBarras"');

      // Validar que el código de barras no esté vacío
      if (codigoBarras.isEmpty) {
        _logger.e('❌ ERROR CRÍTICO: codigoBarras está vacío');
        return {
          'exito': false,
          'mensaje': 'El código de barras no puede estar vacío',
          'error': 'empty_barcode',
        };
      }

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

      // ✅ LOG DETALLADO DEL PAYLOAD
      _logger.i('📦 PAYLOAD A ENVIAR:');
      _logger.i('   Campos principales:');
      _logger.i('     - id: ${payload['id']}');
      _logger.i('     - equipoId: ${payload['equipoId']}');
      _logger.i('     - codigoBarras: ${payload['codigoBarras']}');
      _logger.i('   Relaciones:');
      _logger.i('     - edfModeloId: ${payload['edfModeloId']}');
      _logger.i('     - edfLogoId: ${payload['edfLogoId']}');
      _logger.i('     - marcaId: ${payload['marcaId']}');
      _logger.i('     - clienteId: ${payload['clienteId']}');
      _logger.i('   Flags (como enteros):');
      _logger.i('     - appInsert: ${payload['appInsert']}');
      _logger.i('     - esActivo: ${payload['esActivo']}');
      _logger.i('     - esDisponible: ${payload['esDisponible']}');

      final jsonPayload = jsonEncode(payload);
      _logger.i('📏 TAMAÑO DEL JSON: ${jsonPayload.length} caracteres');

      // Validar tamaño
      if (jsonPayload.length > 50000) {
        _logger.e('❌ PAYLOAD DEMASIADO GRANDE: ${jsonPayload.length} caracteres');
        return {
          'exito': false,
          'mensaje': 'Payload demasiado grande: ${jsonPayload.length} caracteres',
          'error': 'payload_too_large',
        };
      }

      // Mostrar JSON completo si es pequeño
      if (jsonPayload.length < 2000) {
        _logger.i('📄 JSON COMPLETO:');
        _logger.i(jsonPayload);
      }

      final baseUrl = await ApiConfigService.getBaseUrl();
      final fullUrl = '$baseUrl$_endpoint';

      _logger.i('🌐 URL COMPLETA: $fullUrl');

      final response = await http.post(
        Uri.parse(fullUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonPayload,
      ).timeout(Duration(seconds: 60));

      _logger.i('📥 === RESPUESTA RECIBIDA ===');
      _logger.i('   Status: ${response.statusCode}');
      _logger.i('   Body: ${response.body}');

      return _procesarRespuesta(response);

    } on SocketException catch (e) {
      _logger.e('📡 Sin conexión a internet: $e');
      return {
        'exito': false,
        'mensaje': 'Sin conexión a internet',
        'error': 'no_connection',
      };

    } on TimeoutException catch (e) {
      _logger.e('⏰ Timeout en la petición: $e');
      return {
        'exito': false,
        'mensaje': 'Tiempo de espera agotado',
        'error': 'timeout',
      };

    } catch (e, stackTrace) {
      _logger.e('❌ Error inesperado: $e');
      _logger.e('StackTrace: $stackTrace');
      return {
        'exito': false,
        'mensaje': 'Error: $e',
        'error': e.toString(),
      };
    }
  }

  /// Construir payload compatible con el backend Groovy
  /// FLAGS COMO ENTEROS (0 o 1) en lugar de booleanos
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

    _logger.i('📦 === CONSTRUYENDO PAYLOAD ===');
    _logger.i('   codigoBarras: "$codigoBarras"');
    _logger.i('   marcaId: $marcaId');
    _logger.i('   modeloId: $modeloId');
    _logger.i('   logoId: $logoId');
    _logger.i('   clienteId: "$clienteId"');

    // 🔥 CONVERSIÓN DE BOOLEANOS A ENTEROS (0 o 1)
    final int appInsertInt = 1;  // Siempre 1 para equipos creados desde app
    final int esActivoInt = 1;
    final int esAplicaCensoInt = 1;
    final int esDisponibleInt = (clienteId == null || clienteId.isEmpty) ? 1 : 0;

    _logger.i('   Flags convertidos a int:');
    _logger.i('     - appInsert: $appInsertInt');
    _logger.i('     - esActivo: $esActivoInt');
    _logger.i('     - esAplicaCenso: $esAplicaCensoInt');
    _logger.i('     - esDisponible: $esDisponibleInt');

    final payload = {
      // ========================================
      // CAMPOS PRINCIPALES (ambos formatos)
      // ========================================
      'id': codigoBarras,
      'equipoId': codigoBarras,
      'equipo_id': codigoBarras,
      'codigoBarras': codigoBarras,
      'codigo_barras': codigoBarras,

      // ========================================
      // RELACIONES (ambos formatos)
      // ========================================
      'edfModeloId': modeloId,
      'edf_modelo_id': modeloId,
      'edfLogoId': logoId,
      'edf_logo_id': logoId,
      'marcaId': marcaId.toString(),
      'marca_id': marcaId.toString(),
      'clienteId': clienteId,
      'cliente_id': clienteId,

      // ========================================
      // INFORMACIÓN ADICIONAL (ambos formatos)
      // ========================================
      'numSerie': numeroSerie ?? '',
      'num_serie': numeroSerie ?? '',
      'equipo': null,

      // ========================================
      // FLAGS COMO ENTEROS (0 o 1) - NO BOOLEANOS
      // ========================================
      'appInsert': appInsertInt,
      'app_insert': appInsertInt,
      'esActivo': esActivoInt,
      'es_activo': esActivoInt,
      'esAplicaCenso': esAplicaCensoInt,
      'es_aplica_censo': esAplicaCensoInt,
      'esDisponible': esDisponibleInt,
      'es_disponible': esDisponibleInt,

      // ========================================
      // CAMPOS OPCIONALES (ambos formatos)
      // ========================================
      'tipEquipoId': null,
      'tip_equipo_id': null,
      'condicionId': null,
      'condicion_id': null,
      'ubicacionId': null,
      'ubicacion_id': null,
      'proveedorId': null,
      'proveedor_id': null,
      'fecha': now,
      'fecCompra': null,
      'fec_compra': null,
      'fecVencGarantia': null,
      'fec_venc_garantia': null,
      'facNumero': null,
      'fac_numero': null,
      'costo': null,
      'fecFactura': null,
      'fec_factura': null,
      'observacion': null,
      'fechaBaja': null,
      'fecha_baja': null,
      'ubicacionInterna': null,
      'ubicacion_interna': null,
      'monedaId': null,
      'moneda_id': null,
    };

    _logger.i('✅ Payload construido con ${payload.keys.length} campos');

    return payload;
  }

  /// Procesar respuesta del servidor
  static Map<String, dynamic> _procesarRespuesta(http.Response response) {
    _logger.i('🔍 === PROCESANDO RESPUESTA ===');
    _logger.i('   Status Code: ${response.statusCode}');

    // Verificar status code
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _logger.e('❌ Status code fuera de rango 2xx: ${response.statusCode}');
      return {
        'exito': false,
        'mensaje': 'Error del servidor: ${response.statusCode}',
        'status_code': response.statusCode,
        'body': response.body,
      };
    }

    // Intentar parsear como JSON
    try {
      final body = jsonDecode(response.body);
      _logger.i('✅ Respuesta parseada como JSON');

      // Formato con serverAction (Groovy)
      if (body is Map && body.containsKey('serverAction')) {
        final serverAction = body['serverAction'];
        _logger.i('   serverAction: $serverAction');

        if (serverAction == 100) {
          _logger.i('✅ Equipo registrado exitosamente');
          return {
            'exito': true,
            'mensaje': body['resultMessage'] ?? 'Equipo registrado correctamente',
            'servidor_id': body['resultId'],
            'server_action': serverAction,
          };
        } else {
          _logger.e('❌ serverAction indica error: $serverAction');
          return {
            'exito': false,
            'mensaje': body['resultError'] ?? body['resultMessage'] ?? 'Error del servidor',
            'server_action': serverAction,
          };
        }
      }

      // Formato genérico con success
      if (body is Map && body['success'] == true) {
        _logger.i('✅ Respuesta exitosa (formato genérico)');
        return {
          'exito': true,
          'mensaje': body['message'] ?? 'Equipo registrado correctamente',
          'data': body,
        };
      }

      // Formato desconocido
      _logger.w('⚠️ Formato JSON no reconocido: $body');
      return {
        'exito': false,
        'mensaje': 'Formato de respuesta no reconocido',
        'data': body,
      };

    } catch (e) {
      _logger.w('⚠️ Respuesta no es JSON: $e');
    }

    // Procesar como texto plano
    final bodyText = response.body.toLowerCase();

    if (bodyText.contains('registrado') ||
        bodyText.contains('success') ||
        bodyText.contains('ok')) {
      _logger.i('✅ Texto indica éxito');
      return {
        'exito': true,
        'mensaje': 'Equipo registrado correctamente',
        'body': response.body,
      };
    }

    if (bodyText.contains('ya existe') || bodyText.contains('duplicate')) {
      _logger.i('✅ Equipo ya existía');
      return {
        'exito': true,
        'mensaje': 'El equipo ya estaba registrado',
        'body': response.body,
      };
    }

    if (bodyText.contains('<!doctype html>') || bodyText.contains('<html')) {
      _logger.e('❌ Servidor devolvió HTML');
      return {
        'exito': false,
        'mensaje': 'Servidor devolvió HTML. Verifica el endpoint.',
        'error': 'html_response',
      };
    }

    _logger.w('⚠️ Respuesta no reconocida');
    return {
      'exito': false,
      'mensaje': 'Respuesta del servidor no reconocida',
      'body': response.body,
    };
  }
}