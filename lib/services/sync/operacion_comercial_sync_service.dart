// lib/services/sync/operacion_comercial_sync_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import 'package:ada_app/repositories/operacion_comercial_repository.dart';
import 'package:ada_app/models/operaciones_comerciales/operacion_comercial.dart';
import 'package:ada_app/models/operaciones_comerciales/operacion_comercial_detalle.dart';
import 'package:ada_app/models/operaciones_comerciales/enums/tipo_operacion.dart';
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/services/error_log/error_log_service.dart';
import 'package:ada_app/services/database_helper.dart';
import '../post/operaciones_comerciales_post_service.dart';

class OperacionComercialSyncService extends BaseSyncService {
  final OperacionComercialRepositoryImpl _operacionRepository;

  static const String _tableName = 'operacion_comercial';
  static const int maxIntentos = 10;
  static const Duration intervaloTimer = Duration(minutes: 1);

  static Timer? _syncTimer;
  static bool _syncActivo = false;
  static bool _syncEnProgreso = false;
  static int? _usuarioActual;

  static List<dynamic> _ultimasOperaciones = [];

  OperacionComercialSyncService({
    OperacionComercialRepositoryImpl? operacionRepository,
  }) : _operacionRepository =
      operacionRepository ?? OperacionComercialRepositoryImpl();

  static List<dynamic> get ultimasOperacionesObtenidas =>
      List.from(_ultimasOperaciones);

  // ==================== MÉTODOS GET ====================

