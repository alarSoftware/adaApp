import '../models/censo_activo.dart';
import 'base_repository.dart';
import 'package:logger/logger.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';

class EstadoEquipoRepository extends BaseRepository<EstadoEquipo> {
  final Logger _logger = Logger();
  final Uuid _uuid = Uuid();

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
    int? usuarioId,  // ← Nuevo parámetro agregado
    required bool enLocal,
    required DateTime fechaRevision,
    double? latitud,
    double? longitud,
    String? estadoCenso,
    String? observaciones,
  }) async {
    try {
      final now = DateTime.now();
      final uuidId = _uuid.v4();

      _logger.i('📝 Creando nuevo estado en BD local');
      _logger.i('   UUID (id): $uuidId');
      _logger.i('   Equipo ID: $equipoId');
      _logger.i('   Cliente ID: $clienteId');
      _logger.i('   Usuario ID: $usuarioId');  // ← Nuevo log

      final datosEstado = {
        'id': uuidId,
        'equipo_id': equipoId,
        'cliente_id': clienteId,
        'usuario_id': usuarioId,  // ← Nuevo campo agregado
        'en_local': enLocal ? 1 : 0,
        'latitud': latitud,
        'longitud': longitud,
        'fecha_revision': fechaRevision.toIso8601String(),
        'fecha_creacion': now.toIso8601String(),
        'fecha_actualizacion': now.toIso8601String(),
        'sincronizado': 0,
        'estado_censo': estadoCenso ?? EstadoEquipoCenso.creado.valor,
        'observaciones': observaciones,
      };

      await dbHelper.insertar(tableName, datosEstado);

      _logger.i('✅ Estado insertado en BD con UUID: $uuidId');

      return EstadoEquipo(
        id: uuidId,
        equipoId: equipoId,
        clienteId: clienteId,
        usuarioId: usuarioId,  // ← Nuevo campo agregado
        enLocal: enLocal,
        latitud: latitud,
        longitud: longitud,
        fechaRevision: fechaRevision,
        fechaCreacion: now,
        fechaActualizacion: now,
        estaSincronizado: false,
        estadoCenso: estadoCenso ?? EstadoEquipoCenso.creado.valor,
        observaciones: observaciones,
      );
    } catch (e) {
      _logger.e('❌ Error creando nuevo estado: $e');
      rethrow;
    }
  }

  /// Crear nuevo estado con imágenes - DEPRECADO: Usar crearNuevoEstado() + CensoActivoFotoRepository
  @Deprecated('Usar crearNuevoEstado() y CensoActivoFotoRepository.guardarFoto() por separado')
  Future<EstadoEquipo> crearNuevoEstadoConImagenes({
    required String equipoId,
    required int clienteId,
    int? usuarioId,  // ← Nuevo parámetro agregado
    required bool enLocal,
    required DateTime fechaRevision,
    double? latitud,
    double? longitud,
    String? estadoCenso,
    String? observaciones,
    // Primera imagen - DEPRECADO
    String? imagenPath,
    String? imagenBase64,
    bool tieneImagen = false,
    int? imagenTamano,
    // Segunda imagen - DEPRECADO
    String? imagenPath2,
    String? imagenBase64_2,
    bool tieneImagen2 = false,
    int? imagenTamano2,
  }) async {
    try {
      _logger.w('⚠️ Método deprecado: crearNuevoEstadoConImagenes()');
      _logger.w('   Usar crearNuevoEstado() + CensoActivoFotoRepository.guardarFoto()');

      // Crear el estado sin imágenes
      final estado = await crearNuevoEstado(
        equipoId: equipoId,
        clienteId: clienteId,
        usuarioId: usuarioId,  // ← Nuevo parámetro pasado
        enLocal: enLocal,
        fechaRevision: fechaRevision,
        latitud: latitud,
        longitud: longitud,
        estadoCenso: estadoCenso,
        observaciones: observaciones,
      );

      // Log de advertencia para migrar imágenes manualmente
      if (tieneImagen || tieneImagen2) {
        _logger.w('⚠️ IMÁGENES DETECTADAS - Se necesita migración manual:');
        _logger.w('   Estado creado con ID: ${estado.id}');
        _logger.w('   Usar CensoActivoFotoRepository.guardarFoto() para guardar las imágenes');
        if (tieneImagen) _logger.w('   - Imagen 1: ${imagenTamano ?? 0} bytes');
        if (tieneImagen2) _logger.w('   - Imagen 2: ${imagenTamano2 ?? 0} bytes');
      }

      return estado;
    } catch (e) {
      _logger.e('❌ Error creando nuevo estado con imágenes: $e');
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
          _logger.i('📦 Procesando censo: ${censo['id']}');

          // Extraer identificadores
          final equipoId = censo['equipoId']?.toString() ?? censo['edfEquipoId']?.toString() ?? '';
          final clienteId = censo['clienteId'] ?? censo['edfClienteId'] ?? 0;

          // Obtener usuario_id de manera flexible
          final usuarioId = await _obtenerUsuarioIdFlexible(censo);

          final fechaRevision = censo['fechaRevision'] ?? censo['fechaDeRevision'];

          // Verificar si ya existe
          final existente = await dbHelper.consultar(
            tableName,
            where: 'equipo_id = ? AND cliente_id = ? AND fecha_revision = ?',
            whereArgs: [equipoId, clienteId, fechaRevision],
            limit: 1,
          );

          if (existente.isNotEmpty) {
            _logger.i('⏭️ Censo ya existe - Omitiendo');
            continue;
          }

          // Extraer observaciones del datosJson
          String? observacionesExtraidas = _extraerObservacionesDeJson(censo);

          _logger.i('📝 Observaciones extraídas: $observacionesExtraidas');
          _logger.i('👤 Usuario ID resuelto: $usuarioId');

          // Generar UUID si no viene del servidor
          final idCenso = censo['id']?.toString() ?? _uuid.v4();

          // Mapear campos del servidor a estructura local
          final datosLocal = {
            'id': idCenso,
            'equipo_id': equipoId,
            'cliente_id': clienteId,
            'usuario_id': usuarioId,
            'en_local': (censo['enLocal'] == true || censo['enLocal'] == 1) ? 1 : 0,
            'latitud': censo['latitud'],
            'longitud': censo['longitud'],
            'fecha_revision': fechaRevision ?? DateTime.now().toIso8601String(),
            'fecha_creacion': DateTime.now().toIso8601String(),
            'fecha_actualizacion': DateTime.now().toIso8601String(),
            'sincronizado': 1,
            'estado_censo': 'migrado',
            'observaciones': observacionesExtraidas,
          };

          await dbHelper.insertar(tableName, datosLocal);
          guardados++;
          _logger.i('✅ Censo insertado con UUID: $idCenso');

        } catch (e) {
          _logger.w('Error guardando censo individual: $e');
        }
      }

      _logger.i('✅ Censos guardados: $guardados de ${censosServidor.length}');
      return guardados;

    } catch (e) {
      _logger.e('❌ Error guardando censos: $e');
      return guardados;
    }
  }

  /// Método helper para obtener usuario_id desde edfvendedorid
  Future<int?> _obtenerUsuarioIdFlexible(Map<String, dynamic> censo) async {
    try {
      // Obtener edfvendedorid que siempre viene del POST (o null)
      final edfVendedorId = censo['edfvendedorid']?.toString();

      if (edfVendedorId == null || edfVendedorId.isEmpty) {
        _logger.i('👤 No se envió edfvendedorid - usuario_id será null');
        return null;
      }

      _logger.i('🔍 Buscando usuario por edfvendedorid: $edfVendedorId');

      // Consultar tabla Users para obtener el usuario_id
      final usuarioEncontrado = await dbHelper.consultar(
        'Users',
        where: 'edf_vendedor_id = ?',
        whereArgs: [edfVendedorId],
        limit: 1,
      );

      if (usuarioEncontrado.isNotEmpty) {
        final usuarioId = usuarioEncontrado.first['id'] as int?;
        _logger.i('✅ Usuario encontrado: edfvendedorid=$edfVendedorId → usuario_id=$usuarioId');
        return usuarioId;
      } else {
        _logger.w('⚠️ No se encontró usuario con edfvendedorid: $edfVendedorId');
        return null;
      }

    } catch (e) {
      _logger.e('❌ Error resolviendo usuario_id desde edfvendedorid: $e');
      return null;
    }
  }

  // Método helper para extraer observaciones
  String? _extraerObservacionesDeJson(Map<String, dynamic> censo) {
    try {
      // Intentar campo directo primero
      if (censo['observaciones'] != null && censo['observaciones'].toString().isNotEmpty) {
        return censo['observaciones'].toString();
      }

      // Extraer de datosJson
      final datosJson = censo['datosJson'] ?? censo['datos_json'];
      if (datosJson != null && datosJson is String && datosJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(datosJson);
          final obs = decoded['observaciones'];
          if (obs != null && obs.toString().isNotEmpty) {
            return obs.toString();
          }
        } catch (e) {
          _logger.w('Error decodificando datosJson: $e');
        }
      }

      return null;
    } catch (e) {
      _logger.w('Error extrayendo observaciones: $e');
      return null;
    }
  }

  // Método helper para parsear booleanos
  int _parsearBoolean(dynamic valor) {
    if (valor == null) return 0;
    if (valor is bool) return valor ? 1 : 0;
    if (valor is int) return valor;
    if (valor is String) {
      final lower = valor.toLowerCase();
      return (lower == 'true' || lower == '1') ? 1 : 0;
    }
    return 0;
  }

  // ========== MÉTODOS DE CONSULTA ==========

  /// Obtener historial completo por equipo y cliente
  Future<List<EstadoEquipo>> obtenerHistorialCompleto(String equipoId, int clienteId) async {
    try {
      final maps = await dbHelper.consultar(
        tableName,
        where: 'equipo_id = ? AND cliente_id = ?',
        whereArgs: [equipoId, clienteId],
        orderBy: 'fecha_revision DESC',
      );
      return maps.map((map) => fromMap(map)).toList();
    } catch (e) {
      _logger.e('Error al obtener historial completo: $e');
      return [];
    }
  }

  /// Obtener estados por usuario - NUEVO MÉTODO
  Future<List<EstadoEquipo>> obtenerPorUsuario(int usuarioId) async {
    try {
      final maps = await dbHelper.consultar(
        tableName,
        where: 'usuario_id = ?',
        whereArgs: [usuarioId],
        orderBy: getDefaultOrderBy(),
      );
      return maps.map((map) => fromMap(map)).toList();
    } catch (e) {
      _logger.e('Error al obtener estados por usuario: $e');
      return [];
    }
  }

  /// Obtener estados creados (pendientes)
  Future<List<EstadoEquipo>> obtenerCreados() async {
    try {
      final maps = await dbHelper.consultar(
        tableName,
        where: 'estado_censo = ?',
        whereArgs: [EstadoEquipoCenso.creado.valor],
        orderBy: getDefaultOrderBy(),
      );
      return maps.map((map) => fromMap(map)).toList();
    } catch (e) {
      _logger.e('Error al obtener estados creados: $e');
      return [];
    }
  }

  /// Obtener estados migrados
  Future<List<EstadoEquipo>> obtenerMigrados() async {
    try {
      final maps = await dbHelper.consultar(
        tableName,
        where: 'estado_censo = ?',
        whereArgs: [EstadoEquipoCenso.migrado.valor],
        orderBy: getDefaultOrderBy(),
      );
      return maps.map((map) => fromMap(map)).toList();
    } catch (e) {
      _logger.e('Error al obtener estados migrados: $e');
      return [];
    }
  }

  /// Obtener estados con error
  Future<List<EstadoEquipo>> obtenerConError() async {
    try {
      final maps = await dbHelper.consultar(
        tableName,
        where: 'estado_censo = ?',
        whereArgs: [EstadoEquipoCenso.error.valor],
        orderBy: getDefaultOrderBy(),
      );
      return maps.map((map) => fromMap(map)).toList();
    } catch (e) {
      _logger.e('Error al obtener estados con error: $e');
      return [];
    }
  }

  /// Obtener no sincronizados
  Future<List<EstadoEquipo>> obtenerNoSincronizados() async {
    try {
      final maps = await dbHelper.consultar(
        tableName,
        where: 'sincronizado = ?',
        whereArgs: [0],
        orderBy: getDefaultOrderBy(),
      );
      return maps.map((map) => fromMap(map)).toList();
    } catch (e) {
      _logger.e('Error al obtener no sincronizados: $e');
      return [];
    }
  }

  // ========== MÉTODOS DE ACTUALIZACIÓN ==========

  /// Actualizar estado del censo
  Future<void> actualizarEstadoCenso(String estadoId, EstadoEquipoCenso nuevoEstado) async {
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
      _logger.i('Estado $estadoId actualizado a ${nuevoEstado.valor}');
    } catch (e) {
      _logger.e('Error al actualizar estado del censo: $e');
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
      _logger.i('Usuario actualizado en estado $estadoId: $usuarioId');
    } catch (e) {
      _logger.e('Error al actualizar usuario del estado: $e');
      rethrow;
    }
  }

  /// Marcar como sincronizado
  Future<void> marcarComoSincronizado(String estadoId) async {
    try {
      await dbHelper.actualizar(
        tableName,
        {
          'sincronizado': 1,
          'estado_censo': EstadoEquipoCenso.migrado.valor,
          'fecha_actualizacion': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [estadoId],
      );
      _logger.i('Estado $estadoId marcado como sincronizado');
    } catch (e) {
      _logger.e('Error al marcar como sincronizado: $e');
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
          'sincronizado': 1,
          'estado_censo': EstadoEquipoCenso.migrado.valor,
          'fecha_actualizacion': DateTime.now().toIso8601String(),
        },
        where: 'id IN ($placeholders)',
        whereArgs: estadoIds,
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
      _logger.e('Error contando por usuario: $e');
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

  // ========== MÉTODOS PARA SYNC PANEL ==========

  /// Marcar registro como migrado exitosamente
  Future<void> marcarComoMigrado(String estadoId, {dynamic servidorId}) async {
    try {
      await dbHelper.actualizar(
        tableName,
        {
          'sincronizado': 1,
          'estado_censo': EstadoEquipoCenso.migrado.valor,
          'fecha_actualizacion': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [estadoId],
      );
      _logger.i('Estado $estadoId marcado como migrado exitosamente');
    } catch (e) {
      _logger.e('Error al marcar como migrado: $e');
      rethrow;
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
        },
        where: 'id = ?',
        whereArgs: [estadoId],
      );
      _logger.i('Estado $estadoId marcado con error: $mensajeError');
    } catch (e) {
      _logger.e('Error al marcar como error: $e');
      rethrow;
    }
  }

  // ========== MÉTODOS DE COMPATIBILIDAD PARA IMÁGENES (DURANTE TRANSICIÓN) ==========

  /// Obtener estados con imágenes pendientes - DEPRECADO: Usar CensoActivoFotoRepository
  @Deprecated('Usar CensoActivoFotoRepository.obtenerFotosPendientes() en su lugar')
  Future<List<EstadoEquipo>> obtenerEstadosConImagenesPendientes() async {
    try {
      _logger.w('⚠️ Método deprecado: obtenerEstadosConImagenesPendientes()');
      _logger.w('   Usar CensoActivoFotoRepository.obtenerFotosPendientes() en su lugar');

      // Por compatibilidad, retornar lista vacía
      return [];
    } catch (e) {
      _logger.e('Error en método deprecado: $e');
      return [];
    }
  }

  /// Marcar imagen como sincronizada - DEPRECADO: Usar CensoActivoFotoRepository
  @Deprecated('Usar CensoActivoFotoRepository.marcarComoSincronizada() en su lugar')
  Future<void> marcarImagenComoSincronizada(String estadoId, {dynamic servidorId}) async {
    try {
      _logger.w('⚠️ Método deprecado: marcarImagenComoSincronizada()');
      _logger.w('   Usar CensoActivoFotoRepository.marcarComoSincronizada() en su lugar');

      // Solo marcar el censo como sincronizado, sin tocar imágenes
      await marcarComoSincronizado(estadoId);
    } catch (e) {
      _logger.e('Error en método deprecado: $e');
      rethrow;
    }
  }

  /// Limpiar Base64 después de sincronización - DEPRECADO: Usar CensoActivoFotoRepository
  @Deprecated('Usar CensoActivoFotoRepository.marcarComoSincronizada() en su lugar')
  Future<void> limpiarBase64DespuesDeSincronizacion(String estadoId) async {
    try {
      _logger.w('⚠️ Método deprecado: limpiarBase64DespuesDeSincronizacion()');
      _logger.w('   Usar CensoActivoFotoRepository.marcarComoSincronizada() en su lugar');

      // No hacer nada, las imágenes están en otra tabla
    } catch (e) {
      _logger.e('Error en método deprecado: $e');
      rethrow;
    }
  }
}