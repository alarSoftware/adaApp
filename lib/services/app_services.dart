import 'package:ada_app/services/device_log/device_log_background_extension.dart';
import 'package:ada_app/services/background/app_background_service.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:ada_app/services/dynamic_form/dynamic_form_upload_service.dart';
import 'package:ada_app/services/device_log/device_log_upload_service.dart';
import 'package:ada_app/services/api/auth_service.dart';
import 'package:ada_app/models/usuario.dart';
import 'package:logger/logger.dart';

class AppServices {
  static AppServices? _instance;
  static bool _isUserLoggedIn = false;

  final _logger = Logger();

  AppServices._internal();

  factory AppServices() {
    return _instance ??= AppServices._internal();
  }

  // ==================== INICIALIZACIÓN EN LOGIN ====================

  Future<void> inicializarEnLogin() async {
    try {
      _logger.i(
        'Usuario logueado - Inicializando servicios básicos (SIN device logging)',
      );

      _isUserLoggedIn = true;

      // 3. Inicializar device logging (Background Service)
      await AppBackgroundService.initialize();

      // 1. Obtener información del usuario
      final usuario = await _obtenerUsuarioActual();

      if (usuario != null) {
        _logger.i('Usuario: ${usuario.username} (ID: ${usuario.id})');

        // 2. Iniciar SOLO sincronizaciones automáticas (sin device logging)
        await _iniciarSincronizacionesAutomaticas(usuario);
      } else {
        _logger.w('No se pudo obtener información del usuario');
      }

      _logger.i('Servicios básicos iniciados correctamente');
      _logger.i(
        'NOTA: Device logging se iniciará después de la primera sincronización exitosa',
      );
    } catch (e) {
      _logger.e('Error al inicializar servicios en login: $e');
    }
  }

  // MÉTODO PARA INICIALIZAR DEVICE LOGGING DESPUÉS DE SINCRONIZACIÓN
  Future<void> inicializarDeviceLoggingDespuesDeSincronizacion() async {
    try {
      _logger.i(
        'Iniciando device logging después de sincronización exitosa...',
      );

      if (!_isUserLoggedIn) {
        _logger.w('No se puede iniciar device logging sin usuario logueado');
        return;
      }

      await AppBackgroundService.initialize();
      _logger.i(
        'Background Service iniciado exitosamente después de sincronización',
      );
    } catch (e) {
      _logger.e('Error iniciando device logging después de sincronización: $e');
    }
  }

  /// Iniciar todas las sincronizaciones automáticas (SIN device logging)
  Future<void> _iniciarSincronizacionesAutomaticas(Usuario usuario) async {
    try {
      _logger.i(
        'Iniciando sincronizaciones automáticas (SIN device logging)...',
      );

      // Sincronización de Censos (cada 1 minuto)
      // if (usuario.id != null) {
      //   CensoUploadService.iniciarSincronizacionAutomatica(usuario.id!);
      //   _logger.i('  Censos: cada 1 minuto');
      // }

      // Sincronización de Formularios Dinámicos (cada 2 minutos)
      if (usuario.employeeId != null && usuario.employeeId!.isNotEmpty) {
        // DynamicFormUploadService.iniciarSincronizacionAutomatica(usuario.employeeId!);
        _logger.i('  Formularios: cada 2 minutos');
      }

      // Sincronización de Device Logs (cada 10 minutos)
      // NOTA: Esto NO inicia el BackgroundExtension, solo sincroniza logs existentes
      DeviceLogUploadService.iniciarSincronizacionAutomatica();
      _logger.i('  Device Logs Upload: cada 10 minutos (para logs existentes)');

      _logger.i(
        'Sincronizaciones automáticas iniciadas (device logging pendiente)',
      );
    } catch (e) {
      _logger.e('Error iniciando sincronizaciones: $e');
    }
  }

  // ==================== DETENER EN LOGOUT ====================

  /// Detener todos los servicios cuando el usuario hace logout
  Future<void> detenerEnLogout() async {
    try {
      _logger.i('Logout detectado - Deteniendo servicios');

      _isUserLoggedIn = false;

      // 1. Detener device logging (Service)
      final service = FlutterBackgroundService();
      if (await service.isRunning()) {
        service.invoke("stopService");
      }

      // 2. Detener sincronizaciones automáticas
      await _detenerSincronizacionesAutomaticas();

      _logger.i('Todos los servicios detenidos por logout');
    } catch (e) {
      _logger.e('Error deteniendo servicios en logout: $e');
    }
  }

  /// Detener todas las sincronizaciones automáticas
  Future<void> _detenerSincronizacionesAutomaticas() async {
    try {
      // Detener Censos
      // CensoUploadService.detenerSincronizacionAutomatica();
      // OperacionComercialSyncService.detenerSincronizacionAutomatica();

      // Detener Formularios
      DynamicFormUploadService.detenerSincronizacionAutomatica();

      // Detener Device Logs
      DeviceLogUploadService.detenerSincronizacionAutomatica();
    } catch (e) {}
  }

  // ==================== MÉTODOS EXISTENTES ====================

