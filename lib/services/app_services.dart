import 'package:ada_app/services/database_helper.dart';
import 'package:ada_app/repositories/device_log_repository.dart';
import 'package:ada_app/services/device_log/device_log_service.dart';
import 'package:logger/logger.dart';

class AppServices {
  static AppServices? _instance;
  static DeviceLogService? _deviceLogService;

  final _logger = Logger();

  AppServices._internal();

  factory AppServices() {
    return _instance ??= AppServices._internal();
  }

  // Inicializar todos los servicios de la app
  Future<void> inicializar() async {
    try {
      _logger.i('Inicializando servicios de la aplicación');

      // Inicializar servicio de registro de dispositivo
      await _inicializarDeviceLogService();

      _logger.i('Servicios inicializados correctamente');
    } catch (e) {
      _logger.e('Error al inicializar servicios: $e');
    }
  }

  Future<void> _inicializarDeviceLogService() async {
    try {
      final database = await DatabaseHelper().database;
      final repository = DeviceLogRepository(database);
      _deviceLogService = DeviceLogService(repository);

      // Iniciar registro automático cada 5 minutos
      await _deviceLogService!.iniciar(intervalo: const Duration(minutes: 5));

      _logger.i('Servicio de registro de dispositivo iniciado');
    } catch (e) {
      _logger.e('Error al inicializar DeviceLogService: $e');
    }
  }

  // Getter para acceder al servicio desde otras partes de la app
  DeviceLogService? get deviceLogService => _deviceLogService;

  // Detener todos los servicios (útil al cerrar sesión)
  void detener() {
    _logger.i('Deteniendo servicios');
    _deviceLogService?.detener();
  }
}