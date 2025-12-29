import 'dart:async';
import 'dart:math';
import 'package:permission_handler/permission_handler.dart';
import 'package:ada_app/repositories/device_log_repository.dart';
import 'package:ada_app/services/data/database_helper.dart';
import 'package:ada_app/models/device_log.dart';
import 'package:ada_app/services/post/device_log_post_service.dart';
import 'package:ada_app/services/api/api_config_service.dart';
import 'package:ada_app/utils/device_info_helper.dart';
import 'package:ada_app/services/api/auth_service.dart';
import 'package:logger/logger.dart';

import 'package:shared_preferences/shared_preferences.dart';

class BackgroundLogConfig {
  static int horaInicio = 9;
  static int horaFin = 17;

  /// Keys para SharedPreferences
  static const String keyHoraInicio = 'work_hours_start';
  static const String keyHoraFin = 'work_hours_end';
  static const String keyIntervalo = 'work_interval_minutes';

  ///  INTERVALO ENTRE REGISTROS (Dinámico)
  static Duration intervalo = Duration(minutes: 5);

  /// NÚMERO MÁXIMO DE REINTENTOS
  static const int maxReintentos = 5;
  static const List<int> tiemposBackoff = [5, 10, 20, 40, 60];

  static int obtenerTiempoEspera(int numeroIntento) {
    final index = numeroIntento - 1;
    if (index >= 0 && index < tiemposBackoff.length) {
      return tiemposBackoff[index];
    }
    return tiemposBackoff.last;
  }

  static int get minutosMinimosEntreLogs => max(1, intervalo.inMinutes);
}

class DeviceLogBackgroundExtension {
  static final _logger = Logger();
  static Timer? _backgroundTimer;
  static bool _isInitialized = false;
  static bool _isExecuting = false;

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

  /// Inicializar servicio de logging en background
  static Future<void> inicializar({bool verificarSesion = true}) async {
    try {
      // Detener timer previo si existe
      _backgroundTimer?.cancel();

      _isInitialized = true;

      _logger.i(
        'Background logging initialized. Interval: ${BackgroundLogConfig.intervalo.inMinutes} min',
      );

      // Cargar configuración de horario
      await cargarConfiguracionHorario();

      // INICIAR TIMER INTERNO
      _logger.i(
        'Iniciando timer interno con intervalo de ${BackgroundLogConfig.intervalo.inMinutes} min',
      );
      _backgroundTimer = Timer.periodic(
        BackgroundLogConfig.intervalo,
        (timer) async => await ejecutarLoggingConHorario(),
      );

      // Verificar disponibilidad de servicios
      await DeviceInfoHelper.mostrarEstadoDisponibilidad();
    } catch (e) {
      _logger.e('Error inicializando extensión: $e');
    }
  }

  /// 🕒 Cargar horarios e intervalo desde SharedPreferences
  static Future<void> cargarConfiguracionHorario() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs
          .reload(); // 🔴 FORZAR RECARGA DESDE DISCO para ver cambios de UI
      BackgroundLogConfig.horaInicio =
          prefs.getInt(BackgroundLogConfig.keyHoraInicio) ?? 9;
      BackgroundLogConfig.horaFin =
          prefs.getInt(BackgroundLogConfig.keyHoraFin) ?? 17;

      // Cargar intervalo
      final intervaloMin = prefs.getInt(BackgroundLogConfig.keyIntervalo) ?? 5;
      BackgroundLogConfig.intervalo = Duration(minutes: intervaloMin);

      _logger.i(
        'Config loaded - Hours: ${BackgroundLogConfig.horaInicio}-${BackgroundLogConfig.horaFin} | Interval: ${intervaloMin}min',
      );

