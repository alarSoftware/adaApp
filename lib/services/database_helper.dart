import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:logger/logger.dart';
import '../models/cliente.dart';
import '../models/equipos.dart';  // Asegúrate de importar el modelo Equipo

var logger = Logger();

class DatabaseHelper {
  static DatabaseHelper? _instance;
  static Database? _database;

  // Configuración
  static const String _databaseName = 'AdaApp';
  static const int _databaseVersion = 1;

  DatabaseHelper._internal();
  factory DatabaseHelper() => _instance ??= DatabaseHelper._internal();
  // ESQUEMAS DE TABLAS

  static const Map<String, Map<String, dynamic>> _tablesSchema = {
    'clientes': {
      'columns': '''
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        telefono TEXT,
        direccion TEXT,
        activo INTEGER DEFAULT 1,
        fecha_creacion TEXT NOT NULL,
        fecha_actualizacion TEXT,
        sincronizado INTEGER DEFAULT 0
      ''',
      'indexes': [
        'CREATE INDEX idx_clientes_email ON clientes(email)',
        'CREATE INDEX idx_clientes_nombre ON clientes(nombre)',
        'CREATE INDEX idx_clientes_activo ON clientes(activo)'
      ]
    },

    'equipos': {
      'columns': '''
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cod_barras TEXT NOT NULL UNIQUE,
        marca TEXT NOT NULL,
        modelo TEXT NOT NULL,
        tipo_equipo TEXT NOT NULL,
        activo INTEGER DEFAULT 1,
        fecha_creacion TEXT NOT NULL,
        fecha_actualizacion TEXT,
        sincronizado INTEGER DEFAULT 0
      ''',
      'indexes': [
        'CREATE INDEX idx_equipos_cod_barras ON equipos(cod_barras)',
        'CREATE INDEX idx_equipos_marca ON equipos(marca)',
        'CREATE INDEX idx_equipos_tipo ON equipos(tipo_equipo)'
      ]
    },

    'usuarios': {
      'columns': '''
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        contraseña TEXT NOT NULL,
        rol TEXT NOT NULL,
        activo INTEGER DEFAULT 1,
        fecha_creacion TEXT NOT NULL,
        fecha_actualizacion TEXT,
        sincronizado INTEGER DEFAULT 0
      ''',
      'indexes': [
        'CREATE INDEX idx_usuarios_email ON usuarios(email)',
        'CREATE INDEX idx_usuarios_rol ON usuarios(rol)',
        'CREATE INDEX idx_usuarios_activo ON usuarios(activo)'
      ]
    },

    'equipo_cliente': {
      'columns': '''
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        equipo_id INTEGER NOT NULL,
        cliente_id INTEGER NOT NULL,
        fecha_asignacion TEXT NOT NULL,
        fecha_retiro TEXT,
        activo INTEGER DEFAULT 1,
        fecha_creacion TEXT NOT NULL,
        FOREIGN KEY (equipo_id) REFERENCES equipos (id),
        FOREIGN KEY (cliente_id) REFERENCES clientes (id)
      ''',
      'indexes': [
        'CREATE INDEX idx_equipo_cliente_equipo ON equipo_cliente(equipo_id)',
        'CREATE INDEX idx_equipo_cliente_cliente ON equipo_cliente(cliente_id)',
        'CREATE INDEX idx_equipo_cliente_activo ON equipo_cliente(activo)'
      ]
    },

    'estado_equipo': {
      'columns': '''
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        equipo_id INTEGER NOT NULL,
        cliente_id INTEGER NOT NULL,
        usuario_id INTEGER NOT NULL,
        funcionando INTEGER NOT NULL DEFAULT 1,
        estado_general TEXT,
        temperatura_actual REAL,
        temperatura_freezer REAL,
        latitud REAL,
        longitud REAL,
        fecha_revision TEXT NOT NULL,
        fecha_creacion TEXT NOT NULL,
        sincronizado INTEGER DEFAULT 0,
        FOREIGN KEY (equipo_id) REFERENCES equipos (id),
        FOREIGN KEY (cliente_id) REFERENCES clientes (id),
        FOREIGN KEY (usuario_id) REFERENCES usuarios (id)
      ''',
      'indexes': [
        'CREATE INDEX idx_estado_equipo_equipo ON estado_equipo(equipo_id)',
        'CREATE INDEX idx_estado_equipo_cliente ON estado_equipo(cliente_id)',
        'CREATE INDEX idx_estado_equipo_usuario ON estado_equipo(usuario_id)',
        'CREATE INDEX idx_estado_equipo_fecha ON estado_equipo(fecha_revision)',
        'CREATE INDEX idx_estado_equipo_funcionando ON estado_equipo(funcionando)'
      ]
    }
  };

