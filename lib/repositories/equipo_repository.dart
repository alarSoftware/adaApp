import 'package:sqflite/sqflite.dart';
import 'package:ada_app/models/equipos.dart';
import '../repositories/base_repository.dart';

class EquipoRepository extends BaseRepository<Equipo> {
  @override
  String get tableName => 'equipos';

  @override
  Equipo fromMap(Map<String, dynamic> map) => Equipo.fromMap(map);

  @override
  Map<String, dynamic> toMap(Equipo equipo) => equipo.toMap();

  @override
  String getDefaultOrderBy() => 'fecha_creacion DESC';

  @override
  String getBuscarWhere() => 'activo = ? AND (LOWER(cod_barras) LIKE ? OR LOWER(numero_serie) LIKE ?)';

  @override
  List<dynamic> getBuscarArgs(String query) {
    final searchTerm = '%${query.toLowerCase()}%';
    return [1, searchTerm, searchTerm];
  }

  @override
  String getEntityName() => 'Equipo';

  // ========== MÉTODOS PRINCIPALES DE BÚSQUEDA ==========

  /// Búsqueda con detalles completos - FIX para espacios en blanco
  Future<List<Map<String, dynamic>>> buscarConDetalles(String query) async {
    if (query.trim().isEmpty) {
      return await obtenerCompletos(soloActivos: true);
    }

    final searchTerm = query.toLowerCase().trim();

    final sql = '''
  SELECT e.*,
         m.nombre as marca_nombre,
         mo.nombre as modelo_nombre,
         l.nombre as logo_nombre,
         CASE 
           WHEN ec.id IS NOT NULL THEN 'Asignado'
           ELSE 'Disponible'
         END as estado_asignacion,
         c.nombre as cliente_nombre
  FROM equipos e
  LEFT JOIN marcas m ON e.marca_id = m.id
  LEFT JOIN modelos mo ON e.modelo_id = mo.id
  LEFT JOIN logo l ON e.logo_id = l.id
  LEFT JOIN equipo_cliente ec ON e.id = ec.equipo_id 
    AND ec.activo = 1 
    AND ec.fecha_retiro IS NULL
  LEFT JOIN clientes c ON ec.cliente_id = c.id
  WHERE e.activo = 1 
    AND (
      -- Búsqueda exacta con TRIM
      LOWER(TRIM(e.cod_barras)) = ? OR
      LOWER(TRIM(m.nombre)) = ? OR
      LOWER(TRIM(mo.nombre)) = ? OR
      LOWER(TRIM(l.nombre)) = ? OR
      
      -- Búsqueda que empieza con TRIM
      LOWER(TRIM(e.cod_barras)) LIKE ? OR
      LOWER(TRIM(m.nombre)) LIKE ? OR
      LOWER(TRIM(mo.nombre)) LIKE ? OR
      LOWER(TRIM(l.nombre)) LIKE ? OR
      
      -- Búsqueda menos restrictiva
      LOWER(TRIM(e.numero_serie)) LIKE ? OR
      LOWER(TRIM(c.nombre)) LIKE ?
    )
  ORDER BY 
    -- Ordenar por relevancia con TRIM
    CASE 
      WHEN LOWER(TRIM(l.nombre)) = ? THEN 1
      WHEN LOWER(TRIM(m.nombre)) = ? THEN 1
      WHEN LOWER(TRIM(l.nombre)) LIKE ? THEN 2
      WHEN LOWER(TRIM(m.nombre)) LIKE ? THEN 2
      ELSE 3
    END,
    e.fecha_creacion DESC
  ''';

    return await dbHelper.consultarPersonalizada(sql, [
      // Exactas
      searchTerm, searchTerm, searchTerm, searchTerm,
      // Empieza con
      '$searchTerm%', '$searchTerm%', '$searchTerm%', '$searchTerm%',
      // Contiene
      '%$searchTerm%', '%$searchTerm%',
      // Para ORDER BY
      searchTerm, searchTerm, '$searchTerm%', '$searchTerm%',
    ]);
  }

  /// Obtener equipos con datos completos (método unificado)
  Future<List<Map<String, dynamic>>> obtenerCompletos({bool soloActivos = true}) async {
    final whereClause = soloActivos ? 'WHERE e.activo = 1' : '';

    final sql = '''
      SELECT e.*,
             m.nombre as marca_nombre,
             mo.nombre as modelo_nombre,
             l.nombre as logo_nombre,
             CASE 
               WHEN ec.id IS NOT NULL THEN 'Asignado'
               ELSE 'Disponible'
             END as estado_asignacion,
             c.nombre as cliente_nombre
      FROM equipos e
      LEFT JOIN marcas m ON e.marca_id = m.id
      LEFT JOIN modelos mo ON e.modelo_id = mo.id
      LEFT JOIN logo l ON e.logo_id = l.id
      LEFT JOIN equipo_cliente ec ON e.id = ec.equipo_id 
        AND ec.activo = 1 
        AND ec.fecha_retiro IS NULL
      LEFT JOIN clientes c ON ec.cliente_id = c.id
      $whereClause
      ORDER BY e.fecha_creacion DESC
    ''';

    return await dbHelper.consultarPersonalizada(sql);
  }

