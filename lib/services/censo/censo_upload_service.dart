import 'dart:async';
import 'dart:io';
import 'package:ada_app/models/censo_activo.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'package:ada_app/repositories/censo_activo_repository.dart';
import 'package:ada_app/repositories/censo_activo_foto_repository.dart';
import 'package:ada_app/repositories/equipo_repository.dart';
import 'package:ada_app/repositories/equipo_pendiente_repository.dart';
import 'package:ada_app/services/post/censo_activo_post_service.dart';
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/services/error_log/error_log_service.dart';
import 'censo_log_service.dart';

class CensoUploadService {
  final Logger _logger = Logger();
  final EstadoEquipoRepository estadoEquipoRepository;
  final CensoActivoFotoRepository _fotoRepository;
  final CensoLogService _logService;
  final EquipoPendienteRepository _equipoPendienteRepository;
  final EquipoRepository _equipoRepository;

  static const String _tableName = 'censo_activo';
  static const int maxIntentos = 10;
  static const Duration intervaloTimer = Duration(minutes: 1);

  static Timer? _syncTimer;
  static bool _syncActivo = false;
  static bool _syncEnProgreso = false;
  static int? _usuarioActual;
  static final Set<String> _censosEnProceso = {};

  CensoUploadService({
    EstadoEquipoRepository? estadoEquipoRepository,
    CensoActivoFotoRepository? fotoRepository,
    CensoLogService? logService,
    EquipoPendienteRepository? equipoPendienteRepository,
    EquipoRepository? equipoRepository,
  })  : estadoEquipoRepository = estadoEquipoRepository ?? EstadoEquipoRepository(),
        _fotoRepository = fotoRepository ?? CensoActivoFotoRepository(),
        _logService = logService ?? CensoLogService(),
        _equipoPendienteRepository = equipoPendienteRepository ?? EquipoPendienteRepository(),
        _equipoRepository = equipoRepository ?? EquipoRepository();

  Future<void> enviarCensoUnificado({
    required String censoActivoId,
    required int usuarioId,
    required String edfVendedorId,
    required bool guardarLog
  }) async {
    String? fullUrl;

    try {
      _logger.i('Enviando censo unificado: $censoActivoId');

      final baseUrl = await BaseSyncService.getBaseUrl();
      fullUrl = '$baseUrl/censoActivo/insertCensoActivo';

      final maps = await estadoEquipoRepository.dbHelper.consultar(
        'censo_activo',
        where: 'id = ?',
        whereArgs: [censoActivoId],
        limit: 1,
      );

      if (maps.isEmpty) {
        throw Exception('Censo no encontrado en BD: $censoActivoId');
      }

      final censoActivoMap = Map<String, dynamic>.from(maps.first);
      var estado = censoActivoMap['estado_censo']?.toString();

      if (estado == 'migrado') {
        _logger.w('Censo ya migrado: $censoActivoId');
        return;
      }

      final equipoId = censoActivoMap['equipo_id']?.toString();
      var equipoDataMap;

      if (equipoId != null) {
        await _enriquecerDatosEquipo(censoActivoMap, equipoId);

        var equipoDataMapList = await _equipoRepository.dbHelper.consultar(
          'equipos',
          where: 'id = ?',
          whereArgs: [equipoId],
          limit: 1,
        );

        if (equipoDataMapList.isEmpty) {
          throw Exception('Equipo no encontrado: $equipoId');
        }

        equipoDataMap = equipoDataMapList[0];
      }

      final fotos = await _fotoRepository.obtenerFotosPorCenso(censoActivoId);

      final esNuevoEquipo = censoActivoMap['es_nuevo_equipo'] == true;
      final clienteId = _convertirAInt(censoActivoMap['cliente_id']);
      final yaAsignado = await _verificarEquipoAsignado(equipoId, clienteId);
      final crearPendiente = !yaAsignado;

      _logger.i('Flags - Nuevo: $esNuevoEquipo, Crear pendiente: $crearPendiente');

      final pendienteExistente = await _equipoPendienteRepository.dbHelper.consultar(
        'equipos_pendientes',
        where: 'equipo_id = ? AND cliente_id = ?',
        whereArgs: [equipoId, clienteId],
        orderBy: 'fecha_creacion DESC',
        limit: 1,
      );

      await CensoActivoPostService.enviarCensoActivo(
          censoId: censoActivoId,
          equipoId: equipoId,
          codigoBarras: censoActivoMap['codigo_barras']?.toString(),
          marcaId: censoActivoMap['marca_id'] as int?,
          modeloId: censoActivoMap['modelo_id'] as int?,
          logoId: censoActivoMap['logo_id'] as int?,
          numeroSerie: censoActivoMap['numero_serie']?.toString(),
          esNuevoEquipo: esNuevoEquipo,
          clienteId: clienteId,
          edfVendedorId: edfVendedorId,
          crearPendiente: crearPendiente,
          pendienteExistente: pendienteExistente,
          usuarioId: usuarioId,
          latitud: censoActivoMap['latitud']?.toDouble() ?? 0.0,
          longitud: censoActivoMap['longitud']?.toDouble() ?? 0.0,
          observaciones: censoActivoMap['observaciones']?.toString(),
          enLocal: censoActivoMap['en_local'] == true,
          estadoCenso: yaAsignado ? 'asignado' : 'pendiente',
          fotos: fotos,
          clienteNombre: censoActivoMap['cliente_nombre']?.toString(),
          marca: censoActivoMap['marca_nombre']?.toString(),
          modelo: censoActivoMap['modelo']?.toString(),
          logo: censoActivoMap['logo']?.toString(),
          guardarLog: guardarLog,
          equipoDataMap: equipoDataMap
      );

    } catch (e, stackTrace) {
      _logger.e('Error en enviarCensoUnificado: $e', stackTrace: stackTrace);

      await ErrorLogService.manejarExcepcion(
        e,
        censoActivoId,
        fullUrl,
        usuarioId,
        _tableName,
      );

      rethrow;
    }
  }

