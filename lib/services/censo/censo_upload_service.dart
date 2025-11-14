// lib/services/censo/censo_upload_service.dart

import 'dart:async';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:ada_app/repositories/censo_activo_repository.dart';
import 'package:ada_app/repositories/censo_activo_foto_repository.dart';
import 'package:ada_app/repositories/equipo_repository.dart';
import 'package:ada_app/services/censo/censo_api_mapper.dart';
import 'package:ada_app/services/post/base_post_service.dart';
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'censo_log_service.dart';

class CensoUploadService {
  final Logger _logger = Logger();
  final Uuid _uuid = const Uuid();
  final EstadoEquipoRepository _estadoEquipoRepository;
  final CensoActivoFotoRepository _fotoRepository;
  final CensoLogService _logService;

  // ========== CONFIGURACIÓN ==========
  static const int MAX_INTENTOS = 10;
  static const Duration INTERVALO_TIMER = Duration(minutes: 1);

  // ========== VARIABLES ESTÁTICAS ==========
  static Timer? _syncTimer;
  static bool _syncActivo = false;
  static bool _syncEnProgreso = false;
  static int? _usuarioActual;
  static final Set<String> _censosEnProceso = {};

  CensoUploadService({
    EstadoEquipoRepository? estadoEquipoRepository,
    CensoActivoFotoRepository? fotoRepository,
    CensoLogService? logService,
  })  : _estadoEquipoRepository = estadoEquipoRepository ?? EstadoEquipoRepository(),
        _fotoRepository = fotoRepository ?? CensoActivoFotoRepository(),
        _logService = logService ?? CensoLogService();

  // ==================== ENVÍO AL SERVIDOR ====================

  Future<Map<String, dynamic>> enviarCensoAlServidor(
      Map<String, dynamic> datos, {
        int timeoutSegundos = 60,
        bool guardarLog = false,
      }) async {
    try {
      _logger.i('📤 Preparando envío de censo...');

      final timestamp = DateTime.now().toIso8601String();

      if (guardarLog) {
        await _logService.guardarLogPost(
          url: 'API_ENDPOINT',
          headers: {'Content-Type': 'application/json'},
          body: datos,
          timestamp: timestamp,
          censoActivoId: datos['id'] ?? datos['id_local'],
        );
      }

      final resultado = await BasePostService.post(
        endpoint: '/censoActivo/insertCensoActivo',
        body: datos,
        timeout: Duration(seconds: timeoutSegundos),
      );

      _logger.i('✅ Respuesta recibida: ${resultado['exito']}');
      return resultado;

    } catch (e) {
      _logger.e('❌ Error en envío: $e');
      return {
        'exito': false,
        'mensaje': 'Error de conexión: $e',
      };
    }
  }

  Future<Map<String, dynamic>> _prepararPayloadConMapper(
      String estadoId,
      List<dynamic> fotos,
      ) async {
    try {
      _logger.i('📦 Preparando payload con mapper para: $estadoId');

      final maps = await _estadoEquipoRepository.dbHelper.consultar(
        'censo_activo',
        where: 'id = ?',
        whereArgs: [estadoId],
        limit: 1,
      );

      if (maps.isEmpty) {
        throw Exception('No se encontró el censo: $estadoId');
      }

      final datosLocales = maps.first;
      final usuarioId = datosLocales['usuario_id'] as int?;

      if (usuarioId == null) {
        throw Exception('usuario_id es requerido para el censo: $estadoId');
      }

      final edfVendedorId = await _obtenerEdfVendedorIdDesdeUsuarioId(usuarioId);
      if (edfVendedorId == null) {
        throw Exception('No se pudo resolver edfVendedorId para usuario_id: $usuarioId');
      }

      final estaAsignado = await _verificarEquipoAsignado(
        datosLocales['equipo_id']?.toString(),
        datosLocales['cliente_id'],
      );

      final datosLocalesMutable = Map<String, dynamic>.from(datosLocales);
      datosLocalesMutable['ya_asignado'] = estaAsignado;

      final payload = CensoApiMapper.prepararDatosParaApi(
        datosLocales: datosLocalesMutable,
        usuarioId: usuarioId,
        edfVendedorId: edfVendedorId,
        fotosConBase64: fotos,
      );

      _logger.i('✅ Payload preparado: ${payload.keys.length} campos y ${fotos.length} fotos');

      return payload;
    } catch (e) {
      _logger.e('❌ Error preparando payload: $e');
      rethrow;
    }
  }

  // ==================== SINCRONIZACIÓN EN BACKGROUND ====================

