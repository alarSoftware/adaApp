import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:logger/logger.dart';

var logger = Logger();

class DatabaseHelper {
  static DatabaseHelper? _instance;
  static Database? _database;

  static const String _databaseName = 'clientes_app.db';
  static const int _databaseVersion = 3;

  DatabaseHelper._internal();

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
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onOpen: (db) {
          logger.i('Base de datos abierta exitosamente');
        },
      );
    } catch (e) {
      logger.e('Error al inicializar base de datos: $e');
      rethrow;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    logger.i('Creando tablas de base de datos v$version');

    await db.execute('''
      CREATE TABLE clientes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        email TEXT UNIQUE,
        telefono TEXT,
        direccion TEXT,
        activo INTEGER DEFAULT 1,
        sincronizado INTEGER DEFAULT 0,
        fecha_creacion TEXT NOT NULL,
        fecha_actualizacion TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE equipos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cod_barras TEXT UNIQUE,
        numero_serie TEXT UNIQUE,
        marca TEXT NOT NULL,
        modelo TEXT NOT NULL,
        tipo_equipo TEXT NOT NULL,
        activo INTEGER DEFAULT 1,
        sincronizado INTEGER DEFAULT 0,
        fecha_creacion TEXT NOT NULL,
        fecha_actualizacion TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE equipo_cliente (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        equipo_id INTEGER NOT NULL,
        cliente_id INTEGER NOT NULL,
        fecha_asignacion TEXT NOT NULL,
        fecha_retiro TEXT,
        activo INTEGER DEFAULT 1,
        sincronizado INTEGER DEFAULT 0,
        fecha_creacion TEXT NOT NULL,
        fecha_actualizacion TEXT NOT NULL,
        FOREIGN KEY (equipo_id) REFERENCES equipos (id) ON DELETE CASCADE,
        FOREIGN KEY (cliente_id) REFERENCES clientes (id) ON DELETE CASCADE,
        UNIQUE(equipo_id, cliente_id, fecha_asignacion)
      )
    ''');

    // Crear índices para mejorar rendimiento
    await db.execute('CREATE INDEX idx_clientes_email ON clientes (email)');
    await db.execute('CREATE INDEX idx_equipos_cod_barras ON equipos (cod_barras)');
    await db.execute('CREATE INDEX idx_equipos_numero_serie ON equipos (numero_serie)');
    await db.execute('CREATE INDEX idx_equipo_cliente_equipo_id ON equipo_cliente (equipo_id)');
    await db.execute('CREATE INDEX idx_equipo_cliente_cliente_id ON equipo_cliente (cliente_id)');

    logger.i('Tablas e índices creados exitosamente');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    logger.i('Actualizando base de datos de v$oldVersion a v$newVersion');

    // Ejemplo de migración para futuras versiones
    if (oldVersion < 2) {
      // await db.execute('ALTER TABLE clientes ADD COLUMN nueva_columna TEXT');
    }
    if (oldVersion < 3) {
      // await db.execute('CREATE INDEX nueva_index ON tabla (columna)');
    }
  }

  // ================================================================
  // MÉTODOS CRUD GENÉRICOS CON MEJORAS
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
      logger.d('Consulta en $tableName: ${result.length} registros encontrados');
      return result;
    } catch (e) {
      logger.e('Error al consultar $tableName: $e');
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
    try {
      final result = await consultar(tableName, where: 'id = ?', whereArgs: [id]);
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      logger.e('Error al consultar por ID en $tableName: $e');
      rethrow;
    }
  }

  Future<int> insertar(String tableName, Map<String, dynamic> values) async {
    try {
      if (values.isEmpty) {
        throw ArgumentError('Los valores no pueden estar vacíos');
      }

      // Agregar timestamps automáticamente
      final now = DateTime.now().toIso8601String();
      values['fecha_actualizacion'] = now;
      if (!values.containsKey('fecha_creacion')) {
        values['fecha_creacion'] = now;
      }

      final db = await database;
      final id = await db.insert(tableName, values);
      logger.d('Registro insertado en $tableName con ID: $id');
      return id;
    } catch (e) {
      logger.e('Error al insertar en $tableName: $e');
      rethrow;
    }
  }

  Future<int> actualizar(
      String tableName,
      Map<String, dynamic> values, {
        String? where,
        List<dynamic>? whereArgs,
      }) async {
    try {
      if (values.isEmpty) {
        throw ArgumentError('Los valores no pueden estar vacíos');
      }

      // Actualizar timestamp automáticamente
      values['fecha_actualizacion'] = DateTime.now().toIso8601String();

      final db = await database;
      final count = await db.update(
        tableName,
        values,
        where: where,
        whereArgs: whereArgs,
      );
      logger.d('$count registros actualizados en $tableName');
      return count;
    } catch (e) {
      logger.e('Error al actualizar $tableName: $e');
      rethrow;
    }
  }

  Future<int> eliminar(
      String tableName, {
        String? where,
        List<dynamic>? whereArgs,
      }) async {
    try {
      final db = await database;
      final count = await db.delete(
        tableName,
        where: where,
        whereArgs: whereArgs,
      );
      logger.d('$count registros eliminados de $tableName');
      return count;
    } catch (e) {
      logger.e('Error al eliminar de $tableName: $e');
      rethrow;
    }
  }

  Future<int> eliminarPorId(String tableName, int id) async {
    return await eliminar(tableName, where: 'id = ?', whereArgs: [id]);
  }

  // ================================================================
  // MÉTODOS DE TRANSACCIONES
  // ================================================================

  Future<T> ejecutarTransaccion<T>(Future<T> Function(Transaction) operaciones) async {
    try {
      final db = await database;
      return await db.transaction<T>((txn) async {
        logger.d('Iniciando transacción');
        final result = await operaciones(txn);
        logger.d('Transacción completada exitosamente');
        return result;
      });
    } catch (e) {
      logger.e('Error en transacción: $e');
      rethrow;
    }
  }

  // ================================================================
  // MÉTODOS DE RESPALDO Y RESTAURACIÓN
  // ================================================================

  Future<String> respaldarDatos() async {
    try {
      logger.i('Iniciando respaldo de datos');

      final clientes = await consultar('clientes');
      final equipos = await consultar('equipos');
      final equipoCliente = await consultar('equipo_cliente');

      final backup = {
        'version': _databaseVersion,
        'timestamp': DateTime.now().toIso8601String(),
        'data': {
          'clientes': clientes,
          'equipos': equipos,
          'equipo_cliente': equipoCliente,
        }
      };

      final jsonString = jsonEncode(backup);

      // Guardar en el mismo directorio de la base de datos
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

  Future<void> restaurarDatos(String backupPath) async {
    try {
      logger.i('Iniciando restauración de datos desde: $backupPath');

      final file = File(backupPath);
      if (!await file.exists()) {
        throw Exception('El archivo de respaldo no existe');
      }

      final jsonString = await file.readAsString();
      final backup = jsonDecode(jsonString) as Map<String, dynamic>;

      await ejecutarTransaccion((txn) async {
        // Limpiar tablas existentes
        await txn.delete('equipo_cliente');
        await txn.delete('equipos');
        await txn.delete('clientes');

        // Restaurar datos
        final data = backup['data'] as Map<String, dynamic>;

        for (final cliente in data['clientes'] as List) {
          await txn.insert('clientes', cliente);
        }

        for (final equipo in data['equipos'] as List) {
          await txn.insert('equipos', equipo);
        }

        for (final ec in data['equipo_cliente'] as List) {
          await txn.insert('equipo_cliente', ec);
        }
      });

      logger.i('Restauración completada exitosamente');
    } catch (e) {
      logger.e('Error en restauración: $e');
      rethrow;
    }
  }

  // ================================================================
  // MÉTODOS DE UTILIDAD
  // ================================================================

  Future<List<Map<String, dynamic>>> obtenerEsquemaTabla(String tableName) async {
    try {
      final db = await database;
      return await db.rawQuery('PRAGMA table_info($tableName)');
    } catch (e) {
      logger.e('Error al obtener esquema de $tableName: $e');
      rethrow;
    }
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

  Future<int> contarRegistros(String tableName, {String? where, List<dynamic>? whereArgs}) async {
    try {
      final db = await database;
      final result = await db.query(
        tableName,
        columns: ['COUNT(*) as count'],
        where: where,
        whereArgs: whereArgs,
      );
      return result.first['count'] as int;
    } catch (e) {
      logger.e('Error al contar registros en $tableName: $e');
      rethrow;
    }
  }

  Future<bool> existeRegistro(String tableName, String where, List<dynamic> whereArgs) async {
    try {
      final count = await contarRegistros(tableName, where: where, whereArgs: whereArgs);
      return count > 0;
    } catch (e) {
      logger.e('Error al verificar existencia en $tableName: $e');
      rethrow;
    }
  }

  // ================================================================
  // MÉTODOS ESPECÍFICOS DEL NEGOCIO
  // ================================================================

  Future<List<Map<String, dynamic>>> obtenerClientesConEquipos() async {
    const sql = '''
      SELECT 
        c.*,
        COUNT(ec.equipo_id) as total_equipos
      FROM clientes c
      LEFT JOIN equipo_cliente ec ON c.id = ec.cliente_id AND ec.activo = 1
      WHERE c.activo = 1
      GROUP BY c.id
      ORDER BY c.nombre
    ''';
    return await consultarPersonalizada(sql);
  }

  Future<List<Map<String, dynamic>>> obtenerEquiposDisponibles() async {
    const sql = '''
      SELECT e.*
      FROM equipos e
      LEFT JOIN equipo_cliente ec ON e.id = ec.equipo_id AND ec.activo = 1 AND ec.fecha_retiro IS NULL
      WHERE e.activo = 1 AND ec.equipo_id IS NULL
      ORDER BY e.marca, e.modelo
    ''';
    return await consultarPersonalizada(sql);
  }

  Future<List<Map<String, dynamic>>> obtenerHistorialEquipo(int equipoId) async {
    const sql = '''
      SELECT 
        ec.*,
        c.nombre as cliente_nombre,
        c.email as cliente_email,
        e.marca,
        e.modelo,
        e.numero_serie
      FROM equipo_cliente ec
      JOIN clientes c ON ec.cliente_id = c.id
      JOIN equipos e ON ec.equipo_id = e.id
      WHERE ec.equipo_id = ?
      ORDER BY ec.fecha_asignacion DESC
    ''';
    return await consultarPersonalizada(sql, [equipoId]);
  }

  // ================================================================
  // ADMINISTRACIÓN DE BASE DE DATOS
  // ================================================================

  Future<void> cerrarBaseDatos() async {
    try {
      final db = _database;
      if (db != null && db.isOpen) {
        await db.close();
        _database = null;
        logger.i('Base de datos cerrada exitosamente');
      }
    } catch (e) {
      logger.e('Error al cerrar base de datos: $e');
      rethrow;
    }
  }

  Future<void> borrarBaseDatos() async {
    try {
      await cerrarBaseDatos();
      final path = join(await getDatabasesPath(), _databaseName);
      await deleteDatabase(path);
      logger.w('Base de datos eliminada: $path');
    } catch (e) {
      logger.e('Error al borrar base de datos: $e');
      rethrow;
    }
  }

  Future<void> optimizarBaseDatos() async {
    try {
      final db = await database;
      await db.execute('VACUUM');
      await db.execute('ANALYZE');
      logger.i('Base de datos optimizada');
    } catch (e) {
      logger.e('Error al optimizar base de datos: $e');
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

      // Información adicional de la base de datos
      final db = await database;
      final pragmaResult = await db.rawQuery('PRAGMA database_list');
      estadisticas['info_db'] = pragmaResult;

      return estadisticas;
    } catch (e) {
      logger.e('Error al obtener estadísticas: $e');
      rethrow;
    }
  }
}