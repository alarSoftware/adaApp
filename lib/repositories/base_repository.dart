import 'package:sqflite/sqflite.dart';
import 'package:ada_app/services/data/database_helper.dart';

abstract class BaseRepository<T> {
  final DatabaseHelper dbHelper = DatabaseHelper();

  String get tableName;

  T fromMap(Map<String, dynamic> map);

  Map<String, dynamic> toMap(T item);

  Future<void> debugEsquemaTabla() async {
    final db = await dbHelper.database;
    try {
      await db.rawQuery("PRAGMA table_info($tableName)");
    } catch (e) {
      // Silently fail
    }
  }

  Future<List<T>> obtenerTodos() async {
    final maps = await dbHelper.consultar(
      tableName,
      orderBy: getDefaultOrderBy(),
    );
    return maps.map((map) => fromMap(map)).toList();
  }

  Future<List<T>> buscar(String query) async {
    final maps = await dbHelper.consultar(
      tableName,
      where: getBuscarWhere(),
      whereArgs: getBuscarArgs(query),
      orderBy: getDefaultOrderBy(),
      limit: 100,
    );
    return maps.map((map) => fromMap(map)).toList();
  }

  Future<T?> obtenerPorId(int id) async {
    final maps = await dbHelper.consultar(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return maps.isNotEmpty ? fromMap(maps.first) : null;
  }

  Future<int> insertar(T item) async {
    final datos = toMap(item);
    return await dbHelper.insertar(tableName, datos);
  }

  Future<int> actualizar(T item, int id) async {
    final datos = toMap(item);
    return await dbHelper.actualizar(
      tableName,
      datos,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> consultarPersonalizada(String sql) async {
    final db = await dbHelper.database;
    return await db.rawQuery(sql);
  }

  Future<int> eliminar(int id) async {
    return await dbHelper.eliminar(tableName, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> limpiarYSincronizar(List<dynamic> itemsAPI) async {
    final db = await dbHelper.database;

    await db.transaction((txn) async {
      await txn.delete(tableName);

      for (var itemData in itemsAPI) {
        try {
          Map<String, dynamic> datos;

          if (itemData is Map<String, dynamic>) {
            datos = Map<String, dynamic>.from(itemData);
          } else {
            datos = toMap(itemData);
          }

          await txn.insert(
            tableName,
            datos,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        } catch (e) {
          rethrow;
        }
      }
    });
  }

  Future<void> sincronizar(List<dynamic> itemsAPI) async {
    return await limpiarYSincronizar(itemsAPI);
  }

  Future<void> insertarLote(List<dynamic> itemsAPI) async {
    final db = await dbHelper.database;

    await db.transaction((txn) async {
      final batch = txn.batch();

      for (var itemData in itemsAPI) {
        try {
          Map<String, dynamic> datos;

          if (itemData is Map<String, dynamic>) {
            datos = Map<String, dynamic>.from(itemData);
          } else {
            datos = toMap(itemData);
          }

          batch.insert(
            tableName,
            datos,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        } catch (e) {
          // Skip invalid items
        }
      }

      await batch.commit(noResult: true);
    });
  }

  Future<int> contar() async {
    final db = await dbHelper.database;
    return Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM $tableName'),
        ) ??
        0;
  }

  Future<void> vaciar() async {
    final db = await dbHelper.database;
    await db.delete(tableName);
  }

  String getDefaultOrderBy();

  String getBuscarWhere();

  List<dynamic> getBuscarArgs(String query);

  String getEntityName();
}