  // ========== MÉTODOS DE BÚSQUEDA ESPECÍFICA ==========

  /// Buscar por código exacto
  Future<List<Map<String, dynamic>>> buscarPorCodigoExacto({
    required String codigoBarras,
    bool soloActivos = true,
  }) async {
    final condiciones = ['UPPER(e.cod_barras) = ?'];
    final argumentos = [codigoBarras.toUpperCase()];

    if (soloActivos) {
      condiciones.add('e.activo = 1');
    }

    final sql = '''
    SELECT e.*, 
           m.nombre as marca_nombre,
           mo.nombre as modelo_nombre,
           l.nombre as logo_nombre
    FROM equipos e
    LEFT JOIN marcas m ON e.marca_id = m.id
    LEFT JOIN modelos mo ON e.modelo_id = mo.id
    LEFT JOIN logo l ON e.logo_id = l.id
    WHERE ${condiciones.join(' AND ')}
    ORDER BY e.fecha_creacion DESC
    LIMIT 1
    ''';

    return await dbHelper.consultarPersonalizada(sql, argumentos);
  }

  /// Obtener equipos por estado
  Future<List<Map<String, dynamic>>> obtenerPorEstado({
    required bool disponibles,
  }) async {
    final condition = disponibles
        ? 'AND ec.id IS NULL'
        : 'AND ec.id IS NOT NULL';

    final joinType = disponibles ? 'LEFT JOIN' : 'INNER JOIN';

    final sql = '''
      SELECT e.*,
             m.nombre as marca_nombre,
             mo.nombre as modelo_nombre,
             l.nombre as logo_nombre,
             c.nombre as cliente_nombre
      FROM equipos e
      LEFT JOIN marcas m ON e.marca_id = m.id
      LEFT JOIN modelos mo ON e.modelo_id = mo.id
      LEFT JOIN logo l ON e.logo_id = l.id
      $joinType equipo_cliente ec ON e.id = ec.equipo_id 
        AND ec.activo = 1 
        AND ec.fecha_retiro IS NULL
      LEFT JOIN clientes c ON ec.cliente_id = c.id
      WHERE e.activo = 1 
        AND e.estado_local = 1
        $condition
      ORDER BY m.nombre, mo.nombre
    ''';

    return await dbHelper.consultarPersonalizada(sql);
  }

  // ========== MÉTODOS DE VALIDACIÓN ==========

  /// Buscar por código de barras
  Future<Equipo?> buscarPorCodigoBarras(String codBarras) async {
    final maps = await dbHelper.consultar(
      tableName,
      where: 'cod_barras = ? AND activo = ?',
      whereArgs: [codBarras, 1],
      limit: 1,
    );

    return maps.isNotEmpty ? fromMap(maps.first) : null;
  }

  /// Verificar si existe un código de barras
  Future<bool> existeCodigoBarras(String codBarras, {int? excludeId}) async {
    var whereClause = 'cod_barras = ? AND activo = ?';
    var whereArgs = [codBarras, 1];

    if (excludeId != null) {
      whereClause += ' AND id != ?';
      whereArgs.add(excludeId);
    }

    final maps = await dbHelper.consultar(
      tableName,
      where: whereClause,
      whereArgs: whereArgs,
      limit: 1,
    );

    return maps.isNotEmpty;
  }

  /// Verificar si existe un número de serie
  Future<bool> existeNumeroSerie(String numeroSerie, {int? excludeId}) async {
    var whereClause = 'numero_serie = ? AND activo = ?';
    var whereArgs = [numeroSerie, 1];

    if (excludeId != null) {
      whereClause += ' AND id != ?';
      whereArgs.add(excludeId);
    }

    final maps = await dbHelper.consultar(
      tableName,
      where: whereClause,
      whereArgs: whereArgs,
      limit: 1,
    );

    return maps.isNotEmpty;
  }

  // ========== MÉTODOS DE REFERENCIA ==========

  /// Obtener marcas activas
  Future<List<Map<String, dynamic>>> obtenerMarcas() async {
    return await dbHelper.consultar(
      'marcas',
      where: 'activo = ?',
      whereArgs: [1],
      orderBy: 'nombre ASC',
    );
  }

