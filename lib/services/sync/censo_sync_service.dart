import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/services/database_helper.dart';

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

      if (!_isSuccessStatusCode(response.statusCode)) {
        return _handleErrorResponse(response);
      }

      final censosData = await _parseCensusResponse(response);
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
      BaseSyncService.logger.e('Error obteniendo censos activos: $e');
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
      final baseUrl = await BaseSyncService.getBaseUrl();
      final uri = Uri.parse('$baseUrl/api/getCensoActivo/$censoId');

      final response = await http.get(
        uri,
        headers: BaseSyncService.headers,
      ).timeout(BaseSyncService.timeout);

      if (!_isSuccessStatusCode(response.statusCode)) {
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
        return SyncResult(
          exito: false,
          mensaje: 'Censo no encontrado',
          itemsSincronizados: 0,
        );
      }

    } catch (e) {
      BaseSyncService.logger.e('Error obteniendo censo por ID: $e');
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
      final baseUrl = await BaseSyncService.getBaseUrl();
      final uri = Uri.parse('$baseUrl/api/getCensoActivo')
          .replace(queryParameters: {'codigoBarras': codigoBarras});

      final response = await http.get(
        uri,
        headers: BaseSyncService.headers,
      ).timeout(BaseSyncService.timeout);

      if (_isSuccessStatusCode(response.statusCode)) {
        final censosData = await _parseCensusResponse(response);
        _ultimosCensos = censosData;

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
  static Future<http.Response> _makeHttpRequest(Map<String, String> queryParams) async {
    final baseUrl = await BaseSyncService.getBaseUrl();
    final uri = Uri.parse('$baseUrl/api/getCensoActivo')
        .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

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
    return SyncResult(
      exito: false,
      mensaje: 'Error del servidor: $mensaje',
      itemsSincronizados: 0,
    );
  }

  /// Parsear respuesta de censos
  static Future<List<dynamic>> _parseCensusResponse(http.Response response) async {
    try {
      final responseBody = jsonDecode(response.body);

      if (responseBody is Map) {
        final responseMap = Map<String, dynamic>.from(responseBody);

        final status = responseMap['status'];
        if (status != 'OK') {
          return [];
        }

        final dataValue = responseMap['data'];
        if (dataValue == null) return [];

        if (dataValue is String) {
          try {
            final parsed = jsonDecode(dataValue) as List;
            return parsed;
          } catch (e) {
            BaseSyncService.logger.e('Error parseando data como JSON: $e');
            return [];
          }
        } else if (dataValue is List) {
          return dataValue;
        }

        return [];
      } else if (responseBody is List) {
        return responseBody;
      }

      return [];
    } catch (e) {
      BaseSyncService.logger.e('Error parseando respuesta: $e');
      throw Exception('Error parseando respuesta del servidor: $e');
    }
  }

  /// Procesar y guardar censos usando vaciarEInsertar
  static Future<List<Map<String, dynamic>>> _processAndSaveCensus(
      List<dynamic> censosData,
      ) async {
    if (censosData.isEmpty) return [];

    // Convertir datos del API al formato local
    final censosParaGuardar = <Map<String, dynamic>>[];

    for (final censo in censosData) {
      if (censo is Map) {
        try {
          final censoMap = Map<String, dynamic>.from(censo);
          final censoParaGuardar = _mapApiToLocalFormat(censoMap);
          censosParaGuardar.add(censoParaGuardar);
        } catch (e) {
          BaseSyncService.logger.e('Error procesando censo ID ${censo['id']}: $e');
        }
      }
    }

    // Vaciar tabla e insertar todos los censos
    final dbHelper = DatabaseHelper();
    await dbHelper.vaciarEInsertar('censo_activo', censosParaGuardar);


    return censosParaGuardar;
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

  /// Guardar censo individual en la base de datos local
  static Future<void> _saveCensusToDatabase(Map<String, dynamic> censo) async {
    try {
      final dbHelper = DatabaseHelper();
      await dbHelper.vaciarEInsertar('censo_activo', [censo]); // 👈 [censo] en lista
    } catch (e) {
      BaseSyncService.logger.e('Error guardando censo ID ${censo['id']} en BD: $e');
      rethrow;
    }
  }
}