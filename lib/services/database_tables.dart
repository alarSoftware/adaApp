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

    // Tablas de formularios dinámicos
    await db.execute(_sqlDynamicForm());
    await db.execute(_sqlDynamicFormDetail());
    await db.execute(_sqlDynamicFormResponse());
    await db.execute(_sqlDynamicFormResponseDetail());
    await db.execute(_sqlDynamicFormResponseImage());
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
    equipo_id TEXT,
    cliente_id TEXT,
    fecha_censo DATETIME,
    usuario_censo_id INTEGER,
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

  // ==================== TABLAS DE FORMULARIOS DINÁMICOS ====================

  String _sqlDynamicForm() => '''
    CREATE TABLE dynamic_form (
      id TEXT PRIMARY KEY,
      last_update_user_id INTEGER,
      estado TEXT,
      name TEXT,
      total_puntos INTEGER,
      creation_date TEXT,
      creator_user_id INTEGER,
      last_update_date TEXT
    )
  ''';

  String _sqlDynamicFormDetail() => '''
    CREATE TABLE dynamic_form_detail (
      id TEXT PRIMARY KEY,
      version INTEGER,
      respuesta_correcta TEXT,
      dynamic_form_id TEXT,
      sequence INTEGER,
      points INTEGER,
      type TEXT,
      respuesta_correcta_opt TEXT,
      label TEXT,
      parent_id TEXT,
      percentage REAL,
      FOREIGN KEY (dynamic_form_id) REFERENCES dynamic_form (id)
    )
  ''';

  String _sqlDynamicFormResponse() => '''
    CREATE TABLE dynamic_form_response (
      id TEXT PRIMARY KEY,
      version INTEGER,
      contacto_id TEXT,
      cliente_id TEXT,
      edf_vendedor_id TEXT,
      last_update_user_id INTEGER,
      dynamic_form_id TEXT,
      usuario_id INTEGER,
      estado TEXT,
      sync_status TEXT DEFAULT 'pending',
      intentos_sync INTEGER DEFAULT 0,
      ultimo_intento_sync TEXT,
      mensaje_error_sync TEXT,
      fecha_sincronizado TEXT,
      creation_date TEXT,
      creation_user_id INTEGER,
      last_update_date TEXT,
      FOREIGN KEY (dynamic_form_id) REFERENCES dynamic_form (id)
    )
  ''';

  String _sqlDynamicFormResponseDetail() => '''
  CREATE TABLE dynamic_form_response_detail (
    id TEXT PRIMARY KEY,
    version INTEGER,
    response TEXT,
    dynamic_form_response_id TEXT,
    dynamic_form_detail_id TEXT,
    sync_status TEXT DEFAULT 'pending',
    FOREIGN KEY (dynamic_form_response_id) REFERENCES dynamic_form_response (id),
    FOREIGN KEY (dynamic_form_detail_id) REFERENCES dynamic_form_detail (id)
  )
''';

  String _sqlDynamicFormResponseImage() => '''
  CREATE TABLE dynamic_form_response_image (
    id TEXT PRIMARY KEY,
    dynamic_form_response_detail_id TEXT NOT NULL,
    imagen_path TEXT,
    imagen_base64 TEXT,
    imagen_tamano INTEGER,
    mime_type TEXT DEFAULT 'image/jpeg',
    orden INTEGER DEFAULT 1,
    created_at TEXT NOT NULL,
    sync_status TEXT DEFAULT 'pending',
    FOREIGN KEY (dynamic_form_response_detail_id) REFERENCES dynamic_form_response_detail(id) ON DELETE CASCADE
  )
''';

  // ==================== ÍNDICES ====================

  Future<void> _crearIndices(Database db) async {
    await _crearIndicesClientes(db);
    await _crearIndicesEquipos(db);
    await _crearIndicesEquiposPendientes(db);
    await _crearIndicesMaestras(db);
    await _crearIndicesDynamicForms(db);
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

  Future<void> _crearIndicesDynamicForms(Database db) async {
    final indices = [
      // Índices para dynamic_form
      'CREATE INDEX IF NOT EXISTS idx_dynamic_form_name ON dynamic_form (name)',
      'CREATE INDEX IF NOT EXISTS idx_dynamic_form_estado ON dynamic_form (estado)',

      // Índices para dynamic_form_detail
      'CREATE INDEX IF NOT EXISTS idx_dynamic_form_detail_form_id ON dynamic_form_detail (dynamic_form_id)',
      'CREATE INDEX IF NOT EXISTS idx_dynamic_form_detail_sequence ON dynamic_form_detail (sequence)',
      'CREATE INDEX IF NOT EXISTS idx_dynamic_form_detail_type ON dynamic_form_detail (type)',

      // Índices para dynamic_form_response
      'CREATE INDEX IF NOT EXISTS idx_dynamic_form_response_form_id ON dynamic_form_response (dynamic_form_id)',
      'CREATE INDEX IF NOT EXISTS idx_dynamic_form_response_estado ON dynamic_form_response (estado)',
      'CREATE INDEX IF NOT EXISTS idx_dynamic_form_response_sync_status ON dynamic_form_response (sync_status)',
      'CREATE INDEX IF NOT EXISTS idx_dynamic_form_response_usuario_id ON dynamic_form_response (usuario_id)',
      'CREATE INDEX IF NOT EXISTS idx_dynamic_form_response_contacto_id ON dynamic_form_response (contacto_id)',

      // Índices para dynamic_form_response_detail
      'CREATE INDEX IF NOT EXISTS idx_dynamic_form_response_detail_response_id ON dynamic_form_response_detail (dynamic_form_response_id)',
      'CREATE INDEX IF NOT EXISTS idx_dynamic_form_response_detail_detail_id ON dynamic_form_response_detail (dynamic_form_detail_id)',
      'CREATE INDEX IF NOT EXISTS idx_dynamic_form_response_detail_sync_status ON dynamic_form_response_detail (sync_status)',

      // Índices para dynamic_form_response_image
      'CREATE INDEX IF NOT EXISTS idx_dynamic_form_response_image_detail_id ON dynamic_form_response_image(dynamic_form_response_detail_id)',
      'CREATE INDEX IF NOT EXISTS idx_dynamic_form_response_image_sync_status ON dynamic_form_response_image(sync_status)',
    ];

    for (final indice in indices) {
      await db.execute(indice);
    }
  }
}