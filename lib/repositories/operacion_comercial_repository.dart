// lib/repositories/operacion_comercial_repository.dart
import 'package:ada_app/models/operaciones_comerciales/operacion_comercial.dart';
import 'package:ada_app/models/operaciones_comerciales/operacion_comercial_detalle.dart';
import 'package:ada_app/models/operaciones_comerciales/enums/tipo_operacion.dart';
import 'package:ada_app/models/operaciones_comerciales/enums/estado_operacion.dart';
import 'package:ada_app/services/post/operaciones_comerciales_post_service.dart';
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
  Future<List<OperacionComercial>> obtenerOperacionesPorClienteYTipo(int clienteId, TipoOperacion tipo);
  Future<void> eliminarOperacion(String id);
  Future<void> sincronizarOperacionesPendientes();
  Future<void> marcarPendienteSincronizacion(String operacionId);
  Future<List<OperacionComercial>> obtenerOperacionesPendientes();
}

/// Implementación usando BaseRepository
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
  // IMPLEMENTACIÓN DE LA INTERFACE
  // ═══════════════════════════════════════════════════════════════════

  @override
  Future<String> crearOperacion(OperacionComercial operacion) async {
    try {
      _logger.i('📝 Creando operación comercial...');

      final operacionId = operacion.id ?? _uuid.v4();
      final now = DateTime.now();

      final operacionConId = operacion.copyWith(
        id: operacionId,
        fechaCreacion: now,
        estado: EstadoOperacion.borrador,
        syncStatus: 'creado',
        totalProductos: operacion.detalles.length,
      );

      final db = await dbHelper.database;

      await db.transaction((txn) async {
        // 1. Insertar operación principal
        await txn.insert(tableName, operacionConId.toMap());
        _logger.i('✅ Operación insertada con ID: $operacionId');

        // 2. Insertar detalles
        for (int i = 0; i < operacion.detalles.length; i++) {
          final detalle = operacion.detalles[i].copyWith(
            id: _uuid.v4(),
            operacionComercialId: operacionId,
            orden: i + 1,
            fechaCreacion: now,
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

      final operacionActualizada = operacion.copyWith(
        estado: EstadoOperacion.pendiente,
        syncStatus: 'creado',
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
      final operacionMaps = await dbHelper.consultar(
        tableName,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (operacionMaps.isEmpty) return null;

      final detallesMaps = await dbHelper.consultar(
        'operacion_comercial_detalle',
        where: 'operacion_comercial_id = ?',
        whereArgs: [id],
        orderBy: 'orden ASC',
      );

      final detalles = detallesMaps
          .map((map) => OperacionComercialDetalle.fromMap(map))
          .toList();

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
        whereArgs: [tipo.valor],
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
        // 1. Eliminar detalles (CASCADE debería hacerlo automáticamente)
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
          final operacionCompleta = await obtenerOperacionPorId(operacion.id!);
          if (operacionCompleta != null) {
            await _enviarOperacionAlServidor(operacionCompleta);
            _logger.i('✅ Operación ${operacionCompleta.id} sincronizada');
          }

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
          'sync_status': 'creado',
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
        where: 'sync_status = ?',
        whereArgs: ['creado'],
        orderBy: getDefaultOrderBy(),
      );

      return operacionesMaps.map((map) => fromMap(map)).toList();

    } catch (e) {
      _logger.e('❌ Error obteniendo operaciones pendientes: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // MÉTODOS ESPECÍFICOS
  // ═══════════════════════════════════════════════════════════════════

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

  Future<List<OperacionComercial>> obtenerBorradores() async {
    return await obtenerOperacionesPorEstado(EstadoOperacion.borrador);
  }

  Future<List<OperacionComercial>> obtenerOperacionesConError() async {
    try {
      final operacionesMaps = await dbHelper.consultar(
        tableName,
        where: 'sync_status = ?',
        whereArgs: ['error'],
        orderBy: getDefaultOrderBy(),
      );

      return operacionesMaps.map((map) => fromMap(map)).toList();

    } catch (e) {
      _logger.e('❌ Error obteniendo operaciones con error: $e');
      return [];
    }
  }

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
  // MÉTODOS PRIVADOS - SINCRONIZACIÓN
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _enviarOperacionAlServidor(OperacionComercial operacion) async {
    _logger.i('📤 Enviando operación ${operacion.id} al servidor...');

    try {
      final resultado = await OperacionesComercialesPostService.enviarOperacion(operacion);

      if (resultado['exito'] == true) {
        _logger.i('✅ Operación enviada exitosamente al servidor');

        if (resultado['id'] != null) {
          await _marcarComoMigrado(operacion.id!, resultado['id']);
        } else {
          await _marcarComoMigrado(operacion.id!, null);
        }
      } else {
        final mensajeError = resultado['mensaje'] ?? 'Error desconocido del servidor';
        throw Exception(mensajeError);
      }

    } catch (e) {
      _logger.e('❌ Error enviando al servidor: $e');
      rethrow;
    }
  }

  Future<void> _marcarComoMigrado(String operacionId, dynamic serverId) async {
    try {
      final now = DateTime.now();

      await dbHelper.actualizar(
        tableName,
        {
          'sync_status': 'migrado',
          'synced_at': now.toIso8601String(),
          'server_id': serverId,
          'sync_error': null,
        },
        where: 'id = ?',
        whereArgs: [operacionId],
      );

      _logger.i('✅ Operación $operacionId migrada${serverId != null ? ' con server ID: $serverId' : ''}');

    } catch (e) {
      _logger.e('❌ Error marcando como migrado: $e');
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
          'sync_error': mensajeError,
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

  void _sincronizarEnBackground(String operacionId) {
    Future.microtask(() async {
      try {
        final operacion = await obtenerOperacionPorId(operacionId);
        if (operacion != null) {
          await _enviarOperacionAlServidor(operacion);
        }
      } catch (e) {
        await _marcarComoError(operacionId, e.toString());
        _logger.e('❌ Error en sincronización background: $e');
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════════
  // ESTADÍSTICAS
  // ═══════════════════════════════════════════════════════════════════

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