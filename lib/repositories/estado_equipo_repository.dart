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
  String getBuscarWhere() => 'CAST(equipo_pendiente_id AS TEXT) LIKE ?';

  @override
  List<dynamic> getBuscarArgs(String query) {
    final searchTerm = '%${query.toLowerCase()}%';
    return [searchTerm];
  }

  @override
  String getEntityName() => 'EstadoEquipo';

  // ========== MÉTODOS ESPECÍFICOS PARA ESTADO_EQUIPO (NUEVA ESTRUCTURA) ==========

  /// Crear nuevo estado con GPS
  Future<EstadoEquipo> crearNuevoEstado({
    required int equipoPendienteId,
    required bool enLocal,
    required DateTime fechaRevision,
    double? latitud,
    double? longitud,
    String? estadoCenso,
  }) async {
    final nuevoEstado = EstadoEquipo(
      equipoPendienteId: equipoPendienteId,
      enLocal: enLocal,
      fechaRevision: fechaRevision,
      fechaCreacion: DateTime.now(),
      fechaActualizacion: DateTime.now(),
      estaSincronizado: false,
      latitud: latitud,
      longitud: longitud,
      estadoCenso: estadoCenso ?? 'creado',
    );

    final id = await insertar(nuevoEstado);
    return nuevoEstado.copyWith(id: id);
  }

  /// Registrar escaneo de equipo con ubicación
  Future<EstadoEquipo> registrarEscaneoEquipo({
    required int equipoPendienteId,
    required double latitud,
    required double longitud,
  }) async {
    final nuevoEstado = EstadoEquipo(
      equipoPendienteId: equipoPendienteId,
      enLocal: true,
      fechaRevision: DateTime.now(),
      fechaCreacion: DateTime.now(),
      fechaActualizacion: DateTime.now(),
      estaSincronizado: false,
      latitud: latitud,
      longitud: longitud,
      estadoCenso: 'creado',
    );

    final id = await insertar(nuevoEstado);
    return nuevoEstado.copyWith(id: id);
  }

  // ========== MÉTODOS PARA MANEJO DE ESTADOS DE CENSO ==========
  /// Crear nuevo estado de censo con estado 'creado' por defecto
  Future<EstadoEquipo> crearNuevoEstadoCenso({
    required int equipoPendienteId,
    required double latitud,
    required double longitud,
    DateTime? fechaRevision,
    bool enLocal = true,
    String? observaciones,

    // Nuevos parámetros de imagen (OPCIONALES)
    String? imagenPath,
    String? imagenBase64,
    bool tieneImagen = false,
    int? imagenTamano,
  }) async {
    try {
      final now = fechaRevision ?? DateTime.now();

      final nuevoEstado = EstadoEquipo(
        equipoPendienteId: equipoPendienteId,
        enLocal: enLocal,
        latitud: latitud,
        longitud: longitud,
        fechaRevision: now,
        fechaCreacion: now,
        fechaActualizacion: now,
        estaSincronizado: false,
        estadoCenso: EstadoEquipoCenso.creado.valor,

        // Campos de imagen
        imagenPath: imagenPath,
        imagenBase64: imagenBase64,
        tieneImagen: tieneImagen,
        imagenTamano: imagenTamano,
      );

      final id = await insertar(nuevoEstado);
      _logger.i('Estado CREADO ${tieneImagen ? "con imagen" : "sin imagen"} para equipo_pendiente $equipoPendienteId (ID: $id)');

      return nuevoEstado.copyWith(id: id);
    } catch (e) {
      _logger.e('Error creando estado de censo: $e');
      rethrow;
    }
  }

  /// Marcar estado como migrado exitosamente
  Future<bool> marcarComoMigrado(int estadoId, {int? servidorId}) async {
    try {
      final datosActualizacion = <String, dynamic>{
        'estado_censo': EstadoEquipoCenso.migrado.valor,
        'fecha_actualizacion': DateTime.now().toIso8601String(),
        'sincronizado': 1,
      };

      final count = await dbHelper.actualizar(
        tableName,
        datosActualizacion,
        where: 'id = ?',
        whereArgs: [estadoId],
      );

      if (count > 0) {
        _logger.i('✅ Estado $estadoId marcado como MIGRADO');
        return true;
      } else {
        _logger.w('⚠️ No se encontró el estado $estadoId para marcar como migrado');
        return false;
      }
    } catch (e) {
      _logger.e('❌ Error marcando como migrado: $e');
      return false;
    }
  }

  /// Marcar estado como error en migración
  Future<bool> marcarComoError(int estadoId, String mensajeError) async {
    try {
      final datosActualizacion = <String, dynamic>{
        'estado_censo': EstadoEquipoCenso.error.valor,
        'fecha_actualizacion': DateTime.now().toIso8601String(),
        'sincronizado': 0, // Mantener como no sincronizado para reintentar
      };

      final count = await dbHelper.actualizar(
        tableName,
        datosActualizacion,
        where: 'id = ?',
        whereArgs: [estadoId],
      );

      if (count > 0) {
        _logger.e('❌ Estado $estadoId marcado como ERROR: $mensajeError');
        return true;
      } else {
        _logger.w('⚠️ No se encontró el estado $estadoId para marcar como error');
        return false;
      }
    } catch (e) {
      _logger.e('❌ Error marcando como error: $e');
      return false;
    }
  }

  /// Obtener registros por estado de censo
  Future<List<EstadoEquipo>> obtenerPorEstadoCenso(EstadoEquipoCenso estadoCenso) async {
    try {
      final maps = await dbHelper.consultar(
        tableName,
        where: 'estado_censo = ?',
        whereArgs: [estadoCenso.valor],
        orderBy: 'fecha_revision DESC',
      );
      return maps.map((map) => fromMap(map)).toList();
    } catch (e) {
      _logger.e('Error al obtener por estado censo: $e');
      return [];
    }
  }

  /// Obtener registros creados (pendientes de migración)
  Future<List<EstadoEquipo>> obtenerCreados() async {
    return await obtenerPorEstadoCenso(EstadoEquipoCenso.creado);
  }

  /// Obtener registros migrados exitosamente
  Future<List<EstadoEquipo>> obtenerMigrados() async {
    return await obtenerPorEstadoCenso(EstadoEquipoCenso.migrado);
  }

  /// Obtener registros con error
  Future<List<EstadoEquipo>> obtenerConError() async {
    return await obtenerPorEstadoCenso(EstadoEquipoCenso.error);
  }

  /// Reintentar migración de registros con error
  Future<void> reintentarMigracion(int estadoId) async {
    try {
      final datosActualizacion = <String, dynamic>{
        'estado_censo': EstadoEquipoCenso.creado.valor,
        'fecha_actualizacion': DateTime.now().toIso8601String(),
        'sincronizado': 0,
      };

      await dbHelper.actualizar(
        tableName,
        datosActualizacion,
        where: 'id = ?',
        whereArgs: [estadoId],
      );

      _logger.i('🔄 Estado $estadoId preparado para reintento de migración');
    } catch (e) {
      _logger.e('❌ Error preparando reintento: $e');
      rethrow;
    }
  }

  /// Contar registros por estado
  Future<Map<String, int>> contarPorEstado() async {
    try {
      final creados = await obtenerCreados();
      final migrados = await obtenerMigrados();
      final conError = await obtenerConError();

      return {
        'creados': creados.length,
        'migrados': migrados.length,
        'error': conError.length,
        'total': creados.length + migrados.length + conError.length,
      };
    } catch (e) {
      _logger.e('Error contando por estado: $e');
      return {
        'creados': 0,
        'migrados': 0,
        'error': 0,
        'total': 0,
      };
    }
  }

  /// Obtener estadísticas de migración
  Future<Map<String, dynamic>> obtenerEstadisticasMigracion() async {
    try {
      final conteos = await contarPorEstado();
      final total = conteos['total'] ?? 0;

      if (total == 0) {
        return {
          'total_registros': 0,
          'migrados': 0,
          'pendientes': 0,
          'errores': 0,
          'porcentaje_migrado': 0.0,
          'porcentaje_pendiente': 0.0,
          'porcentaje_error': 0.0,
        };
      }

      final migrados = conteos['migrados'] ?? 0;
      final creados = conteos['creados'] ?? 0;
      final errores = conteos['error'] ?? 0;

      return {
        'total_registros': total,
        'migrados': migrados,
        'pendientes': creados,
        'errores': errores,
        'porcentaje_migrado': (migrados / total * 100).toDouble(),
        'porcentaje_pendiente': (creados / total * 100).toDouble(),
        'porcentaje_error': (errores / total * 100).toDouble(),
      };
    } catch (e) {
      _logger.e('Error obteniendo estadísticas de migración: $e');
      return {};
    }
  }

  // ========== MÉTODOS ORIGINALES EXISTENTES (SIN CAMBIOS) ==========

  /// Obtener historial completo por equipo_pendiente_id
  Future<List<EstadoEquipo>> obtenerHistorialCompleto(int equipoClienteId) async {
    try {
      final maps = await dbHelper.consultar(
        tableName,
        where: 'equipo_pendiente_id = ?',
        whereArgs: [equipoClienteId],
        orderBy: 'fecha_revision DESC',
      );
      return maps.map((map) => fromMap(map)).toList();
    } catch (e) {
      _logger.e('Error al obtener historial completo: $e');
      return [];
    }
  }

  /// Obtener estados por equipo_cliente_id
  Future<List<EstadoEquipo>> obtenerPorEquipoCliente(int equipoClienteId) async {
    try {
      final maps = await dbHelper.consultar(
        tableName,
        where: 'equipo_pendiente_id = ?',
        whereArgs: [equipoClienteId],
        orderBy: 'fecha_revision DESC',
      );
      return maps.map((map) => fromMap(map)).toList();
    } catch (e) {
      _logger.e('Error al obtener estados por equipo cliente: $e');
      return [];
    }
  }

  /// Obtener estado más reciente por equipo_cliente_id
  Future<EstadoEquipo?> obtenerUltimoEstado(int equipoClienteId) async {
    try {
      final maps = await dbHelper.consultar(
        tableName,
        where: 'equipo_pendiente_id = ?',
        whereArgs: [equipoClienteId],
        orderBy: 'fecha_revision DESC',
        limit: 1,
      );
      return maps.isNotEmpty ? fromMap(maps.first) : null;
    } catch (e) {
      _logger.e('Error al obtener último estado: $e');
      return null;
    }
  }

  /// Obtener últimos N cambios
  Future<List<EstadoEquipo>> obtenerUltimosCambios(int equipoClienteId, {int limite = 5}) async {
    try {
      final maps = await dbHelper.consultar(
        tableName,
        where: 'equipo_pendiente_id = ?',
        whereArgs: [equipoClienteId],
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
  @override
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

  /// Contar cambios por equipo_cliente_id
  Future<int> contarCambios(int equipoClienteId) async {
    try {
      final result = await dbHelper.consultar(
        tableName,
        where: 'equipo_pendiente_id = ?',
        whereArgs: [equipoClienteId],
      );
      return result.length;
    } catch (e) {
      _logger.e('Error al contar cambios: $e');
      return 0;
    }
  }

  /// Obtener estadísticas de cambios
  Future<Map<String, dynamic>> obtenerEstadisticasCambios(int equipoClienteId) async {
    try {
      final historial = await obtenerHistorialCompleto(equipoClienteId);

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

  Future<Map<String, dynamic>?> obtenerEstadoConDetalles(int? equipoPendienteId) async {
    try {
      // Si equipoPendienteId es null o 0, buscar por el estado ID actual
      if (equipoPendienteId == null || equipoPendienteId == 0) {
        _logger.w('equipoPendienteId is null/0, using direct approach');
        return null; // O implementar búsqueda alternativa
      }

      final sql = '''
      SELECT se.*,
             ep.equipo_id,
             ep.cliente_id,
             e.cod_barras,
             e.numero_serie,
             m.nombre as marca_nombre,
             mo.nombre as modelo_nombre,
             c.nombre as cliente_nombre
      FROM Estado_Equipo se
      JOIN equipos_pendientes ep ON se.equipo_pendiente_id = ep.id
      JOIN equipos e ON ep.equipo_id = e.id
      JOIN marcas m ON e.marca_id = m.id
      JOIN modelos mo ON e.modelo_id = mo.id
      JOIN clientes c ON ep.cliente_id = c.id
      WHERE se.id = ?  -- Cambiar a buscar por estado ID
      ORDER BY se.fecha_revision DESC
      LIMIT 1
    ''';

      final result = await dbHelper.consultarPersonalizada(sql, [equipoPendienteId]);
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      _logger.e('Error obteniendo estado con detalles: $e');
      return null;
    }
  }

  /// Preparar datos para sincronización
  Future<List<Map<String, dynamic>>> prepararDatosParaSincronizacion() async {
    try {
      final noSincronizados = await obtenerNoSincronizados();
      return noSincronizados.map((estado) => estado.toJson()).toList();
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

  // ========== MÉTODOS DE COMPATIBILIDAD (Para migración gradual) ==========

  /// Buscar equipoClienteId basado en equipoId y clienteId
  Future<int?> buscarEquipoPendienteId(dynamic equipoId, int clienteId) async {
    final result = await dbHelper.consultar(
      'equipos_pendientes',
      where: 'equipo_id = ? AND cliente_id = ?',
      whereArgs: [equipoId.toString(), clienteId],  // Convertir a String siempre
      limit: 1,
    );
    return result.isNotEmpty ? result.first['id'] as int? : null;
  }

  /// Método de compatibilidad - buscar por equipoId y clienteId
  Future<EstadoEquipo?> obtenerUltimoEstadoPorEquipoCliente(int equipoId, int clienteId) async {
    final equipoPendienteId = await buscarEquipoPendienteId(equipoId, clienteId);
    if (equipoPendienteId == null) return null;

    return await obtenerUltimoEstado(equipoPendienteId);
  }

  Future<EstadoEquipo> crearEstadoDirecto({
    required String equipoId,
    required int clienteId,
    required double latitud,
    required double longitud,
    DateTime? fechaRevision,
    bool enLocal = true,
    String? observaciones,
    String? imagenPath,
    String? imagenBase64,
    bool tieneImagen = false,
    int? imagenTamano,
  }) async {
    try {
      final now = fechaRevision ?? DateTime.now();

      // Create the estado record directly using your database structure
      final datosEstado = {
        'equipo_id': equipoId,  // TEXT field
        'cliente_id': clienteId,  // INTEGER field
        'en_local': enLocal ? 1 : 0,
        'latitud': latitud,
        'longitud': longitud,
        'fecha_revision': now.toIso8601String(),
        'fecha_creacion': now.toIso8601String(),
        'fecha_actualizacion': now.toIso8601String(),
        'sincronizado': 0,
        'imagen_path': imagenPath,
        'imagen_base64': imagenBase64,
        'tiene_imagen': tieneImagen ? 1 : 0,
        'imagen_tamano': imagenTamano,
        'estado_censo': 'creado',
      };

      final insertedId = await dbHelper.insertar(tableName, datosEstado);

      _logger.i('✅ Estado creado directamente con ID: $insertedId para equipo: $equipoId, cliente: $clienteId');

      // Return EstadoEquipo object with the proper ID
      return EstadoEquipo(
        id: insertedId, // Make sure this gets the actual inserted ID
        equipoPendienteId: 0, // Not used in this structure
        enLocal: enLocal,
        latitud: latitud,
        longitud: longitud,
        fechaRevision: now,
        fechaCreacion: now,
        fechaActualizacion: now,
        estaSincronizado: false,
        imagenPath: imagenPath,
        imagenBase64: imagenBase64,
        tieneImagen: tieneImagen,
        imagenTamano: imagenTamano,
        estadoCenso: 'creado',
      );

    } catch (e) {
      _logger.e('❌ Error creating estado directly: $e');
      rethrow;
    }
  }

  /// Método de compatibilidad - crear estado con equipoId y clienteId
  Future<EstadoEquipo?> crearNuevoEstadoLegacy({
    required int equipoId,
    required int clienteId,
    required bool enLocal,
    required DateTime fechaRevision,
    double? latitud,
    double? longitud,
  }) async {
    final equipoPendienteId = await buscarEquipoPendienteId(equipoId, clienteId);
    if (equipoPendienteId == null) {
      _logger.w('No se encontró relación equipos_pendientes para equipoId: $equipoId, clienteId: $clienteId');
      return null;
    }

    return await crearNuevoEstado(
      equipoPendienteId: equipoPendienteId,  // Usar el ID de equipos_pendientes
      enLocal: enLocal,
      fechaRevision: fechaRevision,
      latitud: latitud,
      longitud: longitud,
    );
  }

  // ========== MÉTODOS DEPRECATED ==========

  @Deprecated('Usar crearNuevoEstado() con equipoClienteId')
  Future<void> actualizarEstadoEquipo(int equipoId, int clienteId, bool enLocal) async {
    await crearNuevoEstadoLegacy(
      equipoId: equipoId,
      clienteId: clienteId,
      enLocal: enLocal,
      fechaRevision: DateTime.now(),
    );
  }
  /// Crear nuevo estado de censo con imagen
  Future<EstadoEquipo> crearNuevoEstadoCensoConImagen({
    required int equipoPendienteId,
    required double latitud,
    required double longitud,
    DateTime? fechaRevision,
    bool enLocal = true,
    String? observaciones,

    // Nuevos parámetros de imagen
    String? imagenPath,
    String? imagenBase64,
    bool tieneImagen = false,
    int? imagenTamano,
  }) async {
    try {
      final now = fechaRevision ?? DateTime.now();

      final nuevoEstado = EstadoEquipo(
        equipoPendienteId: equipoPendienteId,
        enLocal: enLocal,
        latitud: latitud,
        longitud: longitud,
        fechaRevision: now,
        fechaCreacion: now,
        fechaActualizacion: now,
        estaSincronizado: false,
        estadoCenso: EstadoEquipoCenso.creado.valor,

        // Campos de imagen
        imagenPath: imagenPath,
        imagenBase64: imagenBase64,
        tieneImagen: tieneImagen,
        imagenTamano: imagenTamano,
      );

      final id = await insertar(nuevoEstado);
      _logger.i('✅ Estado CREADO ${tieneImagen ? "con imagen" : "sin imagen"} para equipo_pendiente $equipoPendienteId (ID: $id)');

      return nuevoEstado.copyWith(id: id);
    } catch (e) {
      _logger.e('❌ Error creando estado de censo con imagen: $e');
      rethrow;
    }
  }

  /// Limpiar Base64 después de sincronización exitosa (para ahorrar espacio)
  Future<void> limpiarBase64DespuesDeSincronizacion(int estadoId) async {
    try {
      final datosActualizacion = <String, dynamic>{
        'imagen_base64': null, // Limpiar Base64 para ahorrar espacio
        'fecha_actualizacion': DateTime.now().toIso8601String(),
      };

      await dbHelper.actualizar(
        tableName,
        datosActualizacion,
        where: 'id = ? AND sincronizado = 1', // Solo si ya está sincronizado
        whereArgs: [estadoId],
      );

      _logger.i('🧹 Base64 limpiado para estado $estadoId (ya sincronizado)');
    } catch (e) {
      _logger.e('❌ Error limpiando Base64: $e');
      rethrow;
    }
  }

  /// Obtener estados con imágenes pendientes de sincronización
  Future<List<EstadoEquipo>> obtenerEstadosConImagenesPendientes() async {
    try {
      final maps = await dbHelper.consultar(
        tableName,
        where: 'tiene_imagen = 1 AND sincronizado = 0 AND imagen_base64 IS NOT NULL',
        orderBy: 'fecha_creacion ASC',
      );

      final estados = maps.map((map) => fromMap(map)).toList();
      _logger.i('📸 Encontrados ${estados.length} estados con imágenes pendientes');
      return estados;
    } catch (e) {
      _logger.e('❌ Error obteniendo estados con imágenes pendientes: $e');
      return [];
    }
  }

  /// Obtener estadísticas de imágenes
  Future<Map<String, dynamic>> obtenerEstadisticasImagenes() async {
    try {
      // Total de estados con imágenes
      final totalConImagenesResult = await dbHelper.consultarPersonalizada(
          'SELECT COUNT(*) as count FROM Estado_Equipo WHERE tiene_imagen = 1'
      );
      final totalConImagenes = totalConImagenesResult.first['count'] as int;

      // Imágenes sincronizadas
      final imagenesSincronizadasResult = await dbHelper.consultarPersonalizada(
          'SELECT COUNT(*) as count FROM Estado_Equipo WHERE tiene_imagen = 1 AND sincronizado = 1'
      );
      final imagenesSincronizadas = imagenesSincronizadasResult.first['count'] as int;

      // Imágenes pendientes
      final imagenesPendientesResult = await dbHelper.consultarPersonalizada(
          'SELECT COUNT(*) as count FROM Estado_Equipo WHERE tiene_imagen = 1 AND sincronizado = 0'
      );
      final imagenesPendientes = imagenesPendientesResult.first['count'] as int;

      // Tamaño total aproximado de imágenes pendientes
      final tamanoTotalResult = await dbHelper.consultarPersonalizada(
          'SELECT SUM(imagen_tamano) as total FROM Estado_Equipo WHERE tiene_imagen = 1 AND sincronizado = 0'
      );
      final tamanoTotalPendiente = tamanoTotalResult.first['total'] as int? ?? 0;

      return {
        'total_con_imagenes': totalConImagenes,
        'imagenes_sincronizadas': imagenesSincronizadas,
        'imagenes_pendientes': imagenesPendientes,
        'tamano_total_pendiente_bytes': tamanoTotalPendiente,
        'tamano_total_pendiente_mb': (tamanoTotalPendiente / (1024 * 1024)).toStringAsFixed(2),
      };
    } catch (e) {
      _logger.e('❌ Error obteniendo estadísticas de imágenes: $e');
      return {
        'total_con_imagenes': 0,
        'imagenes_sincronizadas': 0,
        'imagenes_pendientes': 0,
        'tamano_total_pendiente_bytes': 0,
        'tamano_total_pendiente_mb': '0.00',
      };
    }
  }

  /// Marcar imagen como sincronizada y limpiar Base64
  Future<void> marcarImagenComoSincronizada(int estadoId, {dynamic servidorId}) async {
    try {
      final datosActualizacion = <String, dynamic>{
        'sincronizado': 1,
        'estado_censo': EstadoEquipoCenso.migrado.valor,
        'fecha_actualizacion': DateTime.now().toIso8601String(),
        'imagen_base64': null, // Limpiar Base64 inmediatamente después de envío exitoso
      };

      await dbHelper.actualizar(
        tableName,
        datosActualizacion,
        where: 'id = ?',
        whereArgs: [estadoId],
      );

      _logger.i('✅ Estado $estadoId marcado como sincronizado y Base64 limpiado');
    } catch (e) {
      _logger.e('❌ Error marcando imagen como sincronizada: $e');
      rethrow;
    }
  }

  /// Obtener solo la ruta de imagen (sin Base64 para ahorrar memoria)
  Future<String?> obtenerRutaImagen(int estadoId) async {
    try {
      final result = await dbHelper.consultar(
        tableName,
        where: 'id = ? AND tiene_imagen = 1',
        whereArgs: [estadoId],
      );

      return result.isNotEmpty ? result.first['imagen_path'] as String? : null;
    } catch (e) {
      _logger.e('❌ Error obteniendo ruta de imagen: $e');
      return null;
    }
  }

  /// Obtener último estado por equipo_pendiente_id (para equipos pendientes)
  Future<Map<String, dynamic>?> obtenerUltimoEstadoPorEquipoPendiente(int equipoPendienteId) async {
    try {
      final estado = await obtenerUltimoEstado(equipoPendienteId);
      return estado?.toMap();
    } catch (e) {
      _logger.e('Error obteniendo último estado por equipo pendiente: $e');
      return null;
    }
  }





  /// Validar integridad de datos de imagen
  Future<Map<String, dynamic>> validarIntegridadImagenes() async {
    try {
      // Buscar estados que dicen tener imagen pero no tienen datos
      final sinDatosResult = await dbHelper.consultarPersonalizada('''
      SELECT COUNT(*) as count FROM Estado_Equipo 
      WHERE tiene_imagen = 1 AND (imagen_path IS NULL OR imagen_path = '')
    ''');
      final sinDatos = sinDatosResult.first['count'] as int;

      // Buscar estados con Base64 pero sin flag de imagen
      final inconsistentesResult = await dbHelper.consultarPersonalizada('''
      SELECT COUNT(*) as count FROM Estado_Equipo 
      WHERE tiene_imagen = 0 AND imagen_base64 IS NOT NULL
    ''');
      final inconsistentes = inconsistentesResult.first['count'] as int;

      // Tamaño promedio de imágenes
      final promedioResult = await dbHelper.consultarPersonalizada('''
      SELECT AVG(imagen_tamano) as promedio FROM Estado_Equipo 
      WHERE tiene_imagen = 1 AND imagen_tamano IS NOT NULL
    ''');
      final tamanoPromedio = promedioResult.first['promedio'] as double? ?? 0.0;

      return {
        'estados_sin_datos': sinDatos,
        'estados_inconsistentes': inconsistentes,
        'tamano_promedio_mb': (tamanoPromedio / (1024 * 1024)).toStringAsFixed(2),
        'integridad_ok': sinDatos == 0 && inconsistentes == 0,
      };
    } catch (e) {
      _logger.e('❌ Error validando integridad de imágenes: $e');
      return {
        'estados_sin_datos': -1,
        'estados_inconsistentes': -1,
        'tamano_promedio_mb': '0.00',
        'integridad_ok': false,
        'error': e.toString(),
      };
    }
  }
  /// Método corregido para obtener historial por equipo y cliente
  Future<List<EstadoEquipo>> obtenerHistorialPorEquipoCliente(int equipoId, int clienteId) async {
    try {
      // Primero buscar el equipo_pendiente_id usando equipoId y clienteId
      final equipoPendienteId = await buscarEquipoPendienteId(equipoId, clienteId);

      if (equipoPendienteId == null) {
        _logger.w('No se encontró relación equipos_pendientes para equipoId: $equipoId, clienteId: $clienteId');
        return [];
      }

      // Usar el método existente que ya funciona correctamente
      return await obtenerHistorialCompleto(equipoPendienteId);

    } catch (e) {
      _logger.e('Error obteniendo historial por equipo-cliente: $e');
      return [];
    }
  }

  Future<EstadoEquipo> crearNuevoEstadoPorEquipoCliente({
    required String equipoId,  // CAMBIO: String en lugar de int
    required int clienteId,
    required bool enLocal,
    required DateTime fechaRevision,
    required double latitud,
    required double longitud,
  }) async {
    try {
      final result = await dbHelper.consultar(
        'equipos_pendientes',
        where: 'equipo_id = ? AND cliente_id = ?',
        whereArgs: [equipoId, clienteId],
        limit: 1,
      );

      final equipoPendienteId = result.isNotEmpty ? result.first['id'] as int? : null;

      if (equipoPendienteId == null) {
        throw Exception('No se encontró relación equipos_pendientes para equipoId: $equipoId, clienteId: $clienteId');
      }

      return await crearNuevoEstado(
        equipoPendienteId: equipoPendienteId,
        enLocal: enLocal,
        fechaRevision: fechaRevision,
        latitud: latitud,
        longitud: longitud,
      );

    } catch (e) {
      _logger.e('Error creando nuevo estado por equipo-cliente: $e');
      rethrow;
    }
  }

  /// Limpiar imágenes huérfanas (opcional - para mantenimiento)
  Future<int> limpiarImagenesHuerfanas() async {
    try {
      // Limpiar estados que dicen tener imagen pero no tienen datos válidos
      final resultado = await dbHelper.actualizar(
        tableName,
        {
          'tiene_imagen': 0,
          'imagen_path': null,
          'imagen_base64': null,
          'imagen_tamano': null,
          'fecha_actualizacion': DateTime.now().toIso8601String(),
        },
        where: 'tiene_imagen = 1 AND (imagen_path IS NULL OR imagen_path = "")',
      );

      if (resultado > 0) {
        _logger.i('🧹 Limpiadas $resultado imágenes huérfanas');
      }

      return resultado;
    } catch (e) {
      _logger.e('❌ Error limpiando imágenes huérfanas: $e');
      return 0;
    }
  }
}