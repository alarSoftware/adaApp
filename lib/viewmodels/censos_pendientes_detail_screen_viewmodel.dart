import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:ada_app/services/database_helper.dart';
import 'package:ada_app/services/post/censo_activo_post_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';

/// Estados de carga para el ViewModel
enum CensosLoadingState {
  initial,
  loading,
  loaded,
  error,
  retrying,
}

/// Modelo para representar un censo fallido
class CensoFallido {
  final String id;
  final String? equipoId;
  final String? codigoBarras;
  final int? clienteId;
  final String? clienteNombre;
  final String? marcaNombre;
  final String? modeloNombre;
  final bool enLocal;
  final double? latitud;
  final double? longitud;
  final String? observaciones;
  final DateTime? fechaCreacion;
  final DateTime? fechaActualizacion;
  final int intentosSync;
  final DateTime? ultimoIntento;
  final String? errorMensaje;
  final int fotosCount;
  final String? estadoCenso;
  final int sincronizado;

  CensoFallido({
    required this.id,
    this.equipoId,
    this.codigoBarras,
    this.clienteId,
    this.clienteNombre,
    this.marcaNombre,
    this.modeloNombre,
    this.enLocal = false,
    this.latitud,
    this.longitud,
    this.observaciones,
    this.fechaCreacion,
    this.fechaActualizacion,
    this.intentosSync = 0,
    this.ultimoIntento,
    this.errorMensaje,
    this.fotosCount = 0,
    this.estadoCenso,
    this.sincronizado = 0,
  });

  factory CensoFallido.fromMap(Map<String, dynamic> map) {
    return CensoFallido(
      id: map['id'] as String,
      equipoId: map['equipo_id']?.toString(),
      codigoBarras: map['cod_barras']?.toString(),
      clienteId: map['cliente_id'] as int?,
      clienteNombre: map['cliente_nombre']?.toString(),
      marcaNombre: map['marca_nombre']?.toString(),
      modeloNombre: map['modelo_nombre']?.toString(),
      enLocal: (map['en_local'] as int?) == 1,
      latitud: (map['latitud'] as num?)?.toDouble(),
      longitud: (map['longitud'] as num?)?.toDouble(),
      observaciones: map['observaciones']?.toString(),
      fechaCreacion: map['fecha_creacion'] != null
          ? DateTime.tryParse(map['fecha_creacion'])
          : null,
      fechaActualizacion: map['fecha_actualizacion'] != null
          ? DateTime.tryParse(map['fecha_actualizacion'])
          : null,
      intentosSync: map['intentos_sync'] as int? ?? 0,
      ultimoIntento: map['ultimo_intento'] != null
          ? DateTime.tryParse(map['ultimo_intento'])
          : null,
      errorMensaje: map['error_mensaje']?.toString(),
      fotosCount: map['fotos_count'] as int? ?? 0,
      estadoCenso: map['estado_censo']?.toString(),
      sincronizado: map['sincronizado'] as int? ?? 0,
    );
  }

  String get equipoNombre {
    final nombre = '${marcaNombre ?? ''} ${modeloNombre ?? ''}'.trim();
    return nombre.isNotEmpty ? nombre : 'Equipo sin datos';
  }

  String get estadoDescripcion {
    if (sincronizado == 1) return 'Sincronizado';
    if (estadoCenso == 'error') return 'Error';
    if (estadoCenso == 'creado') return 'Pendiente';
    return 'Desconocido';
  }

  bool get puedeReintentar {
    // No reintentar si ya está sincronizado
    if (sincronizado == 1) return false;

    // Si no tiene intentos previos, siempre puede reintentar
    if (intentosSync == 0) return true;

    // Si tiene último intento, verificar tiempo de espera
    if (ultimoIntento != null) {
      final minutosEspera = _calcularEsperaMinutos(intentosSync);
      final proximoIntento = ultimoIntento!.add(Duration(minutes: minutosEspera));
      return DateTime.now().isAfter(proximoIntento);
    }

    return true;
  }

  int _calcularEsperaMinutos(int intentos) {
    switch (intentos) {
      case 0: return 0;
      case 1: return 1;
      case 2: return 5;
      case 3: return 10;
      default: return 30;
    }
  }
}

/// Resultado de operación de sincronización
class SyncResult {
  final bool success;
  final String? message;
  final String? error;
  final int? exitosos;
  final int? fallidos;

  SyncResult({
    required this.success,
    this.message,
    this.error,
    this.exitosos,
    this.fallidos,
  });

