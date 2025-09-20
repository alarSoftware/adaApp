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

  // CREACIÓN DE TABLAS ORGANIZADAS

  Future<void> _crearTablasMaestras(Database db) async {
    // Tablas que no dependen de otras (se crean primero por FK)

    await db.execute(_sqlModelos());
    await db.execute(_sqlMarcas());
    await db.execute(_sqlLogo());
  }

  Future<void> _crearTablasPrincipales(Database db) async {
    // Tablas que dependen de las maestras

    await db.execute(_sqlClientes());
    await db.execute(_sqlEquipos());
    await db.execute(_sqlEquipoCliente());
    await db.execute(_sqlUsuarios());
    await db.execute(_sqlEstadoEquipo());
  }

  // ================================================================
  // DEFINICIONES SQL DE TABLAS (más legibles y mantenibles)
  // ================================================================

  String _sqlModelos() => '''
    CREATE TABLE modelos (
      id INTEGER PRIMARY KEY,
      nombre TEXT NOT NULL UNIQUE
    )
  ''';

  String _sqlMarcas() => '''
    CREATE TABLE marcas (
      id INTEGER PRIMARY KEY,
      nombre TEXT NOT NULL UNIQUE,
      activo INTEGER DEFAULT 1,
      fecha_creacion TEXT NOT NULL
    )
  ''';

  String _sqlLogo() => '''
    CREATE TABLE logo (
      id INTEGER PRIMARY KEY,
      nombre TEXT NOT NULL UNIQUE,
      activo INTEGER DEFAULT 1,
      fecha_creacion TEXT NOT NULL
    )
  ''';

  String _sqlClientes() => '''
    CREATE TABLE clientes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      codigo INTEGER,
      nombre TEXT NOT NULL,
      telefono TEXT NOT NULL,
      direccion TEXT NOT NULL,
      ruc_ci TEXT NOT NULL,
      propietario TEXT NOT NULL
    )
  ''';

  String _sqlEquipos() => '''
    CREATE TABLE equipos (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      cliente_id TEXT,                 
      cod_barras TEXT,                       
      marca_id INTEGER NOT NULL,
      modelo_id INTEGER NOT NULL,
      numero_serie TEXT,                      
      logo_id INTEGER NOT NULL,
      estado_local INTEGER DEFAULT 1,
      activo INTEGER DEFAULT 1,
      sincronizado INTEGER DEFAULT 0,
      fecha_creacion TEXT NOT NULL,
      fecha_actualizacion TEXT,
      FOREIGN KEY (marca_id) REFERENCES marcas (id),
      FOREIGN KEY (modelo_id) REFERENCES modelos (id),
      FOREIGN KEY (logo_id) REFERENCES logo (id)
      FOREIGN KEY (cliente_id) REFERENCES clientes(id)
    )
  ''';

  String _sqlEquipoCliente() => '''
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
  ''';

  String _sqlUsuarios() => '''
    CREATE TABLE Users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      edf_vendedor_id TEXT,
      edf_vendedor_nombre TEXT,
      code INTEGER NOT NULL UNIQUE,
      username TEXT NOT NULL,
      password TEXT NOT NULL,   
      fullname TEXT NOT NULL,
      sincronizado INTEGER DEFAULT 0,
      fecha_creacion TEXT NOT NULL,
      fecha_actualizacion TEXT NOT NULL
    )
  ''';

  String _sqlEstadoEquipo() => '''
  CREATE TABLE Estado_Equipo (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    equipo_cliente_id INTEGER NOT NULL,
    en_local INTEGER NOT NULL DEFAULT 0,
    latitud REAL,
    longitud REAL,
    fecha_revision TEXT NOT NULL,
    fecha_creacion TEXT NOT NULL,
    fecha_actualizacion TEXT,
    sincronizado INTEGER NOT NULL DEFAULT 0,
    imagen_path TEXT,
    imagen_base64 TEXT,
    tiene_imagen INTEGER DEFAULT 0,
    imagen_tamano INTEGER,
    estado_censo TEXT DEFAULT 'creado',
    FOREIGN KEY (equipo_cliente_id) REFERENCES equipo_cliente (id) ON DELETE CASCADE
  )
''';


  // ================================================================
  // CREACIÓN DE ÍNDICES ORGANIZADOS
  // ================================================================

  Future<void> _crearIndices(Database db) async {
    await _crearIndicesClientes(db);
    await _crearIndicesEquipos(db);
    await _crearIndicesEquipoCliente(db);
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
      'CREATE INDEX IF NOT EXISTS idx_equipos_activo ON equipos (activo)',
    ];

    for (final indice in indices) {
      await db.execute(indice);
    }
  }

  Future<void> _crearIndicesEquipoCliente(Database db) async {
    final indices = [
      'CREATE INDEX IF NOT EXISTS idx_equipo_cliente_equipo_id ON equipo_cliente (equipo_id)',
      'CREATE INDEX IF NOT EXISTS idx_equipo_cliente_cliente_id ON equipo_cliente (cliente_id)',
      'CREATE INDEX IF NOT EXISTS idx_equipo_cliente_activo ON equipo_cliente (activo)',
      'CREATE INDEX IF NOT EXISTS idx_equipo_cliente_estado ON equipo_cliente (estado)',
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