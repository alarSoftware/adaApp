import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/services/database_helper.dart';

/// Servicio de sincronización de censos activos - ADAPTADO AL FORMATO REAL DEL API
/// Formato del API: {"data": "[{...}]", "status": "OK"}
class CensusSyncService extends BaseSyncService {

  // Variable estática para almacenar los últimos censos obtenidos
  static List<dynamic> _ultimosCensos = [];
  static Map<String, dynamic>? _ultimoCenso;

  // Getters para acceder a los datos
  static List<dynamic> get ultimosCensosObtenidos => List.from(_ultimosCensos);
  static Map<String, dynamic>? get ultimoCensoObtenido => _ultimoCenso;

  /// Método principal para obtener censos activos
  static Future<SyncResult> obtenerCensosActivos({
    int? clienteId,
    int? equipoId,
    String? fechaDesde,
    String? fechaHasta,
    String? estado,
    bool? enLocal,
    int? limit,
    int? offset,
    String? edfVendedorId, // Parámetro opcional para compatibilidad
  }) async {
    try {
      BaseSyncService.logger.i('📊 Obteniendo censos activos desde el servidor...');

      // Construir parámetros de consulta
      final queryParams = _buildQueryParams(
        clienteId: clienteId,
        equipoId: equipoId,
        fechaDesde: fechaDesde,
        fechaHasta: fechaHasta,
        estado: estado,
        enLocal: enLocal,
        limit: limit,
        offset: offset,
        edfVendedorId: edfVendedorId,
      );

      // Realizar petición HTTP
      final response = await _makeHttpRequest(queryParams);

      if (!_isSuccessStatusCode(response.statusCode)) {
        return _handleErrorResponse(response);
      }

      // 🔥 PARSING ADAPTADO AL FORMATO REAL DEL API
      final censosData = await _parseCensusResponse(response);

      // Procesar y guardar censos en la tabla censo_activo
      final processedResult = await _processAndSaveCensus(censosData);

      // Guardar los datos para acceso posterior
      _ultimosCensos = processedResult;

      return SyncResult(
        exito: true,
        mensaje: 'Censos obtenidos correctamente',
        itemsSincronizados: processedResult.length,
        totalEnAPI: processedResult.length,
      );

    } catch (e) {
      BaseSyncService.logger.e('💥 Error obteniendo censos activos: $e');
      _ultimosCensos = [];
      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

  /// Obtener censo específico por ID
  static Future<SyncResult> obtenerCensoPorId(int censoId) async {
    try {
      BaseSyncService.logger.i('🔍 Obteniendo censo por ID: $censoId');

      final baseUrl = await BaseSyncService.getBaseUrl();
      final uri = Uri.parse('$baseUrl/api/getCensoActivo/$censoId');

      BaseSyncService.logger.i('📡 Llamando a: ${uri.toString()}');

      final response = await http.get(
        uri,
        headers: BaseSyncService.headers,
      ).timeout(BaseSyncService.timeout);

      if (!_isSuccessStatusCode(response.statusCode)) {
        return _handleErrorResponse(response);
      }

      // Parsear respuesta (puede ser un objeto único o en el formato estándar)
      final responseBody = jsonDecode(response.body);

      Map<String, dynamic>? censoData;

      if (responseBody is Map) {
        final responseMap = Map<String, dynamic>.from(responseBody);

        if (responseMap.containsKey('data') && responseMap['status'] == 'OK') {
          // Formato estándar con data
          final dataValue = responseMap['data'];
          if (dataValue is String) {
            final parsed = jsonDecode(dataValue);
            if (parsed is List && parsed.isNotEmpty) {
              censoData = Map<String, dynamic>.from(parsed.first);
            } else if (parsed is Map) {
              censoData = Map<String, dynamic>.from(parsed);
            }
          } else if (dataValue is Map) {
            censoData = Map<String, dynamic>.from(dataValue);
          }
        } else {
          // Objeto directo
          censoData = responseMap;
        }
      }

      _ultimoCenso = censoData;

      if (censoData != null) {
        // Guardar en base de datos
        await _saveCensusToDatabase(_mapApiToLocalFormat(censoData));

        return SyncResult(
          exito: true,
          mensaje: 'Censo obtenido correctamente',
          itemsSincronizados: 1,
        );
      } else {
        return SyncResult(
          exito: false,
          mensaje: 'Censo no encontrado',
          itemsSincronizados: 0,
        );
      }

    } catch (e) {
      BaseSyncService.logger.e('💥 Error obteniendo censo por ID: $e');
      _ultimoCenso = null;
      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

  /// Buscar censos por código de barras
  static Future<SyncResult> buscarPorCodigoBarras(String codigoBarras) async {
    try {
      BaseSyncService.logger.i('🔍 Buscando censos por código: $codigoBarras');

      final baseUrl = await BaseSyncService.getBaseUrl();
      final uri = Uri.parse('$baseUrl/api/getCensoActivo')
          .replace(queryParameters: {'codigoBarras': codigoBarras});

      BaseSyncService.logger.i('📡 Llamando a: ${uri.toString()}');

      final response = await http.get(
        uri,
        headers: BaseSyncService.headers,
      ).timeout(BaseSyncService.timeout);

      if (_isSuccessStatusCode(response.statusCode)) {
        final censosData = await _parseCensusResponse(response);
        _ultimosCensos = censosData;

        BaseSyncService.logger.i('Búsqueda completada: ${censosData.length} resultados');

        return SyncResult(
          exito: true,
          mensaje: 'Búsqueda completada: ${censosData.length} resultados',
          itemsSincronizados: censosData.length,
        );
      } else {
        _ultimosCensos = [];
        final mensaje = BaseSyncService.extractErrorMessage(response);
        return SyncResult(
          exito: false,
          mensaje: 'Error en búsqueda: $mensaje',
          itemsSincronizados: 0,
        );
      }
    } catch (e) {
      _ultimosCensos = [];
      BaseSyncService.logger.e('Error buscando por código: $e');
      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

  // Métodos de conveniencia
  static Future<SyncResult> obtenerCensosDeCliente(int clienteId) {
    return obtenerCensosActivos(clienteId: clienteId);
  }

  static Future<SyncResult> obtenerHistoricoEquipo(int equipoId) {
    return obtenerCensosActivos(equipoId: equipoId);
  }

  static Future<SyncResult> obtenerCensosPendientes() {
    return obtenerCensosActivos(enLocal: true);
  }

  // ========== MÉTODOS PRIVADOS HELPER ==========

  /// Construir parámetros de consulta
  static Map<String, String> _buildQueryParams({
    int? clienteId,
    int? equipoId,
    String? fechaDesde,
    String? fechaHasta,
    String? estado,
    bool? enLocal,
    int? limit,
    int? offset,
    String? edfVendedorId,
  }) {
    final Map<String, String> queryParams = {};

    if (edfVendedorId != null) queryParams['edfvendedorId'] = edfVendedorId;
    if (clienteId != null) queryParams['clienteId'] = clienteId.toString();
    if (equipoId != null) queryParams['equipoId'] = equipoId.toString();
    if (fechaDesde != null) queryParams['fechaDesde'] = fechaDesde;
    if (fechaHasta != null) queryParams['fechaHasta'] = fechaHasta;
    if (estado != null) queryParams['estado'] = estado;
    if (enLocal != null) queryParams['enLocal'] = enLocal.toString();
    if (limit != null) queryParams['limit'] = limit.toString();
    if (offset != null) queryParams['offset'] = offset.toString();

    return queryParams;
  }

  /// Realizar petición HTTP
  static Future<http.Response> _makeHttpRequest(Map<String, String> queryParams) async {
    final baseUrl = await BaseSyncService.getBaseUrl();
    final uri = Uri.parse('$baseUrl/api/getCensoActivo')
        .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    BaseSyncService.logger.i('📡 Llamando a: ${uri.toString()}');

    return await http.get(
      uri,
      headers: BaseSyncService.headers,
    ).timeout(BaseSyncService.timeout);
  }

  /// Verificar si el código de estado es exitoso
  static bool _isSuccessStatusCode(int statusCode) {
    return statusCode >= 200 && statusCode < 300;
  }

  /// Manejar respuesta de error
  static SyncResult _handleErrorResponse(http.Response response) {
    final mensaje = BaseSyncService.extractErrorMessage(response);
    BaseSyncService.logger.e('❌ Error del servidor: $mensaje');

    return SyncResult(
      exito: false,
      mensaje: 'Error del servidor: $mensaje',
      itemsSincronizados: 0,
    );
  }

  /// Parsear respuesta de censos - ADAPTADO AL FORMATO REAL DEL API
  static Future<List<dynamic>> _parseCensusResponse(http.Response response) async {
    BaseSyncService.logger.i('📥 Respuesta getCensoActivo: ${response.statusCode}');
    BaseSyncService.logger.i('📄 Body respuesta: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}...');

    try {
      final responseBody = jsonDecode(response.body);
      BaseSyncService.logger.i('📊 Tipo de respuesta: ${responseBody.runtimeType}');

      // 🔥 PARSING ESPECÍFICO PARA EL FORMATO: {"data": "[...]", "status": "OK"}
      if (responseBody is Map) {
        final responseMap = Map<String, dynamic>.from(responseBody);

        // Verificar estado
        final status = responseMap['status'];
        if (status != 'OK') {
          BaseSyncService.logger.e('❌ Estado del API no es OK: $status');
          return [];
        }

        // Obtener data
        final dataValue = responseMap['data'];
        if (dataValue == null) {
          BaseSyncService.logger.w('⚠️ Campo data es null');
          return [];
        }

        BaseSyncService.logger.i('📊 Tipo de data: ${dataValue.runtimeType}');

        if (dataValue is String) {
          // 🔥 CASO PRINCIPAL: data es un string JSON que necesita decodificarse
          try {
            final parsed = jsonDecode(dataValue) as List;
            BaseSyncService.logger.i('✅ Formato: data como string JSON, ${parsed.length} censos');
            return parsed;
          } catch (e) {
            BaseSyncService.logger.e('❌ Error parseando data como JSON: $e');
            return [];
          }
        } else if (dataValue is List) {
          // data es directamente un array
          BaseSyncService.logger.i('✅ Formato: data como array directo, ${dataValue.length} censos');
          return dataValue;
        } else {
          BaseSyncService.logger.w('⚠️ Formato de data no reconocido: ${dataValue.runtimeType}');
          return [];
        }

      } else if (responseBody is List) {
        // Formato directo de array (fallback)
        BaseSyncService.logger.i('✅ Formato: Array directo con ${responseBody.length} censos');
        return responseBody;
      } else {
        BaseSyncService.logger.e('❌ Formato de respuesta desconocido: ${responseBody.runtimeType}');
        return [];
      }
    } catch (e) {
      BaseSyncService.logger.e('❌ Error parseando respuesta: $e');
      throw Exception('Error parseando respuesta del servidor: $e');
    }
  }

  /// Procesar y guardar censos en la tabla censo_activo
  static Future<List<Map<String, dynamic>>> _processAndSaveCensus(
      List<dynamic> censosData,
      ) async {
    BaseSyncService.logger.i('📊 Total censos parseados: ${censosData.length}');

    if (censosData.isEmpty) {
      BaseSyncService.logger.w('⚠️ No se encontraron censos en la respuesta');
      return [];
    }

    // ANÁLISIS DETALLADO DE LOS CENSOS (solo primeros 3 para evitar spam de logs)
    _logCensusAnalysis(censosData);

    // ESTADÍSTICAS DE LOS CENSOS
    _logCensusStatistics(censosData);

    // PROCESAR Y GUARDAR CENSOS
    final censosValidos = <Map<String, dynamic>>[];
    int savedCount = 0;

    for (final censo in censosData) {
      if (censo is Map) {
        try {
          // Convertir a Map<String, dynamic> para evitar errores de tipo
          final censoMap = Map<String, dynamic>.from(censo);

          // Mapear campos del API a la tabla local
          final censoParaGuardar = _mapApiToLocalFormat(censoMap);

          // Guardar en base de datos
          await _saveCensusToDatabase(censoParaGuardar);

          censosValidos.add(censoParaGuardar);
          savedCount++;
        } catch (e) {
          BaseSyncService.logger.e('❌ Error procesando censo ID ${censo['id']}: $e');
        }
      }
    }

    BaseSyncService.logger.i('✅ Censos guardados en BD: $savedCount de ${censosData.length}');

    return censosValidos;
  }

  /// Mapear campos del API al formato de la tabla local censo_activo
  static Map<String, dynamic> _mapApiToLocalFormat(Map<String, dynamic> apiCensus) {
    return {
      'id': apiCensus['id']?.toString(),
      'equipo_id': apiCensus['edfEquipoId']?.toString(),
      'cliente_id': _parseIntSafely(apiCensus['edfClienteId']),
      'usuario_id': _parseIntSafely(apiCensus['usuarioId']),
      'en_local': apiCensus['enLocal'] == true ? 1 : 0,
      'latitud': _parseDoubleSafely(apiCensus['latitud']),
      'longitud': _parseDoubleSafely(apiCensus['longitud']),
      'fecha_revision': apiCensus['fechaDeRevision'],
      'fecha_creacion': apiCensus['creationDate'],
      'fecha_actualizacion': DateTime.now().toIso8601String(),
      'sincronizado': 1,
      'observaciones': apiCensus['observaciones']?.toString(),
      'estado_censo': apiCensus['estadoCenso'] ?? 'pendiente',
    };
  }

  /// Helper para parsear enteros de forma segura
  static int? _parseIntSafely(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      try {
        return int.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// Helper para parsear doubles de forma segura
  static double? _parseDoubleSafely(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// Guardar censo en la base de datos local
  static Future<void> _saveCensusToDatabase(Map<String, dynamic> censo) async {
    try {
      final dbHelper = DatabaseHelper();

      // Usar INSERT OR REPLACE para manejar duplicados
      await dbHelper.insertarOReemplazar('censo_activo', censo);

      BaseSyncService.logger.d('💾 Censo guardado: ID=${censo['id']}, Cliente=${censo['cliente_id']}, Equipo=${censo['equipo_id']}');
    } catch (e) {
      BaseSyncService.logger.e('❌ Error guardando censo ID ${censo['id']} en BD: $e');
      rethrow;
    }
  }

  /// Registrar análisis detallado de censos
  static void _logCensusAnalysis(List<dynamic> censosData) {
    BaseSyncService.logger.i('🔍 Analizando censos obtenidos...');

    final maxAnalysis = censosData.length > 3 ? 3 : censosData.length;

    for (int i = 0; i < maxAnalysis; i++) {
      final censo = censosData[i];
      BaseSyncService.logger.i('📊 Censo ${i + 1}:');

      if (censo is Map) {
        final censoMap = Map<String, dynamic>.from(censo);
        _logSingleCensusDetails(censoMap);
      } else {
        BaseSyncService.logger.w('   ⚠️ Censo no es Map: $censo');
      }
    }
  }

  /// Registrar detalles de un solo censo
  static void _logSingleCensusDetails(Map<String, dynamic> censo) {
    BaseSyncService.logger.i('   ID: ${censo['id']}');
    BaseSyncService.logger.i('   UUID: ${censo['uuid']}');
    BaseSyncService.logger.i('   Equipo ID: ${censo['edfEquipoId']}');
    BaseSyncService.logger.i('   Cliente ID: ${censo['edfClienteId']}');
    BaseSyncService.logger.i('   Estado: ${censo['estadoCenso']}');
    BaseSyncService.logger.i('   En Local: ${censo['enLocal']}');
    BaseSyncService.logger.i('   Fecha Revisión: ${censo['fechaDeRevision']}');
    BaseSyncService.logger.i('   Llaves disponibles: ${censo.keys.join(', ')}');
  }

  /// Registrar estadísticas de los censos
  static void _logCensusStatistics(List<dynamic> censosData) {
    final censosEnLocal = censosData.where((censo) =>
    censo is Map && censo['enLocal'] == true).length;
    final censosPendientes = censosData.where((censo) =>
    censo is Map && censo['estadoCenso'] == 'pendiente').length;
    final censosConUuid = censosData.where((censo) =>
    censo is Map && censo['uuid'] != null).length;

    BaseSyncService.logger.i('📊 Estadísticas de censos:');
    BaseSyncService.logger.i('   Total: ${censosData.length}');
    BaseSyncService.logger.i('   En Local: $censosEnLocal');
    BaseSyncService.logger.i('   Pendientes: $censosPendientes');
    BaseSyncService.logger.i('   Con UUID: $censosConUuid');
  }

  // ========== MÉTODOS DE CONSULTA LOCAL ==========

  /// Obtener censos desde la base de datos local
  static Future<List<Map<String, dynamic>>> obtenerCensosLocales({
    int? clienteId,
    String? equipoId,
    String? estado,
  }) async {
    try {
      final dbHelper = DatabaseHelper();

      String query = 'SELECT * FROM censo_activo WHERE 1=1';
      List<dynamic> args = [];

      if (clienteId != null) {
        query += ' AND cliente_id = ?';
        args.add(clienteId);
      }

      if (equipoId != null) {
        query += ' AND equipo_id = ?';
        args.add(equipoId);
      }

      if (estado != null) {
        query += ' AND estado_censo = ?';
        args.add(estado);
      }

      query += ' ORDER BY fecha_creacion DESC';

      return await dbHelper.consultarPersonalizada(query, args);
    } catch (e) {
      BaseSyncService.logger.e('❌ Error obteniendo censos locales: $e');
      return [];
    }
  }

  /// Contar censos en la base de datos local
  static Future<int> contarCensosLocales() async {
    try {
      final dbHelper = DatabaseHelper();
      final result = await dbHelper.consultarPersonalizada(
        'SELECT COUNT(*) as total FROM censo_activo',
        [],
      );
      return result.isNotEmpty ? (result.first['total'] as int? ?? 0) : 0;
    } catch (e) {
      BaseSyncService.logger.e('❌ Error contando censos locales: $e');
      return 0;
    }
  }
}