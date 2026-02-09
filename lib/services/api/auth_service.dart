import 'package:shared_preferences/shared_preferences.dart';
import 'package:bcrypt/bcrypt.dart';

import 'package:ada_app/services/data/database_helper.dart';
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/services/sync/dynamic_form_sync_service.dart';
import 'package:ada_app/services/sync/user_sync_service.dart';

import 'package:ada_app/services/error_log/error_log_service.dart';
import 'package:ada_app/services/app_services.dart';
import 'package:ada_app/services/device_log/device_log_background_extension.dart';
import 'package:ada_app/services/background/app_background_service.dart';
import 'package:ada_app/models/usuario.dart';
import 'package:ada_app/utils/device_info_helper.dart';
import 'package:ada_app/models/device_log.dart';
import 'package:ada_app/services/post/device_log_post_service.dart';
import 'package:ada_app/repositories/device_log_repository.dart';

class SyncValidationResult {
  final bool requiereSincronizacion;
  final String razon;
  final String? vendedorAnteriorId;
  final String vendedorActualId;
  final String? vendedorAnteriorNombre;
  final String vendedorActualNombre;

  SyncValidationResult({
    required this.requiereSincronizacion,
    required this.razon,
    required this.vendedorAnteriorId,
    required this.vendedorActualId,
    this.vendedorAnteriorNombre,
    required this.vendedorActualNombre,
  });

  @override
  String toString() =>
      'SyncValidationResult(requiere: $requiereSincronizacion, anterior: $vendedorAnteriorNombre, actual: $vendedorActualNombre)';
}

class AuthService {
  static const String _keyHasLoggedIn = 'has_logged_in_before';
  static const String _keyCurrentUser = 'current_user';
  static const String _keyCurrentUserRole = 'current_user_role';
  static const String _keyLastLoginDate = 'last_login_date';
  static const String _keyLastSyncedVendedor = 'last_synced_vendedor_id';
  static const String _keyLastSyncedVendedorName = 'last_synced_vendedor_name';

  static AuthService? _instance;
  AuthService._internal();
  factory AuthService() => _instance ??= AuthService._internal();

  static final _dbHelper = DatabaseHelper();

  // Helper para construir el nombre del vendedor
  String _buildVendorDisplayName(Usuario usuario) {
    if (usuario.employeeName != null &&
        usuario.employeeName!.trim().isNotEmpty) {
      return '${usuario.username} - ${usuario.employeeName}';
    }
    return usuario.username;
  }

