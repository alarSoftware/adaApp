import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/repositories/equipo_pendiente_repository.dart';
import 'package:ada_app/services/error_log/error_log_service.dart';

class EquiposPendientesSyncService extends BaseSyncService {

  // ✅ 1. Instancia del repositorio (El traductor)
  static final _repo = EquipoPendienteRepository();

  static Future<SyncResult> obtenerEquiposPendientes({
    String? edfVendedorId,
  }) async {
    String? currentEndpoint;

    try {
      BaseSyncService.logger.i('🔄 Obteniendo equipos pendientes desde el servidor...');

      final Map<String, String> queryParams = {};
      if (edfVendedorId != null) {
        queryParams['edfvendedorId'] = edfVendedorId;
      }

      final baseUrl = await BaseSyncService.getBaseUrl();
      final uri = Uri.parse('$baseUrl/api/getEquipoPendiente')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      currentEndpoint = uri.toString();

      final response = await http.get(
        uri,
        headers: BaseSyncService.headers,
      ).timeout(BaseSyncService.timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        List<dynamic> equiposData = [];

        // --- PARSEO DE RESPUESTA ---
        try {
          final responseBody = jsonDecode(response.body);
          if (responseBody is Map<String, dynamic> && responseBody.containsKey('data')) {
            final dataValue = responseBody['data'];
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
        } catch (parseError) {
          // ... Manejo de error de parseo ...
          return SyncResult(exito: false, mensaje: 'Error parseando respuesta', itemsSincronizados: 0);
        }

        // --- GUARDADO EN BD ---
        try {
          BaseSyncService.logger.i('🔍 Datos recibidos: ${equiposData.length} registros');

          // 1. Limpiamos la lista para asegurarnos que son mapas
          final List<Map<String, dynamic>> listaMapeada = [];
          for (var item in equiposData) {
            if (item is Map<String, dynamic>) {
              listaMapeada.add(item);
            }
          }

          // ✅ 2. LA SOLUCIÓN: Usamos el método del repo para mapear y guardar
          // Esto evita el error de "Column Mismatch"
          final guardados = await _repo.guardarEquiposPendientesDesdeServidor(listaMapeada);

          BaseSyncService.logger.i('✅ Equipos pendientes guardados correctamente: $guardados');

        } catch (dbError) {
          BaseSyncService.logger.e('❌ Error guardando en BD: $dbError');
          await ErrorLogService.logDatabaseError(
            tableName: 'equipos_pendientes',
            operation: 'insert_from_server',
            errorMessage: 'Error guardando: $dbError',
          );
          // No lanzamos error fatal porque la descarga funcionó, solo falló el guardado local
        }

        return SyncResult(
          exito: true,
          mensaje: 'Equipos pendientes obtenidos correctamente',
          itemsSincronizados: equiposData.length,
        );

      } else {
        // --- MANEJO DE ERROR HTTP ---
        final mensaje = BaseSyncService.extractErrorMessage(response);
        await ErrorLogService.logServerError(
          tableName: 'equipos_pendientes',
          operation: 'sync_from_server',
          errorMessage: mensaje,
          errorCode: response.statusCode.toString(),
          endpoint: currentEndpoint,
          userId: edfVendedorId,
        );
        return SyncResult(exito: false, mensaje: mensaje, itemsSincronizados: 0);
      }

    } catch (e) {
      // --- MANEJO DE EXCEPCIONES GENERALES ---
      BaseSyncService.logger.e('💥 Error general: $e');
      return SyncResult(exito: false, mensaje: BaseSyncService.getErrorMessage(e), itemsSincronizados: 0);
    }
  }
}