import '../models/logo.dart';
import 'base_repository.dart';


class LogoRepository extends BaseRepository<Logo> {

  @override
  String get tableName => 'logo';

  @override
  Logo fromMap(Map<String, dynamic> map) => Logo.fromMap(map);

  @override
  Map<String, dynamic> toMap(Logo logo) => logo.toMap();

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
  String getEntityName() => 'Logo';

  /// Obtener logo por nombre
  Future<Logo?> obtenerPorNombre(String nombre) async {
    final maps = await dbHelper.consultar(
      tableName,
      where: 'LOWER(nombre) = LOWER(?) AND activo = ?',
      whereArgs: [nombre.trim(), 1],
      limit: 1,
    );
    return maps.isNotEmpty ? fromMap(maps.first) : null;
  }

  /// Verificar si existe un logo por nombre
  Future<bool> existeNombre(String nombre, {int? excludeId}) async {
    String where = 'LOWER(nombre) = LOWER(?) AND activo = ?';
    List<dynamic> whereArgs = [nombre.trim(), 1];

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

  /// Contar equipos por logo
  Future<Map<String, dynamic>> obtenerEstadisticasLogo() async {
    const sql = '''
      SELECT 
        l.id,
        l.nombre,
        COUNT(e.id) as total_equipos,
        COUNT(CASE WHEN ec.id IS NOT NULL THEN 1 END) as equipos_asignados,
        COUNT(CASE WHEN ec.id IS NULL THEN 1 END) as equipos_disponibles
      FROM logo l
      LEFT JOIN equipos e ON l.id = e.logo_id AND e.activo = 1 AND e.estado_local = 1
      LEFT JOIN equipo_cliente ec ON e.id = ec.equipo_id AND ec.activo = 1 AND ec.fecha_retiro IS NULL
      WHERE l.activo = 1
      GROUP BY l.id, l.nombre
      ORDER BY l.nombre
    ''';
    return {'logos_con_equipos': await dbHelper.consultarPersonalizada(sql)};
  }
}