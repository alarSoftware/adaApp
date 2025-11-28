import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/services/database_helper.dart';
import 'package:ada_app/repositories/equipo_repository.dart';
import 'package:ada_app/models/equipos.dart';
import 'package:ada_app/services/error_log/error_log_service.dart';

class EquipmentSyncService extends BaseSyncService {
  static final _dbHelper = DatabaseHelper();
  static final _equipoRepo = EquipoRepository();

  // ===============================================================
  // 1. SINCRONIZAR MARCAS (Con vaciado total previo)
  // ===============================================================
  static Future<SyncResult> sincronizarMarcas() async {
    final baseUrl = await BaseSyncService.getBaseUrl();
    final endpoint = '$baseUrl/api/getEdfMarcas';

    try {
      final response = await http.get(
        Uri.parse(endpoint),
        headers: BaseSyncService.headers,
      ).timeout(BaseSyncService.timeout);

      if (response.statusCode != 200) {
        final mensaje = BaseSyncService.extractErrorMessage(response);
        await ErrorLogService.logError(
            tableName: 'marcas', operation: 'sync_from_server', errorMessage: mensaje, errorType: 'server', endpoint: endpoint
        );
        return SyncResult(exito: false, mensaje: mensaje, itemsSincronizados: 0);
      }

      final responseData = jsonDecode(response.body);
      final List<dynamic> marcasAPI = _extraerListaDatos(responseData);

      // Preparamos la lista limpia para insertar
      final List<Map<String, dynamic>> marcasParaInsertar = [];

      for (var item in marcasAPI) {
        if (item != null && item['marca'] != null && item['marca'].toString().trim().isNotEmpty) {
          marcasParaInsertar.add({
            'id': item['id'],
            'nombre': item['marca'],
          });
        }
      }

      // NOTA: Quitamos el "return" si está vacío para permitir que limpie la tabla

      try {
        // Esto vacía la tabla y luego inserta (o deja vacío si la lista es vacía)
        await _dbHelper.vaciarEInsertar('marcas', marcasParaInsertar);
        BaseSyncService.logger.i('Marcas renovadas: ${marcasParaInsertar.length}');
      } catch (dbError) {
        BaseSyncService.logger.e('Error DB Marcas: $dbError');
        return SyncResult(exito: false, mensaje: 'Error guardando marcas', itemsSincronizados: 0);
      }

      return SyncResult(
        exito: true,
        mensaje: 'Marcas sincronizadas',
        itemsSincronizados: marcasParaInsertar.length,
        totalEnAPI: marcasAPI.length,
      );

    } catch (e) {
      return _manejarExcepcion(e, 'marcas', endpoint);
    }
  }

  // ===============================================================
  // 2. SINCRONIZAR MODELOS (Con vaciado total previo)
  // ===============================================================
  static Future<SyncResult> sincronizarModelos() async {
    final baseUrl = await BaseSyncService.getBaseUrl();
    final endpoint = '$baseUrl/api/getEdfModelos';

    try {
      final response = await http.get(Uri.parse(endpoint), headers: BaseSyncService.headers).timeout(BaseSyncService.timeout);

      if (response.statusCode != 200) {
        return SyncResult(exito: false, mensaje: 'Error ${response.statusCode}', itemsSincronizados: 0);
      }

      final responseData = jsonDecode(response.body);
      final List<dynamic> modelosAPI = _extraerListaDatos(responseData);

      final List<Map<String, dynamic>> modelosParaInsertar = [];

      for (var item in modelosAPI) {
        if (item != null && item['modelo'] != null && item['modelo'].toString().trim().isNotEmpty) {
          modelosParaInsertar.add({
            'id': item['id'],
            'nombre': item['modelo'],
            // Si tu tabla modelos tiene marca_id, agrégalo aquí
          });
        }
      }

      try {
        await _dbHelper.vaciarEInsertar('modelos', modelosParaInsertar);
        BaseSyncService.logger.i('Modelos renovados: ${modelosParaInsertar.length}');
      } catch (dbError) {
        return SyncResult(exito: false, mensaje: 'Error BD Modelos', itemsSincronizados: 0);
      }

      return SyncResult(exito: true, mensaje: 'Modelos sincronizados', itemsSincronizados: modelosParaInsertar.length);

    } catch (e) {
      return _manejarExcepcion(e, 'modelos', endpoint);
    }
  }

