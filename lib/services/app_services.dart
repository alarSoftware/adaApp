import 'package:ada_app/services/device_log/device_log_background_extension.dart';
import 'package:ada_app/services/background/app_background_service.dart';

import 'package:ada_app/services/device_log/device_log_upload_service.dart';
import 'package:ada_app/services/sync/operacion_comercial_sync_service.dart';
import 'package:ada_app/services/api/auth_service.dart';
import 'package:ada_app/models/usuario.dart';

class AppServices {
  static AppServices? _instance;
  static bool _isUserLoggedIn = false;

  AppServices._internal();

  factory AppServices() {
    return _instance ??= AppServices._internal();
  }

  // ==================== INICIALIZACIÓN EN LOGIN ====================

  Future<void> inicializarEnLogin() async {
    try {
      print(
        'User logged in - Initializing basic services (no device logging yet)',
      );

      _isUserLoggedIn = true;

      await AppBackgroundService.initialize();

      final usuario = await _obtenerUsuarioActual();

      if (usuario != null) {
        print('Usuario: ${usuario.username} (ID: ${usuario.id})');

        // 2. Iniciar SOLO sincronizaciones automáticas (sin device logging)
        await _iniciarSincronizacionesAutomaticas(usuario);
      } else {
        print('No se pudo obtener información del usuario');
      }

      print('Servicios básicos iniciados correctamente');
      print(
        'NOTA: Device logging se iniciará después de la primera sincronización exitosa',
      );
    } catch (e) {
      print('Error al inicializar servicios en login: $e');
    }
  }

  Future<void> inicializarDeviceLoggingDespuesDeSincronizacion() async {
    try {
      print('Iniciando device logging después de sincronización exitosa...');

      if (!_isUserLoggedIn) {
        print('No se puede iniciar device logging sin usuario logueado');
        return;
      }

      await AppBackgroundService.initialize();

      print(
        'Background Service iniciado exitosamente después de sincronización',
      );
    } catch (e) {
      print('Error iniciando device logging después de sincronización: $e');
    }
  }

  /// Iniciar todas las sincronizaciones automáticas (SIN device logging)
  Future<void> _iniciarSincronizacionesAutomaticas(Usuario usuario) async {
    try {
      print('Iniciando sincronizaciones automáticas (SIN device logging)...');
      // Sincronización de Formularios Dinámicos (cada 2 minutos)
      if (usuario.employeeId != null && usuario.employeeId!.isNotEmpty) {}

      // Sincronización de Operaciones Comerciales
      if (usuario.id != null) {
        OperacionComercialSyncService.iniciarSincronizacionAutomatica(
          usuario.id!,
        );
        print('  Operaciones Comerciales Sync: iniciado');
      }

      // Sincronización de Device Logs (cada 10 minutos)
      // NOTA: Esto NO inicia el BackgroundExtension, solo sincroniza logs existentes
      DeviceLogUploadService.iniciarSincronizacionAutomatica();
      print('  Device Logs Upload: cada 10 minutos (para logs existentes)');

      print(
        'Sincronizaciones automáticas iniciadas (device logging pendiente)',
      );
    } catch (e) {
      print('Error iniciando sincronizaciones: $e');
    }
  }

  // ==================== DETENER EN LOGOUT ====================

  /// Detener todos los servicios cuando el usuario hace logout
  Future<void> detenerEnLogout() async {
    try {
      print('Logout detectado - Deteniendo servicios');

      _isUserLoggedIn = false;

      // 1. Detener device logging (Service)
      await AppBackgroundService.stopService();

      // 2. Detener sincronizaciones automáticas
      await _detenerSincronizacionesAutomaticas();

      print('Todos los servicios detenidos por logout');
    } catch (e) {
      print('Error deteniendo servicios en logout: $e');
    }
  }

  /// Detener todas las sincronizaciones automáticas
  Future<void> _detenerSincronizacionesAutomaticas() async {
    try {
      // Detener Censos
      // CensoUploadService.detenerSincronizacionAutomatica();
      OperacionComercialSyncService.detenerSincronizacionAutomatica();

      // Detener Device Logs
      DeviceLogUploadService.detenerSincronizacionAutomatica();
    } catch (e) {}
  }

  // ==================== MÉTODOS EXISTENTES ====================

