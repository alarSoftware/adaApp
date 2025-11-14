import 'package:sqflite/sqflite.dart';
import 'package:ada_app/models/equipos.dart';
import 'package:ada_app/services/post/equipo_post_service.dart';
import 'package:ada_app/services/auth_service.dart';
import 'package:ada_app/services/error_log/error_log_service.dart';
import '../repositories/base_repository.dart';
import 'package:logger/logger.dart';

class EquipoRepository extends BaseRepository<Equipo> {
  final Logger _logger = Logger();
  final AuthService _authService = AuthService();

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
  // MÉTODOS PARA EQUIPOS ASIGNADOS
  // ================================

  Future<List<Map<String, dynamic>>> obtenerEquiposAsignados(int clienteId) async {
    try {
      final sql = '''
      SELECT DISTINCT
        e.id,
        e.cod_barras,
        e.numero_serie,
        e.marca_id,
        e.modelo_id,
        e.logo_id,
        e.cliente_id,
        m.nombre as marca_nombre,
        mo.nombre as modelo_nombre,
        l.nombre as logo_nombre,
        c.nombre as cliente_nombre,
        'asignado' as estado,
        'asignado' as estado_tipo,
        (SELECT ca2.fecha_revision 
         FROM censo_activo ca2 
         WHERE ca2.equipo_id = e.id AND ca2.cliente_id = ?
         ORDER BY ca2.fecha_creacion DESC 
         LIMIT 1) as fecha_revision,
        (SELECT ca2.fecha_creacion 
         FROM censo_activo ca2 
         WHERE ca2.equipo_id = e.id AND ca2.cliente_id = ?
         ORDER BY ca2.fecha_creacion DESC 
         LIMIT 1) as censo_fecha_creacion,
        (SELECT ca2.fecha_actualizacion 
         FROM censo_activo ca2 
         WHERE ca2.equipo_id = e.id AND ca2.cliente_id = ?
         ORDER BY ca2.fecha_creacion DESC 
         LIMIT 1) as censo_fecha_actualizacion,
        (SELECT ca2.estado_censo 
         FROM censo_activo ca2 
         WHERE ca2.equipo_id = e.id AND ca2.cliente_id = ?
         ORDER BY ca2.fecha_creacion DESC 
         LIMIT 1) as estado_censo,
        (SELECT ca2.sincronizado 
         FROM censo_activo ca2 
         WHERE ca2.equipo_id = e.id AND ca2.cliente_id = ?
         ORDER BY ca2.fecha_creacion DESC 
         LIMIT 1) as sincronizado
      FROM equipos e
      INNER JOIN marcas m ON e.marca_id = m.id
      INNER JOIN modelos mo ON e.modelo_id = mo.id
      INNER JOIN logo l ON e.logo_id = l.id
      INNER JOIN clientes c ON e.cliente_id = c.id
      WHERE e.cliente_id = ?
      ORDER BY e.id DESC
    ''';

      final result = await dbHelper.consultarPersonalizada(
          sql,
          [clienteId, clienteId, clienteId, clienteId, clienteId, clienteId]
      );

      _logger.i('Equipos ASIGNADOS para cliente $clienteId: ${result.length}');
      return result;
    } catch (e) {
      _logger.e('Error obteniendo equipos asignados del cliente $clienteId: $e');
      rethrow;
    }
  }

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

  Future<bool> verificarAsignacionEquipoCliente(String equipoId, int clienteId) async {
    try {
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

      final resultPendientes = await dbHelper.consultar(
        'equipos_pendientes',
        where: 'equipo_id = ? AND cliente_id = ?',
        whereArgs: [equipoId, clienteId],
        limit: 1,
      );

      if (resultPendientes.isNotEmpty) {
        _logger.d('Equipo $equipoId está PENDIENTE para el cliente $clienteId');
        return false;
      }

      _logger.d('Equipo $equipoId NO tiene relación con cliente $clienteId');
      return false;

    } catch (e) {
      _logger.e('Error verificando asignación equipo $equipoId - cliente $clienteId: $e');
      return false;
    }
  }

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
  // BÚSQUEDA CON DETALLES
  // ================================

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
  // CREACIÓN Y SINCRONIZACIÓN DE EQUIPOS NUEVOS
  // ================================

