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

  static const String _databaseName = 'AdaAapp.db';
  static const int _databaseVersion = 1; //incrementar cuando haya actualizacion

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

    // TABLAS MAESTRAS: modelos, marcas y logo (deben crearse primero por FK)

    await db.execute('''
      CREATE TABLE modelos (
        id INTEGER PRIMARY KEY,
        nombre TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE marcas (
        id INTEGER PRIMARY KEY,
        nombre TEXT NOT NULL UNIQUE,
        activo INTEGER DEFAULT 1,
        fecha_creacion TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE logo (
        id INTEGER PRIMARY KEY,
        nombre TEXT NOT NULL UNIQUE,
        activo INTEGER DEFAULT 1,
        fecha_creacion TEXT NOT NULL
      )
    ''');

    // Tabla clientes
    await db.execute('''
  CREATE TABLE clientes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre TEXT NOT NULL,
    telefono TEXT NOT NULL,
    direccion TEXT NOT NULL,
    ruc_ci TEXT NOT NULL,
    propietario TEXT NOT NULL
  )
''');

    // Tabla equipos CORREGIDA
    await db.execute('''
      CREATE TABLE equipos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cod_barras TEXT UNIQUE NOT NULL,
        marca_id INTEGER NOT NULL,
        modelo_id INTEGER NOT NULL,
        numero_serie TEXT UNIQUE,
        logo_id INTEGER NOT NULL,
        estado_local INTEGER DEFAULT 1,
        activo INTEGER DEFAULT 1,
        sincronizado INTEGER DEFAULT 0,
        fecha_creacion TEXT NOT NULL,
        fecha_actualizacion TEXT NOT NULL,
        FOREIGN KEY (marca_id) REFERENCES marcas (id),
        FOREIGN KEY (modelo_id) REFERENCES modelos (id),
        FOREIGN KEY (logo_id) REFERENCES logo (id)
      )
    ''');

    // Tabla equipo_cliente
    await db.execute('''
  CREATE TABLE equipo_cliente (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    equipo_id INTEGER NOT NULL,
    cliente_id INTEGER NOT NULL,
    estado TEXT NOT NULL,
    fecha_asignacion TEXT NOT NULL,
    fecha_retiro TEXT,
    activo INTEGER DEFAULT 1,
    sincronizado INTEGER DEFAULT 0,
    fecha_creacion TEXT NOT NULL,
    fecha_actualizacion TEXT NOT NULL,
    FOREIGN KEY (equipo_id) REFERENCES equipos (id) ON DELETE CASCADE,
    FOREIGN KEY (cliente_id) REFERENCES clientes (id) ON DELETE CASCADE,
    UNIQUE(equipo_id, cliente_id, fecha_asignacion),
    CHECK (estado IN ('pendiente', 'asignado'))
  )
''');
    // Tabla usuarios
    await db.execute('''
      CREATE TABLE usuarios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        rol TEXT NOT NULL,
        activo INTEGER DEFAULT 1,
        sincronizado INTEGER DEFAULT 0,
        fecha_creacion TEXT NOT NULL,
        fecha_actualizacion TEXT NOT NULL
      )
    ''');
