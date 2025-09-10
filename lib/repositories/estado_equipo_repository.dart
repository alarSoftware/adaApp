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
  String getBuscarWhere() => 'CAST(equipo_id AS TEXT) LIKE ? OR CAST(id_clientes AS TEXT) LIKE ?';

  @override
  List<dynamic> getBuscarArgs(String query) {
    final searchTerm = '%${query.toLowerCase()}%';
    return [searchTerm, searchTerm];
  }

  @override
  String getEntityName() => 'EstadoEquipo';

  // ========== MÉTODOS ESPECÍFICOS PARA ESTADO_EQUIPO ==========

  /// Crear nuevo estado con GPS
  Future<EstadoEquipo> crearNuevoEstado({
    required int equipoId,
    required int clienteId,
    required bool enLocal,
    required DateTime fechaRevision,
    String estado = 'ASIGNADO', // AGREGAR PARÁMETRO
    double? latitud,
    double? longitud,
  }) async {
    final nuevoEstado = EstadoEquipo(
      equipoId: equipoId,
      clienteId: clienteId,
      enLocal: enLocal,
      fechaRevision: fechaRevision,
      fechaCreacion: DateTime.now(),
      fechaActualizacion: DateTime.now(),
      estaSincronizado: false,
      estado: estado, // USAR EL PARÁMETRO
      latitud: latitud,
      longitud: longitud,
    );

    final id = await insertar(nuevoEstado);
    return nuevoEstado.copyWith(id: id);
  }

  /// Registrar escaneo de equipo con ubicación
  Future<EstadoEquipo> registrarEscaneoEquipo({
    required int equipoId,
    required int clienteId,
    required double latitud,
    required double longitud,
  }) async {
    final nuevoEstado = EstadoEquipo(
      equipoId: equipoId,
      clienteId: clienteId,
      enLocal: true,
      fechaRevision: DateTime.now(),
      fechaCreacion: DateTime.now(),
      fechaActualizacion: DateTime.now(),
      estaSincronizado: false,
      latitud: latitud,
      longitud: longitud,
    );

    final id = await insertar(nuevoEstado);
    return nuevoEstado.copyWith(id: id);
  }

  /// Obtener historial completo por equipo y cliente
  Future<List<EstadoEquipo>> obtenerHistorialCompleto(int equipoId, int clienteId) async {
    try {
      final maps = await dbHelper.consultar(
        tableName,
        where: 'equipo_id = ? AND id_clientes = ?',
        whereArgs: [equipoId, clienteId],
        orderBy: 'fecha_revision DESC',
      );
      return maps.map((map) => fromMap(map)).toList();
    } catch (e) {
      _logger.e('Error al obtener historial completo: $e');
      return [];
    }
  }

  /// Obtener estados por equipo y cliente (MÉTODO ÚNICO)
  Future<List<EstadoEquipo>> obtenerPorEquipoCliente(int equipoId, int clienteId) async {
    try {
      final maps = await dbHelper.consultar(
        tableName,
        where: 'equipo_id = ? AND id_clientes = ?',
        whereArgs: [equipoId, clienteId],
        orderBy: 'fecha_revision DESC',
      );
      return maps.map((map) => fromMap(map)).toList();
    } catch (e) {
      _logger.e('Error al obtener estados por equipo y cliente: $e');
      return [];
    }
  }

  /// Obtener estado más reciente por equipo y cliente
  Future<EstadoEquipo?> obtenerUltimoEstadoPorEquipoCliente(int equipoId, int clienteId) async {
    try {
      final maps = await dbHelper.consultar(
        tableName,
        where: 'equipo_id = ? AND id_clientes = ?',
        whereArgs: [equipoId, clienteId],
        orderBy: 'fecha_revision DESC',
        limit: 1,
      );
      return maps.isNotEmpty ? fromMap(maps.first) : null;
    } catch (e) {
      _logger.e('Error al obtener último estado: $e');
      return null;
    }
  }

  /// Obtener estados por equipo (todos los clientes)
  Future<List<EstadoEquipo>> obtenerPorEquipo(int equipoId) async {
    try {
      final maps = await dbHelper.consultar(
        tableName,
        where: 'equipo_id = ?',
        whereArgs: [equipoId],
        orderBy: getDefaultOrderBy(),
      );
      return maps.map((map) => fromMap(map)).toList();
    } catch (e) {
      _logger.e('Error al obtener estados por equipo: $e');
      return [];
    }
  }

  /// Obtener últimos N cambios
  Future<List<EstadoEquipo>> obtenerUltimosCambios(int equipoId, int clienteId, {int limite = 5}) async {
    try {
      final maps = await dbHelper.consultar(
        tableName,
        where: 'equipo_id = ? AND id_clientes = ?',
        whereArgs: [equipoId, clienteId],
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

  /// Contar cambios por equipo y cliente
  Future<int> contarCambios(int equipoId, int clienteId) async {
    try {
      final result = await dbHelper.consultar(
        tableName,
        where: 'equipo_id = ? AND id_clientes = ?',
        whereArgs: [equipoId, clienteId],
      );
      return result.length;
    } catch (e) {
      _logger.e('Error al contar cambios: $e');
      return 0;
    }
  }

  /// Obtener estadísticas de cambios
  Future<Map<String, dynamic>> obtenerEstadisticasCambios(int equipoId, int clienteId) async {
    try {
      final historial = await obtenerHistorialCompleto(equipoId, clienteId);

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

  /// Obtener último estado del equipo (para compatibilidad)
  Future<Map<String, dynamic>?> obtenerUltimoEstadoEquipo(int equipoId, int clienteId) async {
    try {
      final maps = await dbHelper.consultar(
        tableName,
        where: 'equipo_id = ? AND id_clientes = ?',
        whereArgs: [equipoId, clienteId],
        orderBy: 'fecha_revision DESC',
        limit: 1,
      );

      return maps.isNotEmpty ? maps.first : null;
    } catch (e) {
      _logger.e('Error obteniendo último estado del equipo $equipoId para cliente $clienteId: $e');
      return null;
    }
  }

  /// Preparar datos para sincronización
  Future<List<Map<String, dynamic>>> prepararDatosParaSincronizacion() async {
    try {
      final noSincronizados = await obtenerNoSincronizados();
      return noSincronizados.map((estado) => estado.toMap()).toList();
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

  // ========== MÉTODOS LEGACY (DEPRECATED) ==========

  @Deprecated('Usar crearNuevoEstado() en su lugar')
  Future<void> actualizarEstadoEquipo(int equipoId, int clienteId, bool enLocal) async {
    await crearNuevoEstado(
      equipoId: equipoId,
      clienteId: clienteId,
      enLocal: enLocal,
      fechaRevision: DateTime.now(),
    );
  }

  @Deprecated('Usar obtenerUltimoEstadoPorEquipoCliente() en su lugar')
  Future<EstadoEquipo?> obtenerPorEquipoYCliente(int equipoId, int clienteId) async {
    return await obtenerUltimoEstadoPorEquipoCliente(equipoId, clienteId);
  }
}