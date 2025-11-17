import 'package:ada_app/models/equipos_pendientes.dart';
import 'package:ada_app/services/post/equipo_pendiente_post_service.dart';
import 'base_repository.dart';
import 'package:uuid/uuid.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:ada_app/services/auth_service.dart';
import 'package:sqflite/sqflite.dart';

class EquipoPendienteRepository extends BaseRepository<EquiposPendientes> {
  final Logger _logger = Logger();

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
      int clienteId) async {
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
      _logger.e(
          'Error obteniendo equipos pendientes del cliente $clienteId: $e');
      rethrow;
    }
  }

  /// Buscar ID del registro pendiente (para EstadoEquipoRepository)
  Future<int?> buscarEquipoPendienteId(dynamic equipoId, int clienteId) async {
    try {
      // Convertir a string para consistencia
      final equipoIdStr = equipoId.toString();

      _logger.i('🔍 Buscando pendiente: equipoId=$equipoIdStr, clienteId=$clienteId');

      final maps = await dbHelper.consultar(
        tableName,
        where: 'CAST(equipo_id AS TEXT) = ? AND cliente_id = ?',
        whereArgs: [equipoIdStr, clienteId],
        orderBy: 'fecha_creacion DESC', // Obtener el más reciente
        limit: 1,
      );

      if (maps.isNotEmpty) {
        final id = maps.first['id'] as int?;
        _logger.i('✅ Encontrado registro pendiente: ID=$id');
        return id;
      }

      _logger.i('❌ No existe registro pendiente');
      return null;
    } catch (e) {
      _logger.e('❌ Error buscando ID de equipo pendiente: $e');
      return null;
    }
  }

  /// Procesar escaneo de censo - crear registro pendiente
  /// ✅ CORREGIDO: Ahora acepta y usa el usuario correcto
  Future<String> procesarEscaneoCenso({
    required dynamic equipoId,
    required int clienteId,
    int? usuarioId, // ✅ Añadir parámetro opcional
  }) async {
    try {
      final now = DateTime.now();
      final equipoIdString = equipoId.toString();

      // ✅ Obtener usuario actual si no se proporcionó
      final authService = AuthService();
      final usuario = await authService.getCurrentUser();
      final usuarioCensoId = usuarioId ?? usuario?.id ?? 1;

      _logger.i('Procesando censo - equipoId: $equipoIdString, clienteId: $clienteId, usuarioId: $usuarioCensoId');

      // Verificar si ya existe por equipo_id + cliente_id
      final existente = await dbHelper.consultar(
        tableName,
        where: 'equipo_id = ? AND cliente_id = ?',
        whereArgs: [equipoIdString, clienteId],
        limit: 1,
      );

      if (existente.isNotEmpty) {
        final registroId = existente.first['id'].toString();
        _logger.i('✅ Ya existe registro pendiente (UUID: $registroId) - ACTUALIZANDO');

        // ✅ Actualizar con usuario correcto
        await dbHelper.actualizar(
          tableName,
          {
            'fecha_censo': now.toIso8601String(),
            'fecha_actualizacion': now.toIso8601String(),
            'usuario_censo_id': usuarioCensoId,
            'sincronizado': 0, // Marcar para reenvío
          },
          where: 'id = ?',
          whereArgs: [registroId],
        );

        _logger.i('📅 Fecha actualizada para UUID: $registroId con usuario: $usuarioCensoId');
        _enviarAlServidorAsync(equipoIdString, clienteId);
        return registroId;
      }

      // Crear nuevo registro con UUID
      final uuid = Uuid().v4();
      final datos = {
        'id': uuid,
        'equipo_id': equipoIdString,
        'cliente_id': clienteId,
        'fecha_censo': now.toIso8601String(),
        'usuario_censo_id': usuarioCensoId, // ✅ Usuario correcto
        'fecha_creacion': now.toIso8601String(),
        'fecha_actualizacion': now.toIso8601String(),
        'sincronizado': 0,
      };

      await dbHelper.insertar(tableName, datos);
      _logger.i('✅ Registro pendiente NUEVO creado con UUID: $uuid y usuario: $usuarioCensoId');

      _enviarAlServidorAsync(equipoIdString, clienteId);
      return uuid;

    } catch (e) {
      _logger.e('❌ Error procesando escaneo de censo: $e');
      rethrow;
    }
  }

  /// Marcar equipos pendientes como sincronizados cuando su censo se migra
  /// ✅ CORREGIDO: Ahora registra fecha_sincronizacion
  Future<int> marcarSincronizadosPorCenso(String equipoId, int clienteId) async {
    try {
      final actualizados = await dbHelper.actualizar(
        tableName,
        {
          'sincronizado': 1,
          'fecha_actualizacion': DateTime.now().toIso8601String(),
          'fecha_sincronizacion': DateTime.now().toIso8601String(), // ✅ Añadir fecha
        },
        where: 'equipo_id = ? AND cliente_id = ? AND sincronizado = 0',
        whereArgs: [equipoId, clienteId],
      );

      _logger.i('✅ Equipos pendientes marcados como sincronizados: $actualizados');
      return actualizados;
    } catch (e) {
      _logger.e('❌ Error marcando equipos pendientes como sincronizados: $e');
      return 0;
    }
  }

  /// Crear nuevo registro de equipo pendiente
  /// ✅ CORREGIDO: Acepta usuarioId como parámetro
  Future<int> crear(Map<String, dynamic> datos) async {
    try {
      final uuid = Uuid();

      // ✅ Obtener usuario del parámetro o del sistema
      final usuarioId = datos['usuario_censo_id'] ?? await _getUsuarioIdActual();

      final registroData = {
        'id': uuid.v4(),
        'equipo_id': datos['equipo_id'],
        'cliente_id': datos['cliente_id'],
        'fecha_censo': datos['fecha_censo'],
        'usuario_censo_id': usuarioId, // ✅ Usuario correcto
        'fecha_creacion': DateTime.now().toIso8601String(),
        'fecha_actualizacion': DateTime.now().toIso8601String(),
        'sincronizado': 0,
      };

      await dbHelper.insertar(tableName, registroData);
      _logger.i('✅ Registro pendiente creado con UUID: ${registroData['id']}, usuario: $usuarioId');

      return 0;
    } catch (e) {
      _logger.e('❌ Error creando registro: $e');
      rethrow;
    }
  }

  /// ✅ NUEVO: Helper para obtener usuario actual
  Future<int> _getUsuarioIdActual() async {
    try {
      final authService = AuthService();
      final usuario = await authService.getCurrentUser();
      return usuario?.id ?? 1;
    } catch (e) {
      _logger.w('⚠️ No se pudo obtener usuario actual, usando 1 por defecto');
      return 1;
    }
  }

  /// Sincronizar pendientes locales al servidor
  /// ✅ CORREGIDO: Registra fecha_sincronizacion al marcar como sincronizado
  Future<Map<String, dynamic>> sincronizarPendientesAlServidor() async {
    try {
      _logger.i('Sincronizando pendientes...');

      final pendientes = await dbHelper.consultar(
        tableName,
        where: 'sincronizado = ?',
        whereArgs: [0],
      );

      if (pendientes.isEmpty) {
        return {'exito': true, 'mensaje': 'No hay pendientes'};
      }

      _logger.i('Encontrados ${pendientes.length} pendientes');

      final authService = AuthService();
      final usuario = await authService.getCurrentUser();
      final usuarioId = usuario?.id ?? 1;
      final edfVendedorId = usuario?.edfVendedorId ?? '1';

      int exitosos = 0;
      int fallidos = 0;

      for (final pendiente in pendientes) {
        try {
          final payload = {
            'id': DateTime.now().millisecondsSinceEpoch.toString(),
            'edfVendedorSucursalId': edfVendedorId,
            'edfEquipoId': pendiente['equipo_id'].toString(),
            'edfClienteId': pendiente['cliente_id'],
            'usuarioId': usuarioId,
            'fecha_revision': pendiente['fecha_censo'] ?? DateTime.now().toIso8601String(),
            'equipo_id': pendiente['equipo_id'].toString(),
            'cliente_id': pendiente['cliente_id'],
            'usuario_id': usuarioId,
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
            // ✅ Marcar como sincronizado CON fecha
            await dbHelper.actualizar(
              tableName,
              {
                'sincronizado': 1,
                'fecha_sincronizacion': DateTime.now().toIso8601String(), // ✅ Añadir fecha
              },
              where: 'id = ?',
              whereArgs: [pendiente['id']],
            );
            exitosos++;
            _logger.i('✅ Pendiente sincronizado con fecha: ${pendiente['id']}');
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
            'usuario_censo_id': equipo['usuario_id'] ?? 1, // ✅ Usar usuario del censo
            'fecha_creacion': now.toIso8601String(),
            'fecha_actualizacion': now.toIso8601String(),
            'sincronizado': 1, // Ya viene del servidor
            'fecha_sincronizacion': now.toIso8601String(), // ✅ Añadir fecha
          };

          await dbHelper.insertar(tableName, datos);
          creados++;
          _logger.i('✅ Pendiente recreado: Equipo ${equipo['equipo_id']} → Cliente ${equipo['cliente_id']} (Usuario: ${datos['usuario_censo_id']})');
        } catch (e) {
          _logger.w('⚠️ Error creando pendiente: $e');
        }
      }

      _logger.i('📊 Procesamiento completado: $creados pendientes recreados');
      return creados;
    } catch (e) {
      _logger.e('❌ Error procesando pendientes del censo: $e');
      return 0;
    }
  }

  /// Guardar equipos pendientes desde el servidor con mapeo de campos
  /// ✅ CORREGIDO: Extrae y guarda usuario_censo_id correctamente
  Future<int> guardarEquiposPendientesDesdeServidor(List<Map<String, dynamic>> equiposAPI) async {
    final db = await dbHelper.database;
    int guardados = 0;

    _logger.i('Guardando ${equiposAPI.length} equipos pendientes desde servidor...');

    await db.transaction((txn) async {
      await txn.delete('equipos_pendientes');
      _logger.i('Tabla equipos_pendientes limpiada');

      for (var equipoAPI in equiposAPI) {
        try {
          // ✅ MAPEO MEJORADO: Incluir usuario y fecha de sincronización
          final equipoLocal = {
            'id': equipoAPI['id'],
            'equipo_id': equipoAPI['edfEquipoId'],
            'cliente_id': equipoAPI['edfClienteId'],
            'fecha_creacion': equipoAPI['creationDate'],
            'fecha_actualizacion': DateTime.now().toIso8601String(),
            'fecha_censo': equipoAPI['creationDate'],
            'usuario_censo_id': equipoAPI['usuarioId'] ?? equipoAPI['usuario']?['id'] ?? 1, // ✅ Extraer usuario
            'sincronizado': 1,
            'fecha_sincronizacion': DateTime.now().toIso8601String(), // ✅ Registrar fecha
          };

          _logger.i('Insertando: equipo_id=${equipoLocal['equipo_id']}, cliente_id=${equipoLocal['cliente_id']}, usuario=${equipoLocal['usuario_censo_id']}');

          await txn.insert(
            'equipos_pendientes',
            equipoLocal,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );

          guardados++;
          _logger.i('✅ Guardado exitosamente');

        } catch (e) {
          _logger.e('❌ Error guardando: $e');
          _logger.e('Dato API: $equipoAPI');
        }
      }
    });

    _logger.i('✅ $guardados equipos pendientes guardados correctamente');
    await debugVerificarDatos();
    return guardados;
  }

  /// DEBUG: Verificar datos guardados
  Future<void> debugVerificarDatos() async {
    final db = await dbHelper.database;

    _logger.i('=== DEBUG: Verificando datos en equipos_pendientes ===');

    final schema = await db.rawQuery("PRAGMA table_info(equipos_pendientes)");
    _logger.i('Columnas de la tabla: ${schema.map((e) => e['name']).toList()}');

    final todos = await db.query('equipos_pendientes');
    _logger.i('Total de registros en tabla: ${todos.length}');

    if (todos.isNotEmpty) {
      _logger.i('=== TODOS LOS REGISTROS ===');
      for (var i = 0; i < todos.length; i++) {
        _logger.i('--- Registro ${i + 1} ---');
        todos[i].forEach((key, value) {
          _logger.i('  $key: $value');
        });
      }
    } else {
      _logger.w('⚠️ LA TABLA ESTÁ VACÍA');
    }

    _logger.i('========================================================');
  }

  void _enviarAlServidorAsync(String equipoId, int clienteId) {
    Future(() async {
      try {
        _logger.i('🚀 INICIO envío async: equipo=$equipoId, cliente=$clienteId');

        final authService = AuthService();
        final usuario = await authService.getCurrentUser();
        final edfVendedorId = usuario?.edfVendedorId ?? '1_1';

        _logger.i('👤 VendedorId obtenido: $edfVendedorId');

        final resultado = await EquiposPendientesApiService.enviarEquipoPendiente(
          equipoId: equipoId,
          clienteId: clienteId,
          edfVendedorId: edfVendedorId,
        );

        _logger.i('📨 RESULTADO FINAL: $resultado');

        if (resultado['exito']) {
          // ✅ Marcar como sincronizado CON fecha
          await dbHelper.actualizar(
            tableName,
            {
              'sincronizado': 1,
              'fecha_sincronizacion': DateTime.now().toIso8601String(),
            },
            where: 'equipo_id = ? AND cliente_id = ?',
            whereArgs: [equipoId, clienteId],
          );
          _logger.i('✅ Enviado al servidor correctamente y marcado con fecha');
        } else {
          _logger.w('⚠️ Fallo: ${resultado['mensaje']}');
        }
      } catch (e) {
        _logger.e('❌ Error completo: $e');
      }
    });
  }
}