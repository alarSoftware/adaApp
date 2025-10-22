import '../models/marca.dart';
import 'base_repository.dart';

class MarcaRepository extends BaseRepository<Marca> {
  @override
  String get tableName => 'marcas';

  @override
  Marca fromMap(Map<String, dynamic> map) => Marca.fromMap(map);

  @override
  Map<String, dynamic> toMap(Marca marca) => marca.toMap();

  @override
  String getDefaultOrderBy() => 'nombre ASC';

  @override
  String getBuscarWhere() => 'activo = ? AND LOWER(nombre) LIKE ?';

  @override
  List<dynamic> getBuscarArgs(String query) {
    final searchTerm = '%${query.toLowerCase()}%';
    return [1, searchTerm];
  }

  @override
  String getEntityName() => 'Marca';

  /// ✅ CORREGIDO: Obtener todas las marcas (SIN filtro activo)
  Future<List<Marca>> obtenerTodos() async {
    try {
      final maps = await dbHelper.consultar(
        tableName,
        // ❌ REMOVIDO: where: 'activo = ?',
        // ❌ REMOVIDO: whereArgs: [1],
        orderBy: 'nombre ASC',
      );

      return maps.map((map) => fromMap(map)).toList();
    } catch (e) {
      print('Error obteniendo todas las marcas: $e');
      return [];
    }
  }

  /// Obtener marca por nombre
  Future<Marca?> obtenerPorNombre(String nombre) async {
    final maps = await dbHelper.consultar(
      tableName,
      where: 'LOWER(nombre) = LOWER(?)',
      whereArgs: [nombre.trim()],
      limit: 1,
    );
    return maps.isNotEmpty ? fromMap(maps.first) : null;
  }

  /// Verificar si existe una marca por nombre
  Future<bool> existeNombre(String nombre, {int? excludeId}) async {
    String where = 'LOWER(nombre) = LOWER(?)';
    List<dynamic> whereArgs = [nombre.trim()];

    if (excludeId != null) {
      where += ' AND id != ?';
      whereArgs.add(excludeId);
    }

    return await dbHelper.existeRegistro(tableName, where, whereArgs);
  }

  /// Borrar todas las marcas/logos
  Future<void> borrarTodos() async {
    await dbHelper.eliminar(tableName);
  }

  /// Contar equipos por marca
  Future<Map<String, dynamic>> obtenerEstadisticasMarca() async {
    const sql = '''
      SELECT 
        m.id,
        m.nombre,
        COUNT(e.id) as total_equipos,
        COUNT(CASE WHEN ec.id IS NOT NULL THEN 1 END) as equipos_asignados,
        COUNT(CASE WHEN ec.id IS NULL THEN 1 END) as equipos_disponibles
      FROM marcas m
      LEFT JOIN equipos e ON m.id = e.marca_id AND e.estado_local = 1
      LEFT JOIN equipo_cliente ec ON e.id = ec.equipo_id AND ec.fecha_retiro IS NULL
      GROUP BY m.id, m.nombre
      ORDER BY m.nombre
    ''';
    return {'marcas_con_equipos': await dbHelper.consultarPersonalizada(sql)};
  }
}