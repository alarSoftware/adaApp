import '../models/censo_activo.dart';
import 'base_repository.dart';
import 'package:logger/logger.dart';

class EstadoEquipoRepository extends BaseRepository<EstadoEquipo> {
  final Logger _logger = Logger();

  @override
  String get tableName => 'censo_activo';

  @override
  EstadoEquipo fromMap(Map<String, dynamic> map) => EstadoEquipo.fromMap(map);

  @override
  Map<String, dynamic> toMap(EstadoEquipo estadoEquipo) => estadoEquipo.toMap();

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
  Future<EstadoEquipo> crearNuevoEstado({
    required String equipoId,
    required int clienteId,
    required bool enLocal,
    required DateTime fechaRevision,
    double? latitud,
    double? longitud,
    String? estadoCenso,
    String? observaciones,
    // Primera imagen
    String? imagenPath,
    String? imagenBase64,
    bool tieneImagen = false,
    int? imagenTamano,
    // Segunda imagen
    String? imagenPath2,
    String? imagenBase64_2,
    bool tieneImagen2 = false,
    int? imagenTamano2,
  }) async {
    try {
      final now = DateTime.now();

      final datosEstado = {
        'equipo_id': equipoId,
        'cliente_id': clienteId,
        'en_local': enLocal ? 1 : 0,
        'latitud': latitud,
        'longitud': longitud,
        'fecha_revision': fechaRevision.toIso8601String(),
        'fecha_creacion': now.toIso8601String(),
        'fecha_actualizacion': now.toIso8601String(),
        'sincronizado': 0,
        'estado_censo': estadoCenso ?? EstadoEquipoCenso.creado.valor,
        'observaciones': observaciones,
        // Primera imagen
        'imagen_path': imagenPath,
        'imagen_base64': imagenBase64,
        'tiene_imagen': tieneImagen ? 1 : 0,
        'imagen_tamano': imagenTamano,
        // Segunda imagen
        'imagen_path2': imagenPath2,
        'imagen_base64_2': imagenBase64_2,
        'tiene_imagen2': tieneImagen2 ? 1 : 0,
        'imagen_tamano2': imagenTamano2,
      };

      final id = await dbHelper.insertar(tableName, datosEstado);

      _logger.i('Estado CREADO para equipo: $equipoId, cliente: $clienteId (ID: $id)');

      return EstadoEquipo(
        id: id,
        equipoId: equipoId,
        clienteId: clienteId,
        enLocal: enLocal,
        latitud: latitud,
        longitud: longitud,
        fechaRevision: fechaRevision,
        fechaCreacion: now,
        fechaActualizacion: now,
        estaSincronizado: false,
        estadoCenso: estadoCenso ?? EstadoEquipoCenso.creado.valor,
        observaciones: observaciones,
        // Primera imagen
        imagenPath: imagenPath,
        imagenBase64: imagenBase64,
        tieneImagen: tieneImagen,
        imagenTamano: imagenTamano,
        // Segunda imagen
        imagenPath2: imagenPath2,
        imagenBase64_2: imagenBase64_2,
        tieneImagen2: tieneImagen2,
        imagenTamano2: imagenTamano2,
      );
    } catch (e) {
      _logger.e('Error creando nuevo estado: $e');
      rethrow;
    }
  }

