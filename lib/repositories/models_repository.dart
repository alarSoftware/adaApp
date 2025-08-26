// repositories/modelo_repository.dart
import '../models/modelo.dart';
import 'base_repository.dart';

class ModeloRepository extends BaseRepository<Modelo> {
  @override
  String get tableName => 'modelos';

  @override
  Modelo fromMap(Map<String, dynamic> map) => Modelo.fromMap(map);

  @override
  Map<String, dynamic> toMap(Modelo modelo) => modelo.toMap();

  @override
  String getDefaultOrderBy() => 'nombre ASC';

  @override
  String getBuscarWhere() => 'LOWER(nombre) LIKE ?';

  @override
  List<dynamic> getBuscarArgs(String query) {
    final searchTerm = '%${query.toLowerCase()}%';
    return [searchTerm];
  }

  @override
  String getEntityName() => 'Modelo';

  @override
  Future<List<Modelo>> obtenerTodos({bool soloActivos = true}) async {
    // La tabla modelos no tiene columna 'activo', así que ignoramos ese parámetro
    final maps = await dbHelper.consultar(
      tableName,
      orderBy: getDefaultOrderBy(),
    );
    return maps.map((map) => fromMap(map)).toList();
  }

  /// Obtener modelo por nombre
  Future<Modelo?> obtenerPorNombre(String nombre) async {
    final maps = await dbHelper.consultar(
      tableName,
      where: 'LOWER(nombre) = LOWER(?)',
      whereArgs: [nombre.trim()],
      limit: 1,
    );
    return maps.isNotEmpty ? fromMap(maps.first) : null;
  }

  /// Verificar si existe un modelo por nombre
  Future<bool> existeNombre(String nombre, {int? excludeId}) async {
    String where = 'LOWER(nombre) = LOWER(?)';
    List<dynamic> whereArgs = [nombre.trim()];

    if (excludeId != null) {
      where += ' AND id != ?';
      whereArgs.add(excludeId);
    }

    return await dbHelper.existeRegistro(tableName, where, whereArgs);
  }

  /// Borrar todos los modelos
  Future<void> borrarTodos() async {
    await dbHelper.eliminar(tableName);
  }

  /// Contar equipos por modelo
  Future<Map<String, dynamic>> obtenerEstadisticasModelo() async {
    const sql = '''
      SELECT 
        m.id,
        m.nombre,
        COUNT(e.id) as total_equipos,
        COUNT(CASE WHEN ec.id IS NOT NULL THEN 1 END) as equipos_asignados,
        COUNT(CASE WHEN ec.id IS NULL THEN 1 END) as equipos_disponibles
      FROM modelos m
      LEFT JOIN equipos e ON m.id = e.modelo_id
      LEFT JOIN equipo_cliente ec ON e.id = ec.equipo_id AND ec.activo = 1 AND ec.fecha_retiro IS NULL
      GROUP BY m.id, m.nombre
      ORDER BY m.nombre
    ''';
    return {'modelos_con_equipos': await dbHelper.consultarPersonalizada(sql)};
  }
}