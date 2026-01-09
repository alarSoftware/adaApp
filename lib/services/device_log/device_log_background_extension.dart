import 'dart:async';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ada_app/repositories/device_log_repository.dart';
import 'package:ada_app/services/data/database_helper.dart';
import 'package:ada_app/models/device_log.dart';
import 'package:ada_app/services/post/device_log_post_service.dart';
import 'package:ada_app/utils/device_info_helper.dart';
import 'package:ada_app/services/api/auth_service.dart';

import 'package:ada_app/services/device_log/device_log_upload_service.dart';
import 'package:ada_app/services/api/api_config_service.dart';
import 'package:ada_app/services/error_log/error_log_service.dart';

import 'package:shared_preferences/shared_preferences.dart';

class BackgroundLogConfig {
  static int horaInicio = 9;
  static int horaFin = 17;
  static List<int> diasTrabajo = [1, 2, 3, 4, 5, 6]; // Default: Lun-Sab

  /// Keys para SharedPreferences
  static const String keyHoraInicio = 'work_hours_start';
  static const String keyHoraFin = 'work_hours_end';
  static const String keyIntervalo = 'work_interval_minutes';
  static const String keyDiasTrabajo = 'work_days_list';

  /// INTERVALO ENTRE REGISTROS (Dinámico)
  static Duration intervalo = Duration(minutes: 15);

  /// NÚMERO MÁXIMO DE REINTENTOS
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
  static Timer? _backgroundTimer;
  static bool _isInitialized = false;
  static bool _isExecuting = false;
  static Function? _onGpsAlertListener;

  static Future<bool> _verificarSesionActiva() async {
    try {
      final authService = AuthService();
      final tieneSession = await authService.hasUserLoggedInBefore();

      if (!tieneSession) {
        print('No active session - stopping auto logging');
        await detener();
        return false;
      }

      return true;
    } catch (e) {
      print('Error checking session: $e');
      return false;
    }
  }

  /// Inicializar servicio de logging en background
  static Future<void> inicializar({
    bool verificarSesion = true,
    Function? onGpsAlert,
    ServiceInstance?
    serviceInstance, // Keeping for compatibility or just in case
  }) async {
    if (onGpsAlert != null) {
      _onGpsAlertListener = onGpsAlert;
    }
    try {
      _backgroundTimer?.cancel();

      _isInitialized = true;

      print('DeviceLog Extension Initialized');

      // Cargar configuración de horario
      await cargarConfiguracionHorario();

      // INICIAR TIMER INTERNO
      print(
        'Iniciando timer interno con intervalo de ${BackgroundLogConfig.intervalo.inMinutes} min',
      );
      _backgroundTimer = Timer.periodic(
        BackgroundLogConfig.intervalo,
        (timer) async => await ejecutarLoggingConHorario(),
      );

      // Verificar disponibilidad de servicios
      await DeviceInfoHelper.mostrarEstadoDisponibilidad();
    } catch (e) {
      print('Error inicializando extensión: $e');
    }
  }

  /// Cargar horarios e intervalo desde SharedPreferences
  static Future<void> cargarConfiguracionHorario() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();

      BackgroundLogConfig.horaInicio =
          prefs.getInt(BackgroundLogConfig.keyHoraInicio) ?? 9;
      BackgroundLogConfig.horaFin =
          prefs.getInt(BackgroundLogConfig.keyHoraFin) ?? 17;

      // Cargar días de trabajo
      final diasString = prefs.getStringList(
        BackgroundLogConfig.keyDiasTrabajo,
      );
      if (diasString != null) {
        BackgroundLogConfig.diasTrabajo = diasString
            .map((e) => int.tryParse(e) ?? 0)
            .where((e) => e > 0)
            .toList();
      } else {
        BackgroundLogConfig.diasTrabajo = [
          1,
          2,
          3,
          4,
          5,
          6,
        ]; // Default fallback
      }