//Tabla Estado_Equipo
    await db.execute('''
  CREATE TABLE Estado_Equipo (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  equipo_id INTEGER NOT NULL,
  id_clientes INTEGER NOT NULL,
  en_local INTEGER NOT NULL DEFAULT 0,
  latitud REAL,
  longitud REAL,
  fecha_revision TEXT NOT NULL,
  fecha_creacion TEXT NOT NULL,
  fecha_actualizacion TEXT,
  sincronizado INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY (equipo_id) REFERENCES equipos (id),
  FOREIGN KEY (id_clientes) REFERENCES clientes (id)
  )
''');
    // Crear índices para mejorar rendimiento
    await _crearIndices(db);
    logger.i('Todas las tablas, índices y datos iniciales creados exitosamente');
  }

  Future<void> _crearIndices(Database db) async {
    // Índices para clientes
    await db.execute('CREATE INDEX IF NOT EXISTS idx_clientes_nombre ON clientes (nombre)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_clientes_ruc_ci ON clientes (ruc_ci)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_clientes_propietario ON clientes (propietario)');

    // Índices para equipos
    await db.execute('CREATE INDEX IF NOT EXISTS idx_equipos_cod_barras ON equipos (cod_barras)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_equipos_numero_serie ON equipos (numero_serie)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_equipos_marca_id ON equipos (marca_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_equipos_modelo_id ON equipos (modelo_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_equipos_logo_id ON equipos (logo_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_equipos_activo ON equipos (activo)');

    // Índices para equipo_cliente
    await db.execute('CREATE INDEX IF NOT EXISTS idx_equipo_cliente_equipo_id ON equipo_cliente (equipo_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_equipo_cliente_cliente_id ON equipo_cliente (cliente_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_equipo_cliente_activo ON equipo_cliente (activo)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_equipo_cliente_estado ON equipo_cliente (estado)');

    // Índices para marcas, modelos y logo
    await db.execute('CREATE INDEX IF NOT EXISTS idx_marcas_nombre ON marcas (nombre)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_modelos_nombre ON modelos (nombre)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_logo_nombre ON logo (nombre)');
  }



  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    logger.i('Actualizando base de datos de v$oldVersion a v$newVersion');
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

      final now = DateTime.now().toIso8601String();

      // Solo agregar timestamps si la tabla los tiene
      if (await _tablaRequiereFechas(tableName)) {
        values['fecha_actualizacion'] = now;
        if (!values.containsKey('fecha_creacion')) {
          values['fecha_creacion'] = now;
        }
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

      // Solo agregar timestamp si la tabla lo requiere
      if (await _tablaRequiereFechas(tableName)) {
        values['fecha_actualizacion'] = DateTime.now().toIso8601String();
      }

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

  // Método auxiliar para saber si una tabla requiere campos de fecha
  Future<bool> _tablaRequiereFechas(String tableName) async {
    // clientes Y modelos no tienen campos de fecha
    if (tableName == 'clientes' || tableName == 'modelos') return false;
    return true;
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
  // MÉTODOS ESPECÍFICOS DEL NEGOCIO ACTUALIZADOS
  // ================================================================

  Future<List<Map<String, dynamic>>> obtenerClientesConEquipos() async {
    const sql = '''
      SELECT 
        c.*,
        COUNT(ec.equipo_id) as total_equipos
      FROM clientes c
      LEFT JOIN equipo_cliente ec ON c.id = ec.cliente_id AND ec.activo = 1
      GROUP BY c.id
      ORDER BY c.nombre
    ''';
    return await consultarPersonalizada(sql);
  }

  Future<List<Map<String, dynamic>>> obtenerEquiposDisponibles() async {
    const sql = '''
      SELECT 
        e.*,
        m.nombre as marca_nombre,
        mo.nombre as modelo_nombre,
        l.nombre as logo_nombre
      FROM equipos e
      JOIN marcas m ON e.marca_id = m.id
      JOIN modelos mo ON e.modelo_id = mo.id
      JOIN logo l ON e.logo_id = l.id
      LEFT JOIN equipo_cliente ec ON e.id = ec.equipo_id AND ec.activo = 1 AND ec.fecha_retiro IS NULL
      WHERE e.activo = 1 AND e.estado_local = 1 AND ec.equipo_id IS NULL
      ORDER BY m.nombre, mo.nombre
    ''';
    return await consultarPersonalizada(sql);
  }

  Future<List<Map<String, dynamic>>> obtenerEquiposConDetalles() async {
    const sql = '''
      SELECT 
        e.*,
        m.nombre as marca_nombre,
        mo.nombre as modelo_nombre,
        l.nombre as logo_nombre,
        CASE 
          WHEN ec.id IS NOT NULL THEN 'Asignado'
          ELSE 'Disponible'
        END as estado_asignacion,
        c.nombre as cliente_nombre
      FROM equipos e
      JOIN marcas m ON e.marca_id = m.id
      JOIN modelos mo ON e.modelo_id = mo.id
      JOIN logo l ON e.logo_id = l.id
      LEFT JOIN equipo_cliente ec ON e.id = ec.equipo_id AND ec.activo = 1 AND ec.fecha_retiro IS NULL
      LEFT JOIN clientes c ON ec.cliente_id = c.id
      WHERE e.activo = 1
      ORDER BY m.nombre, mo.nombre
    ''';
    return await consultarPersonalizada(sql);
  }

  Future<List<Map<String, dynamic>>> obtenerHistorialEquipo(int equipoId) async {
    const sql = '''
      SELECT 
        ec.*,
        c.nombre as cliente_nombre,
        c.ruc_ci as cliente_ruc_ci,
        e.numero_serie,
        m.nombre as marca_nombre,
        mo.nombre as modelo_nombre,
        l.nombre as logo_nombre
      FROM equipo_cliente ec
      JOIN clientes c ON ec.cliente_id = c.id
      JOIN equipos e ON ec.equipo_id = e.id
      JOIN marcas m ON e.marca_id = m.id
      JOIN modelos mo ON e.modelo_id = mo.id
      JOIN logo l ON e.logo_id = l.id
      WHERE ec.equipo_id = ?
      ORDER BY ec.fecha_asignacion DESC
    ''';
    return await consultarPersonalizada(sql, [equipoId]);
  }

  // ================================================================
  // MÉTODOS NUEVOS PARA SINCRONIZACIÓN
  // ================================================================

  /// Obtener marcas, modelos y logos para sincronización
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

  /// Sincronizar marcas desde API
  Future<void> sincronizarMarcas(List<dynamic> marcasAPI) async {
    await ejecutarTransaccion((txn) async {
      for (var marcaData in marcasAPI) {
        await txn.insert('marcas', {
          'id': marcaData['id'],
          'nombre': marcaData['nombre'],
          'activo': 1,
          'fecha_creacion': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  /// Sincronizar modelos desde API
  Future<void> sincronizarModelos(List<dynamic> modelosAPI) async {
    await ejecutarTransaccion((txn) async {
      int sincronizados = 0;
      int omitidos = 0;

      for (var modeloData in modelosAPI) {
        // Validar que el modelo tenga datos válidos
        if (modeloData == null) {
          omitidos++;
          continue;
        }

        final id = modeloData['id'];
        final nombre = modeloData['nombre'];

        if (id == null || nombre == null || nombre.toString().trim().isEmpty) {
          logger.w('Modelo omitido - ID: $id, Nombre: $nombre');
          omitidos++;
          continue;
        }

        try {
          await txn.insert('modelos', {
            'id': id,
            'nombre': nombre.toString().trim(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
          sincronizados++;
        } catch (e) {
          logger.e('Error insertando modelo ID $id: $e');
          omitidos++;
        }
      }

      logger.i('Modelos: $sincronizados sincronizados, $omitidos omitidos');
    });
  }

  /// Sincronizar logos desde API
  Future<void> sincronizarLogos(List<dynamic> logosAPI) async {
    await ejecutarTransaccion((txn) async {
      for (var logoData in logosAPI) {
        await txn.insert('logo', {
          'id': logoData['id'],
          'nombre': logoData['nombre'],
          'activo': 1,
          'fecha_creacion': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  // ================================================================
  // MÉTODOS DE RESPALDO Y RESTAURACIÓN
  // ================================================================

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