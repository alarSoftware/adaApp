import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/repositories/equipo_pendiente_repository.dart';

class EquiposPendientesSyncService extends BaseSyncService {

  /// Obtener equipos pendientes desde el servidor
  static Future<SyncResult> obtenerEquiposPendientes({
    String? edfVendedorId,
  }) async {
    try {
      BaseSyncService.logger.i('Obteniendo equipos pendientes desde el servidor...');

      final Map<String, String> queryParams = {};
      if (edfVendedorId != null) {
        queryParams['edfvendedorId'] = edfVendedorId;
      }

      final uri = Uri.parse('${BaseSyncService.baseUrl}/api/getEquipoPendiente')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      BaseSyncService.logger.i('📡 Llamando a: ${uri.toString()}');

      final response = await http.get(
        uri,
        headers: BaseSyncService.headers,
      ).timeout(BaseSyncService.timeout);

      BaseSyncService.logger.i('📥 Respuesta: ${response.statusCode}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        List<dynamic> equiposData = [];

        try {
          final responseBody = jsonDecode(response.body);

          // CORRECCIÓN: Manejar el formato específico de este endpoint
          if (responseBody is Map<String, dynamic> && responseBody.containsKey('data')) {
            final dataValue = responseBody['data'];

            // El 'data' viene como STRING, no como array directo
            if (dataValue is String) {
              equiposData = jsonDecode(dataValue) as List;
            } else if (dataValue is List) {
              equiposData = dataValue;
            }
          } else if (responseBody is List) {
            equiposData = responseBody;
          } else {
            equiposData = [responseBody];
          }
        } catch (e) {
          BaseSyncService.logger.e('Error parseando respuesta: $e');
          return SyncResult(
            exito: false,
            mensaje: 'Error parseando respuesta del servidor',
            itemsSincronizados: 0,
          );
        }

        BaseSyncService.logger.i('✅ Equipos pendientes parseados: ${equiposData.length}');

        // Guardar en base de datos local
        if (equiposData.isNotEmpty) {
          try {
            final repo = EquipoPendienteRepository();
            final equiposComoMap = equiposData.map((e) => e as Map<String, dynamic>).toList();
            final guardados = await repo.guardarEquiposPendientesDesdeServidor(equiposComoMap);
            BaseSyncService.logger.i('💾 Equipos pendientes guardados: $guardados');
          } catch (e) {
            BaseSyncService.logger.e('❌ Error guardando en BD: $e');
          }
        } else {
          BaseSyncService.logger.w('⚠️ No se encontraron equipos pendientes');
        }

        return SyncResult(
          exito: true,
          mensaje: 'Equipos pendientes obtenidos correctamente',
          itemsSincronizados: equiposData.length,
        );
      } else {
        final mensaje = BaseSyncService.extractErrorMessage(response);
        BaseSyncService.logger.e('❌ Error del servidor: $mensaje');
        return SyncResult(
          exito: false,
          mensaje: 'Error del servidor: $mensaje',
          itemsSincronizados: 0,
        );
      }
    } catch (e) {
      BaseSyncService.logger.e('💥 Error obteniendo equipos pendientes: $e');
      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }
}