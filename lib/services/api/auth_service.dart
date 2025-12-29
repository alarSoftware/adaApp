import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:http/http.dart' as http;
import 'package:ada_app/services/data/database_helper.dart';
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/services/sync/dynamic_form_sync_service.dart';

import 'package:ada_app/services/error_log/error_log_service.dart';
import 'package:ada_app/services/app_services.dart';
import 'package:ada_app/services/device_log/device_log_background_extension.dart';
import 'package:ada_app/models/usuario.dart';

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

  // ✅ MÉTODO HELPER PARA CONSTRUIR EL NOMBRE DEL VENDEDOR
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
        await DeviceLogBackgroundExtension.inicializarDespuesDeLogin();
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
    try {
      final baseUrl = await BaseSyncService.getBaseUrl();

      final response = await http
          .get(
            Uri.parse('$baseUrl/api/getUsers'),
            headers: BaseSyncService.headers,
          )
          .timeout(BaseSyncService.timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = jsonDecode(response.body);

        final String dataString = responseData['data'];
        final List<dynamic> usuariosAPI = jsonDecode(dataString);

        if (usuariosAPI.isEmpty) {
          return SyncResult(
            exito: true,
            mensaje: 'No hay usuarios en el servidor',
            itemsSincronizados: 0,
          );
        }

        final usuariosProcesados = usuariosAPI.map((usuario) {
          String password = usuario['password'].toString();
          if (password.startsWith('{bcrypt}')) {
            password = password.substring(8);
          }

          final usuarioProcesado = {
            'id': usuario['id'],
            'employee_id': usuario['employeeId']?.toString(),
            'employeeName':
                usuario['employeeName']?.toString() ??
                usuario['edfVendedorNombre']?.toString(),
            'code': usuario['id'],
            'username': usuario['username'],
            'password': password,
            'fullname': usuario['fullname'],
            'fecha_creacion': DateTime.now().toIso8601String(),
            'fecha_actualizacion': DateTime.now().toIso8601String(),
          };

          return usuarioProcesado;
        }).toList();

        await _dbHelper.sincronizarUsuarios(usuariosProcesados);

        return SyncResult(
          exito: true,
          mensaje: 'Usuarios sincronizados correctamente',
          itemsSincronizados: usuariosProcesados.length,
          totalEnAPI: usuariosProcesados.length,
        );
      } else {
        final mensaje = BaseSyncService.extractErrorMessage(response);
        return SyncResult(
          exito: false,
          mensaje: mensaje,
          itemsSincronizados: 0,
        );
      }
    } catch (e) {
      await ErrorLogService.logError(
        tableName: 'Users',
        operation: 'sync_from_server',
        errorMessage: 'Error sincronizando usuarios: $e',
        errorType: 'unknown',
      );
      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

  static Future<SyncResult> sincronizarClientesDelVendedor(
    String employeeId,
  ) async {
    try {
      final baseUrl = await BaseSyncService.getBaseUrl();
      final url = '$baseUrl/api/getEdfClientes?employeeId=$employeeId';

      final response = await http
          .get(Uri.parse(url), headers: BaseSyncService.headers)
          .timeout(BaseSyncService.timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<dynamic> clientesAPI = BaseSyncService.parseResponse(
          response.body,
        );

        if (clientesAPI.isEmpty) {
          return SyncResult(
            exito: true,
            mensaje: 'No hay clientes para este vendedor',
            itemsSincronizados: 0,
          );
        }

        final clientesProcesados = <Map<String, dynamic>>[];

        for (final cliente in clientesAPI) {
          if (cliente['cliente'] == null ||
              cliente['cliente'].toString().trim().isEmpty) {
            continue;
          }

          String rucCi = '';
          if (cliente['ruc'] != null &&
              cliente['ruc'].toString().trim().isNotEmpty) {
            rucCi = cliente['ruc'].toString().trim();
          } else if (cliente['cedula'] != null &&
              cliente['cedula'].toString().trim().isNotEmpty) {
            rucCi = cliente['cedula'].toString().trim();
          }

          clientesProcesados.add({
            'id': cliente['id'],
            'nombre': cliente['cliente'].toString().trim(),
            'telefono': cliente['telefono']?.toString().trim() ?? '',
            'direccion': cliente['direccion']?.toString().trim() ?? '',
            'ruc_ci': rucCi,
            'propietario': cliente['propietario']?.toString().trim() ?? '',
          });
        }

        if (clientesProcesados.isEmpty) {
          return SyncResult(
            exito: false,
            mensaje: 'No se procesaron clientes válidos',
            itemsSincronizados: 0,
          );
        }

        await _dbHelper.sincronizarClientes(clientesProcesados);

        return SyncResult(
          exito: true,
          mensaje: 'Clientes sincronizados correctamente',
          itemsSincronizados: clientesProcesados.length,
          totalEnAPI: clientesProcesados.length,
        );
      } else {
        final mensaje = BaseSyncService.extractErrorMessage(response);
        return SyncResult(
          exito: false,
          mensaje: mensaje,
          itemsSincronizados: 0,
        );
      }
    } catch (e) {
      await ErrorLogService.logError(
        tableName: 'Clientes',
        operation: 'sync_from_server',
        errorMessage: 'Error sincronizando clientes: $e',
        errorType: 'unknown',
      );
      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

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
        // ✅ CORREGIDO: Usar el método helper para construir el nombre
        final nombreVendedor = _buildVendorDisplayName(currentUser);

        final syncValidation = await validateSyncRequirement(
          currentUser.employeeId!,
          nombreVendedor,
        );

        if (!syncValidation.requiereSincronizacion) {
          try {
            await DeviceLogBackgroundExtension.inicializar();
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

  Future<void> logout() async {
    try {
      try {
        await DeviceLogBackgroundExtension.detener();
      } catch (e) {}

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyHasLoggedIn);
      await prefs.remove(_keyCurrentUser);
      await prefs.remove(_keyCurrentUserRole);
    } catch (e) {}
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
