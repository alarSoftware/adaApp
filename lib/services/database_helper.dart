// database_helper.dart (COMPLETO CON RESET)
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:logger/logger.dart';
import 'package:ada_app/models/usuario.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 🔥 AGREGADO PARA RESET

// ✅ Importar con alias para evitar conflictos
import 'database_tables.dart' as tables;
import 'database_sync.dart' as sync;
import 'database_queries.dart' as queries;

var logger = Logger();

class DatabaseHelper {
  static DatabaseHelper? _instance;
  static Database? _database;

  static const String _databaseName = 'AdaApp.db';
  static const int _databaseVersion = 1;

  // ✅ Delegados especializados con nombres corregidos
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
      logger.i('Inicializando base de datos en: $path');

      return await openDatabase(
        path,
        version: _databaseVersion,
        onCreate: _tables.onCreate,
        onUpgrade: _tables.onUpgrade,
        onOpen: (db) => logger.i('Base de datos abierta exitosamente'),
      );
    } catch (e) {
      logger.e('Error al inicializar base de datos: $e');
      rethrow;
    }
  }

  // ================================================================
  // MÉTODOS CRUD GENÉRICOS SIMPLIFICADOS
  // ================================================================

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
      logger.d('Consulta en $tableName: ${result.length} registros');
      return result;
    } catch (e) {
      logger.e('Error consultando $tableName: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> consultarPersonalizada(String sql, [List<dynamic>? arguments]) async {
    try {
      final db = await database;
      final result = await db.rawQuery(sql, arguments);
      logger.d('Consulta personalizada: ${result.length} registros encontrados');
      return result;
    } catch (e) {
      logger.e('Error en consulta personalizada: $e');
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
      conflictAlgorithm: conflictAlgorithm ?? ConflictAlgorithm.abort,  // ✅ Maneja conflictos
    );
    logger.d('Insertado en $tableName: ID $id');
    return id;
  }

// Método específico para insertar o ignorar duplicados
  Future<int> insertarOIgnorar(String tableName, Map<String, dynamic> values) async {
    return insertar(tableName, values, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

// Método específico para insertar o reemplazar duplicados
  Future<int> insertarOReemplazar(String tableName, Map<String, dynamic> values) async {
    return insertar(tableName, values, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> vaciarEInsertar(String tableName, List<Map<String, dynamic>> nuevosRegistros) async {
    final db = await database;

    return await db.transaction<int>((txn) async {
      // 1. Vaciar
      await txn.delete(tableName);

      // 2. Insertar
      for (final record in nuevosRegistros) {
        _validateValues(record);
        _addTimestamps(tableName, record);
        await txn.insert(tableName, record);
      }

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
    final count = await db.update(tableName, values, where: where, whereArgs: whereArgs);
    logger.d('Actualizados en $tableName: $count registros');
    return count;
  }

  Future<int> eliminar(String tableName, {String? where, List<dynamic>? whereArgs}) async {
    final db = await database;
    final count = await db.delete(tableName, where: where, whereArgs: whereArgs);
    logger.d('Eliminados de $tableName: $count registros');
    return count;
  }

  Future<int> eliminarPorId(String tableName, int id) async {
    return await eliminar(tableName, where: 'id = ?', whereArgs: [id]);
  }

  // ================================================================
  // MÉTODOS DE SINCRONIZACIÓN (DELEGADOS)
  // ================================================================

  Future<void> sincronizarClientes(List<dynamic> clientesAPI) async {
    final db = await database;
    return _sync.sincronizarClientes(db, clientesAPI);
  }

  Future<void> sincronizarUsuarios(List<Map<String, dynamic>> usuariosMapas) async {
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

  Future<void> sincronizarUsuarioCliente(List<dynamic> usuarioClienteAPI) async {
    final db = await database;
    return _sync.sincronizarUsuarioCliente(db, usuarioClienteAPI);
  }

  // ================================================================
  // CONSULTAS ESPECIALIZADAS (DELEGADAS)
  // ================================================================

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

  Future<List<Map<String, dynamic>>> obtenerHistorialEquipo(int equipoId) async {
    final db = await database;
    return _queries.obtenerHistorialEquipo(db, equipoId);
  }

  Future<List<Usuario>> obtenerUsuarios() async {
    final db = await database;
    final maps = await db.query('Users');
    return maps.map((map) => Usuario.fromMap(map)).toList();
  }

  Future<Map<String, List<Map<String, dynamic>>>> obtenerMarcasModelosYLogos() async {
    final marcas = await consultar('marcas', where: 'activo = ?', whereArgs: [1], orderBy: 'nombre');
    final modelos = await consultar('modelos', orderBy: 'nombre');
    final logos = await consultar('logo', where: 'activo = ?', whereArgs: [1], orderBy: 'nombre');

    return {
      'marcas': marcas,
      'modelos': modelos,
      'logos': logos,
    };
  }

  // ================================================================
  // MÉTODOS DE UTILIDAD Y TRANSACCIONES
  // ================================================================

  Future<T> ejecutarTransaccion<T>(Future<T> Function(Transaction) operaciones) async {
    final db = await database;
    return await db.transaction<T>((txn) async {
      logger.d('Ejecutando transacción');
      final result = await operaciones(txn);
      logger.d('Transacción completada');
      return result;
    });
  }

  Future<bool> existeRegistro(String tableName, String where, List<dynamic> whereArgs) async {
    final count = await contarRegistros(tableName, where: where, whereArgs: whereArgs);
    return count > 0;
  }

  Future<int> contarRegistros(String tableName, {String? where, List<dynamic>? whereArgs}) async {
    final db = await database;
    final result = await db.query(
      tableName,
      columns: ['COUNT(*) as count'],
      where: where,
      whereArgs: whereArgs,
    );
    return result.first['count'] as int;
  }

  // ================================================================
  // ADMINISTRACIÓN
  // ================================================================

  Future<void> cerrarBaseDatos() async {
    if (_database?.isOpen == true) {
      await _database!.close();
      _database = null;
      logger.i('Base de datos cerrada');
    }
  }

  Future<void> borrarBaseDatos() async {
    await cerrarBaseDatos();
    final path = join(await getDatabasesPath(), _databaseName);
    await deleteDatabase(path);
    logger.w('Base de datos eliminada');
  }

  Future<void> optimizarBaseDatos() async {
    final db = await database;
    await db.execute('VACUUM');
    await db.execute('ANALYZE');
    logger.i('Base de datos optimizada');
  }

  Future<List<String>> obtenerNombresTablas() async {
    try {
      final db = await database;
      final result = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
      );
      return result.map((row) => row['name'] as String).toList();
    } catch (e) {
      logger.e('Error al obtener nombres de tablas: $e');
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
      logger.e('Error al obtener estadísticas: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> obtenerEsquemaTabla(String tableName) async {
    try {
      final db = await database;
      return await db.rawQuery('PRAGMA table_info($tableName)');
    } catch (e) {
      logger.e('Error al obtener esquema de $tableName: $e');
      rethrow;
    }
  }

  Future<String> respaldarDatos() async {
    try {
      logger.i('Iniciando respaldo de datos');

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
        }
      };

      final jsonString = jsonEncode(backup);

      final dbPath = await getDatabasesPath();
      final file = File('$dbPath/backup_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(jsonString);

      logger.i('Respaldo completado en: ${file.path}');
      return file.path;
    } catch (e) {
      logger.e('Error en respaldo: $e');
      rethrow;
    }
  }

  // ================================================================
  // 🔥 MÉTODOS DE RESET TEMPORAL - ELIMINAR DESPUÉS DE USAR
  // ================================================================

  /// Reset completo de la base de datos y configuración
  /// ⚠️ SOLO PARA DEBUG - ELIMINAR EN PRODUCCIÓN
  static Future<void> resetCompleteDatabase() async {
    try {
      logger.w('🔥 === RESET COMPLETO DE BASE DE DATOS ===');

      // 1. Cerrar instancia actual si existe
      if (_instance != null) {
        await _instance!.cerrarBaseDatos();
        _instance = null;
        _database = null;
        logger.i('📴 Instancia actual cerrada');
      }

      // 2. Eliminar archivo de base de datos
      final path = join(await getDatabasesPath(), _databaseName);

      try {
        await deleteDatabase(path);
        logger.w('🗑️ Base de datos eliminada: $path');
      } catch (e) {
        logger.e('❌ Error eliminando BD: $e');
      }

      // 3. Eliminar archivos auxiliares
      try {
        await deleteDatabase('$path-journal');
        await deleteDatabase('$path-wal');
        await deleteDatabase('$path-shm');
        logger.i('🗑️ Archivos auxiliares eliminados');
      } catch (e) {
        // No importa si no existen
        logger.d('Archivos auxiliares no existían o ya eliminados');
      }

      // 4. Limpiar SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        logger.w('🧹 SharedPreferences limpiado');
      } catch (e) {
        logger.e('❌ Error limpiando SharedPreferences: $e');
      }

      logger.w('✅ RESET COMPLETO EXITOSO');
      logger.w('   - $_databaseName eliminada completamente');
      logger.w('   - Todas las ${_getTableCount()} tablas serán recreadas');
      logger.w('   - SharedPreferences limpiado');

    } catch (e, stackTrace) {
      logger.e('❌ Error durante reset completo: $e');
      logger.e('❌ StackTrace: $stackTrace');
      rethrow;
    }
  }

  /// Obtener número aproximado de tablas (para logging)
  static int _getTableCount() {
    // Número aproximado basado en las tablas que vimos
    return 20; // clientes, equipos, usuarios, marcas, modelos, etc.
  }

  /// Verificar que la base de datos esté completamente limpia
  static Future<Map<String, dynamic>> verificarEstadoPostReset() async {
    try {
      final helper = DatabaseHelper();
      final stats = await helper.obtenerEstadisticasBaseDatos();
      final tables = await helper.obtenerNombresTablas();

      logger.i('📊 === ESTADO POST-RESET ===');
      logger.i('   - Tablas creadas: ${tables.length}');

      int totalRegistros = 0;
      for (final entry in stats.entries) {
        final count = entry.value as int;
        totalRegistros += count;
        logger.i('   - ${entry.key}: $count registros');
      }

      logger.i('   - Total registros: $totalRegistros');

      return {
        'tablas_creadas': tables.length,
        'total_registros': totalRegistros,
        'estadisticas': stats,
        'tablas': tables,
      };

    } catch (e) {
      logger.e('❌ Error verificando estado: $e');
      return {
        'error': e.toString(),
      };
    }
  }

  // ================================================================
  // MÉTODOS PRIVADOS DE AYUDA
  // ================================================================

  void _validateValues(Map<String, dynamic> values) {
    if (values.isEmpty) {
      throw ArgumentError('Los valores no pueden estar vacíos');
    }
  }

  void _addTimestamps(String tableName, Map<String, dynamic> values, {bool isUpdate = false}) {
    if (!_requiresTimestamps(tableName)) return;

    final now = DateTime.now().toIso8601String();
    values['fecha_actualizacion'] = now;

    if (!isUpdate && !values.containsKey('fecha_creacion')) {
      values['fecha_creacion'] = now;
    }
  }
  //evitar campo fecha_actualizacion
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