  /// Obtener último estado por equipo_id y cliente_id
  Future<EstadoEquipo?> obtenerUltimoEstado(String equipoId, int clienteId) async {
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
      _logger.e('Error al obtener último estado: $e');
      return null;
    }
  }

  /// Guardar censos desde el servidor en la base de datos local
  Future<int> guardarCensosDesdeServidor(List<Map<String, dynamic>> censosServidor) async {
    int guardados = 0;

    try {
      for (final censo in censosServidor) {
        try {
          // Mapear campos del servidor a estructura local
          final datosLocal = {
            'equipo_id': censo['equipoId']?.toString() ?? censo['edfEquipoId']?.toString() ?? '',
            'cliente_id': censo['clienteId'] ?? censo['edfClienteId'] ?? 0,
            'en_local': (censo['enLocal'] == true || censo['enLocal'] == 1) ? 1 : 0,
            'latitud': censo['latitud'],
            'longitud': censo['longitud'],
            'fecha_revision': censo['fechaRevision'] ?? censo['fechaDeRevision'] ?? DateTime.now().toIso8601String(),
            'fecha_creacion': DateTime.now().toIso8601String(),
            'fecha_actualizacion': DateTime.now().toIso8601String(),
            'sincronizado': 1, // Viene del servidor, ya está sincronizado
            'estado_censo': 'migrado', // Censos del servidor están migrados
            'observaciones': censo['observaciones'],
          };

          await dbHelper.insertar(tableName, datosLocal);
          guardados++;

        } catch (e) {
          _logger.w('Error guardando censo individual: $e');
          // Continuar con el siguiente
        }
      }

      _logger.i('✅ Censos guardados en local: $guardados de ${censosServidor.length}');
      return guardados;

    } catch (e) {
      _logger.e('❌ Error guardando censos desde servidor: $e');
      return guardados;
    }
  }

  /// Obtener historial completo por equipo_id y cliente_id
  Future<List<EstadoEquipo>> obtenerHistorialCompleto(String equipoId, int clienteId) async {
    try {
      final maps = await dbHelper.consultar(
        tableName,
        where: 'equipo_id = ? AND cliente_id = ?',
        whereArgs: [equipoId, clienteId],
        orderBy: 'fecha_revision DESC',
      );

      print('🔍 Datos raw de BD: ${maps.length} registros');
      for (int i = 0; i < maps.length && i < 2; i++) {
        print('Registro $i: ${maps[i]}');
      }

      List<EstadoEquipo> resultado = [];
      for (int i = 0; i < maps.length; i++) {
        try {
          final estado = fromMap(maps[i]);
          resultado.add(estado);
          print('✅ Registro $i mapeado correctamente');
        } catch (e) {
          print('❌ Error mapeando registro $i: $e');
          print('   Datos del registro: ${maps[i]}');
        }
      }

      print('🔧 Después del mapeo: ${resultado.length} estados');
      return resultado;

    } catch (e) {
      _logger.e('Error al obtener historial completo: $e');
      return [];
    }
  }
  /// Obtener últimos N cambios por equipo_id y cliente_id
  Future<List<EstadoEquipo>> obtenerUltimosCambios(String equipoId, int clienteId, {int limite = 5}) async {
    try {
      final maps = await dbHelper.consultar(
        tableName,
        where: 'equipo_id = ? AND cliente_id = ?',
        whereArgs: [equipoId, clienteId],
        orderBy: 'fecha_revision DESC',
        limit: limite,
      );
      return maps.map((map) => fromMap(map)).toList();
    } catch (e) {
      _logger.e('Error al obtener últimos cambios: $e');
      return [];
    }
  }

  // ========== MÉTODOS PARA MANEJO DE ESTADOS DE CENSO ==========

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
        _logger.i('Estado $estadoId marcado como MIGRADO');
        return true;
      } else {
        _logger.w('No se encontró el estado $estadoId para marcar como migrado');
        return false;
      }
    } catch (e) {
      _logger.e('Error marcando como migrado: $e');
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
        _logger.e('Estado $estadoId marcado como ERROR: $mensajeError');
        return true;
      } else {
        _logger.w('No se encontró el estado $estadoId para marcar como error');
        return false;
      }
    } catch (e) {
      _logger.e('Error marcando como error: $e');
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

      _logger.i('Estado $estadoId preparado para reintento de migración');
    } catch (e) {
      _logger.e('Error preparando reintento: $e');
      rethrow;
    }
  }

  // ========== MÉTODOS PARA SINCRONIZACIÓN ==========

  /// Obtener registros no sincronizados
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
      _logger.e('Error al contar cambios: $e');
      return 0;
    }
  }

  /// Obtener estadísticas de cambios
  Future<Map<String, dynamic>> obtenerEstadisticasCambios(String equipoId, int clienteId) async {
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

  // ========== MÉTODOS PARA IMÁGENES ==========

  /// Obtener estados con imágenes pendientes de sincronización
  Future<List<EstadoEquipo>> obtenerEstadosConImagenesPendientes() async {
    try {
      final maps = await dbHelper.consultar(
        tableName,
        where: 'tiene_imagen = 1 AND sincronizado = 0 AND imagen_base64 IS NOT NULL',
        orderBy: 'fecha_creacion ASC',
      );

      final estados = maps.map((map) => fromMap(map)).toList();
      _logger.i('Encontrados ${estados.length} estados con imágenes pendientes');
      return estados;
    } catch (e) {
      _logger.e('Error obteniendo estados con imágenes pendientes: $e');
      return [];
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
        'imagen_base64_2': null, // También limpiar segunda imagen si existe
      };

      await dbHelper.actualizar(
        tableName,
        datosActualizacion,
        where: 'id = ?',
        whereArgs: [estadoId],
      );

      _logger.i('Estado $estadoId marcado como sincronizado y Base64 limpiado');
    } catch (e) {
      _logger.e('Error marcando imagen como sincronizada: $e');
      rethrow;
    }
  }

  /// Limpiar Base64 después de sincronización exitosa (para ahorrar espacio)
  Future<void> limpiarBase64DespuesDeSincronizacion(int estadoId) async {
    try {
      final datosActualizacion = <String, dynamic>{
        'imagen_base64': null, // Limpiar Base64 para ahorrar espacio
        'imagen_base64_2': null, // También segunda imagen
        'fecha_actualizacion': DateTime.now().toIso8601String(),
      };

      await dbHelper.actualizar(
        tableName,
        datosActualizacion,
        where: 'id = ? AND sincronizado = 1', // Solo si ya está sincronizado
        whereArgs: [estadoId],
      );

      _logger.i('Base64 limpiado para estado $estadoId (ya sincronizado)');
    } catch (e) {
      _logger.e('Error limpiando Base64: $e');
      rethrow;
    }
  }

  // ========== MÉTODOS UTILITARIOS ==========

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

  // ========== MÉTODOS DE COMPATIBILIDAD CON VIEWMODELS EXISTENTES ==========

  /// Wrapper para compatibilidad con código que usa int equipoId
  Future<EstadoEquipo?> obtenerUltimoEstadoLegacy(int equipoId, int clienteId) async {
    return await obtenerUltimoEstado(equipoId.toString(), clienteId);
  }

  /// Wrapper para compatibilidad con ViewModel de detalle
  Future<List<EstadoEquipo>> obtenerHistorialDirectoPorEquipoCliente(String equipoId, int clienteId) async {
    return await obtenerHistorialCompleto(equipoId, clienteId);
  }

  /// Método para obtener último estado retornando Map (para iconos)
  Future<Map<String, dynamic>?> obtenerUltimoEstadoParaIcono(String equipoId, int clienteId) async {
    try {
      final estado = await obtenerUltimoEstado(equipoId, clienteId);
      return estado?.toMap();
    } catch (e) {
      _logger.e('Error obteniendo último estado para icono: $e');
      return null;
    }
  }
}