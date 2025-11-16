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
  static final _equipoClienteRepo = EquipoPendienteRepository();

  static Future<SyncResult> sincronizarMarcas() async {
    String? currentEndpoint;

    try {
      final baseUrl = await BaseSyncService.getBaseUrl();
      currentEndpoint = '$baseUrl/api/getEdfMarcas';

      final response = await http.get(
        Uri.parse(currentEndpoint),
        headers: BaseSyncService.headers,
      ).timeout(BaseSyncService.timeout);

      if (response.statusCode == 200) {
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

        if (marcasValidas.isNotEmpty) {
          try {
            await _dbHelper.sincronizarMarcas(marcasValidas);
            BaseSyncService.logger.i('Marcas sincronizadas: ${marcasValidas.length} de ${marcasAPI.length}');
          } catch (dbError) {
            BaseSyncService.logger.e('Error guardando marcas en BD: $dbError');

            // 🚨 LOG ERROR: Error de BD local
            await ErrorLogService.logDatabaseError(
              tableName: 'marcas',
              operation: 'bulk_insert',
              errorMessage: 'Error guardando marcas: $dbError',
            );
          }

          return SyncResult(
            exito: true,
            mensaje: 'Marcas sincronizadas correctamente',
            itemsSincronizados: marcasValidas.length,
            totalEnAPI: marcasAPI.length,
          );
        } else {
          BaseSyncService.logger.w('No hay marcas válidas para sincronizar');
          return SyncResult(
            exito: true,
            mensaje: 'No se encontraron marcas válidas',
            itemsSincronizados: 0,
          );
        }
      } else {
        final mensaje = BaseSyncService.extractErrorMessage(response);

        // 🚨 LOG ERROR: Error del servidor
        await ErrorLogService.logServerError(
          tableName: 'marcas',
          operation: 'sync_from_server',
          errorMessage: mensaje,
          errorCode: response.statusCode.toString(),
          endpoint: currentEndpoint,
        );

        return SyncResult(
          exito: false,
          mensaje: mensaje,
          itemsSincronizados: 0,
        );
      }

    } on TimeoutException catch (timeoutError) {
      await ErrorLogService.logNetworkError(
        tableName: 'marcas',
        operation: 'sync_from_server',
        errorMessage: 'Timeout: $timeoutError',
        endpoint: currentEndpoint,
      );

      return SyncResult(
        exito: false,
        mensaje: 'Timeout de conexión',
        itemsSincronizados: 0,
      );

    } on SocketException catch (socketError) {
      await ErrorLogService.logNetworkError(
        tableName: 'marcas',
        operation: 'sync_from_server',
        errorMessage: 'Sin conexión: $socketError',
        endpoint: currentEndpoint,
      );

      return SyncResult(
        exito: false,
        mensaje: 'Sin conexión de red',
        itemsSincronizados: 0,
      );

    } catch (e) {
      BaseSyncService.logger.e('Error sincronizando marcas: $e');

      await ErrorLogService.logError(
        tableName: 'marcas',
        operation: 'sync_from_server',
        errorMessage: 'Error: $e',
        errorType: 'unknown',
        endpoint: currentEndpoint,
      );

      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

  static Future<SyncResult> sincronizarModelos() async {
    String? currentEndpoint;

    try {
      final baseUrl = await BaseSyncService.getBaseUrl();
      currentEndpoint = '$baseUrl/api/getEdfModelos';

      final response = await http.get(
        Uri.parse(currentEndpoint),
        headers: BaseSyncService.headers,
      ).timeout(BaseSyncService.timeout);

      if (response.statusCode == 200) {
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

        if (modelosValidos.isNotEmpty) {
          try {
            await _dbHelper.sincronizarModelos(modelosValidos);
            BaseSyncService.logger.i('Modelos sincronizados: ${modelosValidos.length} de ${modelosAPI.length}');
          } catch (dbError) {
            BaseSyncService.logger.e('Error guardando modelos en BD: $dbError');

            // 🚨 LOG ERROR: Error de BD local
            await ErrorLogService.logDatabaseError(
              tableName: 'modelos',
              operation: 'bulk_insert',
              errorMessage: 'Error guardando modelos: $dbError',
            );
          }

          return SyncResult(
            exito: true,
            mensaje: 'Modelos sincronizados correctamente',
            itemsSincronizados: modelosValidos.length,
            totalEnAPI: modelosAPI.length,
          );
        } else {
          BaseSyncService.logger.w('No hay modelos válidos para sincronizar');
          return SyncResult(
            exito: true,
            mensaje: 'No se encontraron modelos válidos',
            itemsSincronizados: 0,
          );
        }
      } else {
        final mensaje = BaseSyncService.extractErrorMessage(response);

        // 🚨 LOG ERROR: Error del servidor
        await ErrorLogService.logServerError(
          tableName: 'modelos',
          operation: 'sync_from_server',
          errorMessage: mensaje,
          errorCode: response.statusCode.toString(),
          endpoint: currentEndpoint,
        );

        return SyncResult(
          exito: false,
          mensaje: mensaje,
          itemsSincronizados: 0,
        );
      }

    } on TimeoutException catch (timeoutError) {
      await ErrorLogService.logNetworkError(
        tableName: 'modelos',
        operation: 'sync_from_server',
        errorMessage: 'Timeout: $timeoutError',
        endpoint: currentEndpoint,
      );

      return SyncResult(
        exito: false,
        mensaje: 'Timeout de conexión',
        itemsSincronizados: 0,
      );

    } on SocketException catch (socketError) {
      await ErrorLogService.logNetworkError(
        tableName: 'modelos',
        operation: 'sync_from_server',
        errorMessage: 'Sin conexión: $socketError',
        endpoint: currentEndpoint,
      );

      return SyncResult(
        exito: false,
        mensaje: 'Sin conexión de red',
        itemsSincronizados: 0,
      );

    } catch (e) {
      BaseSyncService.logger.e('Error sincronizando modelos: $e');

      await ErrorLogService.logError(
        tableName: 'modelos',
        operation: 'sync_from_server',
        errorMessage: 'Error: $e',
        errorType: 'unknown',
        endpoint: currentEndpoint,
      );

      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

  static Future<SyncResult> sincronizarLogos() async {
    String? currentEndpoint;

    try {
      final baseUrl = await BaseSyncService.getBaseUrl();
      currentEndpoint = '$baseUrl/api/getEdfLogos';

      final response = await http.get(
        Uri.parse(currentEndpoint),
        headers: BaseSyncService.headers,
      ).timeout(BaseSyncService.timeout);

      if (response.statusCode == 200) {
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

        if (logosAPI.isNotEmpty) {
          try {
            await _dbHelper.sincronizarLogos(logosAPI);
            BaseSyncService.logger.i('Logos sincronizados: ${logosAPI.length}');
          } catch (dbError) {
            BaseSyncService.logger.e('Error guardando logos en BD: $dbError');

            // 🚨 LOG ERROR: Error de BD local
            await ErrorLogService.logDatabaseError(
              tableName: 'logo',
              operation: 'bulk_insert',
              errorMessage: 'Error guardando logos: $dbError',
            );
          }

          return SyncResult(
            exito: true,
            mensaje: 'Logos sincronizados correctamente',
            itemsSincronizados: logosAPI.length,
          );
        } else {
          BaseSyncService.logger.w('No se encontraron logos en la respuesta');
          return SyncResult(
            exito: true,
            mensaje: 'No se encontraron logos',
            itemsSincronizados: 0,
          );
        }
      } else {
        final mensaje = BaseSyncService.extractErrorMessage(response);

        // 🚨 LOG ERROR: Error del servidor
        await ErrorLogService.logServerError(
          tableName: 'logo',
          operation: 'sync_from_server',
          errorMessage: mensaje,
          errorCode: response.statusCode.toString(),
          endpoint: currentEndpoint,
        );

        return SyncResult(
          exito: false,
          mensaje: mensaje,
          itemsSincronizados: 0,
        );
      }

    } on TimeoutException catch (timeoutError) {
      await ErrorLogService.logNetworkError(
        tableName: 'logo',
        operation: 'sync_from_server',
        errorMessage: 'Timeout: $timeoutError',
        endpoint: currentEndpoint,
      );

      return SyncResult(
        exito: false,
        mensaje: 'Timeout de conexión',
        itemsSincronizados: 0,
      );

    } on SocketException catch (socketError) {
      await ErrorLogService.logNetworkError(
        tableName: 'logo',
        operation: 'sync_from_server',
        errorMessage: 'Sin conexión: $socketError',
        endpoint: currentEndpoint,
      );

      return SyncResult(
        exito: false,
        mensaje: 'Sin conexión de red',
        itemsSincronizados: 0,
      );

    } catch (e) {
      BaseSyncService.logger.e('Error sincronizando logos: $e');

      await ErrorLogService.logError(
        tableName: 'logo',
        operation: 'sync_from_server',
        errorMessage: 'Error: $e',
        errorType: 'unknown',
        endpoint: currentEndpoint,
      );

      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

  static Future<SyncResult> sincronizarEquipos() async {
    String? currentEndpoint;

    try {
      BaseSyncService.logger.i('🔄 Iniciando sincronización de equipos...');

      final baseUrl = await BaseSyncService.getBaseUrl();
      currentEndpoint = '$baseUrl/api/getEdfEquipos';

      final response = await http.get(
        Uri.parse(currentEndpoint),
        headers: BaseSyncService.headers,
      ).timeout(BaseSyncService.timeout);

      BaseSyncService.logger.i('📡 Respuesta equipos: ${response.statusCode}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
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

            // 🚨 LOG ERROR: Error procesando equipo individual
            await ErrorLogService.logError(
              tableName: 'equipos',
              operation: 'process_item',
              errorMessage: 'Error procesando equipo: $e',
              errorType: 'validation',
              registroFailId: equipoJson['id']?.toString(),
            );
          }
        }

        BaseSyncService.logger.i('📈 RESUMEN PROCESAMIENTO:');
        BaseSyncService.logger.i('- Equipos procesados: $procesados de ${equiposData.length}');
        BaseSyncService.logger.i('- Con código de barras: $conCodigo');

        BaseSyncService.logger.i('💾 Guardando en base de datos...');

        try {
          final equiposMapas = equipos.map((e) => e.toMap()).toList();
          await _equipoRepo.limpiarYSincronizar(equiposMapas);
        } catch (dbError) {
          BaseSyncService.logger.e('Error guardando equipos en BD: $dbError');

          // 🚨 LOG ERROR: Error de BD local
          await ErrorLogService.logDatabaseError(
            tableName: 'equipos',
            operation: 'bulk_insert',
            errorMessage: 'Error guardando equipos: $dbError',
          );
        }

        return SyncResult(
          exito: true,
          mensaje: 'Equipos sincronizados: $procesados equipos, $conCodigo con código',
          itemsSincronizados: equipos.length,
          totalEnAPI: equiposData.length,
        );
      } else {
        final mensaje = BaseSyncService.extractErrorMessage(response);

        // 🚨 LOG ERROR: Error del servidor
        await ErrorLogService.logServerError(
          tableName: 'equipos',
          operation: 'sync_from_server',
          errorMessage: mensaje,
          errorCode: response.statusCode.toString(),
          endpoint: currentEndpoint,
        );

        return SyncResult(
          exito: false,
          mensaje: 'Error del servidor: $mensaje',
          itemsSincronizados: 0,
        );
      }

    } on TimeoutException catch (timeoutError) {
      await ErrorLogService.logNetworkError(
        tableName: 'equipos',
        operation: 'sync_from_server',
        errorMessage: 'Timeout: $timeoutError',
        endpoint: currentEndpoint,
      );

      return SyncResult(
        exito: false,
        mensaje: 'Timeout de conexión',
        itemsSincronizados: 0,
      );

    } on SocketException catch (socketError) {
      await ErrorLogService.logNetworkError(
        tableName: 'equipos',
        operation: 'sync_from_server',
        errorMessage: 'Sin conexión: $socketError',
        endpoint: currentEndpoint,
      );

      return SyncResult(
        exito: false,
        mensaje: 'Sin conexión de red',
        itemsSincronizados: 0,
      );

    } catch (e) {
      BaseSyncService.logger.e('💥 Error en sincronización de equipos: $e');

      await ErrorLogService.logError(
        tableName: 'equipos',
        operation: 'sync_from_server',
        errorMessage: 'Error: $e',
        errorType: 'unknown',
        endpoint: currentEndpoint,
      );

      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

  static Future<int> subirRegistrosEquipos() async {
    try {
      final registrosPendientes = await _dbHelper.consultar(
        'registros_equipos',
        where: 'estado_sincronizacion = ?',
        whereArgs: ['pendiente'],
        orderBy: 'fecha_registro ASC',
        limit: 50,
      );

      if (registrosPendientes.isEmpty) return 0;

      int exitosos = 0;
      final baseUrl = await BaseSyncService.getBaseUrl();

      for (final registro in registrosPendientes) {
        try {
          final estadoData = {
            'equipo_id': registro['equipo_id'],
            'cliente_id': registro['cliente_id'],
            'usuario_id': 1,
            'funcionando': registro['funcionando'] ?? 1,
            'estado_general': registro['estado_general'] ?? 'Revisión móvil',
            'temperatura_actual': registro['temperatura_actual'],
            'temperatura_freezer': registro['temperatura_freezer'],
            'latitud': registro['latitud'],
            'longitud': registro['longitud'],
          };

          final response = await http.post(
            Uri.parse('$baseUrl/estados'),
            headers: BaseSyncService.headers,
            body: jsonEncode(estadoData),
          ).timeout(const Duration(seconds: 15));

          if (response.statusCode == 201) {
            await _dbHelper.actualizar(
              'registros_equipos',
              {
                'estado_sincronizacion': 'sincronizado',
                'fecha_actualizacion': DateTime.now().toIso8601String(),
              },
              where: 'id = ?',
              whereArgs: [registro['id']],
            );
            exitosos++;
          } else {
            await _dbHelper.actualizar(
              'registros_equipos',
              {
                'estado_sincronizacion': 'error',
                'fecha_actualizacion': DateTime.now().toIso8601String(),
              },
              where: 'id = ?',
              whereArgs: [registro['id']],
            );

            // 🚨 LOG ERROR: Error subiendo registro
            await ErrorLogService.logServerError(
              tableName: 'registros_equipos',
              operation: 'upload',
              errorMessage: 'Error subiendo registro',
              errorCode: response.statusCode.toString(),
              registroFailId: registro['id']?.toString(),
            );
          }
        } catch (e) {
          BaseSyncService.logger.w('Error subiendo registro ${registro['id']}: $e');

          // 🚨 LOG ERROR
          await ErrorLogService.logError(
            tableName: 'registros_equipos',
            operation: 'upload',
            errorMessage: 'Error: $e',
            errorType: 'network',
            registroFailId: registro['id']?.toString(),
          );
        }
      }

      return exitosos;
    } catch (e) {
      BaseSyncService.logger.e('Error en subida de registros: $e');

      await ErrorLogService.logError(
        tableName: 'registros_equipos',
        operation: 'upload_batch',
        errorMessage: 'Error: $e',
        errorType: 'unknown',
      );

      return 0;
    }
  }

  static Future<int> crearRegistroEquipo({
    required int clienteId,
    String? clienteNombre,
    String? clienteDireccion,
    String? clienteTelefono,
    int? equipoId,
    String? codigoBarras,
    String? modelo,
    int? marcaId,
    String? numeroSerie,
    int? logoId,
    String? observaciones,
    double? latitud,
    double? longitud,
    bool funcionando = true,
    String? estadoGeneral,
    double? temperaturaActual,
    double? temperaturaFreezer,
    String? versionApp,
    String? dispositivo,
  }) async {
    try {
      final now = DateTime.now();
      final idLocal = now.millisecondsSinceEpoch;

      final registroData = {
        'id_local': idLocal,
        'servidor_id': null,
        'estado_sincronizacion': 'pendiente',
        'cliente_id': clienteId,
        'cliente_nombre': clienteNombre,
        'cliente_direccion': clienteDireccion,
        'cliente_telefono': clienteTelefono,
        'equipo_id': equipoId,
        'codigo_barras': codigoBarras,
        'modelo': modelo,
        'marca_id': marcaId,
        'numero_serie': numeroSerie,
        'logo_id': logoId,
        'observaciones': observaciones,
        'latitud': latitud,
        'longitud': longitud,
        'fecha_registro': now.toIso8601String(),
        'timestamp_gps': now.toIso8601String(),
        'funcionando': funcionando ? 1 : 0,
        'estado_general': estadoGeneral ?? 'Revisión desde móvil',
        'temperatura_actual': temperaturaActual,
        'temperatura_freezer': temperaturaFreezer,
        'version_app': versionApp,
        'dispositivo': dispositivo,
        'fecha_creacion': now.toIso8601String(),
        'fecha_actualizacion': now.toIso8601String(),
      };

      final id = await _dbHelper.insertar('registros_equipos', registroData);
      BaseSyncService.logger.i('Registro de equipo creado con ID local: $idLocal');

      return id;
    } catch (e) {
      BaseSyncService.logger.e('Error creando registro de equipo: $e');

      await ErrorLogService.logDatabaseError(
        tableName: 'registros_equipos',
        operation: 'create',
        errorMessage: 'Error: $e',
      );

      rethrow;
    }
  }
}