// lib/services/sync/operacion_comercial_sync_service.dart
import 'package:flutter/foundation.dart';

import 'dart:async';
import 'dart:convert';

import 'dart:isolate';
import 'package:http/http.dart' as http;
import 'package:ada_app/services/network/monitored_http_client.dart';

import 'package:ada_app/repositories/operacion_comercial_repository.dart';
import 'package:ada_app/models/operaciones_comerciales/operacion_comercial.dart';

import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/services/error_log/error_log_service.dart';

import '../post/operaciones_comerciales_post_service.dart';

class OperacionComercialSyncService extends BaseSyncService {
  final OperacionComercialRepositoryImpl _operacionRepository;

  static const String _tableName = 'operacion_comercial';
  static const int maxIntentos = 60; // 60 min = 1 hora
  static const Duration intervaloTimer = Duration(minutes: 1);
  static const Duration intervaloOdooName = Duration(minutes: 30);

  static Timer? _syncTimer;
  static Timer? _odooNameTimer;
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

  static Future<SyncResult> obtenerOperaciones({
    String? employeeId,
    int? partnerId,
    String? tipo,
  }) async {
    debugPrint('INICIO DESCARGA DE OPERACIONES');
    try {
      final queryParams = <String, String>{};

      if (employeeId != null) {
        // SEGURIDAD: Verificar si hay pendientes
        final pendientes = await OperacionComercialRepositoryImpl()
            .obtenerOperacionesPendientes();

        if (pendientes.isNotEmpty) {
          return SyncResult(
            exito: false,
            mensaje:
                'Hay ${pendientes.length} operaciones pendientes. Por favor sincronízalas antes de actualizar.',
            itemsSincronizados: 0,
          );
        }

        // LIMPIEZA: Si no hay pendientes, limpiar todo para evitar duplicados/stale data
        await OperacionComercialRepositoryImpl().eliminarTodasLasOperaciones();

        queryParams['employeeId'] = employeeId;
      }
      if (partnerId != null) {
        // VALIDACIÓN DE SEGURIDAD:
        // Antes de descargar y reemplazar, verificamos si hay pendientes locales.
        final pendientes = await OperacionComercialRepositoryImpl()
            .obtenerOperacionesPendientesPorCliente(partnerId);

        if (pendientes.isNotEmpty) {
          return SyncResult(
            exito: false,
            mensaje:
                'Hay ${pendientes.length} operaciones pendientes de envío para este cliente. Por favor, incia la sincronización antes de descargar nuevas.',
            itemsSincronizados: 0,
          );
        }

        // Si no hay pendientes, es seguro limpiar para evitar duplicados.
        await OperacionComercialRepositoryImpl().eliminarOperacionesPorCliente(
          partnerId,
        );

        queryParams['partnerId'] = partnerId.toString();
      }
      if (tipo != null) {
        queryParams['tipo'] = tipo;
      }

      final operacionesResponse = await _makeHttpRequest(
        '/api/getOperacionComercial',
        queryParams,
      );

      if (!_isSuccessStatusCode(operacionesResponse.statusCode)) {
        return _handleErrorResponse(operacionesResponse);
      }

      final operacionesData = await _parseResponse(operacionesResponse);

      if (operacionesData.isEmpty) {
        debugPrint('FIN DE DESCARGA');
        return SyncResult(
          exito: true,
          mensaje: 'No hay operaciones para sincronizar',
          itemsSincronizados: 0,
          totalEnAPI: 0,
        );
      }

      final detallesResponse = await _makeHttpRequest(
        '/api/getOperacionComercialDetalle',
        queryParams,
      );

      if (!_isSuccessStatusCode(detallesResponse.statusCode)) {
        return _handleErrorResponse(detallesResponse);
      }

      final detallesData = await _parseResponse(detallesResponse);

      final operacionesConDetalles = await _vincularOperacionesConDetalles(
        operacionesData,
        detallesData,
      );

      final processedResult = await _processAndSaveOperaciones(
        operacionesConDetalles,
      );

      _ultimasOperaciones = processedResult;

      debugPrint('FIN DE DESCARGA');
      return SyncResult(
        exito: true,
        mensaje: 'Operaciones sincronizadas correctamente',
        itemsSincronizados: processedResult.length,
        totalEnAPI: processedResult.length,
      );
    } catch (e) {
      _ultimasOperaciones = [];
      debugPrint('FIN DE DESCARGA CON ERROR: $e');

      // Manejo centralizado de excepciones
      await ErrorLogService.manejarExcepcion(
        e,
        null,
        '/api/getOperacionComercial',
        null, // No tenemos fácil acceso al userId numérico aquí, solo employeeId string
        _tableName,
      );

      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

  static Future<SyncResult> obtenerOperacionesPorVendedor(String employeeId) {
    return obtenerOperaciones(employeeId: employeeId);
  }

  static Future<SyncResult> obtenerOperacionesPorCliente(int partnerId) {
    return obtenerOperaciones(partnerId: partnerId);
  }

  static Future<SyncResult> obtenerOperacionesPorTipo(String tipo) {
    return obtenerOperaciones(tipo: tipo);
  }

  static Future<String?> obtenerOdooName(String adaSequence) async {
    try {
      final queryParams = {'adaSequence': adaSequence};

      final response = await _makeHttpRequest('/api/getOdooName', queryParams);

      if (!_isSuccessStatusCode(response.statusCode)) {
        return null;
      }

      final body = jsonDecode(response.body);

      // Si recibimos un mapa, buscamos la key 'odooName' o 'name'
      if (body is Map) {
        if (body.containsKey('odooName')) return body['odooName']?.toString();
        if (body.containsKey('name')) return body['name']?.toString();
        if (body.containsKey('data'))
          return body['data']?.toString(); // A veces viene en data
      }
      // Si es un string simple, asumimos que es el nombre
      else if (body is String) {
        return body;
      }

      return null;
    } catch (e) {
      debugPrint('Error obteniendo odooName: $e');
      return null;
    }
  }

  static Future<http.Response> _makeHttpRequest(
    String endpoint,
    Map<String, String> queryParams,
  ) async {
    final baseUrl = await BaseSyncService.getBaseUrl();
    final uri = Uri.parse(
      '$baseUrl$endpoint',
    ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    return await MonitoredHttpClient.get(
      url: uri,
      headers: BaseSyncService.headers,
      timeout: BaseSyncService.timeout,
    );
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
    final responseBody = response.body;
    return await Isolate.run(() {
      try {
        final decoded = jsonDecode(responseBody);

        if (decoded is Map) {
          final responseMap = Map<String, dynamic>.from(decoded);

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
        } else if (decoded is List) {
          return decoded;
        }

        return [];
      } catch (e) {
        throw Exception('Error parseando respuesta del servidor: $e');
      }
    });
  }

  static Future<List<Map<String, dynamic>>> _vincularOperacionesConDetalles(
    List<dynamic> operacionesData,
    List<dynamic> detallesData,
  ) async {
    final operacionesConDetalles = <Map<String, dynamic>>[];

    final todosLosDetalles = detallesData
        .where((d) => d is Map)
        .map((d) => Map<String, dynamic>.from(d as Map))
        .toList();

    final detallesPorOperacion = <int, List<Map<String, dynamic>>>{};
    for (final detalleMap in todosLosDetalles) {
      // Intentar obtener el ID de la operación de varias formas
      dynamic operacionIdRaw;

      // 1. Estructura anidada: operacionComercial: { id: 1 }
      if (detalleMap['operacionComercial'] is Map) {
        operacionIdRaw = detalleMap['operacionComercial']['id'];
      }

      // 2. ID directo camelCase: operacionComercialId: 1
      if (operacionIdRaw == null) {
        operacionIdRaw = detalleMap['operacionComercialId'];
      }

      // 3. ID directo snake_case: operacion_comercial_id: 1
      if (operacionIdRaw == null) {
        operacionIdRaw = detalleMap['operacion_comercial_id'];
      }

      // 4. ID directo simple: operacionComercial: 1
      if (operacionIdRaw == null && detalleMap['operacionComercial'] is! Map) {
        operacionIdRaw = detalleMap['operacionComercial'];
      }

      final operacionId = _parseIntSafely(operacionIdRaw);
      final tieneParent = detalleMap['parentDetalle'] != null;

      if (operacionId != null && !tieneParent) {
        if (!detallesPorOperacion.containsKey(operacionId)) {
          detallesPorOperacion[operacionId] = [];
        }
        detallesPorOperacion[operacionId]!.add(detalleMap);
      }
    }

    for (final operacion in operacionesData) {
      if (operacion is Map) {
        final operacionMap = Map<String, dynamic>.from(operacion);
        final operacionId = operacionMap['id'];

        operacionMap['detalles'] = detallesPorOperacion[operacionId] ?? [];
        operacionMap['todosLosDetalles'] = todosLosDetalles;

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
        operacionesInvalidas++;
        debugPrint('Error procesando operación: $e');
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
      debugPrint(
        'Se saltaron $operacionesInvalidas operaciones con datos incompletos',
      );
    }

    return operacionesParaGuardar;
  }

  static Future<Map<String, dynamic>> _mapApiToLocalFormat(
    Map<String, dynamic> apiOperacion,
  ) async {
    final partnerId = _parseIntSafely(apiOperacion['partnerId']);
    final tipo = apiOperacion['tipo']?.toString();

    if (partnerId == null || tipo == null || tipo.trim().isEmpty) {
      throw Exception('Operación sin datos requeridos (partnerId o tipo)');
    }

    final operacionServerId = _parseIntSafely(apiOperacion['id']);
    if (operacionServerId == null) {
      throw Exception('Operación sin ID del servidor');
    }

    int? usuarioId = _parseIntSafely(apiOperacion['creationUser']);
    if (usuarioId == null && apiOperacion['usuario'] is Map) {
      usuarioId = _parseIntSafely(apiOperacion['usuario']['id']);
    }

    final operacionLocal = {
      'id': operacionServerId.toString(),
      'cliente_id': partnerId,
      'tipo_operacion': tipo,
      'fecha_creacion': _parseFechaServerToLocal(apiOperacion['creationDate']),
      'fecha_retiro': apiOperacion['fechaRetiro']?.toString(),
      'total_productos': 0,
      'usuario_id': usuarioId,
      'server_id': operacionServerId,
      'sync_status': 'migrado',
      'employee_id': apiOperacion['employeeId']?.toString(),
      'sync_error': apiOperacion['errorText']?.toString(),
      'synced_at': DateTime.now().toIso8601String(),
      'sync_retry_count': 0,
      'odoo_name': apiOperacion['odooName']?.toString(),
      'ada_sequence': apiOperacion['adaSequence']?.toString(),
      'latitud': _parseDoubleSafely(apiOperacion['latitud']),
      'longitud': _parseDoubleSafely(apiOperacion['longitud']),
    };

    final todosLosDetalles =
        apiOperacion['todosLosDetalles'] as List<Map<String, dynamic>>? ?? [];

    final detalles = <Map<String, dynamic>>[];
    if (apiOperacion.containsKey('detalles') &&
        apiOperacion['detalles'] is List) {
      final detallesApi = apiOperacion['detalles'] as List;

      for (int i = 0; i < detallesApi.length; i++) {
        if (detallesApi[i] is Map) {
          final detalleMap = Map<String, dynamic>.from(detallesApi[i]);
          final detalleMapeado = await _mapDetalleToLocalFormat(
            detalleMap,
            operacionLocal['id'] as String,
            i + 1,
            todosLosDetalles,
          );
          detalles.add(detalleMapeado);
        }
      }
    }

    operacionLocal['total_productos'] = detalles.length;
    operacionLocal['detalles'] = detalles;

    return operacionLocal;
  }

  static String _parseFechaServerToLocal(dynamic fechaServer) {
    if (fechaServer == null) return DateTime.now().toIso8601String();

    try {
      String fechaStr = fechaServer.toString();

      // Si la fecha no tiene indicador de zona horaria (Z o +/-), asumimos UTC
      // Muchas APIs devuelven "2023-10-27T17:05:00" significando UTC
      if (!fechaStr.endsWith('Z') &&
          !fechaStr.contains(RegExp(r'[+\-]\d{2}:\d{2}'))) {
        fechaStr += 'Z';
      }

      final fechaUtc = DateTime.parse(fechaStr);
      final fechaLocal = fechaUtc.toLocal();

      return fechaLocal.toIso8601String();
    } catch (e) {
      // Si falla el parseo, devolver la fecha original o actual
      return fechaServer.toString();
    }
  }

  static Future<Map<String, dynamic>> _mapDetalleToLocalFormat(
    Map<String, dynamic> apiDetalle,
    String operacionId,
    int orden,
    List<Map<String, dynamic>> todosLosDetalles,
  ) async {
    // Intentar obtener productId (camelCase, snake_case o español)
    dynamic productIdRaw = apiDetalle['productId'];
    if (productIdRaw == null) productIdRaw = apiDetalle['product_id'];
    if (productIdRaw == null) productIdRaw = apiDetalle['productoId'];
    if (productIdRaw == null)
      productIdRaw = apiDetalle['producto_id']; // Por si acaso

    final productId = _parseIntSafely(productIdRaw);

    int? productoReemplazoId;

    final detalleServerId = _parseIntSafely(apiDetalle['id']);
    if (detalleServerId == null) {
      throw Exception('Detalle sin ID del servidor');
    }

    final detalleReemplazo = todosLosDetalles.firstWhere(
      (d) =>
          d['parentDetalle'] != null &&
          _parseIntSafely(d['parentDetalle']['id']) == detalleServerId,
      orElse: () => <String, dynamic>{},
    );

    if (detalleReemplazo.isNotEmpty) {
      productoReemplazoId = _parseIntSafely(detalleReemplazo['productId']);
    }

    return {
      'id': detalleServerId.toString(),
      'operacion_comercial_id': operacionId,
      'producto_id': productId,
      'cantidad': _parseDoubleSafely(apiDetalle['cantidad']),
      'ticket': apiDetalle['ticket']?.toString(),
      'precio_unitario': 0.0,
      'subtotal': 0.0,
      'orden': orden,
      'fecha_creacion': DateTime.now().toIso8601String(),
      'producto_reemplazo_id': productoReemplazoId,
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

  Future<Map<String, int>> sincronizarOperacionesPendientes(
    int usuarioId,
  ) async {
    debugPrint(
      '🔄 [SYNC] Iniciando sincronización de operaciones pendientes...',
    );
    int operacionesExitosas = 0;
    int totalFallidas = 0;

    try {
      final operacionesCreadas = await _operacionRepository
          .obtenerOperacionesPendientes();
      debugPrint(
        '🔍 [SYNC] Operaciones pendientes (creado): ${operacionesCreadas.length}',
      );

      final operacionesError = await _operacionRepository
          .obtenerOperacionesConError();
      debugPrint(
        '🔍 [SYNC] Operaciones con error (antes de filtrar): ${operacionesError.length}',
      );

      final operacionesErrorListas =
          await _filtrarOperacionesListasParaReintento(operacionesError);
      debugPrint(
        '🔍 [SYNC] Operaciones listas para reintentar: ${operacionesErrorListas.length}',
      );

      final todasLasOperaciones = [
        ...operacionesCreadas,
        ...operacionesErrorListas,
      ];

      debugPrint(
        '📊 [SYNC] Total de operaciones a procesar: ${todasLasOperaciones.length}',
      );

      final operacionesAProcesar = todasLasOperaciones.take(20);
      debugPrint(
        '📤 [SYNC] Procesando ${operacionesAProcesar.length} operaciones',
      );

      for (final operacion in operacionesAProcesar) {
        debugPrint(
          '🔹 [SYNC] Intentando operación ${operacion.id} (intento ${operacion.syncRetryCount + 1}/${maxIntentos})',
        );
        try {
          await _sincronizarOperacionIndividual(operacion, usuarioId);
          operacionesExitosas++;
          debugPrint(
            '✅ [SYNC] Operación ${operacion.id} sincronizada exitosamente',
          );
        } catch (e) {
          totalFallidas++;
          debugPrint('❌ [SYNC] Error en operación ${operacion.id}: $e');

          // Marcar la operación como error en la BD
          if (operacion.id != null) {
            try {
              await _operacionRepository.marcarComoError(
                operacion.id!,
                e.toString().replaceAll('Exception: ', ''),
              );
            } catch (repoError) {
              // Si falla marcar como error, solo logueamos
              debugPrint('⚠️ Error marcando operación como error: $repoError');
            }
          }
        }

        await Future.delayed(Duration(milliseconds: 500));
      }

      debugPrint(
        '✅ [SYNC] Resumen: ${operacionesExitosas} exitosas | ${totalFallidas} fallidas',
      );

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

      debugPrint(
        '📝 [SYNC] Operación $operacionId: intento $numeroIntento de $maxIntentos',
      );

      if (numeroIntento > maxIntentos) {
        debugPrint('⛔ [SYNC] Máximo de intentos alcanzado para $operacionId');
        await _operacionRepository.marcarComoError(
          operacionId,
          'Máximo de intentos alcanzado ($maxIntentos)',
        );
        return;
      }
      await _actualizarIntentoSincronizacion(operacionId, numeroIntento);
      debugPrint('🚀 [SYNC] Enviando operación $operacionId al servidor...');

      final serverResponse =
          await OperacionesComercialesPostService.enviarOperacion(operacion);
      debugPrint('✅ [SYNC] Operación $operacionId enviada exitosamente');

      // Parsear respuesta del servidor para obtener odooName y adaSequence
      String? odooName;
      String? adaSequence;

      if (serverResponse.resultJson != null) {
        debugPrint('📦 [SYNC] Parseando respuesta del servidor...');
        final parsedData =
            OperacionesComercialesPostService.parsearRespuestaJson(
              serverResponse.resultJson,
            );
        odooName = parsedData['odooName'];
        adaSequence = parsedData['adaSequence'];
        debugPrint(
          '📦 [SYNC] Parsed - odooName: $odooName, adaSequence: $adaSequence',
        );
      }

      // Marcar como migrado en la BD
      await _operacionRepository.marcarComoMigrado(
        operacionId,
        null,
        odooName: odooName,
        adaSequence: adaSequence,
      );
      debugPrint('✅ [SYNC] Operación $operacionId marcada como migrada');
    } catch (e) {
      rethrow;
    }
  }

  Future<List<OperacionComercial>> _filtrarOperacionesListasParaReintento(
    List<OperacionComercial> operacionesError,
  ) async {
    final operacionesListas = <OperacionComercial>[];
    final ahora = DateTime.now();

    debugPrint(
      '🔍 [FILTER] Filtrando ${operacionesError.length} operaciones con error...',
    );

    for (final operacion in operacionesError) {
      try {
        final intentos = operacion.syncRetryCount;
        debugPrint(
          '🔍 [FILTER] Operación ${operacion.id}: $intentos intentos de $maxIntentos',
        );

        if (intentos >= maxIntentos) {
          debugPrint(
            '⛔ [FILTER] Operación ${operacion.id} excede max intentos',
          );
          continue;
        }

        if (operacion.syncedAt == null) {
          debugPrint(
            '✅ [FILTER] Operación ${operacion.id} sin syncedAt, agregando',
          );
          operacionesListas.add(operacion);
          continue;
        }

        // Reintento simple cada 1 minuto (sin backoff exponencial)
        final tiempoProximoIntento = operacion.syncedAt!.add(
          const Duration(minutes: 1),
        );

        final tiempoRestante = tiempoProximoIntento.difference(ahora);
        debugPrint(
          '⏱️ [FILTER] Operación ${operacion.id}: tiempo restante ${tiempoRestante.inSeconds}s',
        );

        if (ahora.isAfter(tiempoProximoIntento)) {
          debugPrint(
            '✅ [FILTER] Operación ${operacion.id} lista para reintentar',
          );
          operacionesListas.add(operacion);
        } else {
          debugPrint(
            '⏸️ [FILTER] Operación ${operacion.id} aún no es tiempo (faltan ${tiempoRestante.inSeconds}s)',
          );
        }
      } catch (e) {
        debugPrint('❌ [FILTER] Error procesando operación ${operacion.id}: $e');
        operacionesListas.add(operacion);
      }
    }

    debugPrint(
      '✅ [FILTER] Resultado: ${operacionesListas.length} operaciones listas',
    );

    return operacionesListas;
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

  static void iniciarSincronizacionAutomatica(int usuarioId) {
    if (_syncActivo && _usuarioActual == usuarioId) {
      return;
    }

    detenerSincronizacionAutomatica();

    _usuarioActual = usuarioId;
    _syncActivo = true;

    debugPrint(
      '⏰ [TIMER] Iniciando timer automático para usuario $usuarioId (cada ${intervaloTimer.inMinutes} min)',
    );

    _syncTimer = Timer.periodic(intervaloTimer, (timer) async {
      await _ejecutarSincronizacionAutomatica();
    });

    // Timer independiente para OdooName (cada 30 min)
    _odooNameTimer = Timer.periodic(intervaloOdooName, (timer) async {
      if (!_syncActivo || _usuarioActual == null) return;
      final service = OperacionComercialSyncService();
      await service.sincronizarOdooNamesPendientes();
    });

    Timer(const Duration(seconds: 15), () async {
      debugPrint(
        '⏰ [TIMER] Ejecutando primera sincronización (15s después del login)',
      );
      await _ejecutarSincronizacionAutomatica();
    });
  }

  static void detenerSincronizacionAutomatica() {
    if (_syncTimer != null) {
      _syncTimer!.cancel();
      _syncTimer = null;
    }
    if (_odooNameTimer != null) {
      _odooNameTimer!.cancel();
      _odooNameTimer = null;
    }
    _syncActivo = false;
    _syncEnProgreso = false;
    _usuarioActual = null;
  }

  static Future<void> _ejecutarSincronizacionAutomatica() async {
    if (_syncEnProgreso || !_syncActivo || _usuarioActual == null) {
      if (_syncEnProgreso)
        debugPrint('⏸️ [TIMER] Sync ya en progreso, saltando...');
      if (!_syncActivo) debugPrint('⏸️ [TIMER] Sync no está activo');
      if (_usuarioActual == null)
        debugPrint('⏸️ [TIMER] Usuario no establecido');
      return;
    }

    debugPrint('⏰ [TIMER] Ejecutando sincronización automática...');

    _syncEnProgreso = true;

    try {
      final conexion = await BaseSyncService.testConnection();
      if (!conexion.exito) {
        debugPrint('❌ [TIMER] Sin conexión, saltando sincronización');
        return;
      }

      debugPrint('✅ [TIMER] Conexión OK, sincronizando operaciones...');

      final service = OperacionComercialSyncService();
      await service.sincronizarOperacionesPendientes(_usuarioActual!);

      // OdooName se sincroniza en su propio timer independiente
    } catch (e) {
    } finally {
      _syncEnProgreso = false;
    }
  }

  Future<void> sincronizarOdooNamesPendientes() async {
    try {
      // DEBUG: Log para verificar que el ciclo corre
      // debugPrint('Verificando Odoo Names pendientes...');

      final operaciones = await _operacionRepository
          .obtenerOperacionesSinOdooName();

      if (operaciones.isEmpty) {
        // debugPrint('No se encontraron operaciones sin Odoo Name.');
        return;
      }

      debugPrint(
        '🔍 [OdooName Sync] Encontradas ${operaciones.length} operaciones sin Odoo Name. Iniciando sincronización...',
      );

      for (final operacion in operaciones) {
        if (operacion.adaSequence == null) {
          debugPrint(
            '⚠️ [OdooName Sync] Operación ${operacion.id} ignorada: adaSequence es nulo.',
          );
          continue;
        }

        try {
          debugPrint(
            '🔄 [OdooName Sync] Consultando para AdaSequence: ${operacion.adaSequence}',
          );
          final odooName = await obtenerOdooName(operacion.adaSequence!);

          if (odooName != null && odooName.isNotEmpty) {
            await _operacionRepository.actualizarOdooName(
              operacion.id!,
              odooName,
            );
            debugPrint(
              '✅ [OdooName Sync] ACTUALIZADO EXITOSAMENTE: ${operacion.adaSequence} -> $odooName',
            );
          } else {
            debugPrint(
              '❌ [OdooName Sync] No se encontró Odoo Name para ${operacion.adaSequence} (Respuesta nula o vacía)',
            );
          }
        } catch (e) {
          debugPrint(
            '🔥 [OdooName Sync] Excepción obteniendo Odoo Name para ${operacion.adaSequence}: $e',
          );
        }

        // Pequeña pausa para no saturar
        await Future.delayed(const Duration(milliseconds: 200));
      }
    } catch (e) {
      debugPrint('🔥 [OdooName Sync] Error general en el proceso: $e');
    }
  }
}
