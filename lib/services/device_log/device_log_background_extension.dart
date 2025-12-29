import 'dart:async';

import 'package:workmanager/workmanager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ada_app/repositories/device_log_repository.dart';
import 'package:ada_app/services/data/database_helper.dart';
import 'package:ada_app/models/device_log.dart';
import 'package:ada_app/services/post/device_log_post_service.dart';
import 'package:ada_app/utils/device_info_helper.dart';
import 'package:ada_app/services/api/auth_service.dart';
import 'package:logger/logger.dart';
import 'package:ada_app/services/device_log/device_log_upload_service.dart';

import 'package:shared_preferences/shared_preferences.dart';

const String taskName = 'simplePeriodicTask';
const String uniqueName = 'json_gl_logging_task';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final logger = Logger();
    logger.i("WorkManager Task Started: $task");

    try {
      if (task == taskName) {
        await DeviceLogBackgroundExtension.ejecutarLoggingDesdeBackground();
      }

      return Future.value(true);
    } catch (e) {
      logger.e("Error en WorkManager Task: $e");
      return Future.value(false);
    }
  });
}

class BackgroundLogConfig {
  static int horaInicio = 9;
  static int horaFin = 17;

  static const String keyHoraInicio = 'work_hours_start';
  static const String keyHoraFin = 'work_hours_end';
  static const String keyIntervalo = 'work_interval_minutes';

  static Duration intervalo = Duration(minutes: 15);

  static const int maxReintentos = 3;
  static const List<int> tiemposBackoff = [5, 10, 20];

  static int obtenerTiempoEspera(int numeroIntento) {
    final index = numeroIntento - 1;
    if (index >= 0 && index < tiemposBackoff.length) {
      return tiemposBackoff[index];
    }
    return tiemposBackoff.last;
  }
}

class DeviceLogBackgroundExtension {
  static final _logger = Logger();
  static bool _isInitialized = false;

  static Future<bool> _verificarSesionActiva() async {
    try {
      final authService = AuthService();
      final tieneSession = await authService.hasUserLoggedInBefore();

      if (!tieneSession) {
        _logger.w('No active session - stopping auto logging');
        await detener();
        return false;
      }

      return true;
    } catch (e) {
      _logger.e('Error checking session: $e');
      return false;
    }
  }

