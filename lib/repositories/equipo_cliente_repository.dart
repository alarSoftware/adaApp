import 'package:ada_app/models/equipos_cliente.dart';
import 'base_repository.dart';
import 'package:logger/logger.dart';

class EquipoClienteRepository extends BaseRepository<EquipoCliente> {
  final Logger _logger = Logger();

  @override
  String get tableName => 'equipo_cliente';

  @override
  EquipoCliente fromMap(Map<String, dynamic> map) => EquipoCliente.fromMap(map);

  @override
  Map<String, dynamic> toMap(EquipoCliente equipoCliente) => equipoCliente.toMap();

  @override
  String getDefaultOrderBy() => 'fecha_asignacion DESC';

  @override
  String getBuscarWhere() => 'activo = ? AND (CAST(equipo_id AS TEXT) LIKE ? OR CAST(cliente_id AS TEXT) LIKE ?)';

  @override
  List<dynamic> getBuscarArgs(String query) {
    final searchTerm = '%${query.toLowerCase()}%';
    return [1, searchTerm, searchTerm];
  }

  @override
  String getEntityName() => 'EquipoCliente';

  // ================================
  // MÉTODO PRINCIPAL PARA SEPARAR EQUIPOS POR ESTADO
  // ================================

  /// Obtener equipos completos de un cliente con información detallada
  Future<List<Map<String, dynamic>>> obtenerPorClienteCompleto(
      int clienteId, {
        bool soloActivos = true,
      }) async {
    try {
      final whereClause = soloActivos
          ? 'WHERE ec.cliente_id = ? AND ec.activo = 1 AND ec.fecha_retiro IS NULL AND e.activo = 1'
          : 'WHERE ec.cliente_id = ?';

      final whereArgs = [clienteId];

      final sql = '''
        SELECT 
          ec.*,
          e.id as equipo_id,
          e.cod_barras as equipo_cod_barras,
          e.numero_serie as equipo_numero_serie,
          e.estado_local as equipo_estado_local,
          m.id as marca_id,
          m.nombre as marca_nombre,
          mo.id as modelo_id,  
          mo.nombre as modelo_nombre,
          l.id as logo_id,
          l.nombre as logo_nombre,
          c.nombre as cliente_nombre,
          c.telefono as cliente_telefono,
          c.direccion as cliente_direccion
        FROM equipo_cliente ec
        INNER JOIN equipos e ON ec.equipo_id = e.id
        INNER JOIN marcas m ON e.marca_id = m.id
        INNER JOIN modelos mo ON e.modelo_id = mo.id
        INNER JOIN logo l ON e.logo_id = l.id
        INNER JOIN clientes c ON ec.cliente_id = c.id
        $whereClause
        ORDER BY ec.fecha_asignacion DESC
      ''';

      final result = await dbHelper.consultarPersonalizada(sql, whereArgs);

      _logger.i('Equipos encontrados para cliente $clienteId: ${result.length}');

      return result;
    } catch (e, stackTrace) {
      _logger.e('Error obteniendo equipos del cliente $clienteId: $e', stackTrace: stackTrace);
      rethrow;
    }
  }

  // ================================
  // MÉTODO PARA VERIFICAR ASIGNACIÓN
  // ================================

  /// Verificar si un equipo está asignado a un cliente específico
  Future<bool> verificarAsignacionEquipoCliente(int equipoId, int clienteId) async {
    try {
      final result = await dbHelper.consultar(
        tableName,
        where: 'equipo_id = ? AND cliente_id = ? AND activo = 1 AND fecha_retiro IS NULL',
        whereArgs: [equipoId, clienteId],
        limit: 1,
      );

      final estaAsignado = result.isNotEmpty;
      _logger.d('Equipo $equipoId ${estaAsignado ? "SÍ" : "NO"} está asignado al cliente $clienteId');

      return estaAsignado;
    } catch (e) {
      _logger.e('Error verificando asignación equipo $equipoId - cliente $clienteId: $e');
      return false;
    }
  }

  // ================================
  // MÉTODOS ADICIONALES ÚTILES
  // ================================

