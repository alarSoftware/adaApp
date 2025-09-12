import '../models/estado_equipo.dart';
import 'base_repository.dart';
import 'package:logger/logger.dart';

class EstadoEquipoRepository extends BaseRepository<EstadoEquipo> {
  final Logger _logger = Logger();

  @override
  String get tableName => 'Estado_Equipo';

  @override
  EstadoEquipo fromMap(Map<String, dynamic> map) => EstadoEquipo.fromMap(map);

  @override
  Map<String, dynamic> toMap(EstadoEquipo estadoEquipo) => estadoEquipo.toMap();

  @override
  String getDefaultOrderBy() => 'fecha_revision DESC';

  @override
  String getBuscarWhere() => 'CAST(equipo_cliente_id AS TEXT) LIKE ?';

  @override
  List<dynamic> getBuscarArgs(String query) {
    final searchTerm = '%${query.toLowerCase()}%';
    return [searchTerm];
  }

  @override
  String getEntityName() => 'EstadoEquipo';

  // ========== MÉTODOS ESPECÍFICOS PARA ESTADO_EQUIPO (NUEVA ESTRUCTURA) ==========

  /// Crear nuevo estado con GPS
  Future<EstadoEquipo> crearNuevoEstado({
    required int equipoClienteId,
    required bool enLocal,
    required DateTime fechaRevision,
    double? latitud,
    double? longitud,
    String? estadoCenso,
  }) async {
    final nuevoEstado = EstadoEquipo(
      equipoClienteId: equipoClienteId,
      enLocal: enLocal,
      fechaRevision: fechaRevision,
      fechaCreacion: DateTime.now(),
      fechaActualizacion: DateTime.now(),
      estaSincronizado: false,
      latitud: latitud,
      longitud: longitud,
      estadoCenso: estadoCenso ?? 'creado',
    );

    final id = await insertar(nuevoEstado);
    return nuevoEstado.copyWith(id: id);
  }

  /// Registrar escaneo de equipo con ubicación
  Future<EstadoEquipo> registrarEscaneoEquipo({
    required int equipoClienteId,
    required double latitud,
    required double longitud,
  }) async {
    final nuevoEstado = EstadoEquipo(
      equipoClienteId: equipoClienteId,
      enLocal: true,
      fechaRevision: DateTime.now(),
      fechaCreacion: DateTime.now(),
      fechaActualizacion: DateTime.now(),
      estaSincronizado: false,
      latitud: latitud,
      longitud: longitud,
      estadoCenso: 'creado',
    );

    final id = await insertar(nuevoEstado);
    return nuevoEstado.copyWith(id: id);
  }

  /// Obtener historial completo por equipo_cliente_id
  Future<List<EstadoEquipo>> obtenerHistorialCompleto(int equipoClienteId) async {
    try {
      final maps = await dbHelper.consultar(
        tableName,
        where: 'equipo_cliente_id = ?',
        whereArgs: [equipoClienteId],
        orderBy: 'fecha_revision DESC',
      );
      return maps.map((map) => fromMap(map)).toList();
    } catch (e) {
      _logger.e('Error al obtener historial completo: $e');
      return [];
    }
  }

  /// Obtener estados por equipo_cliente_id
  Future<List<EstadoEquipo>> obtenerPorEquipoCliente(int equipoClienteId) async {
    try {
      final maps = await dbHelper.consultar(
        tableName,
        where: 'equipo_cliente_id = ?',
        whereArgs: [equipoClienteId],
        orderBy: 'fecha_revision DESC',
      );
      return maps.map((map) => fromMap(map)).toList();
    } catch (e) {
      _logger.e('Error al obtener estados por equipo cliente: $e');
      return [];
    }
  }

