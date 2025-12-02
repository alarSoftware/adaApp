// lib/services/sync/operacion_comercial_sync_service.dart

import 'dart:async';
import 'package:logger/logger.dart';
import 'package:ada_app/repositories/operacion_comercial_repository.dart';
import 'package:ada_app/models/operaciones_comerciales/operacion_comercial.dart';
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/services/error_log/error_log_service.dart';

class OperacionComercialSyncService {
  final Logger _logger = Logger();
  final OperacionComercialRepositoryImpl _operacionRepository;

  static const String _tableName = 'operacion_comercial';
  static const int maxIntentos = 10;
  static const Duration intervaloTimer = Duration(minutes: 1);

  static Timer? _syncTimer;
  static bool _syncActivo = false;
  static bool _syncEnProgreso = false;
  static int? _usuarioActual;

  OperacionComercialSyncService({
    OperacionComercialRepositoryImpl? operacionRepository,
  }) : _operacionRepository = operacionRepository ?? OperacionComercialRepositoryImpl();

  /// Sincroniza todas las operaciones pendientes o con error
  Future<Map<String, int>> sincronizarOperacionesPendientes(int usuarioId) async {
    _logger.i('=== SINCRONIZACIÓN PERIÓDICA DE OPERACIONES ===');

    int operacionesExitosas = 0;
    int totalFallidas = 0;

    try {
      // Obtener operaciones creadas (pendientes)
      final operacionesCreadas = await _operacionRepository.obtenerOperacionesPendientes();

      // Obtener operaciones con error que están listas para reintentar
      final operacionesError = await _operacionRepository.obtenerOperacionesConError();
      final operacionesErrorListas = await _filtrarOperacionesListasParaReintento(
        operacionesError,
      );

      final todasLasOperaciones = [...operacionesCreadas, ...operacionesErrorListas];

      _logger.i('Total operaciones a procesar: ${todasLasOperaciones.length}');
      _logger.i('  - Creadas: ${operacionesCreadas.length}');
      _logger.i('  - Con error listas: ${operacionesErrorListas.length}');

      // Procesar máximo 20 operaciones por vez
      final operacionesAProcesar = todasLasOperaciones.take(20);

      for (final operacion in operacionesAProcesar) {
        try {
          await _sincronizarOperacionIndividual(operacion, usuarioId);
          operacionesExitosas++;
        } catch (e, stacktrace) {
          _logger.e('Error en operación ${operacion.id}: $e', stackTrace: stacktrace);
          totalFallidas++;

          if (operacion.id != null) {
            await _operacionRepository.marcarComoError(
              operacion.id!,
              'Excepción: ${e.toString()}',
            );

            await ErrorLogService.manejarExcepcion(
              e,
              operacion.id!,
              null,
              usuarioId,
              _tableName,
            );
          }
        }

        // Pequeña pausa entre operaciones
        await Future.delayed(Duration(milliseconds: 500));
      }

      _logger.i('=== SINCRONIZACIÓN COMPLETADA ===');
      _logger.i('   - Exitosas: $operacionesExitosas');
      _logger.i('   - Fallidas: $totalFallidas');

      return {
        'operaciones_exitosas': operacionesExitosas,
        'fallidas': totalFallidas,
        'total': operacionesExitosas,
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
        'operaciones_exitosas': operacionesExitosas,
        'fallidas': totalFallidas,
        'total': 0,
      };
    }
  }

  /// Sincroniza una operación individual
  Future<void> _sincronizarOperacionIndividual(
      OperacionComercial operacion,
      int usuarioId,
      ) async {
    try {
      final operacionId = operacion.id;
      if (operacionId == null) {
        throw Exception('Operación sin ID');
      }

      final intentosPrevios = operacion.syncRetryCount;
      final numeroIntento = intentosPrevios + 1;

      if (numeroIntento > maxIntentos) {
        _logger.w('Operación $operacionId alcanzó máximo de intentos ($maxIntentos)');
        return;
      }

      _logger.i('Sincronizando operación $operacionId (intento #$numeroIntento/$maxIntentos)');

      // Actualizar contador de intentos
      await _actualizarIntentoSincronizacion(operacionId, numeroIntento);

      // Intentar sincronizar
      await _operacionRepository.sincronizarOperacion(operacionId);

      _logger.i('✅ Operación $operacionId sincronizada exitosamente');

    } catch (e) {
      _logger.e('❌ Error sincronizando operación: $e');
      rethrow;
    }
  }