  /// Obtener asignaciones activas de un cliente
  Future<List<EquipoCliente>> obtenerAsignacionesActivas(int clienteId) async {
    try {
      final maps = await dbHelper.consultar(
        tableName,
        where: 'cliente_id = ? AND activo = 1 AND fecha_retiro IS NULL',
        whereArgs: [clienteId],
        orderBy: getDefaultOrderBy(),
      );

      return maps.map((map) => fromMap(map)).toList();
    } catch (e) {
      _logger.e('Error obteniendo asignaciones activas del cliente $clienteId: $e');
      rethrow;
    }
  }

  /// Obtener historial completo de asignaciones de un cliente
  Future<List<Map<String, dynamic>>> obtenerHistorialCompleto(int clienteId) async {
    try {
      final sql = '''
        SELECT 
          ec.*,
          e.cod_barras as equipo_cod_barras,
          e.numero_serie as equipo_numero_serie,
          m.nombre as marca_nombre,
          mo.nombre as modelo_nombre,
          l.nombre as logo_nombre
        FROM equipo_cliente ec
        INNER JOIN equipos e ON ec.equipo_id = e.id
        INNER JOIN marcas m ON e.marca_id = m.id
        INNER JOIN modelos mo ON e.modelo_id = mo.id
        INNER JOIN logo l ON e.logo_id = l.id
        WHERE ec.cliente_id = ?
        ORDER BY ec.fecha_asignacion DESC
      ''';

      return await dbHelper.consultarPersonalizada(sql, [clienteId]);
    } catch (e) {
      _logger.e('Error obteniendo historial del cliente $clienteId: $e');
      rethrow;
    }
  }

  /// Crear nueva asignación
  Future<EquipoCliente> crearAsignacion({
    required int equipoId,
    required int clienteId,
    bool enLocal = true,
  }) async {
    try {
      // Verificar que el equipo no esté ya asignado activamente
      final yaAsignado = await verificarAsignacionEquipoCliente(equipoId, clienteId);
      if (yaAsignado) {
        throw Exception('El equipo ya está asignado a este cliente');
      }

      // Verificar que no esté asignado a otro cliente
      final result = await dbHelper.consultar(
        tableName,
        where: 'equipo_id = ? AND activo = 1 AND fecha_retiro IS NULL',
        whereArgs: [equipoId],
        limit: 1,
      );

      if (result.isNotEmpty) {
        final clienteActual = result.first['cliente_id'];
        throw Exception('El equipo ya está asignado al cliente $clienteActual');
      }

      final now = DateTime.now();
      final nuevaAsignacion = EquipoCliente(
        equipoId: equipoId,
        clienteId: clienteId,
        fechaAsignacion: now,
        estaActivo: true,
        fechaCreacion: now,
        estaSincronizado: false,
        enLocal: enLocal,
      );

      final id = await insertar(nuevaAsignacion);

      _logger.i('Asignación creada: Equipo $equipoId → Cliente $clienteId (ID: $id)');

      return nuevaAsignacion.copyWith(id: id);
    } catch (e) {
      _logger.e('Error creando asignación: $e');
      rethrow;
    }
  }
  // ================================
// MÉTODOS ESPECÍFICOS PARA ESTADOS
// ================================

  /// MÉTODO PRINCIPAL: Verificar si existe relación activa equipo-cliente
  Future<bool> existeRelacionActivaEquipoCliente(int equipoId, int clienteId) async {
    try {
      final result = await dbHelper.consultar(
        tableName,
        where: 'equipo_id = ? AND cliente_id = ? AND activo = 1 AND fecha_retiro IS NULL',
        whereArgs: [equipoId, clienteId],
        limit: 1,
      );

      final existe = result.isNotEmpty;
      _logger.d('Relación activa equipo $equipoId - cliente $clienteId: ${existe ? "SÍ EXISTS" : "NO existe"}');
      return existe;
    } catch (e) {
      _logger.e('Error verificando relación activa equipo $equipoId - cliente $clienteId: $e');
      return false;
    }
  }

