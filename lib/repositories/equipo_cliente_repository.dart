import '../models/equipos_cliente.dart';
import 'base_repository.dart';

class EquipoClienteRepository extends BaseRepository<EquipoCliente> {
  @override
  String get tableName => 'equipo_cliente';

  @override
  EquipoCliente fromMap(Map<String, dynamic> map) => EquipoCliente.fromMap(map);

  @override
  Map<String, dynamic> toMap(EquipoCliente equipoCliente) => equipoCliente.toMap();

  @override
  String getDefaultOrderBy() => 'fecha_asignacion DESC';

  @override
  String getBuscarWhere() => 'activo = ? AND (CAST(equipo_id AS TEXT) LIKE ? OR CAST(cliente_id AS TEXT) LIKE ?)';

  @override
  List<dynamic> getBuscarArgs(String query) {
    final searchTerm = '%${query.toLowerCase()}%';
    return [1, searchTerm, searchTerm];
  }

  @override
  String getEntityName() => 'Asignacion';

  // ════════════════════════════════════════════════════════════════
  // MÉTODOS ESPECÍFICOS DE EQUIPO_CLIENTE
  // ════════════════════════════════════════════════════════════════

  /// Obtener asignaciones con datos completos (JOIN)
  Future<List<EquipoCliente>> obtenerCompletas({bool soloActivos = true}) async {
    final whereClause = soloActivos ? 'WHERE ec.activo = 1 AND ec.fecha_retiro IS NULL' : '';

    final sql = '''
    SELECT ec.*,
           e.modelo as equipo_modelo, 
           e.cod_barras as equipo_cod_barras,
           e.numero_serie as equipo_numero_serie,
           m.nombre as marca_nombre,
           l.nombre as logo_nombre,
           c.nombre as cliente_nombre, 
           c.email as cliente_email, 
           c.telefono as cliente_telefono
    FROM equipo_cliente ec
    LEFT JOIN equipos e ON ec.equipo_id = e.id
    LEFT JOIN marcas m ON e.marca_id = m.id
    LEFT JOIN logo l ON e.logo_id = l.id
    LEFT JOIN clientes c ON ec.cliente_id = c.id
    $whereClause
    ORDER BY ec.fecha_asignacion DESC
  ''';

    final maps = await dbHelper.consultarPersonalizada(sql);
    return maps.map((map) => fromMap(map)).toList();
  }

  /// Obtener asignaciones activas
  Future<List<EquipoCliente>> obtenerActivas() async {
    final sql = '''
      SELECT ec.*,
             e.marca as equipo_marca, 
             e.modelo as equipo_modelo, 
             e.cod_barras as equipo_cod_barras,
             c.nombre as cliente_nombre, 
             c.email as cliente_email
      FROM equipo_cliente ec
      LEFT JOIN equipos e ON ec.equipo_id = e.id
      LEFT JOIN clientes c ON ec.cliente_id = c.id
      WHERE ec.activo = 1 AND ec.fecha_retiro IS NULL
      ORDER BY ec.fecha_asignacion DESC
    ''';

    final maps = await dbHelper.consultarPersonalizada(sql);
    return maps.map((map) => fromMap(map)).toList();
  }

  /// Obtener asignaciones por equipo
  Future<List<EquipoCliente>> obtenerPorEquipo(int equipoId, {bool soloActivos = true}) async {
    final maps = await dbHelper.consultar(
      tableName,
      where: soloActivos ? 'equipo_id = ? AND activo = ?' : 'equipo_id = ?',
      whereArgs: soloActivos ? [equipoId, 1] : [equipoId],
      orderBy: getDefaultOrderBy(),
    );
    return maps.map((map) => fromMap(map)).toList();
  }

  /// Obtener asignaciones por cliente
  Future<List<EquipoCliente>> obtenerPorCliente(int clienteId, {bool soloActivos = true}) async {
    final maps = await dbHelper.consultar(
      tableName,
      where: soloActivos ? 'cliente_id = ? AND activo = ?' : 'cliente_id = ?',
      whereArgs: soloActivos ? [clienteId, 1] : [clienteId],
      orderBy: getDefaultOrderBy(),
    );
    return maps.map((map) => fromMap(map)).toList();
  }

  /// Verificar si un equipo está asignado
  Future<bool> equipoEstaAsignado(int equipoId) async {
    final maps = await dbHelper.consultar(
      tableName,
      where: 'equipo_id = ? AND activo = ? AND fecha_retiro IS NULL',
      whereArgs: [equipoId, 1],
      limit: 1,
    );
    return maps.isNotEmpty;
  }

  /// Asignar equipo a cliente
  Future<int> asignarEquipoACliente(int equipoId, int clienteId) async {
    // Verificar que el equipo no esté ya asignado
    final yaAsignado = await equipoEstaAsignado(equipoId);
    if (yaAsignado) {
      throw Exception('El equipo ya está asignado a otro cliente');
    }

    final asignacion = EquipoCliente(
      equipoId: equipoId,
      clienteId: clienteId,
      fechaAsignacion: DateTime.now(),
      fechaCreacion: DateTime.now(),
    );

    return await insertar(asignacion);
  }

  /// Retirar equipo
  Future<int> retirarEquipo(int asignacionId) async {
    return await dbHelper.actualizar(
      tableName,
      {
        'fecha_retiro': DateTime.now().toIso8601String(),
        'activo': 0,
        'fecha_actualizacion': DateTime.now().toIso8601String(),
        'sincronizado': 0,
      },
      where: 'id = ?',
      whereArgs: [asignacionId],
    );
  }
  // Agrega este método a tu EquipoClienteRepository o reemplaza el existente

  /// Obtener equipos de un cliente con datos completos
  Future<List<Map<String, dynamic>>> obtenerPorClienteCompleto(int clienteId, {bool soloActivos = true}) async {
    final whereClause = soloActivos ?
    'WHERE ec.cliente_id = ? AND ec.activo = 1 AND ec.fecha_retiro IS NULL' :
    'WHERE ec.cliente_id = ?';

    final sql = '''
    SELECT ec.*,
           e.cod_barras as equipo_cod_barras,
           e.modelo as equipo_modelo,
           e.numero_serie as equipo_numero_serie,
           m.nombre as marca_nombre,
           l.nombre as logo_nombre,
           c.nombre as cliente_nombre
    FROM equipo_cliente ec
    LEFT JOIN equipos e ON ec.equipo_id = e.id
    LEFT JOIN marcas m ON e.marca_id = m.id
    LEFT JOIN logo l ON e.logo_id = l.id
    LEFT JOIN clientes c ON ec.cliente_id = c.id
    $whereClause
    ORDER BY ec.fecha_asignacion DESC
  ''';

    final whereArgs = soloActivos ? [clienteId] : [clienteId];
    return await dbHelper.consultarPersonalizada(sql, whereArgs);
  }
}