  factory SyncResult.fromMap(Map<String, dynamic> map) {
    return SyncResult(
      success: map['success'] == true,
      message: map['message']?.toString(),
      error: map['error']?.toString(),
      exitosos: map['exitosos'] as int?,
      fallidos: map['fallidos'] as int?,
    );
  }
}

/// ViewModel para la pantalla de Censos Pendientes Detail
class CensosPendientesDetailViewModel extends ChangeNotifier {
  final Logger _logger = Logger();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Estado
  CensosLoadingState _state = CensosLoadingState.initial;
  List<CensoFallido> _censos = [];
  String? _errorMessage;
  String? _retryingCensoId;

  // Getters
  CensosLoadingState get state => _state;
  List<CensoFallido> get censos => _censos;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == CensosLoadingState.loading;
  bool get isRetrying => _state == CensosLoadingState.retrying;
  bool get hasError => _state == CensosLoadingState.error;
  bool get isEmpty => _censos.isEmpty && _state == CensosLoadingState.loaded;
  int get totalCensos => _censos.length;

  /// Carga la lista de censos pendientes
  Future<void> loadCensosPendientes() async {
    _setState(CensosLoadingState.loading);
    _errorMessage = null;

    try {
      _logger.i('🔍 Cargando censos pendientes desde BD...');

      final db = await _dbHelper.database;
      final result = await _getCensosPendientesFromDB(db);

      _censos = result.map((map) => CensoFallido.fromMap(map)).toList();

      _logger.i('✅ Censos pendientes cargados: ${_censos.length}');
      _logger.i('   - Con error (estado_censo = error): ${_censos.where((c) => c.estadoCenso == 'error').length}');
      _logger.i('   - Creados (estado_censo = creado): ${_censos.where((c) => c.estadoCenso == 'creado').length}');
      _logger.i('   - Sin sincronizar (sincronizado = 0): ${_censos.where((c) => c.sincronizado == 0).length}');
      _logger.i('   - Con intentos fallidos: ${_censos.where((c) => c.intentosSync > 0).length}');

      _setState(CensosLoadingState.loaded);

    } catch (e) {
      _logger.e('❌ Error cargando censos pendientes: $e');
      _errorMessage = 'Error al cargar censos: ${e.toString()}';
      _setState(CensosLoadingState.error);
    }
  }

  /// Reintenta sincronizar un censo específico
  Future<SyncResult> reintentarCenso(String censoId) async {
    _retryingCensoId = censoId;
    _setState(CensosLoadingState.retrying);

    try {
      _logger.i('🔄 Reintentando censo: $censoId');

      final db = await _dbHelper.database;

      // 1. Obtener datos del censo
      final censoData = await _obtenerCensoCompleto(db, censoId);
      if (censoData == null) {
        return SyncResult(
          success: false,
          error: 'No se encontraron datos del censo',
        );
      }

      // 2. Validar que no esté ya sincronizado
      if ((censoData['sincronizado'] as int?) == 1) {
        _logger.w('⚠️ Censo $censoId ya está sincronizado');
        await loadCensosPendientes(); // Recargar lista
        return SyncResult(
          success: true,
          message: 'El censo ya estaba sincronizado',
        );
      }

      // 3. Preparar datos para envío
      final position = Position(
        latitude: (censoData['latitud'] as num?)?.toDouble() ?? 0.0,
        longitude: (censoData['longitud'] as num?)?.toDouble() ?? 0.0,
        timestamp: DateTime.now(),
        accuracy: 0.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );

      // 4. Obtener fotos asociadas
      final fotos = await _obtenerFotosCenso(db, censoId);
      _logger.i('📷 Fotos encontradas: ${fotos.length}');

      // 5. Enviar usando tu servicio existente CensoActivoPostService
      final response = await CensoActivoPostService.enviarCambioEstado(
        codigoBarras: censoData['equipo_id']?.toString() ?? '',
        clienteId: (censoData['cliente_id'] as num?)?.toInt() ?? 0,
        enLocal: (censoData['en_local'] as num?) == 1,
        position: position,
        observaciones: censoData['observaciones']?.toString(),
        equipoId: censoData['equipo_id']?.toString(),
      );

      if (response['exito'] == true) {
        // ✅ ÉXITO: Marcar como sincronizado
        await _marcarCensoComoSincronizado(db, censoId);
        await _marcarFotosComoSincronizadas(db, censoId);

        _logger.i('✅ Censo $censoId sincronizado exitosamente');

        // Recargar lista
        await loadCensosPendientes();

        return SyncResult(
          success: true,
          message: 'Censo sincronizado correctamente',
        );

      } else {
        // ❌ ERROR: Registrar intento fallido
        final mensajeError = response['mensaje'] ?? 'Error desconocido del servidor';
        await _registrarIntentoFallido(db, censoId, mensajeError);

        _logger.w('❌ Error sincronizando censo $censoId: $mensajeError');

        return SyncResult(
          success: false,
          error: mensajeError,
        );
      }

    } catch (e) {
      _logger.e('💥 Excepción al reintentar censo: $e');

      // Registrar error en BD
      try {
        final db = await _dbHelper.database;
        await _registrarIntentoFallido(db, censoId, 'Error interno: $e');
      } catch (dbError) {
        _logger.e('Error registrando fallo en BD: $dbError');
      }

      return SyncResult(
        success: false,
        error: 'Error interno: ${e.toString()}',
      );

    } finally {
      _retryingCensoId = null;
      if (_state == CensosLoadingState.retrying) {
        _setState(CensosLoadingState.loaded);
      }
    }
  }

