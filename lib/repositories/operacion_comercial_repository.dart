// lib/repositories/operacion_comercial_repository.dart
import 'dart:convert';

import 'package:ada_app/models/operaciones_comerciales/operacion_comercial.dart';
import 'package:ada_app/models/operaciones_comerciales/operacion_comercial_detalle.dart';
import 'package:ada_app/models/operaciones_comerciales/enums/tipo_operacion.dart';
import 'package:ada_app/services/post/operaciones_comerciales_post_service.dart';
import 'package:ada_app/services/error_log/error_log_service.dart';
import 'package:sqflite/sqflite.dart';
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
  Future<void> guardarOperacionesDesdeServidor(
    List<Map<String, dynamic>> operacionesData,
  );
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
  String getBuscarWhere() => 'cliente_id = ?';

  @override
  List<dynamic> getBuscarArgs(String query) {
    final clienteId = int.tryParse(query) ?? 0;
    return [clienteId];
  }

  @override
  String getEntityName() => 'OperacionComercial';

  Future<List<OperacionComercialDetalle>> _obtenerDetallesConCodigoBarras(
    String operacionId,
  ) async {
    try {
      final db = await dbHelper.database;

      final resultado = await db.rawQuery(
        '''
        SELECT 
          ocd.id,
          ocd.operacion_comercial_id,
          ocd.producto_id,
          ocd.cantidad,
          ocd.ticket,
          ocd.precio_unitario,
          ocd.subtotal,
          ocd.orden,
          ocd.fecha_creacion,
          ocd.producto_reemplazo_id,
          p.codigo_barras AS producto_codigo_barras,
          pr.codigo_barras AS producto_reemplazo_codigo_barras
        FROM operacion_comercial_detalle ocd
        LEFT JOIN productos p ON ocd.producto_id = p.id
        LEFT JOIN productos pr ON ocd.producto_reemplazo_id = pr.id
        WHERE ocd.operacion_comercial_id = ?
        ORDER BY ocd.orden ASC
      ''',
        [operacionId],
      );

      return resultado
          .map((map) => OperacionComercialDetalle.fromMap(map))
          .toList();
    } catch (e) {
      return [];
    }
  }

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
        final serverResponse =
            await OperacionesComercialesPostService.enviarOperacion(
              operacionConId,
            );

        String? odooName;
        String? adaSequence;

        if (serverResponse.resultJson != null) {
          print('DEBUG: ResultJson received: ${serverResponse.resultJson}');
          try {
            final jsonMap = jsonDecode(serverResponse.resultJson!);
            odooName =
                jsonMap['name'] as String? ?? jsonMap['odooName'] as String?;

            // Intentar varias claves posibles para adaSequence
            adaSequence =
                jsonMap['sequence'] as String? ??
                jsonMap['adaSequence'] as String? ??
                jsonMap['ada_sequence'] as String?;

            print(
              'DEBUG: Parsed odooName: $odooName, adaSequence: $adaSequence',
            );
          } catch (e) {
            print('DEBUG: Error parsing resultJson: $e');
          }
        }

        await marcarComoMigrado(
          operacionId,
          null,
          odooName: odooName,
          adaSequence: adaSequence,
        );
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

      final detalles = await _obtenerDetallesConCodigoBarras(id);

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

        final detalles = await _obtenerDetallesConCodigoBarras(operacionId);

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

        final detalles = await _obtenerDetallesConCodigoBarras(operacionId);

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

  Future<void> marcarComoMigrado(
    String operacionId,
    dynamic serverId, {
    String? odooName,
    String? adaSequence,
  }) async {
    try {
      final now = DateTime.now();

      final data = {
        'sync_status': 'migrado',
        'synced_at': now.toIso8601String(),
        'server_id': serverId,
        'sync_error': null,
      };

      if (odooName != null) {
        data['odoo_name'] = odooName;
      }
      if (adaSequence != null) {
        data['ada_sequence'] = adaSequence;
      }

      await dbHelper.actualizar(
        tableName,
        data,
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

  // ==================== MÉTODOS NUEVOS PARA SINCRONIZACIÓN GET ====================

  @override
  Future<void> guardarOperacionesDesdeServidor(
    List<Map<String, dynamic>> operacionesData,
  ) async {
    try {
      final db = await dbHelper.database;

      await db.transaction((txn) async {
        for (final operacionData in operacionesData) {
          // Extraer detalles
          final detalles =
              operacionData['detalles'] as List<Map<String, dynamic>>?;

          // Remover detalles del mapa principal
          final operacionMap = Map<String, dynamic>.from(operacionData);
          operacionMap.remove('detalles');
          operacionMap.remove(
            'observaciones',
          ); // Explicitly remove just in case

          // Verificar si la operación ya existe por ID o server_id
          final existente = await _operacionExisteEnTransaccion(
            txn,
            operacionMap['id'] as String?,
            operacionMap['server_id'] as int?,
          );

          if (existente) {
            // Actualizar operación existente
            await txn.update(
              tableName,
              operacionMap,
              where: 'id = ? OR server_id = ?',
              whereArgs: [operacionMap['id'], operacionMap['server_id']],
            );

            // Eliminar detalles anteriores
            await txn.delete(
              'operacion_comercial_detalle',
              where: 'operacion_comercial_id = ?',
              whereArgs: [operacionMap['id']],
            );
          } else {
            // Insertar nueva operación
            await txn.insert(
              tableName,
              operacionMap,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }

          // Insertar detalles
          if (detalles != null && detalles.isNotEmpty) {
            for (final detalle in detalles) {
              await txn.insert(
                'operacion_comercial_detalle',
                detalle,
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
          }
        }
      });
    } catch (e) {
      await ErrorLogService.logDatabaseError(
        tableName: tableName,
        operation: 'guardar_operaciones_desde_servidor',
        errorMessage: 'Error guardando operaciones desde servidor: $e',
      );
      rethrow;
    }
  }

  Future<bool> _operacionExisteEnTransaccion(
    Transaction txn,
    String? uuid,
    int? serverId,
  ) async {
    if (uuid != null) {
      final result = await txn.query(
        tableName,
        where: 'id = ?',
        whereArgs: [uuid],
        limit: 1,
      );
      if (result.isNotEmpty) return true;
    }

    if (serverId != null) {
      final result = await txn.query(
        tableName,
        where: 'server_id = ?',
        whereArgs: [serverId],
        limit: 1,
      );
      if (result.isNotEmpty) return true;
    }

    return false;
  }
}
