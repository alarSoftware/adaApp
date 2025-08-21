import '../models/cliente.dart';
import 'base_repository.dart';

class ClienteRepository extends BaseRepository<Cliente> {
  @override
  String get tableName => 'clientes';

  @override
  Cliente fromMap(Map<String, dynamic> map) => Cliente.fromMap(map);

  @override
  Map<String, dynamic> toMap(Cliente cliente) => cliente.toMap();

  @override
  String getDefaultOrderBy() => 'nombre ASC';

  @override
  String getBuscarWhere() =>
      'activo = ? AND (LOWER(nombre) LIKE ? OR LOWER(email) LIKE ? OR telefono LIKE ?)';

  @override
  List<dynamic> getBuscarArgs(String query) {
    final searchTerm = '%${query.toLowerCase()}%';
    return [1, searchTerm, searchTerm, searchTerm];
  }

  @override
  String getEntityName() => 'Cliente';

  // Métodos específicos de Cliente
  Future<Cliente?> obtenerPorEmail(String email) async {
    final clientes = await buscar(email); // Usa método genérico
    return clientes.isNotEmpty ? clientes.first : null;
  }

  Future<bool> existeEmail(String email) async {
    final clientes = await buscar(email);
    return clientes.isNotEmpty;
  }
}
