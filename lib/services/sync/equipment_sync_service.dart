import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/services/database_helper.dart';
import 'package:ada_app/repositories/equipo_repository.dart';
import 'package:ada_app/repositories/equipo_pendiente_repository.dart';
import 'package:ada_app/models/equipos.dart';
import 'package:ada_app/services/error_log/error_log_service.dart';

class EquipmentSyncService extends BaseSyncService {
  static final _dbHelper = DatabaseHelper();
  static final _equipoRepo = EquipoRepository();

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
          tableName: 'marcas',
          operation: 'sync_from_server',
          errorMessage: 'HTTP ${response.statusCode}: $mensaje',
          errorType: 'server',
          errorCode: response.statusCode.toString(),
          endpoint: endpoint,
        );

        return SyncResult(
          exito: false,
          mensaje: mensaje,
          itemsSincronizados: 0,
        );
      }

      final responseData = jsonDecode(response.body);

      List<dynamic> marcasAPI = [];
      if (responseData is Map<String, dynamic>) {
        if (responseData.containsKey('data')) {
          if (responseData['data'] is String) {
            final String dataString = responseData['data'];
            marcasAPI = jsonDecode(dataString) as List<dynamic>;
          } else if (responseData['data'] is List) {
            marcasAPI = responseData['data'] as List<dynamic>;
          }
        }
      } else if (responseData is List) {
        marcasAPI = responseData;
      }

      final marcasValidas = marcasAPI.where((marca) {
        return marca != null &&
            marca['marca'] != null &&
            marca['marca'].toString().trim().isNotEmpty;
      }).toList();

      if (marcasValidas.isEmpty) {
        BaseSyncService.logger.w('No hay marcas válidas para sincronizar');
        return SyncResult(
          exito: true,
          mensaje: 'No se encontraron marcas válidas',
          itemsSincronizados: 0,
        );
      }

      // Envolver operación de base de datos en try-catch
      try {
        await _dbHelper.sincronizarMarcas(marcasValidas);
        BaseSyncService.logger.i('Marcas sincronizadas: ${marcasValidas.length} de ${marcasAPI.length}');
      } catch (dbError) {
        BaseSyncService.logger.e('Error insertando marcas en BD: $dbError');

        await ErrorLogService.logError(
          tableName: 'marcas',
          operation: 'database_insert',
          errorMessage: dbError.toString(),
          errorType: 'database',
        );

        return SyncResult(
          exito: false,
          mensaje: 'Error guardando marcas en base de datos',
          itemsSincronizados: 0,
        );
      }

      return SyncResult(
        exito: true,
        mensaje: 'Marcas sincronizadas correctamente',
        itemsSincronizados: marcasValidas.length,
        totalEnAPI: marcasAPI.length,
      );

    } catch (e) {
      BaseSyncService.logger.e('Error sincronizando marcas: $e');

      // Detectar tipo de error directamente
      String errorType;
      String mensaje;

      if (e is TimeoutException) {
        errorType = 'network';
        mensaje = 'Timeout de conexión';
      } else if (e is SocketException) {
        errorType = 'network';
        mensaje = 'Sin conexión de red';
      } else if (e is http.ClientException) {
        errorType = 'network';
        mensaje = 'Error de cliente HTTP';
      } else if (e is FormatException) {
        errorType = 'validation';
        mensaje = 'Error en formato de datos';
      } else {
        errorType = 'unknown';
        mensaje = BaseSyncService.getErrorMessage(e);
      }

      await ErrorLogService.logError(
        tableName: 'marcas',
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

  static Future<SyncResult> sincronizarModelos() async {
    final baseUrl = await BaseSyncService.getBaseUrl();
    final endpoint = '$baseUrl/api/getEdfModelos';

    try {
      final response = await http.get(
        Uri.parse(endpoint),
        headers: BaseSyncService.headers,
      ).timeout(BaseSyncService.timeout);

      if (response.statusCode != 200) {
        final mensaje = BaseSyncService.extractErrorMessage(response);

        await ErrorLogService.logError(
          tableName: 'modelos',
          operation: 'sync_from_server',
          errorMessage: 'HTTP ${response.statusCode}: $mensaje',
          errorType: 'server',
          errorCode: response.statusCode.toString(),
          endpoint: endpoint,
        );

        return SyncResult(
          exito: false,
          mensaje: mensaje,
          itemsSincronizados: 0,
        );
      }

      final responseData = jsonDecode(response.body);

      List<dynamic> modelosAPI = [];
      if (responseData is Map<String, dynamic>) {
        if (responseData.containsKey('data')) {
          if (responseData['data'] is String) {
            final String dataString = responseData['data'];
            modelosAPI = jsonDecode(dataString) as List<dynamic>;
          } else if (responseData['data'] is List) {
            modelosAPI = responseData['data'] as List<dynamic>;
          }
        }
      } else if (responseData is List) {
        modelosAPI = responseData;
      }

      final modelosValidos = modelosAPI.where((modelo) {
        return modelo != null &&
            modelo['modelo'] != null &&
            modelo['modelo'].toString().trim().isNotEmpty;
      }).map((modelo) {
        return {
          'id': modelo['id'],
          'nombre': modelo['modelo'],
        };
      }).toList();

      if (modelosValidos.isEmpty) {
        BaseSyncService.logger.w('No hay modelos válidos para sincronizar');
        return SyncResult(
          exito: true,
          mensaje: 'No se encontraron modelos válidos',
          itemsSincronizados: 0,
        );
      }

      // Envolver operación de base de datos en try-catch
      try {
        await _dbHelper.sincronizarModelos(modelosValidos);
        BaseSyncService.logger.i('Modelos sincronizados: ${modelosValidos.length} de ${modelosAPI.length}');
      } catch (dbError) {
        BaseSyncService.logger.e('Error insertando modelos en BD: $dbError');

        await ErrorLogService.logError(
          tableName: 'modelos',
          operation: 'database_insert',
          errorMessage: dbError.toString(),
          errorType: 'database',
        );

        return SyncResult(
          exito: false,
          mensaje: 'Error guardando modelos en base de datos',
          itemsSincronizados: 0,
        );
      }

      return SyncResult(
        exito: true,
        mensaje: 'Modelos sincronizados correctamente',
        itemsSincronizados: modelosValidos.length,
        totalEnAPI: modelosAPI.length,
      );

    } catch (e) {
      BaseSyncService.logger.e('Error sincronizando modelos: $e');

      String errorType;
      String mensaje;

      if (e is TimeoutException) {
        errorType = 'network';
        mensaje = 'Timeout de conexión';
      } else if (e is SocketException) {
        errorType = 'network';
        mensaje = 'Sin conexión de red';
      } else if (e is http.ClientException) {
        errorType = 'network';
        mensaje = 'Error de cliente HTTP';
      } else if (e is FormatException) {
        errorType = 'validation';
        mensaje = 'Error en formato de datos';
      } else {
        errorType = 'unknown';
        mensaje = BaseSyncService.getErrorMessage(e);
      }

      await ErrorLogService.logError(
        tableName: 'modelos',
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

  static Future<SyncResult> sincronizarLogos() async {
    final baseUrl = await BaseSyncService.getBaseUrl();
    final endpoint = '$baseUrl/api/getEdfLogos';

    try {
      final response = await http.get(
        Uri.parse(endpoint),
        headers: BaseSyncService.headers,
      ).timeout(BaseSyncService.timeout);

      if (response.statusCode != 200) {
        final mensaje = BaseSyncService.extractErrorMessage(response);

        await ErrorLogService.logError(
          tableName: 'logo',
          operation: 'sync_from_server',
          errorMessage: 'HTTP ${response.statusCode}: $mensaje',
          errorType: 'server',
          errorCode: response.statusCode.toString(),
          endpoint: endpoint,
        );

        return SyncResult(
          exito: false,
          mensaje: mensaje,
          itemsSincronizados: 0,
        );
      }

      final responseData = jsonDecode(response.body);

      List<dynamic> logosAPI = [];
      if (responseData is Map<String, dynamic>) {
        if (responseData.containsKey('data')) {
          if (responseData['data'] is String) {
            final String dataString = responseData['data'];
            logosAPI = jsonDecode(dataString) as List<dynamic>;
          } else if (responseData['data'] is List) {
            logosAPI = responseData['data'] as List<dynamic>;
          }
        }
      } else if (responseData is List) {
        logosAPI = responseData;
      }

      if (logosAPI.isEmpty) {
        BaseSyncService.logger.w('No se encontraron logos en la respuesta');
        return SyncResult(
          exito: true,
          mensaje: 'No se encontraron logos',
          itemsSincronizados: 0,
        );
      }

      // Envolver operación de base de datos en try-catch
      try {
        await _dbHelper.sincronizarLogos(logosAPI);
        BaseSyncService.logger.i('Logos sincronizados: ${logosAPI.length}');
      } catch (dbError) {
        BaseSyncService.logger.e('Error insertando logos en BD: $dbError');

        await ErrorLogService.logError(
          tableName: 'logo',
          operation: 'database_insert',
          errorMessage: dbError.toString(),
          errorType: 'database',
        );

        return SyncResult(
          exito: false,
          mensaje: 'Error guardando logos en base de datos',
          itemsSincronizados: 0,
        );
      }

      return SyncResult(
        exito: true,
        mensaje: 'Logos sincronizados correctamente',
        itemsSincronizados: logosAPI.length,
      );

    } catch (e) {
      BaseSyncService.logger.e('Error sincronizando logos: $e');

      String errorType;
      String mensaje;

      if (e is TimeoutException) {
        errorType = 'network';
        mensaje = 'Timeout de conexión';
      } else if (e is SocketException) {
        errorType = 'network';
        mensaje = 'Sin conexión de red';
      } else if (e is http.ClientException) {
        errorType = 'network';
        mensaje = 'Error de cliente HTTP';
      } else if (e is FormatException) {
        errorType = 'validation';
        mensaje = 'Error en formato de datos';
      } else {
        errorType = 'unknown';
        mensaje = BaseSyncService.getErrorMessage(e);
      }

      await ErrorLogService.logError(
        tableName: 'logo',
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

  static Future<SyncResult> sincronizarEquipos() async {
    final baseUrl = await BaseSyncService.getBaseUrl();
    final endpoint = '$baseUrl/api/getEdfEquipos';

    try {
      BaseSyncService.logger.i('🔄 Iniciando sincronización de equipos...');

      final response = await http.get(
        Uri.parse(endpoint),
        headers: BaseSyncService.headers,
      ).timeout(BaseSyncService.timeout);

      BaseSyncService.logger.i('📡 Respuesta equipos: ${response.statusCode}');

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final mensaje = BaseSyncService.extractErrorMessage(response);

        await ErrorLogService.logError(
          tableName: 'equipos',
          operation: 'sync_from_server',
          errorMessage: 'HTTP ${response.statusCode}: $mensaje',
          errorType: 'server',
          errorCode: response.statusCode.toString(),
          endpoint: endpoint,
        );

        return SyncResult(
          exito: false,
          mensaje: 'Error del servidor: $mensaje',
          itemsSincronizados: 0,
        );
      }

      final List<dynamic> equiposData = BaseSyncService.parseResponse(response.body);
      BaseSyncService.logger.i('📊 Equipos parseados: ${equiposData.length}');

      if (equiposData.isEmpty) {
        return SyncResult(
          exito: true,
          mensaje: 'No hay equipos en el servidor',
          itemsSincronizados: 0,
        );
      }

      if (equiposData.isNotEmpty) {
        BaseSyncService.logger.i('PRIMER EQUIPO DE LA API:');
        final primer = equiposData.first;
        BaseSyncService.logger.i('- id original: ${primer['id']}');
        BaseSyncService.logger.i('- equipoId (codigo barras): ${primer['equipoId']}');
        BaseSyncService.logger.i('- edfModeloId: ${primer['edfModeloId']}');
        BaseSyncService.logger.i('- edfLogoId: ${primer['edfLogoId']}');
        BaseSyncService.logger.i('- marcaId: ${primer['marcaId']}');
        BaseSyncService.logger.i('- numSerie: ${primer['numSerie']}');
        BaseSyncService.logger.i('- equipo (modelo): ${primer['equipo']}');
      }

      final equipos = <Equipo>[];
      int procesados = 0;
      int conCodigo = 0;

      for (var equipoJson in equiposData) {
        try {
          final equipo = Equipo.fromJson(equipoJson);
          equipos.add(equipo);
          procesados++;

          if (equipo.codBarras.isNotEmpty) {
            conCodigo++;
            if (conCodigo <= 3) {
              BaseSyncService.logger.i('✅ Código procesado: "${equipo.codBarras}"');
            }
          }
        } catch (e) {
          BaseSyncService.logger.w('Error procesando equipo: $e');
          BaseSyncService.logger.w('JSON problemático: ${jsonEncode(equipoJson)}');

          await ErrorLogService.logError(
            tableName: 'equipos',
            operation: 'process_item',
            errorMessage: e.toString(),
            errorType: 'validation',
            registroFailId: equipoJson['id']?.toString(),
          );
        }
      }

      BaseSyncService.logger.i('📈 RESUMEN PROCESAMIENTO:');
      BaseSyncService.logger.i('- Equipos procesados: $procesados de ${equiposData.length}');
      BaseSyncService.logger.i('- Con código de barras: $conCodigo');

      BaseSyncService.logger.i('💾 Guardando en base de datos...');

      // Envolver operación de base de datos en try-catch
      try {
        final equiposMapas = equipos.map((e) => e.toMap()).toList();
        await _equipoRepo.limpiarYSincronizar(equiposMapas);
        BaseSyncService.logger.i('✅ Equipos guardados exitosamente en BD');
      } catch (dbError) {
        BaseSyncService.logger.e('Error guardando equipos en BD: $dbError');

        await ErrorLogService.logError(
          tableName: 'equipos',
          operation: 'database_insert',
          errorMessage: dbError.toString(),
          errorType: 'database',
        );

        return SyncResult(
          exito: false,
          mensaje: 'Error guardando equipos en base de datos',
          itemsSincronizados: 0,
        );
      }

      return SyncResult(
        exito: true,
        mensaje: 'Equipos sincronizados: $procesados equipos, $conCodigo con código',
        itemsSincronizados: equipos.length,
        totalEnAPI: equiposData.length,
      );

    } catch (e) {
      BaseSyncService.logger.e('💥 Error en sincronización de equipos: $e');

      String errorType;
      String mensaje;

      if (e is TimeoutException) {
        errorType = 'network';
        mensaje = 'Timeout de conexión';
      } else if (e is SocketException) {
        errorType = 'network';
        mensaje = 'Sin conexión de red';
      } else if (e is http.ClientException) {
        errorType = 'network';
        mensaje = 'Error de cliente HTTP';
      } else if (e is FormatException) {
        errorType = 'validation';
        mensaje = 'Error en formato de datos';
      } else {
        errorType = 'unknown';
        mensaje = BaseSyncService.getErrorMessage(e);
      }

      await ErrorLogService.logError(
        tableName: 'equipos',
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
}