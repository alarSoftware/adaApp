import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:http/http.dart' as http;
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/services/data/database_helper.dart';
import 'package:ada_app/services/error_log/error_log_service.dart';

/// Servicio de sincronización de censos activos
/// Formato del API: {"data": "[{...}]", "status": "OK"}
class CensusSyncService extends BaseSyncService {
  // Variables estáticas para almacenar los últimos censos obtenidos
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
    String? edfVendedorId,
  }) async {
    String? currentEndpoint;

    try {
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

      final response = await _makeHttpRequest(queryParams);
      currentEndpoint = response.request?.url.toString();

      if (!_isSuccessStatusCode(response.statusCode)) {
        final errorMessage = BaseSyncService.extractErrorMessage(response);
        return _handleErrorResponse(response);
      }

      // Procesar JSON en Isolate
      final processedResult = await _procesarCensosEnIsolate(response.body);

      // Guardar en BD (hilo principal)
      if (processedResult.isNotEmpty) {
        try {
          final dbHelper = DatabaseHelper();
          await dbHelper.vaciarEInsertar('censo_activo', processedResult);
        } catch (e) {
          BaseSyncService.logger.e('Error guardando censos en BD: $e');
          await ErrorLogService.logDatabaseError(
            tableName: 'censo_activo',
            operation: 'bulk_insert',
            errorMessage: 'Error en vaciarEInsertar: $e',
          );
        }
      }

      // Guardar los datos para acceso posterior
      _ultimosCensos = processedResult;

      return SyncResult(
        exito: true,
        mensaje: 'Censos obtenidos correctamente',
        itemsSincronizados: processedResult.length,
        totalEnAPI: processedResult.length,
      );
    } on TimeoutException catch (timeoutError) {
      BaseSyncService.logger.e('⏰ Timeout obteniendo censos: $timeoutError');

      // 🚨 LOG ERROR: Timeout
      // await ErrorLogService.logNetworkError(
      //   tableName: 'censo_activo',
      //   operation: 'sync_from_server',
      //   errorMessage: 'Timeout de conexión: $timeoutError',
      //   endpoint: currentEndpoint,
      //   userId: edfVendedorId,
      // );

      _ultimosCensos = [];
      return SyncResult(
        exito: false,
        mensaje: 'Timeout de conexión al servidor',
        itemsSincronizados: 0,
      );
    } on SocketException catch (socketError) {
      BaseSyncService.logger.e('📡 Error de red: $socketError');

      // 🚨 LOG ERROR: Sin conexión de red
      // await ErrorLogService.logNetworkError(
      //   tableName: 'censo_activo',
      //   operation: 'sync_from_server',
      //   errorMessage: 'Sin conexión de red: $socketError',
      //   endpoint: currentEndpoint,
      //   userId: edfVendedorId,
      // );

      _ultimosCensos = [];
      return SyncResult(
        exito: false,
        mensaje: 'Sin conexión de red',
        itemsSincronizados: 0,
      );
    } catch (e) {
      BaseSyncService.logger.e('💥 Error obteniendo censos activos: $e');

      // 🚨 LOG ERROR: Error general
      // await ErrorLogService.logError(
      //   tableName: 'censo_activo',
      //   operation: 'sync_from_server',
      //   errorMessage: 'Error general: $e',
      //   errorType: 'unknown',
      //   errorCode: 'GENERAL_ERROR',
      //   endpoint: currentEndpoint,
      //   userId: edfVendedorId,
      // );

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
    String? currentEndpoint;

    try {
      final baseUrl = await BaseSyncService.getBaseUrl();
      final uri = Uri.parse('$baseUrl/api/getCensoActivo/$censoId');
      currentEndpoint = uri.toString();

      final response = await http
          .get(uri, headers: BaseSyncService.headers)
          .timeout(BaseSyncService.timeout);

      if (!_isSuccessStatusCode(response.statusCode)) {
        // 🚨 LOG ERROR: Error del servidor
        await ErrorLogService.logServerError(
          tableName: 'censo_activo',
          operation: 'get_by_id',
          errorMessage: BaseSyncService.extractErrorMessage(response),
          errorCode: response.statusCode.toString(),
          endpoint: currentEndpoint,
          registroFailId: censoId.toString(),
        );

        return _handleErrorResponse(response);
      }

      final responseBody = jsonDecode(response.body);
      Map<String, dynamic>? censoData;

      if (responseBody is Map) {
        final responseMap = Map<String, dynamic>.from(responseBody);

        if (responseMap.containsKey('data') && responseMap['status'] == 'OK') {
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
          censoData = responseMap;
        }
      }

      _ultimoCenso = censoData;

      if (censoData != null) {
        await _saveCensusToDatabase(_mapApiToLocalFormat(censoData));
        return SyncResult(
          exito: true,
          mensaje: 'Censo obtenido correctamente',
          itemsSincronizados: 1,
        );
      } else {
        // 🚨 LOG ERROR: Censo no encontrado
        await ErrorLogService.logValidationError(
          tableName: 'censo_activo',
          operation: 'get_by_id',
          errorMessage: 'Censo no encontrado',
          registroFailId: censoId.toString(),
        );

        return SyncResult(
          exito: false,
          mensaje: 'Censo no encontrado',
          itemsSincronizados: 0,
        );
      }
    } on TimeoutException catch (timeoutError) {
      await ErrorLogService.logNetworkError(
        tableName: 'censo_activo',
        operation: 'get_by_id',
        errorMessage: 'Timeout: $timeoutError',
        endpoint: currentEndpoint,
        registroFailId: censoId.toString(),
      );

      _ultimoCenso = null;
      return SyncResult(
        exito: false,
        mensaje: 'Timeout de conexión',
        itemsSincronizados: 0,
      );
    } on SocketException catch (socketError) {
      await ErrorLogService.logNetworkError(
        tableName: 'censo_activo',
        operation: 'get_by_id',
        errorMessage: 'Sin conexión: $socketError',
        endpoint: currentEndpoint,
        registroFailId: censoId.toString(),
      );

      _ultimoCenso = null;
      return SyncResult(
        exito: false,
        mensaje: 'Sin conexión de red',
        itemsSincronizados: 0,
      );
    } catch (e) {
      BaseSyncService.logger.e('Error obteniendo censo por ID: $e');

      await ErrorLogService.logError(
        tableName: 'censo_activo',
        operation: 'get_by_id',
        errorMessage: 'Error: $e',
        errorType: 'unknown',
        endpoint: currentEndpoint,
        registroFailId: censoId.toString(),
      );

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
    String? currentEndpoint;

    try {
      final baseUrl = await BaseSyncService.getBaseUrl();
      final uri = Uri.parse(
        '$baseUrl/api/getCensoActivo',
      ).replace(queryParameters: {'codigoBarras': codigoBarras});
      currentEndpoint = uri.toString();

      final response = await http
          .get(uri, headers: BaseSyncService.headers)
          .timeout(BaseSyncService.timeout);

      if (_isSuccessStatusCode(response.statusCode)) {
        final censosData = await _procesarCensosEnIsolate(response.body);
        _ultimosCensos = censosData;

        return SyncResult(
          exito: true,
          mensaje: 'Búsqueda completada: ${censosData.length} resultados',
          itemsSincronizados: censosData.length,
        );
      } else {
        // 🚨 LOG ERROR: Error en búsqueda
        await ErrorLogService.logServerError(
          tableName: 'censo_activo',
          operation: 'buscar_por_codigo',
          errorMessage: BaseSyncService.extractErrorMessage(response),
          errorCode: response.statusCode.toString(),
          endpoint: currentEndpoint,
        );

        _ultimosCensos = [];
        return SyncResult(
          exito: false,
          mensaje:
              'Error en búsqueda: ${BaseSyncService.extractErrorMessage(response)}',
          itemsSincronizados: 0,
        );
      }
    } on TimeoutException catch (timeoutError) {
      await ErrorLogService.logNetworkError(
        tableName: 'censo_activo',
        operation: 'buscar_por_codigo',
        errorMessage: 'Timeout: $timeoutError',
        endpoint: currentEndpoint,
      );

      _ultimosCensos = [];
      return SyncResult(
        exito: false,
        mensaje: 'Timeout de conexión',
        itemsSincronizados: 0,
      );
    } on SocketException catch (socketError) {
      await ErrorLogService.logNetworkError(
        tableName: 'censo_activo',
        operation: 'buscar_por_codigo',
        errorMessage: 'Sin conexión: $socketError',
        endpoint: currentEndpoint,
      );

      _ultimosCensos = [];
      return SyncResult(
        exito: false,
        mensaje: 'Sin conexión de red',
        itemsSincronizados: 0,
      );
    } catch (e) {
      BaseSyncService.logger.e('Error buscando por código: $e');

      await ErrorLogService.logError(
        tableName: 'censo_activo',
        operation: 'buscar_por_codigo',
        errorMessage: 'Error: $e',
        errorType: 'unknown',
        endpoint: currentEndpoint,
      );

      _ultimosCensos = [];
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
      BaseSyncService.logger.e('Error obteniendo censos locales: $e');

      await ErrorLogService.logDatabaseError(
        tableName: 'censo_activo',
        operation: 'query_local',
        errorMessage: 'Error consultando BD local: $e',
      );

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
      BaseSyncService.logger.e('Error contando censos locales: $e');

      await ErrorLogService.logDatabaseError(
        tableName: 'censo_activo',
        operation: 'count_local',
        errorMessage: 'Error contando en BD local: $e',
      );

      return 0;
    }
  }

  // ========== MÉTODOS PRIVADOS ==========

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
  static Future<http.Response> _makeHttpRequest(
    Map<String, String> queryParams,
  ) async {
    final baseUrl = await BaseSyncService.getBaseUrl();
    final uri = Uri.parse(
      '$baseUrl/api/getCensoActivo',
    ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    return await http
        .get(uri, headers: BaseSyncService.headers)
        .timeout(BaseSyncService.timeout);
  }

  /// Verificar si el código de estado es exitoso
  static bool _isSuccessStatusCode(int statusCode) {
    return statusCode >= 200 && statusCode < 300;
  }

  /// Manejar respuesta de error
  static SyncResult _handleErrorResponse(http.Response response) {
    final mensaje = BaseSyncService.extractErrorMessage(response);
    return SyncResult(
      exito: false,
      mensaje: 'Error del servidor: $mensaje',
      itemsSincronizados: 0,
    );
  }

  /// Parsear respuesta de censos

  /// Mapear campos del API al formato de la tabla local censo_activo
  static Map<String, dynamic> _mapApiToLocalFormat(
    Map<String, dynamic> apiCensus,
  ) {
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
      'observaciones': apiCensus['observaciones']?.toString(),
      'estado_censo': 'migrado',
    };
  }

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

  /// Guardar censo individual en la base de datos local
  static Future<void> _saveCensusToDatabase(Map<String, dynamic> censo) async {
    try {
      final dbHelper = DatabaseHelper();
      await dbHelper.vaciarEInsertar('censo_activo', [censo]);
    } catch (e) {
      BaseSyncService.logger.e(
        'Error guardando censo ID ${censo['id']} en BD: $e',
      );

      await ErrorLogService.logDatabaseError(
        tableName: 'censo_activo',
        operation: 'save_single',
        errorMessage: 'Error guardando censo en BD: $e',
        registroFailId: censo['id']?.toString(),
      );

      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> _procesarCensosEnIsolate(
    String responseBody,
  ) async {
    return await Isolate.run(() => _procesarCensosJSON(responseBody));
  }

  static List<Map<String, dynamic>> _procesarCensosJSON(String responseBody) {
    try {
      final decoded = jsonDecode(responseBody);
      List<dynamic> censosData = [];

      if (decoded is Map) {
        final responseMap = Map<String, dynamic>.from(decoded);
        if (responseMap['status'] != 'OK') return [];

        final dataValue = responseMap['data'];
        if (dataValue == null) return [];

        if (dataValue is String) {
          try {
            censosData = jsonDecode(dataValue) as List;
          } catch (e) {
            return [];
          }
        } else if (dataValue is List) {
          censosData = dataValue;
        }
      } else if (decoded is List) {
        censosData = decoded;
      }

      final censosParaGuardar = <Map<String, dynamic>>[];

      for (final censo in censosData) {
        if (censo is Map) {
          try {
            final censoMap = Map<String, dynamic>.from(censo);
            final censoParaGuardar = _mapApiToLocalFormat(censoMap);
            censosParaGuardar.add(censoParaGuardar);
          } catch (e) {
            // Error procesando censo
          }
        }
      }

      return censosParaGuardar;
    } catch (e) {
      return [];
    }
  }
}