  /// Obtener equipos PENDIENTES de un cliente
  Future<List<Map<String, dynamic>>> obtenerEquiposPendientes(int clienteId) async {
    try {
      final sql = '''
      SELECT 
        ec.*,
        e.id as equipo_id,
        e.cod_barras as equipo_cod_barras,
        e.numero_serie as equipo_numero_serie,
        m.nombre as marca_nombre,
        mo.nombre as modelo_nombre,
        l.nombre as logo_nombre,
        c.nombre as cliente_nombre
      FROM equipo_cliente ec
      INNER JOIN equipos e ON ec.equipo_id = e.id
      INNER JOIN marcas m ON e.marca_id = m.id
      INNER JOIN modelos mo ON e.modelo_id = mo.id
      INNER JOIN logo l ON e.logo_id = l.id
      INNER JOIN clientes c ON ec.cliente_id = c.id
      WHERE ec.cliente_id = ? 
        AND ec.estado = 'pendiente' 
        AND ec.activo = 1 
        AND ec.fecha_retiro IS NULL
      ORDER BY ec.fecha_asignacion DESC
    ''';

      final result = await dbHelper.consultarPersonalizada(sql, [clienteId]);
      _logger.i('Equipos PENDIENTES para cliente $clienteId: ${result.length}');
      return result;
    } catch (e) {
      _logger.e('Error obteniendo equipos pendientes del cliente $clienteId: $e');
      rethrow;
    }
  }

  /// Obtener equipos ASIGNADOS de un cliente
  Future<List<Map<String, dynamic>>> obtenerEquiposAsignados(int clienteId) async {
    try {
      final sql = '''
      SELECT 
        ec.*,
        e.id as equipo_id,
        e.cod_barras as equipo_cod_barras,
        e.numero_serie as equipo_numero_serie,
        m.nombre as marca_nombre,
        mo.nombre as modelo_nombre,
        l.nombre as logo_nombre,
        c.nombre as cliente_nombre
      FROM equipo_cliente ec
      INNER JOIN equipos e ON ec.equipo_id = e.id
      INNER JOIN marcas m ON e.marca_id = m.id
      INNER JOIN modelos mo ON e.modelo_id = mo.id
      INNER JOIN logo l ON e.logo_id = l.id
      INNER JOIN clientes c ON ec.cliente_id = c.id
      WHERE ec.cliente_id = ? 
        AND ec.estado = 'asignado' 
        AND ec.activo = 1 
        AND ec.fecha_retiro IS NULL
      ORDER BY ec.fecha_asignacion DESC
    ''';

      final result = await dbHelper.consultarPersonalizada(sql, [clienteId]);
      _logger.i('Equipos ASIGNADOS para cliente $clienteId: ${result.length}');
      return result;
    } catch (e) {
      _logger.e('Error obteniendo equipos asignados del cliente $clienteId: $e');
      rethrow;
    }
  }

  /// Finalizar asignación (marcar como retirada)
  Future<int> finalizarAsignacion(int equipoId, int clienteId) async {
    try {
      final count = await dbHelper.actualizar(
        tableName,
        {
          'fecha_retiro': DateTime.now().toIso8601String(),
          'activo': 0,
          'sincronizado': 0,
        },
        where: 'equipo_id = ? AND cliente_id = ? AND activo = 1',
        whereArgs: [equipoId, clienteId],
      );

      _logger.i('Asignación finalizada: Equipo $equipoId - Cliente $clienteId');
      return count;
    } catch (e) {
      _logger.e('Error finalizando asignación: $e');
      rethrow;
    }
  }

  /// Obtener estadísticas de asignaciones
  Future<Map<String, dynamic>> obtenerEstadisticas() async {
    try {
      final sql = '''
        SELECT 
          COUNT(*) as total_asignaciones,
          COUNT(CASE WHEN activo = 1 AND fecha_retiro IS NULL THEN 1 END) as asignaciones_activas,
          COUNT(CASE WHEN activo = 0 OR fecha_retiro IS NOT NULL THEN 1 END) as asignaciones_finalizadas,
          COUNT(CASE WHEN sincronizado = 0 THEN 1 END) as pendientes_sincronizacion,
          COUNT(DISTINCT cliente_id) as clientes_con_equipos,
          COUNT(DISTINCT equipo_id) as equipos_asignados
        FROM equipo_cliente
      ''';

      final result = await dbHelper.consultarPersonalizada(sql);
      return result.isNotEmpty ? result.first : {};
    } catch (e) {
      _logger.e('Error obteniendo estadísticas: $e');
      return {};
    }
  }

