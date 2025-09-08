import '../models/estado_equipo.dart';
import 'base_repository.dart';

class EstadoEquipoRepository extends BaseRepository<EstadoEquipo> {
  @override
  String get tableName => 'Estado_Equipo';

  @override
  EstadoEquipo fromMap(Map<String, dynamic> map) => EstadoEquipo.fromMap(map);

  @override
  Map<String, dynamic> toMap(EstadoEquipo estadoEquipo) => estadoEquipo.toMap();

  @override
  String getDefaultOrderBy() => 'fecha_revision DESC';

  @override
  String getBuscarWhere() => 'CAST(equipo_id AS TEXT) LIKE ? OR CAST(id_clientes AS TEXT) LIKE ?';

  @override
  List<dynamic> getBuscarArgs(String query) {
    final searchTerm = '%${query.toLowerCase()}%';
    return [searchTerm, searchTerm];
  }

  @override
  String getEntityName() => 'EstadoEquipo';

  /// Actualizar estado de ubicación del equipo
  Future<void> actualizarEstadoEquipo(int equipoId, int clienteId, bool enLocal) async {
    // Buscar estado existente
    final existente = await obtenerPorEquipoYCliente(equipoId, clienteId);

    if (existente != null) {
      // Actualizar existente
      final actualizado = existente.copyWith(
        enLocal: enLocal,
        fechaRevision: DateTime.now(),
      );
      await actualizar(actualizado, existente.id!);
    } else {
      // Crear nuevo
      final nuevo = EstadoEquipo(
        equipoId: equipoId,
        clienteId: clienteId,
        enLocal: enLocal,
        fechaRevision: DateTime.now(),
        fechaCreacion: DateTime.now(),
      );
      await insertar(nuevo);
    }
  }

  /// Obtener estado por equipo y cliente
  Future<EstadoEquipo?> obtenerPorEquipoYCliente(int equipoId, int clienteId) async {
    final maps = await dbHelper.consultar(
      tableName,
      where: 'equipo_id = ? AND id_clientes = ?',
      whereArgs: [equipoId, clienteId],
      orderBy: 'fecha_revision DESC',
      limit: 1,
    );
    return maps.isNotEmpty ? fromMap(maps.first) : null;
  }

  /// Obtener estados por equipo
  Future<List<EstadoEquipo>> obtenerPorEquipo(int equipoId) async {
    final maps = await dbHelper.consultar(
      tableName,
      where: 'equipo_id = ?',
      whereArgs: [equipoId],
      orderBy: getDefaultOrderBy(),
    );
    return maps.map((map) => fromMap(map)).toList();
  }

  /// Obtener estados por cliente
  Future<List<EstadoEquipo>> obtenerPorCliente(int clienteId) async {
    final maps = await dbHelper.consultar(
      tableName,
      where: 'id_clientes = ?',
      whereArgs: [clienteId],
      orderBy: getDefaultOrderBy(),
    );
    return maps.map((map) => fromMap(map)).toList();
  }
}