  /// Reintento manual de una operación
  Future<Map<String, dynamic>> reintentarEnvioOperacion(
      String operacionId,
      int usuarioId,
      ) async {
    bool success = false;
    String message = '';

    try {
      _logger.i('Reintento manual de operación: $operacionId');

      // Marcar como pendiente antes de reintentar
      await _operacionRepository.marcarPendienteSincronizacion(operacionId);

      // Intentar sincronizar
      await _operacionRepository.sincronizarOperacion(operacionId);

      // Verificar el resultado
      final operacion = await _operacionRepository.obtenerOperacionPorId(operacionId);

      if (operacion == null) {
        throw Exception('Operación no encontrada después del envío');
      }

      if (operacion.syncStatus == 'migrado') {
        success = true;
        message = 'Operación sincronizada correctamente';
      } else if (operacion.syncStatus == 'error') {
        success = false;
        message = operacion.syncError ?? 'Error desconocido';
      } else {
        success = false;
        message = 'Estado de sincronización: ${operacion.syncStatus}';
      }

    } catch (e, stackTrace) {
      _logger.e('Error en reintentarEnvioOperacion: $e', stackTrace: stackTrace);
      success = false;
      message = e.toString();

      await ErrorLogService.manejarExcepcion(
        e,
        operacionId,
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

  /// Filtra operaciones con error que están listas para reintentar
  Future<List<OperacionComercial>> _filtrarOperacionesListasParaReintento(
      List<OperacionComercial> operacionesError,
      ) async {
    final operacionesListas = <OperacionComercial>[];
    final ahora = DateTime.now();

    for (final operacion in operacionesError) {
      try {
        final intentos = operacion.syncRetryCount;

        // Si alcanzó el máximo, no reintentar
        if (intentos >= maxIntentos) {
          _logger.w('Operación ${operacion.id} alcanzó máximo de reintentos');
          continue;
        }

        // Si no tiene syncedAt (último intento), está lista
        if (operacion.syncedAt == null) {
          operacionesListas.add(operacion);
          continue;
        }

        // Calcular tiempo de espera según número de intentos
        final minutosEspera = _calcularProximoIntento(intentos);
        if (minutosEspera < 0) continue;

        final tiempoProximoIntento = operacion.syncedAt!.add(
          Duration(minutes: minutosEspera),
        );

        // Si ya pasó el tiempo de espera, reintentar
        if (ahora.isAfter(tiempoProximoIntento)) {
          _logger.i('Operación ${operacion.id} lista para reintento (esperó $minutosEspera min)');
          operacionesListas.add(operacion);
        } else {
          final minutosRestantes = tiempoProximoIntento.difference(ahora).inMinutes;
          _logger.d('Operación ${operacion.id} esperará $minutosRestantes min más');
        }
      } catch (e) {
        _logger.w('Error verificando operación ${operacion.id}: $e');
        // En caso de error, agregar para reintentar
        operacionesListas.add(operacion);
      }
    }

    return operacionesListas;
  }

  /// Calcula minutos de espera según número de intentos (backoff exponencial)
  int _calcularProximoIntento(int numeroIntento) {
    if (numeroIntento > maxIntentos) return -1;

    switch (numeroIntento) {
      case 1: return 1;   // 1 minuto
      case 2: return 5;   // 5 minutos
      case 3: return 10;  // 10 minutos
      case 4: return 15;  // 15 minutos
      case 5: return 20;  // 20 minutos
      case 6: return 25;  // 25 minutos
      default: return 30; // 30 minutos
    }
  }

  /// Actualiza el contador de intentos de sincronización
  Future<void> _actualizarIntentoSincronizacion(
      String operacionId,
      int numeroIntento,
      ) async {
    try {
      await _operacionRepository.actualizarIntentoSync(
        operacionId,
        numeroIntento,
      );
    } catch (e) {
      _logger.w('Error actualizando intento: $e');
      rethrow;
    }
  }

  // ==================== SINCRONIZACIÓN AUTOMÁTICA ====================

  /// Inicia la sincronización automática periódica
  static void iniciarSincronizacionAutomatica(int usuarioId) {
    if (_syncActivo && _usuarioActual == usuarioId) {
      Logger().w('Sincronización de operaciones ya activa para usuario $usuarioId');
      return;
    }

    detenerSincronizacionAutomatica();

    _usuarioActual = usuarioId;
    _syncActivo = true;

    Logger().i('Iniciando sincronización automática de operaciones cada ${intervaloTimer.inMinutes} min');

    // Timer periódico
    _syncTimer = Timer.periodic(intervaloTimer, (timer) async {
      await _ejecutarSincronizacionAutomatica();
    });

    // Primera ejecución después de 15 segundos
    Timer(const Duration(seconds: 15), () async {
      await _ejecutarSincronizacionAutomatica();
    });
  }

  /// Detiene la sincronización automática
  static void detenerSincronizacionAutomatica() {
    if (_syncTimer != null) {
      _syncTimer!.cancel();
      _syncTimer = null;
      _syncActivo = false;
      _syncEnProgreso = false;
      _usuarioActual = null;
      Logger().i('Sincronización automática de operaciones detenida');
    }
  }

  /// Ejecuta la sincronización automática
  static Future<void> _ejecutarSincronizacionAutomatica() async {
    if (_syncEnProgreso || !_syncActivo || _usuarioActual == null) return;

    _syncEnProgreso = true;

    try {
      // Verificar conexión
      final conexion = await BaseSyncService.testConnection();
      if (!conexion.exito) {
        Logger().w('Sin conexión al servidor: ${conexion.mensaje}');
        return;
      }

      // Ejecutar sincronización
      final service = OperacionComercialSyncService();
      final resultado = await service.sincronizarOperacionesPendientes(_usuarioActual!);

      if (resultado['total']! > 0) {
        Logger().i('Auto-sync operaciones: ${resultado['operaciones_exitosas']}/${resultado['total']}');
      }
    } catch (e, stackTrace) {
      Logger().e('Error en auto-sync de operaciones: $e', stackTrace: stackTrace);

      await ErrorLogService.manejarExcepcion(
        e,
        null,
        null,
        _usuarioActual,
        _tableName,
      );
    } finally {
      _syncEnProgreso = false;
    }
  }

  /// Fuerza una sincronización inmediata
  static Future<Map<String, int>?> forzarSincronizacion() async {
    if (!_syncActivo || _usuarioActual == null) {
      Logger().w('Sincronización automática no está activa');
      return null;
    }

    Logger().i('Forzando sincronización de operaciones...');
    final service = OperacionComercialSyncService();
    return await service.sincronizarOperacionesPendientes(_usuarioActual!);
  }

  // Getters de estado
  static bool get esSincronizacionActiva => _syncActivo;
  static bool get estaEnProgreso => _syncEnProgreso;
  static int? get usuarioActual => _usuarioActual;
}