  /// ✅ PROTECCIÓN CONTRA DUPLICADOS
  Future<void> sincronizarCensoEnBackground(
      String estadoId,
      Map<String, dynamic> datos,
      ) async {
    if (_censosEnProceso.contains(estadoId)) {
      _logger.w('⚠️ Censo $estadoId ya está siendo procesado');
      return;
    }

    _censosEnProceso.add(estadoId);

    Future.delayed(Duration.zero, () async {
      try {
        _logger.i('🔄 Sincronización background para: $estadoId');

        final maps = await _estadoEquipoRepository.dbHelper.consultar(
          'censo_activo',
          where: 'id = ?',
          whereArgs: [estadoId],
          limit: 1,
        );

        if (maps.isEmpty) {
          _logger.e('❌ No se encontró el estado: $estadoId');
          return;
        }

        final fotos = await _fotoRepository.obtenerFotosPorCenso(estadoId);
        _logger.i('📸 Fotos encontradas: ${fotos.length}');

        final datosParaApi = await _prepararPayloadConMapper(estadoId, fotos);

        await _actualizarUltimoIntento(estadoId, 1);

        final respuesta = await enviarCensoAlServidor(
          datosParaApi,
          timeoutSegundos: 45,
        );

        if (respuesta['exito'] == true) {
          await _estadoEquipoRepository.marcarComoMigrado(
            estadoId,
            servidorId: respuesta['servidor_id'],
          );
          await _estadoEquipoRepository.marcarComoSincronizado(estadoId);

          for (final foto in fotos) {
            if (foto.id != null) {
              await _fotoRepository.marcarComoSincronizada(foto.id!);
            }
          }

          _logger.i('✅ Sincronización exitosa: $estadoId');
        } else {
          await _estadoEquipoRepository.marcarComoError(
            estadoId,
            'Error (intento #1): ${respuesta['detalle'] ?? respuesta['mensaje']}',
          );

          final proximoIntento = _calcularProximoIntento(1);
          _logger.w('⚠️ Error - reintento en $proximoIntento minuto(s)');
        }
      } catch (e) {
        _logger.e('💥 Excepción en sincronización: $e');
        await _actualizarUltimoIntento(estadoId, 1);
        await _estadoEquipoRepository.marcarComoError(estadoId, 'Excepción: $e');
      } finally {
        _censosEnProceso.remove(estadoId);
      }
    });
  }

  Future<Map<String, int>> sincronizarRegistrosPendientes(int usuarioId) async {
    try {
      _logger.i('🔄 Sincronización de pendientes...');

      final registrosCreados = await _estadoEquipoRepository.obtenerCreados();
      final registrosError = await _estadoEquipoRepository.obtenerConError();
      final registrosErrorListos = await _filtrarRegistrosListosParaReintento(registrosError);

      final todosLosRegistros = [...registrosCreados, ...registrosErrorListos];

      if (todosLosRegistros.isEmpty) {
        _logger.i('✅ No hay registros pendientes');
        return {'exitosos': 0, 'fallidos': 0, 'total': 0};
      }

      _logger.i('📋 Total a sincronizar: ${todosLosRegistros.length}');

      int exitosos = 0;
      int fallidos = 0;

      for (final registro in todosLosRegistros) {
        try {
          await _sincronizarRegistroIndividualConBackoff(registro, usuarioId);
          exitosos++;
        } catch (e) {
          _logger.e('❌ Error: $e');
          fallidos++;

          if (registro.id != null) {
            await _estadoEquipoRepository.marcarComoError(
              registro.id!,
              'Excepción: $e',
            );
          }
        }
      }

      _logger.i('✅ Completado - Exitosos: $exitosos, Fallidos: $fallidos');

      return {
        'exitosos': exitosos,
        'fallidos': fallidos,
        'total': todosLosRegistros.length,
      };
    } catch (e) {
      _logger.e('💥 Error en sincronización: $e');
      return {'exitosos': 0, 'fallidos': 0, 'total': 0};
    }
  }

