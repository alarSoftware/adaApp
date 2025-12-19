import '../models/censo_activo.dart';
import 'base_repository.dart';

import 'package:uuid/uuid.dart';

class CensoActivoRepository extends BaseRepository<CensoActivo> {
  final Uuid _uuid = Uuid();

  @override
  String get tableName => 'censo_activo';

  @override
  CensoActivo fromMap(Map<String, dynamic> map) => CensoActivo.fromMap(map);

  @override
  Map<String, dynamic> toMap(CensoActivo estadoEquipo) => estadoEquipo.toMap();

  @override
  String getDefaultOrderBy() => 'fecha_revision DESC';

  @override
  String getBuscarWhere() => 'CAST(cliente_id AS TEXT) LIKE ?';

  @override
  List<dynamic> getBuscarArgs(String query) {
    final searchTerm = '%${query.toLowerCase()}%';
    return [searchTerm];
  }

  @override
  String getEntityName() => 'EstadoEquipo';

  // ========== MÉTODOS PRINCIPALES ==========

  /// Crear nuevo estado con GPS usando equipoId y clienteId
  Future<CensoActivo> crearCensoActivo({
    required String equipoId,
    required int clienteId,
    int? usuarioId,
    required bool enLocal,
    required DateTime fechaRevision,
    double? latitud,
    double? longitud,
    String? estadoCenso,
    String? observaciones,
    String? employeeId,
  }) async {
    try {
      final now = DateTime.now();
      final uuidId = _uuid.v4();
      final censoActivoData = {
        'id': uuidId,
        'equipo_id': equipoId,
        'cliente_id': clienteId,
        'usuario_id': usuarioId,
        'en_local': enLocal ? 1 : 0,
        'latitud': latitud,
        'longitud': longitud,
        'fecha_revision': fechaRevision.toIso8601String(),
        'fecha_creacion': now.toIso8601String(),
        'fecha_actualizacion': now.toIso8601String(),
        'estado_censo': EstadoEquipoCenso.creado.valor,
        'observaciones': observaciones,
        'employee_id': employeeId,
      };

      // 1. Usar await y no castear el resultado
      await dbHelper.insertar(tableName, censoActivoData);

      // 2. Recuperar usando el mismo UUID que generamos (sin crear nueva instancia de repo)
      CensoActivo? censoRecuperado = await obtenerCensoActivoById(uuidId);

      // 3. Validar que no sea null para cumplir con el retorno Future<CensoActivo>
      if (censoRecuperado == null) {
        throw Exception(
          "Error crítico: No se pudo recuperar el censo recién creado ($uuidId)",
        );
      }

      return censoRecuperado;
    } catch (e) {
      rethrow;
    }
  }

  /// Crear nuevo estado con imágenes - DEPRECADO: Usar crearCensoActivo() + CensoActivoFotoRepository
  // @Deprecated('Usar crearCensoActivo() y CensoActivoFotoRepository.guardarFoto() por separado')
  // Future<EstadoEquipo> crearNuevoEstadoConImagenes({
  //   required String equipoId,
  //   required int clienteId,
  //   int? usuarioId,  // ← Nuevo parámetro agregado
  //   required bool enLocal,
  //   required DateTime fechaRevision,
  //   double? latitud,
  //   double? longitud,
  //   String? estadoCenso,
  //   String? observaciones,
  //   // Primera imagen - DEPRECADO
  //   String? imagenPath,
  //   String? imagenBase64,
  //   bool tieneImagen = false,
  //   int? imagenTamano,
  //   // Segunda imagen - DEPRECADO
  //   String? imagenPath2,
  //   String? imagenBase64_2,
  //   bool tieneImagen2 = false,
  //   int? imagenTamano2,
  // }) async {
  //   try {
  //     _logger.w('⚠️ Método deprecado: crearNuevoEstadoConImagenes()');
  //     _logger.w('   Usar crearCensoActivo() + CensoActivoFotoRepository.guardarFoto()');
  //
  //     // Crear el estado sin imágenes
  //     final estado = await crearCensoActivo(
  //       equipoId: equipoId,
  //       clienteId: clienteId,
  //       usuarioId: usuarioId,  // ← Nuevo parámetro pasado
  //       enLocal: enLocal,
  //       fechaRevision: fechaRevision,
  //       latitud: latitud,
  //       longitud: longitud,
  //       estadoCenso: estadoCenso,
  //       observaciones: observaciones,
  //     );
  //
  //     // Log de advertencia para migrar imágenes manualmente
  //     if (tieneImagen || tieneImagen2) {
  //       _logger.w('⚠️ IMÁGENES DETECTADAS - Se necesita migración manual:');
  //       _logger.w('   Estado creado con ID: ${estado.id}');
  //       _logger.w('   Usar CensoActivoFotoRepository.guardarFoto() para guardar las imágenes');
  //       if (tieneImagen) _logger.w('   - Imagen 1: ${imagenTamano ?? 0} bytes');
  //       if (tieneImagen2) _logger.w('   - Imagen 2: ${imagenTamano2 ?? 0} bytes');
  //     }
  //
  //     return estado;
  //   } catch (e) {
  //     _logger.e('❌ Error creando nuevo estado con imágenes: $e');
  //     rethrow;
  //   }
  // }

