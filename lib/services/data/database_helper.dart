import 'dart:async';
import '../../utils/logger.dart';
import 'package:ada_app/config/app_config.dart';
import 'dart:convert';
import 'dart:io';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:ada_app/models/usuario.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'database_tables.dart' as tables;
import 'database_sync.dart' as sync;
import 'database_queries.dart' as queries;

class DatabaseHelper {
  static DatabaseHelper? _instance;
  static Database? _database;

  static const String _databaseName = 'AdaApp.db';
  static const int _databaseVersion = AppConfig.databaseVersion;

  late final tables.DatabaseTables _tables;
  late final sync.DatabaseSync _sync;
  late final queries.DatabaseQueries _queries;

  DatabaseHelper._internal() {
    _tables = tables.DatabaseTables();
    _sync = sync.DatabaseSync();
    _queries = queries.DatabaseQueries();
  }

  factory DatabaseHelper() {
    return _instance ??= DatabaseHelper._internal();
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      final path = join(await getDatabasesPath(), _databaseName);

      return await openDatabase(
        path,
        version: _databaseVersion,
        onConfigure: _onConfigure,
        onCreate: _tables.onCreate,
        onUpgrade: _tables.onUpgrade,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _onConfigure(Database db) async {
    await db.rawQuery('PRAGMA journal_mode = WAL');
    await db.execute('PRAGMA synchronous = NORMAL');
  }

  Future<List<Map<String, dynamic>>> consultar(
    String tableName, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    try {
      final db = await database;
      final result = await db.query(
        tableName,
        where: where,
        whereArgs: whereArgs,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      );
      return result;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> consultarPersonalizada(
    String sql, [
    List<dynamic>? arguments,
  ]) async {
    try {
      final db = await database;
      final result = await db.rawQuery(sql, arguments);
      return result;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> consultarPorId(String tableName, int id) async {
    final result = await consultar(tableName, where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> insertar(
    String tableName,
    Map<String, dynamic> values, {
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    _validateValues(values);
    _addTimestamps(tableName, values);

    final db = await database;
    final id = await db.insert(
      tableName,
      values,
      conflictAlgorithm: conflictAlgorithm ?? ConflictAlgorithm.abort,
    );
    return id;
  }

  Future<int> insertarOIgnorar(
    String tableName,
    Map<String, dynamic> values,
  ) async {
    return insertar(
      tableName,
      values,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<int> insertarOReemplazar(
    String tableName,
    Map<String, dynamic> values,
  ) async {
    return insertar(
      tableName,
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> vaciarEInsertar(
    String tableName,
    List<Map<String, dynamic>> nuevosRegistros,
  ) async {
    final db = await database;

    return await db.transaction<int>((txn) async {
      await txn.delete(tableName);

      final batch = txn.batch();
      for (final record in nuevosRegistros) {
        _validateValues(record);
        _addTimestamps(tableName, record);
        batch.insert(tableName, record);
      }

      await batch.commit(noResult: true);
      return nuevosRegistros.length;
    });
  }

  Future<int> actualizar(
    String tableName,
    Map<String, dynamic> values, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    _validateValues(values);
    _addTimestamps(tableName, values, isUpdate: true);

    final db = await database;
    final count = await db.update(
      tableName,
      values,
      where: where,
      whereArgs: whereArgs,
    );
    return count;
  }

  Future<int> eliminar(
    String tableName, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final db = await database;
    final count = await db.delete(
      tableName,
      where: where,
      whereArgs: whereArgs,
    );
    return count;
  }

  Future<int> eliminarPorId(String tableName, int id) async {
    return await eliminar(tableName, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> sincronizarClientes(List<dynamic> clientesAPI) async {
    final db = await database;
    return _sync.sincronizarClientes(db, clientesAPI);
  }

  Future<void> sincronizarUsuarios(
    List<Map<String, dynamic>> usuariosMapas,
  ) async {
    final db = await database;
    return _sync.sincronizarUsuarios(db, usuariosMapas);
  }

  Future<void> sincronizarMarcas(List<dynamic> marcasAPI) async {
    final db = await database;
    return _sync.sincronizarMarcas(db, marcasAPI);
  }

  Future<void> sincronizarModelos(List<dynamic> modelosAPI) async {
    final db = await database;
    return _sync.sincronizarModelos(db, modelosAPI);
  }

  Future<void> sincronizarLogos(List<dynamic> logosAPI) async {
    final db = await database;
    return _sync.sincronizarLogos(db, logosAPI);
  }

  Future<void> sincronizarUsuarioCliente(
    List<dynamic> usuarioClienteAPI,
  ) async {
    final db = await database;
    return _sync.sincronizarUsuarioCliente(db, usuarioClienteAPI);
  }

  Future<void> sincronizarRutas(int userId, List<dynamic> rutas) async {
    final db = await database;

    await db.transaction((txn) async {
      // Nota: La tabla app_routes ya fue limpiada completamente
      // al inicio de sincronizarUsuarios(), no es necesario limpiar por usuario

      // Insertar nuevas rutas
      final batch = txn.batch();
      final now = DateTime.now().toIso8601String();

      for (final ruta in rutas) {
        if (ruta is Map) {
          batch.insert('app_routes', {
            'user_id': userId,
            'module_name': ruta['nombre_modulo']?.toString() ?? '',
            'route_path': ruta['ruta']?.toString() ?? '',
            'fecha_sync': now,
          });
        }
      }

      await batch.commit(noResult: true);
    });
  }

  // MÉTODO PARA DEBUG: TOGGLE PERMISSION
  Future<void> toggleTestPermission(
    int userId,
    String moduleName,
    bool enable,
  ) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    if (enable) {
      // Insertar si no existe
      await db.insert('app_routes', {
        'user_id': userId,
        'module_name': moduleName,
        'route_path': 'debug/$moduleName',
        'fecha_sync': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    } else {
      // Borrar
      await db.delete(
        'app_routes',
        where: 'user_id = ? AND module_name = ?',
        whereArgs: [userId, moduleName],
      );
    }
  }

  Future<List<Map<String, dynamic>>> obtenerClientesConEquipos() async {
    final db = await database;
    return _queries.obtenerClientesConEquipos(db);
  }

  Future<List<Map<String, dynamic>>> obtenerEquiposDisponibles() async {
    final db = await database;
    return _queries.obtenerEquiposDisponibles(db);
  }

  Future<List<Map<String, dynamic>>> obtenerEquiposConDetalles() async {
    final db = await database;
    return _queries.obtenerEquiposConDetalles(db);
  }

  Future<List<Map<String, dynamic>>> obtenerHistorialEquipo(
    int equipoId,
  ) async {
    final db = await database;
    return _queries.obtenerHistorialEquipo(db, equipoId);
  }

  Future<List<Usuario>> obtenerUsuarios() async {
    final db = await database;
    final maps = await db.query('Users');
    return maps.map((map) => Usuario.fromMap(map)).toList();
  }

  Future<Map<String, List<Map<String, dynamic>>>>
  obtenerMarcasModelosYLogos() async {
    final marcas = await consultar(
      'marcas',
      where: 'activo = ?',
      whereArgs: [1],
      orderBy: 'nombre',
    );
    final modelos = await consultar('modelos', orderBy: 'nombre');
    final logos = await consultar(
      'logo',
      where: 'activo = ?',
      whereArgs: [1],
      orderBy: 'nombre',
    );

    return {'marcas': marcas, 'modelos': modelos, 'logos': logos};
  }

  Future<T> ejecutarTransaccion<T>(
    Future<T> Function(Transaction) operaciones,
  ) async {
    final db = await database;
    return await db.transaction<T>((txn) async {
      final result = await operaciones(txn);
      return result;
    });
  }

  Future<bool> existeRegistro(
    String tableName,
    String where,
    List<dynamic> whereArgs,
  ) async {
    final count = await contarRegistros(
      tableName,
      where: where,
      whereArgs: whereArgs,
    );
    return count > 0;
  }

  Future<int> contarRegistros(
    String tableName, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final db = await database;
    final result = await db.query(
      tableName,
      columns: ['COUNT(*) as count'],
      where: where,
      whereArgs: whereArgs,
    );
    return result.first['count'] as int;
  }

  Future<void> cerrarBaseDatos() async {
    if (_database?.isOpen == true) {
      await _database!.close();
      _database = null;
    }
  }

  Future<void> borrarBaseDatos() async {
    await cerrarBaseDatos();
    final path = join(await getDatabasesPath(), _databaseName);
    await deleteDatabase(path);
  }

  Future<void> optimizarBaseDatos() async {
    final db = await database;
    await db.execute('VACUUM');
    await db.execute('ANALYZE');
  }

  Future<List<String>> obtenerNombresTablas() async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
      );
      return result.map((row) => row['name'] as String).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> obtenerEstadisticasBaseDatos() async {
    try {
      final tablas = await obtenerNombresTablas();
      final estadisticas = <String, dynamic>{};

      for (final tabla in tablas) {
        final count = await contarRegistros(tabla);
        estadisticas[tabla] = count;
      }

      return estadisticas;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> obtenerEsquemaTabla(
    String tableName,
  ) async {
    try {
      final db = await database;
      return await db.rawQuery('PRAGMA table_info($tableName)');
    } catch (e) {
      rethrow;
    }
  }

  Future<String> respaldarDatos() async {
    try {
      final clientes = await consultar('clientes');
      final equipos = await consultarPersonalizada('''
        SELECT e.*, m.nombre as marca_nombre, mo.nombre as modelo_nombre, l.nombre as logo_nombre
        FROM equipos e
        JOIN marcas m ON e.marca_id = m.id
        JOIN modelos mo ON e.modelo_id = mo.id
        JOIN logo l ON e.logo_id = l.id
      ''');
      final equipoCliente = await consultar('equipo_cliente');
      final marcas = await consultar('marcas');
      final modelos = await consultar('modelos');
      final logos = await consultar('logo');

      final backup = {
        'version': _databaseVersion,
        'timestamp': DateTime.now().toIso8601String(),
        'data': {
          'clientes': clientes,
          'equipos': equipos,
          'equipo_cliente': equipoCliente,
          'marcas': marcas,
          'modelos': modelos,
          'logos': logos,
        },
      };

      final jsonString = jsonEncode(backup);

      final dbPath = await getDatabasesPath();
      final file = File(
        '$dbPath/backup_${DateTime.now().millisecondsSinceEpoch}.json',
      );
      await file.writeAsString(jsonString);

      return file.path;
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> resetCompleteDatabase() async {
    try {
      if (_instance != null) {
        await _instance!.cerrarBaseDatos();
        _instance = null;
        _database = null;
      }

      final path = join(await getDatabasesPath(), _databaseName);

      try {
        await deleteDatabase(path);
      } catch (e) {
        // Continue anyway
      }

      try {
        await deleteDatabase('$path-journal');
        await deleteDatabase('$path-wal');
        await deleteDatabase('$path-shm');
      } catch (e) {
        // Files may not exist
      }

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
      } catch (e) {
        // Continue anyway
      }
    } catch (e, stackTrace) {
      rethrow;
    }
  }

  static int _getTableCount() {
    return 20;
  }

  static Future<Map<String, dynamic>> verificarEstadoPostReset() async {
    try {
      final helper = DatabaseHelper();
      final stats = await helper.obtenerEstadisticasBaseDatos();
      final tables = await helper.obtenerNombresTablas();

      int totalRegistros = 0;
      for (final entry in stats.entries) {
        final count = entry.value as int;
        totalRegistros += count;
      }

      return {
        'tablas_creadas': tables.length,
        'total_registros': totalRegistros,
        'estadisticas': stats,
        'tablas': tables,
      };
    } catch (e) { AppLogger.e("DATABASE_HELPER: Error", e); return {'error': e.toString()}; }
  }

  void _validateValues(Map<String, dynamic> values) {
    if (values.isEmpty) {
      throw ArgumentError('Los valores no pueden estar vacíos');
    }
  }

  void _addTimestamps(
    String tableName,
    Map<String, dynamic> values, {
    bool isUpdate = false,
  }) {
    if (!_requiresTimestamps(tableName)) return;

    final now = DateTime.now().toIso8601String();
    values['fecha_actualizacion'] = now;

    if (!isUpdate && !values.containsKey('fecha_creacion')) {
      values['fecha_creacion'] = now;
    }
  }

  bool _requiresTimestamps(String tableName) {
    const tablesWithoutTimestamps = {
      'clientes',
      'modelos',
      'marcas',
      'logo',
      'dynamic_form',
      'dynamic_form_detail',
      'dynamic_form_response',
      'dynamic_form_response_detail',
      'dynamic_form_response_image',
      'censo_activo_foto',
      'operacion_comercial',
      'operacion_comercial_detalle',
      'productos',
    };
    return !tablesWithoutTimestamps.contains(tableName);
  }
}
