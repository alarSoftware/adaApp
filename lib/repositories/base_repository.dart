// base_repository.dart - VERSIÓN SIMPLIFICADA SIN CAMPOS DE AUDITORÍA
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
  // MÉTODO DE DEBUG PARA VERIFICAR ESQUEMA
  // ════════════════════════════════════════════════════════════════

  /// Debug: Verificar columnas de una tabla
  Future<void> debugEsquemaTabla() async {
    final db = await dbHelper.database;
    try {
      final result = await db.rawQuery("PRAGMA table_info($tableName)");
      final columnas = result.map((r) => r['name']).toList();

      logger.i('=== ESQUEMA DE TABLA: $tableName ===');
      logger.i('Columnas encontradas: $columnas');
      logger.i('===============================');
    } catch (e) {
      logger.e('Error verificando esquema de $tableName: $e');
    }
  }

  // ════════════════════════════════════════════════════════════════
  // MÉTODOS CRUD GENÉRICOS SIMPLIFICADOS
  // ════════════════════════════════════════════════════════════════

  /// Obtener todos los elementos
  Future<List<T>> obtenerTodos() async {
    final maps = await dbHelper.consultar(
      tableName,
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

  /// Insertar elemento - SIMPLIFICADO
  Future<int> insertar(T item) async {
    final datos = toMap(item);
    return await dbHelper.insertar(tableName, datos);
  }

  /// Actualizar elemento - SIMPLIFICADO
  Future<int> actualizar(T item, int id) async {
    final datos = toMap(item);
    return await dbHelper.actualizar(tableName, datos, where: 'id = ?', whereArgs: [id]);
  }

  /// Consulta personalizada
  Future<List<Map<String, dynamic>>> consultarPersonalizada(String sql) async {
    final db = await dbHelper.database;
    return await db.rawQuery(sql);
  }

  /// Eliminar elemento - DELETE FÍSICO SIEMPRE
  Future<int> eliminar(int id) async {
    return await dbHelper.eliminar(tableName, where: 'id = ?', whereArgs: [id]);
  }

  /// Obtener estadísticas básicas
  Future<Map<String, dynamic>> obtenerEstadisticas() async {
    final db = await dbHelper.database;

    final total = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM $tableName')) ?? 0;

    return {
      'total${getEntityName()}s': total,
      'ultimaActualizacion': DateTime.now().toIso8601String(),
    };
  }

  // ════════════════════════════════════════════════════════════════
  // MÉTODOS PARA SINCRONIZACIÓN SIMPLIFICADOS
  // ════════════════════════════════════════════════════════════════

  /// Limpiar y sincronizar desde API - MANTIENE NOMBRE ORIGINAL
  Future<void> limpiarYSincronizar(List<dynamic> itemsAPI) async {
    final db = await dbHelper.database;

    logger.i('Iniciando limpiarYSincronizar para $tableName con ${itemsAPI.length} items');

    await db.transaction((txn) async {
      // Limpiar tabla completamente
      final deleted = await txn.delete(tableName);
      logger.i('Items eliminados de $tableName: $deleted');

      // Insertar items de la API
      int exitosos = 0;
      int errores = 0;

      for (var itemData in itemsAPI) {
        try {
          Map<String, dynamic> datos;

          if (itemData is Map<String, dynamic>) {
            datos = Map<String, dynamic>.from(itemData);
          } else {
            datos = toMap(itemData);
          }

          await txn.insert(tableName, datos, conflictAlgorithm: ConflictAlgorithm.replace);
          exitosos++;

          // Log cada 500 inserciones exitosas
          if (exitosos % 500 == 0) {
            logger.i('Procesados: $exitosos de ${itemsAPI.length}');
          }

        } catch (e) {
          errores++;
          logger.e('Error insertando item en $tableName: $e');

          if (errores <= 3) { // Solo mostrar los primeros 3 errores
            logger.e('Datos del item con error: $itemData');
          }
        }
      }

      logger.i('Sincronización completa en $tableName: $exitosos exitosos, $errores errores');
    });

    logger.i('Sincronización completa: ${itemsAPI.length} items procesados en $tableName');
  }

  /// Método alternativo con nombre más simple
  Future<void> sincronizar(List<dynamic> itemsAPI) async {
    return await limpiarYSincronizar(itemsAPI);
  }

  /// Método batch insert para mejor performance
  Future<void> insertarLote(List<dynamic> itemsAPI) async {
    final db = await dbHelper.database;

    logger.i('Insertando lote en $tableName: ${itemsAPI.length} items');

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

          batch.insert(tableName, datos, conflictAlgorithm: ConflictAlgorithm.replace);
        } catch (e) {
          logger.e('Error preparando item para lote: $e');
        }
      }

      await batch.commit(noResult: true);
      logger.i('Lote insertado exitosamente en $tableName');
    });
  }

  /// Contar registros
  Future<int> contar() async {
    final db = await dbHelper.database;
    return Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $tableName')) ?? 0;
  }

  /// Vaciar tabla
  Future<void> vaciar() async {
    final db = await dbHelper.database;
    await db.delete(tableName);
    logger.i('Tabla $tableName vaciada');
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