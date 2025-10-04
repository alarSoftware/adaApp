import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ada_app/services/sync/base_sync_service.dart';

class EquiposPendientesApiService {

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
      final response = await http.post(
        Uri.parse('${BaseSyncService.baseUrl}/edfEquipoPendiente/insertEquipoPendiente'),
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
      'appId': DateTime.now().millisecondsSinceEpoch.toString(),
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