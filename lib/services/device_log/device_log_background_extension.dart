// lib/services/device_log/device_log_background_extension.dart
import 'dart:async';
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

//  CONFIGURACIÓN CENTRALIZADA
class BackgroundLogConfig {
  ///  HORARIO DE TRABAJO (Dinámico)
  static int horaInicio = 9; // Default 9 AM
  static int horaFin = 17; // Default 5 PM

  /// Keys para SharedPreferences
  static const String keyHoraInicio = 'work_hours_start';
  static const String keyHoraFin = 'work_hours_end';
  static const String keyIntervalo = 'work_interval_minutes';

  ///  INTERVALO ENTRE REGISTROS (Dinámico)
  static Duration intervalo = Duration(minutes: 5); // Default 5 min

  /// NÚMERO MÁXIMO DE REINTENTOS
  static const int maxReintentos = 5;

  /// TIEMPOS DE ESPERA PARA BACKOFF EXPONENCIAL (en segundos)
  /// Progresión: 5s, 10s, 20s, 40s, 60s
  static const List<int> tiemposBackoff = [5, 10, 20, 40, 60];

  /// Obtener tiempo de espera según el número de intento (1-based)
  static int obtenerTiempoEspera(int numeroIntento) {
    // numeroIntento empieza en 1, pero el array en 0
    final index = numeroIntento - 1;

    // Validar que el índice esté dentro del rango
    if (index >= 0 && index < tiemposBackoff.length) {
      return tiemposBackoff[index];
    }

    // Si se excede, usar el último valor (mayor tiempo de espera)
    return tiemposBackoff.last;
  }

  ///  MINUTOS MÍNIMOS ENTRE LOGS (prevenir duplicados)
  // static const int minutosMinimosEntreLogs = 8;
}

/// - CON PROTECCIÓN ANTI-DUPLICADOS Y LOCK DE CONCURRENCIA
class DeviceLogBackgroundExtension {
  static final _logger = Logger();
  static Timer? _backgroundTimer;
  static bool _isInitialized = false;
  static bool _isExecuting = false;

  /// 🆕 Verificar si hay una sesión activa antes de proceder
  static Future<bool> _verificarSesionActiva() async {
    try {
      final authService = AuthService();
      final tieneSession = await authService.hasUserLoggedInBefore();

      if (!tieneSession) {
        _logger.w('⚠️ No hay sesión activa - deteniendo logging automático');
        await detener();
        return false;
      }

      return true;
    } catch (e) {
      _logger.e('❌ Error verificando sesión: $e');
      return false;
    }
  }

  /// Inicializar servicio de logging en background
  /// 🆕 SOLO INICIA CON SESIÓN ACTIVA
  static Future<void> inicializar({bool verificarSesion = true}) async {
    try {
      _logger.i('═══════════════════════════════════════');
      _logger.i('INICIALIZANDO BACKGROUND LOGGING');
      _logger.i('═══════════════════════════════════════');

      // Verificar sesión antes de inicializar
      if (verificarSesion && !await _verificarSesionActiva()) {
        _logger.w('No se puede inicializar sin sesión activa');
        return;
      }

      // Detener timer previo si existe
      _backgroundTimer?.cancel();

      // CREAR LOG INMEDIATAMENTE AL INICIAR (solo si hay sesión)
      _logger.i('Creando primer log inmediatamente...');
      await _ejecutarLogging();
      _logger.i('Primer log creado y enviado');

      // Crear timer periódico para los siguientes logs
      _backgroundTimer = Timer.periodic(
        BackgroundLogConfig.intervalo,
        (timer) async => await _ejecutarLoggingConHorario(),
      );

      _isInitialized = true;

      // Mostrar configuración
      final urlActual = await ApiConfigService.getBaseUrl();
      _logger.i('Extensión de logging configurada');
      _logger.i('URL del servidor: $urlActual');
      _logger.i(
        'Horario: ${BackgroundLogConfig.horaInicio}:00 - ${BackgroundLogConfig.horaFin}:00',
      );
      _logger.i(
        'Intervalo: ${BackgroundLogConfig.intervalo.inMinutes} minutos',
      );
      // _logger.i('Reintentos máximos: ${BackgroundLogConfig.maxReintentos}');
      // _logger.i(
      //   // 'Mínimo entre logs: ${BackgroundLogConfig.minutosMinimosEntreLogs} min',
      // );
      _logger.i(
        'Verificación de sesión: ${verificarSesion ? "ACTIVADA" : "DESACTIVADA"}',
      );
      _logger.i('═══════════════════════════════════════');

      // Cargar configuración de horario
      await _cargarConfiguracionHorario();

      // Verificar disponibilidad de servicios
      await DeviceInfoHelper.mostrarEstadoDisponibilidad();
    } catch (e) {
      _logger.e('Error inicializando extensión: $e');
    }
  }

