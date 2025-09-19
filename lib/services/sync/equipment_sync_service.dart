import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/services/database_helper.dart';
import 'package:ada_app/repositories/equipo_repository.dart';
import 'package:ada_app/repositories/equipo_cliente_repository.dart';
import 'package:ada_app/models/equipos.dart';

class EquipmentSyncService extends BaseSyncService {
  static final _dbHelper = DatabaseHelper();
  static final _equipoRepo = EquipoRepository();
  static final _equipoClienteRepo = EquipoClienteRepository();

  static Future<SyncResult> sincronizarMarcas() async {
    try {
      final response = await http.get(
        Uri.parse('${BaseSyncService.baseUrl}/getEdfMarcas'),
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

        // CORRECCIÓN: El filtro ahora busca 'marca' que es como viene de la API
        final marcasValidas = marcasAPI.where((marca) {
          return marca != null &&
              marca['marca'] != null &&  // Cambiado de 'nombre' a 'marca'
              marca['marca'].toString().trim().isNotEmpty;
        }).toList();

        if (marcasValidas.isNotEmpty) {
          await _dbHelper.sincronizarMarcas(marcasValidas);
          BaseSyncService.logger.i('Marcas sincronizadas: ${marcasValidas.length} de ${marcasAPI.length}');

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
        return SyncResult(
          exito: false,
          mensaje: mensaje,
          itemsSincronizados: 0,
        );
      }
    } catch (e) {
      BaseSyncService.logger.e('Error sincronizando marcas: $e');
      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

  static Future<SyncResult> sincronizarModelos() async {
    try {
      final response = await http.get(
        Uri.parse('${BaseSyncService.baseUrl}/getEdfModelos'),
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
          await _dbHelper.sincronizarModelos(modelosValidos);
          BaseSyncService.logger.i('Modelos sincronizados: ${modelosValidos.length} de ${modelosAPI.length}');

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
        return SyncResult(
          exito: false,
          mensaje: mensaje,
          itemsSincronizados: 0,
        );
      }
    } catch (e) {
      BaseSyncService.logger.e('Error sincronizando modelos: $e');
      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

  static Future<SyncResult> sincronizarLogos() async {
    try {
      final response = await http.get(
        Uri.parse('${BaseSyncService.baseUrl}/getEdfLogos'),
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
          await _dbHelper.sincronizarLogos(logosAPI);
          BaseSyncService.logger.i('Logos sincronizados: ${logosAPI.length}');

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
        return SyncResult(
          exito: false,
          mensaje: mensaje,
          itemsSincronizados: 0,
        );
      }
    } catch (e) {
      BaseSyncService.logger.e('Error sincronizando logos: $e');
      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

  static Future<SyncResult> sincronizarEquipos() async {
    try {
      BaseSyncService.logger.i('🔄 Iniciando sincronización de equipos...');
      final response = await http.get(
        Uri.parse('${BaseSyncService.baseUrl}/getEdfEquipos'),
        headers: BaseSyncService.headers,
      ).timeout(BaseSyncService.timeout);

      BaseSyncService.logger.i('📡 Respuesta equipos: ${response.statusCode}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Usar el parseResponse corregido
        final List<dynamic> equiposData = BaseSyncService.parseResponse(response.body);
        BaseSyncService.logger.i('📊 Equipos parseados: ${equiposData.length}');

        if (equiposData.isEmpty) {
          return SyncResult(
            exito: true,
            mensaje: 'No hay equipos en el servidor',
            itemsSincronizados: 0,
          );
        }

        // Debug: Mostrar el primer equipo procesado
        if (equiposData.isNotEmpty) {
          BaseSyncService.logger.i('PRIMER EQUIPO DE LA API:');
          final primer = equiposData.first;
          BaseSyncService.logger.i('- id original: ${primer['id']}');
          BaseSyncService.logger.i('- equipoId (codigo barras): ${primer['equipoId']}');
          BaseSyncService.logger.i('- edfModeloId: ${primer['edfModeloId']}');
          BaseSyncService.logger.i('- edfLogoId: ${primer['edfLogoId']}');
          BaseSyncService.logger.i('- marcaId: ${primer['marcaId']}');
          BaseSyncService.logger.i('- numSerie: ${primer['numSerie']}');
          BaseSyncService.logger.i('- esActivo: ${primer['esActivo']}');
          BaseSyncService.logger.i('- esDisponible: ${primer['esDisponible']}');
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
              // Log de los primeros 3 códigos para verificar
              if (conCodigo <= 3) {
                BaseSyncService.logger.i('✅ Código procesado: "${equipo.codBarras}"');
              }
            }
          } catch (e) {
            BaseSyncService.logger.w('Error procesando equipo: $e');
            BaseSyncService.logger.w('JSON problemático: ${jsonEncode(equipoJson)}');
          }
        }

        BaseSyncService.logger.i('📈 RESUMEN PROCESAMIENTO:');
        BaseSyncService.logger.i('- Equipos procesados: $procesados de ${equiposData.length}');
        BaseSyncService.logger.i('- Con código de barras: $conCodigo');

        BaseSyncService.logger.i('💾 Guardando en base de datos...');
        final equiposMapas = equipos.map((e) => e.toMap()).toList();
        await _equipoRepo.limpiarYSincronizar(equiposMapas);

        return SyncResult(
          exito: true,
          mensaje: 'Equipos sincronizados: $procesados equipos, $conCodigo con código',
          itemsSincronizados: equipos.length,
          totalEnAPI: equiposData.length,
        );
      } else {
        final mensaje = BaseSyncService.extractErrorMessage(response);
        return SyncResult(
          exito: false,
          mensaje: 'Error del servidor: $mensaje',
          itemsSincronizados: 0,
        );
      }
    } catch (e) {
      BaseSyncService.logger.e('💥 Error en sincronización de equipos: $e');
      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

  static Future<SyncResult> sincronizarAsignaciones() async {
    try {
      final response = await http.get(
        Uri.parse('${BaseSyncService.baseUrl}/asignaciones'),
        headers: BaseSyncService.headers,
      ).timeout(BaseSyncService.timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<dynamic> asignacionesData = BaseSyncService.parseResponse(response.body);

        if (asignacionesData.isEmpty) {
          return SyncResult(
            exito: true,
            mensaje: 'No hay asignaciones en el servidor',
            itemsSincronizados: 0,
          );
        }

        final asignacionesLimpias = asignacionesData.map((asignacion) {
          return {
            'id': asignacion['id'],
            'equipo_id': asignacion['equipo_id'],
            'cliente_id': asignacion['cliente_id'],
            'estado': asignacion['estado'] ?? 'asignado',
            'fecha_asignacion': asignacion['fecha_asignacion'],
            'fecha_retiro': asignacion['fecha_retiro'],
            'activo': asignacion['activo'] ?? 1,
          };
        }).toList();

        await _equipoClienteRepo.limpiarYSincronizar(asignacionesLimpias);

        return SyncResult(
          exito: true,
          mensaje: 'Asignaciones sincronizadas correctamente',
          itemsSincronizados: asignacionesLimpias.length,
          totalEnAPI: asignacionesLimpias.length,
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
            Uri.parse('${BaseSyncService.baseUrl}/estados'),
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
          }
        } catch (e) {
          BaseSyncService.logger.w('Error subiendo registro ${registro['id']}: $e');
        }
      }

      return exitosos;
    } catch (e) {
      BaseSyncService.logger.e('Error en subida de registros: $e');
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
      rethrow;
    }
  }
}