  /// Obtiene operaciones comerciales desde el servidor
  static Future<SyncResult> obtenerOperaciones({
    String? edfVendedorId,
    int? partnerId,
    String? tipo,
  }) async {
    String? currentEndpoint;

    try {
      // 1. Obtener operaciones (cabecera)
      final queryParams = _buildQueryParams(
        edfVendedorId: edfVendedorId,
        partnerId: partnerId,
        tipo: tipo,
      );

      final operacionesResponse = await _makeHttpRequest(
        '/api/getOperacionComercial',
        queryParams,
      );
      currentEndpoint = operacionesResponse.request?.url.toString();

      if (!_isSuccessStatusCode(operacionesResponse.statusCode)) {
        return _handleErrorResponse(operacionesResponse);
      }

      final operacionesData = await _parseResponse(operacionesResponse);

      if (operacionesData.isEmpty) {
        return SyncResult(
          exito: true,
          mensaje: 'No hay operaciones para sincronizar',
          itemsSincronizados: 0,
          totalEnAPI: 0,
        );
      }

      // 2. Obtener detalles
      final detallesResponse = await _makeHttpRequest(
        '/api/getOperacionComercialDetalle',
        queryParams,
      );

      if (!_isSuccessStatusCode(detallesResponse.statusCode)) {
        return _handleErrorResponse(detallesResponse);
      }

      final detallesData = await _parseResponse(detallesResponse);

      // 3. Vincular operaciones con sus detalles
      final operacionesConDetalles = await _vincularOperacionesConDetalles(
        operacionesData,
        detallesData,
      );

      // 4. Procesar y guardar
      final processedResult = await _processAndSaveOperaciones(
        operacionesConDetalles,
      );

      _ultimasOperaciones = processedResult;

      return SyncResult(
        exito: true,
        mensaje: 'Operaciones sincronizadas correctamente',
        itemsSincronizados: processedResult.length,
        totalEnAPI: processedResult.length,
      );

    } on TimeoutException catch (timeoutError) {
      _ultimasOperaciones = [];
      return SyncResult(
        exito: false,
        mensaje: 'Timeout de conexión al servidor',
        itemsSincronizados: 0,
      );

    } on SocketException catch (socketError) {
      _ultimasOperaciones = [];
      return SyncResult(
        exito: false,
        mensaje: 'Sin conexión de red',
        itemsSincronizados: 0,
      );

    } catch (e) {
      _ultimasOperaciones = [];
      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

  /// Obtiene operaciones para un vendedor específico
  static Future<SyncResult> obtenerOperacionesPorVendedor(String edfVendedorId) {
    return obtenerOperaciones(edfVendedorId: edfVendedorId);
  }

  /// Obtiene operaciones de un cliente específico
  static Future<SyncResult> obtenerOperacionesPorCliente(int partnerId) {
    return obtenerOperaciones(partnerId: partnerId);
  }

  /// Obtiene operaciones por tipo
  static Future<SyncResult> obtenerOperacionesPorTipo(String tipo) {
    return obtenerOperaciones(tipo: tipo);
  }

  static Map<String, String> _buildQueryParams({
    String? edfVendedorId,
    int? partnerId,
    String? tipo,
  }) {
    final Map<String, String> queryParams = {};

    if (edfVendedorId != null) queryParams['edfvendedorId'] = edfVendedorId;
    if (partnerId != null) queryParams['partnerId'] = partnerId.toString();
    if (tipo != null) queryParams['tipo'] = tipo;

    return queryParams;
  }

  static Future<http.Response> _makeHttpRequest(
      String endpoint,
      Map<String, String> queryParams,
      ) async {
    final baseUrl = await BaseSyncService.getBaseUrl();
    final uri = Uri.parse('$baseUrl$endpoint')
        .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    return await http.get(
      uri,
      headers: BaseSyncService.headers,
    ).timeout(BaseSyncService.timeout);
  }

  static bool _isSuccessStatusCode(int statusCode) {
    return statusCode >= 200 && statusCode < 300;
  }

  static SyncResult _handleErrorResponse(http.Response response) {
    final mensaje = BaseSyncService.extractErrorMessage(response);
    return SyncResult(
      exito: false,
      mensaje: 'Error del servidor: $mensaje',
      itemsSincronizados: 0,
    );
  }

  static Future<List<dynamic>> _parseResponse(http.Response response) async {
    try {
      final responseBody = jsonDecode(response.body);

      if (responseBody is Map) {
        final responseMap = Map<String, dynamic>.from(responseBody);

        final dataValue = responseMap['data'];
        if (dataValue == null) return [];

        if (dataValue is String) {
          try {
            final parsed = jsonDecode(dataValue) as List;
            return parsed;
          } catch (e) {
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
      throw Exception('Error parseando respuesta del servidor: $e');
    }
  }

  /// Vincula operaciones con sus detalles y completa info de productos
  static Future<List<Map<String, dynamic>>> _vincularOperacionesConDetalles(
      List<dynamic> operacionesData,
      List<dynamic> detallesData,
      ) async {
    final operacionesConDetalles = <Map<String, dynamic>>[];

    // Agrupar detalles por operacionId
    final detallesPorOperacion = <int, List<Map<String, dynamic>>>{};
    for (final detalle in detallesData) {
      if (detalle is Map) {
        final detalleMap = Map<String, dynamic>.from(detalle);
        final operacionId = detalleMap['operacionComercial']?['id'];

        if (operacionId != null) {
          if (!detallesPorOperacion.containsKey(operacionId)) {
            detallesPorOperacion[operacionId] = [];
          }
          detallesPorOperacion[operacionId]!.add(detalleMap);
        }
      }
    }

    // Vincular cada operación con sus detalles
    for (final operacion in operacionesData) {
      if (operacion is Map) {
        final operacionMap = Map<String, dynamic>.from(operacion);
        final operacionId = operacionMap['id'];

        // Agregar detalles a la operación
        operacionMap['detalles'] = detallesPorOperacion[operacionId] ?? [];
        operacionesConDetalles.add(operacionMap);
      }
    }

    return operacionesConDetalles;
  }

  static Future<List<Map<String, dynamic>>> _processAndSaveOperaciones(
      List<Map<String, dynamic>> operacionesData,
      ) async {
    if (operacionesData.isEmpty) return [];

    final operacionesParaGuardar = <Map<String, dynamic>>[];
    int operacionesInvalidas = 0;

    for (final operacion in operacionesData) {
      try {
        final operacionParaGuardar = await _mapApiToLocalFormat(operacion);
        operacionesParaGuardar.add(operacionParaGuardar);
      } catch (e) {
        // Saltar operación inválida
        operacionesInvalidas++;
        print('⚠️ Error procesando operación: $e');
      }
    }

    if (operacionesParaGuardar.isNotEmpty) {
      try {
        final repo = OperacionComercialRepositoryImpl();
        await repo.guardarOperacionesDesdeServidor(operacionesParaGuardar);
      } catch (e) {
        await ErrorLogService.logDatabaseError(
          tableName: _tableName,
          operation: 'guardar_via_repository',
          errorMessage: 'Error guardando operaciones via repository: $e',
        );
        rethrow;
      }
    }

    if (operacionesInvalidas > 0) {
      print('⚠️ Se saltaron $operacionesInvalidas operaciones con datos incompletos');
    }

    return operacionesParaGuardar;
  }

  static Future<Map<String, dynamic>> _mapApiToLocalFormat(
      Map<String, dynamic> apiOperacion,
      ) async {
    // Validar datos requeridos
    final partnerId = _parseIntSafely(apiOperacion['partnerId']);
    final tipo = apiOperacion['tipo']?.toString();

    if (partnerId == null || tipo == null || tipo.trim().isEmpty) {
      throw Exception('Operación sin datos requeridos (partnerId o tipo)');
    }

    // Mapear operación (cabecera)
    final operacionLocal = {
      'id': apiOperacion['uuid']?.toString() ?? apiOperacion['id']?.toString(),
      'cliente_id': partnerId,
      'tipo_operacion': tipo,
      'fecha_creacion': apiOperacion['creationDate']?.toString() ??
          DateTime.now().toIso8601String(),
      'fecha_retiro': apiOperacion['fechaRetiro']?.toString(),
      'observaciones': null,
      'total_productos': 0,
      'usuario_id': _parseIntSafely(apiOperacion['creationUser']),
      'server_id': _parseIntSafely(apiOperacion['id']),
      'sync_status': 'migrado',
      'sync_error': apiOperacion['errorText']?.toString(),
      'synced_at': DateTime.now().toIso8601String(),
      'sync_retry_count': 0,
    };

    // Mapear detalles
    final detalles = <Map<String, dynamic>>[];
    if (apiOperacion.containsKey('detalles') && apiOperacion['detalles'] is List) {
      final detallesApi = apiOperacion['detalles'] as List;

      for (int i = 0; i < detallesApi.length; i++) {
        if (detallesApi[i] is Map) {
          final detalleMap = Map<String, dynamic>.from(detallesApi[i]);
          final detalleMapeado = await _mapDetalleToLocalFormat(
            detalleMap,
            operacionLocal['id'] as String,
            i + 1,
          );
          detalles.add(detalleMapeado);
        }
      }
    }

    operacionLocal['total_productos'] = detalles.length;
    operacionLocal['detalles'] = detalles;

    return operacionLocal;
  }

  static Future<Map<String, dynamic>> _mapDetalleToLocalFormat(
      Map<String, dynamic> apiDetalle,
      String operacionId,
      int orden,
      ) async {
    // Obtener info del producto desde la BD local
    final productId = _parseIntSafely(apiDetalle['productId']);
    final productoInfo = await _obtenerInfoProducto(productId);

    return {
      'id': apiDetalle['uuid']?.toString() ??
          apiDetalle['id']?.toString() ??
          '${operacionId}_det_$orden',
      'operacion_comercial_id': operacionId,
      'producto_codigo': productoInfo['codigo'] ?? '',
      'producto_descripcion': productoInfo['nombre'] ?? '',
      'producto_categoria': productoInfo['categoria'] ?? '',
      'producto_id': productId,
      'cantidad': _parseDoubleSafely(apiDetalle['cantidad']),
      'unidad_medida': productoInfo['unidadMedida'] ?? '',
      'ticket': apiDetalle['ticket']?.toString(),
      'precio_unitario': 0.0, // No viene en el API
      'subtotal': 0.0, // No viene en el API
      'orden': orden,
      'fecha_creacion': DateTime.now().toIso8601String(),
      'producto_reemplazo_id': null,
      'producto_reemplazo_codigo': null,
      'producto_reemplazo_descripcion': null,
      'producto_reemplazo_categoria': null,
    };
  }

  /// Obtiene información del producto desde la BD local
  /// Obtiene información del producto desde la BD local
  static Future<Map<String, dynamic>> _obtenerInfoProducto(int? productId) async {
    if (productId == null) {
      return {
        'codigo': '',
        'nombre': 'Producto desconocido',
        'categoria': '',
        'unidadMedida': 'Units',
      };
    }

    try {
      final db = await DatabaseHelper().database;
      final result = await db.query(
        'Productos',
        columns: ['codigo', 'nombre', 'categoria', 'unidadMedida'],
        where: 'id = ?',
        whereArgs: [productId],
        limit: 1,
      );

      if (result.isNotEmpty) {
        return Map<String, dynamic>.from(result.first);
      }

      return {
        'codigo': '',
        'nombre': 'Producto ID: $productId',
        'categoria': '',
        'unidadMedida': 'Units',
      };
    } catch (e) {
      print('Error obteniendo info de producto $productId: $e');
      return {
        'codigo': '',
        'nombre': 'Producto ID: $productId',
        'categoria': '',
        'unidadMedida': 'Units',
      };
    }
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

  static double _parseDoubleSafely(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return 0.0;
      }
    }
    return 0.0;
  }

  // ==================== MÉTODOS POST (EXISTENTES) ====================

  /// Sincroniza todas las operaciones pendientes o con error.
  Future<Map<String, int>> sincronizarOperacionesPendientes(
      int usuarioId,
      ) async {
    int operacionesExitosas = 0;
    int totalFallidas = 0;

    try {
      final operacionesCreadas = await _operacionRepository
          .obtenerOperacionesPendientes();
      final operacionesError = await _operacionRepository
          .obtenerOperacionesConError();
      final operacionesErrorListas =
      await _filtrarOperacionesListasParaReintento(operacionesError);

      final todasLasOperaciones = [
        ...operacionesCreadas,
        ...operacionesErrorListas,
      ];

      final operacionesAProcesar = todasLasOperaciones.take(20);

      for (final operacion in operacionesAProcesar) {
        try {
          await _sincronizarOperacionIndividual(operacion, usuarioId);
          operacionesExitosas++;
        } catch (e) {
          totalFallidas++;
        }

        await Future.delayed(Duration(milliseconds: 500));
      }

      return {
        'operaciones_exitosas': operacionesExitosas,
        'fallidas': totalFallidas,
        'total': operacionesExitosas,
      };
    } catch (e) {
      await ErrorLogService.manejarExcepcion(
        e,
        null,
        null,
        usuarioId,
        _tableName,
      );

      return {
        'operaciones_exitosas': operacionesExitosas,
        'fallidas': totalFallidas,
        'total': 0,
      };
    }
  }

  Future<void> _sincronizarOperacionIndividual(
      OperacionComercial operacion,
      int usuarioId,
      ) async {
    try {
      final operacionId = operacion.id;
      if (operacionId == null) {
        throw Exception('Operación sin ID');
      }

      final intentosPrevios = operacion.syncRetryCount;
      final numeroIntento = intentosPrevios + 1;

      if (numeroIntento > maxIntentos) {
        return;
      }
      await _actualizarIntentoSincronizacion(operacionId, numeroIntento);

      await OperacionesComercialesPostService.enviarOperacion(operacion);
    } catch (e) {
      rethrow;
    }
  }

  Future<List<OperacionComercial>> _filtrarOperacionesListasParaReintento(
      List<OperacionComercial> operacionesError,
      ) async {
    final operacionesListas = <OperacionComercial>[];
    final ahora = DateTime.now();

    for (final operacion in operacionesError) {
      try {
        final intentos = operacion.syncRetryCount;

        if (intentos >= maxIntentos) {
          continue;
        }

        if (operacion.syncedAt == null) {
          operacionesListas.add(operacion);
          continue;
        }

        final minutosEspera = _calcularProximoIntento(intentos);
        if (minutosEspera < 0) continue;

        final tiempoProximoIntento = operacion.syncedAt!.add(
          Duration(minutes: minutosEspera),
        );

        if (ahora.isAfter(tiempoProximoIntento)) {
          operacionesListas.add(operacion);
        }
      } catch (e) {
        operacionesListas.add(operacion);
      }
    }

    return operacionesListas;
  }

  int _calcularProximoIntento(int numeroIntento) {
    if (numeroIntento > maxIntentos) return -1;

    switch (numeroIntento) {
      case 1:
        return 1;
      case 2:
        return 5;
      case 3:
        return 10;
      case 4:
        return 15;
      case 5:
        return 20;
      case 6:
        return 25;
      default:
        return 30;
    }
  }

  Future<void> _actualizarIntentoSincronizacion(
      String operacionId,
      int numeroIntento,
      ) async {
    try {
      await _operacionRepository.actualizarIntentoSync(
        operacionId,
        numeroIntento,
      );
    } catch (e) {
      rethrow;
    }
  }

  // ==================== SINCRONIZACIÓN AUTOMÁTICA ====================

  static void iniciarSincronizacionAutomatica(int usuarioId) {
    if (_syncActivo && _usuarioActual == usuarioId) {
      return;
    }

    detenerSincronizacionAutomatica();

    _usuarioActual = usuarioId;
    _syncActivo = true;

    _syncTimer = Timer.periodic(intervaloTimer, (timer) async {
      await _ejecutarSincronizacionAutomatica();
    });

    Timer(const Duration(seconds: 15), () async {
      await _ejecutarSincronizacionAutomatica();
    });
  }

  static void detenerSincronizacionAutomatica() {
    if (_syncTimer != null) {
      _syncTimer!.cancel();
      _syncTimer = null;
      _syncActivo = false;
      _syncEnProgreso = false;
      _usuarioActual = null;
    }
  }

  static Future<void> _ejecutarSincronizacionAutomatica() async {
    if (_syncEnProgreso || !_syncActivo || _usuarioActual == null) return;

    _syncEnProgreso = true;

    try {
      final conexion = await BaseSyncService.testConnection();
      if (!conexion.exito) {
        return;
      }

      final service = OperacionComercialSyncService();
      await service.sincronizarOperacionesPendientes(_usuarioActual!);

    } catch (e) {
      // Error handling managed internally
    } finally {
      _syncEnProgreso = false;
    }
  }

  static bool get esSincronizacionActiva => _syncActivo;
  static bool get estaEnProgreso => _syncEnProgreso;
  static int? get usuarioActual => _usuarioActual;
}