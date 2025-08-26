import 'package:sqflite/sqflite.dart';
import '../services/database_helper.dart';
import 'package:logger/logger.dart';

var logger = Logger();

abstract class BaseRepository<T> {
  final DatabaseHelper dbHelper = DatabaseHelper(); // ← SIN UNDERSCORE

  // Nombre de la tabla (debe ser implementado por cada repository)
  String get tableName;

  // Método para convertir Map a objeto (debe ser implementado)
  T fromMap(Map<String, dynamic> map);

  // Método para convertir objeto a Map (debe ser implementado)
  Map<String, dynamic> toMap(T item);

  // ════════════════════════════════════════════════════════════════
  // MÉTODOS CRUD GENÉRICOS
  // ════════════════════════════════════════════════════════════════

  /// Obtener todos los elementos
// En BaseRepository, cambia el método obtenerTodos:
  Future<List<T>> obtenerTodos({bool soloActivos = true}) async {
    // Verificar si la tabla tiene columna 'activo' antes de usarla
    String? where;
    List<dynamic>? whereArgs;

    if (soloActivos && tableName != 'modelos') {  // modelos no tiene columna activo
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
    final maps = await dbHelper.consultar( // ← SIN UNDERSCORE
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
    final maps = await dbHelper.consultar( // ← SIN UNDERSCORE
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
    datos['fecha_creacion'] = DateTime.now().toIso8601String();
    datos['fecha_actualizacion'] = DateTime.now().toIso8601String();
    datos['sincronizado'] = 0;
    return await dbHelper.insertar(tableName, datos); // ← SIN UNDERSCORE
  }

  /// Actualizar elemento
  Future<int> actualizar(T item, int id) async {
    final datos = toMap(item);
    datos['fecha_actualizacion'] = DateTime.now().toIso8601String();
    datos['sincronizado'] = 0;
    return await dbHelper.actualizar(tableName, datos, where: 'id = ?', whereArgs: [id]); // ← SIN UNDERSCORE
  }

  Future<List<Map<String, dynamic>>> consultarPersonalizada(String sql) async {
    final db = await dbHelper.database; // ← SIN UNDERSCORE
    return await db.rawQuery(sql);
  }

  /// Eliminar elemento (soft delete)
  Future<int> eliminar(int id) async {
    return await dbHelper.actualizar( // ← SIN UNDERSCORE
      tableName,
      {
        'activo': 0,
        'fecha_actualizacion': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Obtener estadísticas
  Future<Map<String, dynamic>> obtenerEstadisticas() async {
    final db = await dbHelper.database; // ← SIN UNDERSCORE

    final total = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM $tableName WHERE activo = 1')) ?? 0;
    final sincronizados = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM $tableName WHERE activo = 1 AND sincronizado = 1')) ?? 0;
    final noSincronizados = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM $tableName WHERE activo = 1 AND sincronizado = 0')) ?? 0;

    return {
      'total${getEntityName()}s': total,
      '${getEntityName().toLowerCase()}sSincronizados': sincronizados,
      '${getEntityName().toLowerCase()}sNoSincronizados': noSincronizados,
      'ultimaActualizacion': DateTime.now().toIso8601String(),
    };
  }

  // ════════════════════════════════════════════════════════════════
  // MÉTODOS PARA SINCRONIZACIÓN
  // ════════════════════════════════════════════════════════════════

  /// Limpiar y sincronizar desde API
  Future<void> limpiarYSincronizar(List<dynamic> itemsAPI) async {
    final db = await dbHelper.database; // ← SIN UNDERSCORE

    await db.transaction((txn) async {
      // Soft delete de elementos existentes
      await txn.update(tableName, {
        'activo': 0,
        'fecha_actualizacion': DateTime.now().toIso8601String(),
      });

      // Insertar elementos de la API
      for (var itemData in itemsAPI) {
        Map<String, dynamic> datos;

        if (itemData is Map<String, dynamic>) {
          datos = Map<String, dynamic>.from(itemData);
        } else {
          datos = toMap(itemData);
        }

        datos['activo'] = 1;
        datos['sincronizado'] = 1;
        datos['fecha_actualizacion'] = DateTime.now().toIso8601String();

        if (datos['fecha_creacion'] == null) {
          datos['fecha_creacion'] = DateTime.now().toIso8601String();
        }

        await txn.insert(tableName, datos, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });

    logger.i('✅ Sincronización completa: ${itemsAPI.length} ${getEntityName().toLowerCase()}s procesados');
  }

  /// Obtener elementos no sincronizados
  Future<List<T>> obtenerNoSincronizados() async {
    final maps = await dbHelper.consultar( // ← SIN UNDERSCORE
      tableName,
      where: 'activo = ? AND sincronizado = ?',
      whereArgs: [1, 0],
      orderBy: 'fecha_creacion ASC',
    );
    return maps.map((map) => fromMap(map)).toList();
  }

  /// Marcar como sincronizados
  Future<void> marcarComoSincronizados(List<int> ids) async {
    if (ids.isEmpty) return;

    final db = await dbHelper.database; // ← SIN UNDERSCORE
    final placeholders = ids.map((_) => '?').join(',');

    await db.rawUpdate(
      'UPDATE $tableName SET sincronizado = 1, fecha_actualizacion = ? WHERE id IN ($placeholders)',
      [DateTime.now().toIso8601String(), ...ids],
    );

    logger.i('✅ ${ids.length} ${getEntityName().toLowerCase()}s marcados como sincronizados');
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