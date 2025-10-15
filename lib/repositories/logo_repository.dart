import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import '../models/logo.dart';
import '../services/sync/base_sync_service.dart';
import '../services/database_helper.dart';
import 'base_repository.dart';

final _logger = Logger();

class LogoRepository extends BaseRepository<Logo> {
  static final _dbHelper = DatabaseHelper();

  @override
  String get tableName => 'logo';

  @override
  Logo fromMap(Map<String, dynamic> map) => Logo.fromMap(map);

  @override
  Map<String, dynamic> toMap(Logo logo) => logo.toMap();

  @override
  String getDefaultOrderBy() => 'nombre ASC';

  @override
  String getBuscarWhere() => 'activo = ? AND LOWER(nombre) LIKE ?';

  @override
  List<dynamic> getBuscarArgs(String query) {
    final searchTerm = '%${query.toLowerCase()}%';
    return [1, searchTerm];
  }

  @override
  String getEntityName() => 'Logo';

  /// Sincronizar logos desde el servidor
  /// Usa el mismo flujo que EquipmentSyncService.sincronizarLogos()
  Future<Map<String, dynamic>> sincronizarDesdeServidor() async {
    try {
      _logger.i('🎨 Sincronizando logos desde el servidor...');

      final baseUrl = await BaseSyncService.getBaseUrl();

      final response = await http.get(
        Uri.parse('$baseUrl/api/getEdfLogos'),
        headers: BaseSyncService.headers,
      ).timeout(BaseSyncService.timeout);

      _logger.i('📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        // Parsear respuesta (puede venir como Map con 'data' o como List directa)
        List<dynamic> logosAPI = [];
        if (responseData is Map<String, dynamic>) {
          if (responseData.containsKey('data')) {
            if (responseData['data'] is String) {
              final String dataString = responseData['data'];
              logosAPI = jsonDecode(dataString) as List<dynamic>;
            } else if (responseData['data'] is List) {
              logosAPI = responseData['data'] as List<dynamic>;
            }
          }
        } else if (responseData is List) {
          logosAPI = responseData;
        }

        _logger.i('📊 Logos parseados de la API: ${logosAPI.length}');

        if (logosAPI.isNotEmpty) {
          // DatabaseHelper.sincronizarLogos() llama a DatabaseSync._mapearLogo()
          // que mapea logoData['logo'] → 'nombre' en la BD
          await _dbHelper.sincronizarLogos(logosAPI);

          _logger.i('✅ Logos sincronizados exitosamente: ${logosAPI.length}');

          return {
            'exito': true,
            'mensaje': 'Logos sincronizados correctamente',
            'itemsSincronizados': logosAPI.length,
          };
        } else {
          _logger.w('⚠️ No se encontraron logos en la respuesta');
          return {
            'exito': true,
            'mensaje': 'No se encontraron logos',
            'itemsSincronizados': 0,
          };
        }
      } else {
        final mensaje = BaseSyncService.extractErrorMessage(response);
        _logger.e('❌ Error del servidor: $mensaje');
        return {
          'exito': false,
          'mensaje': mensaje,
          'itemsSincronizados': 0,
        };
      }
    } catch (e) {
      _logger.e('💥 Error sincronizando logos: $e');
      return {
        'exito': false,
        'mensaje': BaseSyncService.getErrorMessage(e),
        'itemsSincronizados': 0,
      };
    }
  }

  /// Obtener logo por nombre
  Future<Logo?> obtenerPorNombre(String nombre) async {
    final maps = await dbHelper.consultar(
      tableName,
      where: 'LOWER(nombre) = LOWER(?) AND activo = ?',
      whereArgs: [nombre.trim(), 1],
      limit: 1,
    );
    return maps.isNotEmpty ? fromMap(maps.first) : null;
  }

  /// Verificar si existe un logo por nombre
  Future<bool> existeNombre(String nombre, {int? excludeId}) async {
    String where = 'LOWER(nombre) = LOWER(?) AND activo = ?';
    List<dynamic> whereArgs = [nombre.trim(), 1];

    if (excludeId != null) {
      where += ' AND id != ?';
      whereArgs.add(excludeId);
    }

    return await dbHelper.existeRegistro(tableName, where, whereArgs);
  }

  /// Borrar todas las marcas/logos
  Future<void> borrarTodos() async {
    await dbHelper.eliminar(tableName);
  }

  /// Contar equipos por logo
  Future<Map<String, dynamic>> obtenerEstadisticasLogo() async {
    const sql = '''
      SELECT 
        l.id,
        l.nombre,
        COUNT(e.id) as total_equipos,
        COUNT(CASE WHEN ec.id IS NOT NULL THEN 1 END) as equipos_asignados,
        COUNT(CASE WHEN ec.id IS NULL THEN 1 END) as equipos_disponibles
      FROM logo l
      LEFT JOIN equipos e ON l.id = e.logo_id AND e.activo = 1 AND e.estado_local = 1
      LEFT JOIN equipo_cliente ec ON e.id = ec.equipo_id AND ec.activo = 1 AND ec.fecha_retiro IS NULL
      WHERE l.activo = 1
      GROUP BY l.id, l.nombre
      ORDER BY l.nombre
    ''';
    return {'logos_con_equipos': await dbHelper.consultarPersonalizada(sql)};
  }
}