  static Future<void> inicializar({bool verificarSesion = true}) async {
    try {
      if (_isInitialized) return;

      _logger.i('Inicializando WorkManager para DeviceLog...');

      await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

      await cargarConfiguracionHorario();

      final frequency = BackgroundLogConfig.intervalo.inMinutes < 15
          ? Duration(minutes: 15)
          : BackgroundLogConfig.intervalo;

      _logger.i(
        'Registrando tarea periódica (Frecuencia: ${frequency.inMinutes} min)...',
      );

      await Workmanager().registerPeriodicTask(
        uniqueName,
        taskName,
        frequency: frequency,
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: true,
        ),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
        initialDelay: Duration(seconds: 10),
        backoffPolicy: BackoffPolicy.linear,
        backoffPolicyDelay: Duration(seconds: 30),
      );

      _isInitialized = true;
      _logger.i('WorkManager inicializado y tarea registrada');

      await DeviceInfoHelper.mostrarEstadoDisponibilidad();
    } catch (e) {
      _logger.e('Error inicializando WorkManager: $e');
    }
  }

  static Future<void> cargarConfiguracionHorario() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();

      BackgroundLogConfig.horaInicio =
          prefs.getInt(BackgroundLogConfig.keyHoraInicio) ?? 9;
      BackgroundLogConfig.horaFin =
          prefs.getInt(BackgroundLogConfig.keyHoraFin) ?? 17;

      final intervaloMin = prefs.getInt(BackgroundLogConfig.keyIntervalo) ?? 15;
      BackgroundLogConfig.intervalo = Duration(minutes: intervaloMin);

      _logger.i(
        'Config loaded - Hours: ${BackgroundLogConfig.horaInicio}-${BackgroundLogConfig.horaFin} | Interval: ${intervaloMin}min (WM min: 15)',
      );
    } catch (e) {
      _logger.e('Error cargando configuración: $e');
    }
  }

  static Future<void> guardarConfiguracionHorario(
    int inicio,
    int fin, {
    int? intervaloMinutos,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(BackgroundLogConfig.keyHoraInicio, inicio);
      await prefs.setInt(BackgroundLogConfig.keyHoraFin, fin);

      BackgroundLogConfig.horaInicio = inicio;
      BackgroundLogConfig.horaFin = fin;

      if (intervaloMinutos != null) {
        final int safeInterval = intervaloMinutos < 15 ? 15 : intervaloMinutos;

        await prefs.setInt(BackgroundLogConfig.keyIntervalo, safeInterval);
        BackgroundLogConfig.intervalo = Duration(minutes: safeInterval);
      }

      await inicializar();
    } catch (e) {
      _logger.e('Error guardando configuración: $e');
      rethrow;
    }
  }

  static Future<void> ejecutarLoggingDesdeBackground() async {
    await _ejecutarLoggingCompleto();
  }

  static Future<void> _ejecutarLoggingCompleto() async {
    try {
      await cargarConfiguracionHorario();

      if (!await _verificarSesionActiva()) {
        _logger.w('LOGGING SKIPPED: No hay sesión activa');
        return;
      }

      if (!estaEnHorarioTrabajo()) {
        _logger.i(
          'Fuera del horario de trabajo (${BackgroundLogConfig.horaInicio}:00 - ${BackgroundLogConfig.horaFin}:00)',
        );
        return;
      }

      final hasPermission = await Permission.location.isGranted;
      final hasAlways = await Permission.locationAlways.isGranted;

      if (!hasPermission && !hasAlways) {
        _logger.w('LOGGING SKIPPED: Sin permisos de ubicación');
        return;
      }

      final log = await DeviceInfoHelper.crearDeviceLog();
      if (log == null) return;

      await _guardarEnBD(log);
      await _intentarEnviarConReintentos(log);

      _logger.i('Intentando sincronizar logs pendientes...');
      await DeviceLogUploadService.sincronizarDeviceLogsPendientes();
    } catch (e) {
      _logger.e('Error en ejecución de logging background: $e');
      rethrow;
    }
  }

  static bool estaEnHorarioTrabajo() {
    final now = DateTime.now();
    final hora = now.hour;
    final esDiaLaboral = now.weekday >= 1 && now.weekday <= 6;
    final esHorarioTrabajo =
        hora >= BackgroundLogConfig.horaInicio &&
        hora < BackgroundLogConfig.horaFin;

    return esDiaLaboral && esHorarioTrabajo;
  }

  static Future<void> _guardarEnBD(DeviceLog log) async {
    final db = await DatabaseHelper().database;
    final repository = DeviceLogRepository(db);
    await repository.guardarLog(
      id: log.id,
      employeeId: log.employeeId,
      latitud: double.parse(log.latitudLongitud.split(',')[0]),
      longitud: double.parse(log.latitudLongitud.split(',')[1]),
      bateria: log.bateria,
      modelo: log.modelo,
    );
    _logger.i('Log guardado en BD local');
  }

  static Future<void> _intentarEnviarConReintentos(DeviceLog log) async {
    try {
      final resultado = await DeviceLogPostService.enviarDeviceLog(
        log,
        userId: log.employeeId,
      );
      if (resultado['exito'] == true) {
        _logger.i('Log enviado y sincronizado inmediatamente');
        await _marcarComoSincronizado(log.id);
      } else {
        _logger.w('Envío inmediato falló - quedará pendiente para batch sync');
      }
    } catch (e) {
      _logger.e('Error envío inmediato: $e');
    }
  }

  static Future<void> _marcarComoSincronizado(String logId) async {
    final db = await DatabaseHelper().database;
    await db.update(
      'device_log',
      {'sincronizado': 1},
      where: 'id = ?',
      whereArgs: [logId],
    );
  }

  static Future<void> detener() async {
    await Workmanager().cancelByUniqueName(uniqueName);
    _isInitialized = false;
    _logger.i('WorkManager Task Cancelled');
  }

  static Future<Map<String, dynamic>> obtenerEstado() async {
    return {
      'activo': _isInitialized,
      'engine': 'WorkManager',
      'min_interval': '15m (Android limitation)',
      'configured_interval': '${BackgroundLogConfig.intervalo.inMinutes}m',
    };
  }

  static Future<void> ejecutarManual({bool verificarSesion = true}) async {
    await _ejecutarLoggingCompleto();
  }

  static Future<void> mostrarConfiguracion() async {
    _logger.i(
      'WorkManager Configuration: Interval=${BackgroundLogConfig.intervalo.inMinutes}m',
    );
  }

  static Future<void> inicializarDespuesDeLogin() async => inicializar();
  static bool get estaActivo => _isInitialized;
}