  Future<Map<String, int>> sincronizarCensosNoMigrados(int usuarioId) async {
    _logger.i('=== SINCRONIZACIÓN PERIÓDICA UNIFICADA ===');

    int censosExitosos = 0;
    int totalFallidos = 0;

    try {
      final registrosCreados = await estadoEquipoRepository.obtenerCreados();
      final registrosError = await estadoEquipoRepository.obtenerConError();
      final registrosErrorListos = await _filtrarRegistrosListosParaReintento(
          registrosError,
          registrosCreados
      );

      final todosLosRegistros = [...registrosCreados, ...registrosErrorListos];

      _logger.i('Total censos a procesar: ${todosLosRegistros.length}');

      final registrosAProcesar = todosLosRegistros.take(20);

      for (final registro in registrosAProcesar) {
        try {
          await _sincronizarRegistroIndividualUnificado(registro, usuarioId);
          censosExitosos++;
          _logger.i('Censo sincronizado: ${registro.id}');
        } catch (e) {
          _logger.e('Error en censo ${registro.id}: $e');
          totalFallidos++;

          if (registro.id != null) {
            await estadoEquipoRepository.marcarComoError(
              registro.id!,
              'Excepción: ${e.toString()}',
            );

            await ErrorLogService.manejarExcepcion(
              e,
              registro.id!,
              null,
              usuarioId,
              _tableName,
            );
          }
        }

        await Future.delayed(Duration(milliseconds: 500));
      }

      _logger.i('=== SINCRONIZACIÓN COMPLETADA ===');
      _logger.i('   - Exitosos: $censosExitosos');
      _logger.i('   - Fallidos: $totalFallidos');

      return {
        'censos_exitosos': censosExitosos,
        'fallidos': totalFallidos,
        'total': censosExitosos,
      };

    } catch (e, stackTrace) {
      _logger.e('Error en sincronización periódica: $e', stackTrace: stackTrace);

      await ErrorLogService.manejarExcepcion(
        e,
        null,
        null,
        usuarioId,
        _tableName,
      );

      return {
        'censos_exitosos': censosExitosos,
        'fallidos': totalFallidos,
        'total': 0,
      };
    }
  }