  Future<void> inicializar() async {
    try {
      _logger.i('Inicializando servicios de la aplicación');

      // 🕒 CARGAR CONFIGURACIÓN DE HORARIO EN UI ISOLATE
      await DeviceLogBackgroundExtension.cargarConfiguracionHorario();

      // VERIFICACIÓN DOBLE: Si la variable interna es false, verificamos con AuthService por si acaso
      if (!_isUserLoggedIn) {
        final authService = AuthService();
        _isUserLoggedIn = await authService.hasUserLoggedInBefore();
      }

      if (_isUserLoggedIn) {
        // Inicializar background service si el usuario ya tiene sesión
        await AppBackgroundService.initialize();
        _logger.i('Servicios básicos y background service inicializados');
      } else {
        _logger.i('Usuario no logueado - servicios no iniciados');
      }
    } catch (e) {
      _logger.e('Error al inicializar servicios: $e');
    }
  }

  // ==================== GETTERS ====================

  bool get usuarioLogueado => _isUserLoggedIn;

  // ==================== MÉTODOS DE UTILIDAD ====================

  Future<void> ejecutarLoggingManual() async {
    try {
      if (!_isUserLoggedIn) {
        _logger.w('No se puede ejecutar logging manual sin usuario logueado');
        return;
      }

      await DeviceLogBackgroundExtension.ejecutarManual();
      _logger.i('Logging manual ejecutado');
    } catch (e) {
      _logger.e('Error en logging manual: $e');
    }
  }

  bool estaEnHorarioTrabajo() {
    return DeviceLogBackgroundExtension.estaEnHorarioTrabajo();
  }

  Future<Map<String, dynamic>> obtenerEstadoServicios() async {
    try {
      // Obtener estado de background extension
      final backgroundState =
          await DeviceLogBackgroundExtension.obtenerEstado();

      return {
        'usuario_logueado': _isUserLoggedIn,
        'extension_activa': DeviceLogBackgroundExtension.estaActivo,
        // 'censo_sync_activo': CensoUploadService.esSincronizacionActiva,
        'formularios_sync_activo':
            DynamicFormUploadService.esSincronizacionActiva,
        'device_logs_sync_activo':
            DeviceLogUploadService.esSincronizacionActiva,
        // Agregar campos del background state individualmente
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
    await DeviceLogBackgroundExtension.detener();
  }

  Future<void> reiniciarServicios() async {
    try {
      _logger.i('Reiniciando servicios de logging');

      await detener();
      await Future.delayed(const Duration(seconds: 1));

      if (_isUserLoggedIn) {
        // CAMBIO: NO reiniciar automáticamente el device logging
        _logger.i(
          'Device logging NO reiniciado - requiere sincronización previa',
        );
      }

      _logger.i('Servicios básicos reiniciados');
    } catch (e) {
      _logger.e('Error reiniciando servicios: $e');
    }
  }

  // ==================== MÉTODOS PARA FORZAR SINCRONIZACIÓN ====================

  /// Fuerza la sincronización de censos pendientes
  Future<Map<String, int>?> forzarSincronizacionCensos() async {
    try {
      _logger.i('Forzando sincronización de censos...');
      // return await CensoUploadService.forzarSincronizacion();
    } catch (e) {
      _logger.e('Error forzando sync de censos: $e');
      return null;
    }
    return null;
  }

  /// Fuerza la sincronización de formularios pendientes
  Future<Map<String, int>?> forzarSincronizacionFormularios() async {
    try {
      _logger.i('Forzando sincronización de formularios...');
      return await DynamicFormUploadService.forzarSincronizacion();
    } catch (e) {
      _logger.e('Error forzando sync de formularios: $e');
      return null;
    }
  }

  /// Fuerza la sincronización de device logs pendientes
  Future<Map<String, int>?> forzarSincronizacionDeviceLogs() async {
    try {
      _logger.i('Forzando sincronización de device logs...');
      return await DeviceLogUploadService.forzarSincronizacion();
    } catch (e) {
      _logger.e('Error forzando sync de device logs: $e');
      return null;
    }
  }

  /// Fuerza sincronización de TODO
  Future<Map<String, dynamic>> forzarSincronizacionCompleta() async {
    try {
      _logger.i('Forzando sincronización completa...');

      final censos = await forzarSincronizacionCensos();
      final formularios = await forzarSincronizacionFormularios();
      final deviceLogs = await forzarSincronizacionDeviceLogs();

      return {
        'censos': censos ?? {'exitosos': 0, 'fallidos': 0, 'total': 0},
        'formularios':
            formularios ?? {'exitosos': 0, 'fallidos': 0, 'total': 0},
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
      _logger.i("CONFIGURACIÓN COMPLETA DE SERVICIOS");
      _logger.i("═══════════════════════════════════════");

      // Estado general
      final estado = await obtenerEstadoServicios();
      _logger.i("Usuario logueado: ${estado['usuario_logueado']}");
      _logger.i("Servicios activos:");
      _logger.i("   • Background Extension: ${estado['extension_activa']}");
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
