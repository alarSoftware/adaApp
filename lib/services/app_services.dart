// lib/services/app_services.dart

import 'package:ada_app/services/database_helper.dart';
import 'package:ada_app/repositories/device_log_repository.dart';
import 'package:ada_app/services/device_log/device_log_service.dart';
import 'package:ada_app/services/device_log/device_log_background_extension.dart';
import 'package:ada_app/services/censo/censo_upload_service.dart';
import 'package:ada_app/services/dynamic_form/dynamic_form_upload_service.dart';
import 'package:ada_app/services/device_log/device_log_upload_service.dart';
import 'package:ada_app/services/auth_service.dart';
import 'package:ada_app/models/usuario.dart';
import 'package:logger/logger.dart';

class AppServices {
  static AppServices? _instance;
  static DeviceLogService? _deviceLogService;
  static bool _isUserLoggedIn = false;

  final _logger = Logger();

  AppServices._internal();

  factory AppServices() {
    return _instance ??= AppServices._internal();
  }

  // ==================== INICIALIZACIÓN EN LOGIN ====================

  /// Inicializar todos los servicios cuando el usuario hace login
  Future<void> inicializarEnLogin() async {
    try {
      _logger.i('🔐 Usuario logueado - Inicializando servicios');

      _isUserLoggedIn = true;

      // 1. Inicializar servicios de logging básicos
      await _inicializarExtensionLogging();
      await _inicializarDeviceLogService();

      // 2. Obtener información del usuario
      final usuario = await _obtenerUsuarioActual();

      if (usuario != null) {
        _logger.i('👤 Usuario: ${usuario.username} (ID: ${usuario.id})');

        // 3. Iniciar sincronizaciones automáticas
        await _iniciarSincronizacionesAutomaticas(usuario);
      } else {
        _logger.w('⚠️ No se pudo obtener información del usuario');
      }

      _logger.i('✅ Todos los servicios iniciados correctamente');
    } catch (e) {
      _logger.e('💥 Error al inicializar servicios en login: $e');
    }
  }

  /// Iniciar todas las sincronizaciones automáticas
  Future<void> _iniciarSincronizacionesAutomaticas(Usuario usuario) async {
    try {
      _logger.i('🔄 Iniciando sincronizaciones automáticas...');

      // Sincronización de Censos (cada 1 minuto)
      if (usuario.id != null) {
        CensoUploadService.iniciarSincronizacionAutomatica(usuario.id!);
        _logger.i('  ✅ Censos: cada 1 minuto');
      }

      // Sincronización de Formularios Dinámicos (cada 2 minutos)
      if (usuario.edfVendedorId != null && usuario.edfVendedorId!.isNotEmpty) {
        DynamicFormUploadService.iniciarSincronizacionAutomatica(usuario.edfVendedorId!);
        _logger.i('  ✅ Formularios: cada 2 minutos');
      }

      // Sincronización de Device Logs (cada 10 minutos)
      DeviceLogUploadService.iniciarSincronizacionAutomatica();
      _logger.i('  ✅ Device Logs: cada 10 minutos');

      _logger.i('✅ Sincronizaciones automáticas iniciadas');
    } catch (e) {
      _logger.e('💥 Error iniciando sincronizaciones: $e');
    }
  }

  // ==================== DETENER EN LOGOUT ====================

  /// Detener todos los servicios cuando el usuario hace logout
  Future<void> detenerEnLogout() async {
    try {
      _logger.i('🚪 Logout detectado - Deteniendo servicios');

      _isUserLoggedIn = false;

      // 1. Detener servicios de logging básicos
      _deviceLogService?.detener();
      await DeviceLogBackgroundExtension.detener();
      _deviceLogService = null;

      // 2. Detener sincronizaciones automáticas
      await _detenerSincronizacionesAutomaticas();

      _logger.i('✅ Todos los servicios detenidos por logout');
    } catch (e) {
      _logger.e('Error deteniendo servicios en logout: $e');
    }
  }

