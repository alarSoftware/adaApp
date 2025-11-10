import 'dart:convert';
import 'dart:async'; // Para TimeoutException
import 'dart:io'; // Para SocketException
import 'package:http/http.dart' as http;
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/repositories/equipo_pendiente_repository.dart';
import 'package:ada_app/services/error_log/error_log_service.dart'; // 🆕 NUEVO IMPORT

class EquiposPendientesSyncService extends BaseSyncService {

  /// Obtener equipos pendientes desde el servidor
  static Future<SyncResult> obtenerEquiposPendientes({
    String? edfVendedorId,
  }) async {
    String? currentEndpoint; // 🆕 Para capturar endpoint en errores

    try {
      BaseSyncService.logger.i('Obteniendo equipos pendientes desde el servidor...');

      final Map<String, String> queryParams = {};
      if (edfVendedorId != null) {
        queryParams['edfvendedorId'] = edfVendedorId;
      }

      final baseUrl = await BaseSyncService.getBaseUrl();
      final uri = Uri.parse('$baseUrl/api/getEquipoPendiente')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      currentEndpoint = uri.toString(); // 🆕 Guardar endpoint para logs
      BaseSyncService.logger.i('📡 Llamando a: $currentEndpoint');

      final response = await http.get(
        uri,
        headers: BaseSyncService.headers,
      ).timeout(BaseSyncService.timeout);

      BaseSyncService.logger.i('📥 Respuesta: ${response.statusCode}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        List<dynamic> equiposData = [];

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
          BaseSyncService.logger.e('Error parseando respuesta: $parseError');

          // 🚨 LOG ERROR: Error de parsing
          await ErrorLogService.logError(
            tableName: 'equipos_pendientes',
            operation: 'sync_from_server',
            errorMessage: 'Error parseando respuesta del servidor: $parseError',
            errorType: 'server',
            errorCode: 'PARSE_ERROR',
            endpoint: currentEndpoint,
            userId: edfVendedorId,
          );

          return SyncResult(
            exito: false,
            mensaje: 'Error parseando respuesta del servidor',
            itemsSincronizados: 0,
          );
        }

        BaseSyncService.logger.i('✅ Equipos pendientes parseados: ${equiposData.length}');

        try {
          BaseSyncService.logger.i('🔍 Datos que se van a guardar: ${equiposData.length} equipos');

          if (equiposData.isNotEmpty) {
            BaseSyncService.logger.i('🔍 Primer equipo ejemplo: ${equiposData.first}');
          }

          final repo = EquipoPendienteRepository();
          final equiposComoMap = equiposData.map((e) => e as Map<String, dynamic>).toList();

          // 🆕 Forzar sincronizado = 1 para datos del servidor
          final equiposConSync = equiposComoMap.map((equipo) {
            final equipoMap = Map<String, dynamic>.from(equipo);
            equipoMap['sincronizado'] = 1; // ✅ SIEMPRE 1 para datos del servidor
            equipoMap['fecha_sincronizacion'] = DateTime.now().toIso8601String();
            return equipoMap;
          }).toList();

          final guardados = await repo.guardarEquiposPendientesDesdeServidor(equiposConSync);
          BaseSyncService.logger.i('💾 Equipos pendientes guardados con sincronizado=1: $guardados');

        } catch (dbError) {
          BaseSyncService.logger.e('❌ Error guardando en BD: $dbError');

          // 🚨 LOG ERROR: Error de base de datos local
          await ErrorLogService.logDatabaseError(
            tableName: 'equipos_pendientes',
            operation: 'insert_from_server',
            errorMessage: 'Error guardando equipos en base de datos local: $dbError',
          );

          // No retornar error porque los datos se descargaron correctamente del servidor
        }

        return SyncResult(
          exito: true,
          mensaje: 'Equipos pendientes obtenidos correctamente',
          itemsSincronizados: equiposData.length,
        );

      } else {
        final mensaje = BaseSyncService.extractErrorMessage(response);
        BaseSyncService.logger.e('❌ Error del servidor: $mensaje');

        // 🚨 LOG ERROR: Error del servidor
        await ErrorLogService.logServerError(
          tableName: 'equipos_pendientes',
          operation: 'sync_from_server',
          errorMessage: mensaje,
          errorCode: response.statusCode.toString(),
          endpoint: currentEndpoint,
          userId: edfVendedorId,
        );

        return SyncResult(
          exito: false,
          mensaje: 'Error del servidor: $mensaje',
          itemsSincronizados: 0,
        );
      }

    } on TimeoutException catch (timeoutError) {
      BaseSyncService.logger.e('⏰ Timeout obteniendo equipos pendientes: $timeoutError');

      // 🚨 LOG ERROR: Timeout
      await ErrorLogService.logNetworkError(
        tableName: 'equipos_pendientes',
        operation: 'sync_from_server',
        errorMessage: 'Timeout de conexión: $timeoutError',
        endpoint: currentEndpoint,
        userId: edfVendedorId,
      );

      return SyncResult(
        exito: false,
        mensaje: 'Timeout de conexión al servidor',
        itemsSincronizados: 0,
      );

    } on SocketException catch (socketError) {
      BaseSyncService.logger.e('📡 Error de red: $socketError');

      // 🚨 LOG ERROR: Sin conexión de red
      await ErrorLogService.logNetworkError(
        tableName: 'equipos_pendientes',
        operation: 'sync_from_server',
        errorMessage: 'Sin conexión de red: $socketError',
        endpoint: currentEndpoint,
        userId: edfVendedorId,
      );

      return SyncResult(
        exito: false,
        mensaje: 'Sin conexión de red',
        itemsSincronizados: 0,
      );

    } catch (e) {
      BaseSyncService.logger.e('💥 Error obteniendo equipos pendientes: $e');

      // 🚨 LOG ERROR: Error general
      await ErrorLogService.logError(
        tableName: 'equipos_pendientes',
        operation: 'sync_from_server',
        errorMessage: 'Error general: $e',
        errorType: 'unknown',
        errorCode: 'GENERAL_ERROR',
        endpoint: currentEndpoint,
        userId: edfVendedorId,
      );

      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }
}