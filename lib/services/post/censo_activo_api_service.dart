import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:ada_app/services/api_config_service.dart';
import 'package:ada_app/services/auth_service.dart';
import 'package:logger/logger.dart';

class CensoActivoApiService {
  static const String _endpoint = '/censoActivo/insertCensoActivo';
  static const int _timeoutSegundos = 30;
  static final Logger _logger = Logger();
  static final AuthService _authService = AuthService();

  /// Envía un cambio de estado de equipo al servidor
  static Future<Map<String, dynamic>> enviarCambioEstado({
    required String codigoBarras,
    required int clienteId,
    required bool enLocal,
    required Position position,
    String? observaciones,
    String? imagenBase64,
    String? imagenBase64_2,
    String? equipoId,
    String? clienteNombre,
    String? numeroSerie,
    String? modelo,
    String? marca,
    String? logo,
  }) async {
    try {
      final fullUrl = await ApiConfigService.getFullUrl(_endpoint);

      // Obtener usuario actual
      final usuario = await _authService.getCurrentUser();
      final usuarioId = usuario?.id ?? 1;
      final edfVendedorId = usuario?.edfVendedorId ?? '';

      final now = DateTime.now().toLocal();
      final timestampId = now.millisecondsSinceEpoch;

      // Formatear fecha sin UTC (igual que en preview_screen_viewmodel)
      String formatearFechaLocal(DateTime fecha) {
        final local = fecha.toLocal();
        return local.toIso8601String().replaceAll('Z', '');
      }

      // Estructura IDÉNTICA a _prepararDatosParaApiEstados
      final datos = {
        'id': timestampId.toString(),
        'edfVendedorSucursalId': edfVendedorId,
        'edfEquipoId': equipoId ?? codigoBarras,
        'usuarioId': usuarioId,
        'edfClienteId': clienteId,
        'fecha_revision': formatearFechaLocal(now),
        'latitud': position.latitude,
        'longitud': position.longitude,
        'enLocal': enLocal,
        'fechaDeRevision': formatearFechaLocal(now),
        'estadoCenso': 'asignado', // Ya que es un equipo asignado cambiando a "fuera del local"
        'equipo_codigo_barras': codigoBarras,
        'equipo_numero_serie': numeroSerie ?? '',
        'equipo_modelo': modelo ?? '',
        'equipo_marca': marca ?? '',
        'equipo_logo': logo ?? '',
        'equipo_id': equipoId ?? codigoBarras,
        'cliente_nombre': clienteNombre ?? '',
        'observaciones': observaciones ?? '',
        'cliente_id': clienteId,
        'usuario_id': usuarioId,
        'imagenPath': null,
        'imageBase64_1': imagenBase64,
        'imageBase64_2': imagenBase64_2,
        'imageSize': null,
        'en_local': enLocal,
        'dispositivo': 'android',
        'es_censo': false, // No es censo, es cambio de ubicación
        'version_app': '1.0.0',
        'estado_general': observaciones ?? 'Cambio de ubicación desde APP móvil',
        'imagen_tamano': null,
        'imagen_base64': imagenBase64,
        'imagen_base64_2': imagenBase64_2,
        'imagen_tamano2': null,
        'tiene_imagen': imagenBase64 != null && imagenBase64.isNotEmpty,
        'tiene_imagen2': imagenBase64_2 != null && imagenBase64_2.isNotEmpty,
        'imagen_path': null,
        'imagen_path2': null,
      };

      _logger.i('📤 Enviando a: $fullUrl');
      _logger.i('📤 Datos: ${json.encode(datos)}');

      final response = await http.post(
        Uri.parse(fullUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(datos),
      ).timeout(Duration(seconds: _timeoutSegundos));

      _logger.i('📥 Status: ${response.statusCode}');
      _logger.i('📥 Response body: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return _procesarRespuestaExitosa(response);
      } else {
        return {
          'exito': false,
          'mensaje': 'Error del servidor: ${response.statusCode}',
        };
      }
    } on http.ClientException catch (e) {
      return {
        'exito': false,
        'mensaje': 'Error de red: ${e.message}',
      };
    } on TimeoutException catch (_) {
      return {
        'exito': false,
        'mensaje': 'Tiempo de espera agotado. Verifica tu conexión.',
      };
    } catch (e) {
      _logger.e('❌ Error en enviarCambioEstado: $e');
      return {
        'exito': false,
        'mensaje': 'Error de conexión: $e',
      };
    }
  }

  static Map<String, dynamic> _procesarRespuestaExitosa(http.Response response) {
    dynamic servidorId = DateTime.now().millisecondsSinceEpoch;
    String mensaje = 'Estado registrado correctamente';

    try {
      final responseBody = json.decode(response.body);

      servidorId = responseBody['estado']?['id'] ??
          responseBody['id'] ??
          responseBody['insertId'] ??
          servidorId;

      if (responseBody['message'] != null) {
        mensaje = responseBody['message'].toString();
      }
    } catch (e) {
      // Error parseando respuesta, pero el POST fue exitoso
    }

    return {
      'exito': true,
      'id': servidorId,
      'mensaje': mensaje,
    };
  }
}