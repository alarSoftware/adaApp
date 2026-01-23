import 'package:sqflite/sqflite.dart';
import 'package:ada_app/models/equipos.dart';
import 'package:ada_app/services/error_log/error_log_service.dart';
import '../repositories/base_repository.dart';

class EquipoRepository extends BaseRepository<Equipo> {
  @override
  String get tableName => 'equipos';

  @override
  Equipo fromMap(Map<String, dynamic> map) => Equipo.fromMap(map);

  @override
  Map<String, dynamic> toMap(Equipo equipo) => equipo.toMap();

  @override
  String getDefaultOrderBy() => 'id DESC';

  @override
  String getBuscarWhere() =>
      'LOWER(cod_barras) LIKE ? OR LOWER(numero_serie) LIKE ?';

  @override
  List<dynamic> getBuscarArgs(String query) {
    final searchTerm = '%${query.toLowerCase()}%';
    return [searchTerm, searchTerm];
  }

  @override
  String getEntityName() => 'Equipo';

  @override
  Future<void> limpiarYSincronizar(List<dynamic> itemsAPI) async {
    try {
      final List<Map<String, dynamic>> equipos = itemsAPI
          .cast<Map<String, dynamic>>();

      final db = await dbHelper.database;

      await db.transaction((txn) async {
        await txn.delete(tableName);

        final batch = txn.batch();

        for (final equipo in equipos) {
          batch.insert(
            tableName,
            equipo,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        await batch.commit(noResult: true);
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> limpiarYSincronizarEnChunks(
    List<Map<String, dynamic>> equipos, {
    int chunkSize = 500,
  }) async {
    try {
      final db = await dbHelper.database;

      await db.transaction((txn) async {
        await txn.delete(tableName);

        for (var i = 0; i < equipos.length; i += chunkSize) {
          final end = (i + chunkSize < equipos.length)
              ? i + chunkSize
              : equipos.length;
          final chunk = equipos.sublist(i, end);

          final batch = txn.batch();
          for (var equipo in chunk) {
            batch.insert(
              tableName,
              equipo,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          await batch.commit(noResult: true);
        }
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> obtenerEquiposAsignados(
    int clienteId,
  ) async {
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
       LIMIT 1) as estado_censo
    FROM equipos e
    INNER JOIN marcas m ON e.marca_id = m.id
    INNER JOIN modelos mo ON e.modelo_id = mo.id
    INNER JOIN logo l ON e.logo_id = l.id
    INNER JOIN clientes c ON e.cliente_id = c.id
    LEFT JOIN equipos_pendientes ep 
      ON CAST(e.id AS TEXT) = CAST(ep.equipo_id AS TEXT) 
      AND CAST(e.cliente_id AS TEXT) = CAST(ep.cliente_id AS TEXT)
    WHERE e.cliente_id = ?
      AND ep.id IS NULL
    ORDER BY e.id DESC
  ''';

      final result = await dbHelper.consultarPersonalizada(sql, [
        clienteId,
        clienteId,
        clienteId,
        clienteId,
        clienteId,
      ]);

      return result;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> obtenerPorClienteCompleto(
    int clienteId,
  ) async {
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

      return result;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> verificarAsignacionEquipoCliente(
    String equipoId,
    int clienteId,
  ) async {
    try {
      final resultPendientes = await dbHelper.consultar(
        'equipos_pendientes',
        where: 'equipo_id = ? AND cliente_id = ? AND sincronizado = 0',
        whereArgs: [equipoId, clienteId.toString()],
        limit: 1,
      );

      if (resultPendientes.isNotEmpty) {
        return false;
      }

      final resultEquipos = await dbHelper.consultar(
        'equipos',
        where: 'id = ? AND cliente_id = ?',
        whereArgs: [equipoId, clienteId.toString()],
        limit: 1,
      );

      if (resultEquipos.isNotEmpty) {
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Verifica si un equipo está asignado usando la misma lógica estricta que obtenerEquiposAsignados
  /// Es decir: Está en 'equipos' Y NO está en 'equipos_pendientes'
  Future<bool> verificarAsignacionEstricta(
    String equipoId,
    int clienteId,
  ) async {
    try {
      final query = '''
        SELECT e.id 
        FROM equipos e
        LEFT JOIN equipos_pendientes ep 
          ON CAST(e.id AS TEXT) = CAST(ep.equipo_id AS TEXT) 
          AND CAST(e.cliente_id AS TEXT) = CAST(ep.cliente_id AS TEXT)
        WHERE e.id = ? 
          AND e.cliente_id = ?
          AND ep.id IS NULL
        LIMIT 1
      ''';

      final db = await dbHelper.database;
      final result = await db.rawQuery(query, [equipoId, clienteId]);

      return result.isNotEmpty;
    } catch (e) {
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
      rethrow;
    }
  }

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
           c.nombre as cliente_nombre,
           (SELECT MAX(ca.fecha_creacion) 
            FROM censo_activo ca 
            WHERE ca.equipo_id = e.id) as ultima_fecha_censo
    FROM equipos e
    LEFT JOIN marcas m ON e.marca_id = m.id
    LEFT JOIN modelos mo ON e.modelo_id = mo.id
    LEFT JOIN logo l ON e.logo_id = l.id
    LEFT JOIN clientes c ON CAST(e.cliente_id AS INTEGER) = c.id
    WHERE LOWER(TRIM(e.cod_barras)) LIKE ? OR
          LOWER(TRIM(m.nombre)) LIKE ? OR
          LOWER(TRIM(mo.nombre)) LIKE ? OR
          LOWER(TRIM(l.nombre)) LIKE ? OR
          LOWER(TRIM(e.numero_serie)) LIKE ? OR
          LOWER(TRIM(c.nombre)) LIKE ?
    ORDER BY CASE WHEN c.nombre IS NOT NULL AND c.nombre != '' THEN 0 ELSE 1 END, e.id DESC
    ''';

    return await dbHelper.consultarPersonalizada(sql, [
      '%$searchTerm%',
      '%$searchTerm%',
      '%$searchTerm%',
      '%$searchTerm%',
      '%$searchTerm%',
      '%$searchTerm%',
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
             c.nombre as cliente_nombre,
             (SELECT MAX(ca.fecha_creacion) 
              FROM censo_activo ca 
              WHERE ca.equipo_id = e.id) as ultima_fecha_censo
      FROM equipos e
      LEFT JOIN marcas m ON e.marca_id = m.id
      LEFT JOIN modelos mo ON e.modelo_id = mo.id
      LEFT JOIN logo l ON e.logo_id = l.id
      LEFT JOIN clientes c ON CAST(e.cliente_id AS INTEGER) = c.id
      ORDER BY CASE WHEN c.nombre IS NOT NULL AND c.nombre != '' THEN 0 ELSE 1 END, e.id DESC
    ''';

    return await dbHelper.consultarPersonalizada(sql);
  }

  Future<String> crearEquipoNuevo({
    required String codigoBarras,
    required int marcaId,
    required int modeloId,
    required String? numeroSerie,
    required int logoId,
    int? clienteId,
  }) async {
    try {
      if (codigoBarras.isNotEmpty) {
        final existe = await existeCodigoBarras(codigoBarras);
        if (existe) {
          throw Exception('Ya existe un equipo con el código: $codigoBarras');
        }
      }

      final now = DateTime.now();
      final equipoId = codigoBarras.isEmpty
          ? 'NUEVO_${now.millisecondsSinceEpoch}'
          : codigoBarras;

      final equipoMap = {
        'id': equipoId,
        'cliente_id': clienteId,
        'cod_barras': codigoBarras,
        'marca_id': marcaId,
        'modelo_id': modeloId,
        'numero_serie': numeroSerie,
        'logo_id': logoId,
        'app_insert': 1,
        'sincronizado': 0,
        'fecha_creacion': now.toIso8601String(),
        'fecha_actualizacion': now.toIso8601String(),
      };

      await dbHelper.insertar(
        tableName,
        equipoMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      return equipoId;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> crearEquipoSimple({
    required String codigoBarras,
    required int marcaId,
    required int modeloId,
    required String? numeroSerie,
    required int logoId,
    int? clienteId,
  }) async {
    try {
      final equipoId = await crearEquipoNuevo(
        codigoBarras: codigoBarras,
        marcaId: marcaId,
        modeloId: modeloId,
        numeroSerie: numeroSerie,
        logoId: logoId,
        clienteId: clienteId,
      );

      return {
        'success': true,
        'equipo_id': equipoId,
        'message': 'Equipo creado exitosamente.',
      };
    } catch (e) {
      await ErrorLogService.logError(
        tableName: 'equipos',
        operation: 'crear_equipo_simple',
        errorMessage: 'Error: $e',
        errorType: 'general',
      );
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<void> marcarEquipoComoSincronizado(String equipoId) async {
    await dbHelper.actualizar(
      tableName,
      {'sincronizado': 1},
      where: 'id = ?',
      whereArgs: [equipoId],
    );
  }

  Future<List<Map<String, dynamic>>> obtenerEquiposNoSincronizados() async {
    return await dbHelper.consultar(
      tableName,
      where: 'app_insert = 1 AND (sincronizado IS NULL OR sincronizado = 0)',
    );
  }

  Future<List<Map<String, dynamic>>> obtenerEquiposNuevos() async {
    return obtenerEquiposNoSincronizados();
  }

  Future<List<Map<String, dynamic>>> buscarPorCodigoExacto({
    required String codigoBarras,
  }) async {
    final sql = '''
      SELECT e.*, m.nombre as marca_nombre, mo.nombre as modelo_nombre, l.nombre as logo_nombre, c.nombre as cliente_nombre
      FROM equipos e
      LEFT JOIN marcas m ON e.marca_id = m.id
      LEFT JOIN modelos mo ON e.modelo_id = mo.id
      LEFT JOIN logo l ON e.logo_id = l.id
      LEFT JOIN clientes c ON CAST(e.cliente_id AS INTEGER) = c.id
      WHERE UPPER(e.cod_barras) = ?
      LIMIT 1
    ''';
    return await dbHelper.consultarPersonalizada(sql, [
      codigoBarras.toUpperCase(),
    ]);
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
      whereArgs.add(excludeId.toString());
    }
    final count = await dbHelper.contarRegistros(
      tableName,
      where: whereClause,
      whereArgs: whereArgs,
    );
    return count > 0;
  }

  Future<Map<String, dynamic>?> obtenerEquipoClientePorId(
    dynamic equipoId,
  ) async {
    final result = await dbHelper.consultarPorId(
      tableName,
      int.tryParse(equipoId.toString()) ?? 0,
    );
    if (result == null && equipoId is String) {
      final list = await dbHelper.consultar(
        tableName,
        where: 'id = ?',
        whereArgs: [equipoId],
      );
      return list.isNotEmpty ? list.first : null;
    }
    return result;
  }

  /// Recuperar equipo con nombres de marcas/modelos
  Future<Map<String, dynamic>?> obtenerEquipoCompletoPorId(
    String equipoId,
  ) async {
    try {
      final sql = '''
        SELECT e.*, 
               m.nombre as marca_nombre, 
               mo.nombre as modelo_nombre, 
               l.nombre as logo_nombre
        FROM equipos e
        LEFT JOIN marcas m ON e.marca_id = m.id
        LEFT JOIN modelos mo ON e.modelo_id = mo.id
        LEFT JOIN logo l ON e.logo_id = l.id
        WHERE e.id = ?
        LIMIT 1
      ''';

      final results = await dbHelper.consultarPersonalizada(sql, [equipoId]);
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> obtenerMarcas() async =>
      dbHelper.consultar('marcas', orderBy: 'nombre ASC');
  Future<List<Map<String, dynamic>>> obtenerModelos() async =>
      dbHelper.consultar('modelos', orderBy: 'nombre ASC');
  Future<List<Map<String, dynamic>>> obtenerLogos() async =>
      dbHelper.consultar('logo', orderBy: 'nombre ASC');

  Future<Map<String, dynamic>> obtenerEstadisticas() async {
    final sql = '''
      SELECT 
        COUNT(*) as total_equipos,
        COUNT(CASE WHEN cliente_id IS NOT NULL AND cliente_id != '' AND cliente_id != '0' THEN 1 END) as equipos_asignados,
        COUNT(CASE WHEN cliente_id IS NULL OR cliente_id = '' OR cliente_id = '0' THEN 1 END) as equipos_disponibles,
        COUNT(CASE WHEN sincronizado = 0 THEN 1 END) as pendientes_sincronizacion
      FROM equipos
    ''';
    final result = await dbHelper.consultarPersonalizada(sql);
    return result.isNotEmpty ? result.first : {};
  }
}
