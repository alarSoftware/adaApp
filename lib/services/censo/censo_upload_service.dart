import 'dart:async';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:ada_app/repositories/censo_activo_repository.dart';
import 'package:ada_app/repositories/censo_activo_foto_repository.dart';
import 'package:ada_app/repositories/equipo_repository.dart';
import 'package:ada_app/services/censo/censo_api_mapper.dart';
import 'package:ada_app/services/post/base_post_service.dart';
import 'package:ada_app/services/error_log/error_log_service.dart'; // 🆕 AGREGAR
import 'censo_log_service.dart';

class CensoUploadService {
  final Logger _logger = Logger();
  final Uuid _uuid = const Uuid();
  final EstadoEquipoRepository _estadoEquipoRepository;
  final CensoActivoFotoRepository _fotoRepository;
  final CensoLogService _logService;

  static const String _tableName = 'censo_activo'; // 🆕 AGREGAR
  static const String _endpoint = '/censoActivo/insertCensoActivo'; // 🆕 AGREGAR

  static Timer? _syncTimer;
  static bool _syncActivo = false;
  static int? _usuarioActual;

  CensoUploadService({
    EstadoEquipoRepository? estadoEquipoRepository,
    CensoActivoFotoRepository? fotoRepository,
    CensoLogService? logService,
  })  : _estadoEquipoRepository = estadoEquipoRepository ?? EstadoEquipoRepository(),
        _fotoRepository = fotoRepository ?? CensoActivoFotoRepository(),
        _logService = logService ?? CensoLogService();

  /// Envía censo al servidor usando BasePostService
  Future<Map<String, dynamic>> enviarCensoAlServidor(
      Map<String, dynamic> datos, {
        int timeoutSegundos = 60,
        bool guardarLog = false,
        String? userId,
      }) async {
    final estadoId = datos['id'] ?? datos['id_local'];

    try {
      _logger.i('📤 Preparando envío de censo...');

      final timestamp = DateTime.now().toIso8601String();

      if (guardarLog) {
        await _logService.guardarLogPost(
          url: 'API_ENDPOINT',
          headers: {'Content-Type': 'application/json'},
          body: datos,
          timestamp: timestamp,
          censoActivoId: estadoId,
        );
      }

      // ✅ USAR BasePostService con logging
      final resultado = await BasePostService.post(
        endpoint: _endpoint,
        body: datos,
        timeout: Duration(seconds: timeoutSegundos),
        tableName: _tableName,
        registroId: estadoId?.toString(),
        userId: userId,
      );

      _logger.i('✅ Respuesta recibida: ${resultado['exito']}');
      return resultado;

    } catch (e) {
      _logger.e('❌ Error en envío: $e');

      // 🚨 LOG: Error general en envío
      await ErrorLogService.logError(
        tableName: _tableName,
        operation: 'enviar_censo',
        errorMessage: 'Error de conexión: $e',
        errorType: 'upload',
        registroFailId: estadoId?.toString(),
        userId: userId,
      );

      return {
        'exito': false,
        'mensaje': 'Error de conexión: $e',
      };
    }
  }

  /// Prepara datos usando el mapper correctamente
  Future<Map<String, dynamic>> _prepararPayloadConMapper(
      String estadoId,
      List<dynamic> fotos,
      String? userId,
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
        // 🚨 LOG: Censo no encontrado
        await ErrorLogService.logValidationError(
          tableName: _tableName,
          operation: 'preparar_payload',
          errorMessage: 'No se encontró el censo en BD local',
          registroFailId: estadoId,
          userId: userId,
        );

        throw Exception('No se encontró el censo: $estadoId');
      }

      final datosLocales = maps.first;
      final usuarioId = datosLocales['usuario_id'] as int?;

      if (usuarioId == null) {
        // 🚨 LOG: usuario_id faltante
        await ErrorLogService.logValidationError(
          tableName: _tableName,
          operation: 'preparar_payload',
          errorMessage: 'usuario_id es requerido',
          registroFailId: estadoId,
        );

        throw Exception('usuario_id es requerido para el censo: $estadoId');
      }

