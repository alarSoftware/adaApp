import 'dart:async';

import 'package:workmanager/workmanager.dart'; // 🆕 IMPORTAR WORKMANAGER
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

// 🆕 DEFINICIÓN DE TAREAS
const String taskName = 'simplePeriodicTask';
const String uniqueName = 'json_gl_logging_task';

// 🆕 DISPATCHER: Debe ser top-level o static
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final logger = Logger();
    logger.i("🔄 WorkManager Task Started: $task");

    try {
      // Re-inicializar servicios necesarios si es necesario
      // (SharedPreferences y SQFLite suelen funcionar bien en Isolate)

      if (task == taskName) {
        await DeviceLogBackgroundExtension.ejecutarLoggingDesdeBackground();
      }

      return Future.value(true);
    } catch (e) {
      logger.e("💥 Error en WorkManager Task: $e");
      return Future.value(false);
    }
  });
}

class BackgroundLogConfig {
  static int horaInicio = 9;
  static int horaFin = 17;

  /// Keys para SharedPreferences
  static const String keyHoraInicio = 'work_hours_start';
  static const String keyHoraFin = 'work_hours_end';
  static const String keyIntervalo = 'work_interval_minutes';

  ///  INTERVALO ENTRE REGISTROS (Mínimo 15 min para WorkManager)
  ///  Aunque se configure menos, Android forzará 15 min.
  static Duration intervalo = Duration(minutes: 15);

  /// NÚMERO MÁXIMO DE REINTENTOS
  static const int maxReintentos = 3; // Reducido para background task
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

