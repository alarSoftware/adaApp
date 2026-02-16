import 'package:ada_app/services/device_log/device_log_background_extension.dart';
import 'package:ada_app/services/background/app_background_service.dart';

import 'package:ada_app/services/device_log/device_log_upload_service.dart';
import 'package:ada_app/services/sync/operacion_comercial_sync_service.dart';
import 'package:ada_app/services/api/auth_service.dart';
import 'package:ada_app/models/usuario.dart';
import 'package:ada_app/services/websocket/socket_service.dart';
import 'package:ada_app/utils/logger.dart';

class AppServices {
  static AppServices? _instance;
  static bool _isUserLoggedIn = false;

  AppServices._internal();

  factory AppServices() {
    return _instance ??= AppServices._internal();
  }

  // ==================== INICIALIZACIÓN EN LOGIN ====================
  Future<void> inicializarEnLogin({String? password}) async {
    try {
      AppLogger.i(
        'User logged in - Initializing basic services (no device logging yet)',
      );
      _isUserLoggedIn = true;
      await AppBackgroundService.initialize();
      final usuario = await _obtenerUsuarioActual();

      if (usuario != null) {
        AppLogger.i('Usuario: ${usuario.username} (ID: ${usuario.id})');
        await _iniciarSincronizacionesAutomaticas(usuario);
      } else {
        AppLogger.w('No se pudo obtener información del usuario');
      }

      if (usuario != null) {
        SocketService().enableReconnect();
        SocketService().connect(username: usuario.username, password: password);
      }

      AppLogger.i('Servicios básicos iniciados correctamente');
      AppLogger.i(
        'NOTA: Device logging se iniciará después de la primera sincronización exitosa',
      );
    } catch (e) {
      AppLogger.e('Error al inicializar servicios en login', e);
    }
  }

  Future<void> inicializarDeviceLoggingDespuesDeSincronizacion() async {
    try {
      AppLogger.i(
        'Iniciando device logging después de sincronización exitosa...',
      );

      if (!_isUserLoggedIn) {
        AppLogger.w('No se puede iniciar device logging sin usuario logueado');
        return;
      }

      await AppBackgroundService.initialize();

      AppLogger.i(
        'Background Service iniciado exitosamente después de sincronización',
      );
    } catch (e) {
      AppLogger.e(
        'Error iniciando device logging después de sincronización',
        e,
      );
    }
  }

  /// Iniciar todas las sincronizaciones automáticas (SIN device logging)
  Future<void> _iniciarSincronizacionesAutomaticas(Usuario usuario) async {
    try {
      AppLogger.i(
        'Iniciando sincronizaciones automáticas (SIN device logging)...',
      );

      if (usuario.id != null) {
        OperacionComercialSyncService.iniciarSincronizacionAutomatica(
          usuario.id!,
        );
        AppLogger.i('  Operaciones Comerciales Sync: iniciado');
      }

      DeviceLogUploadService.iniciarSincronizacionAutomatica();
      AppLogger.i(
        '  Device Logs Upload: cada 10 minutos (para logs existentes)',
      );

      AppLogger.i(
        'Sincronizaciones automáticas iniciadas (device logging pendiente)',
      );
    } catch (e) {
      AppLogger.e('Error iniciando sincronizaciones', e);
    }
  }

  // ==================== DETENER EN LOGOUT ====================

  /// Detener todos los servicios cuando el usuario hace logout
  Future<void> detenerEnLogout() async {
    try {
      AppLogger.i('Logout detectado - Deteniendo servicios');
      _isUserLoggedIn = false;
      await AppBackgroundService.stopService();
      await _detenerSincronizacionesAutomaticas();
      SocketService().disconnect();
      AppLogger.i('Todos los servicios detenidos por logout');
    } catch (e) {
      AppLogger.e('Error deteniendo servicios en logout', e);
    }
  }

  /// Detener todas las sincronizaciones automáticas
  Future<void> _detenerSincronizacionesAutomaticas() async {
    try {
      OperacionComercialSyncService.detenerSincronizacionAutomatica();
      DeviceLogUploadService.detenerSincronizacionAutomatica();
    } catch (e) {
      AppLogger.e('Error deteniendo sincronizaciones automáticas', e);
    }
  }

  // ==================== MÉTODOS EXISTENTES ====================

