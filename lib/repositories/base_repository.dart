import 'package:sqflite/sqflite.dart';
import '../services/database_helper.dart';
import 'package:logger/logger.dart';

var logger = Logger();

abstract class BaseRepository<T> {
  final DatabaseHelper dbHelper = DatabaseHelper();

  // Nombre de la tabla (debe ser implementado por cada repository)
  String get tableName;

  // Método para convertir Map a objeto (debe ser implementado)
  T fromMap(Map<String, dynamic> map);

  // Método para convertir objeto a Map (debe ser implementado)
  Map<String, dynamic> toMap(T item);

  // ════════════════════════════════════════════════════════════════
  // MÉTODOS PARA DETECTAR CAPACIDADES DE LA TABLA
  // ════════════════════════════════════════════════════════════════

  /// Verifica si la tabla tiene columna 'activo'
  bool _tieneColumnaActivo() {
    return tableName != 'clientes' && tableName != 'modelos';
  }

  /// Verifica si la tabla tiene columnas de fecha
  bool _tieneCamposFecha() {
    return tableName != 'clientes' && tableName != 'modelos';
  }

  /// Verifica si la tabla tiene columna 'sincronizado'
  bool _tieneColumnaSincronizado() {
    return tableName != 'clientes' && tableName != 'modelos';
  }

  // ════════════════════════════════════════════════════════════════
  // MÉTODOS CRUD GENÉRICOS
  // ════════════════════════════════════════════════════════════════

  /// Obtener todos los elementos
  Future<List<T>> obtenerTodos({bool soloActivos = true}) async {
    String? where;
    List<dynamic>? whereArgs;

    // Solo filtrar por activo si la tabla tiene esa columna
    if (soloActivos && _tieneColumnaActivo()) {
      where = 'activo = ?';
      whereArgs = [1];
    }

    final maps = await dbHelper.consultar(
      tableName,
      where: where,
      whereArgs: whereArgs,
      orderBy: getDefaultOrderBy(),
    );
    return maps.map((map) => fromMap(map)).toList();
  }

  /// Buscar elementos
  Future<List<T>> buscar(String query) async {
    final maps = await dbHelper.consultar(
      tableName,
      where: getBuscarWhere(),
      whereArgs: getBuscarArgs(query),
      orderBy: getDefaultOrderBy(),
      limit: 50,
    );
    return maps.map((map) => fromMap(map)).toList();
  }