  Future<void> inicializar() async {
    try {
      print('Initializing app services');

      // Load work hours config
      await DeviceLogBackgroundExtension.cargarConfiguracionHorario();

      // Verificamos con AuthService por si acaso
      if (!_isUserLoggedIn) {
        final authService = AuthService();
        _isUserLoggedIn = await authService.hasUserLoggedInBefore();
      }

      if (_isUserLoggedIn) {
        // Inicializar background service si el usuario ya tiene sesión
        await AppBackgroundService.initialize();

        print('Servicios básicos y background service inicializados');

        // 🔴 CRITICAL FIX: Iniciar sincronizaciones automáticas si el usuario ya está logueado
        final usuario = await _obtenerUsuarioActual();
        if (usuario != null) {
          await _iniciarSincronizacionesAutomaticas(usuario);
          print(
            'Sincronizaciones automáticas restauradas para usuario: ${usuario.username}',
          );
        }
      } else {
        print('Usuario no logueado - servicios no iniciados');
      }
    } catch (e) {
      print('Error al inicializar servicios: $e');
    }
  }

  // ==================== GETTERS ====================

  bool get usuarioLogueado => _isUserLoggedIn;

  // ==================== MÉTODOS DE UTILIDAD ====================

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
        'formularios_sync_activo': false,
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
      print('Error obteniendo estado de servicios: $e');
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
    print('Deteniendo servicios');
    await DeviceLogBackgroundExtension.detener();
  }

  Future<void> reiniciarServicios() async {
    try {
      print('Reiniciando servicios de logging');

      await detener();
      await Future.delayed(const Duration(seconds: 1));

      if (_isUserLoggedIn) {
        // NO reiniciar automáticamente el device logging
        print('Device logging NO reiniciado - requiere sincronización previa');
      }

      print('Servicios básicos reiniciados');
    } catch (e) {
      print('Error reiniciando servicios: $e');
    }
  }

  // ==================== MÉTODOS PARA FORZAR SINCRONIZACIÓN ====================

  /// Fuerza la sincronización de censos pendientes
  Future<Map<String, int>?> forzarSincronizacionCensos() async {
    try {
      print('Forzando sincronización de censos...');
      // return await CensoUploadService.forzarSincronizacion();
    } catch (e) {
      print('Error forzando sync de censos: $e');
      return null;
    }
    return null;
  }

  /// Fuerza la sincronización de formularios pendientes
  Future<Map<String, int>?> forzarSincronizacionFormularios() async {
    try {
      print('Forzando sincronización de formularios... (Not implemented)');
      return null;
    } catch (e) {
      print('Error forzando sync de formularios: $e');
      return null;
    }
  }

  /// Fuerza la sincronización de device logs pendientes
  Future<Map<String, int>?> forzarSincronizacionDeviceLogs() async {
    try {
      print('Forzando sincronización de device logs...');
      return await DeviceLogUploadService.forzarSincronizacion();
    } catch (e) {
      print('Error forzando sync de device logs: $e');
      return null;
    }
  }

  /// Fuerza sincronización de TODO
  Future<Map<String, dynamic>> forzarSincronizacionCompleta() async {
    try {
      print('Forzando sincronización completa...');

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
      print('Error en sincronización completa: $e');
      return {};
    }
  }

  // ==================== MÉTODOS PARA DEBUGGING ====================

  /// Mostrar configuración completa de todos los servicios
  Future<void> mostrarConfiguracionCompleta() async {
    try {
      print("FULL SERVICE CONFIGURATION");

      // Estado general
      final estado = await obtenerEstadoServicios();
      print("Usuario logueado: ${estado['usuario_logueado']}");
      print("Servicios activos:");
      print("   • Background Extension: ${estado['extension_activa']}");
      print("   • Censos Sync: ${estado['censo_sync_activo']}");
      print("   • Formularios Sync: ${estado['formularios_sync_activo']}");
      print("   • Device Logs Sync: ${estado['device_logs_sync_activo']}");

      // Configuración de Background Extension
      await DeviceLogBackgroundExtension.mostrarConfiguracion();

      // Configuración de Upload Service
      await DeviceLogUploadService.mostrarConfiguracion();
    } catch (e) {
      print("Error mostrando configuración: $e");
    }
  }

  // ==================== HELPER PRIVADO ====================

  /// Obtiene el usuario actualmente logueado
  Future<Usuario?> _obtenerUsuarioActual() async {
    try {
      final authService = AuthService();
      return await authService.getCurrentUser();
    } catch (e) {
      print('Error obteniendo usuario actual: $e');
      return null;
    }
  }
}
