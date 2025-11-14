import 'dart:async';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import 'package:ada_app/repositories/device_log_repository.dart';
import 'package:ada_app/services/database_helper.dart';
import 'package:ada_app/models/device_log.dart';
import 'package:ada_app/services/post/device_log_post_service.dart';
import 'package:ada_app/services/api_config_service.dart';
import 'package:logger/logger.dart';

// 🔧 CONFIGURACIÓN LIMPIA - Solo horarios
class BackgroundLogConfig {
  // ⏰ HORARIO DE TRABAJO
  static const int horaInicio = 9;  // 9 AM
  static const int horaFin = 17;    // 5 PM

  // 🔄 INTERVALO
  static const Duration intervalo = Duration(minutes: 10);
}

// 🎯 EXTENSIÓN MEJORADA DE TU SERVICIO (SIN CÓDIGO DUPLICADO)
class DeviceLogBackgroundExtension {
  static final _logger = Logger();
  static Timer? _backgroundTimer;
  static bool _isInitialized = false;

  // 🚀 Inicializar servicio extendido
  static Future<void> inicializar() async {
    try {
      _logger.i("🚀 Inicializando extensión de logging...");

      // Detener timer previo si existe
      _backgroundTimer?.cancel();

      // ⏰ Crear timer que verifica horario antes de ejecutar
      _backgroundTimer = Timer.periodic(BackgroundLogConfig.intervalo, (timer) async {
        await _ejecutarLoggingConHorario();
      });

      _isInitialized = true;

      // 🌐 Mostrar URL configurada
      final urlActual = await ApiConfigService.getBaseUrl();

      _logger.i("✅ Extensión de logging configurada");
      _logger.i("🌐 URL del servidor: $urlActual");
      _logger.i("⏰ Horario: ${BackgroundLogConfig.horaInicio}:00 - ${BackgroundLogConfig.horaFin}:00");
      _logger.i("🔄 Intervalo: ${BackgroundLogConfig.intervalo.inMinutes} minutos");

    } catch (e) {
      _logger.e("💥 Error inicializando extensión: $e");
    }
  }

  // 🔄 Ejecutar logging con verificación de horario
  static Future<void> _ejecutarLoggingConHorario() async {
    try {
      // ⏰ Verificar horario de trabajo
      if (!estaEnHorarioTrabajo()) {
        _logger.i("⏰ Fuera del horario de trabajo (9 AM - 5 PM)");
        return;
      }

      _logger.i("🔄 Ejecutando logging en horario laboral...");

      // 📊 Ejecutar el logging
      await _ejecutarLogging();

    } catch (e) {
      _logger.e("💥 Error en logging con horario: $e");
    }
  }

  // 📊 Ejecutar logging (usando TU lógica existente)
  static Future<void> _ejecutarLogging() async {
    final logger = Logger();

    try {
      // 🔐 Verificar permisos
      final hasPermission = await Permission.location.isGranted;
      if (!hasPermission) {
        logger.w("⚠️ Sin permisos de ubicación");
        return;
      }

      // 📍 Obtener ubicación
      final position = await _obtenerUbicacion();
      if (position == null) {
        logger.w("⚠️ No se pudo obtener ubicación");
        return;
      }

      // 🔋 Obtener batería
      final bateria = await _obtenerNivelBateria();

      // 📱 Obtener modelo
      final modelo = await _obtenerModeloDispositivo();

      // 👤 Obtener usuario
      final edfVendedorId = await _obtenerEdfVendedorId();

      // 📦 Crear DeviceLog (usando TU modelo existente)
      final log = DeviceLog(
        id: const Uuid().v4(),
        edfVendedorId: edfVendedorId,
        latitudLongitud: '${position.latitude},${position.longitude}',
        bateria: bateria,
        modelo: modelo,
        fechaRegistro: DateTime.now().toIso8601String(),
        sincronizado: 0,
      );

      // 💾 Guardar en BD local
      await _guardarEnBD(log);

      // 🌐 Intentar enviar a servidor (usando tu servicio existente)
      await _intentarEnviarAServidor(log);

      logger.i("✅ Background log creado: ${log.id}");

    } catch (e) {
      logger.e("💥 Error en logging background: $e");
    }
  }

  // ⏰ Verificar horario de trabajo
  static bool estaEnHorarioTrabajo() {
    final now = DateTime.now();
    final hora = now.hour;
    final esDiaLaboral = now.weekday >= 1 && now.weekday <= 5; // Lunes a Viernes
    final esHorarioTrabajo = hora >= BackgroundLogConfig.horaInicio &&
        hora < BackgroundLogConfig.horaFin;

    return esDiaLaboral && esHorarioTrabajo;
  }

