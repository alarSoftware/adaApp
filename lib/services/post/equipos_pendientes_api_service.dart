import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:uuid/uuid.dart';  // ✅ AÑADIR IMPORT

class EquiposPendientesApiService {
  static const Uuid _uuid = Uuid();  // ✅ INSTANCIA UUID

  static Future<Map<String, dynamic>> enviarEquipoPendiente({
    required String equipoId,
    required int clienteId,
    required String edfVendedorId,
  }) async {
    try {
      BaseSyncService.logger.i('💡 Enviando equipo pendiente...');
      final payload = _construirPayload(equipoId, clienteId, edfVendedorId);
      BaseSyncService.logger.i('📦 Payload completo: $payload');
      print(jsonEncode(payload));

      // CAMBIO AQUÍ: Obtener la URL dinámica
      final baseUrl = await BaseSyncService.getBaseUrl();
      final response = await http.post(
        Uri.parse('$baseUrl/edfEquipoPendiente/insertEquipoPendiente'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(BaseSyncService.timeout);

      BaseSyncService.logger.i('📥 Respuesta HTTP: ${response.statusCode}');
      BaseSyncService.logger.i('📄 Body respuesta: ${response.body}');

      return _procesarRespuesta(response);
    } catch (e) {
      BaseSyncService.logger.e('❌ Error enviando: $e');
      return {'exito': false, 'mensaje': 'Error de conexión: $e'};
    }
  }

  static Map<String, dynamic> _construirPayload(
      String equipoId,
      int clienteId,
      String edfVendedorId,
      ) {
    return {
      'equipoId': equipoId,
      'clienteId': clienteId.toString(),
      'appId': _uuid.v4(),  // ✅ UUID en lugar de timestamp
      'vendedorSucursalId': edfVendedorId,
    };
  }

  static Map<String, dynamic> _procesarRespuesta(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return {
        'exito': false,
        'mensaje': 'Error del servidor: ${response.statusCode}'
      };
    }

    final body = response.body;
    if (body.contains('REGISTRADO')) {
      return {'exito': true, 'mensaje': 'Equipo pendiente registrado'};
    } else if (body.contains('ya fue registrado')) {
      return {'exito': true, 'mensaje': 'Equipo ya estaba registrado'};
    } else {
      return {'exito': false, 'mensaje': body};
    }
  }
}