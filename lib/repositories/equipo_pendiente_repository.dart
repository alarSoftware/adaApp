import 'package:ada_app/models/equipos_pendientes.dart';
import 'base_repository.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:ada_app/services/auth_service.dart';

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
      _logger.i('Equipos PENDIENTES para cliente $clienteId: ${result.length}');
      return result;
    } catch (e) {
      _logger.e('Error obteniendo equipos pendientes del cliente $clienteId: $e');
      rethrow;
    }
  }

  /// Buscar ID del registro pendiente (para EstadoEquipoRepository)
  Future<int?> buscarEquipoPendienteId(dynamic equipoId, int clienteId) async {
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
    required dynamic equipoId, // Acepta String o int
    required int clienteId,
  }) async {
    try {
      final now = DateTime.now();

      // Convertir a String para almacenar (ya que la columna es TEXT)
      final equipoIdString = equipoId.toString();

      _logger.i('Procesando censo - equipoId: $equipoIdString, clienteId: $clienteId');

      // Verificar si ya existe
      final existe = await buscarEquipoPendienteId(equipoIdString, clienteId);
      if (existe != null) {
        _logger.i('Ya existe registro pendiente para equipoId: $equipoIdString, clienteId: $clienteId');
        return existe;
      }

      // Crear nuevo registro
      final datos = {
        'equipo_id': equipoIdString, // Guardar como String
        'cliente_id': clienteId,
        'fecha_censo': now.toIso8601String(),
        'usuario_censo_id': 1,
        'latitud': 0.0,
        'longitud': 0.0,
        'observaciones': 'Registro creado desde censo móvil',
      };

      final id = await crear(datos);
      _logger.i('Registro pendiente creado: Equipo $equipoIdString → Cliente $clienteId (ID: $id)');
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
  /// Sincronizar pendientes locales al servidor
  /// Sincronizar pendientes locales al servidor
  Future<Map<String, dynamic>> sincronizarPendientesAlServidor() async {
    try {
      _logger.i('Sincronizando pendientes...');

      // Obtener pendientes no sincronizados
      final pendientes = await dbHelper.consultar(
        tableName,
        where: 'sincronizado = ?',
        whereArgs: [0],
      );

      if (pendientes.isEmpty) {
        return {'exito': true, 'mensaje': 'No hay pendientes'};
      }

      _logger.i('Encontrados ${pendientes.length} pendientes');

      // Necesitamos AuthService para el usuario
      final authService = AuthService();
      final usuario = await authService.getCurrentUser();
      final usuarioId = usuario?.id ?? 1;
      final edfVendedorId = usuario?.edfVendedorId ?? '1';

      int exitosos = 0;
      int fallidos = 0;

      // Enviar cada pendiente
      for (final pendiente in pendientes) {
        try {
          final payload = {
            'id': DateTime.now().millisecondsSinceEpoch.toString(),
            'edfVendedorSucursalId': edfVendedorId,
            'edfEquipoId': pendiente['equipo_id'].toString(),
            'edfClienteId': pendiente['cliente_id'],
            'usuarioId': usuarioId,
            'fecha_revision': pendiente['fecha_censo'] ?? DateTime.now().toIso8601String(),
            'latitud': pendiente['latitud'] ?? 0.0,
            'longitud': pendiente['longitud'] ?? 0.0,
            'equipo_id': pendiente['equipo_id'].toString(),
            'cliente_id': pendiente['cliente_id'],
            'usuario_id': usuarioId,
            'observaciones': 'Pendiente desde APP móvil',
            'es_censo': true,
            'estadoCenso': 'pendiente'
          };

          _logger.i('Enviando pendiente: ${pendiente['equipo_id']}');

          final response = await http.post(
            Uri.parse('https://ada-api.loca.lt/adaControl/censoActivo/insertCensoActivo'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(payload),
          ).timeout(Duration(seconds: 10));

          if (response.statusCode >= 200 && response.statusCode < 300) {
            // Marcar como sincronizado
            await dbHelper.actualizar(
              tableName,
              {
                'sincronizado': 1,
                'fecha_sincronizacion': DateTime.now().toIso8601String(),
              },
              where: 'id = ?',
              whereArgs: [pendiente['id']],
            );
            exitosos++;
          } else {
            fallidos++;
          }
        } catch (e) {
          _logger.e('Error en pendiente: $e');
          fallidos++;
        }
      }

      return {
        'exito': exitosos > 0,
        'mensaje': 'Sincronizados: $exitosos, Fallidos: $fallidos'
      };

    } catch (e) {
      _logger.e('Error sincronizando: $e');
      return {'exito': false, 'mensaje': 'Error: $e'};
    }
  }
  /// Procesar equipos pendientes después de descargar censo del servidor
  Future<int> procesarPendientesDelCensoDescargado() async {
    try {
      _logger.i('🔄 Procesando pendientes del censo descargado...');

      final db = await dbHelper.database;

      // Obtener equipos con estadoCenso = 'pendiente' del censo_activo
      final equiposPendientes = await db.rawQuery('''
      SELECT DISTINCT
        ca.equipo_id,
        ca.cliente_id
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
        _logger.i('✅ No hay pendientes nuevos en el censo descargado');
        return 0;
      }

      _logger.i('📋 Encontrados ${equiposPendientes.length} pendientes nuevos');

      int creados = 0;
      final now = DateTime.now();

      for (final equipo in equiposPendientes) {
        try {
          final datos = {
            'equipo_id': equipo['equipo_id'].toString(),
            'cliente_id': equipo['cliente_id'],
            'fecha_censo': now.toIso8601String(),
            'usuario_censo_id': 1,
            'latitud': 0.0,
            'longitud': 0.0,
            'observaciones': 'Pendiente sincronizado desde servidor',
            'fecha_creacion': now.toIso8601String(),
            'fecha_actualizacion': now.toIso8601String(),
            'sincronizado': 1, // Ya viene del servidor
          };

          await dbHelper.insertar(tableName, datos);
          creados++;
          _logger.i('✅ Pendiente recreado: Equipo ${equipo['equipo_id']} → Cliente ${equipo['cliente_id']}');

        } catch (e) {
          _logger.w('⚠️ Error creando pendiente: $e');
        }
      }

      _logger.i('📊 Procesamiento compcletado: $creados pendientes recreados');
      return creados;

    } catch (e) {
      _logger.e('❌ Error procesando pendientes del censo: $e');
      return 0;
    }
  }
}