  /// Crear equipo nuevo desde la app
  Future<String> crearEquipoNuevo({
    required String codigoBarras,
    required int marcaId,
    required int modeloId,
    required String? numeroSerie,
    required int logoId,
  }) async {
    try {
      _logger.i('=== CREANDO EQUIPO NUEVO ===');
      _logger.i('Código: $codigoBarras');

      if (codigoBarras.isNotEmpty) {
        final existe = await existeCodigoBarras(codigoBarras);
        if (existe) {
          throw Exception('Ya existe un equipo con el código: $codigoBarras');
        }
      }

      final equipoId = codigoBarras.isEmpty
          ? 'NUEVO_${DateTime.now().millisecondsSinceEpoch}'
          : codigoBarras;

      final equipoMap = {
        'id': equipoId,
        'cliente_id': null,
        'cod_barras': codigoBarras,
        'marca_id': marcaId,
        'modelo_id': modeloId,
        'numero_serie': numeroSerie,
        'logo_id': logoId,
        'app_insert': 1,
      };

      _logger.i('Datos a insertar: $equipoMap');

      await dbHelper.database.then((db) async {
        await db.insert(
          tableName,
          equipoMap,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      });

      _logger.i('✅ Equipo nuevo creado como DISPONIBLE con ID: $equipoId');
      return equipoId;

    } catch (e, stackTrace) {
      _logger.e('❌ Error creando equipo nuevo: $e', stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Crear equipo nuevo Y sincronizarlo con el servidor
  Future<Map<String, dynamic>> crearYSincronizarEquipoNuevo({
    required String codigoBarras,
    required int marcaId,
    required int modeloId,
    required String? numeroSerie,
    required int logoId,
    String? clienteId,
    bool sincronizarInmediato = true,
  }) async {
    try {
      _logger.i('=== CREANDO Y SINCRONIZANDO EQUIPO NUEVO ===');

      // 1. Crear equipo localmente
      final equipoId = await crearEquipoNuevo(
        codigoBarras: codigoBarras,
        marcaId: marcaId,
        modeloId: modeloId,
        numeroSerie: numeroSerie,
        logoId: logoId,
      );

      // 2. Sincronizar si se requiere
      if (sincronizarInmediato) {
        try {
          final usuario = await _authService.getCurrentUser();
          final edfVendedorId = usuario?.edfVendedorId ?? '';

          if (edfVendedorId.isEmpty) {
            _logger.w('⚠️ No hay edfVendedorId, sincronización pendiente');
            return {
              'success': true,
              'equipo_id': equipoId,
              'sincronizado': false,
              'message': 'Equipo creado localmente, sincronización pendiente',
            };
          }

          final resultado = await EquipoPostService.enviarEquipoNuevo(
            equipoId: equipoId,
            codigoBarras: codigoBarras,
            marcaId: marcaId,
            modeloId: modeloId,
            logoId: logoId,
            numeroSerie: numeroSerie,
            clienteId: clienteId,
            edfVendedorId: edfVendedorId,
          );

          if (resultado['exito'] == true) {
            await marcarEquipoComoSincronizado(equipoId);

            return {
              'success': true,
              'equipo_id': equipoId,
              'sincronizado': true,
              'message': 'Equipo creado y sincronizado',
            };
          } else {
            return {
              'success': true,
              'equipo_id': equipoId,
              'sincronizado': false,
              'message': 'Equipo creado localmente, sincronización pendiente',
              'error_sync': resultado['mensaje'],
            };
          }
        } catch (e) {
          _logger.e('⚠️ Error en sincronización: $e');
          return {
            'success': true,
            'equipo_id': equipoId,
            'sincronizado': false,
            'message': 'Equipo creado localmente, sincronización pendiente',
            'error_sync': e.toString(),
          };
        }
      }

      return {
        'success': true,
        'equipo_id': equipoId,
        'sincronizado': false,
        'message': 'Equipo creado localmente',
      };

    } catch (e, stackTrace) {
      _logger.e('❌ Error creando equipo: $e', stackTrace: stackTrace);

      await ErrorLogService.logError(
        tableName: 'equipos',
        operation: 'crear_y_sincronizar_equipo',
        errorMessage: 'Error: $e',
        errorType: 'general',
      );

      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Sincronizar equipos pendientes en background
  Future<void> sincronizarEquiposPendientes() async {
    try {
      _logger.i('🔄 Sincronizando equipos pendientes...');

      final usuario = await _authService.getCurrentUser();
      final edfVendedorId = usuario?.edfVendedorId ?? '';

      if (edfVendedorId.isEmpty) {
        _logger.w('⚠️ No hay edfVendedorId, no se puede sincronizar');
        return;
      }

      final equiposPendientes = await obtenerEquiposNoSincronizados();

      _logger.i('📊 Equipos pendientes: ${equiposPendientes.length}');

      for (final equipo in equiposPendientes) {
        try {
          final resultado = await EquipoPostService.enviarEquipoNuevo(
            equipoId: equipo['id'],
            codigoBarras: equipo['cod_barras'] ?? '',
            marcaId: equipo['marca_id'],
            modeloId: equipo['modelo_id'],
            logoId: equipo['logo_id'],
            numeroSerie: equipo['numero_serie'],
            clienteId: equipo['cliente_id'],
            edfVendedorId: edfVendedorId,
          );

          if (resultado['exito'] == true) {
            await marcarEquipoComoSincronizado(equipo['id']);
            _logger.i('✅ Equipo sincronizado: ${equipo['id']}');
          } else {
            _logger.w('⚠️ Fallo sincronizando equipo: ${equipo['id']}');
          }

          await Future.delayed(const Duration(milliseconds: 500));

        } catch (e) {
          _logger.e('❌ Error sincronizando equipo ${equipo['id']}: $e');
        }
      }

      _logger.i('✅ Sincronización de equipos completada');

    } catch (e) {
      _logger.e('❌ Error en sincronización de equipos: $e');
    }
  }

  Future<List<Map<String, dynamic>>> obtenerEquiposNoSincronizados() async {
    try {
      final sql = '''
        SELECT e.*
        FROM equipos e
        WHERE e.app_insert = 1 
          AND (e.sincronizado IS NULL OR e.sincronizado = 0)
        ORDER BY e.id DESC
      ''';

      return await dbHelper.consultarPersonalizada(sql);
    } catch (e) {
      _logger.e('Error obteniendo equipos no sincronizados: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> obtenerEquiposNuevos() async {
    try {
      final sql = '''
      SELECT 
        e.*,
        m.nombre as marca_nombre,
        mo.nombre as modelo_nombre,
        l.nombre as logo_nombre,
        c.nombre as cliente_nombre
      FROM equipos e
      LEFT JOIN marcas m ON e.marca_id = m.id
      LEFT JOIN modelos mo ON e.modelo_id = mo.id
      LEFT JOIN logo l ON e.logo_id = l.id
      LEFT JOIN clientes c ON e.cliente_id = c.id
      WHERE e.app_insert = 1
      ORDER BY e.id DESC
    ''';

      final result = await dbHelper.consultarPersonalizada(sql);
      _logger.i('Equipos nuevos encontrados: ${result.length}');
      return result;
    } catch (e) {
      _logger.e('Error obteniendo equipos nuevos: $e');
      rethrow;
    }
  }

  Future<void> marcarEquipoComoSincronizado(String equipoId) async {
    try {
      await dbHelper.actualizar(
        tableName,
        {'sincronizado': 1},
        where: 'id = ?',
        whereArgs: [equipoId],
      );
      _logger.i('Equipo $equipoId marcado como sincronizado');
    } catch (e) {
      _logger.e('Error marcando equipo como sincronizado: $e');
      rethrow;
    }
  }

  // ================================
  // MÉTODOS DE BÚSQUEDA ESPECÍFICA
  // ================================

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

  Future<Equipo?> buscarPorCodigoBarras(String codBarras) async {
    final maps = await dbHelper.consultar(
      tableName,
      where: 'cod_barras = ?',
      whereArgs: [codBarras],
      limit: 1,
    );

    return maps.isNotEmpty ? fromMap(maps.first) : null;
  }

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

  Future<Map<String, dynamic>?> obtenerEquipoClientePorId(dynamic equipoId) async {
    try {
      final sql = '''
      SELECT 
        e.id,
        e.cod_barras,
        e.numero_serie,
        e.marca_id,
        e.modelo_id,
        e.logo_id,
        e.cliente_id,
        m.nombre as marca_nombre,
        mo.nombre as modelo_nombre,
        l.nombre as logo_nombre,
        c.nombre as cliente_nombre,
        c.telefono as cliente_telefono,
        c.direccion as cliente_direccion,
        'asignado' as tipo_estado
      FROM equipos e
      LEFT JOIN marcas m ON e.marca_id = m.id
      LEFT JOIN modelos mo ON e.modelo_id = mo.id
      LEFT JOIN logo l ON e.logo_id = l.id
      LEFT JOIN clientes c ON e.cliente_id = c.id
      WHERE e.id = ?
      LIMIT 1
    ''';

      final result = await dbHelper.consultarPersonalizada(sql, [equipoId.toString()]);

      if (result.isEmpty) {
        _logger.w('No se encontró equipo con ID: $equipoId');
        return null;
      }

      _logger.i('Equipo encontrado: ${result.first['cod_barras']}');
      return result.first;
    } catch (e, stackTrace) {
      _logger.e('Error obteniendo equipo por ID $equipoId: $e', stackTrace: stackTrace);
      return null;
    }
  }

  // ================================
  // MÉTODOS AUXILIARES
  // ================================

  Future<List<Map<String, dynamic>>> obtenerMarcas() async {
    return await dbHelper.consultar(
      'marcas',
      orderBy: 'nombre ASC',
    );
  }

  Future<List<Map<String, dynamic>>> obtenerModelos() async {
    return await dbHelper.consultar(
      'modelos',
      orderBy: 'nombre ASC',
    );
  }

  Future<List<Map<String, dynamic>>> obtenerLogos() async {
    return await dbHelper.consultar(
      'logo',
      orderBy: 'nombre ASC',
    );
  }

  // ================================
  // MÉTODOS DE ESTADÍSTICAS
  // ================================

  @override
  Future<Map<String, dynamic>> obtenerEstadisticas() async {
    try {
      final sql = '''
      SELECT 
        COUNT(*) as total_equipos,
        COUNT(CASE WHEN e.cliente_id IS NOT NULL AND e.cliente_id != '' AND e.cliente_id != '0' THEN 1 END) as equipos_asignados,
        COUNT(CASE WHEN e.cliente_id IS NULL OR e.cliente_id = '' OR e.cliente_id = '0' THEN 1 END) as equipos_disponibles,
        COUNT(CASE WHEN e.sincronizado = 0 THEN 1 END) as pendientes_sincronizacion,
        COUNT(CASE WHEN e.app_insert = 1 THEN 1 END) as equipos_nuevos,
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

  Future<Map<String, dynamic>> obtenerResumenDashboard() async {
    final sql = '''
    SELECT 
      COUNT(*) as total_equipos,
      COUNT(CASE WHEN e.cliente_id IS NOT NULL AND e.cliente_id != '' AND e.cliente_id != '0' THEN 1 END) as asignados,
      COUNT(CASE WHEN (e.cliente_id IS NULL OR e.cliente_id = '' OR e.cliente_id = '0') THEN 1 END) as disponibles,
      COUNT(CASE WHEN e.sincronizado = 0 THEN 1 END) as pendientes_sync,
      COUNT(CASE WHEN e.app_insert = 1 THEN 1 END) as equipos_nuevos
    FROM equipos e
  ''';

    final result = await dbHelper.consultarPersonalizada(sql);
    return result.isNotEmpty ? result.first : {};
  }
}