  // ════════════════════════════════════════════════════════════════
  // INICIALIZACIÓN DE BASE DE DATOS
  // ════════════════════════════════════════════════════════════════

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    logger.i('📂 Inicializando base de datos en: $path');

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
      onOpen: (db) async {
        logger.i('🔓 Base de datos abierta correctamente');
        await _verificarIntegridad(db);
      },
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    logger.i('🆕 Creando base de datos versión $version');

    // Crear todas las tablas usando el esquema
    for (String tableName in _tablesSchema.keys) {
      await _createTable(db, tableName);
    }

    logger.i('✅ Base de datos creada con ${_tablesSchema.length} tablas e índices');
  }

  Future<void> _createTable(Database db, String tableName) async {
    final schema = _tablesSchema[tableName];
    if (schema == null) return;

    // Crear tabla
    await db.execute('CREATE TABLE $tableName(${schema['columns']})');
    logger.i('📋 Tabla $tableName creada');

    // Crear índices
    final indexes = schema['indexes'] as List<String>?;
    if (indexes != null) {
      for (String indexSql in indexes) {
        await db.execute(indexSql);
      }
      logger.i('📊 ${indexes.length} índices creados para $tableName');
    }
  }

  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    logger.i('🔄 Actualizando base de datos de versión $oldVersion a $newVersion');

    // Aquí puedes manejar migraciones específicas por versión
    for (int version = oldVersion + 1; version <= newVersion; version++) {
      await _migrateToVersion(db, version);
    }

    logger.i('✅ Base de datos actualizada');
  }

  Future<void> _migrateToVersion(Database db, int version) async {
    switch (version) {
      case 2:
      // Ejemplo de migración a versión 2
        await db.execute('ALTER TABLE clientes ADD COLUMN campo_nuevo TEXT');
        break;
      case 3:
      // Ejemplo de migración a versión 3
        await _createTable(db, 'nueva_tabla');
        break;
    // Agregar más casos según necesites
    }
  }

  Future<void> _verificarIntegridad(Database db) async {
    try {
      final result = await db.rawQuery('PRAGMA integrity_check');
      if (result.first['integrity_check'] == 'ok') {
        logger.i('✅ Integridad de base de datos verificada');
      } else {
        logger.w('⚠️ Problemas de integridad detectados');
      }
    } catch (e) {
      logger.w('⚠️ No se pudo verificar integridad: $e');
    }
  }

  // ════════════════════════════════════════════════════════════════
  // MÉTODOS GENÉRICOS CRUD
  // ════════════════════════════════════════════════════════════════

  Future<int> insertar(String tabla, Map<String, dynamic> valores,
      {ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.replace}) async {
    final db = await database;
    return await db.insert(tabla, valores, conflictAlgorithm: conflictAlgorithm);
  }

  Future<int> actualizar(String tabla, Map<String, dynamic> valores,
      {String? where, List<dynamic>? whereArgs}) async {
    final db = await database;
    return await db.update(tabla, valores, where: where, whereArgs: whereArgs);
  }

  Future<int> eliminar(String tabla, {String? where, List<dynamic>? whereArgs}) async {
    final db = await database;
    return await db.delete(tabla, where: where, whereArgs: whereArgs);
  }

  Future<List<Map<String, dynamic>>> consultar(
      String tabla, {
        String? where,
        List<dynamic>? whereArgs,
        String? orderBy,
        int? limit,
        String? groupBy,
        String? having,
      }) async {
    final db = await database;
    return await db.query(
      tabla,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
      groupBy: groupBy,
      having: having,
    );
  }

  Future<List<Map<String, dynamic>>> consultarPersonalizada(String sql, [List<dynamic>? args]) async {
    final db = await database;
    return await db.rawQuery(sql, args);
  }

  // ════════════════════════════════════════════════════════════════
  // MÉTODOS DE ADMINISTRACIÓN
  // ════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> obtenerEstadisticasGenerales() async {
    final db = await database;
    Map<String, dynamic> stats = {};

    for (String tableName in _tablesSchema.keys) {
      final total = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM $tableName')) ?? 0;

      // Para tablas que tienen campo 'activo'
      if (_tablesSchema[tableName]?['columns'].toString().contains('activo') == true) {
        final activos = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM $tableName WHERE activo = 1')) ?? 0;
        final inactivos = total - activos;

        stats[tableName] = {
          'total': total,
          'activos': activos,
          'inactivos': inactivos,
        };
      } else {
        stats[tableName] = {'total': total};
      }
    }

    stats['ultima_actualizacion'] = DateTime.now().toIso8601String();
    return stats;
  }

  Future<void> reiniciarBaseDeDatos() async {
    try {
      await close();
      String path = join(await getDatabasesPath(), _databaseName);
      await deleteDatabase(path);
      _database = null;
      logger.i('🔄 Base de datos reiniciada');
    } catch (e) {
      logger.e('❌ Error reiniciando base de datos: $e');
      throw Exception('Error reiniciando base de datos: $e');
    }
  }

  Future<List<String>> obtenerTablas() async {
    final db = await database;
    final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'");
    return result.map((row) => row['name'] as String).toList();
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      logger.i('🔒 Base de datos cerrada');
    }
  }

  // ════════════════════════════════════════════════════════════════
  // MÉTODOS ESPECÍFICOS PARA CLIENTES
  // ════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> obtenerTodosLosClientes({bool soloActivos = true}) async {
    return await consultar(
      'clientes',
      where: soloActivos ? 'activo = ?' : null,
      whereArgs: soloActivos ? [1] : null,
      orderBy: 'nombre ASC',
    );
  }

  Future<List<Map<String, dynamic>>> buscarClientes(String query) async {
    final searchTerm = '%${query.toLowerCase()}%';
    return await consultar(
      'clientes',
      where: 'activo = ? AND (LOWER(nombre) LIKE ? OR LOWER(email) LIKE ? OR telefono LIKE ?)',
      whereArgs: [1, searchTerm, searchTerm, searchTerm],
      orderBy: 'nombre ASC',
      limit: 50,
    );
  }

  Future<int> insertarCliente(Map<String, dynamic> clienteData) async {
    final datos = Map<String, dynamic>.from(clienteData);
    datos['fecha_actualizacion'] = DateTime.now().toIso8601String();
    datos['sincronizado'] = 0;
    return await insertar('clientes', datos);
  }

  Future<int> actualizarCliente(Map<String, dynamic> clienteData, int id) async {
    final datos = Map<String, dynamic>.from(clienteData);
    datos['fecha_actualizacion'] = DateTime.now().toIso8601String();
    datos['sincronizado'] = 0;
    return await actualizar('clientes', datos, where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>?> obtenerClientePorEmail(String email) async {
    final maps = await consultar(
      'clientes',
      where: 'email = ? AND activo = ?',
      whereArgs: [email, 1],
      limit: 1,
    );
    return maps.isNotEmpty ? maps.first : null;
  }

  Future<Map<String, dynamic>?> obtenerClientePorId(int id) async {
    final maps = await consultar(
      'clientes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return maps.isNotEmpty ? maps.first : null;
  }

  Future<bool> existeEmail(String email) async {
    final maps = await consultar(
      'clientes',
      where: 'email = ? AND activo = ?',
      whereArgs: [email, 1],
      limit: 1,
    );
    return maps.isNotEmpty;
  }

  // ════════════════════════════════════════════════════════════════
  // MÉTODOS ESPECÍFICOS PARA EQUIPOS
  // ════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> obtenerTodosLosEquipos({bool soloActivos = true}) async {
    return await consultar(
      'equipos',
      where: soloActivos ? 'activo = ?' : null,
      whereArgs: soloActivos ? [1] : null,
      orderBy: 'marca ASC, modelo ASC',
    );
  }

  Future<List<Map<String, dynamic>>> buscarEquipos(String query) async {
    final searchTerm = '%${query.toLowerCase()}%';
    return await consultar(
      'equipos',
      where: 'activo = ? AND (LOWER(cod_barras) LIKE ? OR LOWER(marca) LIKE ? OR LOWER(modelo) LIKE ? OR LOWER(tipo_equipo) LIKE ?)',
      whereArgs: [1, searchTerm, searchTerm, searchTerm, searchTerm],
      orderBy: 'marca ASC, modelo ASC',
      limit: 50,
    );
  }

  Future<int> insertarEquipo(Map<String, dynamic> equipoData) async {
    final datos = Map<String, dynamic>.from(equipoData);
    datos['fecha_actualizacion'] = DateTime.now().toIso8601String();
    datos['sincronizado'] = 0;
    return await insertar('equipos', datos);
  }

  Future<int> actualizarEquipo(Map<String, dynamic> equipoData, int id) async {
    final datos = Map<String, dynamic>.from(equipoData);
    datos['fecha_actualizacion'] = DateTime.now().toIso8601String();
    datos['sincronizado'] = 0;
    return await actualizar('equipos', datos, where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>?> obtenerEquipoPorCodBarras(String codBarras) async {
    final maps = await consultar(
      'equipos',
      where: 'cod_barras = ? AND activo = ?',
      whereArgs: [codBarras, 1],
      limit: 1,
    );
    return maps.isNotEmpty ? maps.first : null;
  }

  Future<Map<String, dynamic>?> obtenerEquipoPorId(int id) async {
    final maps = await consultar(
      'equipos',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return maps.isNotEmpty ? maps.first : null;
  }

  Future<bool> existeCodBarras(String codBarras) async {
    final maps = await consultar(
      'equipos',
      where: 'cod_barras = ? AND activo = ?',
      whereArgs: [codBarras, 1],
      limit: 1,
    );
    return maps.isNotEmpty;
  }

  // ════════════════════════════════════════════════════════════════
  // MÉTODOS REQUERIDOS POR SYNC_SERVICE
  // ════════════════════════════════════════════════════════════════

  /// Limpiar y sincronizar clientes desde la API
  Future<void> limpiarYSincronizar(List<dynamic> clientesAPI) async {
    final db = await database;

    await db.transaction((txn) async {
      // Limpiar clientes existentes (soft delete)
      await txn.update('clientes', {
        'activo': 0,
        'fecha_actualizacion': DateTime.now().toIso8601String(),
      });

      // Insertar clientes de la API
      for (var clienteData in clientesAPI) {
        Map<String, dynamic> datos;

        if (clienteData is Map<String, dynamic>) {
          datos = Map<String, dynamic>.from(clienteData);
        } else {
          // Si es un objeto Cliente, convertirlo a Map
          datos = clienteData.toMap();
        }

        datos['activo'] = 1;
        datos['sincronizado'] = 1;
        datos['fecha_actualizacion'] = DateTime.now().toIso8601String();

        if (datos['fecha_creacion'] == null) {
          datos['fecha_creacion'] = DateTime.now().toIso8601String();
        }

        await txn.insert('clientes', datos, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });

    logger.i('✅ Sincronización completa: ${clientesAPI.length} clientes procesados');
  }

  /// Limpiar y sincronizar equipos desde la API
  Future<void> limpiarYSincronizarEquipos(List<dynamic> equiposAPI) async {
    final db = await database;

    await db.transaction((txn) async {
      // Limpiar equipos existentes (soft delete)
      await txn.update('equipos', {
        'activo': 0,
        'fecha_actualizacion': DateTime.now().toIso8601String(),
      });

      // Insertar equipos de la API
      for (var equipoData in equiposAPI) {
        Map<String, dynamic> datos;

        if (equipoData is Map<String, dynamic>) {
          datos = Map<String, dynamic>.from(equipoData);
        } else {
          // Si es un objeto Equipo, convertirlo a Map
          datos = equipoData.toMap();
        }

        datos['activo'] = 1;
        datos['sincronizado'] = 1;
        datos['fecha_actualizacion'] = DateTime.now().toIso8601String();

        if (datos['fecha_creacion'] == null) {
          datos['fecha_creacion'] = DateTime.now().toIso8601String();
        }

        await txn.insert('equipos', datos, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });

    logger.i('✅ Sincronización completa: ${equiposAPI.length} equipos procesados');
  }

  /// Obtener clientes no sincronizados
  Future<List<Map<String, dynamic>>> obtenerClientesNoSincronizados() async {
    return await consultar(
      'clientes',
      where: 'activo = ? AND sincronizado = ?',
      whereArgs: [1, 0],
      orderBy: 'fecha_creacion ASC',
    );
  }


  /// Obtener equipos no sincronizados
  Future<List<Map<String, dynamic>>> obtenerEquiposNoSincronizados() async {
    return await consultar(
      'equipos',
      where: 'activo = ? AND sincronizado = ?',
      whereArgs: [1, 0],
      orderBy: 'fecha_creacion ASC',
    );
  }

  /// Marcar clientes como sincronizados
  Future<void> marcarComoSincronizados(List<int> ids) async {
    if (ids.isEmpty) return;

    final db = await database;
    final placeholders = ids.map((_) => '?').join(',');

    await db.rawUpdate(
      'UPDATE clientes SET sincronizado = 1, fecha_actualizacion = ? WHERE id IN ($placeholders)',
      [DateTime.now().toIso8601String(), ...ids],
    );

    logger.i('✅ ${ids.length} clientes marcados como sincronizados');
  }

  /// Marcar equipos como sincronizados
  Future<void> marcarEquiposComoSincronizados(List<int> ids) async {
    if (ids.isEmpty) return;

    final db = await database;
    final placeholders = ids.map((_) => '?').join(',');

    await db.rawUpdate(
      'UPDATE equipos SET sincronizado = 1, fecha_actualizacion = ? WHERE id IN ($placeholders)',
      [DateTime.now().toIso8601String(), ...ids],
    );

    logger.i('✅ ${ids.length} equipos marcados como sincronizados');
  }

  /// Estadísticas específicas para clientes
  Future<Map<String, dynamic>> obtenerEstadisticas() async {
    final db = await database;

    final total = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM clientes WHERE activo = 1')) ?? 0;
    final sincronizados = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM clientes WHERE activo = 1 AND sincronizado = 1')) ?? 0;
    final noSincronizados = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM clientes WHERE activo = 1 AND sincronizado = 0')) ?? 0;
    final eliminados = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM clientes WHERE activo = 0')) ?? 0;

    return {
      'totalClientes': total,
      'clientesSincronizados': sincronizados,
      'clientesNoSincronizados': noSincronizados,
      'clientesEliminados': eliminados,
      'ultimaActualizacion': DateTime.now().toIso8601String(),
    };
  }

  /// Estadísticas específicas para equipos
  Future<Map<String, dynamic>> obtenerEstadisticasEquipos() async {
    final db = await database;

    final total = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM equipos WHERE activo = 1')) ?? 0;
    final sincronizados = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM equipos WHERE activo = 1 AND sincronizado = 1')) ?? 0;
    final noSincronizados = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM equipos WHERE activo = 1 AND sincronizado = 0')) ?? 0;
    final eliminados = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM equipos WHERE activo = 0')) ?? 0;

    return {
      'totalEquipos': total,
      'equiposSincronizados': sincronizados,
      'equiposNoSincronizados': noSincronizados,
      'equiposEliminados': eliminados,
      'ultimaActualizacion': DateTime.now().toIso8601String(),
    };
  }

  // ════════════════════════════════════════════════════════════════
  // MÉTODOS QUE DEVUELVEN OBJETOS CLIENTE
  // ════════════════════════════════════════════════════════════════

  Future<List<Cliente>> obtenerTodosLosClientesObjeto({bool soloActivos = true}) async {
    final maps = await consultar(
      'clientes',
      where: soloActivos ? 'activo = ?' : null,
      whereArgs: soloActivos ? [1] : null,
      orderBy: 'nombre ASC',
    );

    return maps.map((map) => Cliente.fromMap(map)).toList();
  }

  Future<List<Cliente>> buscarClientesObjeto(String query) async {
    final searchTerm = '%${query.toLowerCase()}%';
    final maps = await consultar(
      'clientes',
      where: 'activo = ? AND (LOWER(nombre) LIKE ? OR LOWER(email) LIKE ? OR telefono LIKE ?)',
      whereArgs: [1, searchTerm, searchTerm, searchTerm],
      orderBy: 'nombre ASC',
      limit: 50,
    );

    return maps.map((map) => Cliente.fromMap(map)).toList();
  }

  Future<Cliente?> obtenerClientePorIdObjeto(int id) async {
    final maps = await consultar(
      'clientes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return maps.isNotEmpty ? Cliente.fromMap(maps.first) : null;
  }

  Future<Cliente?> obtenerClientePorEmailObjeto(String email) async {
    final maps = await consultar(
      'clientes',
      where: 'email = ? AND activo = ?',
      whereArgs: [email, 1],
      limit: 1,
    );
    return maps.isNotEmpty ? Cliente.fromMap(maps.first) : null;
  }

  Future<List<Cliente>> obtenerClientesNoSincronizadosObjeto() async {
    final maps = await consultar(
      'clientes',
      where: 'activo = ? AND sincronizado = ?',
      whereArgs: [1, 0],
      orderBy: 'fecha_creacion ASC',
    );

    return maps.map((map) => Cliente.fromMap(map)).toList();
  }

  // ════════════════════════════════════════════════════════════════
  // MÉTODOS QUE DEVUELVEN OBJETOS EQUIPO
  // ════════════════════════════════════════════════════════════════

  Future<List<Equipo>> obtenerTodosLosEquiposObjeto({bool soloActivos = true}) async {
    final maps = await consultar(
      'equipos',
      where: soloActivos ? 'activo = ?' : null,
      whereArgs: soloActivos ? [1] : null,
      orderBy: 'marca ASC, modelo ASC',
    );

    return maps.map((map) => Equipo.fromMap(map)).toList();
  }

  Future<List<Equipo>> buscarEquipoObjeto(String query) async {
    final searchTerm = '%${query.toLowerCase()}%';
    final maps = await consultar(
      'equipos',
      where: 'activo = ? AND (LOWER(cod_barras) LIKE ? OR LOWER(marca) LIKE ? OR LOWER(modelo) LIKE ? OR LOWER(tipo_equipo) LIKE ?)',
      whereArgs: [1, searchTerm, searchTerm, searchTerm, searchTerm],
      orderBy: 'marca ASC, modelo ASC',
      limit: 50,
    );

    return maps.map((map) => Equipo.fromMap(map)).toList();
  }

  Future<Equipo?> obtenerEquipoPorIdObjeto(int id) async {
    final maps = await consultar(
      'equipos',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return maps.isNotEmpty ? Equipo.fromMap(maps.first) : null;
  }

  Future<Equipo?> obtenerEquipoPorCodBarrasObjeto(String codBarras) async {
    final maps = await consultar(
      'equipos',
      where: 'cod_barras = ? AND activo = ?',
      whereArgs: [codBarras, 1],
      limit: 1,
    );
    return maps.isNotEmpty ? Equipo.fromMap(maps.first) : null;
  }

  Future<List<Equipo>> obtenerEquiposNoSincronizadosObjeto() async {
    final maps = await consultar(
      'equipos',
      where: 'activo = ? AND sincronizado = ?',
      whereArgs: [1, 0],
      orderBy: 'fecha_creacion ASC',
    );

    return maps.map((map) => Equipo.fromMap(map)).toList();
  }
  Future<void> borrarTodosLosDatos() async {
    final db = await database;

    try {
      logger.i('🗑️ Borrando todos los datos de las tablas...');

      await db.transaction((txn) async {
        await txn.delete('clientes');
        await txn.delete('equipos');
        await txn.delete('usuarios');
        await txn.delete('equipo_cliente');
        await txn.delete('estado_equipo');
      });

      logger.i('✅ Todos los datos borrados correctamente');
    } catch (e) {
      logger.e('❌ Error borrando datos: $e');
      rethrow;
    }
  }
}