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
  static const int _databaseVersion = 5; // Incrementado para las nuevas tablas

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

    // NUEVAS TABLAS: marcas y logo (deben crearse primero por FK)
    await db.execute('''
      CREATE TABLE marcas (
        id INTEGER PRIMARY KEY,
        nombre TEXT NOT NULL UNIQUE,
        activo INTEGER DEFAULT 1,
        sincronizado INTEGER DEFAULT 1,
        fecha_creacion TEXT NOT NULL,
        fecha_actualizacion TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE logo (
        id INTEGER PRIMARY KEY,
        nombre TEXT NOT NULL UNIQUE,
        activo INTEGER DEFAULT 1,
        sincronizado INTEGER DEFAULT 1,
        fecha_creacion TEXT NOT NULL,
        fecha_actualizacion TEXT NOT NULL
      )
    ''');

    // Tabla clientes (actualizada)
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

    // Tabla equipos (ACTUALIZADA para coincidir con API)
    await db.execute('''
      CREATE TABLE equipos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cod_barras TEXT UNIQUE NOT NULL,
        marca_id INTEGER NOT NULL,
        modelo TEXT NOT NULL,
        numero_serie TEXT UNIQUE,
        logo_id INTEGER NOT NULL,
        estado_local INTEGER DEFAULT 1,
        activo INTEGER DEFAULT 1,
        sincronizado INTEGER DEFAULT 0,
        fecha_creacion TEXT NOT NULL,
        fecha_actualizacion TEXT NOT NULL,
        FOREIGN KEY (marca_id) REFERENCES marcas (id),
        FOREIGN KEY (logo_id) REFERENCES logo (id)
      )
    ''');

    // Tabla equipo_cliente (actualizada)
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

    // TABLA OPTIMIZADA: registros_equipos (para sincronización con /estados)
    await db.execute('''
      CREATE TABLE registros_equipos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_local INTEGER UNIQUE NOT NULL,
        servidor_id INTEGER,
        estado_sincronizacion TEXT NOT NULL DEFAULT 'pendiente',
        
        -- Datos del cliente
        cliente_id INTEGER NOT NULL,
        cliente_nombre TEXT,
        cliente_direccion TEXT,
        cliente_telefono TEXT,
        
        -- Datos del equipo
        equipo_id INTEGER,
        codigo_barras TEXT,
        modelo TEXT,
        marca_id INTEGER,
        numero_serie TEXT,
        logo_id INTEGER,
        observaciones TEXT,
        
        -- Datos de ubicación
        latitud REAL,
        longitud REAL,
        fecha_registro TEXT,
        timestamp_gps TEXT,
        
        -- Datos para API (/estados)
        funcionando INTEGER DEFAULT 1,
        estado_general TEXT DEFAULT 'Revisión pendiente',
        temperatura_actual REAL,
        temperatura_freezer REAL,
        
        -- Metadatos
        version_app TEXT,
        dispositivo TEXT,
        fecha_creacion TEXT NOT NULL,
        fecha_actualizacion TEXT NOT NULL,
        
        FOREIGN KEY (cliente_id) REFERENCES clientes (id) ON DELETE CASCADE,
        FOREIGN KEY (equipo_id) REFERENCES equipos (id) ON DELETE SET NULL,
        FOREIGN KEY (marca_id) REFERENCES marcas (id),
        FOREIGN KEY (logo_id) REFERENCES logo (id)
      )
    ''');

    // Crear índices para mejorar rendimiento
    await _crearIndices(db);

    // Insertar datos iniciales
    await _insertarDatosIniciales(db);

    logger.i('Todas las tablas, índices y datos iniciales creados exitosamente');
  }

  Future<void> _crearIndices(Database db) async {
    // Índices existentes optimizados
    await db.execute('CREATE INDEX IF NOT EXISTS idx_clientes_email ON clientes (email)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_clientes_activo ON clientes (activo)');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_equipos_cod_barras ON equipos (cod_barras)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_equipos_numero_serie ON equipos (numero_serie)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_equipos_marca_id ON equipos (marca_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_equipos_logo_id ON equipos (logo_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_equipos_activo ON equipos (activo)');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_equipo_cliente_equipo_id ON equipo_cliente (equipo_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_equipo_cliente_cliente_id ON equipo_cliente (cliente_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_equipo_cliente_activo ON equipo_cliente (activo)');

// Nuevos índices para registros_equipos
    await db.execute('CREATE INDEX IF NOT EXISTS idx_registros_estado_sincronizacion ON registros_equipos(estado_sincronizacion)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_registros_cliente_id ON registros_equipos(cliente_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_registros_codigo_barras ON registros_equipos(codigo_barras)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_registros_id_local ON registros_equipos(id_local)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_registros_fecha_registro ON registros_equipos(fecha_registro)');

// Índices para marcas y logo
    await db.execute('CREATE INDEX IF NOT EXISTS idx_marcas_nombre ON marcas (nombre)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_logo_nombre ON logo (nombre)');
  }

  Future<void> _insertarDatosIniciales(Database db) async {
    final now = DateTime.now().toIso8601String();

    // Insertar marcas iniciales (coincidentes con tu API)
    final marcas = [
      {'id': 1, 'nombre': 'Samsung'},
      {'id': 2, 'nombre': 'LG'},
      {'id': 3, 'nombre': 'Whirlpool'},
      {'id': 4, 'nombre': 'Electrolux'},
      {'id': 5, 'nombre': 'Panasonic'},
      {'id': 6, 'nombre': 'Midea'},
      {'id': 7, 'nombre': 'Bosch'},
      {'id': 8, 'nombre': 'Daewoo'},
      {'id': 9, 'nombre': 'GE'},
      {'id': 10, 'nombre': 'Sharp'},
      {'id': 11, 'nombre': 'Frigidaire'},
      {'id': 12, 'nombre': 'Hisense'},
      {'id': 13, 'nombre': 'Philco'},
      {'id': 14, 'nombre': 'Beko'},
      {'id': 15, 'nombre': 'Koblenz'},
    ];

    // Insertar logos iniciales (coincidentes con tu API)
    final logos = [
      {'id': 1, 'nombre': 'Pulp'},
      {'id': 2, 'nombre': 'Pepsi'},
      {'id': 3, 'nombre': 'Paso de los Toros'},
      {'id': 4, 'nombre': 'Mirinda'},
      {'id': 5, 'nombre': '7Up'},
      {'id': 6, 'nombre': 'Split'},
      {'id': 7, 'nombre': 'Watts'},
      {'id': 8, 'nombre': 'Puro Sol'},
      {'id': 9, 'nombre': 'La Fuente'},
      {'id': 10, 'nombre': 'Aquafina'},
      {'id': 11, 'nombre': 'Gatorade'},
      {'id': 12, 'nombre': 'Red Bull'},
      {'id': 13, 'nombre': 'Rockstar'},
    ];

    for (final marca in marcas) {
      await db.insert('marcas', {
        ...marca,
        'activo': 1,
        'sincronizado': 1,
        'fecha_creacion': now,
        'fecha_actualizacion': now,
      });
    }

    for (final logo in logos) {
      await db.insert('logo', {
        ...logo,
        'activo': 1,
        'sincronizado': 1,
        'fecha_creacion': now,
        'fecha_actualizacion': now,
      });
    }

    logger.i('Datos iniciales insertados: ${marcas.length} marcas, ${logos.length} logos');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    logger.i('Actualizando base de datos de v$oldVersion a v$newVersion');

    if (oldVersion < 5) {
      // Crear nuevas tablas si no existen
      await db.execute('''
        CREATE TABLE IF NOT EXISTS marcas (
          id INTEGER PRIMARY KEY,
          nombre TEXT NOT NULL UNIQUE,
          activo INTEGER DEFAULT 1,
          sincronizado INTEGER DEFAULT 1,
          fecha_creacion TEXT NOT NULL,
          fecha_actualizacion TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS logo (
          id INTEGER PRIMARY KEY,
          nombre TEXT NOT NULL UNIQUE,
          activo INTEGER DEFAULT 1,
          sincronizado INTEGER DEFAULT 1,
          fecha_creacion TEXT NOT NULL,
          fecha_actualizacion TEXT NOT NULL
        )
      ''');

      // Actualizar tabla equipos
      try {
        // Renombrar tabla equipos existente
        await db.execute('ALTER TABLE equipos RENAME TO equipos_old');

        // Crear nueva tabla equipos
        await db.execute('''
          CREATE TABLE equipos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            cod_barras TEXT UNIQUE NOT NULL,
            marca_id INTEGER NOT NULL,
            modelo TEXT NOT NULL,
            numero_serie TEXT UNIQUE,
            logo_id INTEGER NOT NULL,
            estado_local INTEGER DEFAULT 1,
            activo INTEGER DEFAULT 1,
            sincronizado INTEGER DEFAULT 0,
            fecha_creacion TEXT NOT NULL,
            fecha_actualizacion TEXT NOT NULL,
            FOREIGN KEY (marca_id) REFERENCES marcas (id),
            FOREIGN KEY (logo_id) REFERENCES logo (id)
          )
        ''');

        // Insertar datos iniciales antes de migrar
        await _insertarDatosIniciales(db);

        // Migrar datos existentes (si existen)
        final equiposExistentes = await db.query('equipos_old WHERE activo = 1');
        for (final equipo in equiposExistentes) {
          // Mapear marca texto a marca_id (buscar en tabla marcas)
          final marcaTexto = equipo['marca'] as String?;
          int marcaId = 1; // Default Samsung
          if (marcaTexto != null) {
            final marcaResult = await db.query(
                'marcas',
                where: 'LOWER(nombre) = LOWER(?)',
                whereArgs: [marcaTexto]
            );
            if (marcaResult.isNotEmpty) {
              marcaId = marcaResult.first['id'] as int;
            }
          }

          await db.insert('equipos', {
            'id': equipo['id'],
            'cod_barras': equipo['cod_barras'] ?? 'REF${equipo['id']?.toString().padLeft(3, '0')}',
            'marca_id': marcaId,
            'modelo': equipo['modelo'] ?? 'Modelo Desconocido',
            'numero_serie': equipo['numero_serie'],
            'logo_id': 1, // Default Pulp
            'estado_local': 1,
            'activo': equipo['activo'] ?? 1,
            'sincronizado': 0,
            'fecha_creacion': equipo['fecha_creacion'] ?? DateTime.now().toIso8601String(),
            'fecha_actualizacion': DateTime.now().toIso8601String(),
          });
        }

        // Eliminar tabla antigua
        await db.execute('DROP TABLE IF EXISTS equipos_old');

      } catch (e) {
        logger.w('Error en migración de equipos: $e. Creando tabla limpia.');
      }

      // Crear nuevos índices
      await _crearIndices(db);
    }
  }

  // ================================================================
  // MÉTODOS CRUD GENÉRICOS CON MEJORAS (SIN CAMBIOS)
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
  // MÉTODOS ESPECÍFICOS DEL NEGOCIO ACTUALIZADOS
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
      SELECT 
        e.*,
        m.nombre as marca_nombre,
        l.nombre as logo_nombre
      FROM equipos e
      JOIN marcas m ON e.marca_id = m.id
      JOIN logo l ON e.logo_id = l.id
      LEFT JOIN equipo_cliente ec ON e.id = ec.equipo_id AND ec.activo = 1 AND ec.fecha_retiro IS NULL
      WHERE e.activo = 1 AND e.estado_local = 1 AND ec.equipo_id IS NULL
      ORDER BY m.nombre, e.modelo
    ''';
    return await consultarPersonalizada(sql);
  }

  Future<List<Map<String, dynamic>>> obtenerEquiposConDetalles() async {
    const sql = '''
      SELECT 
        e.*,
        m.nombre as marca_nombre,
        l.nombre as logo_nombre,
        CASE 
          WHEN ec.id IS NOT NULL THEN 'Asignado'
          ELSE 'Disponible'
        END as estado_asignacion,
        c.nombre as cliente_nombre
      FROM equipos e
      JOIN marcas m ON e.marca_id = m.id
      JOIN logo l ON e.logo_id = l.id
      LEFT JOIN equipo_cliente ec ON e.id = ec.equipo_id AND ec.activo = 1 AND ec.fecha_retiro IS NULL
      LEFT JOIN clientes c ON ec.cliente_id = c.id
      WHERE e.activo = 1
      ORDER BY m.nombre, e.modelo
    ''';
    return await consultarPersonalizada(sql);
  }

  Future<List<Map<String, dynamic>>> obtenerHistorialEquipo(int equipoId) async {
    const sql = '''
      SELECT 
        ec.*,
        c.nombre as cliente_nombre,
        c.email as cliente_email,
        e.modelo,
        e.numero_serie,
        m.nombre as marca_nombre,
        l.nombre as logo_nombre
      FROM equipo_cliente ec
      JOIN clientes c ON ec.cliente_id = c.id
      JOIN equipos e ON ec.equipo_id = e.id
      JOIN marcas m ON e.marca_id = m.id
      JOIN logo l ON e.logo_id = l.id
      WHERE ec.equipo_id = ?
      ORDER BY ec.fecha_asignacion DESC
    ''';
    return await consultarPersonalizada(sql, [equipoId]);
  }

  // ================================================================
  // MÉTODOS NUEVOS PARA SINCRONIZACIÓN
  // ================================================================

  /// Obtener marcas y logos para sincronización
  Future<Map<String, List<Map<String, dynamic>>>> obtenerMarcasYLogos() async {
    final marcas = await consultar('marcas', where: 'activo = ?', whereArgs: [1], orderBy: 'nombre');
    final logos = await consultar('logo', where: 'activo = ?', whereArgs: [1], orderBy: 'nombre');

    return {
      'marcas': marcas,
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
          'sincronizado': 1,
          'fecha_creacion': DateTime.now().toIso8601String(),
          'fecha_actualizacion': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
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
          'sincronizado': 1,
          'fecha_creacion': DateTime.now().toIso8601String(),
          'fecha_actualizacion': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  // ================================================================
  // MÉTODOS DE RESPALDO Y RESTAURACIÓN (SIN CAMBIOS)
  // ================================================================

  Future<String> respaldarDatos() async {
    try {
      logger.i('Iniciando respaldo de datos');

      final clientes = await consultar('clientes');
      final equipos = await consultarPersonalizada('''
        SELECT e.*, m.nombre as marca_nombre, l.nombre as logo_nombre
        FROM equipos e
        JOIN marcas m ON e.marca_id = m.id
        JOIN logo l ON e.logo_id = l.id
      ''');
      final equipoCliente = await consultar('equipo_cliente');
      final marcas = await consultar('marcas');
      final logos = await consultar('logo');

      final backup = {
        'version': _databaseVersion,
        'timestamp': DateTime.now().toIso8601String(),
        'data': {
          'clientes': clientes,
          'equipos': equipos,
          'equipo_cliente': equipoCliente,
          'marcas': marcas,
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
  // MÉTODOS DE UTILIDAD (SIN CAMBIOS MAYORES)
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