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
  String getDefaultOrderBy() => 'id DESC';

  @override
  String getBuscarWhere() => 'LOWER(cod_barras) LIKE ? OR LOWER(numero_serie) LIKE ?';

  @override
  List<dynamic> getBuscarArgs(String query) {
    final searchTerm = '%${query.toLowerCase()}%';
    return [searchTerm, searchTerm];
  }

  @override
  String getEntityName() => 'Equipo';

  // ================================
  // MÉTODOS CORREGIDOS PARA EQUIPOS ASIGNADOS
  // ================================

  /// Obtener equipos ASIGNADOS de un cliente (solo tabla equipos)
  Future<List<Map<String, dynamic>>> obtenerEquiposAsignados(int clienteId) async {
    try {
      final sql = '''
      SELECT 
        e.*,
        m.nombre as marca_nombre,
        mo.nombre as modelo_nombre,
        l.nombre as logo_nombre,
        c.nombre as cliente_nombre,
        'asignado' as estado,
        'asignado' as estado_tipo
      FROM equipos e
      INNER JOIN marcas m ON e.marca_id = m.id
      INNER JOIN modelos mo ON e.modelo_id = mo.id
      INNER JOIN logo l ON e.logo_id = l.id
      INNER JOIN clientes c ON e.cliente_id = c.id
      WHERE e.cliente_id = ?
      ORDER BY e.id DESC
    ''';

      final result = await dbHelper.consultarPersonalizada(sql, [clienteId]);
      _logger.i('Equipos ASIGNADOS del cliente $clienteId: ${result.length}');
      return result;
    } catch (e) {
      _logger.e('Error obteniendo equipos asignados del cliente $clienteId: $e');
      rethrow;
    }
  }

  /// Obtener equipos completos de un cliente con información detallada
  Future<List<Map<String, dynamic>>> obtenerPorClienteCompleto(int clienteId) async {
    try {
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
        c.direccion as cliente_direccion,
        'asignado' as estado
      FROM equipos e
      INNER JOIN marcas m ON e.marca_id = m.id
      INNER JOIN modelos mo ON e.modelo_id = mo.id
      INNER JOIN logo l ON e.logo_id = l.id
      INNER JOIN clientes c ON e.cliente_id = c.id
      WHERE e.cliente_id = ?
      ORDER BY e.id DESC
    ''';

      final result = await dbHelper.consultarPersonalizada(sql, [clienteId]);
      _logger.i('Equipos encontrados para cliente $clienteId: ${result.length}');
      return result;
    } catch (e, stackTrace) {
      _logger.e('Error obteniendo equipos del cliente $clienteId: $e', stackTrace: stackTrace);
      rethrow;
    }
  }

  // ================================
  // MÉTODOS DE VERIFICACIÓN
  // ================================

  /// Verificar si un equipo está asignado a un cliente específico
  Future<bool> verificarAsignacionEquipoCliente(String equipoId, int clienteId) async {
    try {
      // Verificar si el equipo está ASIGNADO en la tabla equipos
      final resultEquipos = await dbHelper.consultar(
        'equipos',
        where: 'id = ? AND cliente_id = ?',
        whereArgs: [equipoId, clienteId.toString()],
        limit: 1,
      );

      if (resultEquipos.isNotEmpty) {
        _logger.d('Equipo $equipoId YA está asignado al cliente $clienteId en tabla equipos');
        return true;
      }

      // Si no está en equipos, verificar si está PENDIENTE
      final resultPendientes = await dbHelper.consultar(
        'equipos_pendientes',
        where: 'equipo_id = ? AND cliente_id = ?',
        whereArgs: [equipoId, clienteId],
        limit: 1,
      );

      if (resultPendientes.isNotEmpty) {
        _logger.d('Equipo $equipoId está PENDIENTE para el cliente $clienteId');
        return false; // Está pendiente, NO asignado definitivamente
      }

      _logger.d('Equipo $equipoId NO tiene relación con cliente $clienteId');
      return false;

    } catch (e) {
      _logger.e('Error verificando asignación equipo $equipoId - cliente $clienteId: $e');
      return false;
    }
  }
  /// Verificar si existe relación equipo-cliente
  Future<bool> existeRelacionEquipoCliente(int equipoId, int clienteId) async {
    try {
      final result = await dbHelper.consultar(
        tableName,
        where: 'id = ? AND cliente_id = ?',
        whereArgs: [equipoId, clienteId],
        limit: 1,
      );

      final existe = result.isNotEmpty;
      _logger.d('Relación equipo $equipoId - cliente $clienteId: ${existe ? "SÍ EXISTE" : "NO existe"}');
      return existe;
    } catch (e) {
      _logger.e('Error verificando relación equipo $equipoId - cliente $clienteId: $e');
      return false;
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
      WHERE e.cliente_id IS NULL OR e.cliente_id = '' OR e.cliente_id = '0'
      ORDER BY m.nombre, mo.nombre
    ''';

      return await dbHelper.consultarPersonalizada(sql);
    } catch (e) {
      _logger.e('Error obteniendo equipos disponibles: $e');
      rethrow;
    }
  }

  // ================================
  // MÉTODOS DE ASIGNACIÓN
  // ================================

  /// Crear nueva asignación (asignar equipo a cliente)
  Future<int> crearAsignacion({
    required int equipoId,
    required int clienteId,
  }) async {
    try {
      final equipo = await obtenerPorId(equipoId);
      if (equipo == null) {
        throw Exception('El equipo no existe');
      }

      if (equipo.clienteId != null && equipo.clienteId!.isNotEmpty) {
        throw Exception('El equipo ya está asignado al cliente ${equipo.clienteId}');
      }

      // ✅ Solo actualizar campos que SÍ existen en la tabla equipos
      final count = await dbHelper.actualizar(
        tableName,
        {
          'cliente_id': clienteId.toString(),
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

  /// MÉTODO PARA EL FLUJO DE CENSO: Procesar escaneo de equipo
  Future<Equipo?> procesarEscaneoCenso({
    required int equipoId,
    required int clienteId,
  }) async {
    try {
      final equipo = await obtenerPorId(equipoId);
      if (equipo == null) {
        throw Exception('Equipo no encontrado');
      }

      if (equipo.clienteId == clienteId.toString()) {
        // ✅ Solo actualizar campos que existen (si hay alguno que actualizar)
        // Por ahora, no hay nada que actualizar ya que no hay campos de auditoría
        _logger.i('Equipo $equipoId ya asignado al cliente $clienteId');
        return equipo;
      } else {
        // ✅ Solo actualizar cliente_id
        await dbHelper.actualizar(
          tableName,
          {
            'cliente_id': clienteId.toString(),
          },
          where: 'id = ?',
          whereArgs: [equipoId],
        );

        _logger.i('Asignación actualizada: Equipo $equipoId → Cliente $clienteId');
        return await obtenerPorId(equipoId);
      }
    } catch (e) {
      _logger.e('Error procesando escaneo de censo: $e');
      rethrow;
    }
  }

  // ================================
  // BÚSQUEDA CON DETALLES
  // ================================

  /// Búsqueda con detalles completos incluyendo asignación
  Future<List<Map<String, dynamic>>> buscarConDetalles(String query) async {
    if (query.trim().isEmpty) {
      return await obtenerCompletos();
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
    WHERE LOWER(TRIM(e.cod_barras)) LIKE ? OR
          LOWER(TRIM(m.nombre)) LIKE ? OR
          LOWER(TRIM(mo.nombre)) LIKE ? OR
          LOWER(TRIM(l.nombre)) LIKE ? OR
          LOWER(TRIM(e.numero_serie)) LIKE ? OR
          LOWER(TRIM(c.nombre)) LIKE ?
    ORDER BY e.id DESC
    ''';

    return await dbHelper.consultarPersonalizada(sql, [
      '%$searchTerm%', '%$searchTerm%', '%$searchTerm%',
      '%$searchTerm%', '%$searchTerm%', '%$searchTerm%'
    ]);
  }

  /// Obtener equipos con datos completos
  Future<List<Map<String, dynamic>>> obtenerCompletos() async {
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
      ORDER BY e.id DESC
    ''';

    return await dbHelper.consultarPersonalizada(sql);
  }

  // ================================
  // MÉTODOS DE ESTADÍSTICAS
  // ================================

  /// Obtener estadísticas de asignaciones
  Future<Map<String, dynamic>> obtenerEstadisticas() async {
    try {
      final sql = '''
        SELECT 
          COUNT(*) as total_equipos,
          COUNT(CASE WHEN e.cliente_id IS NOT NULL AND e.cliente_id != '' AND e.cliente_id != '0' THEN 1 END) as equipos_asignados,
          COUNT(CASE WHEN e.cliente_id IS NULL OR e.cliente_id = '' OR e.cliente_id = '0' THEN 1 END) as equipos_disponibles,
          COUNT(CASE WHEN e.sincronizado = 0 THEN 1 END) as pendientes_sincronizacion,
          COUNT(DISTINCT e.cliente_id) as clientes_con_equipos
        FROM equipos e
      ''';

      final result = await dbHelper.consultarPersonalizada(sql);
      return result.isNotEmpty ? result.first : {};
    } catch (e) {
      _logger.e('Error obteniendo estadísticas: $e');
      return {};
    }
  }

  /// Obtener resumen para dashboard
  Future<Map<String, dynamic>> obtenerResumenDashboard() async {
    final sql = '''
      SELECT 
        COUNT(*) as total_equipos,
        COUNT(CASE WHEN e.cliente_id IS NOT NULL AND e.cliente_id != '' AND e.cliente_id != '0' THEN 1 END) as asignados,
        COUNT(CASE WHEN (e.cliente_id IS NULL OR e.cliente_id = '' OR e.cliente_id = '0') THEN 1 END) as disponibles,
        COUNT(CASE WHEN e.sincronizado = 0 THEN 1 END) as pendientes_sync
      FROM equipos e
    ''';

    final result = await dbHelper.consultarPersonalizada(sql);
    return result.isNotEmpty ? result.first : {};
  }

  // ================================
  // MÉTODOS DE BÚSQUEDA ESPECÍFICA
  // ================================

  /// Buscar por código exacto
  Future<List<Map<String, dynamic>>> buscarPorCodigoExacto({
    required String codigoBarras,
  }) async {
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
  WHERE UPPER(e.cod_barras) = ?
  ORDER BY e.id DESC
  LIMIT 1
  ''';

    return await dbHelper.consultarPersonalizada(sql, [codigoBarras.toUpperCase()]);
  }

  /// Buscar por código de barras
  Future<Equipo?> buscarPorCodigoBarras(String codBarras) async {
    final maps = await dbHelper.consultar(
      tableName,
      where: 'cod_barras = ?',
      whereArgs: [codBarras],
      limit: 1,
    );

    return maps.isNotEmpty ? fromMap(maps.first) : null;
  }

  /// Verificar si existe un código de barras
  Future<bool> existeCodigoBarras(String codBarras, {int? excludeId}) async {
    var whereClause = 'cod_barras = ?';
    var whereArgs = [codBarras];

    if (excludeId != null) {
      whereClause += ' AND id != ?';
      whereArgs.add(excludeId as String);
    }

    final maps = await dbHelper.consultar(
      tableName,
      where: whereClause,
      whereArgs: whereArgs,
      limit: 1,
    );

    return maps.isNotEmpty;
  }

  // ================================
  // MÉTODOS DE CREACIÓN DE EQUIPOS
  // ================================

  /// Crear equipo con validaciones
  Future<int> crearEquipo({
    String? codBarras,
    required int marcaId,
    required int modeloId,
    required int logoId,
    String? numeroSerie,
    int? clienteId,
  }) async {
    if (codBarras != null && codBarras.isNotEmpty && await existeCodigoBarras(codBarras)) {
      throw Exception('Ya existe un equipo con el código de barras: $codBarras');
    }

    // ✅ Solo incluir campos que SÍ existen en la tabla equipos
    final equipoData = {
      'cod_barras': codBarras ?? '',
      'marca_id': marcaId,
      'modelo_id': modeloId,
      'logo_id': logoId,
      'numero_serie': numeroSerie,
      'cliente_id': clienteId,
    };

    return await dbHelper.insertar(tableName, equipoData);
  }

  // ================================
  // MÉTODOS AUXILIARES
  // ================================

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