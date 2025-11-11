// lib/repositories/operacion_comercial_repository.dart
import 'package:ada_app/models/operaciones_comerciales/operacion_comercial.dart';
import 'package:ada_app/models/operaciones_comerciales/operacion_comercial_detalle.dart';
import 'package:ada_app/models/operaciones_comerciales/enums/tipo_operacion.dart';
import 'package:ada_app/models/operaciones_comerciales/enums/estado_operacion.dart';
import 'base_repository.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

/// Interface para el repository de operaciones comerciales
abstract class OperacionComercialRepository {
  Future<String> crearOperacion(OperacionComercial operacion);
  Future<void> actualizarOperacion(OperacionComercial operacion);
  Future<OperacionComercial?> obtenerOperacionPorId(String id);
  Future<List<OperacionComercial>> obtenerOperacionesPorCliente(int clienteId);
  Future<List<OperacionComercial>> obtenerOperacionesPorTipo(TipoOperacion tipo);
  Future<List<OperacionComercial>> obtenerOperacionesPorClienteYTipo(int clienteId, TipoOperacion tipo); // ✅ AGREGAR ESTA LÍNEA
  Future<void> eliminarOperacion(String id);
  Future<void> sincronizarOperacionesPendientes();
  Future<void> marcarPendienteSincronizacion(String operacionId);
  Future<List<OperacionComercial>> obtenerOperacionesPendientes();
}