  /// Obtener por ID
  Future<T?> obtenerPorId(int id) async {
    final maps = await dbHelper.consultar(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return maps.isNotEmpty ? fromMap(maps.first) : null;
  }

  /// Insertar elemento
  Future<int> insertar(T item) async {
    final datos = toMap(item);

    // Solo agregar campos de auditoría si la tabla los tiene
    if (_tieneCamposFecha()) {
      datos['fecha_creacion'] = DateTime.now().toIso8601String();
      datos['fecha_actualizacion'] = DateTime.now().toIso8601String();
    }

    if (_tieneColumnaSincronizado()) {
      datos['sincronizado'] = 0;
    }

    return await dbHelper.insertar(tableName, datos);
  }

  /// Actualizar elemento
  Future<int> actualizar(T item, int id) async {
    final datos = toMap(item);

    // Solo agregar campos de auditoría si la tabla los tiene
    if (_tieneCamposFecha()) {
      datos['fecha_actualizacion'] = DateTime.now().toIso8601String();
    }

    if (_tieneColumnaSincronizado()) {
      datos['sincronizado'] = 0;
    }

    return await dbHelper.actualizar(tableName, datos, where: 'id = ?', whereArgs: [id]);
  }

  /// Consulta personalizada
  Future<List<Map<String, dynamic>>> consultarPersonalizada(String sql) async {
    final db = await dbHelper.database;
    return await db.rawQuery(sql);
  }

  /// Eliminar elemento (soft delete si tiene columna activo, sino delete físico)
  Future<int> eliminar(int id) async {
    if (_tieneColumnaActivo()) {
      // Soft delete
      final datos = <String, dynamic>{'activo': 0};
      if (_tieneCamposFecha()) {
        datos['fecha_actualizacion'] = DateTime.now().toIso8601String();
      }
      return await dbHelper.actualizar(tableName, datos, where: 'id = ?', whereArgs: [id]);
    } else {
      // Delete físico
      return await dbHelper.eliminar(tableName, where: 'id = ?', whereArgs: [id]);
    }
  }

  /// Obtener estadísticas
  Future<Map<String, dynamic>> obtenerEstadisticas() async {
    final db = await dbHelper.database;

    int total;
    int sincronizados = 0;
    int noSincronizados = 0;

    if (_tieneColumnaActivo()) {
      total = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM $tableName WHERE activo = 1')) ?? 0;

      if (_tieneColumnaSincronizado()) {
        sincronizados = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM $tableName WHERE activo = 1 AND sincronizado = 1')) ?? 0;
        noSincronizados = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM $tableName WHERE activo = 1 AND sincronizado = 0')) ?? 0;
      }
    } else {
      total = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM $tableName')) ?? 0;

      if (_tieneColumnaSincronizado()) {
        sincronizados = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM $tableName WHERE sincronizado = 1')) ?? 0;
        noSincronizados = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM $tableName WHERE sincronizado = 0')) ?? 0;
      }
    }

    final stats = <String, dynamic>{
      'total${getEntityName()}s': total,
      'ultimaActualizacion': DateTime.now().toIso8601String(),
    };

    if (_tieneColumnaSincronizado()) {
      stats['${getEntityName().toLowerCase()}sSincronizados'] = sincronizados;
      stats['${getEntityName().toLowerCase()}sNoSincronizados'] = noSincronizados;
    }

    return stats;
  }

  // ════════════════════════════════════════════════════════════════
  // MÉTODOS PARA SINCRONIZACIÓN
  // ════════════════════════════════════════════════════════════════

  /// Limpiar y sincronizar desde API
  Future<void> limpiarYSincronizar(List<dynamic> itemsAPI) async {
    final db = await dbHelper.database;

    await db.transaction((txn) async {
      if (_tieneColumnaActivo()) {
        // Soft delete de elementos existentes
        final updateData = <String, dynamic>{'activo': 0};
        if (_tieneCamposFecha()) {
          updateData['fecha_actualizacion'] = DateTime.now().toIso8601String();
        }
        await txn.update(tableName, updateData);
      } else {
        // Para tablas sin 'activo', limpiar completamente
        await txn.delete(tableName);
      }

      // Insertar elementos de la API
      for (var itemData in itemsAPI) {
        Map<String, dynamic> datos;

        if (itemData is Map<String, dynamic>) {
          datos = Map<String, dynamic>.from(itemData);
        } else {
          datos = toMap(itemData);
        }

        // Solo agregar campos de auditoría si la tabla los tiene
        if (_tieneColumnaActivo()) {
          datos['activo'] = 1; // Usar INTEGER en lugar de boolean
        }

        if (_tieneColumnaSincronizado()) {
          datos['sincronizado'] = 1; // Usar INTEGER en lugar de boolean
        }

        if (_tieneCamposFecha()) {
          datos['fecha_actualizacion'] = DateTime.now().toIso8601String();
          if (datos['fecha_creacion'] == null) {
            datos['fecha_creacion'] = DateTime.now().toIso8601String();
          }
        }

        await txn.insert(tableName, datos, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });

    logger.i('✅ Sincronización completa: ${itemsAPI.length} ${getEntityName().toLowerCase()}s procesados');
  }

  /// Obtener elementos no sincronizados
  Future<List<T>> obtenerNoSincronizados() async {
    if (!_tieneColumnaSincronizado()) {
      // Si la tabla no tiene columna sincronizado, retornar lista vacía
      return [];
    }

    String where = 'sincronizado = ?';
    List<dynamic> whereArgs = [0];

    if (_tieneColumnaActivo()) {
      where = 'activo = ? AND sincronizado = ?';
      whereArgs = [1, 0];
    }

    final maps = await dbHelper.consultar(
      tableName,
      where: where,
      whereArgs: whereArgs,
      orderBy: _tieneCamposFecha() ? 'fecha_creacion ASC' : getDefaultOrderBy(),
    );
    return maps.map((map) => fromMap(map)).toList();
  }

  /// Marcar como sincronizados
  Future<void> marcarComoSincronizados(List<int> ids) async {
    if (ids.isEmpty || !_tieneColumnaSincronizado()) return;

    final db = await dbHelper.database;
    final placeholders = ids.map((_) => '?').join(',');

    final updateData = <dynamic>[1]; // sincronizado = 1
    if (_tieneCamposFecha()) {
      updateData.insert(0, DateTime.now().toIso8601String()); // fecha_actualizacion
    }
    updateData.addAll(ids);

    String sql = 'UPDATE $tableName SET sincronizado = ?';
    if (_tieneCamposFecha()) {
      sql = 'UPDATE $tableName SET fecha_actualizacion = ?, sincronizado = ?';
    }
    sql += ' WHERE id IN ($placeholders)';

    await db.rawUpdate(sql, updateData);

    logger.i('✅ ${ids.length} ${getEntityName().toLowerCase()}s marcados como sincronizados');
  }

  // ════════════════════════════════════════════════════════════════
  // MÉTODOS ESPECÍFICOS PARA CLIENTES (sobrescribir en ClienteRepository)
  // ════════════════════════════════════════════════════════════════

  /// Método específico para sincronizar clientes (sin campos de auditoría)
  Future<void> sincronizarClientesSimple(List<dynamic> clientesAPI) async {
    final db = await dbHelper.database;

    await db.transaction((txn) async {
      // Limpiar tabla completamente
      await txn.delete(tableName);

      // Insertar clientes de la API
      for (var clienteData in clientesAPI) {
        Map<String, dynamic> datos;

        if (clienteData is Map<String, dynamic>) {
          datos = Map<String, dynamic>.from(clienteData);
        } else {
          datos = toMap(clienteData);
        }

        // NO agregar campos activo, sincronizado, fechas para clientes
        await txn.insert(tableName, datos, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });

    logger.i('✅ Sincronización de clientes completa: ${clientesAPI.length} clientes procesados');
  }

  // ════════════════════════════════════════════════════════════════
  // MÉTODOS ABSTRACTOS (DEBEN SER IMPLEMENTADOS)
  // ════════════════════════════════════════════════════════════════

  /// Orden por defecto para las consultas
  String getDefaultOrderBy();

  /// WHERE clause para búsquedas
  String getBuscarWhere();

  /// Argumentos para búsquedas
  List<dynamic> getBuscarArgs(String query);

  /// Nombre de la entidad (para logs y estadísticas)
  String getEntityName();
}