  Future<void> _sincronizarRegistroIndividualUnificado(
      dynamic registro,
      int usuarioId,
      ) async {
    final estadoId = registro.id as String;

    final intentosPrevios = await _obtenerNumeroIntentos(estadoId);
    final numeroIntento = intentosPrevios + 1;

    if (numeroIntento > maxIntentos) {
      await estadoEquipoRepository.marcarComoError(
        estadoId,
        'Fallo permanente: máximo de intentos alcanzado',
      );

      await ErrorLogService.logError(
        tableName: _tableName,
        operation: 'sincronizar_individual',
        errorMessage: 'Máximo de intentos alcanzado ($maxIntentos)',
        errorType: 'sync',
        errorCode: 'MAX_RETRIES_EXCEEDED',
        registroFailId: estadoId,
        userId: usuarioId,
      );

      return;
    }

    _logger.i('Sincronizando $estadoId (intento #$numeroIntento/$maxIntentos)');

    final edfVendedorId = await _obtenerEdfVendedorIdDesdeUsuarioId(usuarioId);
    if (edfVendedorId == null || edfVendedorId.isEmpty) {
      await ErrorLogService.logValidationError(
        tableName: _tableName,
        operation: 'sincronizar_individual',
        errorMessage: 'edfVendedorId no encontrado para usuario $usuarioId',
        registroFailId: estadoId,
        userId: usuarioId,
      );
      throw Exception('edfVendedorId no encontrado');
    }

    await _actualizarUltimoIntento(estadoId, numeroIntento);

    await enviarCensoUnificado(
      censoActivoId: estadoId,
      usuarioId: usuarioId,
      edfVendedorId: edfVendedorId,
      guardarLog: false,
    );
  }

  Future<Map<String, dynamic>> reintentarEnvioCenso(
      String censoActivoId,
      int usuarioId,
      String? edfVendedorId,
      ) async {
    bool success = false;
    String message = '';

    try {
      _logger.i('Reintento manual: $censoActivoId');

      if (edfVendedorId == null || edfVendedorId.isEmpty) {
        throw Exception('edfVendedorId es requerido');
      }

      await enviarCensoUnificado(
        censoActivoId: censoActivoId,
        usuarioId: usuarioId,
        edfVendedorId: edfVendedorId,
        guardarLog: true,
      );

      final censoActivoMapList = await estadoEquipoRepository.dbHelper.consultar(
        'censo_activo',
        where: 'id = ?',
        whereArgs: [censoActivoId],
        limit: 1,
      );

      if (censoActivoMapList.isEmpty) {
        throw Exception('Censo no encontrado después del envío');
      }

      final censoActivoMap = Map<String, dynamic>.from(censoActivoMapList.first);
      var estadoCenso = censoActivoMap['estado_censo'];

      if (estadoCenso == 'migrado') {
        success = true;
        message = 'Registro sincronizado correctamente';

        await ErrorLogService.marcarErroresComoResueltos(
          registroFailId: censoActivoId,
          tableName: _tableName,
        );
      } else {
        success = false;
        message = censoActivoMap['error_mensaje'] ?? 'Error desconocido';
      }

    } catch (e, stackTrace) {
      _logger.e('Error en reintento: $e', stackTrace: stackTrace);
      message = 'Error en reintento: $e';

      await ErrorLogService.manejarExcepcion(
        e,
        censoActivoId,
        null,
        usuarioId,
        _tableName,
      );
    }

    return {
      'success': success,
      'message': message,
    };
  }

  Future<void> _enriquecerDatosEquipo(
      Map<String, dynamic> datosLocales,
      String equipoId,
      ) async {
    try {
      final db = await _equipoRepository.dbHelper.database;
      final result = await db.rawQuery('''
      SELECT 
        e.id,
        e.cod_barras,
        e.marca_id,
        e.modelo_id,
        e.logo_id,
        e.numero_serie,
        e.app_insert,
        m.nombre as marca_nombre,
        mo.nombre as modelo_nombre,
        l.nombre as logo_nombre
      FROM equipos e
      LEFT JOIN marcas m ON e.marca_id = m.id
      LEFT JOIN modelos mo ON e.modelo_id = mo.id
      LEFT JOIN logo l ON e.logo_id = l.id
      WHERE e.id = ?
    ''', [equipoId]);

      if (result.isNotEmpty) {
        final infoEquipo = result.first;

        datosLocales['marca_id'] ??= infoEquipo['marca_id'];
        datosLocales['modelo_id'] ??= infoEquipo['modelo_id'];
        datosLocales['logo_id'] ??= infoEquipo['logo_id'];
        datosLocales['numero_serie'] ??= infoEquipo['numero_serie'];
        datosLocales['codigo_barras'] ??= infoEquipo['cod_barras'];
        datosLocales['marca_nombre'] ??= infoEquipo['marca_nombre'];
        datosLocales['modelo'] ??= infoEquipo['modelo_nombre'];
        datosLocales['logo'] ??= infoEquipo['logo_nombre'];
        datosLocales['es_nuevo_equipo'] ??= (infoEquipo['app_insert'] == 1);

        _logger.i('Datos enriquecidos desde equipos');
      }
    } catch (e) {
      _logger.w('No se pudo enriquecer datos: $e');
      rethrow;
    }
  }