  Future<void> inicializar() async {
    try {
      AppLogger.i('Initializing app services');
      await DeviceLogBackgroundExtension.cargarConfiguracionHorario();

      if (!_isUserLoggedIn) {
        final authService = AuthService();
        _isUserLoggedIn = await authService.hasUserLoggedInBefore();
      }

      if (_isUserLoggedIn) {
        await AppBackgroundService.initialize();
        AppLogger.i('Servicios básicos y background service inicializados');

        final usuario = await _obtenerUsuarioActual();
        if (usuario != null) {
          await _iniciarSincronizacionesAutomaticas(usuario);
          AppLogger.i(
            'Sincronizaciones automaticas restauradas para usuario: ${usuario.username}',
          );

          SocketService().enableReconnect();
          SocketService().connect(username: usuario.username);
        } else {
          AppLogger.w('Usuario no disponible - WebSocket no conectado');
        }
      } else {
        AppLogger.i('Usuario no logueado - servicios no iniciados');
      }
    } catch (e) {
      AppLogger.e('Error al inicializar servicios', e);
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
      AppLogger.e('Error obteniendo estado de servicios', e);
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
    AppLogger.i('Deteniendo servicios');
    await DeviceLogBackgroundExtension.detener();
  }

  Future<void> reiniciarServicios() async {
    try {
      AppLogger.i('Reiniciando servicios de logging');

      await detener();
      await Future.delayed(const Duration(seconds: 1));

      if (_isUserLoggedIn) {
        AppLogger.i(
          'Device logging NO reiniciado - requiere sincronización previa',
        );
      }

      AppLogger.i('Servicios básicos reiniciados');
    } catch (e) {
      AppLogger.e('Error reiniciando servicios', e);
    }
  }

  // ==================== MÉTODOS PARA FORZAR SINCRONIZACIÓN ====================

  /// Fuerza la sincronización de censos pendientes
  Future<Map<String, int>?> forzarSincronizacionCensos() async {
    try {
      AppLogger.i('Forzando sincronización de censos...');
    } catch (e) {
      AppLogger.e('Error forzando sync de censos', e);
      return null;
    }
    return null;
  }

  /// Fuerza la sincronización de formularios pendientes
  Future<Map<String, int>?> forzarSincronizacionFormularios() async {
    try {
      AppLogger.i(
        'Forzando sincronización de formularios... (Not implemented)',
      );
      return null;
    } catch (e) {
      AppLogger.e('Error forzando sync de formularios', e);
      return null;
    }
  }

  /// Fuerza la sincronización de device logs pendientes
  Future<Map<String, int>?> forzarSincronizacionDeviceLogs() async {
    try {
      AppLogger.i('Forzando sincronización de device logs...');
      return await DeviceLogUploadService.forzarSincronizacion();
    } catch (e) {
      AppLogger.e('Error forzando sync de device logs', e);
      return null;
    }
  }

  /// Fuerza sincronización de TODO
  Future<Map<String, dynamic>> forzarSincronizacionCompleta() async {
    try {
      AppLogger.i('Forzando sincronización completa...');
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
      AppLogger.e('Error en sincronización completa', e);
      return {};
    }
  }

  // ==================== MÉTODOS PARA DEBUGGING ====================

  /// Mostrar configuración completa de todos los servicios
  Future<void> mostrarConfiguracionCompleta() async {
    try {
      AppLogger.i("FULL SERVICE CONFIGURATION");

      final estado = await obtenerEstadoServicios();
      AppLogger.i("Usuario logueado: ${estado['usuario_logueado']}");
      AppLogger.i("Servicios activos:");
      AppLogger.i("   • Background Extension: ${estado['extension_activa']}");
      AppLogger.i("   • Censos Sync: ${estado['censo_sync_activo']}");
      AppLogger.i(
        "   • Formularios Sync: ${estado['formularios_sync_activo']}",
      );
      AppLogger.i(
        "   • Device Logs Sync: ${estado['device_logs_sync_activo']}",
      );

      await DeviceLogBackgroundExtension.mostrarConfiguracion();
      await DeviceLogUploadService.mostrarConfiguracion();
    } catch (e) {
      AppLogger.e("Error mostrando configuración", e);
    }
  }

  // ==================== HELPER PRIVADO ====================

  /// Obtiene el usuario actualmente logueado
  Future<Usuario?> _obtenerUsuarioActual() async {
    try {
      final authService = AuthService();
      return await authService.getCurrentUser();
    } catch (e) {
      AppLogger.e('Error obteniendo usuario actual', e);
      return null;
    }
  }
}