  /// 🕒 Cargar horarios e intervalo desde SharedPreferences
  static Future<void> _cargarConfiguracionHorario() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      BackgroundLogConfig.horaInicio =
          prefs.getInt(BackgroundLogConfig.keyHoraInicio) ?? 9;
      BackgroundLogConfig.horaFin =
          prefs.getInt(BackgroundLogConfig.keyHoraFin) ?? 17;

      // Cargar intervalo
      final intervaloMin = prefs.getInt(BackgroundLogConfig.keyIntervalo) ?? 5;
      BackgroundLogConfig.intervalo = Duration(minutes: intervaloMin);

      _logger.i(
        'Configuración cargada - Horario: ${BackgroundLogConfig.horaInicio}:00-${BackgroundLogConfig.horaFin}:00 | Intervalo: ${intervaloMin}min',
      );

      // Si el timer está activo, REINICIARLO con el nuevo intervalo
      if (_isInitialized &&
          _backgroundTimer != null &&
          _backgroundTimer!.isActive) {
        _logger.i('Reiniciando timer con nuevo intervalo log...');
        _backgroundTimer?.cancel();
        _backgroundTimer = Timer.periodic(
          BackgroundLogConfig.intervalo,
          (timer) async => await _ejecutarLoggingConHorario(),
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
      await _cargarConfiguracionHorario();
    } catch (e) {
      _logger.e('Error guardando configuración: $e');
      rethrow;
    }
  }

  /// Ejecutar logging con verificación de horario y sesión
  static Future<void> _ejecutarLoggingConHorario() async {
    try {
      // 🔄 IMPORTANTE: Recargar configuración en cada ejecución
      // Esto es necesario porque el servicio corre en un Isolate separado
      // y no recibe las actualizaciones de variables estáticas desde la UI
      await _cargarConfiguracionHorario();

      // Verificar sesión antes de cada ejecución
      if (!await _verificarSesionActiva()) {
        return; // Ya se maneja el stop dentro de _verificarSesionActiva
      }

      // Verificar si estamos en horario laboral
      if (!estaEnHorarioTrabajo()) {
        _logger.i(
          'Fuera del horario de trabajo (${BackgroundLogConfig.horaInicio}:00 - ${BackgroundLogConfig.horaFin}:00)',
        );
        return;
      }

      _logger.i('═══════════════════════════════════════');
      _logger.i('EJECUTANDO LOGGING EN HORARIO LABORAL');
      _logger.i('═══════════════════════════════════════');

      await _ejecutarLogging();

      _logger.i('═══════════════════════════════════════');
    } catch (e) {
      _logger.e('Error en logging con horario: $e');
    }
  }

