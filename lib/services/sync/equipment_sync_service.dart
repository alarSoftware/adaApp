import 'dart:convert';
import 'package:ada_app/services/network/monitored_http_client.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

import 'dart:isolate';

import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/services/data/database_helper.dart';
import 'package:ada_app/repositories/equipo_repository.dart';

import 'package:ada_app/services/error_log/error_log_service.dart';

class EquipmentSyncService extends BaseSyncService {
  static final _dbHelper = DatabaseHelper();
  static final _equipoRepo = EquipoRepository();

  static Future<SyncResult> sincronizarMarcas() async {
    final baseUrl = await BaseSyncService.getBaseUrl();
    final endpoint = '$baseUrl/api/getEdfMarcas';

    try {
      final response = await MonitoredHttpClient.get(
        url: Uri.parse(endpoint),
        headers: BaseSyncService.headers,
        timeout: BaseSyncService.timeout,
      );

      if (response.statusCode != 200) {
        final mensaje = BaseSyncService.extractErrorMessage(response);
        await ErrorLogService.logError(
          tableName: 'marcas',
          operation: 'sync_from_server',
          errorMessage: mensaje,
          errorType: 'server',
          endpoint: endpoint,
        );
        return SyncResult(
          exito: false,
          mensaje: mensaje,
          itemsSincronizados: 0,
        );
      }

      final responseData = jsonDecode(response.body);
      final List<dynamic> marcasAPI = _extraerListaDatos(responseData);

      final List<Map<String, dynamic>> marcasParaInsertar = [];

      for (var item in marcasAPI) {
        if (item != null &&
            item['marca'] != null &&
            item['marca'].toString().trim().isNotEmpty) {
          marcasParaInsertar.add({'id': item['id'], 'nombre': item['marca']});
        }
      }

      try {
        await _dbHelper.vaciarEInsertar('marcas', marcasParaInsertar);
      } catch (dbError) {
        return SyncResult(
          exito: false,
          mensaje: 'Error guardando marcas',
          itemsSincronizados: 0,
        );
      }

      return SyncResult(
        exito: true,
        mensaje: 'Marcas sincronizadas',
        itemsSincronizados: marcasParaInsertar.length,
        totalEnAPI: marcasAPI.length,
      );
    } catch (e) {
      await ErrorLogService.manejarExcepcion(e, null, endpoint, null, 'marcas');
      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

  static Future<SyncResult> sincronizarModelos() async {
    final baseUrl = await BaseSyncService.getBaseUrl();
    final endpoint = '$baseUrl/api/getEdfModelos';

    try {
      final response = await MonitoredHttpClient.get(
        url: Uri.parse(endpoint),
        headers: BaseSyncService.headers,
        timeout: BaseSyncService.timeout,
      );

      if (response.statusCode != 200) {
        return SyncResult(
          exito: false,
          mensaje: 'Error ${response.statusCode}',
          itemsSincronizados: 0,
        );
      }

      final responseData = jsonDecode(response.body);
      final List<dynamic> modelosAPI = _extraerListaDatos(responseData);

      final List<Map<String, dynamic>> modelosParaInsertar = [];

      for (var item in modelosAPI) {
        if (item != null &&
            item['modelo'] != null &&
            item['modelo'].toString().trim().isNotEmpty) {
          modelosParaInsertar.add({'id': item['id'], 'nombre': item['modelo']});
        }
      }

      try {
        await _dbHelper.vaciarEInsertar('modelos', modelosParaInsertar);
      } catch (dbError) {
        return SyncResult(
          exito: false,
          mensaje: 'Error BD Modelos',
          itemsSincronizados: 0,
        );
      }

      return SyncResult(
        exito: true,
        mensaje: 'Modelos sincronizados',
        itemsSincronizados: modelosParaInsertar.length,
      );
    } catch (e) {
      await ErrorLogService.manejarExcepcion(
        e,
        null,
        endpoint,
        null,
        'modelos',
      );
      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

  static Future<SyncResult> sincronizarLogos() async {
    final baseUrl = await BaseSyncService.getBaseUrl();
    final endpoint = '$baseUrl/api/getEdfLogos';

    try {
      final response = await MonitoredHttpClient.get(
        url: Uri.parse(endpoint),
        headers: BaseSyncService.headers,
        timeout: BaseSyncService.timeout,
      );

      if (response.statusCode != 200) {
        return SyncResult(
          exito: false,
          mensaje: 'Error ${response.statusCode}',
          itemsSincronizados: 0,
        );
      }

      final responseData = jsonDecode(response.body);
      final List<dynamic> logosAPI = _extraerListaDatos(responseData);

      final List<Map<String, dynamic>> logosParaInsertar = [];

      for (var item in logosAPI) {
        var nombreLogo = item['logo'] ?? item['nombre'];
        if (nombreLogo != null) {
          logosParaInsertar.add({'id': item['id'], 'nombre': nombreLogo});
        }
      }

      try {
        await _dbHelper.vaciarEInsertar('logo', logosParaInsertar);
      } catch (dbError) {
        return SyncResult(
          exito: false,
          mensaje: 'Error BD Logos',
          itemsSincronizados: 0,
        );
      }

      return SyncResult(
        exito: true,
        mensaje: 'Logos sincronizados',
        itemsSincronizados: logosParaInsertar.length,
      );
    } catch (e) {
      await ErrorLogService.manejarExcepcion(e, null, endpoint, null, 'logo');
      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

  static Future<SyncResult> sincronizarEquipos() async {
    final baseUrl = await BaseSyncService.getBaseUrl();
    final endpoint = '$baseUrl/api/getEdfEquipos';

    try {
      debugPrint('INICIO DESCARGA: ${DateTime.now()}');
      final stopwatchDownload = Stopwatch()..start();

      final response = await MonitoredHttpClient.get(
        url: Uri.parse(endpoint),
        headers: BaseSyncService.headers,
        timeout: const Duration(minutes: 5),
      );

      stopwatchDownload.stop();
      debugPrint(
        'FIN DESCARGA: ${DateTime.now()} - Duracion: ${stopwatchDownload.elapsedMilliseconds} ms',
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final mensaje = BaseSyncService.extractErrorMessage(response);
        await ErrorLogService.logError(
          tableName: 'equipos',
          operation: 'sync_from_server',
          errorMessage: 'HTTP ${response.statusCode}: $mensaje',
          errorType: 'server',
          endpoint: endpoint,
        );
        return SyncResult(
          exito: false,
          mensaje: 'Error del servidor: $mensaje',
          itemsSincronizados: 0,
        );
      }

      final equiposMapas = await _procesarEquiposEnIsolate(response.body);

      if (equiposMapas.isEmpty) {
        try {
          await _equipoRepo.limpiarYSincronizar([]);
        } catch (dbError) {
          await ErrorLogService.logError(
            tableName: 'equipos',
            operation: 'database_clear',
            errorMessage: dbError.toString(),
            errorType: 'database',
          );
          return SyncResult(
            exito: false,
            mensaje: 'Error limpiando BD',
            itemsSincronizados: 0,
          );
        }

        return SyncResult(
          exito: true,
          mensaje: 'Tabla limpiada (Sin equipos en servidor)',
          itemsSincronizados: 0,
          totalEnAPI: 0,
        );
      }

      try {
        debugPrint(
          'INICIO INSERCION BD: ${DateTime.now()} (Total: ${equiposMapas.length} items)',
        );
        final stopwatch = Stopwatch()..start();

        await _equipoRepo.limpiarYSincronizarEnChunks(equiposMapas);

        stopwatch.stop();
        debugPrint(
          'FIN INSERCION BD: ${DateTime.now()} - Duracion: ${stopwatch.elapsedMilliseconds} ms',
        );
      } catch (dbError) {
        await ErrorLogService.logError(
          tableName: 'equipos',
          operation: 'database_insert',
          errorMessage: dbError.toString(),
          errorType: 'database',
        );
        return SyncResult(
          exito: false,
          mensaje: 'Error guardando en BD',
          itemsSincronizados: 0,
        );
      }

      return SyncResult(
        exito: true,
        mensaje: 'Equipos sincronizados: ${equiposMapas.length}',
        itemsSincronizados: equiposMapas.length,
        totalEnAPI: equiposMapas.length,
      );
    } catch (e) {
      await ErrorLogService.manejarExcepcion(
        e,
        null,
        endpoint,
        null,
        'equipos',
      );
      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

  static Future<List<Map<String, dynamic>>> _procesarEquiposEnIsolate(
    String responseBody,
  ) async {
    return await Isolate.run(() => _procesarEquiposJSON(responseBody));
  }

  static List<Map<String, dynamic>> _procesarEquiposJSON(String responseBody) {
    final List<dynamic> equiposData = BaseSyncService.parseResponse(
      responseBody,
    );
    final List<Map<String, dynamic>> equiposMapas = [];
    final ahora = DateTime.now().toIso8601String();

    for (var equipoJson in equiposData) {
      if (equipoJson is Map<String, dynamic>) {
        try {
          equiposMapas.add(_mapearEquipo(equipoJson, ahora));
        } catch (e) {
          // Skip invalid item
        }
      }
    }

    return equiposMapas;
  }

  static Map<String, dynamic> _mapearEquipo(
    Map<String, dynamic> equipoJson,
    String fechaDefault,
  ) {
    return {
      'id': equipoJson['id']?.toString() ?? '',
      'cliente_id': equipoJson['clienteId']?.toString(),
      'cod_barras': equipoJson['equipoId']?.toString() ?? '',
      'marca_id': int.tryParse(equipoJson['marcaId']?.toString() ?? '1') ?? 1,
      'modelo_id':
          int.tryParse(equipoJson['edfModeloId']?.toString() ?? '1') ?? 1,
      'numero_serie': equipoJson['numSerie']?.toString(),
      'logo_id': int.tryParse(equipoJson['edfLogoId']?.toString() ?? '1') ?? 1,
      'app_insert': _esAppInsert(equipoJson),
      'sincronizado': 1,
      'fecha_creacion':
          equipoJson['fecha_creacion']?.toString() ??
          equipoJson['fechaCreacion']?.toString() ??
          equipoJson['fecha']?.toString() ??
          fechaDefault,
      'fecha_actualizacion':
          equipoJson['fecha_actualizacion']?.toString() ??
          equipoJson['fechaActualizacion']?.toString(),
    };
  }

  static int _esAppInsert(Map<String, dynamic> json) {
    final appInsert = json['appInsert'] ?? json['app_insert'];
    return (appInsert == true || appInsert == 1) ? 1 : 0;
  }

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
}