      // Resolver edfVendedorId
      final edfVendedorId = await _obtenerEdfVendedorIdDesdeUsuarioId(usuarioId);
      if (edfVendedorId == null) {
        // 🚨 LOG: edfVendedorId no encontrado
        await ErrorLogService.logValidationError(
          tableName: _tableName,
          operation: 'preparar_payload',
          errorMessage: 'No se pudo resolver edfVendedorId para usuario_id: $usuarioId',
          registroFailId: estadoId,
          userId: usuarioId.toString(),
        );

        throw Exception('No se pudo resolver edfVendedorId para usuario_id: $usuarioId');
      }

      // Verificar asignación
      final estaAsignado = await _verificarEquipoAsignado(
        datosLocales['equipo_id']?.toString(),
        datosLocales['cliente_id'],
      );

      final datosLocalesMutable = Map<String, dynamic>.from(datosLocales);
      datosLocalesMutable['ya_asignado'] = estaAsignado;

      _logger.i('🔍 Equipo ${datosLocales['equipo_id']} para cliente ${datosLocales['cliente_id']}: ${estaAsignado ? "ASIGNADO" : "PENDIENTE"}');

      // Usar mapper
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

      // 🚨 LOG: Error preparando payload (si no se logueó antes)
      if (!e.toString().contains('No se encontró') &&
          !e.toString().contains('requerido') &&
          !e.toString().contains('resolver')) {
        await ErrorLogService.logError(
          tableName: _tableName,
          operation: 'preparar_payload',
          errorMessage: 'Error preparando payload: $e',
          errorType: 'preparation',
          registroFailId: estadoId,
          userId: userId,
        );
      }