  /// Ejecutar proceso completo de logging
  static Future<void> _ejecutarLogging() async {
    // LOCK DE CONCURRENCIA - Prevenir ejecución simultánea
    if (_isExecuting) {
      _logger.w('Ya hay un proceso de logging en ejecución - saltando...');
      return;
    }

    _isExecuting = true;

    try {
      // Verificar sesión al inicio del proceso
      if (!await _verificarSesionActiva()) {
        return; // Ya se maneja el stop dentro de _verificarSesionActiva
      }

      // Verificar permisos de ubicación
      // NOTA: En background no podemos solicitar permisos interactivamente.
      // Se asume que los permisos ya fueron otorgados en el uso normal de la app.
      final hasPermission = await Permission.location.isGranted;
      if (!hasPermission) {
        final hasAlways = await Permission.locationAlways.isGranted;
        if (!hasAlways) {
          _logger.w(
            'Sin permisos de ubicación (Background) - No se puede crear log',
          );
          return;
        }
      }

      // VALIDAR QUE NO EXISTA UN LOG MUY RECIENTE (prevenir duplicados)
      /*
      // COMENTADO PARA TESTING TESTING EXTENSIVO - IGNORAR DUPLICADOS
      final db = await DatabaseHelper().database;
      final repository = DeviceLogRepository(db);

      // Obtener vendedor actual (puede ser null en algunas situaciones)
      final logInfo = await DeviceInfoHelper.crearDeviceLog();
      final vendedorId = logInfo?.employeeId;
      
      final existeReciente = await repository.existeLogReciente(
        vendedorId,
        minutos: BackgroundLogConfig.minutosMinimosEntreLogs,
      );

      if (existeReciente) {
        _logger.i(
          'Ya existe un log reciente (últimos ${BackgroundLogConfig.minutosMinimosEntreLogs} min) - saltando creación',
        );
        return;
      }
      */

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

    // Verificar día laboral (Lunes = 1 a Viernes = 5)
    final esDiaLaboral = now.weekday >= 1 && now.weekday <= 5;

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
    _logger.w('═══════════════════════════════════════');
    _logger.w('TODOS LOS INTENTOS FALLARON');
    _logger.w('═══════════════════════════════════════');
    _logger.w('Log ID: ${log.id}');
    _logger.w('Intentos realizados: ${BackgroundLogConfig.maxReintentos}');
    _logger.w('Estado: Quedará como PENDIENTE (sincronizado: 0)');
    _logger.w('El UploadService lo reintentará en la próxima sincronización');
    _logger.w('═══════════════════════════════════════');
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
      _logger.i('═══════════════════════════════════════');
      _logger.i('EJECUCIÓN MANUAL DE LOGGING');
      _logger.i('═══════════════════════════════════════');

      // Verificar sesión si está habilitado
      if (verificarSesion && !await _verificarSesionActiva()) {
        _logger.w('No se puede ejecutar sin sesión activa');
        return;
      }

      final urlActual = await ApiConfigService.getBaseUrl();
      _logger.i('URL configurada: $urlActual');

      await _ejecutarLogging();

      _logger.i('═══════════════════════════════════════');
      _logger.i('EJECUCIÓN MANUAL COMPLETADA');
      _logger.i('═══════════════════════════════════════');
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

  /// Mostrar configuración completa
  static Future<void> mostrarConfiguracion() async {
    final estado = await obtenerEstado();

    _logger.i('═══════════════════════════════════════');
    _logger.i('CONFIGURACIÓN BACKGROUND LOGGING');
    _logger.i('═══════════════════════════════════════');
    _logger.i('Estado General:');
    _logger.i('   • Activo: ${estado['activo'] == true ? "SÍ" : "NO"}');
    _logger.i(
      '   • Inicializado: ${estado['inicializado'] == true ? "SÍ" : "NO"}',
    );
    _logger.i(
      '   • Timer: ${estado['timer_activo'] == true ? "ACTIVO" : "INACTIVO"}',
    );
    _logger.i('   • Ejecutando: ${estado['ejecutando'] == true ? "SÍ" : "NO"}');
    _logger.i(
      '   • Sesión activa: ${estado['sesion_activa'] == true ? "SÍ" : "NO"}',
    );
    _logger.i('');
    _logger.i('Horario Actual:');
    _logger.i('   • Día: ${estado['dia_nombre']}');
    _logger.i(
      '   • Hora: ${estado['hora_actual']}:${estado['minuto_actual']?.toString().padLeft(2, '0')}',
    );
    _logger.i(
      '   • En horario laboral: ${estado['en_horario'] == true ? "SÍ" : "NO"}',
    );
    _logger.i('');
    _logger.i('Configuración de Horario:');
    _logger.i('   • Horario: ${estado['horario']}');
    _logger.i('   • Días: Lunes a Viernes');
    _logger.i('   • Intervalo: ${estado['intervalo_minutos']} minutos');
    _logger.i(
      '   • Mínimo entre logs: ${estado['minutos_minimos_entre_logs']} min',
    );
    _logger.i('');
    _logger.i('Configuración de Red:');
    _logger.i('   • URL Servidor: ${estado['url_servidor']}');
    _logger.i('   • Endpoint: /appDeviceLog/insertAppDeviceLog');
    _logger.i('');
    _logger.i('Configuración de Reintentos:');
    _logger.i('   • Máximo reintentos: ${estado['max_reintentos']}');
    _logger.i('   • Tiempos backoff: ${estado['tiempos_backoff']}s');
    _logger.i('   • Progresión: 5s → 10s → 20s → 40s → 60s');
    _logger.i('═══════════════════════════════════════');
  }

  /// 📅 Obtener nombre del día de la semana
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

  /// 📈 Obtener estadísticas de uso
  static Future<Map<String, dynamic>> obtenerEstadisticas() async {
    try {
      final db = await DatabaseHelper().database;
      final repository = DeviceLogRepository(db);

      final stats = await repository.obtenerEstadisticas();

      return {
        'total_logs': stats['total'] ?? 0,
        'logs_sincronizados': stats['sincronizados'] ?? 0,
        'logs_pendientes': stats['pendientes'] ?? 0,
        'porcentaje_sincronizado': stats['total'] > 0
            ? ((stats['sincronizados'] / stats['total']) * 100).toStringAsFixed(
                1,
              )
            : '0.0',
      };
    } catch (e) {
      _logger.e('Error obteniendo estadísticas: $e');
      return {
        'total_logs': 0,
        'logs_sincronizados': 0,
        'logs_pendientes': 0,
        'porcentaje_sincronizado': '0.0',
      };
    }
  }

  /// Mostrar estadísticas completas
  static Future<void> mostrarEstadisticas() async {
    final stats = await obtenerEstadisticas();

    _logger.i('═══════════════════════════════════════');
    _logger.i('ESTADÍSTICAS DE DEVICE LOGS');
    _logger.i('═══════════════════════════════════════');
    _logger.i('Total de logs: ${stats['total_logs']}');
    _logger.i('Sincronizados: ${stats['logs_sincronizados']}');
    _logger.i('Pendientes: ${stats['logs_pendientes']}');
    _logger.i('% Sincronizado: ${stats['porcentaje_sincronizado']}%');
    _logger.i('═══════════════════════════════════════');
  }
}