  Future<Map<String, dynamic>> reintentarEnvioCenso(
      String estadoId,
      int usuarioId,
      String? edfVendedorId,
      ) async {
    try {
      _logger.i('🔁 Reintentando: $estadoId');

      final maps = await _estadoEquipoRepository.dbHelper.consultar(
        'censo_activo',
        where: 'id = ?',
        whereArgs: [estadoId],
        limit: 1,
      );

      if (maps.isEmpty) {
        return {'success': false, 'error': 'No se encontró el registro'};
      }

      final fotos = await _fotoRepository.obtenerFotosPorCenso(estadoId);
      final datosParaApi = await _prepararPayloadConMapper(estadoId, fotos);

      final respuesta = await enviarCensoAlServidor(
        datosParaApi,
        timeoutSegundos: 45,
      );

      if (respuesta['exito'] == true) {
        await _estadoEquipoRepository.marcarComoMigrado(estadoId, servidorId: respuesta['id']);
        await _estadoEquipoRepository.marcarComoSincronizado(estadoId);

        for (final foto in fotos) {
          if (foto.id != null) {
            await _fotoRepository.marcarComoSincronizada(foto.id!);
          }
        }

        return {'success': true, 'message': 'Registro sincronizado'};
      } else {
        await _estadoEquipoRepository.marcarComoError(estadoId, 'Error: ${respuesta['mensaje']}');
        return {'success': false, 'error': respuesta['mensaje']};
      }
    } catch (e) {
      _logger.e('💥 Error en reintento: $e');
      await _estadoEquipoRepository.marcarComoError(estadoId, 'Excepción: $e');
      return {'success': false, 'error': 'Error: $e'};
    }
  }

  // ==================== SINCRONIZACIÓN AUTOMÁTICA ====================

  /// ✅ MEJORADO: Con protección contra múltiples inicios
  static void iniciarSincronizacionAutomatica(int usuarioId) {
    if (_syncActivo && _usuarioActual == usuarioId) {
      Logger().w('⚠️ Sincronización ya activa para usuario $usuarioId');
      return;
    }

    detenerSincronizacionAutomatica();

    _usuarioActual = usuarioId;
    _syncActivo = true;

    Logger().i('🚀 Iniciando sincronización automática cada ${INTERVALO_TIMER.inMinutes} min para usuario $usuarioId');

    _syncTimer = Timer.periodic(INTERVALO_TIMER, (timer) async {
      await _ejecutarSincronizacionAutomatica();
    });

    Timer(Duration(seconds: 15), () async {
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
      Logger().i('⏹️ Sincronización automática detenida');
    }
  }

  /// ✅ MEJORADO: Evita ejecuciones simultáneas + verifica conexión
  static Future<void> _ejecutarSincronizacionAutomatica() async {
    if (_syncEnProgreso) {
      Logger().w('⚠️ Sincronización anterior en progreso, saltando ciclo');
      return;
    }

    if (!_syncActivo || _usuarioActual == null) {
      return;
    }

    _syncEnProgreso = true;

    try {
      final logger = Logger();
      logger.i('🔄 Ejecutando sincronización automática...');

      // ✅ Verificar conexión primero
      final conexion = await BaseSyncService.testConnection();
      if (!conexion.exito) {
        logger.w('⚠️ Sin conexión al servidor: ${conexion.mensaje}');
        return;
      }

      final service = CensoUploadService();
      final resultado = await service.sincronizarRegistrosPendientes(_usuarioActual!);

      if (resultado['total']! > 0) {
        logger.i('✅ Auto-sync: ${resultado['exitosos']}/${resultado['total']}');
      }
    } catch (e) {
      Logger().e('❌ Error en sincronización automática: $e');
    } finally {
      _syncEnProgreso = false;
    }
  }

  static Future<Map<String, int>?> forzarSincronizacion() async {
    if (!_syncActivo || _usuarioActual == null) {
      Logger().w('⚠️ No se puede forzar');
      return null;
    }

    Logger().i('⚡ Forzando sincronización...');
    final service = CensoUploadService();
    return await service.sincronizarRegistrosPendientes(_usuarioActual!);
  }

  // ==================== GETTERS ====================

  static bool get esSincronizacionActiva => _syncActivo;
  static int? get usuarioActualSync => _usuarioActual;
  static bool get estaEnProgreso => _syncEnProgreso;

  // ==================== MÉTODOS PRIVADOS ====================

  Future<void> _sincronizarRegistroIndividualConBackoff(
      dynamic registro,
      int usuarioId,
      ) async {
    final fotos = await _fotoRepository.obtenerFotosPorCenso(registro.id!);
    final intentosPrevios = await _obtenerNumeroIntentos(registro.id!);
    final numeroIntento = intentosPrevios + 1;

    // ✅ Límite de intentos
    if (numeroIntento > MAX_INTENTOS) {
      _logger.e('❌ Máximo de intentos ($MAX_INTENTOS) alcanzado para ${registro.id}');
      await _estadoEquipoRepository.marcarComoError(
        registro.id!,
        'Fallo permanente: máximo de intentos alcanzado',
      );
      return;
    }

    _logger.i('🔄 Sincronizando ${registro.id} (intento #$numeroIntento/$MAX_INTENTOS)');

    final datosParaApi = await _prepararPayloadConMapper(registro.id!, fotos);
    await _actualizarUltimoIntento(registro.id!, numeroIntento);

    final respuesta = await enviarCensoAlServidor(datosParaApi, timeoutSegundos: 60);

    if (respuesta['exito'] == true) {
      await _estadoEquipoRepository.marcarComoMigrado(registro.id!, servidorId: respuesta['id']);
      await _estadoEquipoRepository.marcarComoSincronizado(registro.id!);

      for (final foto in fotos) {
        if (foto.id != null) {
          await _fotoRepository.marcarComoSincronizada(foto.id!);
        }
      }

      _logger.i('✅ ${registro.id} sincronizado después de $numeroIntento intentos');
    } else {
      await _estadoEquipoRepository.marcarComoError(
        registro.id!,
        'Error (intento #$numeroIntento): ${respuesta['mensaje']}',
      );

      final proximoIntento = _calcularProximoIntento(numeroIntento);
      _logger.w('⚠️ Error intento #$numeroIntento - próximo en $proximoIntento min');
    }
  }

  Future<List<dynamic>> _filtrarRegistrosListosParaReintento(List<dynamic> registrosError) async {
    final registrosListos = <dynamic>[];
    final ahora = DateTime.now();

    for (final registro in registrosError) {
      try {
        final intentos = await _obtenerNumeroIntentos(registro.id!);

        if (intentos >= MAX_INTENTOS) {
          continue;
        }

        final ultimoIntento = await _obtenerUltimoIntento(registro.id!);

        if (ultimoIntento == null) {
          registrosListos.add(registro);
          continue;
        }

        final minutosEspera = _calcularProximoIntento(intentos);

        if (minutosEspera < 0) {
          continue;
        }

        final tiempoProximoIntento = ultimoIntento.add(Duration(minutes: minutosEspera));

        if (ahora.isAfter(tiempoProximoIntento)) {
          registrosListos.add(registro);
        }
      } catch (e) {
        _logger.w('⚠️ Error verificando ${registro.id}: $e');
        registrosListos.add(registro);
      }
    }

    return registrosListos;
  }

  int _calcularProximoIntento(int numeroIntento) {
    if (numeroIntento > MAX_INTENTOS) {
      return -1;
    }

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
      final maps = await _estadoEquipoRepository.dbHelper.consultar(
        'censo_activo',
        where: 'id = ?',
        whereArgs: [estadoId],
        limit: 1,
      );

      if (maps.isNotEmpty) {
        return maps.first['intentos_sync'] as int? ?? 0;
      }
    } catch (e) {
      _logger.w('⚠️ Error obteniendo intentos: $e');
    }
    return 0;
  }