  Future<void> marcarComoSincronizadoCompleto({
    required String censoId,
    required String? equipoId,
    required int clienteId,
    required bool esNuevoEquipo,
    required bool crearPendiente,
    required List<dynamic> fotos,
  }) async {
    await estadoEquipoRepository.marcarComoMigrado(censoId);
    await estadoEquipoRepository.marcarComoSincronizado(censoId);

    if (equipoId != null && esNuevoEquipo) {
      await _equipoRepository.marcarEquipoComoSincronizado(equipoId);
    }

    if (equipoId != null && crearPendiente) {
      await _equipoPendienteRepository.marcarSincronizadosPorCenso(
        equipoId,
        clienteId,
      );
    }

    for (final foto in fotos) {
      if (foto.id != null) {
        await _fotoRepository.marcarComoSincronizada(foto.id!);
      }
    }

    await ErrorLogService.marcarErroresComoResueltos(
      registroFailId: censoId,
      tableName: _tableName,
    );
  }

  static void iniciarSincronizacionAutomatica(int usuarioId) {
    if (_syncActivo && _usuarioActual == usuarioId) {
      Logger().w('Sincronización ya activa para usuario $usuarioId');
      return;
    }

    detenerSincronizacionAutomatica();

    _usuarioActual = usuarioId;
    _syncActivo = true;

    Logger().i('Iniciando sincronización automática cada ${intervaloTimer.inMinutes} min');

    _syncTimer = Timer.periodic(intervaloTimer, (timer) async {
      await _ejecutarSincronizacionAutomatica();
    });

    Timer(const Duration(seconds: 15), () async {
      await _ejecutarSincronizacionAutomatica();
    });
  }

  static void detenerSincronizacionAutomatica() {
    if (_syncTimer != null) {
      _syncTimer!.cancel();
      _syncTimer = null;
      _syncActivo = false;
      _syncEnProgreso = false;
      _usuarioActual = null;
      _censosEnProceso.clear();
      Logger().i('Sincronización automática detenida');
    }
  }

  static Future<void> _ejecutarSincronizacionAutomatica() async {
    if (_syncEnProgreso || !_syncActivo || _usuarioActual == null) return;

    _syncEnProgreso = true;

    try {
      final conexion = await BaseSyncService.testConnection();
      if (!conexion.exito) {
        Logger().w('Sin conexión al servidor: ${conexion.mensaje}');
        return;
      }

      final service = CensoUploadService();
      final resultado = await service.sincronizarCensosNoMigrados(_usuarioActual!);

      if (resultado['total']! > 0) {
        Logger().i('Auto-sync: ${resultado['censos_exitosos']}/${resultado['total']}');
      }
    } catch (e, stackTrace) {
      Logger().e('Error en auto-sync: $e', stackTrace: stackTrace);

      await ErrorLogService.manejarExcepcion(
        e,
        null,
        null,
        _usuarioActual,
        'censo_activo',
      );
    } finally {
      _syncEnProgreso = false;
    }
  }

  static Future<Map<String, int>?> forzarSincronizacion() async {
    if (!_syncActivo || _usuarioActual == null) return null;

    Logger().i('Forzando sincronización...');
    final service = CensoUploadService();
    return await service.sincronizarCensosNoMigrados(_usuarioActual!);
  }

  static bool get esSincronizacionActiva => _syncActivo;
  static bool get estaEnProgreso => _syncEnProgreso;