  // 📍 Obtener ubicación (TU LÓGICA EXISTENTE)
  static Future<Position?> _obtenerUbicacion() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 15),
      );
    } catch (e) {
      Logger().e('Error al obtener ubicación: $e');
      return null;
    }
  }

  // 🔋 Obtener batería (TU LÓGICA EXISTENTE)
  static Future<int> _obtenerNivelBateria() async {
    try {
      final battery = Battery();
      return await battery.batteryLevel;
    } catch (e) {
      Logger().e('Error al obtener nivel de batería: $e');
      return 0;
    }
  }

  // 📱 Obtener modelo (TU LÓGICA EXISTENTE)
  static Future<String> _obtenerModeloDispositivo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return '${androidInfo.brand} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return '${iosInfo.name} ${iosInfo.model}';
      }

      return 'Desconocido';
    } catch (e) {
      Logger().e('Error al obtener modelo: $e');
      return 'Desconocido';
    }
  }

  // 👤 Obtener usuario (TU LÓGICA EXISTENTE)
  static Future<String?> _obtenerEdfVendedorId() async {
    try {
      final db = await DatabaseHelper().database;
      final result = await db.query(
        'Users',
        columns: ['edf_vendedor_id'],
        limit: 1,
      );

      if (result.isNotEmpty) {
        return result.first['edf_vendedor_id'] as String?;
      }

      return null;
    } catch (e) {
      Logger().e('Error al obtener edf_vendedor_id: $e');
      return null;
    }
  }

  // 💾 Guardar en BD (usando TU repository)
  static Future<void> _guardarEnBD(DeviceLog log) async {
    try {
      final db = await DatabaseHelper().database;
      final repository = DeviceLogRepository(db);

      await repository.guardarLog(
        edfVendedorId: log.edfVendedorId,
        latitud: double.parse(log.latitudLongitud.split(',')[0]),
        longitud: double.parse(log.latitudLongitud.split(',')[1]),
        bateria: log.bateria,
        modelo: log.modelo,
      );

      Logger().i('💾 Background log guardado en BD');
    } catch (e) {
      Logger().e('Error guardando en BD: $e');
    }
  }

  // 🌐 Enviar a servidor (usando tu servicio existente - SIN DUPLICACIÓN)
  static Future<void> _intentarEnviarAServidor(DeviceLog log) async {
    try {
      // 🎯 Mostrar URL completa para debugging
      final urlCompleta = await ApiConfigService.getFullUrl('/appDeviceLog/insertAppDeviceLog');
      _logger.i("🌐 Enviando a: $urlCompleta");

      // 🔥 Usar tu servicio existente (con logging de errores automático)
      final resultado = await DeviceLogPostService.enviarDeviceLog(
        log,
        userId: log.edfVendedorId,
      );

      if (resultado['exito'] == true) {
        _logger.i("✅ Background log enviado exitosamente");

        // 🔄 Marcar como sincronizado en BD si fue exitoso
        await _marcarComoSincronizado(log.id);
      } else {
        _logger.w("⚠️ Error en servidor: ${resultado['mensaje']}");
      }
    } catch (e) {
      _logger.w("⚠️ Error enviando background log: $e");
    }
  }

  // 🔄 Marcar log como sincronizado
  static Future<void> _marcarComoSincronizado(String logId) async {
    try {
      final db = await DatabaseHelper().database;
      await db.update(
        'DeviceLogs',
        {'sincronizado': 1},
        where: 'id = ?',
        whereArgs: [logId],
      );
      _logger.i('✅ Log marcado como sincronizado: $logId');
    } catch (e) {
      _logger.e('Error marcando como sincronizado: $e');
    }
  }

  // 🛑 Detener servicio
  static Future<void> detener() async {
    try {
      _backgroundTimer?.cancel();
      _backgroundTimer = null;
      _isInitialized = false;
      _logger.i("🛑 Extensión de logging detenida");
    } catch (e) {
      _logger.e("Error deteniendo extensión: $e");
    }
  }

  // 🔧 Ejecutar manualmente (para testing)
  static Future<void> ejecutarManual() async {
    try {
      final urlActual = await ApiConfigService.getBaseUrl();
      _logger.i("🔧 Ejecutando logging manual...");
      _logger.i("🌐 URL configurada: $urlActual");

      await _ejecutarLogging();
      _logger.i("✅ Ejecución manual completada");
    } catch (e) {
      _logger.e("Error en ejecución manual: $e");
    }
  }

  // ℹ️ Verificar si está activo
  static bool get estaActivo => _isInitialized && (_backgroundTimer?.isActive ?? false);

  // 📊 Obtener información de estado
  static Future<Map<String, dynamic>> obtenerEstado() async {
    final now = DateTime.now();
    final urlActual = await ApiConfigService.getBaseUrl();

    return {
      'activo': estaActivo,
      'en_horario': estaEnHorarioTrabajo(),
      'hora_actual': now.hour,
      'dia_actual': now.weekday,
      'intervalo_minutos': BackgroundLogConfig.intervalo.inMinutes,
      'horario': '${BackgroundLogConfig.horaInicio}:00 - ${BackgroundLogConfig.horaFin}:00',
      'url_servidor': urlActual,
      'endpoint_completo': '$urlActual/appDeviceLog/insertAppDeviceLog',
    };
  }

  // 🔍 Método para debugging - mostrar configuración actual
  static Future<void> mostrarConfiguracion() async {
    final estado = await obtenerEstado();
    _logger.i("═══════════════════════════════════════");
    _logger.i("🔧 CONFIGURACIÓN BACKGROUND LOGGING");
    _logger.i("═══════════════════════════════════════");
    _logger.i("🌐 URL Servidor: ${estado['url_servidor']}");
    _logger.i("📍 Endpoint: ${estado['endpoint_completo']}");
    _logger.i("⏰ Horario: ${estado['horario']}");
    _logger.i("🔄 Intervalo: ${estado['intervalo_minutos']} min");
    _logger.i("📊 Estado: ${estado['activo'] ? 'ACTIVO' : 'INACTIVO'}");
    _logger.i("🕐 En horario: ${estado['en_horario'] ? 'SÍ' : 'NO'}");
    _logger.i("═══════════════════════════════════════");
  }
}