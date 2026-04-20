import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/repositories/equipo_extraviado_repository.dart';
import 'package:ada_app/services/error_log/error_log_service.dart';

class EquiposExtraviadosSyncService extends BaseSyncService {
  static final _repo = EquipoExtraviadoRepository();

  static Future<SyncResult> obtenerEquiposExtraviados({
    String? employeeId,
  }) async {
    String? currentEndpoint;

    try {
      final Map<String, String> queryParams = {};
      if (employeeId != null) {
        queryParams['employeeId'] = employeeId;
      }

      final baseUrl = await BaseSyncService.getBaseUrl();
      final uri = Uri.parse(
        '$baseUrl/api/getEdfEquipoExtraviado',
      ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      currentEndpoint = uri.toString();

      final response = await http
          .get(uri, headers: BaseSyncService.headers)
          .timeout(BaseSyncService.timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        List<dynamic> equiposData = [];

        try {
          final responseBody = jsonDecode(response.body);
          if (responseBody is Map<String, dynamic> &&
              responseBody.containsKey('data')) {
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
          return SyncResult(
            exito: false,
            mensaje: 'Error parseando respuesta de equipos extraviados',
            itemsSincronizados: 0,
          );
        }

        try {
          final List<Map<String, dynamic>> listaMapeada = [];
          for (var item in equiposData) {
            if (item is Map<String, dynamic>) {
              listaMapeada.add(item);
            }
          }

          await _repo.guardarEquiposExtraviadosDesdeServidor(listaMapeada);
        } catch (dbError) {
          await ErrorLogService.logDatabaseError(
            tableName: 'equipos_extraviados',
            operation: 'insert_from_server',
            errorMessage: 'Error guardando equipos extraviados: $dbError',
          );
        }

        return SyncResult(
          exito: true,
          mensaje: 'Equipos extraviados obtenidos correctamente',
          itemsSincronizados: equiposData.length,
        );
      } else {
        final mensaje = BaseSyncService.extractErrorMessage(response);
        return SyncResult(
          exito: false,
          mensaje: mensaje,
          itemsSincronizados: 0,
        );
      }
    } catch (e) {
      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }
}