  /// Reintenta sincronizar todos los censos pendientes
  Future<SyncResult> reintentarTodosCensos() async {
    if (_censos.isEmpty) {
      return SyncResult(
        success: true,
        message: 'No hay censos pendientes',
      );
    }

    _setState(CensosLoadingState.retrying);

    int exitosos = 0;
    int fallidos = 0;
    int saltados = 0;

    try {
      _logger.i('🔄 Iniciando sincronización masiva de ${_censos.length} censos...');

      for (var censo in _censos) {
        // Solo reintentar censos que puedan reintentarse
        if (!censo.puedeReintentar) {
          _logger.i('⏭️ Saltando censo ${censo.id} (ya sincronizado o en cooldown)');
          saltados++;
          continue;
        }

        final resultado = await reintentarCenso(censo.id);

        if (resultado.success) {
          exitosos++;
        } else {
          fallidos++;
        }

        // Pequeña pausa para no saturar el servidor
        await Future.delayed(const Duration(milliseconds: 500));
      }

      _logger.i('📊 Resultado: ✅ $exitosos exitosos | ❌ $fallidos fallidos | ⏭️ $saltados saltados');

      // Recargar lista final
      await loadCensosPendientes();

      if (fallidos == 0 && exitosos > 0) {
        return SyncResult(
          success: true,
          message: 'Todos los censos sincronizados ($exitosos)${saltados > 0 ? " ($saltados ya estaban sincronizados)" : ""}',
          exitosos: exitosos,
          fallidos: 0,
        );
      } else if (exitosos > 0) {
        return SyncResult(
          success: true,
          message: 'Sincronización parcial: $exitosos exitosos, $fallidos fallidos${saltados > 0 ? ", $saltados saltados" : ""}',
          exitosos: exitosos,
          fallidos: fallidos,
        );
      } else {
        return SyncResult(
          success: false,
          error: 'No se pudieron sincronizar censos${saltados > 0 ? " ($saltados ya estaban sincronizados)" : ""}',
          exitosos: 0,
          fallidos: fallidos,
        );
      }

    } catch (e) {
      _logger.e('💥 Error en sincronización masiva: $e');
      return SyncResult(
        success: false,
        error: 'Error general: ${e.toString()}',
        exitosos: exitosos,
        fallidos: fallidos,
      );
    }
  }

  /// Obtiene estadísticas de censos
  Future<Map<String, int>> getEstadisticas() async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery('''
        SELECT 
          COUNT(*) as total,
          SUM(CASE WHEN sincronizado = 1 THEN 1 ELSE 0 END) as sincronizados,
          SUM(CASE WHEN sincronizado = 0 OR sincronizado IS NULL THEN 1 ELSE 0 END) as pendientes,
          SUM(CASE WHEN intentos_sync > 0 AND sincronizado = 0 THEN 1 ELSE 0 END) as con_errores,
          SUM(CASE WHEN estado_censo = 'error' THEN 1 ELSE 0 END) as estado_error,
          SUM(CASE WHEN estado_censo = 'creado' THEN 1 ELSE 0 END) as creados
        FROM censo_activo
      ''');

