import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:ada_app/services/database_helper.dart';
import 'package:ada_app/services/post/censo_activo_post_service.dart';
import 'package:ada_app/repositories/censo_activo_foto_repository.dart';
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
    this.estadoCenso
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
    );
  }

  String get equipoNombre {
    final nombre = '${marcaNombre ?? ''} ${modeloNombre ?? ''}'.trim();
    return nombre.isNotEmpty ? nombre : 'Equipo sin datos';
  }

  String get estadoDescripcion {
    if (estadoCenso == 'error') return 'Error';
    if (estadoCenso == 'creado') return 'Pendiente';
    return 'Desconocido';
  }

  bool get puedeReintentar {
    if (intentosSync == 0) return true;

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
  final CensoActivoFotoRepository _fotoRepository = CensoActivoFotoRepository();

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



      // 2. Obtener usuario_id
      final usuarioId = censoData['usuario_id'] as int?;
      if (usuarioId == null) {
        _logger.e('❌ usuario_id no encontrado en censo $censoId');
        return SyncResult(
          success: false,
          error: 'Usuario no encontrado en el censo',
        );
      }

      // 3. Obtener edf_vendedor_id
      final usuariosList = await db.query(
        'Users',
        where: 'id = ?',
        whereArgs: [usuarioId],
        limit: 1,
      );

      if (usuariosList.isEmpty) {
        _logger.e('❌ Usuario $usuarioId no encontrado');
        return SyncResult(
          success: false,
          error: 'Datos del usuario no disponibles',
        );
      }

      final edfVendedorId = usuariosList.first['edf_vendedor_id'] as String?;
      if (edfVendedorId == null || edfVendedorId.isEmpty) {
        _logger.e('❌ edf_vendedor_id vacío');
        return SyncResult(
          success: false,
          error: 'edf_vendedor_id no disponible',
        );
      }

      // 4. Obtener fotos del censo
      final fotos = await _fotoRepository.obtenerFotosPorCenso(censoId);
      _logger.i('📸 Fotos encontradas: ${fotos.length}');

      // 5. Obtener datos del equipo
      final equipoId = censoData['equipo_id']?.toString();
      int? marcaId;
      int? modeloId;
      int? logoId;
      String? numeroSerie;

      if (equipoId != null) {
        final equiposList = await db.query(
          'equipos',
          where: 'id = ?',
          whereArgs: [equipoId],
          limit: 1,
        );

        if (equiposList.isNotEmpty) {
          final equipo = equiposList.first;
          marcaId = equipo['marca_id'] as int?;
          modeloId = equipo['modelo_id'] as int?;
          logoId = equipo['logo_id'] as int?;
          numeroSerie = equipo['numero_serie'] as String?;
        }
      }

      // 6. Llamada directa a enviarCensoActivo
      _logger.i('📤 Usando enviarCensoActivo...');
      final response = null;
      // final response = await CensoActivoPostService.enviarCensoActivo(
      //   equipoId: equipoId ?? '',
      //   codigoBarras: censoData['codigo_barras']?.toString() ?? equipoId ?? '',
      //   marcaId: marcaId,
      //   modeloId: modeloId,
      //   logoId: logoId,
      //   numeroSerie: numeroSerie,
      //   esNuevoEquipo: false,
      //   clienteId: (censoData['cliente_id'] as num?)?.toInt() ?? 0,
      //   edfVendedorId: edfVendedorId,
      //   crearPendiente: false,
      //   usuarioId: usuarioId,
      //   latitud: (censoData['latitud'] as num?)?.toDouble() ?? 0.0,
      //   longitud: (censoData['longitud'] as num?)?.toDouble() ?? 0.0,
      //   observaciones: censoData['observaciones']?.toString(),
      //   enLocal: (censoData['en_local'] as int?) == 1,
      //   estadoCenso: censoData['estado_censo']?.toString() ?? 'pendiente',
      //   fotos: fotos,
      //   clienteNombre: censoData['cliente_nombre']?.toString(),
      //   marca: censoData['marca_nombre']?.toString(),
      //   modelo: censoData['modelo']?.toString(),
      //   logo: censoData['logo']?.toString(),
      //   timeoutSegundos: 45,
      //   userId: usuarioId.toString(),
      //   guardarLog: true,
      // );

      if (response['exito'] == true) {
        await db.update(
          'censo_activo',
          {
            'estado_censo': 'migrado',
            'fecha_actualizacion': DateTime.now().toIso8601String(),
            'error_mensaje': null,
          },
          where: 'id = ?',
          whereArgs: [censoId],
        );

        for (final foto in fotos) {
          if (foto.id != null) {
            await _fotoRepository.marcarComoSincronizada(foto.id!);
          }
        }

        _logger.i('✅ Censo $censoId migrado exitosamente');
        await loadCensosPendientes();

        return SyncResult(
          success: true,
          message: 'Censo migrado correctamente',
        );

      } else {
        final errorMessage = response['mensaje'] ?? 'Error desconocido';

        await db.rawUpdate('''
          UPDATE censo_activo 
          SET intentos_sync = intentos_sync + 1,
              ultimo_intento = ?,
              error_mensaje = ?,
              estado_censo = 'error'
          WHERE id = ?
        ''', [
          DateTime.now().toIso8601String(),
          errorMessage,
          censoId,
        ]);

        return SyncResult(
          success: false,
          error: errorMessage,
        );
      }

    } catch (e) {
      _logger.e('💥 Excepción al reintentar censo: $e');

      try {
        final db = await _dbHelper.database;
        await db.rawUpdate('''
          UPDATE censo_activo 
          SET intentos_sync = intentos_sync + 1,
              ultimo_intento = ?,
              error_mensaje = ?,
              estado_censo = 'error'
          WHERE id = ?
        ''', [
          DateTime.now().toIso8601String(),
          'Error interno: $e',
          censoId,
        ]);
      } catch (dbError) {
        _logger.e('Error registrando fallo: $dbError');
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
      _logger.i('🔄 Iniciando sincronización masiva...');

      for (var censo in _censos) {
        if (!censo.puedeReintentar) {
          saltados++;
          continue;
        }

        final resultado = await reintentarCenso(censo.id);

        if (resultado.success) {
          exitosos++;
        } else {
          fallidos++;
        }

        await Future.delayed(const Duration(milliseconds: 500));
      }

      await loadCensosPendientes();

      if (fallidos == 0 && exitosos > 0) {
        return SyncResult(
          success: true,
          message: 'Todos los censos migrados ($exitosos)',
          exitosos: exitosos,
          fallidos: 0,
        );
      } else if (exitosos > 0) {
        return SyncResult(
          success: true,
          message: 'Sincronización parcial: $exitosos exitosos, $fallidos fallidos',
          exitosos: exitosos,
          fallidos: fallidos,
        );
      } else {
        return SyncResult(
          success: false,
          error: 'No se pudieron sincronizar censos',
          exitosos: 0,
          fallidos: fallidos,
        );
      }

    } catch (e) {
      return SyncResult(
        success: false,
        error: 'Error general: ${e.toString()}',
        exitosos: exitosos,
        fallidos: fallidos,
      );
    }
  }



  void _setState(CensosLoadingState newState) {
    _state = newState;
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> _getCensosPendientesFromDB(Database db) async {
    const sql = '''
    SELECT 
      ca.*,
      eq.cod_barras,
      c.nombre as cliente_nombre,
      m.nombre as marca_nombre,
      mo.nombre as modelo_nombre
    FROM censo_activo ca
    LEFT JOIN clientes c ON ca.cliente_id = c.id
    LEFT JOIN equipos eq ON ca.equipo_id = eq.id
    LEFT JOIN marcas m ON eq.marca_id = m.id
    LEFT JOIN modelos mo ON eq.modelo_id = mo.id
    ORDER BY ca.fecha_creacion DESC
  ''';

    return await db.rawQuery(sql);
  }

  Future<Map<String, dynamic>?> _obtenerCensoCompleto(Database db, String censoId) async {
    final result = await db.query(
      'censo_activo',
      where: 'id = ?',
      whereArgs: [censoId],
    );

    return result.isNotEmpty ? result.first : null;
  }

  @override
  void dispose() {
    _logger.i('🗑️ Disposed');
    super.dispose();
  }
}