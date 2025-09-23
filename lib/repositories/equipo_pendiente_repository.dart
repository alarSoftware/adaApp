import 'package:ada_app/models/equipos_pendientes.dart';
import 'base_repository.dart';
import 'package:logger/logger.dart';

class EquipoPendienteRepository extends BaseRepository<EquiposPendientes> {
  final Logger _logger = Logger();

  @override
  String get tableName => 'equipos_pendientes';

  @override
  EquiposPendientes fromMap(Map<String, dynamic> map) => EquiposPendientes.fromMap(map);

  @override
  Map<String, dynamic> toMap(EquiposPendientes equipoPendiente) => equipoPendiente.toMap();

  @override
  String getDefaultOrderBy() => 'fecha_creacion DESC';

  @override
  String getBuscarWhere() => 'CAST(equipo_id AS TEXT) LIKE ? OR CAST(cliente_id AS TEXT) LIKE ?';

  @override
  List<dynamic> getBuscarArgs(String query) {
    final searchTerm = '%${query.toLowerCase()}%';
    return [searchTerm, searchTerm];
  }

  @override
  String getEntityName() => 'EquipoPendiente';

  /// Obtener equipos PENDIENTES de un cliente
  Future<List<Map<String, dynamic>>> obtenerEquiposPendientesPorCliente(int clienteId) async {
    try {
      final sql = '''
      SELECT 
        ep.*,
        e.cod_barras,
        e.numero_serie,
        m.nombre as marca_nombre,
        mo.nombre as modelo_nombre,
        l.nombre as logo_nombre,
        c.nombre as cliente_nombre,
        'pendiente' as estado
      FROM equipos_pendientes ep
      INNER JOIN equipos e ON ep.equipo_id = e.id
      INNER JOIN marcas m ON e.marca_id = m.id
      INNER JOIN modelos mo ON e.modelo_id = mo.id
      INNER JOIN logo l ON e.logo_id = l.id
      INNER JOIN clientes c ON ep.cliente_id = c.id
      WHERE ep.cliente_id = ?
      ORDER BY ep.fecha_creacion DESC
    ''';

      final result = await dbHelper.consultarPersonalizada(sql, [clienteId]);
      _logger.i('Equipos PENDIENTES para cliente $clienteId: ${result.length}');
      return result;
    } catch (e) {
      _logger.e('Error obteniendo equipos pendientes del cliente $clienteId: $e');
      rethrow;
    }
  }

  /// Buscar ID del registro pendiente (para EstadoEquipoRepository)
  Future<int?> buscarEquipoPendienteId(int equipoId, int clienteId) async {
    try {
      final maps = await dbHelper.consultar(
        tableName,
        where: 'equipo_id = ? AND cliente_id = ?',
        whereArgs: [equipoId, clienteId],
        limit: 1,
      );

      return maps.isNotEmpty ? maps.first['id'] as int? : null;
    } catch (e) {
      _logger.e('Error buscando ID de equipo pendiente: $e');
      return null;
    }
  }

  /// Procesar escaneo de censo - crear registro pendiente
  Future<int> procesarEscaneoCenso({
    required int equipoId,
    required int clienteId,
  }) async {
    try {
      final now = DateTime.now();

      // Verificar si ya existe
      final existe = await buscarEquipoPendienteId(equipoId, clienteId);
      if (existe != null) {
        _logger.i('Ya existe registro pendiente para equipoId: $equipoId, clienteId: $clienteId');
        return existe;
      }

      // Crear nuevo registro
      final datos = {
        'equipo_id': equipoId,
        'cliente_id': clienteId,
        'fecha_censo': now.toIso8601String(),
        'usuario_censo_id': 1,
        'latitud': 0.0, // Se actualizará con GPS real
        'longitud': 0.0, // Se actualizará con GPS real
        'observaciones': 'Registro creado desde censo móvil',
      };

      final id = await crear(datos);
      _logger.i('Registro pendiente creado: Equipo $equipoId → Cliente $clienteId (ID: $id)');
      return id;
    } catch (e) {
      _logger.e('Error procesando escaneo de censo: $e');
      rethrow;
    }
  }

  /// Crear nuevo registro de equipo pendiente
  Future<int> crear(Map<String, dynamic> datos) async {
    try {
      final registroData = {
        'equipo_id': datos['equipo_id'],
        'cliente_id': datos['cliente_id'],
        'fecha_censo': datos['fecha_censo'],
        'usuario_censo_id': datos['usuario_censo_id'],
        'latitud': datos['latitud'],
        'longitud': datos['longitud'],
        'observaciones': datos['observaciones'],
        'fecha_creacion': DateTime.now().toIso8601String(),
        'fecha_actualizacion': DateTime.now().toIso8601String(),
      };

      final id = await dbHelper.insertar(tableName, registroData);
      _logger.i('Registro creado con ID: $id');
      return id;
    } catch (e) {
      _logger.e('Error creando registro: $e');
      rethrow;
    }
  }
}