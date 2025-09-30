import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/repositories/censo_activo_repository.dart';

class CensusSyncService extends BaseSyncService {

  // Obtener todos los censos activos
  static Future<SyncResult> obtenerCensosActivos({
    int? clienteId,
    int? equipoId,
    String? fechaDesde,
    String? fechaHasta,
    String? estado,
    bool? enLocal,
    int? limit,
    int? offset,
    String? edfVendedorId,
  }) async {
    try {
      BaseSyncService.logger.i('Obteniendo censos activos desde el servidor...');

      final Map<String, String> queryParams = {};

      if (edfVendedorId != null) {
        queryParams['edfvendedorId'] = edfVendedorId;
      }

      if (clienteId != null) queryParams['clienteId'] = clienteId.toString();
      if (equipoId != null) queryParams['equipoId'] = equipoId.toString();
      if (fechaDesde != null) queryParams['fechaDesde'] = fechaDesde;
      if (fechaHasta != null) queryParams['fechaHasta'] = fechaHasta;
      if (estado != null) queryParams['estado'] = estado;
      if (enLocal != null) queryParams['enLocal'] = enLocal.toString();
      if (limit != null) queryParams['limit'] = limit.toString();
      if (offset != null) queryParams['offset'] = offset.toString();

      final uri = Uri.parse('${BaseSyncService.baseUrl}/getCensoActivo')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      BaseSyncService.logger.i('📡 Llamando a: ${uri.toString()}');

      final response = await http.get(
        uri,
        headers: BaseSyncService.headers,
      ).timeout(BaseSyncService.timeout);

      BaseSyncService.logger.i('📥 Respuesta getCensoActivo: ${response.statusCode}');
      BaseSyncService.logger.i('📄 Body respuesta: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        List<dynamic> censosData = [];

        try {
          final responseBody = jsonDecode(response.body);

          if (responseBody is List) {
            censosData = responseBody;
          } else if (responseBody.containsKey('data')) {
            final dataValue = responseBody['data'];

            if (dataValue is String) {
              censosData = jsonDecode(dataValue) as List;
            } else if (dataValue is List) {
              censosData = dataValue;
            } else {
              censosData = [];
            }
          } else {
            censosData = [responseBody];
          }
        } catch (e) {
          BaseSyncService.logger.e('Error parseando respuesta: $e');
          return SyncResult(
            exito: false,
            mensaje: 'Error parseando respuesta del servidor',
            itemsSincronizados: 0,
          );
        }

        BaseSyncService.logger.i('✅ Censos parseados: ${censosData.length}');

        // GUARDAR EN BASE DE DATOS LOCAL
        if (censosData.isNotEmpty) {
          try {
            final repo = EstadoEquipoRepository();
            final censosComoMap = censosData.map((e) => e as Map<String, dynamic>).toList();
            final guardados = await repo.guardarCensosDesdeServidor(censosComoMap);
            BaseSyncService.logger.i('💾 Censos guardados en BD local: $guardados');
          } catch (e) {
            BaseSyncService.logger.e('❌ Error guardando en BD local: $e');
          }

          BaseSyncService.logger.i('PRIMER CENSO DE LA API:');
          final primer = censosData.first;
          BaseSyncService.logger.i('- id: ${primer['id']}');
          BaseSyncService.logger.i('- cliente_id: ${primer['cliente_id'] ?? primer['clienteId']}');
          BaseSyncService.logger.i('- equipo_id: ${primer['equipo_id'] ?? primer['equipoId']}');
        } else {
          BaseSyncService.logger.w('⚠️ No se encontraron censos en la respuesta');
        }

        return SyncResult(
          exito: true,
          mensaje: 'Censos obtenidos correctamente',
          itemsSincronizados: censosData.length,
          totalEnAPI: censosData.length,
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
      BaseSyncService.logger.e('💥 Error obteniendo censos activos: $e');
      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

  // Obtener censo específico por ID
  static Future<SyncResult> obtenerCensoPorId(int censoId) async {
    try {
      BaseSyncService.logger.i('Obteniendo censo ID: $censoId');

      final response = await http.get(
        Uri.parse('${BaseSyncService.baseUrl}/getCensoActivo/$censoId'),
        headers: BaseSyncService.headers,
      ).timeout(BaseSyncService.timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = jsonDecode(response.body);

        Map<String, dynamic> censoData;
        if (responseData is Map<String, dynamic>) {
          if (responseData.containsKey('data')) {
            censoData = responseData['data'];
          } else {
            censoData = responseData;
          }
        } else {
          throw 'Formato de respuesta inesperado';
        }

        BaseSyncService.logger.i('Censo obtenido: ID ${censoData['id']}');

        return SyncResult(
          exito: true,
          mensaje: 'Censo obtenido correctamente',
          itemsSincronizados: 1,
        );
      } else {
        final mensaje = BaseSyncService.extractErrorMessage(response);
        return SyncResult(
          exito: false,
          mensaje: 'Censo no encontrado: $mensaje',
          itemsSincronizados: 0,
        );
      }
    } catch (e) {
      BaseSyncService.logger.e('Error obteniendo censo por ID: $e');
      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

  // Buscar censos por código de barras
  static Future<SyncResult> buscarPorCodigoBarras(String codigoBarras) async {
    try {
      BaseSyncService.logger.i('Buscando censos por código: $codigoBarras');

      final response = await http.get(
        Uri.parse('${BaseSyncService.baseUrl}/getCensoActivo')
            .replace(queryParameters: {'codigoBarras': codigoBarras}),
        headers: BaseSyncService.headers,
      ).timeout(BaseSyncService.timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<dynamic> censosData = BaseSyncService.parseResponse(response.body);

        BaseSyncService.logger.i('Búsqueda completada: ${censosData.length} resultados');

        return SyncResult(
          exito: true,
          mensaje: 'Búsqueda completada: ${censosData.length} resultados',
          itemsSincronizados: censosData.length,
        );
      } else {
        final mensaje = BaseSyncService.extractErrorMessage(response);
        return SyncResult(
          exito: false,
          mensaje: 'Error en búsqueda: $mensaje',
          itemsSincronizados: 0,
        );
      }
    } catch (e) {
      BaseSyncService.logger.e('Error buscando por código: $e');
      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

  // Métodos más simples
  static Future<SyncResult> obtenerCensosDeCliente(int clienteId) {
    return obtenerCensosActivos(clienteId: clienteId);
  }

  static Future<SyncResult> obtenerHistoricoEquipo(int equipoId) {
    return obtenerCensosActivos(equipoId: equipoId);
  }

  static Future<SyncResult> obtenerCensosPendientes() {
    return obtenerCensosActivos(enLocal: true);
  }
}