  /// Obtener modelos
  Future<List<Map<String, dynamic>>> obtenerModelos() async {
    return await dbHelper.consultar(
      'modelos',
      orderBy: 'nombre ASC',
    );
  }

  /// Obtener logos activos
  Future<List<Map<String, dynamic>>> obtenerLogos() async {
    return await dbHelper.consultar(
      'logo',
      where: 'activo = ?',
      whereArgs: [1],
      orderBy: 'nombre ASC',
    );
  }

  // ========== MÉTODOS DE ESTADÍSTICAS ==========

  /// Obtener resumen para dashboard
  Future<Map<String, dynamic>> obtenerResumenDashboard() async {
    final sql = '''
      SELECT 
        COUNT(*) as total_equipos,
        COUNT(CASE WHEN e.activo = 1 THEN 1 END) as activos,
        COUNT(CASE WHEN e.estado_local = 0 THEN 1 END) as mantenimiento,
        COUNT(CASE WHEN ec.id IS NOT NULL THEN 1 END) as asignados,
        COUNT(CASE WHEN ec.id IS NULL AND e.activo = 1 AND e.estado_local = 1 THEN 1 END) as disponibles,
        COUNT(CASE WHEN e.sincronizado = 0 THEN 1 END) as pendientes_sync
      FROM equipos e
      LEFT JOIN equipo_cliente ec ON e.id = ec.equipo_id 
        AND ec.activo = 1 
        AND ec.fecha_retiro IS NULL
    ''';

    final result = await dbHelper.consultarPersonalizada(sql);
    return result.isNotEmpty ? result.first : {};
  }

  // ========== MÉTODOS DE GESTIÓN ==========

  /// Crear equipo con validaciones
  Future<int> crearEquipo({
    String? codBarras,
    required int marcaId,
    required int modeloId,
    required int logoId,
    String? numeroSerie,
    int estadoLocal = 1,
  }) async {
    // Validaciones
    if (codBarras != null && codBarras.isNotEmpty && await existeCodigoBarras(codBarras)) {
      throw Exception('Ya existe un equipo con el código de barras: $codBarras');
    }

    if (numeroSerie != null && numeroSerie.isNotEmpty && await existeNumeroSerie(numeroSerie)) {
      throw Exception('Ya existe un equipo con el número de serie: $numeroSerie');
    }

    final now = DateTime.now().toIso8601String();
    final equipoData = {
      'cod_barras': codBarras ?? '',
      'marca_id': marcaId,
      'modelo_id': modeloId,
      'logo_id': logoId,
      'numero_serie': numeroSerie,
      'estado_local': estadoLocal,
      'activo': 1,
      'sincronizado': 0,
      'fecha_creacion': now,
      'fecha_actualizacion': now,
    };

    return await dbHelper.insertar(tableName, equipoData);
  }

  /// Actualizar equipo
  Future<int> actualizarEquipo(int id, Map<String, dynamic> datos) async {
    final equipoActual = await obtenerPorId(id);
    if (equipoActual == null) {
      throw Exception('Equipo no encontrado');
    }

    // Validar código de barras si se cambió
    if (datos.containsKey('cod_barras') && datos['cod_barras'] != equipoActual.codBarras) {
      if (await existeCodigoBarras(datos['cod_barras'], excludeId: id)) {
        throw Exception('Ya existe otro equipo con el código de barras: ${datos['cod_barras']}');
      }
    }

    // Agregar campos de control
    datos['sincronizado'] = 0;
    datos['fecha_actualizacion'] = DateTime.now().toIso8601String();

    return await dbHelper.actualizar(tableName, datos, where: 'id = ?', whereArgs: [id]);
  }

  /// Marcar como sincronizado
  Future<int> marcarComoSincronizado(int id) async {
    return await dbHelper.actualizar(
      tableName,
      {
        'sincronizado': 1,
        'fecha_actualizacion': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ========== MÉTODOS DE SINCRONIZACIÓN ==========

  @override
  Future<List<Equipo>> obtenerNoSincronizados() async {
    final maps = await dbHelper.consultar(
      tableName,
      where: 'sincronizado = ? AND activo = ?',
      whereArgs: [0, 1],
      orderBy: getDefaultOrderBy(),
    );
    return maps.map((map) => fromMap(map)).toList();
  }

  /// Sincronizar equipos desde API
  Future<void> sincronizarDesdeAPI(List<dynamic> equiposAPI) async {
    await limpiarYSincronizar(equiposAPI);
  }

  /// Insertar lote de equipos
  Future<void> insertarLote(List<Equipo> equipos) async {
    if (equipos.isEmpty) return;

    await dbHelper.ejecutarTransaccion((txn) async {
      for (final equipo in equipos) {
        await txn.insert(tableName, equipo.toMap());
      }
    });
  }
}