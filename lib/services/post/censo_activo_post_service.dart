// lib/services/post/censo_activo_post_service.dart

import 'package:geolocator/geolocator.dart';
import 'package:ada_app/services/post/base_post_service.dart';
import 'package:ada_app/services/auth_service.dart';

class CensoActivoPostService {
  static const String _endpoint = '/censoActivo/insertCensoActivo';
  static final AuthService _authService = AuthService();

  /// Enviar cambio de estado de equipo
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
    // Obtener usuario actual
    final usuario = await _authService.getCurrentUser();
    final usuarioId = usuario?.id ?? 1;
    final edfVendedorId = usuario?.edfVendedorId ?? '';

    final now = DateTime.now().toLocal();
    final timestampId = now.millisecondsSinceEpoch;

    // Preparar datos
    final datos = _prepararDatosEstado(
      timestampId: timestampId,
      edfVendedorId: edfVendedorId,
      equipoId: equipoId ?? codigoBarras,
      usuarioId: usuarioId,
      clienteId: clienteId,
      position: position,
      enLocal: enLocal,
      observaciones: observaciones,
      imagenBase64: imagenBase64,
      imagenBase64_2: imagenBase64_2,
      codigoBarras: codigoBarras,
      numeroSerie: numeroSerie,
      modelo: modelo,
      marca: marca,
      logo: logo,
      clienteNombre: clienteNombre,
      now: now,
    );

    return await BasePostService.post(
      endpoint: _endpoint,
      body: datos,
      timeout: const Duration(seconds: 30),
    );
  }

  /// Preparar datos para el estado
  static Map<String, dynamic> _prepararDatosEstado({
    required int timestampId,
    required String edfVendedorId,
    required String equipoId,
    required int usuarioId,
    required int clienteId,
    required Position position,
    required bool enLocal,
    required DateTime now,
    String? observaciones,
    String? imagenBase64,
    String? imagenBase64_2,
    String? codigoBarras,
    String? numeroSerie,
    String? modelo,
    String? marca,
    String? logo,
    String? clienteNombre,
  }) {
    String formatearFechaLocal(DateTime fecha) {
      final local = fecha.toLocal();
      return local.toIso8601String().replaceAll('Z', '');
    }

    return {
      'id': timestampId.toString(),
      'edfVendedorSucursalId': edfVendedorId,
      'edfEquipoId': equipoId,
      'usuarioId': usuarioId,
      'edfClienteId': clienteId,
      'fecha_revision': formatearFechaLocal(now),
      'latitud': position.latitude,
      'longitud': position.longitude,
      'enLocal': enLocal,
      'fechaDeRevision': formatearFechaLocal(now),
      'estadoCenso': 'asignado',
      'equipo_codigo_barras': codigoBarras,
      'equipo_numero_serie': numeroSerie ?? '',
      'equipo_modelo': modelo ?? '',
      'equipo_marca': marca ?? '',
      'equipo_logo': logo ?? '',
      'equipo_id': equipoId,
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
      'es_censo': false,
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
  }
}