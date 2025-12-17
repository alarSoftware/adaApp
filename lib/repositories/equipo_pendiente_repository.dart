import 'package:ada_app/models/equipos_pendientes.dart';
import 'base_repository.dart';
import 'package:uuid/uuid.dart';

import 'package:ada_app/services/api/auth_service.dart';
import 'package:sqflite/sqflite.dart';

class EquipoPendienteRepository extends BaseRepository<EquiposPendientes> {
  @override
  String get tableName => 'equipos_pendientes';

  @override
  EquiposPendientes fromMap(Map<String, dynamic> map) =>
      EquiposPendientes.fromMap(map);

  @override
  Map<String, dynamic> toMap(EquiposPendientes equipoPendiente) =>
      equipoPendiente.toMap();

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
  String getEntityName() => 'EquipoPendiente';

  /// Obtener equipos PENDIENTES de un cliente
  Future<List<Map<String, dynamic>>> obtenerEquiposPendientesPorCliente(
      int clienteId,
      ) async {
    try {
      final sql = '''
    SELECT DISTINCT
      ep.id,
      ep.equipo_id,
      ep.cliente_id,
      ep.fecha_creacion,
      e.cod_barras,
      e.numero_serie,
      m.nombre as marca_nombre,
      mo.nombre as modelo_nombre,
      l.nombre as logo_nombre,
      c.nombre as cliente_nombre,
      'pendiente' as estado,
      'pendiente' as tipo_estado
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

      return result;
    } catch (e) {
      rethrow;
    }
  }

  /// Buscar ID del registro pendiente (para EstadoEquipoRepository)
  Future<int?> buscarEquipoPendienteId(dynamic equipoId, int clienteId) async {
    try {
      // Convertir a string para consistencia
      final equipoIdStr = equipoId.toString();

      final maps = await dbHelper.consultar(
        tableName,
        where: 'CAST(equipo_id AS TEXT) = ? AND cliente_id = ?',
        whereArgs: [equipoIdStr, clienteId],
        orderBy: 'fecha_creacion DESC', // Obtener el más reciente
        limit: 1,
      );

      if (maps.isNotEmpty) {
        final id = maps.first['id'] as int?;

        return id;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Procesar escaneo de censo - crear registro pendiente
  Future<String> procesarEscaneoCenso({
    required dynamic equipoId,
    required int clienteId,
    int? usuarioId,
    String? edfVendedorId,
  }) async {
    try {
      final now = DateTime.now();
      final equipoIdString = equipoId.toString();

      final authService = AuthService();
      final usuario = await authService.getCurrentUser();
      final usuarioCensoId = usuarioId ?? usuario?.id ?? 1;

      await dbHelper.eliminar(
        tableName,
        where: 'equipo_id = ? AND cliente_id = ?',
        whereArgs: [equipoIdString, clienteId],
      );

      final uuid = Uuid().v4();
      final datos = {
        'id': uuid,
        'equipo_id': equipoIdString,
        'cliente_id': clienteId,
        'fecha_censo': now.toIso8601String(),
        'usuario_censo_id': usuarioCensoId,
        'fecha_creacion': now.toIso8601String(),
        'fecha_actualizacion': now.toIso8601String(),
        'edf_vendedor_id': edfVendedorId,
        'sincronizado': 0,
      };

      await dbHelper.insertar(tableName, datos);

      return uuid;
    } catch (e) {
      rethrow;
    }
  }

  /// Marcar equipos pendientes como sincronizados
  /// ✅ Llamado desde CensoActivoPostService cuando la sincronización unificada es exitosa
  Future<int> marcarSincronizadosPorCenso(
      String equipoId,
      int clienteId,
      ) async {
    try {
      final actualizados = await dbHelper.actualizar(
        tableName,
        {
          'sincronizado': 1,
          'fecha_actualizacion': DateTime.now().toIso8601String(),
          'fecha_sincronizacion': DateTime.now().toIso8601String(),
        },
        where: 'equipo_id = ? AND cliente_id = ? AND sincronizado = 0',
        whereArgs: [equipoId, clienteId],
      );

      if (actualizados > 0) {
      } else {}

      return actualizados;
    } catch (e) {
      return 0;
    }
  }

  /// Crear nuevo registro de equipo pendiente
  /// ✅ COMPATIBLE: Acepta usuarioId como parámetro
  Future<int> crear(Map<String, dynamic> datos) async {
    try {
      final uuid = Uuid();

      // ✅ Obtener usuario del parámetro o del sistema
      final usuarioId =
          datos['usuario_censo_id'] ?? await _getUsuarioIdActual();

      final registroData = {
        'id': uuid.v4(),
        'equipo_id': datos['equipo_id'],
        'cliente_id': datos['cliente_id'],
        'fecha_censo': datos['fecha_censo'],
        'usuario_censo_id': usuarioId,
        'fecha_creacion': DateTime.now().toIso8601String(),
        'fecha_actualizacion': DateTime.now().toIso8601String(),
        'sincronizado': 0, // Será manejado por CensoActivoPostService
      };

      await dbHelper.insertar(tableName, registroData);

      return 0;
    } catch (e) {
      rethrow;
    }
  }

  /// ✅ Helper para obtener usuario actual
  Future<int> _getUsuarioIdActual() async {
    try {
      final authService = AuthService();
      final usuario = await authService.getCurrentUser();
      return usuario?.id ?? 1;
    } catch (e) {
      return 1;
    }
  }

  // ================================
  // MÉTODOS DE CONSULTA (sin sincronización manual)
  // ================================

  /// Obtener pendientes no sincronizados (para debug/reportes)
  Future<List<Map<String, dynamic>>> obtenerPendientesNoSincronizados() async {
    try {
      final sql = '''
        SELECT ep.*,
               e.cod_barras,
               e.numero_serie,
               m.nombre as marca_nombre,
               mo.nombre as modelo_nombre,
               c.nombre as cliente_nombre
        FROM equipos_pendientes ep
        LEFT JOIN equipos e ON ep.equipo_id = e.id
        LEFT JOIN marcas m ON e.marca_id = m.id
        LEFT JOIN modelos mo ON e.modelo_id = mo.id
        LEFT JOIN clientes c ON ep.cliente_id = c.id
        ORDER BY ep.fecha_creacion DESC
      ''';

      return await dbHelper.consultarPersonalizada(sql);
    } catch (e) {
      return [];
    }
  }

  /// Obtener estadísticas de pendientes
  Future<Map<String, dynamic>> obtenerEstadisticasPendientes() async {
    try {
      final sql = '''
        SELECT 
          COUNT(*) as total_pendientes,
          COUNT(CASE WHEN sincronizado = 0 THEN 1 END) as pendientes_no_sincronizados,
          COUNT(CASE WHEN sincronizado = 1 THEN 1 END) as pendientes_sincronizados,
          COUNT(DISTINCT equipo_id) as equipos_con_pendientes,
          COUNT(DISTINCT cliente_id) as clientes_con_pendientes
        FROM equipos_pendientes
      ''';

      final result = await dbHelper.consultarPersonalizada(sql);
      return result.isNotEmpty ? result.first : {};
    } catch (e) {
      return {};
    }
  }

  // ================================
  // MÉTODOS PARA DESCARGA/SINCRONIZACIÓN DESDE SERVIDOR
  // ================================

  /// Procesar equipos pendientes después de descargar censo del servidor
  Future<int> procesarPendientesDelCensoDescargado() async {
    try {
      final db = await dbHelper.database;

      final equiposPendientes = await db.rawQuery('''
      SELECT DISTINCT
        ca.equipo_id,
        ca.cliente_id,
        ca.usuario_id
      FROM censo_activo ca
      WHERE ca.estado_censo = 'pendiente'
      AND NOT EXISTS (
        SELECT 1 
        FROM equipos_pendientes ep 
        WHERE ep.equipo_id = ca.equipo_id 
        AND ep.cliente_id = ca.cliente_id
      )
    ''');

      if (equiposPendientes.isEmpty) {
        return 0;
      }

      int creados = 0;
      final now = DateTime.now();

      for (final equipo in equiposPendientes) {
        try {
          final datos = {
            'equipo_id': equipo['equipo_id'].toString(),
            'cliente_id': equipo['cliente_id'],
            'fecha_censo': now.toIso8601String(),
            'usuario_censo_id': equipo['usuario_id'] ?? 1,
            'fecha_creacion': now.toIso8601String(),
            'fecha_actualizacion': now.toIso8601String(),
            'sincronizado': 1, // Ya viene del servidor
            'fecha_sincronizacion': now.toIso8601String(),
          };

          await dbHelper.insertar(tableName, datos);
          creados++;
        } catch (e) {}
      }

      return creados;
    } catch (e) {
      return 0;
    }
  }

  Future<int> guardarEquiposPendientesDesdeServidor(
      List<Map<String, dynamic>> equiposAPI,
      ) async {
    final db = await dbHelper.database;
    int guardados = 0;

    await db.transaction((txn) async {
      await txn.delete('equipos_pendientes');

      for (var equipoAPI in equiposAPI) {
        try {
          // ✅ MAPEO MEJORADO: Incluir usuario, fecha y edf_vendedor_id
          final equipoLocal = {
            'id': equipoAPI['id'],
            'equipo_id': equipoAPI['edfEquipoId'],
            'cliente_id': equipoAPI['edfClienteId'],
            'fecha_creacion': equipoAPI['creationDate'],
            'fecha_actualizacion': DateTime.now().toIso8601String(),
            'fecha_censo': equipoAPI['creationDate'],
            'usuario_censo_id':
            equipoAPI['usuarioId'] ?? equipoAPI['usuario']?['id'] ?? 1,

            // --- CORRECCIÓN AQUÍ: Guardar edf_vendedor_id ---
            'edf_vendedor_id':
            equipoAPI['edfVendedorSucursalId'] ??
                equipoAPI['edfVendedorId'],

            // ------------------------------------------------
            'sincronizado': 1,
            'fecha_sincronizacion': DateTime.now().toIso8601String(),
          };

          await txn.insert(
            'equipos_pendientes',
            equipoLocal,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );

          guardados++;
        } catch (e) {}
      }
    });

    return guardados;
  }

// ================================
// MÉTODOS DE DEBUG Y VERIFICACIÓN
// ================================
}