  /// Detener todas las sincronizaciones automáticas
  Future<void> _detenerSincronizacionesAutomaticas() async {
    try {
      _logger.i('🛑 Deteniendo sincronizaciones automáticas...');

      // Detener Censos
      CensoUploadService.detenerSincronizacionAutomatica();
      _logger.i('  ✅ Censos detenidos');

      // Detener Formularios
      DynamicFormUploadService.detenerSincronizacionAutomatica();
      _logger.i('  ✅ Formularios detenidos');

      // Detener Device Logs
      DeviceLogUploadService.detenerSincronizacionAutomatica();
      _logger.i('  ✅ Device Logs detenidos');

      _logger.i('✅ Sincronizaciones automáticas detenidas');
    } catch (e) {
      _logger.e('Error deteniendo sincronizaciones: $e');
    }
  }

  // ==================== MÉTODOS EXISTENTES ====================

  Future<void> inicializar() async {
    try {
      _logger.i('Inicializando servicios de la aplicación');

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

  Future<void> _inicializarExtensionLogging() async {
    try {
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

  Future<void> _inicializarDeviceLogService() async {
    try {
      if (!_isUserLoggedIn) {
        _logger.w('⚠️ No se puede iniciar DeviceLogService sin usuario logueado');
        return;
      }

      final database = await DatabaseHelper().database;
      final repository = DeviceLogRepository(database);
      _deviceLogService = DeviceLogService(repository);

      await _deviceLogService!.iniciar(intervalo: const Duration(minutes: 5));

      _logger.i('✅ Servicio de registro de dispositivo iniciado para usuario');
    } catch (e) {
      _logger.e('Error al inicializar DeviceLogService: $e');
    }
  }

  // ==================== GETTERS ====================

  DeviceLogService? get deviceLogService => _deviceLogService;
  bool get usuarioLogueado => _isUserLoggedIn;

  // ==================== MÉTODOS DE UTILIDAD ====================

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

  bool estaEnHorarioTrabajo() {
    return DeviceLogBackgroundExtension.estaEnHorarioTrabajo();
  }

  // ✅ MÉTODO CORREGIDO - Ahora es async
  Future<Map<String, dynamic>> obtenerEstadoServicios() async {
    try {
      // 🔍 Obtener estado de background extension
      final backgroundState = await DeviceLogBackgroundExtension.obtenerEstado();

      return {
        'usuario_logueado': _isUserLoggedIn,
        'servicio_normal': _deviceLogService?.estaActivo ?? false,
        'extension_activa': DeviceLogBackgroundExtension.estaActivo,
        'censo_sync_activo': CensoUploadService.esSincronizacionActiva,
        'formularios_sync_activo': DynamicFormUploadService.esSincronizacionActiva,
        'device_logs_sync_activo': DeviceLogUploadService.esSincronizacionActiva,
        // ✅ Agregar campos del background state individualmente
        'en_horario': backgroundState['en_horario'],
        'hora_actual': backgroundState['hora_actual'],
        'dia_actual': backgroundState['dia_actual'],
        'intervalo_minutos': backgroundState['intervalo_minutos'],
        'horario': backgroundState['horario'],
        'url_servidor': backgroundState['url_servidor'],
        'endpoint_completo': backgroundState['endpoint_completo'],
      };
    } catch (e) {
      _logger.e('Error obteniendo estado de servicios: $e');
      return {
        'usuario_logueado': _isUserLoggedIn,
        'servicio_normal': _deviceLogService?.estaActivo ?? false,
        'extension_activa': DeviceLogBackgroundExtension.estaActivo,
        'censo_sync_activo': false,
        'formularios_sync_activo': false,
        'device_logs_sync_activo': false,
        'error': 'No se pudo obtener estado completo',
      };
    }
  }

  Future<void> detener() async {
    _logger.i('Deteniendo servicios');

    _deviceLogService?.detener();
    await DeviceLogBackgroundExtension.detener();
  }

  Future<void> reiniciarServicios() async {
    try {
      _logger.i('🔄 Reiniciando servicios de logging');

      await detener();
      await Future.delayed(const Duration(seconds: 1));

      if (_isUserLoggedIn) {
        await _inicializarExtensionLogging();
        await _inicializarDeviceLogService();
      }

      _logger.i('✅ Servicios reiniciados');
    } catch (e) {
      _logger.e('Error reiniciando servicios: $e');
    }
  }

  // ==================== MÉTODOS PARA FORZAR SINCRONIZACIÓN ====================

  /// Fuerza la sincronización de censos pendientes
  Future<Map<String, int>?> forzarSincronizacionCensos() async {
    try {
      _logger.i('⚡ Forzando sincronización de censos...');
      return await CensoUploadService.forzarSincronizacion();
    } catch (e) {
      _logger.e('Error forzando sync de censos: $e');
      return null;
    }
  }

  /// Fuerza la sincronización de formularios pendientes
  Future<Map<String, int>?> forzarSincronizacionFormularios() async {
    try {
      _logger.i('⚡ Forzando sincronización de formularios...');
      return await DynamicFormUploadService.forzarSincronizacion();
    } catch (e) {
      _logger.e('Error forzando sync de formularios: $e');
      return null;
    }
  }

  /// Fuerza la sincronización de device logs pendientes
  Future<Map<String, int>?> forzarSincronizacionDeviceLogs() async {
    try {
      _logger.i('⚡ Forzando sincronización de device logs...');
      return await DeviceLogUploadService.forzarSincronizacion();
    } catch (e) {
      _logger.e('Error forzando sync de device logs: $e');
      return null;
    }
  }

  /// Fuerza sincronización de TODO
  Future<Map<String, dynamic>> forzarSincronizacionCompleta() async {
    try {
      _logger.i('⚡⚡⚡ Forzando sincronización completa...');

      final censos = await forzarSincronizacionCensos();
      final formularios = await forzarSincronizacionFormularios();
      final deviceLogs = await forzarSincronizacionDeviceLogs();

      return {
        'censos': censos ?? {'exitosos': 0, 'fallidos': 0, 'total': 0},
        'formularios': formularios ?? {'exitosos': 0, 'fallidos': 0, 'total': 0},
        'device_logs': deviceLogs ?? {'exitosos': 0, 'fallidos': 0, 'total': 0},
      };
    } catch (e) {
      _logger.e('Error en sincronización completa: $e');
      return {};
    }
  }

  // ==================== MÉTODOS PARA DEBUGGING ====================

  /// Mostrar configuración completa de todos los servicios
  Future<void> mostrarConfiguracionCompleta() async {
    try {
      _logger.i("═══════════════════════════════════════");
      _logger.i("🔧 CONFIGURACIÓN COMPLETA DE SERVICIOS");
      _logger.i("═══════════════════════════════════════");

      // Estado general
      final estado = await obtenerEstadoServicios();
      _logger.i("👤 Usuario logueado: ${estado['usuario_logueado']}");
      _logger.i("🔄 Servicios activos:");
      _logger.i("   • Background Extension: ${estado['extension_activa']}");
      _logger.i("   • Device Log Service: ${estado['servicio_normal']}");
      _logger.i("   • Censos Sync: ${estado['censo_sync_activo']}");
      _logger.i("   • Formularios Sync: ${estado['formularios_sync_activo']}");
      _logger.i("   • Device Logs Sync: ${estado['device_logs_sync_activo']}");

      // Configuración de Background Extension
      await DeviceLogBackgroundExtension.mostrarConfiguracion();

      // Configuración de Upload Service
      await DeviceLogUploadService.mostrarConfiguracion();

      _logger.i("═══════════════════════════════════════");
    } catch (e) {
      _logger.e("Error mostrando configuración: $e");
    }
  }

  // ==================== HELPER PRIVADO ====================

  /// Obtiene el usuario actualmente logueado
  Future<Usuario?> _obtenerUsuarioActual() async {
    try {
      final authService = AuthService();
      return await authService.getCurrentUser();
    } catch (e) {
      _logger.e('Error obteniendo usuario actual: $e');
      return null;
    }
  }
}