  // ===============================================================
  // 3. SINCRONIZAR LOGOS (Con vaciado total previo)
  // ===============================================================
  static Future<SyncResult> sincronizarLogos() async {
    final baseUrl = await BaseSyncService.getBaseUrl();
    final endpoint = '$baseUrl/api/getEdfLogos';

    try {
      final response = await http.get(Uri.parse(endpoint), headers: BaseSyncService.headers).timeout(BaseSyncService.timeout);

      if (response.statusCode != 200) {
        return SyncResult(exito: false, mensaje: 'Error ${response.statusCode}', itemsSincronizados: 0);
      }

      final responseData = jsonDecode(response.body);
      final List<dynamic> logosAPI = _extraerListaDatos(responseData);

      final List<Map<String, dynamic>> logosParaInsertar = [];

      for (var item in logosAPI) {
        var nombreLogo = item['logo'] ?? item['nombre'];
        if (nombreLogo != null) {
          logosParaInsertar.add({
            'id': item['id'],
            'nombre': nombreLogo,
          });
        }
      }

      try {
        await _dbHelper.vaciarEInsertar('logo', logosParaInsertar);
        BaseSyncService.logger.i('Logos renovados: ${logosParaInsertar.length}');
      } catch (dbError) {
        return SyncResult(exito: false, mensaje: 'Error BD Logos', itemsSincronizados: 0);
      }

      return SyncResult(exito: true, mensaje: 'Logos sincronizados', itemsSincronizados: logosParaInsertar.length);

    } catch (e) {
      return _manejarExcepcion(e, 'logo', endpoint);
    }
  }

  // ===============================================================
  // 4. SINCRONIZAR EQUIPOS (CORREGIDO: PROCESA AUNQUE ESTÉ VACÍO)
  // ===============================================================
  static Future<SyncResult> sincronizarEquipos() async {
    final baseUrl = await BaseSyncService.getBaseUrl();
    final endpoint = '$baseUrl/api/getEdfEquipos';

    try {
      BaseSyncService.logger.i('🔄 Iniciando sincronización de equipos...');

      final response = await http.get(
        Uri.parse(endpoint),
        headers: BaseSyncService.headers,
      ).timeout(BaseSyncService.timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final mensaje = BaseSyncService.extractErrorMessage(response);
        await ErrorLogService.logError(
            tableName: 'equipos', operation: 'sync_from_server', errorMessage: 'HTTP ${response.statusCode}: $mensaje', errorType: 'server', endpoint: endpoint
        );
        return SyncResult(exito: false, mensaje: 'Error del servidor: $mensaje', itemsSincronizados: 0);
      }

      final List<dynamic> equiposData = BaseSyncService.parseResponse(response.body);

      // 🔥 CORRECCIÓN PRINCIPAL:
      // Hemos eliminado el bloque "if (equiposData.isEmpty) return..."
      // Ahora el flujo continúa para limpiar la tabla aunque no vengan datos.

      final equipos = <Equipo>[];
      int procesados = 0;

      for (var equipoJson in equiposData) {
        try {
          final equipo = Equipo.fromJson(equipoJson);
          equipos.add(equipo);
          procesados++;
        } catch (e) {
          BaseSyncService.logger.w('Error procesando equipo ID ${equipoJson['id']}: $e');
        }
      }

      BaseSyncService.logger.i('💾 Guardando ${equipos.length} equipos en BD local...');

      try {
        final equiposMapas = equipos.map((e) => e.toMap()).toList();

        // Llamamos al método que hace DELETE FROM equipos e INSERT
        // Si equiposMapas está vacío, la tabla quedará vacía.
        await _equipoRepo.limpiarYSincronizar(equiposMapas);

        BaseSyncService.logger.i('✅ Tabla equipos actualizada correctamente');
      } catch (dbError) {
        BaseSyncService.logger.e('Error guardando equipos en BD: $dbError');
        await ErrorLogService.logError(
            tableName: 'equipos', operation: 'database_insert', errorMessage: dbError.toString(), errorType: 'database'
        );
        return SyncResult(exito: false, mensaje: 'Error guardando en BD', itemsSincronizados: 0);
      }

      return SyncResult(
        exito: true,
        mensaje: equiposData.isEmpty
            ? 'Tabla limpiada (Sin equipos en servidor)'
            : 'Equipos sincronizados: $procesados',
        itemsSincronizados: equipos.length,
        totalEnAPI: equiposData.length,
      );

    } catch (e) {
      return _manejarExcepcion(e, 'equipos', endpoint);
    }
  }

  // ===============================================================
  // MÉTODOS AUXILIARES
  // ===============================================================

  static List<dynamic> _extraerListaDatos(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      if (responseData.containsKey('data')) {
        if (responseData['data'] is String) {
          return jsonDecode(responseData['data']);
        } else if (responseData['data'] is List) {
          return responseData['data'];
        }
      }
    } else if (responseData is List) {
      return responseData;
    }
    return [];
  }

  static Future<SyncResult> _manejarExcepcion(dynamic e, String tabla, String endpoint) async {
    BaseSyncService.logger.e('Error sincronizando $tabla: $e');

    String errorType = 'unknown';
    String mensaje = BaseSyncService.getErrorMessage(e);

    if (e is TimeoutException) { errorType = 'network'; mensaje = 'Timeout'; }
    else if (e is SocketException) { errorType = 'network'; mensaje = 'Sin conexión'; }

    await ErrorLogService.logError(
      tableName: tabla,
      operation: 'sync_from_server',
      errorMessage: e.toString(),
      errorType: errorType,
      endpoint: endpoint,
    );

    return SyncResult(
      exito: false,
      mensaje: mensaje,
      itemsSincronizados: 0,
    );
  }
}