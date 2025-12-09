// lib/services/sync/operacion_comercial_sync_service.dart

import 'dart:async';

import 'package:ada_app/repositories/operacion_comercial_repository.dart';
import 'package:ada_app/models/operaciones_comerciales/operacion_comercial.dart';
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/services/error_log/error_log_service.dart';

import '../post/operaciones_comerciales_post_service.dart';

class OperacionComercialSyncService {
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
  }) : _operacionRepository =
           operacionRepository ?? OperacionComercialRepositoryImpl();

  /// Sincroniza todas las operaciones pendientes o con error.
  /// CATCH PADRE #1: Maneja errores de sincronización de múltiples operaciones.
  Future<Map<String, int>> sincronizarOperacionesPendientes(
    int usuarioId,
  ) async {
    int operacionesExitosas = 0;
    int totalFallidas = 0;

    try {
      final operacionesCreadas = await _operacionRepository
          .obtenerOperacionesPendientes();
      final operacionesError = await _operacionRepository
          .obtenerOperacionesConError();
      final operacionesErrorListas =
          await _filtrarOperacionesListasParaReintento(operacionesError);

      final todasLasOperaciones = [
        ...operacionesCreadas,
        ...operacionesErrorListas,
      ];

      final operacionesAProcesar = todasLasOperaciones.take(20);

      for (final operacion in operacionesAProcesar) {
        try {
          await _sincronizarOperacionIndividual(operacion, usuarioId);
          operacionesExitosas++;
        } catch (e) {
          totalFallidas++;
          // El error ya fue logueado en OperacionesComercialesPostService
        }

        await Future.delayed(Duration(milliseconds: 500));
      }

      return {
        'operaciones_exitosas': operacionesExitosas,
        'fallidas': totalFallidas,
        'total': operacionesExitosas,
      };
    } catch (e) {
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

  /// Sincroniza una operación individual.
  /// Los errores se propagan con rethrow para que el catch padre los maneje.
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
        return;
      }
      await _actualizarIntentoSincronizacion(operacionId, numeroIntento);

      //TODO ESTOY SINCRONIZANDO EN BACKGROUND
      await OperacionesComercialesPostService.enviarOperacion(operacion);
    } catch (e) {
      rethrow;
    }
  }

  /// Filtra operaciones con error que están listas para reintentar.
  Future<List<OperacionComercial>> _filtrarOperacionesListasParaReintento(
    List<OperacionComercial> operacionesError,
  ) async {
    final operacionesListas = <OperacionComercial>[];
    final ahora = DateTime.now();

    for (final operacion in operacionesError) {
      try {
        final intentos = operacion.syncRetryCount;

        if (intentos >= maxIntentos) {
          continue;
        }

        if (operacion.syncedAt == null) {
          operacionesListas.add(operacion);
          continue;
        }

        final minutosEspera = _calcularProximoIntento(intentos);
        if (minutosEspera < 0) continue;

        final tiempoProximoIntento = operacion.syncedAt!.add(
          Duration(minutes: minutosEspera),
        );

        if (ahora.isAfter(tiempoProximoIntento)) {
          operacionesListas.add(operacion);
        }
      } catch (e) {
        operacionesListas.add(operacion);
      }
    }

    return operacionesListas;
  }

  /// Calcula minutos de espera según número de intentos (backoff exponencial).
  int _calcularProximoIntento(int numeroIntento) {
    if (numeroIntento > maxIntentos) return -1;

    switch (numeroIntento) {
      case 1:
        return 1;
      case 2:
        return 5;
      case 3:
        return 10;
      case 4:
        return 15;
      case 5:
        return 20;
      case 6:
        return 25;
      default:
        return 30;
    }
  }

  /// Actualiza el contador de intentos de sincronización.
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
      rethrow;
    }
  }

  /// Inicia la sincronización automática periódica.
  static void iniciarSincronizacionAutomatica(int usuarioId) {
    if (_syncActivo && _usuarioActual == usuarioId) {
      return;
    }

    detenerSincronizacionAutomatica();

    _usuarioActual = usuarioId;
    _syncActivo = true;

    _syncTimer = Timer.periodic(intervaloTimer, (timer) async {
      await _ejecutarSincronizacionAutomatica();
    });

    Timer(const Duration(seconds: 15), () async {
      // await _ejecutarSincronizacionAutomatica();
    });
  }

  /// Detiene la sincronización automática.
  static void detenerSincronizacionAutomatica() {
    if (_syncTimer != null) {
      _syncTimer!.cancel();
      _syncTimer = null;
      _syncActivo = false;
      _syncEnProgreso = false;
      _usuarioActual = null;
    }
  }

  /// Ejecuta la sincronización automática.
  /// Los errores son manejados por sincronizarOperacionesPendientes internamente.
  static Future<void> _ejecutarSincronizacionAutomatica() async {
    if (_syncEnProgreso || !_syncActivo || _usuarioActual == null) return;

    _syncEnProgreso = true;

    try {
      final conexion = await BaseSyncService.testConnection();
      if (!conexion.exito) {
        return;
      }

      final service = OperacionComercialSyncService();
      await service.sincronizarOperacionesPendientes(_usuarioActual!);
    } catch (e) {
      // Error handling managed internally
    } finally {
      _syncEnProgreso = false;
    }
  }

  static bool get esSincronizacionActiva => _syncActivo;
  static bool get estaEnProgreso => _syncEnProgreso;
  static int? get usuarioActual => _usuarioActual;
}
