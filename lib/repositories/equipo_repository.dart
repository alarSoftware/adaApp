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

  /// Obtener equipos con datos completos (JOIN con marcas, modelos y logos) - CORREGIDO
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

  /// Obtener equipos activos
  Future<List<Equipo>> obtenerActivos() async {
    final maps = await dbHelper.consultar(
      tableName,
      where: 'activo = ?',
      whereArgs: [1],
      orderBy: getDefaultOrderBy(),
    );
    return maps.map((map) => fromMap(map)).toList();
  }

  /// Obtener equipos por marca ID
  Future<List<Equipo>> obtenerPorMarcaId(int marcaId, {bool soloActivos = true}) async {
    final whereCondition = soloActivos
        ? 'marca_id = ? AND activo = ?'
        : 'marca_id = ?';
    final whereArgs = soloActivos ? [marcaId, 1] : [marcaId];

    final maps = await dbHelper.consultar(
      tableName,
      where: whereCondition,
      whereArgs: whereArgs,
      orderBy: getDefaultOrderBy(),
    );
    return maps.map((map) => fromMap(map)).toList();
  }

  /// Obtener equipos por modelo ID - NUEVO
  Future<List<Equipo>> obtenerPorModeloId(int modeloId, {bool soloActivos = true}) async {
    final whereCondition = soloActivos
        ? 'modelo_id = ? AND activo = ?'
        : 'modelo_id = ?';
    final whereArgs = soloActivos ? [modeloId, 1] : [modeloId];

    final maps = await dbHelper.consultar(
      tableName,
      where: whereCondition,
      whereArgs: whereArgs,
      orderBy: getDefaultOrderBy(),
    );
    return maps.map((map) => fromMap(map)).toList();
  }

  /// Obtener equipos por logo ID
  Future<List<Equipo>> obtenerPorLogoId(int logoId, {bool soloActivos = true}) async {
    final whereCondition = soloActivos
        ? 'logo_id = ? AND activo = ?'
        : 'logo_id = ?';
    final whereArgs = soloActivos ? [logoId, 1] : [logoId];

    final maps = await dbHelper.consultar(
      tableName,
      where: whereCondition,
      whereArgs: whereArgs,
      orderBy: getDefaultOrderBy(),
    );
    return maps.map((map) => fromMap(map)).toList();
  }

  Future<List<Map<String, dynamic>>> buscarPorCodigoExacto({
    required String codigoBarras,
    bool soloActivos = true,
  }) async {
    final condiciones = <String>[];
    final argumentos = <dynamic>[];

    // ✅ BÚSQUEDA EXACTA - No parcial
    condiciones.add('UPPER(e.cod_barras) = ?');
    argumentos.add(codigoBarras.toUpperCase());

    if (soloActivos) {
      condiciones.add('e.activo = 1');
    }

    final whereClause = 'WHERE ${condiciones.join(' AND ')}';

    final sql = '''
    SELECT e.*, 
           m.nombre as marca_nombre,
           mo.nombre as modelo_nombre,
           l.nombre as logo_nombre
    FROM equipos e
    LEFT JOIN marcas m ON e.marca_id = m.id
    LEFT JOIN modelos mo ON e.modelo_id = mo.id
    LEFT JOIN logo l ON e.logo_id = l.id
    $whereClause
    ORDER BY e.fecha_creacion DESC
    LIMIT 1
  ''';

    return await dbHelper.consultarPersonalizada(sql, argumentos);
  }

  /// Buscar por código de barras
  Future<Equipo?> buscarPorCodigoBarras(String codBarras) async {
    final maps = await dbHelper.consultar(
      tableName,
      where: 'cod_barras = ? AND activo = ?',
      whereArgs: [codBarras, 1],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return fromMap(maps.first);
    }
    return null;
  }

  /// Buscar por número de serie
  Future<Equipo?> buscarPorNumeroSerie(String numeroSerie) async {
    final maps = await dbHelper.consultar(
      tableName,
      where: 'numero_serie = ? AND activo = ?',
      whereArgs: [numeroSerie, 1],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return fromMap(maps.first);
    }
    return null;
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

  /// Obtener equipos disponibles (no asignados) - CORREGIDO
  Future<List<Map<String, dynamic>>> obtenerDisponiblesConDetalles() async {
    final sql = '''
      SELECT e.*,
             m.nombre as marca_nombre,
             mo.nombre as modelo_nombre,
             l.nombre as logo_nombre
      FROM equipos e
      LEFT JOIN marcas m ON e.marca_id = m.id
      LEFT JOIN modelos mo ON e.modelo_id = mo.id
      LEFT JOIN logo l ON e.logo_id = l.id
      LEFT JOIN equipo_cliente ec ON e.id = ec.equipo_id 
        AND ec.activo = 1 
        AND ec.fecha_retiro IS NULL
      WHERE e.activo = 1 
        AND e.estado_local = 1
        AND ec.id IS NULL
      ORDER BY m.nombre, mo.nombre
    ''';

    return await dbHelper.consultarPersonalizada(sql);
  }

  /// Obtener equipos asignados - CORREGIDO
  Future<List<Map<String, dynamic>>> obtenerAsignadosConDetalles() async {
    final sql = '''
      SELECT DISTINCT e.*,
             m.nombre as marca_nombre,
             mo.nombre as modelo_nombre,
             l.nombre as logo_nombre,
             c.nombre as cliente_nombre
      FROM equipos e
      LEFT JOIN marcas m ON e.marca_id = m.id
      LEFT JOIN modelos mo ON e.modelo_id = mo.id
      LEFT JOIN logo l ON e.logo_id = l.id
      INNER JOIN equipo_cliente ec ON e.id = ec.equipo_id
      LEFT JOIN clientes c ON ec.cliente_id = c.id
      WHERE e.activo = 1 
        AND ec.activo = 1 
        AND ec.fecha_retiro IS NULL
      ORDER BY m.nombre, mo.nombre
    ''';

    return await dbHelper.consultarPersonalizada(sql);
  }

  /// Obtener estadísticas de equipos
  Future<Map<String, dynamic>> obtenerEstadisticasEquipos() async {
    final sql = '''
      SELECT 
        COUNT(*) as total_equipos,
        COUNT(CASE WHEN e.activo = 1 THEN 1 END) as equipos_activos,
        COUNT(CASE WHEN e.activo = 0 THEN 1 END) as equipos_inactivos,
        COUNT(CASE WHEN e.sincronizado = 0 THEN 1 END) as no_sincronizados,
        COUNT(CASE WHEN ec.id IS NOT NULL THEN 1 END) as equipos_asignados,
        COUNT(CASE WHEN ec.id IS NULL AND e.activo = 1 THEN 1 END) as equipos_disponibles,
        COUNT(DISTINCT e.marca_id) as marcas_diferentes,
        COUNT(DISTINCT e.modelo_id) as modelos_diferentes
      FROM equipos e
      LEFT JOIN equipo_cliente ec ON e.id = ec.equipo_id 
        AND ec.activo = 1 
        AND ec.fecha_retiro IS NULL
    ''';

    final result = await dbHelper.consultarPersonalizada(sql);
    return result.isNotEmpty ? result.first : {};
  }

  /// Buscar equipos con filtros avanzados - CORREGIDO
  Future<List<Map<String, dynamic>>> buscarConFiltrosLike({
    int? marcaId,
    int? modeloId,
    int? logoId,
    String? numeroSerie,
    String? codigoBarras, // Esta sigue siendo búsqueda parcial para filtros
    bool? soloActivos,
    bool? soloDisponibles,
    DateTime? fechaDesde,
    DateTime? fechaHasta,
  }) async {
    final condiciones = <String>[];
    final argumentos = <dynamic>[];

    if (soloActivos == true) {
      condiciones.add('e.activo = 1');
    }

    if (marcaId != null) {
      condiciones.add('e.marca_id = ?');
      argumentos.add(marcaId);
    }

    if (modeloId != null) { // CORREGIDO
      condiciones.add('e.modelo_id = ?');
      argumentos.add(modeloId);
    }

    if (logoId != null) {
      condiciones.add('e.logo_id = ?');
      argumentos.add(logoId);
    }

    if (numeroSerie?.isNotEmpty == true) {
      condiciones.add('LOWER(e.numero_serie) LIKE ?');
      argumentos.add('%${numeroSerie!.toLowerCase()}%');
    }

    if (codigoBarras?.isNotEmpty == true) {
      condiciones.add('LOWER(e.cod_barras) LIKE ?');
      argumentos.add('%${codigoBarras!.toLowerCase()}%');
    }

    if (fechaDesde != null) {
      condiciones.add('DATE(e.fecha_creacion) >= ?');
      argumentos.add(fechaDesde.toIso8601String().split('T')[0]);
    }

    if (fechaHasta != null) {
      condiciones.add('DATE(e.fecha_creacion) <= ?');
      argumentos.add(fechaHasta.toIso8601String().split('T')[0]);
    }

    String sqlBase = '''
      SELECT e.*, 
             m.nombre as marca_nombre,
             mo.nombre as modelo_nombre,
             l.nombre as logo_nombre
      FROM equipos e
      LEFT JOIN marcas m ON e.marca_id = m.id
      LEFT JOIN modelos mo ON e.modelo_id = mo.id
      LEFT JOIN logo l ON e.logo_id = l.id
    ''';

    if (soloDisponibles == true) {
      sqlBase += '''
        LEFT JOIN equipo_cliente ec ON e.id = ec.equipo_id 
          AND ec.activo = 1 
          AND ec.fecha_retiro IS NULL
      ''';
      condiciones.add('ec.id IS NULL');
    }

    final whereClause = condiciones.isNotEmpty
        ? 'WHERE ${condiciones.join(' AND ')}'
        : '';

    final sql = '''
      $sqlBase
      $whereClause
      ORDER BY m.nombre, mo.nombre
      LIMIT 100
    ''';

    return await dbHelper.consultarPersonalizada(sql, argumentos);
  }

  /// Obtener marcas para dropdown
  Future<List<Map<String, dynamic>>> obtenerMarcas() async {
    return await dbHelper.consultar(
      'marcas',
      where: 'activo = ?',
      whereArgs: [1],
      orderBy: 'nombre ASC',
    );
  }

  /// Obtener modelos para dropdown - NUEVO
  Future<List<Map<String, dynamic>>> obtenerModelos() async {
    return await dbHelper.consultar(
      'modelos',
      orderBy: 'nombre ASC',
    );
  }

  /// Obtener logos para dropdown
  Future<List<Map<String, dynamic>>> obtenerLogos() async {
    return await dbHelper.consultar(
      'logo',
      where: 'activo = ?',
      whereArgs: [1],
      orderBy: 'nombre ASC',
    );
  }

  /// Crear equipo con validaciones - CORREGIDO
  Future<int> crearEquipo({
    required String codBarras,
    required int marcaId,
    required int modeloId, // CAMBIADO: de String modelo a int modeloId
    required int logoId,
    String? numeroSerie,
    int estadoLocal = 1,
  }) async {
    // Validar que el código de barras no exista
    if (await existeCodigoBarras(codBarras)) {
      throw Exception('Ya existe un equipo con el código de barras: $codBarras');
    }

    // Validar que el número de serie no exista (si se proporciona)
    if (numeroSerie != null && numeroSerie.isNotEmpty && await existeNumeroSerie(numeroSerie)) {
      throw Exception('Ya existe un equipo con el número de serie: $numeroSerie');
    }

    final now = DateTime.now().toIso8601String();
    final equipoData = {
      'cod_barras': codBarras,
      'marca_id': marcaId,
      'modelo_id': modeloId, // CORREGIDO
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

  /// Actualizar equipo con validaciones - CORREGIDO
  Future<int> actualizarEquipo(int id, {
    String? codBarras,
    int? marcaId,
    int? modeloId, // CAMBIADO: de String modelo a int modeloId
    int? logoId,
    String? numeroSerie,
    int? estadoLocal,
  }) async {
    final equipoActual = await obtenerPorId(id);
    if (equipoActual == null) {
      throw Exception('Equipo no encontrado');
    }

    // Validar código de barras si se cambió
    if (codBarras != null && codBarras != equipoActual.codBarras) {
      if (await existeCodigoBarras(codBarras, excludeId: id)) {
        throw Exception('Ya existe otro equipo con el código de barras: $codBarras');
      }
    }

    // Validar número de serie si se cambió
    if (numeroSerie != null && numeroSerie != equipoActual.numeroSerie) {
      if (numeroSerie.isNotEmpty && await existeNumeroSerie(numeroSerie, excludeId: id)) {
        throw Exception('Ya existe otro equipo con el número de serie: $numeroSerie');
      }
    }

    final datosActualizacion = <String, dynamic>{};
    if (codBarras != null) datosActualizacion['cod_barras'] = codBarras;
    if (marcaId != null) datosActualizacion['marca_id'] = marcaId;
    if (modeloId != null) datosActualizacion['modelo_id'] = modeloId; // CORREGIDO
    if (logoId != null) datosActualizacion['logo_id'] = logoId;
    if (numeroSerie != null) datosActualizacion['numero_serie'] = numeroSerie;
    if (estadoLocal != null) datosActualizacion['estado_local'] = estadoLocal;

    datosActualizacion['sincronizado'] = 0;
    datosActualizacion['fecha_actualizacion'] = DateTime.now().toIso8601String();

    return await dbHelper.actualizar(
      tableName,
      datosActualizacion,
      where: 'id = ?',
      whereArgs: [id],
    );
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

  /// Obtener equipos no sincronizados
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
    if (result.isNotEmpty) {
      return result.first;
    }
    return {};
  }

  /// Sincronizar equipos desde API
  Future<void> sincronizarDesdeAPI(List<dynamic> equiposAPI) async {
    await limpiarYSincronizar(equiposAPI);
  }

  /// Método alternativo para sincronización específica de equipos - CORREGIDO
  Future<void> sincronizarEquiposCompletos(List<dynamic> equiposAPI) async {
    final db = await dbHelper.database;

    await db.transaction((txn) async {
      // Marcar todos los equipos existentes como inactivos
      await txn.update('equipos', {
        'activo': 0,
        'fecha_actualizacion': DateTime.now().toIso8601String(),
      });

      // Insertar/actualizar equipos de la API
      for (var equipoData in equiposAPI) {
        Map<String, dynamic> datos;

        if (equipoData is Map<String, dynamic>) {
          datos = Map<String, dynamic>.from(equipoData);
        } else {
          // Si equipoData es un objeto Equipo
          datos = (equipoData as Equipo).toMap();
        }

        // Asegurar campos requeridos
        datos['activo'] = 1; // Cambié true por 1
        datos['sincronizado'] = 1; // Cambié true por 1
        datos['fecha_actualizacion'] = DateTime.now().toIso8601String();

        if (datos['fecha_creacion'] == null) {
          datos['fecha_creacion'] = DateTime.now().toIso8601String();
        }

        // Usar INSERT OR REPLACE para manejar conflictos
        await txn.insert(
            'equipos',
            datos,
            conflictAlgorithm: ConflictAlgorithm.replace
        );
      }
    });
  }
}