  Future<CensoActivo?> obtenerCensoActivoById(String id) async {
    try {
      final maps = await dbHelper.consultar(
        tableName,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      return maps.isNotEmpty ? fromMap(maps.first) : null;
    } catch (e) {
      return null;
    }
  }

  /// Obtener último estado por equipo_id y cliente_id
  Future<CensoActivo?> obtenerUltimoEstado(
    String equipoId,
    int clienteId,
  ) async {
    try {
      final maps = await dbHelper.consultar(
        tableName,
        where: 'equipo_id = ? AND cliente_id = ?',
        whereArgs: [equipoId, clienteId],
        orderBy: 'fecha_revision DESC',
        limit: 1,
      );
      return maps.isNotEmpty ? fromMap(maps.first) : null;
    } catch (e) {
      return null;
    }
  }

  // ========== MÉTODOS DE CONSULTA ==========

  /// Obtener historial completo por equipo y cliente
  Future<List<CensoActivo>> obtenerHistorialCompleto(
    String equipoId,
    int clienteId,
  ) async {
    try {
      final maps = await dbHelper.consultar(
        tableName,
        where: 'equipo_id = ? AND cliente_id = ?',
        whereArgs: [equipoId, clienteId],
        orderBy: 'fecha_revision DESC',
      );
      return maps.map((map) => fromMap(map)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Obtener estados por usuario - NUEVO MÉTODO
  Future<List<CensoActivo>> obtenerPorUsuario(int usuarioId) async {
    try {
      final maps = await dbHelper.consultar(
        tableName,
        where: 'usuario_id = ?',
        whereArgs: [usuarioId],
        orderBy: getDefaultOrderBy(),
      );
      return maps.map((map) => fromMap(map)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Obtener estados creados (pendientes)
  Future<List<CensoActivo>> obtenerCreados() async {
    try {
      final maps = await dbHelper.consultar(
        tableName,
        where: 'estado_censo = ?',
        whereArgs: [EstadoEquipoCenso.creado.valor],
        orderBy: getDefaultOrderBy(),
      );
      return maps.map((map) => fromMap(map)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Obtener estados migrados
  Future<List<CensoActivo>> obtenerMigrados() async {
    try {
      final maps = await dbHelper.consultar(
        tableName,
        where: 'estado_censo = ?',
        whereArgs: [EstadoEquipoCenso.migrado.valor],
        orderBy: getDefaultOrderBy(),
      );
      return maps.map((map) => fromMap(map)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Obtener estados con error
  Future<List<CensoActivo>> obtenerConError() async {
    try {
      final maps = await dbHelper.consultar(
        tableName,
        where: 'estado_censo = ?',
        whereArgs: [EstadoEquipoCenso.error.valor],
        orderBy: getDefaultOrderBy(),
      );
      return maps.map((map) => fromMap(map)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<CensoActivo>> obtenerNoSincronizados() async {
    try {
      final maps = await dbHelper.consultar(
        tableName,
        where:
            'estado_censo IN (?, ?)', // <--- CAMBIO CLAVE: Buscar CREADO y ERROR
        whereArgs: [
          EstadoEquipoCenso.creado.valor,
          EstadoEquipoCenso.error.valor,
        ],
        orderBy: getDefaultOrderBy(),
      );

      return maps.map((map) => fromMap(map)).toList();
    } catch (e) {
      return [];
    }
  }

  // ========== MÉTODOS DE ACTUALIZACIÓN ==========

  /// Actualizar estado del censo
  Future<void> actualizarEstadoCenso(
    String estadoId,
    EstadoEquipoCenso nuevoEstado,
  ) async {
    try {
      await dbHelper.actualizar(
        tableName,
        {
          'estado_censo': nuevoEstado.valor,
          'fecha_actualizacion': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [estadoId],
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Actualizar usuario de un estado - NUEVO MÉTODO
  Future<void> actualizarUsuario(String estadoId, int? usuarioId) async {
    try {
      await dbHelper.actualizar(
        tableName,
        {
          'usuario_id': usuarioId,
          'fecha_actualizacion': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [estadoId],
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Marcar múltiples como sincronizados
  Future<void> marcarMultiplesComoSincronizados(List<String> estadoIds) async {
    try {
      final placeholders = estadoIds.map((_) => '?').join(',');
      await dbHelper.actualizar(
        tableName,
        {
          'estado_censo': EstadoEquipoCenso.migrado.valor,
          'fecha_actualizacion': DateTime.now().toIso8601String(),
        },
        where: 'id IN ($placeholders)',
        whereArgs: estadoIds,
      );
    } catch (e) {
      rethrow;
    }
  }

  // ========== MÉTODOS DE ESTADÍSTICAS ==========

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
      return {'creados': 0, 'migrados': 0, 'error': 0, 'total': 0};
    }
  }

  /// Contar registros por usuario - NUEVO MÉTODO
  Future<Map<String, int>> contarPorUsuario(int usuarioId) async {
    try {
      final maps = await dbHelper.consultar(
        tableName,
        where: 'usuario_id = ?',
        whereArgs: [usuarioId],
      );

      final estados = maps.map((map) => fromMap(map)).toList();
      final creados = estados.where((e) => e.estaCreado).length;
      final migrados = estados.where((e) => e.estaMigrado).length;
      final conError = estados.where((e) => e.tieneError).length;

      return {
        'creados': creados,
        'migrados': migrados,
        'error': conError,
        'total': estados.length,
      };
    } catch (e) {
      return {'creados': 0, 'migrados': 0, 'error': 0, 'total': 0};
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
      return {};
    }
  }

  /// Contar cambios por equipo_id y cliente_id
  Future<int> contarCambios(String equipoId, int clienteId) async {
    try {
      final result = await dbHelper.consultar(
        tableName,
        where: 'equipo_id = ? AND cliente_id = ?',
        whereArgs: [equipoId, clienteId],
      );
      return result.length;
    } catch (e) {
      return 0;
    }
  }

  /// Obtener estadísticas de cambios
  Future<Map<String, dynamic>> obtenerEstadisticasCambios(
    String equipoId,
    int clienteId,
  ) async {
    try {
      final historial = await obtenerHistorialCompleto(equipoId, clienteId);

      if (historial.isEmpty) {
        return {
          'total_cambios': 0,
          'ultimo_cambio': null,
          'estado_actual': null,
          'cambios_pendientes': 0,
        };
      }

      return {
        'total_cambios': historial.length,
        'ultimo_cambio': historial.first.fechaRevision,
        'estado_actual': historial.first.enLocal,
      };
    } catch (e) {
      return {
        'total_cambios': 0,
        'ultimo_cambio': null,
        'estado_actual': null,
        'cambios_pendientes': 0,
      };
    }
  }

  // ========== MÉTODOS UTILITARIOS ==========

  /// Preparar datos para sincronización
  Future<List<Map<String, dynamic>>> prepararDatosParaSincronizacion() async {
    try {
      final noSincronizados = await obtenerNoSincronizados();
      return noSincronizados.map((estado) => estado.toJson()).toList();
    } catch (e) {
      return [];
    }
  }

  /// Limpiar historial antiguo
  Future<void> limpiarHistorialAntiguo({int diasAntiguedad = 90}) async {
    try {
      final fechaLimite = DateTime.now().subtract(
        Duration(days: diasAntiguedad),
      );

      await dbHelper.eliminar(
        tableName,
        where: 'fecha_creacion < ? AND estado_censo = ?',
        whereArgs: [fechaLimite.toIso8601String(), 'migrado'],
      );
    } catch (e) {
      rethrow;
    }
  }

  // ========== MÉTODOS DE COMPATIBILIDAD CON VIEWMODELS EXISTENTES ==========

  /// Wrapper para compatibilidad con código que usa int equipoId
  Future<CensoActivo?> obtenerUltimoEstadoLegacy(
    int equipoId,
    int clienteId,
  ) async {
    return await obtenerUltimoEstado(equipoId.toString(), clienteId);
  }

  /// Wrapper para compatibilidad con ViewModel de detalle
  Future<List<CensoActivo>> obtenerHistorialDirectoPorEquipoCliente(
    String equipoId,
    int clienteId,
  ) async {
    return await obtenerHistorialCompleto(equipoId, clienteId);
  }

  /// Método para obtener último estado retornando Map (para iconos)
  Future<Map<String, dynamic>?> obtenerUltimoEstadoParaIcono(
    String equipoId,
    int clienteId,
  ) async {
    try {
      final estado = await obtenerUltimoEstado(equipoId, clienteId);
      return estado?.toMap();
    } catch (e) {
      return null;
    }
  }

  // ========== MÉTODOS PARA SYNC PANEL ==========

  /// Marcar registro como migrado exitosamente
  Future<void> marcarComoMigrado(String censoActivoId) async {
    try {
      await dbHelper.actualizar(
        tableName,
        {
          'estado_censo': EstadoEquipoCenso.migrado.valor,
          'fecha_actualizacion': DateTime.now().toIso8601String(),
          'error_mensaje': null,
        },
        where: 'id = ?',
        whereArgs: [censoActivoId],
      );
    } catch (e) {
      throw Exception('Error en Marcar como Migrado: $e');
    }
  }

  /// Marcar registro con error de sincronización
  Future<void> marcarComoError(String estadoId, String mensajeError) async {
    try {
      await dbHelper.actualizar(
        tableName,
        {
          'estado_censo': EstadoEquipoCenso.error.valor,
          'fecha_actualizacion': DateTime.now().toIso8601String(),
          'error_mensaje': mensajeError,
        },
        where: 'id = ?',
        whereArgs: [estadoId],
      );
    } catch (e) {
      rethrow;
    }
  }
}