      rethrow;
    }
  }

  // Helpers sin cambios
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

  // ==================== SINCRONIZACIÓN ====================

  /// Sincroniza un censo específico en segundo plano
  Future<void> sincronizarCensoEnBackground(
      String estadoId,
      Map<String, dynamic> datos,
      ) async {
    Future.delayed(Duration.zero, () async {
      String? userId;

      try {
        _logger.i('🔄 Sincronización background para: $estadoId');

        // Verificar existencia
        final maps = await _estadoEquipoRepository.dbHelper.consultar(
          'censo_activo',
          where: 'id = ?',
          whereArgs: [estadoId],
          limit: 1,
        );

        if (maps.isEmpty) {
          _logger.e('❌ No se encontró el estado: $estadoId');

          // 🚨 LOG: Estado no encontrado
          await ErrorLogService.logValidationError(
            tableName: _tableName,
            operation: 'sync_background',
            errorMessage: 'Estado no encontrado en BD local',
            registroFailId: estadoId,
          );

          return;
        }

        userId = maps.first['usuario_id']?.toString();

        // Obtener fotos
        final fotos = await _fotoRepository.obtenerFotosPorCenso(estadoId);
        _logger.i('📸 Fotos encontradas: ${fotos.length}');

        // Preparar payload
        final datosParaApi = await _prepararPayloadConMapper(estadoId, fotos, userId);

        // Registrar intento
        await _actualizarUltimoIntento(estadoId, 1);

        // Enviar
        final respuesta = await enviarCensoAlServidor(
          datosParaApi,
          timeoutSegundos: 45,
          userId: userId,
        );

        // Actualizar estado
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

          // 🚨 LOG: Error en primer intento
          await ErrorLogService.logError(
            tableName: _tableName,
            operation: 'sync_background',
            errorMessage: 'Error en primer intento: ${respuesta['mensaje']}',
            errorType: 'sync',
            registroFailId: estadoId,
            syncAttempt: 1,
            userId: userId,
          );

          final proximoIntento = _calcularProximoIntento(1);
          _logger.w('⚠️ Error - reintento en $proximoIntento minuto(s)');
        }

      } catch (e) {
        _logger.e('💥 Excepción en sincronización: $e');

        // 🚨 LOG: Excepción en background sync
        await ErrorLogService.logError(
          tableName: _tableName,
          operation: 'sync_background',
          errorMessage: 'Excepción en sincronización: $e',
          errorType: 'exception',
          registroFailId: estadoId,
          userId: userId,
        );

        await _actualizarUltimoIntento(estadoId, 1);
        await _estadoEquipoRepository.marcarComoError(estadoId, 'Excepción: $e');
      }
    });
  }

  /// Sincroniza todos los registros pendientes
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

          // 🚨 LOG: Error en sincronización individual
          await ErrorLogService.logError(
            tableName: _tableName,
            operation: 'sync_pendientes',
            errorMessage: 'Error sincronizando censo: $e',
            errorType: 'sync_batch',
            registroFailId: registro.id,
            userId: usuarioId.toString(),
          );

          if (registro.id != null) {
            await _estadoEquipoRepository.marcarComoError(
              registro.id!,
              'Excepción: $e',
            );
          }
        }
      }

      _logger.i('✅ Completado - Exitosos: $exitosos, Fallidos: $fallidos');

      // 🚨 LOG: Alta tasa de fallos
      if (fallidos > 0 && fallidos >= exitosos) {
        await ErrorLogService.logError(
          tableName: _tableName,
          operation: 'sync_pendientes',
          errorMessage: 'Alta tasa de fallos: $fallidos de ${todosLosRegistros.length}',
          errorType: 'sync_batch_high_failure',
          userId: usuarioId.toString(),
        );
      }

      return {
        'exitosos': exitosos,
        'fallidos': fallidos,
        'total': todosLosRegistros.length,
      };

    } catch (e) {
      _logger.e('💥 Error en sincronización: $e');

      // 🚨 LOG: Error general en batch
      await ErrorLogService.logError(
        tableName: _tableName,
        operation: 'sync_pendientes',
        errorMessage: 'Error en sincronización masiva: $e',
        errorType: 'sync_batch',
        userId: usuarioId.toString(),
      );

      return {'exitosos': 0, 'fallidos': 0, 'total': 0};
    }
  }

  /// Reintenta el envío de un censo específico
  Future<Map<String, dynamic>> reintentarEnvioCenso(
      String estadoId,
      int usuarioId,
      String? edfVendedorId,
      ) async {
    try {
      _logger.i('🔁 Reintentando: $estadoId');

      // Obtener intentos previos
      final intentosPrevios = await _obtenerNumeroIntentos(estadoId);
      final numeroIntento = intentosPrevios + 1;

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
      final datosParaApi = await _prepararPayloadConMapper(
        estadoId,
        fotos,
        usuarioId.toString(),
      );

      final respuesta = await enviarCensoAlServidor(
        datosParaApi,
        timeoutSegundos: 45,
        userId: usuarioId.toString(),
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

        // 🚨 LOG: Reintento fallido
        await ErrorLogService.logError(
          tableName: _tableName,
          operation: 'RETRY_POST',
          errorMessage: 'Reintento #$numeroIntento falló: ${respuesta['mensaje']}',
          errorType: 'retry_failed',
          registroFailId: estadoId,
          syncAttempt: numeroIntento,
          userId: usuarioId.toString(),
        );

        return {'success': false, 'error': respuesta['mensaje']};
      }

    } catch (e) {
      _logger.e('💥 Error en reintento: $e');

      // 🚨 LOG: Excepción en reintento
      await ErrorLogService.logError(
        tableName: _tableName,
        operation: 'RETRY_POST',
        errorMessage: 'Excepción en reintento: $e',
        errorType: 'retry_exception',
        registroFailId: estadoId,
        userId: usuarioId.toString(),
      );

      await _estadoEquipoRepository.marcarComoError(estadoId, 'Excepción: $e');
      return {'success': false, 'error': 'Error: $e'};
    }
  }

  // ==================== SINCRONIZACIÓN AUTOMÁTICA ====================

  static void iniciarSincronizacionAutomatica(int usuarioId) {
    if (_syncActivo) {
      Logger().i('⚠️ Ya está activa');
      return;
    }

    _usuarioActual = usuarioId;
    _syncActivo = true;

    Logger().i('🚀 Iniciando sincronización automática cada 1 minuto...');

    _syncTimer = Timer.periodic(Duration(minutes: 1), (timer) async {
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
      _usuarioActual = null;
      Logger().i('⏹️ Sincronización automática detenida');
    }
  }

  static Future<void> _ejecutarSincronizacionAutomatica() async {
    if (!_syncActivo || _usuarioActual == null) return;

    try {
      final logger = Logger();
      logger.i('🔄 Ejecutando sincronización automática...');

      final service = CensoUploadService();
      final resultado = await service.sincronizarRegistrosPendientes(_usuarioActual!);

      if (resultado['total']! > 0) {
        logger.i('✅ Auto-sync: ${resultado['exitosos']}/${resultado['total']}');
      }

    } catch (e) {
      Logger().e('❌ Error: $e');

      // 🚨 LOG: Error en auto-sync
      await ErrorLogService.logError(
        tableName: _tableName,
        operation: 'auto_sync',
        errorMessage: 'Error en sincronización automática: $e',
        errorType: 'auto_sync',
        userId: _usuarioActual?.toString(),
      );
    }
  }

  static bool get esSincronizacionActiva => _syncActivo;
  static int? get usuarioActualSync => _usuarioActual;

  static Future<Map<String, int>?> forzarSincronizacion() async {
    if (!_syncActivo || _usuarioActual == null) {
      Logger().w('⚠️ No se puede forzar');
      return null;
    }

    Logger().i('⚡ Forzando sincronización...');
    final service = CensoUploadService();
    return await service.sincronizarRegistrosPendientes(_usuarioActual!);
  }

  // ==================== MÉTODOS PRIVADOS - BACKOFF ====================

  Future<void> _sincronizarRegistroIndividualConBackoff(
      dynamic registro,
      int usuarioId,
      ) async {
    final fotos = await _fotoRepository.obtenerFotosPorCenso(registro.id!);
    final intentosPrevios = await _obtenerNumeroIntentos(registro.id!);
    final numeroIntento = intentosPrevios + 1;

    _logger.i('🔄 Sincronizando ${registro.id} (intento #$numeroIntento)');

    final datosParaApi = await _prepararPayloadConMapper(
      registro.id!,
      fotos,
      usuarioId.toString(),
    );
    await _actualizarUltimoIntento(registro.id!, numeroIntento);

    final respuesta = await enviarCensoAlServidor(
      datosParaApi,
      timeoutSegundos: 60,
      userId: usuarioId.toString(),
    );

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

      // 🚨 LOG: Intento fallido con backoff
      await ErrorLogService.logError(
        tableName: _tableName,
        operation: 'sync_individual',
        errorMessage: 'Error en intento #$numeroIntento: ${respuesta['mensaje']}',
        errorType: 'sync_retry',
        registroFailId: registro.id!,
        syncAttempt: numeroIntento,
        userId: usuarioId.toString(),
      );

      final proximoIntento = _calcularProximoIntento(numeroIntento);
      _logger.w('⚠️ Error intento #$numeroIntento - próximo en $proximoIntento min');
    }
  }

  // Resto de métodos sin cambios...
  Future<List<dynamic>> _filtrarRegistrosListosParaReintento(List<dynamic> registrosError) async {
    final registrosListos = <dynamic>[];
    final ahora = DateTime.now();

    for (final registro in registrosError) {
      try {
        final intentos = await _obtenerNumeroIntentos(registro.id!);
        final ultimoIntento = await _obtenerUltimoIntento(registro.id!);

        if (ultimoIntento == null) {
          registrosListos.add(registro);
          continue;
        }

        final minutosEspera = _calcularProximoIntento(intentos);
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
}