/// Implementación usando tu BaseRepository existente + tu modelo real
class OperacionComercialRepositoryImpl extends BaseRepository<OperacionComercial>
    implements OperacionComercialRepository {

  final Logger _logger = Logger();
  final Uuid _uuid = Uuid();

  @override
  String get tableName => 'operacion_comercial';

  @override
  OperacionComercial fromMap(Map<String, dynamic> map) => OperacionComercial.fromMap(map);

  @override
  Map<String, dynamic> toMap(OperacionComercial operacion) => operacion.toMap();

  @override
  String getDefaultOrderBy() => 'fecha_creacion DESC';

  @override
  String getBuscarWhere() => 'cliente_id = ? OR observaciones LIKE ?';

  @override
  List<dynamic> getBuscarArgs(String query) {
    final searchTerm = '%${query.toLowerCase()}%';
    final clienteId = int.tryParse(query) ?? 0;
    return [clienteId, searchTerm];
  }

  @override
  String getEntityName() => 'OperacionComercial';

  // ═══════════════════════════════════════════════════════════════════
  // IMPLEMENTACIÓN DE LA INTERFACE - USANDO TU MODELO REAL
  // ═══════════════════════════════════════════════════════════════════

  @override
  Future<String> crearOperacion(OperacionComercial operacion) async {
    try {
      _logger.i('📝 Creando operación comercial...');

      // Generar UUID si no tiene ID
      final operacionId = operacion.id ?? _uuid.v4();
      final now = DateTime.now();

      // Usar tu modelo completo con todos los campos
      final operacionConId = operacion.copyWith(
        id: operacionId,
        fechaCreacion: now,
        estado: EstadoOperacion.borrador,
        estaSincronizado: false,
        syncStatus: 'pending',
        intentosSync: 0,
        totalProductos: operacion.detalles.length,
      );

      final db = await dbHelper.database;

      await db.transaction((txn) async {
        // 1. Insertar operación principal usando tu toMap()
        await txn.insert(tableName, operacionConId.toMap());
        _logger.i('✅ Operación insertada con ID: $operacionId');

        // 2. Insertar detalles en tabla separada
        for (int i = 0; i < operacion.detalles.length; i++) {
          final detalle = operacion.detalles[i].copyWith(
            id: _uuid.v4(),
            operacionComercialId: operacionId,
            orden: i + 1,
            fechaCreacion: now,
            estaSincronizado: false,
          );

          await txn.insert('operacion_comercial_detalle', detalle.toMap());
        }

        _logger.i('✅ ${operacion.detalles.length} detalles insertados');
      });

      // 3. Marcar para sincronización
      await marcarPendienteSincronizacion(operacionId);

      // 4. Intentar sincronizar inmediatamente (background)
      _sincronizarEnBackground(operacionId);

      _logger.i('✅ Operación creada exitosamente: $operacionId');
      return operacionId;

    } catch (e) {
      _logger.e('❌ Error creando operación: $e');
      rethrow;
    }
  }

  @override
  Future<void> actualizarOperacion(OperacionComercial operacion) async {
    try {
      _logger.i('🔄 Actualizando operación ${operacion.id}...');

      // Usar copyWith de tu modelo con los campos correctos
      final operacionActualizada = operacion.copyWith(
        estado: EstadoOperacion.pendiente,
        estaSincronizado: false,
        syncStatus: 'pending',
        totalProductos: operacion.detalles.length,
      );

      final db = await dbHelper.database;

      await db.transaction((txn) async {
        // 1. Actualizar operación principal
        await txn.update(
          tableName,
          operacionActualizada.toMap(),
          where: 'id = ?',
          whereArgs: [operacion.id],
        );

        // 2. Eliminar detalles anteriores
        await txn.delete(
          'operacion_comercial_detalle',
          where: 'operacion_comercial_id = ?',
          whereArgs: [operacion.id],
        );

        // 3. Insertar nuevos detalles
        for (int i = 0; i < operacion.detalles.length; i++) {
          final detalleOriginal = operacion.detalles[i];
          final detalle = detalleOriginal.copyWith(
            id: detalleOriginal.id ?? _uuid.v4(),
            operacionComercialId: operacion.id!,
            orden: i + 1,
            fechaCreacion: DateTime.now(),
            estaSincronizado: false,
          );

          await txn.insert('operacion_comercial_detalle', detalle.toMap());
        }
      });

      await marcarPendienteSincronizacion(operacion.id!);
      _sincronizarEnBackground(operacion.id!);

      _logger.i('✅ Operación actualizada exitosamente');

    } catch (e) {
      _logger.e('❌ Error actualizando operación: $e');
      rethrow;
    }
  }

  @override
  Future<OperacionComercial?> obtenerOperacionPorId(String id) async {
    try {
      // 1. Obtener operación principal
      final operacionMaps = await dbHelper.consultar(
        tableName,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (operacionMaps.isEmpty) return null;

      // 2. Obtener detalles
      final detallesMaps = await dbHelper.consultar(
        'operacion_comercial_detalle',
        where: 'operacion_comercial_id = ?',
        whereArgs: [id],
        orderBy: 'orden ASC',
      );

      final detalles = detallesMaps
          .map((map) => OperacionComercialDetalle.fromMap(map))
          .toList();

      // 3. Crear operación con detalles usando tu fromMap
      final operacion = fromMap(operacionMaps.first);
      return operacion.copyWith(detalles: detalles);

    } catch (e) {
      _logger.e('❌ Error obteniendo operación $id: $e');
      return null;
    }
  }

  @override
  Future<List<OperacionComercial>> obtenerOperacionesPorCliente(int clienteId) async {
    try {
      final operacionesMaps = await dbHelper.consultar(
        tableName,
        where: 'cliente_id = ?',
        whereArgs: [clienteId],
        orderBy: getDefaultOrderBy(),
      );

      final operaciones = <OperacionComercial>[];

      // Obtener detalles para cada operación
      for (final operacionMap in operacionesMaps) {
        final operacionId = operacionMap['id'];

        final detallesMaps = await dbHelper.consultar(
          'operacion_comercial_detalle',
          where: 'operacion_comercial_id = ?',
          whereArgs: [operacionId],
          orderBy: 'orden ASC',
        );

        final detalles = detallesMaps
            .map((map) => OperacionComercialDetalle.fromMap(map))
            .toList();

        final operacion = fromMap(operacionMap).copyWith(detalles: detalles);
        operaciones.add(operacion);
      }

      return operaciones;

    } catch (e) {
      _logger.e('❌ Error obteniendo operaciones del cliente $clienteId: $e');
      return [];
    }
  }

  @override
  Future<List<OperacionComercial>> obtenerOperacionesPorTipo(TipoOperacion tipo) async {
    try {
      final operacionesMaps = await dbHelper.consultar(
        tableName,
        where: 'tipo_operacion = ?',
        whereArgs: [tipo.valor], // Usar .valor de tu enum
        orderBy: getDefaultOrderBy(),
      );

      return operacionesMaps.map((map) => fromMap(map)).toList();

    } catch (e) {
      _logger.e('❌ Error obteniendo operaciones del tipo $tipo: $e');
      return [];
    }
  }

  @override
  Future<List<OperacionComercial>> obtenerOperacionesPorClienteYTipo(
      int clienteId,
      TipoOperacion tipo,
      ) async {
    try {
      _logger.i('📋 Obteniendo operaciones de cliente $clienteId tipo ${tipo.valor}');

      final operacionesMaps = await dbHelper.consultar(
        tableName,
        where: 'cliente_id = ? AND tipo_operacion = ?',
        whereArgs: [clienteId, tipo.valor],
        orderBy: getDefaultOrderBy(),
      );

      if (operacionesMaps.isEmpty) {
        _logger.d('No se encontraron operaciones');
        return [];
      }

      final operaciones = <OperacionComercial>[];

      // Obtener detalles para cada operación
      for (final operacionMap in operacionesMaps) {
        final operacionId = operacionMap['id'];

        final detallesMaps = await dbHelper.consultar(
          'operacion_comercial_detalle',
          where: 'operacion_comercial_id = ?',
          whereArgs: [operacionId],
          orderBy: 'orden ASC',
        );

        final detalles = detallesMaps
            .map((map) => OperacionComercialDetalle.fromMap(map))
            .toList();

        final operacion = fromMap(operacionMap).copyWith(detalles: detalles);
        operaciones.add(operacion);
      }

      _logger.i('✅ ${operaciones.length} operaciones obtenidas');
      return operaciones;

    } catch (e) {
      _logger.e('❌ Error obteniendo operaciones: $e');
      return [];
    }
  }

  @override
  Future<void> eliminarOperacion(String id) async {
    try {
      _logger.i('🗑️ Eliminando operación $id...');

      final db = await dbHelper.database;

      await db.transaction((txn) async {
        // 1. Eliminar detalles
        await txn.delete(
          'operacion_comercial_detalle',
          where: 'operacion_comercial_id = ?',
          whereArgs: [id],
        );

        // 2. Eliminar operación principal
        await txn.delete(
          tableName,
          where: 'id = ?',
          whereArgs: [id],
        );
      });

      _logger.i('✅ Operación eliminada exitosamente');

    } catch (e) {
      _logger.e('❌ Error eliminando operación: $e');
      rethrow;
    }
  }

  @override
  Future<void> sincronizarOperacionesPendientes() async {
    try {
      _logger.i('🔄 Sincronizando operaciones pendientes...');

      final operacionesPendientes = await obtenerOperacionesPendientes();

      if (operacionesPendientes.isEmpty) {
        _logger.i('✅ No hay operaciones pendientes');
        return;
      }

      _logger.i('📤 Sincronizando ${operacionesPendientes.length} operaciones...');

      for (final operacion in operacionesPendientes) {
        try {
          await _enviarOperacionAlServidor(operacion);
          await _marcarComoSincronizado(operacion.id!);
          _logger.i('✅ Operación ${operacion.id} sincronizada');

        } catch (e) {
          await _marcarComoError(operacion.id!, e.toString());
          _logger.e('❌ Error sincronizando ${operacion.id}: $e');
        }
      }

      _logger.i('✅ Sincronización completada');

    } catch (e) {
      _logger.e('❌ Error en sincronización: $e');
      rethrow;
    }
  }

  @override
  Future<void> marcarPendienteSincronizacion(String operacionId) async {
    try {
      await dbHelper.actualizar(
        tableName,
        {
          'sincronizado': 0,
          'sync_status': 'pending',
          'estado': EstadoOperacion.pendiente.valor,
        },
        where: 'id = ?',
        whereArgs: [operacionId],
      );

      _logger.i('⏳ Operación $operacionId marcada como pendiente');

    } catch (e) {
      _logger.e('❌ Error marcando como pendiente: $e');
      rethrow;
    }
  }

  @override
  Future<List<OperacionComercial>> obtenerOperacionesPendientes() async {
    try {
      final operacionesMaps = await dbHelper.consultar(
        tableName,
        where: 'sincronizado = ? OR sync_status = ?',
        whereArgs: [0, 'pending'],
        orderBy: getDefaultOrderBy(),
      );

      return operacionesMaps.map((map) => fromMap(map)).toList();

    } catch (e) {
      _logger.e('❌ Error obteniendo operaciones pendientes: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // MÉTODOS ESPECÍFICOS PARA TU MODELO
  // ═══════════════════════════════════════════════════════════════════

  /// Obtener operaciones por estado
  Future<List<OperacionComercial>> obtenerOperacionesPorEstado(EstadoOperacion estado) async {
    try {
      final operacionesMaps = await dbHelper.consultar(
        tableName,
        where: 'estado = ?',
        whereArgs: [estado.valor],
        orderBy: getDefaultOrderBy(),
      );

      return operacionesMaps.map((map) => fromMap(map)).toList();

    } catch (e) {
      _logger.e('❌ Error obteniendo operaciones por estado: $e');
      return [];
    }
  }

  /// Obtener borradores
  Future<List<OperacionComercial>> obtenerBorradores() async {
    return await obtenerOperacionesPorEstado(EstadoOperacion.borrador);
  }

  /// Obtener operaciones con errores
  Future<List<OperacionComercial>> obtenerOperacionesConError() async {
    try {
      final operacionesMaps = await dbHelper.consultar(
        tableName,
        where: 'estado = ? OR sync_status = ?',
        whereArgs: [EstadoOperacion.error.valor, 'error'],
        orderBy: getDefaultOrderBy(),
      );

      return operacionesMaps.map((map) => fromMap(map)).toList();

    } catch (e) {
      _logger.e('❌ Error obteniendo operaciones con error: $e');
      return [];
    }
  }

  /// Actualizar estado de operación
  Future<void> actualizarEstado(String operacionId, EstadoOperacion nuevoEstado) async {
    try {
      await dbHelper.actualizar(
        tableName,
        {
          'estado': nuevoEstado.valor,
        },
        where: 'id = ?',
        whereArgs: [operacionId],
      );

      _logger.i('✅ Estado de operación $operacionId actualizado a ${nuevoEstado.valor}');

    } catch (e) {
      _logger.e('❌ Error actualizando estado: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // MÉTODOS PRIVADOS Y UTILITARIOS
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _enviarOperacionAlServidor(OperacionComercial operacion) async {
    _logger.i('📤 Enviando operación ${operacion.id} al servidor...');

    try {
      // Incrementar intentos
      await _incrementarIntentosSync(operacion.id!);

      // TODO: Implementar integración real con tu API
      // Usar operacion.toJson() que ya está implementado en tu modelo

      // Simular envío por ahora
      await Future.delayed(const Duration(seconds: 1));

      /*
      final payload = operacion.toJson(); // Tu método ya implementado

      final response = await http.post(
        Uri.parse('https://tu-api.com/operaciones-comerciales'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = json.decode(response.body);
        final serverId = responseData['id'];

        // Marcar como sincronizado con server_id
        await _marcarComoSincronizadoConServerId(operacion.id!, serverId);
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
      */

      _logger.i('✅ Operación enviada al servidor (simulado)');

    } catch (e) {
      _logger.e('❌ Error enviando al servidor: $e');
      rethrow;
    }
  }

  Future<void> _marcarComoSincronizado(String operacionId) async {
    try {
      final now = DateTime.now();

      await dbHelper.actualizar(
        tableName,
        {
          'sincronizado': 1,
          'estado': EstadoOperacion.sincronizado.valor,
          'sync_status': 'success',
          'fecha_sincronizacion': now.toIso8601String(),
          'mensaje_error_sync': null,
        },
        where: 'id = ?',
        whereArgs: [operacionId],
      );

      _logger.i('✅ Operación $operacionId marcada como sincronizada');

    } catch (e) {
      _logger.e('❌ Error marcando como sincronizado: $e');
      rethrow;
    }
  }

  Future<void> _marcarComoError(String operacionId, String mensajeError) async {
    try {
      await dbHelper.actualizar(
        tableName,
        {
          'estado': EstadoOperacion.error.valor,
          'sync_status': 'error',
          'mensaje_error_sync': mensajeError,
          'ultimo_intento_sync': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [operacionId],
      );

      _logger.e('❌ Operación $operacionId marcada con error: $mensajeError');

    } catch (e) {
      _logger.e('❌ Error marcando como error: $e');
      rethrow;
    }
  }

  Future<void> _incrementarIntentosSync(String operacionId) async {
    try {
      final operacion = await obtenerOperacionPorId(operacionId);
      if (operacion != null) {
        await dbHelper.actualizar(
          tableName,
          {
            'intentos_sync': operacion.intentosSync + 1,
            'ultimo_intento_sync': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [operacionId],
        );
      }
    } catch (e) {
      _logger.w('⚠️ Error incrementando intentos: $e');
    }
  }

  Future<void> _marcarComoSincronizadoConServerId(String operacionId, int serverId) async {
    try {
      final now = DateTime.now();

      await dbHelper.actualizar(
        tableName,
        {
          'sincronizado': 1,
          'estado': EstadoOperacion.sincronizado.valor,
          'sync_status': 'success',
          'fecha_sincronizacion': now.toIso8601String(),
          'server_id': serverId,
          'mensaje_error_sync': null,
        },
        where: 'id = ?',
        whereArgs: [operacionId],
      );

      _logger.i('✅ Operación $operacionId sincronizada con server ID: $serverId');

    } catch (e) {
      _logger.e('❌ Error marcando como sincronizado: $e');
      rethrow;
    }
  }

  void _sincronizarEnBackground(String operacionId) {
    // Sincronización asíncrona sin bloquear UI
    Future.microtask(() async {
      try {
        final operacion = await obtenerOperacionPorId(operacionId);
        if (operacion != null) {
          await _enviarOperacionAlServidor(operacion);
          await _marcarComoSincronizado(operacionId);
        }
      } catch (e) {
        await _marcarComoError(operacionId, e.toString());
        _logger.e('❌ Error en sincronización background: $e');
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════════
  // ESTADÍSTICAS USANDO TU MODELO COMPLETO
  // ═══════════════════════════════════════════════════════════════════

  /// Obtener estadísticas completas
  Future<Map<String, dynamic>> obtenerEstadisticasCompletas() async {
    try {
      final stats = await obtenerEstadisticas();

      final pendientes = await obtenerOperacionesPendientes();
      final conError = await obtenerOperacionesConError();
      final borradores = await obtenerBorradores();

      final porTipo = <String, int>{};
      for (final tipo in TipoOperacion.values) {
        final operaciones = await obtenerOperacionesPorTipo(tipo);
        porTipo[tipo.displayName] = operaciones.length;
      }

      final porEstado = <String, int>{};
      for (final estado in EstadoOperacion.values) {
        final operaciones = await obtenerOperacionesPorEstado(estado);
        porEstado[estado.displayName] = operaciones.length;
      }

      return {
        ...stats,
        'operaciones_pendientes': pendientes.length,
        'operaciones_error': conError.length,
        'borradores': borradores.length,
        'por_tipo': porTipo,
        'por_estado': porEstado,
      };

    } catch (e) {
      _logger.e('❌ Error obteniendo estadísticas: $e');
      return {};
    }
  }
}