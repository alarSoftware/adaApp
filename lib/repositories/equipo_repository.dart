import '../models/equipos.dart';
import 'base_repository.dart';

class EquipoRepository extends BaseRepository<Equipo> {
  @override
  String get tableName => 'equipos';

  @override
  Equipo fromMap(Map<String, dynamic> map) => Equipo.fromMap(map);

  @override
  Map<String, dynamic> toMap(Equipo equipo) => equipo.toMap();

  @override
  String getDefaultOrderBy() => 'marca ASC, modelo ASC';

  @override
  String getBuscarWhere() => 'activo = ? AND (LOWER(cod_barras) LIKE ? OR LOWER(marca) LIKE ? OR LOWER(modelo) LIKE ? OR LOWER(tipo_equipo) LIKE ?)';

  @override
  List<dynamic> getBuscarArgs(String query) {
    final searchTerm = '%${query.toLowerCase()}%';
    return [1, searchTerm, searchTerm, searchTerm, searchTerm];
  }

  @override
  String getEntityName() => 'Equipo';

  // ════════════════════════════════════════════════════════════════
  // MÉTODOS ESPECÍFICOS DE EQUIPO
  // ════════════════════════════════════════════════════════════════

  /// Obtener equipo por código de barras
  Future<Equipo?> obtenerPorCodBarras(String codBarras) async {
    final maps = await dbHelper.consultar(
      tableName,
      where: 'cod_barras = ? AND activo = ?',
      whereArgs: [codBarras, 1],
      limit: 1,
    );
    return maps.isNotEmpty ? fromMap(maps.first) : null;
  }

  /// Verificar si existe código de barras
  Future<bool> existeCodBarras(String codBarras) async {
    final maps = await dbHelper.consultar(
      tableName,
      where: 'cod_barras = ? AND activo = ?',
      whereArgs: [codBarras, 1],
      limit: 1,
    );
    return maps.isNotEmpty;
  }

  /// Obtener equipos por tipo
  Future<List<Equipo>> obtenerPorTipo(String tipoEquipo) async {
    final maps = await dbHelper.consultar(
      tableName,
      where: 'tipo_equipo = ? AND activo = ?',
      whereArgs: [tipoEquipo, 1],
      orderBy: getDefaultOrderBy(),
    );
    return maps.map((map) => fromMap(map)).toList();
  }
}