  Future<DateTime?> _obtenerUltimoIntento(String estadoId) async {
    try {
      final maps = await _estadoEquipoRepository.dbHelper.consultar(
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
      _logger.w('⚠️ Error obteniendo último intento: $e');
    }
    return null;
  }

  Future<void> _actualizarUltimoIntento(String estadoId, int numeroIntento) async {
    try {
      await _estadoEquipoRepository.dbHelper.actualizar(
        'censo_activo',
        {
          'intentos_sync': numeroIntento,
          'ultimo_intento': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [estadoId],
      );
    } catch (e) {
      _logger.w('⚠️ Error actualizando último intento: $e');
    }
  }

  Future<String?> _obtenerEdfVendedorIdDesdeUsuarioId(int? usuarioId) async {
    try {
      if (usuarioId == null) return null;

      final usuarioEncontrado = await _estadoEquipoRepository.dbHelper.consultar(
        'Users',
        where: 'id = ?',
        whereArgs: [usuarioId],
        limit: 1,
      );

      if (usuarioEncontrado.isNotEmpty) {
        return usuarioEncontrado.first['edf_vendedor_id'] as String?;
      }
      return null;
    } catch (e) {
      _logger.e('❌ Error resolviendo edfvendedorid: $e');
      return null;
    }
  }

  Future<bool> _verificarEquipoAsignado(String? equipoId, dynamic clienteId) async {
    try {
      if (equipoId == null || clienteId == null) return false;

      final equipoRepository = EquipoRepository();
      return await equipoRepository.verificarAsignacionEquipoCliente(
        equipoId,
        _convertirAInt(clienteId),
      );
    } catch (e) {
      _logger.w('⚠️ Error verificando asignación: $e');
      return false;
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