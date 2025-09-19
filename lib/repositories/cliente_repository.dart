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
      'LOWER(nombre) LIKE ? OR LOWER(propietario) LIKE ? OR LOWER(ruc_ci) LIKE ? OR LOWER(telefono) LIKE ? OR LOWER(direccion) LIKE ? OR CAST(codigo AS TEXT) LIKE ?';

  @override
  List<dynamic> getBuscarArgs(String query) {
    final searchTerm = '%${query.toLowerCase()}%';
    return [searchTerm, searchTerm, searchTerm, searchTerm, searchTerm, searchTerm];
  }

  @override
  String getEntityName() => 'Cliente';

  // Métodos específicos de Cliente (actualizados para el nuevo modelo)
  Future<Cliente?> obtenerPorRucCi(String rucCi) async {
    final clientes = await buscar(rucCi);
    return clientes.isNotEmpty ? clientes.first : null;
  }

  Future<bool> existeRucCi(String rucCi) async {
    final clientes = await buscar(rucCi);
    return clientes.isNotEmpty;
  }
}