import 'package:ada_app/models/equipos_extraviados.dart';
import '../utils/logger.dart';
import 'base_repository.dart';
import 'package:ada_app/services/api/auth_service.dart';
import 'package:sqflite/sqflite.dart';

class EquipoExtraviadoRepository extends BaseRepository<EquiposExtraviados> {
  @override
  String get tableName => 'equipos_extraviados';

  @override
  EquiposExtraviados fromMap(Map<String, dynamic> map) =>
      EquiposExtraviados.fromMap(map);

  @override
  Map<String, dynamic> toMap(EquiposExtraviados equipoExtraviado) =>
      equipoExtraviado.toMap();

  @override
  String getDefaultOrderBy() => 'fecha_creacion DESC';

  @override
  String getBuscarWhere() =>
      'CAST(equipo_id AS TEXT) LIKE ? OR CAST(cliente_id AS TEXT) LIKE ?';

  @override
  List<dynamic> getBuscarArgs(String query) {
    final searchTerm = '%${query.toLowerCase()}%';
    return [searchTerm, searchTerm];
  }

  @override
  String getEntityName() => 'EquipoExtraviado';

  /// Obtener equipos EXTRAVIADOS de un cliente
  Future<List<Map<String, dynamic>>> obtenerEquiposExtraviadosPorCliente(
    int clienteId,
  ) async {
    try {
      final sql = '''
    SELECT DISTINCT
      ee.id,
      ee.equipo_id,
      ee.cliente_id,
      ee.fecha_creacion,
      e.cod_barras,
      e.numero_serie,
      m.nombre as marca_nombre,
      mo.nombre as modelo_nombre,
      l.nombre as logo_nombre,
      c.nombre as cliente_nombre,
      'extraviado' as estado,
      'extraviado' as tipo_estado
    FROM equipos_extraviados ee
    INNER JOIN equipos e ON ee.equipo_id = e.id
    INNER JOIN marcas m ON e.marca_id = m.id
    INNER JOIN modelos mo ON e.modelo_id = mo.id
    INNER JOIN logo l ON e.logo_id = l.id
    INNER JOIN clientes c ON ee.cliente_id = c.id
    WHERE ee.cliente_id = ?
    ORDER BY ee.fecha_creacion DESC
  ''';

      final result = await dbHelper.consultarPersonalizada(sql, [clienteId]);

      return result;
    } catch (e) {
      rethrow;
    }
  }

  Future<int> guardarEquiposExtraviadosDesdeServidor(
    List<Map<String, dynamic>> equiposAPI,
  ) async {
    final db = await dbHelper.database;
    int guardados = 0;

    await db.transaction((txn) async {
      await txn.delete(tableName);

      for (var equipoAPI in equiposAPI) {
        try {
          final equipoLocal = {
            'id': equipoAPI['id'],
            'equipo_id': equipoAPI['edfEquipoId'],
            'cliente_id': equipoAPI['edfClienteId'],
            'fecha_creacion': equipoAPI['creationDate'],
            'fecha_actualizacion': DateTime.now().toIso8601String(),
            'fecha_censo': equipoAPI['creationDate'],
            'usuario_censo_id':
                equipoAPI['usuarioId'] ?? equipoAPI['usuario']?['id'] ?? 1,
            'employee_id':
                equipoAPI['edfVendedorSucursalId'] ?? equipoAPI['employeeId'],
            'sincronizado': 1,
            'fecha_sincronizacion': DateTime.now().toIso8601String(),
          };

          await txn.insert(
            tableName,
            equipoLocal,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );

          guardados++;
        } catch (e) {
          AppLogger.e("EQUIPO_EXTRAVIADO_REPOSITORY: Error", e);
        }
      }
    });

    return guardados;
  }
}