  /// Inicializar servicio de logging con WorkManager
  static Future<void> inicializar({bool verificarSesion = true}) async {
    try {
      if (_isInitialized) return;

      _logger.i('🚀 Inicializando WorkManager para DeviceLog...');

      // 1. Inicializar WorkManager
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: false, // Poner true para ver notificaciones de debug
      );

      // 2. Cargar configuración para asegurar intervalo correcto
      await cargarConfiguracionHorario();

      // 3. Registrar Tarea Periódica
      // Nota: Android impone un mínimo de 15 minutos
      final frequency = BackgroundLogConfig.intervalo.inMinutes < 15
          ? Duration(minutes: 15)
          : BackgroundLogConfig.intervalo;

      _logger.i(
        '📅 Registrando tarea periódica (Frecuencia: ${frequency.inMinutes} min)...',
      );

      await Workmanager().registerPeriodicTask(
        uniqueName,
        taskName,
        frequency: frequency,
        constraints: Constraints(
          networkType: NetworkType.connected, // Preferible tener red
          requiresBatteryNotLow: true,
        ),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
        initialDelay: Duration(seconds: 10), // Pequeño delay inicial
        backoffPolicy: BackoffPolicy.linear,
        backoffPolicyDelay: Duration(seconds: 30),
      );

      _isInitialized = true;
      _logger.i('✅ WorkManager inicializado y tarea registrada');

      // Verificar disponibilidad de servicios
      await DeviceInfoHelper.mostrarEstadoDisponibilidad();
    } catch (e) {
      _logger.e('❌ Error inicializando WorkManager: $e');
    }
  }

  /// 🕒 Cargar horarios e intervalo desde SharedPreferences
  static Future<void> cargarConfiguracionHorario() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();

      BackgroundLogConfig.horaInicio =
          prefs.getInt(BackgroundLogConfig.keyHoraInicio) ?? 9;
      BackgroundLogConfig.horaFin =
          prefs.getInt(BackgroundLogConfig.keyHoraFin) ?? 17;

      // Cargar intervalo (respetando mínimo 15)
      final intervaloMin = prefs.getInt(BackgroundLogConfig.keyIntervalo) ?? 15;
      BackgroundLogConfig.intervalo = Duration(minutes: intervaloMin);

      _logger.i(
        'Config loaded - Hours: ${BackgroundLogConfig.horaInicio}-${BackgroundLogConfig.horaFin} | Interval: ${intervaloMin}min (WM min: 15)',
      );
    } catch (e) {
      _logger.e('Error cargando configuración: $e');
    }
  }

  /// 💾 Guardar nuevos horarios e intervalo
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
        // Enforce 15-minute minimum
        final int safeInterval = intervaloMinutos < 15 ? 15 : intervaloMinutos;

        await prefs.setInt(BackgroundLogConfig.keyIntervalo, safeInterval);
        BackgroundLogConfig.intervalo = Duration(minutes: safeInterval);
        // NOTA: Para cambiar el intervalo en WorkManager, se debe re-registrar la tarea
        // Esto se hará efectivo en la próxima inicialización o reinicio
      }

      // Reiniciar tarea para aplicar cambios inmediatamente si es necesario
      await inicializar();
    } catch (e) {
      _logger.e('Error guardando configuración: $e');
      rethrow;
    }
  }

  /// Método público expuesto para el Dispatcher
  static Future<void> ejecutarLoggingDesdeBackground() async {
    await _ejecutarLoggingCompleto();
  }

  /// Lógica principal de logging (Unificada)
  static Future<void> _ejecutarLoggingCompleto() async {
    try {
      await cargarConfiguracionHorario();

      // Verificar sesión
      if (!await _verificarSesionActiva()) {
        _logger.w('LOGGING SKIPPED: No hay sesión activa');
        return;
      }

      // Verificar Horario
      if (!estaEnHorarioTrabajo()) {
        _logger.i(
          'Fuera del horario de trabajo (${BackgroundLogConfig.horaInicio}:00 - ${BackgroundLogConfig.horaFin}:00)',
        );
        return;
      }

      // Verificar Permisos
      final hasPermission = await Permission.location.isGranted;
      // WorkManager corre en background, locationAlways es ideal
      final hasAlways = await Permission.locationAlways.isGranted;

      if (!hasPermission && !hasAlways) {
        _logger.w('LOGGING SKIPPED: Sin permisos de ubicación');
        return;
      }

      /*  LOGIC ANTI-DUPLICADOS: REMOVIDA POR SOLICITUD DEL USUARIO
          Se permite que el log manual y el background ocurran simultáneamente si coinciden.
       */
      // final db = await DatabaseHelper().database;
      // final repository = DeviceLogRepository(db);
      // final logInfo = await DeviceInfoHelper.crearDeviceLog();
      // final vendedorId = logInfo?.employeeId;
      final log = await DeviceInfoHelper.crearDeviceLog();
      if (log == null) return;

      await _guardarEnBD(log);
      await _intentarEnviarConReintentos(log);

      // Sincronizar logs anteriores que hayan fallado
      _logger.i('Intentando sincronizar logs pendientes...');
      await DeviceLogUploadService.sincronizarDeviceLogsPendientes();
    } catch (e) {
      _logger.e('Error en ejecución de logging background: $e');
      throw e;
    }
  }

  ///  Verificar si estamos en horario de trabajo
  static bool estaEnHorarioTrabajo() {
    final now = DateTime.now();
    final hora = now.hour;
    // Lunes=1 ... Sábado=6. Domingo=7 (excluido)
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

  // ===========================================================================
  //MÉTODOS DE COMPATIBILIDAD (Para evitar romper otras partes de la app)
  // ===========================================================================

  /// Obtener estado actual (Simulado para compatibilidad)
  static Future<Map<String, dynamic>> obtenerEstado() async {
    return {
      'activo': _isInitialized,
      'engine': 'WorkManager',
      'min_interval': '15m (Android limitation)',
      'configured_interval': '${BackgroundLogConfig.intervalo.inMinutes}m',
    };
  }

  /// Ejecución manual (alias para la nueva lógica)
  static Future<void> ejecutarManual({bool verificarSesion = true}) async {
    await _ejecutarLoggingCompleto();
  }

  /// Mostrar configuración (alias)
  static Future<void> mostrarConfiguracion() async {
    _logger.i(
      'WorkManager Configuration: Interval=${BackgroundLogConfig.intervalo.inMinutes}m',
    );
  }

  // Compatibilidad
  static Future<void> inicializarDespuesDeLogin() async => inicializar();
  static bool get estaActivo => _isInitialized;
}
