import 'package:ada_app/models/operaciones_comerciales/operacion_comercial.dart';
import 'package:ada_app/models/operaciones_comerciales/operacion_comercial_detalle.dart';
import 'package:ada_app/models/operaciones_comerciales/enums/tipo_operacion.dart';
import 'package:ada_app/services/post/operaciones_comerciales_post_service.dart';
import 'package:ada_app/services/error_log/error_log_service.dart';
import 'base_repository.dart';

import 'package:uuid/uuid.dart';

abstract class OperacionComercialRepository {
  Future<String> crearOperacion(OperacionComercial operacion);

  Future<OperacionComercial?> obtenerOperacionPorId(String id);
  Future<List<OperacionComercial>> obtenerOperacionesPorCliente(int clienteId);
  Future<List<OperacionComercial>> obtenerOperacionesPorTipo(
    TipoOperacion tipo,
  );
  Future<List<OperacionComercial>> obtenerOperacionesPorClienteYTipo(
    int clienteId,
    TipoOperacion tipo,
  );
  Future<void> eliminarOperacion(String id);

  Future<void> marcarPendienteSincronizacion(String operacionId);
  Future<List<OperacionComercial>> obtenerOperacionesPendientes();
}

class OperacionComercialRepositoryImpl
    extends BaseRepository<OperacionComercial>
    implements OperacionComercialRepository {
  final Uuid _uuid = Uuid();

  @override
  String get tableName => 'operacion_comercial';

  @override
  OperacionComercial fromMap(Map<String, dynamic> map) =>
      OperacionComercial.fromMap(map);

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

  @override
  Future<String> crearOperacion(OperacionComercial operacion) async {
    String? operacionId;
    try {
      operacionId = operacion.id ?? _uuid.v4();
      final now = DateTime.now();

      final operacionConId = operacion.copyWith(
        id: operacionId,
        fechaCreacion: now,
        syncStatus: 'creado',
        totalProductos: operacion.detalles.length,
      );

      final db = await dbHelper.database;
      await db.transaction((txn) async {
        await txn.insert(tableName, operacionConId.toMap());

        for (int i = 0; i < operacion.detalles.length; i++) {
          final detalle = operacion.detalles[i].copyWith(
            id: _uuid.v4(),
            operacionComercialId: operacionId,
            orden: i + 1,
            fechaCreacion: now,
          );

          await txn.insert('operacion_comercial_detalle', detalle.toMap());
        }
      });
      await marcarPendienteSincronizacion(operacionId);

      try {
        await OperacionesComercialesPostService.enviarOperacion(operacionConId);
        await marcarComoMigrado(operacionId, null);
      } catch (syncError) {
        await marcarComoError(
          operacionId,
          syncError.toString().replaceAll('Exception: ', ''),
        );
      }

      return operacionId;
    } catch (e) {
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
      return null;
    }
  }

  @override
  Future<List<OperacionComercial>> obtenerOperacionesPorCliente(
    int clienteId,
  ) async {
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
      return [];
    }
  }

  @override
  Future<List<OperacionComercial>> obtenerOperacionesPorTipo(
    TipoOperacion tipo,
  ) async {
    try {
      final operacionesMaps = await dbHelper.consultar(
        tableName,
        where: 'tipo_operacion = ?',
        whereArgs: [tipo.valor],
        orderBy: getDefaultOrderBy(),
      );

      return operacionesMaps.map((map) => fromMap(map)).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<OperacionComercial>> obtenerOperacionesPorClienteYTipo(
    int clienteId,
    TipoOperacion tipo,
  ) async {
    try {
      final operacionesMaps = await dbHelper.consultar(
        tableName,
        where: 'cliente_id = ? AND tipo_operacion = ?',
        whereArgs: [clienteId, tipo.valor],
        orderBy: getDefaultOrderBy(),
      );

      if (operacionesMaps.isEmpty) {
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

      return operaciones;
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> eliminarOperacion(String id) async {
    try {
      final db = await dbHelper.database;

      await db.transaction((txn) async {
        await txn.delete(
          'operacion_comercial_detalle',
          where: 'operacion_comercial_id = ?',
          whereArgs: [id],
        );

        await txn.delete(tableName, where: 'id = ?', whereArgs: [id]);
      });
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> marcarPendienteSincronizacion(String operacionId) async {
    try {
      await dbHelper.actualizar(
        tableName,
        {'sync_status': 'creado', 'sync_error': null},
        where: 'id = ?',
        whereArgs: [operacionId],
      );
    } catch (e) {
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
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // MÉTODOS ESPECÍFICOS
  // ═══════════════════════════════════════════════════════════════════

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
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // MÉTODOS PRIVADOS - SINCRONIZACIÓN
  // ═══════════════════════════════════════════════════════════════════

  Future<void> marcarComoMigrado(String operacionId, dynamic serverId) async {
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

      await ErrorLogService.marcarErroresComoResueltos(
        registroFailId: operacionId,
        tableName: tableName,
      );
    } catch (e) {
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // MÉTODOS PARA SISTEMA DE REINTENTOS AUTOMÁTICOS
  // ═══════════════════════════════════════════════════════════════════

  /// Actualiza el contador de intentos de sincronización
  Future<void> actualizarIntentoSync(
    String operacionId,
    int numeroIntento,
  ) async {
    try {
      await dbHelper.actualizar(
        tableName,
        {
          'sync_retry_count': numeroIntento,
          'synced_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [operacionId],
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> marcarComoError(String operacionId, String mensajeError) async {
    try {
      final operacionMaps = await dbHelper.consultar(
        tableName,
        where: 'id = ?',
        whereArgs: [operacionId],
        limit: 1,
      );

      int retryCount = 0;
      if (operacionMaps.isNotEmpty) {
        retryCount = operacionMaps.first['sync_retry_count'] as int? ?? 0;
      }

      await dbHelper.actualizar(
        tableName,
        {
          'sync_status': 'error',
          'sync_error': mensajeError,
          'synced_at': DateTime.now().toIso8601String(),
          'sync_retry_count': retryCount,
        },
        where: 'id = ?',
        whereArgs: [operacionId],
      );
    } catch (e) {
      rethrow;
    }
  }
}