  /// Obtener estado más reciente por equipo_cliente_id
  Future<EstadoEquipo?> obtenerUltimoEstado(int equipoClienteId) async {
    try {
      final maps = await dbHelper.consultar(
        tableName,
        where: 'equipo_cliente_id = ?',
        whereArgs: [equipoClienteId],
        orderBy: 'fecha_revision DESC',
        limit: 1,
      );
      return maps.isNotEmpty ? fromMap(maps.first) : null;
    } catch (e) {
      _logger.e('Error al obtener último estado: $e');
      return null;
    }
  }

  /// Obtener últimos N cambios
  Future<List<EstadoEquipo>> obtenerUltimosCambios(int equipoClienteId, {int limite = 5}) async {
    try {
      final maps = await dbHelper.consultar(
        tableName,
        where: 'equipo_cliente_id = ?',
        whereArgs: [equipoClienteId],
        orderBy: 'fecha_revision DESC',
        limit: limite,
      );
      return maps.map((map) => fromMap(map)).toList();
    } catch (e) {
      _logger.e('Error al obtener últimos cambios: $e');
      return [];
    }
  }

  /// Obtener registros no sincronizados
  @override
  Future<List<EstadoEquipo>> obtenerNoSincronizados() async {
    try {
      final maps = await dbHelper.consultar(
        tableName,
        where: 'sincronizado = ?',
        whereArgs: [0],
        orderBy: 'fecha_creacion ASC',
      );
      return maps.map((map) => fromMap(map)).toList();
    } catch (e) {
      _logger.e('Error al obtener no sincronizados: $e');
      return [];
    }
  }