      // Si el timer está activo, REINICIARLO con el nuevo intervalo
      if (_isInitialized &&
          _backgroundTimer != null &&
          _backgroundTimer!.isActive) {
        _logger.i('Reiniciando timer con nuevo intervalo log...');
        _backgroundTimer?.cancel();
        _backgroundTimer = Timer.periodic(
          BackgroundLogConfig.intervalo,
          (timer) async => await ejecutarLoggingConHorario(),
        );
      }
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
        await prefs.setInt(BackgroundLogConfig.keyIntervalo, intervaloMinutos);
        BackgroundLogConfig.intervalo = Duration(minutes: intervaloMinutos);
      }

      _logger.i(
        'Nueva configuración guardada - Intervalo: ${intervaloMinutos ?? BackgroundLogConfig.intervalo.inMinutes}min',
      );

      // Recargar para aplicar cambios al timer inmediatamente
      await cargarConfiguracionHorario();
    } catch (e) {
      _logger.e('Error guardando configuración: $e');
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

      if (!estaEnHorarioTrabajo()) {
        _logger.i(
          'Fuera del horario de trabajo (${BackgroundLogConfig.horaInicio}:00 - ${BackgroundLogConfig.horaFin}:00)',
        );
        return;
      }

      await _ejecutarLogging();
    } catch (e) {
      _logger.e('Error en logging con horario: $e');
    }
  }

  /// Ejecutar proceso completo de logging
  static Future<void> _ejecutarLogging() async {
    // LOCK DE CONCURRENCIA - Prevenir ejecución simultánea
    // if (_isExecuting) {
    //   _logger.w('Ya hay un proceso de logging en ejecución - saltando...');
    //   return;
    // }

    _isExecuting = true;

    try {
      if (!await _verificarSesionActiva()) {
        _logger.w('LOGGING SKIPPED: No hay sesión activa');
        return;
      }
      final hasPermission = await Permission.location.isGranted;
      if (!hasPermission) {
        final hasAlways = await Permission.locationAlways.isGranted;
        if (!hasAlways) {
          _logger.w('LOGGING SKIPPED: Sin permisos de ubicación (Background)');
          return;
        }
      } else {
        _logger.i('Permisos de ubicación OK');
      }

      final db = await DatabaseHelper().database;
      final repository = DeviceLogRepository(db);
      final logInfo = await DeviceInfoHelper.crearDeviceLog();
      final vendedorId = logInfo?.employeeId;
      final intervaloSegundos = BackgroundLogConfig.intervalo.inSeconds;
      final toleranciaSegundos = (intervaloSegundos * 0.5).round();

      final existeReciente = await repository.existeLogReciente(
        vendedorId,
        segundos: toleranciaSegundos,
      );

      if (existeReciente) {
        _logger.w(
          'Skipping log: Too close to previous (last ${toleranciaSegundos}s)',
        );
        // Liberar lock antes de salir
        _isExecuting = false;
        return;
      }

      // Crear log usando helper compartido
      _logger.i('Creando device log...');
      final log = await DeviceInfoHelper.crearDeviceLog();

      if (log == null) {
        _logger.w(
          'No se pudo crear el device log - posiblemente sin sesión activa',
        );
        return;
      }

      //  Guardar en base de datos local
      _logger.i('Guardando en base de datos local...');
      await _guardarEnBD(log);

      //  Intentar enviar al servidor con reintentos automáticos
      _logger.i('Intentando enviar al servidor...');
      await _intentarEnviarConReintentos(log);

      _logger.i('Proceso de logging completado para: ${log.id}');
    } catch (e) {
      _logger.e('Error en proceso de logging: $e');
    } finally {
      // LIBERAR LOCK SIEMPRE
      _isExecuting = false;
    }
  }

  ///  Verificar si estamos en horario de trabajo
  static bool estaEnHorarioTrabajo() {
    final now = DateTime.now();
    final hora = now.hour;

    // Verificar día laboral (Lunes = 1 a Sábado = 6)
    final esDiaLaboral = now.weekday >= 1 && now.weekday <= 6;

    // Verificar horario
    final esHorarioTrabajo =
        hora >= BackgroundLogConfig.horaInicio &&
        hora < BackgroundLogConfig.horaFin;

    return esDiaLaboral && esHorarioTrabajo;
  }

  ///  Guardar log en base de datos local
  static Future<void> _guardarEnBD(DeviceLog log) async {
    try {
      final db = await DatabaseHelper().database;
      final repository = DeviceLogRepository(db);

      await repository.guardarLog(
        id: log.id, // <--- PASAR ID EXISTENTE
        employeeId: log.employeeId,
        latitud: double.parse(log.latitudLongitud.split(',')[0]),
        longitud: double.parse(log.latitudLongitud.split(',')[1]),
        bateria: log.bateria,
        modelo: log.modelo,
      );

      _logger.i('Log guardado en BD local (sincronizado: 0)');
    } catch (e) {
      _logger.e('Error guardando en BD: $e');
      rethrow;
    }
  }

  /// Enviar al servidor con reintentos automáticos
  static Future<void> _intentarEnviarConReintentos(DeviceLog log) async {
    int intento = 0;

    while (intento < BackgroundLogConfig.maxReintentos) {
      intento++;

      try {
        _logger.i(
          'Intento $intento de ${BackgroundLogConfig.maxReintentos}...',
        );

        // Mostrar URL para debugging
        final urlCompleta = await ApiConfigService.getFullUrl(
          '/appDeviceLog/insertAppDeviceLog',
        );
        _logger.i('Enviando a: $urlCompleta');

        // Usar el servicio unificado
        final resultado = await DeviceLogPostService.enviarDeviceLog(
          log,
          userId: log.employeeId,
        );

        if (resultado['exito'] == true) {
          _logger.i('Enviado exitosamente en intento $intento');

          // Marcar como sincronizado
          await _marcarComoSincronizado(log.id);

          _logger.i('Log sincronizado correctamente');
          return; // Éxito - salir del loop
        } else {
          _logger.w('Fallo en intento $intento: ${resultado['mensaje']}');
        }
      } catch (e) {
        _logger.w('Error en intento $intento: $e');
      }

      // Backoff exponencial antes del siguiente intento
      if (intento < BackgroundLogConfig.maxReintentos) {
        final esperaSegundos = BackgroundLogConfig.obtenerTiempoEspera(intento);
        _logger.i(
          'Esperando ${esperaSegundos}s antes del siguiente intento...',
        );
        await Future.delayed(Duration(seconds: esperaSegundos));
      }
    }

    // Todos los intentos fallaron
  }

  /// 🔄 Marcar log como sincronizado en BD
  static Future<void> _marcarComoSincronizado(String logId) async {
    try {
      final db = await DatabaseHelper().database;
      await db.update(
        'device_log',
        {'sincronizado': 1},
        where: 'id = ?',
        whereArgs: [logId],
      );
      _logger.i('Log marcado como sincronizado en BD');
    } catch (e) {
      _logger.e('Error marcando como sincronizado: $e');
    }
  }

  /// 🛑 Detener servicio de logging
  static Future<void> detener() async {
    try {
      _logger.i('Deteniendo extensión de logging...');

      _backgroundTimer?.cancel();
      _backgroundTimer = null;
      _isInitialized = false;
      _isExecuting = false; // Limpiar lock también

      _logger.i('Extensión de logging detenida');
    } catch (e) {
      _logger.e('Error deteniendo extensión: $e');
    }
  }

  /// 🔧 Ejecutar logging manualmente (para testing o primer login)
  /// Verificar sesión por defecto para evitar logs sin usuario
  static Future<void> ejecutarManual({bool verificarSesion = true}) async {
    try {
      _logger.i('Manual execution completed');
    } catch (e) {
      _logger.e('Error en ejecución manual: $e');
    }
  }

  /// Método para inicializar desde login exitoso
  static Future<void> inicializarDespuesDeLogin() async {
    try {
      _logger.i('Inicializando logging después de login exitoso...');

      // Inicializar con verificación de sesión
      await inicializar(verificarSesion: true);

      _logger.i('Logging post-login inicializado correctamente');
    } catch (e) {
      _logger.e('Error inicializando logging post-login: $e');
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
      'minuto_actual': now.minute,
      'dia_actual': now.weekday,
      'dia_nombre': _obtenerNombreDia(now.weekday),
      'intervalo_minutos': BackgroundLogConfig.intervalo.inMinutes,
      'horario':
          '${BackgroundLogConfig.horaInicio}:00 - ${BackgroundLogConfig.horaFin}:00',
      'url_servidor': urlActual,
      'max_reintentos': BackgroundLogConfig.maxReintentos,
      'tiempos_backoff': BackgroundLogConfig.tiemposBackoff.join(', '),
      // 'minutos_minimos_entre_logs': BackgroundLogConfig.minutosMinimosEntreLogs,
    };
  }

  static Future<void> mostrarConfiguracion() async {
    final estado = await obtenerEstado();

    _logger.i(
      'Background Logging Config: Active=${estado['activo']}, Initialized=${estado['inicializado']}, Session=${estado['sesion_activa']}',
    );
  }

  static String _obtenerNombreDia(int weekday) {
    const dias = {
      1: 'Lunes',
      2: 'Martes',
      3: 'Miércoles',
      4: 'Jueves',
      5: 'Viernes',
      6: 'Sábado',
      7: 'Domingo',
    };
    return dias[weekday] ?? 'Desconocido';
  }
}