  Future<List<dynamic>> _filtrarRegistrosListosParaReintento(
      List<dynamic> registrosError,
      [List<CensoActivo>? registrosCreados]
      ) async {
    final registrosListos = <dynamic>[];
    final ahora = DateTime.now();

    for (final registro in registrosError) {
      try {
        final intentos = await _obtenerNumeroIntentos(registro.id!);
        if (intentos >= maxIntentos) continue;

        final ultimoIntento = await _obtenerUltimoIntento(registro.id!);
        if (ultimoIntento == null) {
          registrosListos.add(registro);
          continue;
        }

        final minutosEspera = _calcularProximoIntento(intentos);
        if (minutosEspera < 0) continue;

        final tiempoProximoIntento = ultimoIntento.add(Duration(minutes: minutosEspera));

        if (ahora.isAfter(tiempoProximoIntento)) {
          registrosListos.add(registro);
        }
      } catch (e) {
        _logger.w('Error verificando ${registro.id}: $e');
        registrosListos.add(registro);
      }
    }
    return registrosListos;
  }

  int _calcularProximoIntento(int numeroIntento) {
    if (numeroIntento > maxIntentos) return -1;
    switch (numeroIntento) {
      case 1: return 1;
      case 2: return 5;
      case 3: return 10;
      case 4: return 15;
      case 5: return 20;
      case 6: return 25;
      default: return 30;
    }
  }

  Future<int> _obtenerNumeroIntentos(String estadoId) async {
    try {
      final maps = await estadoEquipoRepository.dbHelper.consultar(
        'censo_activo',
        where: 'id = ?',
        whereArgs: [estadoId],
        limit: 1,
      );
      return maps.isNotEmpty ? maps.first['intentos_sync'] as int? ?? 0 : 0;
    } catch (e) {
      _logger.w('Error obteniendo intentos: $e');
      return 0;
    }
  }

  Future<DateTime?> _obtenerUltimoIntento(String estadoId) async {
    try {
      final maps = await estadoEquipoRepository.dbHelper.consultar(
        'censo_activo',
        where: 'id = ?',
        whereArgs: [estadoId],
        limit: 1,
      );
      if (maps.isNotEmpty) {
        final ultimoIntentoStr = maps.first['ultimo_intento'] as String?;
        if (ultimoIntentoStr != null && ultimoIntentoStr.isNotEmpty) {
          return DateTime.parse(ultimoIntentoStr);
        }
      }
    } catch (e) {
      _logger.w('Error obteniendo último intento: $e');
      return null;
    }
    return null;
  }

  Future<void> _actualizarUltimoIntento(String estadoId, int numeroIntento) async {
    try {
      await estadoEquipoRepository.dbHelper.actualizar(
        'censo_activo',
        {
          'intentos_sync': numeroIntento,
          'ultimo_intento': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [estadoId],
      );
    } catch (e) {
      _logger.w('Error actualizando último intento: $e');
      rethrow;
    }
  }

  Future<String?> _obtenerEdfVendedorIdDesdeUsuarioId(int? usuarioId) async {
    try {
      if (usuarioId == null) return null;

      final usuarioEncontrado = await estadoEquipoRepository.dbHelper.consultar(
        'Users',
        where: 'id = ?',
        whereArgs: [usuarioId],
        limit: 1,
      );

      return usuarioEncontrado.isNotEmpty
          ? usuarioEncontrado.first['edf_vendedor_id'] as String?
          : null;
    } catch (e) {
      _logger.e('Error resolviendo edfVendedorId: $e');
      rethrow;
    }
  }

  Future<bool> _verificarEquipoAsignado(String? equipoId, dynamic clienteId) async {
    try {
      if (equipoId == null || clienteId == null) return false;

      return await _equipoRepository.verificarAsignacionEquipoCliente(
        equipoId,
        _convertirAInt(clienteId),
      );
    } catch (e) {
      _logger.w('Error verificando asignación: $e');
      rethrow;
    }
  }

  int _convertirAInt(dynamic valor) {
    if (valor == null) return 0;
    if (valor is int) return valor;
    if (valor is String) return int.tryParse(valor) ?? 0;
    if (valor is double) return valor.toInt();
    return 0;
  }
}