  /// Marcar como sincronizado
  Future<void> marcarComoSincronizado(int id) async {
    try {
      await dbHelper.actualizar(
        tableName,
        {
          'sincronizado': 1,
          'fecha_actualizacion': DateTime.now().toIso8601String()
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      _logger.e('Error al marcar como sincronizado: $e');
      rethrow;
    }
  }

  /// Marcar múltiples como sincronizados
  Future<void> marcarMultiplesComoSincronizados(List<int> ids) async {
    if (ids.isEmpty) return;

    try {
      final idsString = ids.join(',');
      await dbHelper.actualizar(
        tableName,
        {
          'sincronizado': 1,
          'fecha_actualizacion': DateTime.now().toIso8601String()
        },
        where: 'id IN ($idsString)',
      );
    } catch (e) {
      _logger.e('Error al marcar múltiples como sincronizados: $e');
      rethrow;
    }
  }

  /// Contar cambios por equipo_cliente_id
  Future<int> contarCambios(int equipoClienteId) async {
    try {
      final result = await dbHelper.consultar(
        tableName,
        where: 'equipo_cliente_id = ?',
        whereArgs: [equipoClienteId],
      );
      return result.length;
    } catch (e) {
      _logger.e('Error al contar cambios: $e');
      return 0;
    }
  }

  /// Obtener estadísticas de cambios
  Future<Map<String, dynamic>> obtenerEstadisticasCambios(int equipoClienteId) async {
    try {
      final historial = await obtenerHistorialCompleto(equipoClienteId);

      if (historial.isEmpty) {
        return {
          'total_cambios': 0,
          'ultimo_cambio': null,
          'estado_actual': null,
          'cambios_pendientes': 0,
        };
      }

      final cambiosPendientes = historial.where((e) => !e.estaSincronizado).length;

      return {
        'total_cambios': historial.length,
        'ultimo_cambio': historial.first.fechaRevision,
        'estado_actual': historial.first.enLocal,
        'cambios_pendientes': cambiosPendientes,
      };
    } catch (e) {
      _logger.e('Error al obtener estadísticas: $e');
      return {
        'total_cambios': 0,
        'ultimo_cambio': null,
        'estado_actual': null,
        'cambios_pendientes': 0,
      };
    }
  }

  /// Obtener estado del equipo con datos completos (con JOIN)
  Future<Map<String, dynamic>?> obtenerEstadoConDetalles(int equipoClienteId) async {
    try {
      final sql = '''
        SELECT se.*,
               ec.equipo_id,
               ec.cliente_id,
               e.cod_barras,
               e.numero_serie,
               m.nombre as marca_nombre,
               mo.nombre as modelo_nombre,
               c.nombre as cliente_nombre
        FROM Estado_Equipo se
        JOIN equipo_cliente ec ON se.equipo_cliente_id = ec.id
        JOIN equipos e ON ec.equipo_id = e.id
        JOIN marcas m ON e.marca_id = m.id
        JOIN modelos mo ON e.modelo_id = mo.id
        JOIN clientes c ON ec.cliente_id = c.id
        WHERE se.equipo_cliente_id = ?
        ORDER BY se.fecha_revision DESC
        LIMIT 1
      ''';

      final result = await dbHelper.consultarPersonalizada(sql, [equipoClienteId]);
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      _logger.e('Error obteniendo estado con detalles: $e');
      return null;
    }
  }

  /// Preparar datos para sincronización
  Future<List<Map<String, dynamic>>> prepararDatosParaSincronizacion() async {
    try {
      final noSincronizados = await obtenerNoSincronizados();
      return noSincronizados.map((estado) => estado.toJson()).toList();
    } catch (e) {
      _logger.e('Error al preparar datos para sincronización: $e');
      return [];
    }
  }

  /// Limpiar historial antiguo
  Future<void> limpiarHistorialAntiguo({int diasAntiguedad = 90}) async {
    try {
      final fechaLimite = DateTime.now().subtract(Duration(days: diasAntiguedad));

      await dbHelper.eliminar(
        tableName,
        where: 'fecha_creacion < ? AND sincronizado = ?',
        whereArgs: [fechaLimite.toIso8601String(), 1],
      );
    } catch (e) {
      _logger.e('Error al limpiar historial antiguo: $e');
      rethrow;
    }
  }

  // ========== MÉTODOS DE COMPATIBILIDAD (Para migración gradual) ==========

  /// Buscar equipoClienteId basado en equipoId y clienteId
  Future<int?> buscarEquipoClienteId(int equipoId, int clienteId) async {
    try {
      final result = await dbHelper.consultar(
        'equipo_cliente',
        where: 'equipo_id = ? AND cliente_id = ? AND activo = 1',
        whereArgs: [equipoId, clienteId],
        limit: 1,
      );
      return result.isNotEmpty ? result.first['id'] as int : null;
    } catch (e) {
      _logger.e('Error buscando equipo_cliente_id: $e');
      return null;
    }
  }

  /// Método de compatibilidad - buscar por equipoId y clienteId
  Future<EstadoEquipo?> obtenerUltimoEstadoPorEquipoCliente(int equipoId, int clienteId) async {
    final equipoClienteId = await buscarEquipoClienteId(equipoId, clienteId);
    if (equipoClienteId == null) return null;

    return await obtenerUltimoEstado(equipoClienteId);
  }

  /// Método de compatibilidad - crear estado con equipoId y clienteId
  Future<EstadoEquipo?> crearNuevoEstadoLegacy({
    required int equipoId,
    required int clienteId,
    required bool enLocal,
    required DateTime fechaRevision,
    double? latitud,
    double? longitud,
  }) async {
    final equipoClienteId = await buscarEquipoClienteId(equipoId, clienteId);
    if (equipoClienteId == null) {
      _logger.w('No se encontró relación equipo_cliente para equipoId: $equipoId, clienteId: $clienteId');
      return null;
    }

    return await crearNuevoEstado(
      equipoClienteId: equipoClienteId,
      enLocal: enLocal,
      fechaRevision: fechaRevision,
      latitud: latitud,
      longitud: longitud,
    );
  }

  // ========== MÉTODOS DEPRECATED ==========

  @Deprecated('Usar crearNuevoEstado() con equipoClienteId')
  Future<void> actualizarEstadoEquipo(int equipoId, int clienteId, bool enLocal) async {
    await crearNuevoEstadoLegacy(
      equipoId: equipoId,
      clienteId: clienteId,
      enLocal: enLocal,
      fechaRevision: DateTime.now(),
    );
  }
}