  /// Obtener equipos disponibles para asignar
  Future<List<Map<String, dynamic>>> obtenerEquiposDisponibles() async {
    try {
      final sql = '''
        SELECT 
          e.*,
          m.nombre as marca_nombre,
          mo.nombre as modelo_nombre,
          l.nombre as logo_nombre
        FROM equipos e
        INNER JOIN marcas m ON e.marca_id = m.id
        INNER JOIN modelos mo ON e.modelo_id = mo.id
        INNER JOIN logo l ON e.logo_id = l.id
        LEFT JOIN equipo_cliente ec ON e.id = ec.equipo_id 
          AND ec.activo = 1 
          AND ec.fecha_retiro IS NULL
        WHERE e.activo = 1 
          AND e.estado_local = 1
          AND ec.id IS NULL
        ORDER BY m.nombre, mo.nombre
      ''';

      return await dbHelper.consultarPersonalizada(sql);
    } catch (e) {
      _logger.e('Error obteniendo equipos disponibles: $e');
      rethrow;
    }
  }

  /// Sincronizar asignaciones desde API
  Future<void> sincronizarDesdeAPI(List<dynamic> asignacionesAPI) async {
    try {
      await limpiarYSincronizar(asignacionesAPI.map((item) {
        if (item is Map<String, dynamic>) {
          return EquipoCliente.fromJson(item);
        } else if (item is EquipoCliente) {
          return item;
        } else {
          throw Exception('Tipo de dato no válido para sincronización');
        }
      }).toList());

      _logger.i('Sincronización de asignaciones completada: ${asignacionesAPI.length} registros');
    } catch (e) {
      _logger.e('Error sincronizando asignaciones: $e');
      rethrow;
    }
  }


  /// MÉTODO PARA EL FLUJO DE CENSO: Procesar escaneo de equipo
  Future<EquipoCliente> procesarEscaneoCenso({
    required int equipoId,
    required int clienteId,
  }) async {
    try {
      final now = DateTime.now();

      // Verificar si ya existe la relación
      final yaExiste = await existeRelacionActivaEquipoCliente(equipoId, clienteId);

      if (yaExiste) {
        // Ya existe - mantener como asignado, solo actualizar fecha
        await dbHelper.actualizar(
          tableName,
          {
            'fecha_actualizacion': now.toIso8601String(),
            'sincronizado': 0,
          },
          where: 'equipo_id = ? AND cliente_id = ? AND activo = 1',
          whereArgs: [equipoId, clienteId],
        );

        // Obtener el registro existente
        final result = await dbHelper.consultar(
          tableName,
          where: 'equipo_id = ? AND cliente_id = ? AND activo = 1',
          whereArgs: [equipoId, clienteId],
          limit: 1,
        );

        _logger.i('Equipo $equipoId ya asignado al cliente $clienteId - actualizado');
        return EquipoCliente.fromMap(result.first);
      } else {
        // No existe - crear nuevo registro como PENDIENTE
        final nuevoRegistro = EquipoCliente(
          equipoId: equipoId,
          clienteId: clienteId,
          estado: EstadoEquipoCliente.pendiente,
          fechaAsignacion: now,
          estaActivo: true,
          fechaCreacion: now,
          estaSincronizado: false,
        );

        final id = await insertar(nuevoRegistro);
        _logger.i('Nueva asignación PENDIENTE creada: Equipo $equipoId → Cliente $clienteId (ID: $id)');

        return nuevoRegistro.copyWith(id: id);
      }
    } catch (e) {
      _logger.e('Error procesando escaneo de censo: $e');
      rethrow;
    }
  }
  /// Obtener resumen para dashboard
  Future<Map<String, dynamic>> obtenerResumenDashboard() async {
    try {
      final sql = '''
        SELECT 
          COUNT(*) as total_asignaciones,
          COUNT(CASE WHEN ec.activo = 1 AND ec.fecha_retiro IS NULL THEN 1 END) as activas,
          COUNT(CASE WHEN ec.activo = 0 OR ec.fecha_retiro IS NOT NULL THEN 1 END) as finalizadas,
          COUNT(DISTINCT ec.cliente_id) as clientes_con_equipos,
          COUNT(DISTINCT ec.equipo_id) as equipos_en_uso,
          AVG(JULIANDAY('now') - JULIANDAY(ec.fecha_asignacion)) as promedio_dias_asignacion
        FROM equipo_cliente ec
        WHERE ec.activo = 1 AND ec.fecha_retiro IS NULL
      ''';

      final result = await dbHelper.consultarPersonalizada(sql);
      return result.isNotEmpty ? result.first : {};
    } catch (e) {
      _logger.e('Error obteniendo resumen para dashboard: $e');
      return {};
    }
  }
}