      if (result.isNotEmpty) {
        final stats = result.first;
        return {
          'total': stats['total'] as int? ?? 0,
          'sincronizados': stats['sincronizados'] as int? ?? 0,
          'pendientes': stats['pendientes'] as int? ?? 0,
          'con_errores': stats['con_errores'] as int? ?? 0,
          'estado_error': stats['estado_error'] as int? ?? 0,
          'creados': stats['creados'] as int? ?? 0,
        };
      }
    } catch (e) {
      _logger.e('❌ Error obteniendo estadísticas: $e');
    }

    return {
      'total': 0,
      'sincronizados': 0,
      'pendientes': 0,
      'con_errores': 0,
      'estado_error': 0,
      'creados': 0,
    };
  }

  // ==================== MÉTODOS PRIVADOS ====================

  void _setState(CensosLoadingState newState) {
    _state = newState;
    notifyListeners();
  }

  /// Consulta SQL para obtener censos pendientes
  /// Filtra por: sincronizado = 0 Y (estado_censo = 'creado' O 'error' O NULL)
  Future<List<Map<String, dynamic>>> _getCensosPendientesFromDB(Database db) async {
    const sql = '''
    SELECT 
      ca.id,
      ca.equipo_id,
      ca.cliente_id,
      ca.en_local,
      ca.latitud,
      ca.longitud,
      ca.observaciones,
      ca.fecha_creacion,
      ca.fecha_actualizacion,
      ca.sincronizado,
      ca.intentos_sync,
      ca.ultimo_intento,
      ca.error_mensaje,
      ca.estado_censo,
      eq.cod_barras,
      c.nombre as cliente_nombre,
      m.nombre as marca_nombre,
      mo.nombre as modelo_nombre,
      (SELECT COUNT(*) FROM censo_activo_foto f WHERE f.censo_activo_id = ca.id) as fotos_count
    FROM censo_activo ca
    LEFT JOIN clientes c ON ca.cliente_id = c.id
    LEFT JOIN equipos eq ON ca.equipo_id = eq.id
    LEFT JOIN marcas m ON eq.marca_id = m.id
    LEFT JOIN modelos mo ON eq.modelo_id = mo.id
    WHERE (
      ca.sincronizado = 0 
      OR ca.estado_censo = 'error'
    )
    ORDER BY ca.fecha_creacion DESC
  ''';

    return await db.rawQuery(sql);
  }

  /// Obtiene el censo completo con todos sus datos
  Future<Map<String, dynamic>?> _obtenerCensoCompleto(Database db, String censoId) async {
    final result = await db.query(
      'censo_activo',
      where: 'id = ?',
      whereArgs: [censoId],
    );

    return result.isNotEmpty ? result.first : null;
  }

  /// Obtiene las fotos asociadas a un censo
  Future<List<Map<String, dynamic>>> _obtenerFotosCenso(Database db, String censoId) async {
    return await db.query(
      'censo_activo_foto',
      where: 'censo_activo_id = ?',
      whereArgs: [censoId],
      orderBy: 'orden ASC',
    );
  }

  /// Marca un censo como sincronizado
  Future<void> _marcarCensoComoSincronizado(Database db, String censoId) async {
    await db.update(
      'censo_activo',
      {
        'sincronizado': 1,
        'estado_censo': 'migrado',
        'fecha_actualizacion': DateTime.now().toIso8601String(),
        'error_mensaje': null, // Limpiar error si existía
      },
      where: 'id = ?',
      whereArgs: [censoId],
    );

    _logger.i('✅ Censo $censoId marcado como sincronizado en BD');
  }

  /// Marca las fotos como sincronizadas
  Future<void> _marcarFotosComoSincronizadas(Database db, String censoId) async {
    final fotosActualizadas = await db.update(
      'censo_activo_foto',
      {'sincronizado': 1},
      where: 'censo_activo_id = ?',
      whereArgs: [censoId],
    );

    _logger.i('✅ $fotosActualizadas fotos marcadas como sincronizadas');
  }

  /// Registra un intento fallido de sincronización
  Future<void> _registrarIntentoFallido(Database db, String censoId, String mensajeError) async {
    await db.rawUpdate('''
      UPDATE censo_activo 
      SET intentos_sync = intentos_sync + 1,
          ultimo_intento = ?,
          error_mensaje = ?,
          estado_censo = 'error',
          sincronizado = 0
      WHERE id = ?
    ''', [
      DateTime.now().toIso8601String(),
      mensajeError,
      censoId,
    ]);

    _logger.w('⚠️ Intento fallido registrado para censo $censoId: $mensajeError');
  }

  @override
  void dispose() {
    _logger.i('🗑️ CensosPendientesDetailViewModel disposed');
    super.dispose();
  }
}