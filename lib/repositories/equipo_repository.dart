import 'package:sqflite/sqflite.dart';
import 'package:ada_app/models/equipos.dart';
import '../repositories/base_repository.dart';
import 'package:logger/logger.dart';

class EquipoRepository extends BaseRepository<Equipo> {
  final Logger _logger = Logger();

  @override
  String get tableName => 'equipos';

  @override
  Equipo fromMap(Map<String, dynamic> map) => Equipo.fromMap(map);

  @override
  Map<String, dynamic> toMap(Equipo equipo) => equipo.toMap();

  @override
  String getDefaultOrderBy() => 'fecha_creacion DESC';

  @override
  String getBuscarWhere() => 'activo = ? AND (LOWER(cod_barras) LIKE ? OR LOWER(numero_serie) LIKE ?)';

  @override
  List<dynamic> getBuscarArgs(String query) {
    final searchTerm = '%${query.toLowerCase()}%';
    return [1, searchTerm, searchTerm];
  }

  @override
  String getEntityName() => 'Equipo';

  // ================================
  // MÉTODOS PRINCIPALES PARA ASIGNACIONES
  // ================================

  /// Obtener equipos completos de un cliente con información detallada
  Future<List<Map<String, dynamic>>> obtenerPorClienteCompleto(
      int clienteId, {
        bool soloActivos = true,
      }) async {
    try {
      final whereClause = soloActivos
          ? 'WHERE e.cliente_id = ? AND e.activo = 1'
          : 'WHERE e.cliente_id = ?';

      final whereArgs = [clienteId];

      final sql = '''
        SELECT 
          e.*,
          m.id as marca_id,
          m.nombre as marca_nombre,
          mo.id as modelo_id,  
          mo.nombre as modelo_nombre,
          l.id as logo_id,
          l.nombre as logo_nombre,
          c.nombre as cliente_nombre,
          c.telefono as cliente_telefono,
          c.direccion as cliente_direccion
        FROM equipos e
        INNER JOIN marcas m ON e.marca_id = m.id
        INNER JOIN modelos mo ON e.modelo_id = mo.id
        INNER JOIN logo l ON e.logo_id = l.id
        INNER JOIN clientes c ON e.cliente_id = c.id
        $whereClause
        ORDER BY e.fecha_asignacion DESC
      ''';

      final result = await dbHelper.consultarPersonalizada(sql, whereArgs);

      _logger.i('Equipos encontrados para cliente $clienteId: ${result.length}');

      return result;
    } catch (e, stackTrace) {
      _logger.e('Error obteniendo equipos del cliente $clienteId: $e', stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Verificar si un equipo está asignado a un cliente específico
  Future<bool> verificarAsignacionEquipoCliente(int equipoId, int clienteId) async {
    try {
      final result = await dbHelper.consultar(
        tableName,
        where: 'id = ? AND cliente_id = ? AND activo = 1',
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

  /// Verificar si existe relación activa equipo-cliente
  Future<bool> existeRelacionActivaEquipoCliente(int equipoId, int clienteId) async {
    try {
      final result = await dbHelper.consultar(
        tableName,
        where: 'id = ? AND cliente_id = ? AND activo = 1',
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

  // ================================
  // MÉTODOS PARA ESTADOS DE EQUIPOS
  // ================================

  /// Obtener equipos PENDIENTES de un cliente
  Future<List<Map<String, dynamic>>> obtenerEquiposPendientes(int clienteId) async {
    try {
      final sql = '''
      SELECT 
        e.*,
        m.nombre as marca_nombre,
        mo.nombre as modelo_nombre,
        l.nombre as logo_nombre,
        c.nombre as cliente_nombre,
        'pendiente' as estado
      FROM equipos e
      INNER JOIN marcas m ON e.marca_id = m.id
      INNER JOIN modelos mo ON e.modelo_id = mo.id
      INNER JOIN logo l ON e.logo_id = l.id
      INNER JOIN clientes c ON e.cliente_id = c.id
      WHERE e.cliente_id = ? 
        AND e.activo = 1
        AND e.estado_local = 0
      ORDER BY e.fecha_creacion DESC
    ''';

      final result = await dbHelper.consultarPersonalizada(sql, [clienteId.toString()]);
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
      // DEBUG: Verificar datos antes de la consulta principal
      final debugSql = '''
        SELECT COUNT(*) as total,
               COUNT(CASE WHEN cliente_id = ? THEN 1 END) as con_cliente_id,
               COUNT(CASE WHEN estado_local = 1 THEN 1 END) as estado_local_1
        FROM equipos 
        WHERE activo = 1
      ''';

      final debugResult = await dbHelper.consultarPersonalizada(debugSql, [clienteId.toString()]);
      _logger.i('=== DEBUG ASIGNADOS ===');
      _logger.i('Total activos: ${debugResult.first['total']}');
      _logger.i('Con cliente_id $clienteId: ${debugResult.first['con_cliente_id']}');
      _logger.i('Con estado_local=1: ${debugResult.first['estado_local_1']}');

      final sql = '''
      SELECT 
        e.*,
        m.nombre as marca_nombre,
        mo.nombre as modelo_nombre,
        l.nombre as logo_nombre,
        c.nombre as cliente_nombre,
        'asignado' as estado
      FROM equipos e
      INNER JOIN marcas m ON e.marca_id = m.id
      INNER JOIN modelos mo ON e.modelo_id = mo.id
      INNER JOIN logo l ON e.logo_id = l.id
      INNER JOIN clientes c ON e.cliente_id = c.id
      WHERE e.cliente_id = ? 
        AND e.activo = 1
        AND e.estado_local = 1
      ORDER BY e.fecha_creacion DESC
    ''';

      final result = await dbHelper.consultarPersonalizada(sql, [clienteId.toString()]);
      _logger.i('Equipos ASIGNADOS para cliente $clienteId: ${result.length}');
      return result;
    } catch (e) {
      _logger.e('Error obteniendo equipos asignados del cliente $clienteId: $e');
      rethrow;
    }
  }

  /// Obtener equipos disponibles para asignar (sin cliente)
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
        WHERE e.activo = 1 
          AND e.estado_local = 1
          AND (e.cliente_id IS NULL OR e.cliente_id = '' OR e.cliente_id = '0')
        ORDER BY m.nombre, mo.nombre
      ''';

      return await dbHelper.consultarPersonalizada(sql);
    } catch (e) {
      _logger.e('Error obteniendo equipos disponibles: $e');
      rethrow;
    }
  }

  // ================================
  // MÉTODOS DE ASIGNACIÓN Y GESTIÓN
  // ================================

  /// Crear nueva asignación (asignar equipo a cliente)
  Future<int> crearAsignacion({
    required int equipoId,
    required int clienteId,
    String estado = 'asignado',
  }) async {
    try {
      // Verificar que el equipo exista y esté disponible
      final equipo = await obtenerPorId(equipoId);
      if (equipo == null) {
        throw Exception('El equipo no existe');
      }

      if (equipo.clienteId != null && equipo.clienteId!.isNotEmpty && equipo.clienteId != '0') {
        throw Exception('El equipo ya está asignado al cliente ${equipo.clienteId}');
      }

      final now = DateTime.now();
      final count = await dbHelper.actualizar(
        tableName,
        {
          'cliente_id': clienteId?.toString(),
          'estado': estado,
          'fecha_asignacion': now.toIso8601String(),
          'fecha_actualizacion': now.toIso8601String(),
          'sincronizado': 0,
        },
        where: 'id = ?',
        whereArgs: [equipoId],
      );

      _logger.i('Asignación creada: Equipo $equipoId → Cliente $clienteId');
      return count;
    } catch (e) {
      _logger.e('Error creando asignación: $e');
      rethrow;
    }
  }

  /// Finalizar asignación (liberar equipo)
  Future<int> finalizarAsignacion(int equipoId, int clienteId) async {
    try {
      final count = await dbHelper.actualizar(
        tableName,
        {
          'cliente_id': null,
          'fecha_retiro': DateTime.now().toIso8601String(),
          'fecha_actualizacion': DateTime.now().toIso8601String(),
          'sincronizado': 0,
        },
        where: 'id = ? AND cliente_id = ? AND activo = 1',
        whereArgs: [equipoId, clienteId.toString()],
      );

      _logger.i('Asignación finalizada: Equipo $equipoId liberado del Cliente $clienteId');
      return count;
    } catch (e) {
      _logger.e('Error finalizando asignación: $e');
      rethrow;
    }
  }

  /// MÉTODO PARA EL FLUJO DE CENSO: Procesar escaneo de equipo
  Future<Equipo?> procesarEscaneoCenso({
    required int equipoId,
    required int clienteId,
  }) async {
    try {
      final now = DateTime.now();

      // Obtener el equipo actual
      final equipo = await obtenerPorId(equipoId);
      if (equipo == null) {
        throw Exception('Equipo no encontrado');
      }

      // Verificar si ya está asignado al cliente
      if (equipo.clienteId == clienteId.toString()) {
        // Ya está asignado - mantener como asignado, solo actualizar fecha
        await dbHelper.actualizar(
          tableName,
          {
            'fecha_actualizacion': now.toIso8601String(),
            'sincronizado': 0,
          },
          where: 'id = ?',
          whereArgs: [equipoId],
        );

        _logger.i('Equipo $equipoId ya asignado al cliente $clienteId - actualizado');
        return await obtenerPorId(equipoId);
      } else {
        // No está asignado a este cliente - asignar como PENDIENTE
        await dbHelper.actualizar(
          tableName,
          {
            'cliente_id': clienteId.toString(),
            'estado_local': 0, // 0 = pendiente, 1 = asignado
            'fecha_actualizacion': now.toIso8601String(),
            'sincronizado': 0,
          },
          where: 'id = ?',
          whereArgs: [equipoId],
        );

        _logger.i('Nueva asignación PENDIENTE: Equipo $equipoId → Cliente $clienteId');
        return await obtenerPorId(equipoId);
      }
    } catch (e) {
      _logger.e('Error procesando escaneo de censo: $e');
      rethrow;
    }
  }

  // ================================
  // BÚSQUEDA CON DETALLES ACTUALIZADA
  // ================================

  /// Búsqueda con detalles completos incluyendo asignación
  Future<List<Map<String, dynamic>>> buscarConDetalles(String query) async {
    if (query.trim().isEmpty) {
      return await obtenerCompletos(soloActivos: true);
    }

    final searchTerm = query.toLowerCase().trim();

    final sql = '''
    SELECT e.*,
           m.nombre as marca_nombre,
           mo.nombre as modelo_nombre,
           l.nombre as logo_nombre,
           CASE 
             WHEN e.cliente_id IS NOT NULL AND e.cliente_id != '' AND e.cliente_id != '0' THEN 'Asignado'
             ELSE 'Disponible'
           END as estado_asignacion,
           c.nombre as cliente_nombre
    FROM equipos e
    LEFT JOIN marcas m ON e.marca_id = m.id
    LEFT JOIN modelos mo ON e.modelo_id = mo.id
    LEFT JOIN logo l ON e.logo_id = l.id
    LEFT JOIN clientes c ON e.cliente_id = c.id
    WHERE e.activo = 1 
      AND (
        LOWER(TRIM(e.cod_barras)) = ? OR
        LOWER(TRIM(m.nombre)) = ? OR
        LOWER(TRIM(mo.nombre)) = ? OR
        LOWER(TRIM(l.nombre)) = ? OR
        LOWER(TRIM(e.cod_barras)) LIKE ? OR
        LOWER(TRIM(m.nombre)) LIKE ? OR
        LOWER(TRIM(mo.nombre)) LIKE ? OR
        LOWER(TRIM(l.nombre)) LIKE ? OR
        LOWER(TRIM(e.numero_serie)) LIKE ? OR
        LOWER(TRIM(c.nombre)) LIKE ?
      )
    ORDER BY 
      CASE 
        WHEN LOWER(TRIM(l.nombre)) = ? THEN 1
        WHEN LOWER(TRIM(m.nombre)) = ? THEN 1
        WHEN LOWER(TRIM(l.nombre)) LIKE ? THEN 2
        WHEN LOWER(TRIM(m.nombre)) LIKE ? THEN 2
        ELSE 3
      END,
      e.fecha_creacion DESC
    ''';

    return await dbHelper.consultarPersonalizada(sql, [
      // Exactas
      searchTerm, searchTerm, searchTerm, searchTerm,
      // Empieza con
      '$searchTerm%', '$searchTerm%', '$searchTerm%', '$searchTerm%',
      // Contiene
      '%$searchTerm%', '%$searchTerm%',
      // Para ORDER BY
      searchTerm, searchTerm, '$searchTerm%', '$searchTerm%',
    ]);
  }

  /// Obtener equipos con datos completos (método actualizado)
  Future<List<Map<String, dynamic>>> obtenerCompletos({bool soloActivos = true}) async {
    final whereClause = soloActivos ? 'WHERE e.activo = 1' : '';

    final sql = '''
      SELECT e.*,
             m.nombre as marca_nombre,
             mo.nombre as modelo_nombre,
             l.nombre as logo_nombre,
             CASE 
               WHEN e.cliente_id IS NOT NULL AND e.cliente_id != '' AND e.cliente_id != '0' THEN 'Asignado'
               ELSE 'Disponible'
             END as estado_asignacion,
             c.nombre as cliente_nombre
      FROM equipos e
      LEFT JOIN marcas m ON e.marca_id = m.id
      LEFT JOIN modelos mo ON e.modelo_id = mo.id
      LEFT JOIN logo l ON e.logo_id = l.id
      LEFT JOIN clientes c ON e.cliente_id = c.id
      $whereClause
      ORDER BY e.fecha_creacion DESC
    ''';

    return await dbHelper.consultarPersonalizada(sql);
  }

  // ================================
  // MÉTODOS DE ESTADÍSTICAS ACTUALIZADOS
  // ================================

  /// Obtener estadísticas de asignaciones
  Future<Map<String, dynamic>> obtenerEstadisticas() async {
    try {
      final sql = '''
        SELECT 
          COUNT(*) as total_equipos,
          COUNT(CASE WHEN e.activo = 1 THEN 1 END) as equipos_activos,
          COUNT(CASE WHEN e.cliente_id IS NOT NULL AND e.cliente_id != '' AND e.cliente_id != '0' THEN 1 END) as equipos_asignados,
          COUNT(CASE WHEN e.cliente_id IS NULL OR e.cliente_id = '' OR e.cliente_id = '0' THEN 1 END) as equipos_disponibles,
          COUNT(CASE WHEN e.estado_local = 0 AND e.cliente_id IS NOT NULL THEN 1 END) as equipos_pendientes,
          COUNT(CASE WHEN e.sincronizado = 0 THEN 1 END) as pendientes_sincronizacion,
          COUNT(DISTINCT e.cliente_id) as clientes_con_equipos
        FROM equipos e
        WHERE e.activo = 1
      ''';

      final result = await dbHelper.consultarPersonalizada(sql);
      return result.isNotEmpty ? result.first : {};
    } catch (e) {
      _logger.e('Error obteniendo estadísticas: $e');
      return {};
    }
  }

  /// Obtener resumen para dashboard actualizado
  Future<Map<String, dynamic>> obtenerResumenDashboard() async {
    final sql = '''
      SELECT 
        COUNT(*) as total_equipos,
        COUNT(CASE WHEN e.activo = 1 THEN 1 END) as activos,
        COUNT(CASE WHEN e.estado_local = 0 THEN 1 END) as mantenimiento,
        COUNT(CASE WHEN e.cliente_id IS NOT NULL AND e.cliente_id != '' AND e.cliente_id != '0' THEN 1 END) as asignados,
        COUNT(CASE WHEN (e.cliente_id IS NULL OR e.cliente_id = '' OR e.cliente_id = '0') AND e.activo = 1 AND e.estado_local = 1 THEN 1 END) as disponibles,
        COUNT(CASE WHEN e.sincronizado = 0 THEN 1 END) as pendientes_sync
      FROM equipos e
    ''';

    final result = await dbHelper.consultarPersonalizada(sql);
    return result.isNotEmpty ? result.first : {};
  }

  // ================================
  // MÉTODOS EXISTENTES MANTENIDOS
  // ================================

  /// Buscar por código exacto
  Future<List<Map<String, dynamic>>> buscarPorCodigoExacto({
    required String codigoBarras,
    bool soloActivos = true,
  }) async {
    final condiciones = ['UPPER(e.cod_barras) = ?'];
    final argumentos = [codigoBarras.toUpperCase()];

    if (soloActivos) {
      condiciones.add('e.activo = 1');
    }

    final sql = '''
    SELECT e.*, 
           m.nombre as marca_nombre,
           mo.nombre as modelo_nombre,
           l.nombre as logo_nombre,
           c.nombre as cliente_nombre
    FROM equipos e
    LEFT JOIN marcas m ON e.marca_id = m.id
    LEFT JOIN modelos mo ON e.modelo_id = mo.id
    LEFT JOIN logo l ON e.logo_id = l.id
    LEFT JOIN clientes c ON e.cliente_id = c.id
    WHERE ${condiciones.join(' AND ')}
    ORDER BY e.fecha_creacion DESC
    LIMIT 1
    ''';

    return await dbHelper.consultarPersonalizada(sql, argumentos);
  }

  /// Buscar por código de barras
  Future<Equipo?> buscarPorCodigoBarras(String codBarras) async {
    final maps = await dbHelper.consultar(
      tableName,
      where: 'cod_barras = ? AND activo = ?',
      whereArgs: [codBarras, 1],
      limit: 1,
    );

    return maps.isNotEmpty ? fromMap(maps.first) : null;
  }

  /// Verificar si existe un código de barras
  Future<bool> existeCodigoBarras(String codBarras, {int? excludeId}) async {
    var whereClause = 'cod_barras = ? AND activo = ?';
    var whereArgs = [codBarras, 1];

    if (excludeId != null) {
      whereClause += ' AND id != ?';
      whereArgs.add(excludeId);
    }

    final maps = await dbHelper.consultar(
      tableName,
      where: whereClause,
      whereArgs: whereArgs,
      limit: 1,
    );

    return maps.isNotEmpty;
  }

  /// Crear equipo con validaciones
  Future<int> crearEquipo({
    String? codBarras,
    required int marcaId,
    required int modeloId,
    required int logoId,
    String? numeroSerie,
    int? clienteId,
    String estado = 'disponible',
    int estadoLocal = 1,
  }) async {
    // Validaciones
    if (codBarras != null && codBarras.isNotEmpty && await existeCodigoBarras(codBarras)) {
      throw Exception('Ya existe un equipo con el código de barras: $codBarras');
    }

    final now = DateTime.now().toIso8601String();
    final equipoData = {
      'cod_barras': codBarras ?? '',
      'marca_id': marcaId,
      'modelo_id': modeloId,
      'logo_id': logoId,
      'numero_serie': numeroSerie,
      'cliente_id': clienteId,
      'estado': estado,
      'estado_local': estadoLocal,
      'activo': 1,
      'sincronizado': 0,
      'fecha_creacion': now,
      'fecha_actualizacion': now,
      if (clienteId != null && clienteId > 0) 'fecha_asignacion': now,
    };

    return await dbHelper.insertar(tableName, equipoData);
  }

  /// Obtener marcas activas
  Future<List<Map<String, dynamic>>> obtenerMarcas() async {
    return await dbHelper.consultar(
      'marcas',
      where: 'activo = ?',
      whereArgs: [1],
      orderBy: 'nombre ASC',
    );
  }

  /// Obtener modelos
  Future<List<Map<String, dynamic>>> obtenerModelos() async {
    return await dbHelper.consultar(
      'modelos',
      orderBy: 'nombre ASC',
    );
  }

  /// Obtener logos activos
  Future<List<Map<String, dynamic>>> obtenerLogos() async {
    return await dbHelper.consultar(
      'logo',
      where: 'activo = ?',
      whereArgs: [1],
      orderBy: 'nombre ASC',
    );
  }
}