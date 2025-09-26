// database_tables.dart
import 'package:sqflite/sqflite.dart';
import 'package:logger/logger.dart';

var logger = Logger();

class DatabaseTables {

  Future<void> onCreate(Database db, int version) async {
    logger.i('Creando tablas de base de datos v$version');

    await _crearTablasMaestras(db);
    await _crearTablasPrincipales(db);
    await _crearIndices(db);

    logger.i('Todas las tablas e índices creados exitosamente');
  }

  Future<void> onUpgrade(Database db, int oldVersion, int newVersion) async {
    logger.i('Actualizando base de datos de v$oldVersion a v$newVersion');
    // Aquí irían las migraciones futuras
  }

  Future<void> _crearTablasMaestras(Database db) async {
    await db.execute(_sqlModelos());
    await db.execute(_sqlMarcas());
    await db.execute(_sqlLogo());
  }

  Future<void> _crearTablasPrincipales(Database db) async {
    await db.execute(_sqlClientes());
    await db.execute(_sqlEquipos());
    await db.execute(_sqlEquiposPendientes());
    await db.execute(_sqlUsuarios());
    await db.execute(_sqlCensoActivo());
  }

  String _sqlModelos() => '''
    CREATE TABLE modelos (
      id INTEGER PRIMARY KEY,
      nombre TEXT
    )
  ''';

  String _sqlMarcas() => '''
    CREATE TABLE marcas (
      id INTEGER PRIMARY KEY,
      nombre TEXT
    )
  ''';

  String _sqlLogo() => '''
    CREATE TABLE logo (
      id INTEGER PRIMARY KEY,
      nombre TEXT
    )
  ''';

  String _sqlClientes() => '''
    CREATE TABLE clientes (
      id INTEGER PRIMARY KEY,
      codigo TEXT,
      nombre TEXT,
      telefono TEXT,
      direccion TEXT,
      ruc_ci TEXT,
      propietario TEXT
    )
  ''';

  String _sqlEquipos() => '''
  CREATE TABLE equipos (
    id TEXT PRIMARY KEY,
    cliente_id TEXT,                 
    cod_barras TEXT,                       
    marca_id INTEGER,
    modelo_id INTEGER,
    numero_serie TEXT,                      
    logo_id INTEGER,
    FOREIGN KEY (marca_id) REFERENCES marcas (id),
    FOREIGN KEY (modelo_id) REFERENCES modelos (id),
    FOREIGN KEY (logo_id) REFERENCES logo (id),
    FOREIGN KEY (cliente_id) REFERENCES clientes(id)
  )
''';

  String _sqlEquiposPendientes() => '''
  CREATE TABLE equipos_pendientes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    equipo_id INTEGER,
    cliente_id INTEGER,
    fecha_censo DATETIME,
    usuario_censo_id INTEGER,
    latitud REAL,
    longitud REAL,
    observaciones TEXT,
    fecha_creacion DATETIME DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion DATETIME,
    FOREIGN KEY (equipo_id) REFERENCES equipos (id),
    FOREIGN KEY (cliente_id) REFERENCES clientes (id)
  )
''';

  String _sqlUsuarios() => '''
    CREATE TABLE Users (
      id INTEGER PRIMARY KEY,
      edf_vendedor_id TEXT,
      edf_vendedor_nombre TEXT,
      code INTEGER,
      username,
      password,   
      fullname
    )
  ''';

  // ✅ ACTUALIZADO: Tabla con columnas para segunda imagen
  String _sqlCensoActivo() => '''
  CREATE TABLE censo_activo (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    equipo_id TEXT NOT NULL,
    cliente_id INTEGER NOT NULL,   
    en_local INTEGER DEFAULT 0,
    latitud REAL,
    longitud REAL,
    fecha_revision TEXT,
    fecha_creacion TEXT,
    fecha_actualizacion TEXT,
    sincronizado INTEGER DEFAULT 0,
    observaciones TEXT,
    imagen_path TEXT,
    imagen_base64 TEXT,
    tiene_imagen INTEGER DEFAULT 0,
    imagen_tamano INTEGER,
    imagen_path2 TEXT,
    imagen_base64_2 TEXT,
    tiene_imagen2 INTEGER DEFAULT 0,
    imagen_tamano2 INTEGER,
    estado_censo TEXT DEFAULT 'creado'
  )
''';

  Future<void> _crearIndices(Database db) async {
    await _crearIndicesClientes(db);
    await _crearIndicesEquipos(db);
    await _crearIndicesEquiposPendientes(db);
    await _crearIndicesMaestras(db);
  }

  Future<void> _crearIndicesClientes(Database db) async {
    final indices = [
      'CREATE INDEX IF NOT EXISTS idx_clientes_nombre ON clientes (nombre)',
      'CREATE INDEX IF NOT EXISTS idx_clientes_ruc_ci ON clientes (ruc_ci)',
      'CREATE INDEX IF NOT EXISTS idx_clientes_telefono ON clientes (telefono)',
      'CREATE INDEX IF NOT EXISTS idx_clientes_direccion ON clientes (direccion)',
      'CREATE INDEX IF NOT EXISTS idx_clientes_codigo ON clientes (codigo)',
      'CREATE INDEX IF NOT EXISTS idx_clientes_propietario ON clientes (propietario)',
    ];

    for (final indice in indices) {
      await db.execute(indice);
    }
  }

  Future<void> _crearIndicesEquipos(Database db) async {
    final indices = [
      'CREATE INDEX IF NOT EXISTS idx_equipos_cod_barras ON equipos (cod_barras)',
      'CREATE INDEX IF NOT EXISTS idx_equipos_cliente_id ON equipos (cliente_id)',
      'CREATE INDEX IF NOT EXISTS idx_equipos_numero_serie ON equipos (numero_serie)',
      'CREATE INDEX IF NOT EXISTS idx_equipos_marca_id ON equipos (marca_id)',
      'CREATE INDEX IF NOT EXISTS idx_equipos_modelo_id ON equipos (modelo_id)',
      'CREATE INDEX IF NOT EXISTS idx_equipos_logo_id ON equipos (logo_id)',
    ];

    for (final indice in indices) {
      await db.execute(indice);
    }
  }


  Future<void> _crearIndicesEquiposPendientes(Database db) async {
    final indices = [
      'CREATE INDEX IF NOT EXISTS idx_equipos_pendientes_equipo_id ON equipos_pendientes (equipo_id)',
      'CREATE INDEX IF NOT EXISTS idx_equipos_pendientes_cliente_id ON equipos_pendientes (cliente_id)',
      'CREATE INDEX IF NOT EXISTS idx_equipos_pendientes_fecha_censo ON equipos_pendientes (fecha_censo)',
      'CREATE INDEX IF NOT EXISTS idx_equipos_pendientes_usuario_censo_id ON equipos_pendientes (usuario_censo_id)',
    ];

    for (final indice in indices) {
      await db.execute(indice);
    }
  }

  Future<void> _crearIndicesMaestras(Database db) async {
    final indices = [
      'CREATE INDEX IF NOT EXISTS idx_marcas_nombre ON marcas (nombre)',
      'CREATE INDEX IF NOT EXISTS idx_modelos_nombre ON modelos (nombre)',
      'CREATE INDEX IF NOT EXISTS idx_logo_nombre ON logo (nombre)',
    ];

    for (final indice in indices) {
      await db.execute(indice);
    }

  }
}