      // Cargar intervalo
      final intervaloMin = prefs.getInt(BackgroundLogConfig.keyIntervalo) ?? 5;
      final nuevoIntervalo = Duration(minutes: intervaloMin);
      // SOLO reiniciar si el intervalo cambió
      if (nuevoIntervalo != BackgroundLogConfig.intervalo) {
        BackgroundLogConfig.intervalo = nuevoIntervalo;

        if (_isInitialized &&
            _backgroundTimer != null &&
            _backgroundTimer!.isActive) {
          // Detener y reiniciar el timer
          _backgroundTimer?.cancel();
          _backgroundTimer = Timer.periodic(
            BackgroundLogConfig.intervalo,
            (timer) async => await ejecutarLoggingConHorario(),
          );
        }
      }
    } catch (e) {
      print('Error cargando configuración: $e');
    }
  }

  /// Guardar nuevos horarios e intervalo
  static Future<void> guardarConfiguracionHorario(
    int inicio,
    int fin, {
    int? intervaloMinutos,
    List<int>? diasTrabajo,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(BackgroundLogConfig.keyHoraInicio, inicio);
      await prefs.setInt(BackgroundLogConfig.keyHoraFin, fin);

      BackgroundLogConfig.horaInicio = inicio;
      BackgroundLogConfig.horaFin = fin;

      if (intervaloMinutos != null) {
        await prefs.setInt(BackgroundLogConfig.keyIntervalo, intervaloMinutos);
        BackgroundLogConfig.intervalo = Duration(minutes: intervaloMinutos);
      }

      if (diasTrabajo != null) {
        final diasString = diasTrabajo.map((e) => e.toString()).toList();
        await prefs.setStringList(
          BackgroundLogConfig.keyDiasTrabajo,
          diasString,
        );
        BackgroundLogConfig.diasTrabajo = diasTrabajo;
      }

      print(
        'Nueva configuración guardada - Intervalo: ${intervaloMinutos ?? BackgroundLogConfig.intervalo.inMinutes}min',
      );

      // Enviar señal al servicio background para que recargue inmediatamente
      final service = FlutterBackgroundService();
      if (await service.isRunning()) {
        service.invoke('updateConfig');
        print('Señal updateConfig enviada al servicio');
      } else {
        // Fallback porsi el servicio no corre (raro)
        // No llamamos inicializar() aqui para no duplicar timers en UI
        print('Servicio no corriendo - configuración guardada solo en disco');
      }
    } catch (e) {
      print('Error guardando configuración: $e');
      rethrow;
    }
  }

  /// Ejecutar logging con verificación de horario y sesión
  static Future<void> ejecutarLoggingConHorario() async {
    try {
      await cargarConfiguracionHorario();

      // Verificar sesión antes de cada ejecución
      if (!await _verificarSesionActiva()) {
        return;
      }

      // Verificar horario
      if (!estaEnHorarioTrabajo()) {
        print(
          'Fuera del horario de trabajo (${BackgroundLogConfig.horaInicio}:00 - ${BackgroundLogConfig.horaFin}:00)',
        );
        return;
      }

      await _ejecutarLogging();
    } catch (e) {
      print('Error en logging con horario: $e');
    }
  }

  /// Ejecutar proceso completo de logging
  static Future<void> _ejecutarLogging() async {
    // LOCK DE CONCURRENCIA
    if (_isExecuting) {
      print('Ya hay un proceso de logging en ejecución - saltando...');
      return;
    }

    _isExecuting = true;

    try {
      // Re-verificar sesión
      if (!await _verificarSesionActiva()) {
        print('LOGGING SKIPPED: No hay sesión activa');
        return;
      }

      final isGpsEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isGpsEnabled) {
        print('LOGGING SKIPPED: GPS Desactivado - Enviando alerta');

        // Llamada directa al callback si existe (Sin usar invoke)
        if (_onGpsAlertListener != null) {
          _onGpsAlertListener!();
        }
        return;
      }

      final hasPermission = await Permission.location.isGranted;
      final hasAlways = await Permission.locationAlways.isGranted;

      if (!hasPermission && !hasAlways) {
        print('LOGGING SKIPPED: Sin permisos de ubicación');
        return;
      }

      // Crear log
      print('Creando device log...');
      final log = await DeviceInfoHelper.crearDeviceLog();

      if (log == null) {
        print('No se pudo crear el device log');
        return;
      }

      // Guardar local
      await _guardarEnBD(log);

      // Enviar
      await _intentarEnviarConReintentos(log);

      // Trigger sync general
      await DeviceLogUploadService.sincronizarDeviceLogsPendientes();

      // 🔴 NUEVO: Intentar reenvío de Error Logs pendientes
      try {
        print('Intentando reenviar error logs pendientes...');
        await ErrorLogService.enviarErrorLogsAlServidor();
      } catch (e) {
        print('Error en reenvío automático de error logs: $e');
      }

      print('Proceso de logging completado para: ${log.id}');
    } catch (e) {
      print('Error en proceso de logging: $e');
    } finally {
      _isExecuting = false;
    }
  }

  /// Verificar si estamos en horario de trabajo
  static bool estaEnHorarioTrabajo() {
    final now = DateTime.now();
    final hora = now.hour;

    // Verificar día laboral (Usando la lista configurada)
    // DateTime.weekday devuelve 1 para lunes, 7 para domingo
    final esDiaLaboral = BackgroundLogConfig.diasTrabajo.contains(now.weekday);

    // Verificar horario
    final esHorarioTrabajo =
        hora >= BackgroundLogConfig.horaInicio &&
        hora < BackgroundLogConfig.horaFin;

    return esDiaLaboral && esHorarioTrabajo;
  }

  /// Guardar log en base de datos local
  static Future<void> _guardarEnBD(DeviceLog log) async {
    try {
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

      print('Log guardado en BD local (sincronizado: 0)');
    } catch (e) {
      print('Error guardando en BD: $e');
      rethrow;
    }
  }

  /// Enviar al servidor con reintentos automáticos
  static Future<void> _intentarEnviarConReintentos(DeviceLog log) async {
    int intento = 0;

    while (intento < BackgroundLogConfig.maxReintentos) {
      intento++;

      try {
        print('Intento $intento de ${BackgroundLogConfig.maxReintentos}...');

        // FETCH CORRECT USER ID
        final authService = AuthService();
        final currentUser = await authService.getCurrentUser();
        String? validUserId = currentUser?.id?.toString();

        // Si no tenemos session (raro en este punto), intentar lookup por employeeId
        if (validUserId == null) {
          validUserId = await DeviceLogUploadService.obtenerUserIdPorEmployeeId(
            log.employeeId!,
          );
        }

        final resultado = await DeviceLogPostService.enviarDeviceLog(
          log,
          userId: validUserId,
        );

        if (resultado['exito'] == true) {
          print('Enviado exitosamente en intento $intento');
          await _marcarComoSincronizado(log.id);
          return;
        } else {
          print('Fallo en intento $intento: ${resultado['mensaje']}');
        }
      } catch (e) {
        print('Error en intento $intento: $e');
      }

      if (intento < BackgroundLogConfig.maxReintentos) {
        final esperaSegundos = BackgroundLogConfig.obtenerTiempoEspera(intento);
        await Future.delayed(Duration(seconds: esperaSegundos));
      }
    }
  }

  static Future<void> _marcarComoSincronizado(String logId) async {
    try {
      final db = await DatabaseHelper().database;
      await db.update(
        'device_log',
        {'sincronizado': 1},
        where: 'id = ?',
        whereArgs: [logId],
      );
      print('Log marcado como sincronizado en BD');
    } catch (e) {
      print('Error marcando como sincronizado: $e');
    }
  }

  /// Detener servicio de logging
  static Future<void> detener() async {
    try {
      print('Deteniendo extensión de logging...');

      _backgroundTimer?.cancel();
      _backgroundTimer = null;
      _isInitialized = false;
      _isExecuting = false;

      print('Extensión de logging detenida');
    } catch (e) {
      print('Error deteniendo extensión: $e');
    }
  }

  /// Método para inicializar desde login exitoso
  static Future<void> inicializarDespuesDeLogin() async {
    try {
      // FIX: Usar AppBackgroundService para evitar timer duplicado en Isolate Principal
      // await inicializar(verificarSesion: true);
      final service = FlutterBackgroundService();
      if (!(await service.isRunning())) {
        await service.startService();
      }
    } catch (e) {
      print('Error inicializando logging post-login: $e');
    }
  }

  /// Verificar si el servicio está activo
  static bool get estaActivo =>
      _isInitialized && (_backgroundTimer?.isActive ?? false);

  /// Obtener información completa del estado
  static Future<Map<String, dynamic>> obtenerEstado() async {
    final now = DateTime.now();
    final urlActual = await ApiConfigService.getBaseUrl();
    final tieneSesion = await _verificarSesionActiva();

    return {
      'activo': estaActivo,
      'inicializado': _isInitialized,
      'timer_activo': _backgroundTimer?.isActive ?? false,
      'ejecutando': _isExecuting,
      'sesion_activa': tieneSesion,
      'en_horario': estaEnHorarioTrabajo(),
      'hora_actual': now.hour,
      'intervalo_minutos': BackgroundLogConfig.intervalo.inMinutes,
      'horario':
          '${BackgroundLogConfig.horaInicio}:00 - ${BackgroundLogConfig.horaFin}:00',
      'url_servidor': urlActual,
    };
  }

  static Future<void> mostrarConfiguracion() async {
    final estado = await obtenerEstado();
    print(
      'Background Logging Config: Active=${estado['activo']}, Interval=${estado['intervalo_minutos']}',
    );
  }
}