  Future<SyncValidationResult> validateSyncRequirement(
    String currentEmployeeId,
    String currentEmployeeName,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncedVendedorId = prefs.getString(_keyLastSyncedVendedor);

      final lastSyncedVendedorName =
          prefs.getString(_keyLastSyncedVendedorName) ??
          lastSyncedVendedorId ??
          'Anterior';

      if (lastSyncedVendedorId == null) {
        return SyncValidationResult(
          requiereSincronizacion: true,
          razon: 'Primera sincronización requerida',
          vendedorAnteriorId: null,
          vendedorActualId: currentEmployeeId,
          vendedorAnteriorNombre: null,
          vendedorActualNombre: currentEmployeeName,
        );
      }

      if (lastSyncedVendedorId != currentEmployeeId) {
        return SyncValidationResult(
          requiereSincronizacion: true,
          razon: 'Cambio de vendedor detectado',
          vendedorAnteriorId: lastSyncedVendedorId,
          vendedorActualId: currentEmployeeId,
          vendedorAnteriorNombre: lastSyncedVendedorName,
          vendedorActualNombre: currentEmployeeName,
        );
      }

      return SyncValidationResult(
        requiereSincronizacion: false,
        razon: 'Mismo vendedor que la sincronización anterior',
        vendedorAnteriorId: lastSyncedVendedorId,
        vendedorActualId: currentEmployeeId,
        vendedorAnteriorNombre: lastSyncedVendedorName,
        vendedorActualNombre: currentEmployeeName,
      );
    } catch (e) {
      return SyncValidationResult(
        requiereSincronizacion: true,
        razon: 'Error en validación - sincronización por seguridad',
        vendedorAnteriorId: null,
        vendedorActualId: currentEmployeeId,
        vendedorAnteriorNombre: null,
        vendedorActualNombre: currentEmployeeName,
      );
    }
  }

  Future<void> markSyncCompleted(String employeeId, String employeeName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLastSyncedVendedor, employeeId);
      await prefs.setString(_keyLastSyncedVendedorName, employeeName);
      await prefs.setString('last_sync_date', DateTime.now().toIso8601String());

      try {
        await AppServices().inicializarDeviceLoggingDespuesDeSincronizacion();
      } catch (e) {}
    } catch (e) {}
  }

  Future<void> clearSyncData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyLastSyncedVendedor);
      await prefs.remove(_keyLastSyncedVendedorName);
      await prefs.remove('last_sync_date');

      await _dbHelper.eliminar('clientes');
    } catch (e) {}
  }

  static Future<SyncResult> sincronizarSoloUsuarios() async {
    // Delegar al servicio centralizado de sincronización de usuarios
    // Esto asegura que se use la misma lógica de "adaAppJsonPermission" y manejo de errores
    try {
      // Necesitamos importar el servicio, se agregará en los imports
      return await UserSyncService.sincronizarUsuarios();
    } catch (e) {
      await ErrorLogService.logError(
        tableName: 'Users',
        operation: 'sync_from_server',
        errorMessage: 'Error delegando sync usuarios: $e',
        errorType: 'unknown',
      );
      return SyncResult(
        exito: false,
        mensaje: 'Error interno: $e',
        itemsSincronizados: 0,
      );
    }
  }

  // static Future<SyncResult> sincronizarClientesDelVendedor(
  //   String employeeId,
  // ) async {
  //   try {
  //     final baseUrl = await BaseSyncService.getBaseUrl();
  //     final url = '$baseUrl/api/getEdfClientes?employeeId=$employeeId';
  //
  //     final response = await http
  //         .get(Uri.parse(url), headers: BaseSyncService.headers)
  //         .timeout(BaseSyncService.timeout);
  //
  //     if (response.statusCode >= 200 && response.statusCode < 300) {
  //       final List<dynamic> clientesAPI = BaseSyncService.parseResponse(
  //         response.body,
  //       );
  //
  //       if (clientesAPI.isEmpty) {
  //         return SyncResult(
  //           exito: true,
  //           mensaje: 'No hay clientes para este vendedor',
  //           itemsSincronizados: 0,
  //         );
  //       }
  //
  //       final clientesProcesados = <Map<String, dynamic>>[];
  //
  //       for (final cliente in clientesAPI) {
  //         if (cliente['cliente'] == null ||
  //             cliente['cliente'].toString().trim().isEmpty) {
  //           continue;
  //         }
  //
  //         String rucCi = '';
  //         if (cliente['ruc'] != null &&
  //             cliente['ruc'].toString().trim().isNotEmpty) {
  //           rucCi = cliente['ruc'].toString().trim();
  //         } else if (cliente['cedula'] != null &&
  //             cliente['cedula'].toString().trim().isNotEmpty) {
  //           rucCi = cliente['cedula'].toString().trim();
  //         }
  //
  //         clientesProcesados.add({
  //           'id': cliente['id'],
  //           'nombre': cliente['cliente'].toString().trim(),
  //           'telefono': cliente['telefono']?.toString().trim() ?? '',
  //           'direccion': cliente['direccion']?.toString().trim() ?? '',
  //           'ruc_ci': rucCi,
  //           'propietario': cliente['propietario']?.toString().trim() ?? '',
  //         });
  //       }
  //
  //       if (clientesProcesados.isEmpty) {
  //         return SyncResult(
  //           exito: false,
  //           mensaje: 'No se procesaron clientes válidos',
  //           itemsSincronizados: 0,
  //         );
  //       }
  //
  //       await _dbHelper.sincronizarClientes(clientesProcesados);
  //
  //       return SyncResult(
  //         exito: true,
  //         mensaje: 'Clientes sincronizados correctamente',
  //         itemsSincronizados: clientesProcesados.length,
  //         totalEnAPI: clientesProcesados.length,
  //       );
  //     } else {
  //       final mensaje = BaseSyncService.extractErrorMessage(response);
  //       return SyncResult(
  //         exito: false,
  //         mensaje: mensaje,
  //         itemsSincronizados: 0,
  //       );
  //     }
  //   } catch (e) {
  //     await ErrorLogService.logError(
  //       tableName: 'Clientes',
  //       operation: 'sync_from_server',
  //       errorMessage: 'Error sincronizando clientes: $e',
  //       errorType: 'unknown',
  //     );
  //     return SyncResult(
  //       exito: false,
  //       mensaje: BaseSyncService.getErrorMessage(e),
  //       itemsSincronizados: 0,
  //     );
  //   }
  // }

  static Future<SyncResult> sincronizarRespuestasDelVendedor(
    String employeeId,
  ) async {
    try {
      return await DynamicFormSyncService.obtenerRespuestasPorVendedor(
        employeeId,
      );
    } catch (e) {
      return SyncResult(
        exito: false,
        mensaje: 'Error: $e',
        itemsSincronizados: 0,
      );
    }
  }

  Future<AuthResult> login(String username, String password) async {
    try {
      final usuarios = await _dbHelper.obtenerUsuarios();
      final usuarioEncontrado = usuarios
          .where((u) => u.username.toLowerCase() == username.toLowerCase())
          .firstOrNull;

      if (usuarioEncontrado == null) {
        return AuthResult(exitoso: false, mensaje: 'Usuario no encontrado');
      }

      final passwordValido = BCrypt.checkpw(
        password,
        usuarioEncontrado.password,
      );
      if (!passwordValido) {
        return AuthResult(exitoso: false, mensaje: 'Credenciales incorrectas');
      }

      final usuarioAuth = UsuarioAuth.fromUsuario(usuarioEncontrado);
      await _saveLoginSuccess(usuarioAuth);

      try {
        await AppServices().inicializarEnLogin();
      } catch (e) {}

      return AuthResult(
        exitoso: true,
        mensaje: 'Bienvenido, ${usuarioEncontrado.fullname}',
        usuario: usuarioAuth,
      );
    } catch (e) {
      return AuthResult(
        exitoso: false,
        mensaje: 'Error en el inicio de sesión',
      );
    }
  }

  Future<AuthResult> authenticateWithBiometric() async {
    try {
      final currentUser = await getCurrentUser();
      if (currentUser == null) {
        return AuthResult(
          exitoso: false,
          mensaje: 'Debes iniciar sesión con credenciales primero',
        );
      }

      final usuarioAuth = UsuarioAuth.fromUsuario(currentUser);

      if (currentUser.employeeId != null) {
        // Usar el método helper para construir el nombre
        final nombreVendedor = _buildVendorDisplayName(currentUser);

        final syncValidation = await validateSyncRequirement(
          currentUser.employeeId!,
          nombreVendedor,
        );

        if (!syncValidation.requiereSincronizacion) {
          try {
            await AppBackgroundService.initialize();
          } catch (e) {}
        }
      }

      return AuthResult(
        exitoso: true,
        mensaje: 'Bienvenido de nuevo, ${currentUser.fullname}',
        usuario: usuarioAuth,
      );
    } catch (e) {
      return AuthResult(
        exitoso: false,
        mensaje: 'Error en autenticación biométrica',
      );
    }
  }

  Future<AuthResult> forceLogin(Usuario usuario) async {
    try {
      final usuarioAuth = UsuarioAuth.fromUsuario(usuario);
      await _saveLoginSuccess(usuarioAuth);

      try {
        await AppServices().inicializarEnLogin();
      } catch (e) {}

      return AuthResult(
        exitoso: true,
        mensaje: 'Bienvenido (Debug), ${usuario.fullname}',
        usuario: usuarioAuth,
      );
    } catch (e) {
      return AuthResult(
        exitoso: false,
        mensaje: 'Error en inicio de sesión forzado',
      );
    }
  }

  Future<void> logout() async {
    try {
      // 1. PRIMERO: Obtener usuario ANTES de limpiar (necesario para el device log)
      final currentUser = await getCurrentUser();

      // 2. Detener sincronizaciones y servicios para que no bloqueen
      try {
        await AppServices().detenerEnLogout();
      } catch (e) {
        print('Error deteniendo servicios: $e');
      }

      // 3. Crear y GUARDAR el device log (esperar solo el guardado, no el envío)
      if (currentUser != null) {
        await _guardarLogoutLog(currentUser);
      }

      // 4. Limpiar sesión
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyHasLoggedIn);
      await prefs.remove(_keyCurrentUser);
      await prefs.remove(_keyCurrentUserRole);

      print('Logout completado');
    } catch (e) {
      print('Error en logout: $e');
    }
  }

  /// Guarda el DeviceLog de logout en BD local y envía al servidor en segundo plano
  Future<void> _guardarLogoutLog(Usuario currentUser) async {
    try {
      print('Guardando device log de logout...');

      // Usar método rápido para no bloquear (usa última ubicación conocida)
      final log = await DeviceInfoHelper.crearDeviceLogRapido();

      if (log != null) {
        final parts = log.latitudLongitud.split(',');
        double lat = 0.0;
        double long = 0.0;
        if (parts.length == 2) {
          lat = double.tryParse(parts[0]) ?? 0.0;
          long = double.tryParse(parts[1]) ?? 0.0;
        }

        // Guardar en BD local primero
        final db = await _dbHelper.database;
        final repository = DeviceLogRepository(db);

        // Crear una instancia nueva con la marca [LOGOUT]
        final logId = await repository.guardarLog(
          id: log.id,
          employeeId: log.employeeId,
          latitud: lat,
          longitud: long,
          bateria: log.bateria,
          modelo: '${log.modelo} [LOGOUT]',
        );

        print('✅ Device log de logout guardado en BD local (ID: $logId)');

        // Recuperar el objeto completo desde la BD
        final logParaEnviar = await repository.obtenerPorId(logId);

        if (logParaEnviar != null) {
          // Enviar al servidor en segundo plano (fire and forget)
          DeviceLogPostService.enviarDeviceLog(
                logParaEnviar,
                userId: currentUser.id.toString(),
              )
              .then((resultado) async {
                if (resultado['exito'] == true) {
                  await repository.marcarComoSincronizado(logId);
                  print('✅ Logout log enviado y sincronizado');
                } else {
                  print(
                    '⚠️ Logout log guardado, se sincronizará después: ${resultado['mensaje']}',
                  );
                }
              })
              .catchError((e) {
                print('⚠️ Logout log guardado, se sincronizará después: $e');
              });
        }
      } else {
        print('⚠️ No se pudo crear device log de logout');
      }
    } catch (e) {
      print('Error guardando logout log: $e');
    }
  }

  Future<void> clearAllData() async {
    try {
      await DeviceLogBackgroundExtension.detener();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyHasLoggedIn);
      await prefs.remove(_keyCurrentUser);
      await prefs.remove(_keyCurrentUserRole);
      await prefs.remove(_keyLastLoginDate);
      await prefs.remove(_keyLastSyncedVendedor);
      await prefs.remove(_keyLastSyncedVendedorName);
      await prefs.remove('last_sync_date');
    } catch (e) {}
  }

  Future<bool> hasUserLoggedInBefore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyHasLoggedIn) ?? false;
  }

  Future<void> _saveLoginSuccess(UsuarioAuth usuario) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasLoggedIn, true);
    await prefs.setString(_keyCurrentUser, usuario.username);
    await prefs.setString(_keyCurrentUserRole, usuario.rol);
    await prefs.setString(_keyLastLoginDate, DateTime.now().toIso8601String());
  }

  Future<Usuario?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString(_keyCurrentUser);
      if (username == null) return null;

      final usuarios = await _dbHelper.obtenerUsuarios();
      return usuarios
          .where((u) => u.username.toLowerCase() == username.toLowerCase())
          .firstOrNull;
    } catch (e) {
      return null;
    }
  }

  Future<UsuarioAuth?> getCurrentUserAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString(_keyCurrentUser);
    if (username != null) {
      return UsuarioAuth(id: null, username: username, fullname: '');
    }
    return null;
  }

  Future<DateTime?> getLastLoginDate() async {
    final prefs = await SharedPreferences.getInstance();
    final dateString = prefs.getString(_keyLastLoginDate);
    return dateString != null ? DateTime.parse(dateString) : null;
  }

  Future<bool> hasActiveSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCurrentUser) != null;
  }

  Future<Map<String, dynamic>> getSessionInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceLogState = await DeviceLogBackgroundExtension.obtenerEstado();

      return {
        'hasLoggedInBefore': prefs.getBool(_keyHasLoggedIn) ?? false,
        'currentUser': prefs.getString(_keyCurrentUser),
        'lastSyncedVendedor': prefs.getString(_keyLastSyncedVendedor),
        'lastSyncedVendedorName': prefs.getString(_keyLastSyncedVendedorName),
        'deviceLogActivo': deviceLogState['activo'],
        'deviceLogInicializado': deviceLogState['inicializado'],
      };
    } catch (e) {
      return {};
    }
  }
}

class AuthResult {
  final bool exitoso;
  final String mensaje;
  final UsuarioAuth? usuario;

  AuthResult({required this.exitoso, required this.mensaje, this.usuario});
}

class UsuarioAuth {
  final int? id;
  final String username;
  final String fullname;

  UsuarioAuth({this.id, required this.username, required this.fullname});

  UsuarioAuth.fromUsuario(Usuario usuario)
    : id = usuario.id,
      username = usuario.username,
      fullname = usuario.fullname;

  String get rol =>
      (username == 'admin' || username == 'useradmin') ? 'admin' : 'user';
  bool get esAdmin => rol == 'admin';

  @override
  String toString() => 'UsuarioAuth(username: $username)';
}
