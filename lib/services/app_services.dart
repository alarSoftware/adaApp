import 'package:ada_app/services/database_helper.dart';
import 'package:ada_app/repositories/device_log_repository.dart';
import 'package:ada_app/services/device_log/device_log_service.dart';
import 'package:ada_app/services/device_log/device_log_background_extension.dart';
import 'package:logger/logger.dart';

class AppServices {
  static AppServices? _instance;
  static DeviceLogService? _deviceLogService;
  static bool _isUserLoggedIn = false; // 🆕 NUEVO

  final _logger = Logger();

  AppServices._internal();

  factory AppServices() {
    return _instance ??= AppServices._internal();
  }

  // 🆕 NUEVO MÉTODO: Inicializar servicios al hacer login
  Future<void> inicializarEnLogin() async {
    try {
      _logger.i('🔐 Usuario logueado - Inicializando servicios de logging');

      _isUserLoggedIn = true;

      // Inicializar servicios de logging
      await _inicializarExtensionLogging();
      await _inicializarDeviceLogService();

      _logger.i('✅ Servicios de logging iniciados para usuario logueado');
    } catch (e) {
      _logger.e('💥 Error al inicializar servicios en login: $e');
    }
  }

  // Método existente - ahora verifica si el usuario está logueado
  Future<void> inicializar() async {
    try {
      _logger.i('Inicializando servicios de la aplicación');

      // Solo inicializar si el usuario está logueado
      if (_isUserLoggedIn) {
        await _inicializarExtensionLogging();
        await _inicializarDeviceLogService();
        _logger.i('Servicios inicializados correctamente');
      } else {
        _logger.i('⚠️ Usuario no logueado - servicios de logging no iniciados');
      }
    } catch (e) {
      _logger.e('Error al inicializar servicios: $e');
    }
  }

  // 🆕 NUEVO MÉTODO: Inicializar extensión simple
  Future<void> _inicializarExtensionLogging() async {
    try {
      // Solo inicializar si hay usuario logueado
      if (!_isUserLoggedIn) {
        _logger.w('⚠️ No se puede iniciar logging sin usuario logueado');
        return;
      }

      await DeviceLogBackgroundExtension.inicializar();
      _logger.i('✅ Extensión de logging iniciada para usuario');
    } catch (e) {
      _logger.e('💥 Error inicializando extensión: $e');
    }
  }

  // Método existente actualizado
  Future<void> _inicializarDeviceLogService() async {
    try {
      // Solo inicializar si hay usuario logueado
      if (!_isUserLoggedIn) {
        _logger.w('⚠️ No se puede iniciar DeviceLogService sin usuario logueado');
        return;
      }

      final database = await DatabaseHelper().database;
      final repository = DeviceLogRepository(database);
      _deviceLogService = DeviceLogService(repository);

      // Iniciar registro automático cada 5 minutos
      await _deviceLogService!.iniciar(intervalo: const Duration(minutes: 5));

      _logger.i('✅ Servicio de registro de dispositivo iniciado para usuario');
    } catch (e) {
      _logger.e('Error al inicializar DeviceLogService: $e');
    }
  }

  // 🆕 NUEVO MÉTODO: Detener servicios al hacer logout
  Future<void> detenerEnLogout() async {
    try {
      _logger.i('🚪 Logout detectado - Deteniendo servicios de logging');

      _isUserLoggedIn = false;

      // Detener servicios
      _deviceLogService?.detener();
      await DeviceLogBackgroundExtension.detener();

      // Limpiar instancias
      _deviceLogService = null;

      _logger.i('✅ Servicios de logging detenidos por logout');
    } catch (e) {
      _logger.e('Error deteniendo servicios en logout: $e');
    }
  }

  // Getter existente (SIN CAMBIOS)
  DeviceLogService? get deviceLogService => _deviceLogService;

  // 🆕 NUEVO GETTER: Verificar si usuario está logueado
  bool get usuarioLogueado => _isUserLoggedIn;

  // Método existente (SIN CAMBIOS)
  Future<void> ejecutarLoggingManual() async {
    try {
      if (!_isUserLoggedIn) {
        _logger.w('⚠️ No se puede ejecutar logging manual sin usuario logueado');
        return;
      }

      await DeviceLogBackgroundExtension.ejecutarManual();
      _logger.i('✅ Logging manual ejecutado');
    } catch (e) {
      _logger.e('Error en logging manual: $e');
    }
  }

  // Método existente (SIN CAMBIOS)
  bool estaEnHorarioTrabajo() {
    return DeviceLogBackgroundExtension.estaEnHorarioTrabajo();
  }

  // Método existente actualizado
  Map<String, dynamic> obtenerEstadoServicios() {
    return {
      'usuario_logueado': _isUserLoggedIn,
      'servicio_normal': _deviceLogService?.estaActivo ?? false,
      'extension_activa': DeviceLogBackgroundExtension.estaActivo,
      ...DeviceLogBackgroundExtension.obtenerEstado(),
    };
  }

  // Método existente actualizado
  Future<void> detener() async {
    _logger.i('Deteniendo servicios');

    // Tu servicio existente (sin cambios)
    _deviceLogService?.detener();

    // Detener extensión
    await DeviceLogBackgroundExtension.detener();
  }

  // 🆕 NUEVO MÉTODO: Reiniciar servicios (útil para debugging)
  Future<void> reiniciarServicios() async {
    try {
      _logger.i('🔄 Reiniciando servicios de logging');

      // Detener servicios actuales
      await detener();

      // Esperar un momento
      await Future.delayed(const Duration(seconds: 1));

      // Reiniciar si hay usuario logueado
      if (_isUserLoggedIn) {
        await _inicializarExtensionLogging();
        await _inicializarDeviceLogService();
      }

      _logger.i('✅ Servicios reiniciados');
    } catch (e) {
      _logger.e('Error reiniciando servicios: $e');
    }
  }
}