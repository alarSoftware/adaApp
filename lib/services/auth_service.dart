import 'dart:convert';
import 'package:ada_app/services/sync/operacion_comercial_sync_service.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:http/http.dart' as http;
import 'package:ada_app/services/database_helper.dart';
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/services/sync/dynamic_form_sync_service.dart';
import 'package:ada_app/services/censo/censo_upload_service.dart';
import 'package:ada_app/services/error_log/error_log_service.dart';
import 'package:ada_app/services/app_services.dart';
import 'package:ada_app/services/device_log/device_log_background_extension.dart';
import 'package:ada_app/models/usuario.dart';

var logger = Logger();

// ✅ CLASE ACTUALIZADA: Incluye nombres para mostrar en la UI
class SyncValidationResult {
  final bool requiereSincronizacion;
  final String razon;
  final String? vendedorAnteriorId;
  final String vendedorActualId;
  final String? vendedorAnteriorNombre; // Nuevo
  final String vendedorActualNombre;    // Nuevo

  SyncValidationResult({
    required this.requiereSincronizacion,
    required this.razon,
    required this.vendedorAnteriorId,
    required this.vendedorActualId,
    this.vendedorAnteriorNombre,
    required this.vendedorActualNombre,
  });

  @override
  String toString() => 'SyncValidationResult(requiere: $requiereSincronizacion, anterior: $vendedorAnteriorNombre, actual: $vendedorActualNombre)';
}

class AuthService {
  // Keys para SharedPreferences
  static const String _keyHasLoggedIn = 'has_logged_in_before';
  static const String _keyCurrentUser = 'current_user';
  static const String _keyCurrentUserRole = 'current_user_role';
  static const String _keyLastLoginDate = 'last_login_date';
  static const String _keyLastSyncedVendedor = 'last_synced_vendedor_id';
  static const String _keyLastSyncedVendedorName = 'last_synced_vendedor_name'; // ✅ Nueva Key

  // Singleton
  static AuthService? _instance;
  AuthService._internal();
  factory AuthService() => _instance ??= AuthService._internal();

  static final _dbHelper = DatabaseHelper();

  // ==============================================================
  // 🆕 VALIDACIÓN DE SINCRONIZACIÓN (CON NOMBRES)
  // ==============================================================

  Future<SyncValidationResult> validateSyncRequirement(String currentEdfVendedorId, String currentEdfVendedorNombre) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncedVendedorId = prefs.getString(_keyLastSyncedVendedor);

      // Intentamos recuperar el nombre anterior, si no existe, usamos el ID o un texto por defecto
      final lastSyncedVendedorName = prefs.getString(_keyLastSyncedVendedorName) ?? lastSyncedVendedorId ?? 'Anterior';

      logger.i('Validando sync: Actual: $currentEdfVendedorNombre ($currentEdfVendedorId) vs Anterior: $lastSyncedVendedorName ($lastSyncedVendedorId)');

      // 1. Primera vez (no hay vendedor previo)
      if (lastSyncedVendedorId == null) {
        logger.i('Primera sincronización - se requiere sincronizar');
        return SyncValidationResult(
          requiereSincronizacion: true,
          razon: 'Primera sincronización requerida',
          vendedorAnteriorId: null,
          vendedorActualId: currentEdfVendedorId,
          vendedorAnteriorNombre: null,
          vendedorActualNombre: currentEdfVendedorNombre,
        );
      }

      // 2. Si el vendedor es diferente al último sincronizado
      if (lastSyncedVendedorId != currentEdfVendedorId) {
        logger.w('Vendedor diferente detectado ($lastSyncedVendedorName -> $currentEdfVendedorNombre)');
        return SyncValidationResult(
          requiereSincronizacion: true,
          razon: 'Cambio de vendedor detectado',
          vendedorAnteriorId: lastSyncedVendedorId,
          vendedorActualId: currentEdfVendedorId,
          vendedorAnteriorNombre: lastSyncedVendedorName,
          vendedorActualNombre: currentEdfVendedorNombre,
        );
      }

      // 3. Mismo vendedor, no requiere forzar
      logger.i('Mismo vendedor - no requiere sincronización forzada');
      return SyncValidationResult(
        requiereSincronizacion: false,
        razon: 'Mismo vendedor que la sincronización anterior',
        vendedorAnteriorId: lastSyncedVendedorId,
        vendedorActualId: currentEdfVendedorId,
        vendedorAnteriorNombre: lastSyncedVendedorName,
        vendedorActualNombre: currentEdfVendedorNombre,
      );

    } catch (e) {
      logger.e('Error validando requerimiento de sincronización: $e');
      return SyncValidationResult(
        requiereSincronizacion: true,
        razon: 'Error en validación - sincronización por seguridad',
        vendedorAnteriorId: null,
        vendedorActualId: currentEdfVendedorId,
        vendedorAnteriorNombre: null,
        vendedorActualNombre: currentEdfVendedorNombre,
      );
    }
  }

  // ✅ MÉTODO ACTUALIZADO: Guarda ID y NOMBRE al completar sync
  Future<void> markSyncCompleted(String edfVendedorId, String edfVendedorNombre) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLastSyncedVendedor, edfVendedorId);
      await prefs.setString(_keyLastSyncedVendedorName, edfVendedorNombre); // Guardamos nombre
      await prefs.setString('last_sync_date', DateTime.now().toIso8601String());

      logger.i('Sincronización marcada como completada para: $edfVendedorNombre ($edfVendedorId)');

      // INICIALIZAR DEVICE LOGGING DESPUÉS DE SYNC EXITOSA
      try {
        logger.i('🚀 Sincronización completada - Iniciando Device Log Background Extension...');
        await DeviceLogBackgroundExtension.inicializarDespuesDeLogin();
        logger.i('✅ Device Log Background Extension iniciado correctamente');
      } catch (e) {
        logger.e('💥 Error iniciando Device Log Background Extension: $e');
      }

    } catch (e) {
      logger.e('Error marcando sincronización completada: $e');
    }
  }

  Future<void> clearSyncData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyLastSyncedVendedor);
      await prefs.remove(_keyLastSyncedVendedorName); // Limpiamos nombre también
      await prefs.remove('last_sync_date');

      await _dbHelper.eliminar('clientes');

      logger.i('Datos de sincronización limpiados');
    } catch (e) {
      logger.e('Error limpiando datos de sincronización: $e');
    }
  }

  // ==============================================================
  // 🔄 MÉTODOS DE SINCRONIZACIÓN
  // ==============================================================

  static Future<SyncResult> sincronizarSoloUsuarios() async {
    try {
      logger.i('Sincronizando solo usuarios...');

      final baseUrl = await BaseSyncService.getBaseUrl();

      final response = await http.get(
        Uri.parse('$baseUrl/api/getUsers'),
        headers: BaseSyncService.headers,
      ).timeout(BaseSyncService.timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = jsonDecode(response.body);
        // logger.i('Response data: $responseData');

        final String dataString = responseData['data'];
        final List<dynamic> usuariosAPI = jsonDecode(dataString);

        if (usuariosAPI.isEmpty) {
          logger.w('No hay usuarios en el servidor');
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

          // ✅ MAPEO CORREGIDO: Incluye edfVendedorNombre
          final usuarioProcesado = {
            'id': usuario['id'],
            'edf_vendedor_id': usuario['edfVendedorId']?.toString(),
            'edfVendedorNombre': usuario['edfVendedorNombre']?.toString(), // 👈 IMPORTANTE
            'code': usuario['id'],
            'username': usuario['username'],
            'password': password,
            'fullname': usuario['fullname'],
            'fecha_creacion': DateTime.now().toIso8601String(),
            'fecha_actualizacion': DateTime.now().toIso8601String(),
          };

          return usuarioProcesado;
        }).toList();

        logger.i('Enviando ${usuariosProcesados.length} usuarios a DB Local');
        await _dbHelper.sincronizarUsuarios(usuariosProcesados);

        return SyncResult(
          exito: true,
          mensaje: 'Usuarios sincronizados correctamente',
          itemsSincronizados: usuariosProcesados.length,
          totalEnAPI: usuariosProcesados.length,
        );

      } else {
        final mensaje = BaseSyncService.extractErrorMessage(response);
        return SyncResult(exito: false, mensaje: mensaje, itemsSincronizados: 0);
      }
    } catch (e) {
      logger.e('Error sincronizando usuarios: $e');
      await ErrorLogService.logError(tableName: 'Users', operation: 'sync_from_server', errorMessage: 'Error sincronizando usuarios: $e', errorType: 'unknown');
      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

  static Future<SyncResult> sincronizarClientesDelVendedor(String edfVendedorId) async {
    try {
      logger.i('Sincronizando clientes del vendedor: $edfVendedorId');

      final baseUrl = await BaseSyncService.getBaseUrl();
      final url = '$baseUrl/api/getEdfClientes?edfvendedorId=$edfVendedorId';

      final response = await http.get(
        Uri.parse(url),
        headers: BaseSyncService.headers,
      ).timeout(BaseSyncService.timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<dynamic> clientesAPI = BaseSyncService.parseResponse(response.body);

        if (clientesAPI.isEmpty) {
          return SyncResult(
            exito: true,
            mensaje: 'No hay clientes para este vendedor',
            itemsSincronizados: 0,
          );
        }

        final clientesProcesados = <Map<String, dynamic>>[];

        for (final cliente in clientesAPI) {
          if (cliente['cliente'] == null || cliente['cliente'].toString().trim().isEmpty) {
            continue;
          }

          String rucCi = '';
          if (cliente['ruc'] != null && cliente['ruc'].toString().trim().isNotEmpty) {
            rucCi = cliente['ruc'].toString().trim();
          } else if (cliente['cedula'] != null && cliente['cedula'].toString().trim().isNotEmpty) {
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
          return SyncResult(exito: false, mensaje: 'No se procesaron clientes válidos', itemsSincronizados: 0);
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
        return SyncResult(exito: false, mensaje: mensaje, itemsSincronizados: 0);
      }
    } catch (e) {
      logger.e('Error sincronizando clientes: $e');
      await ErrorLogService.logError(tableName: 'Clientes', operation: 'sync_from_server', errorMessage: 'Error sincronizando clientes: $e', errorType: 'unknown');
      return SyncResult(exito: false, mensaje: BaseSyncService.getErrorMessage(e), itemsSincronizados: 0);
    }
  }

  static Future<SyncResult> sincronizarRespuestasDelVendedor(String edfVendedorId) async {
    try {
      print('🔄 Iniciando sincronización de respuestas para vendedor: $edfVendedorId');
      return await DynamicFormSyncService.obtenerRespuestasPorVendedor(edfVendedorId);
    } catch (e) {
      print('❌ Error sincronizando respuestas: $e');
      return SyncResult(exito: false, mensaje: 'Error: $e', itemsSincronizados: 0);
    }
  }

  // ==============================================================
  // 🔐 AUTENTICACIÓN Y SESIÓN
  // ==============================================================

  Future<AuthResult> login(String username, String password) async {
    logger.i('Intentando login para: $username');

    try {
      final usuarios = await _dbHelper.obtenerUsuarios();
      final usuarioEncontrado = usuarios.where(
            (u) => u.username.toLowerCase() == username.toLowerCase(),
      ).firstOrNull;

      if (usuarioEncontrado == null) {
        return AuthResult(exitoso: false, mensaje: 'Usuario no encontrado');
      }

      final passwordValido = BCrypt.checkpw(password, usuarioEncontrado.password);
      if (!passwordValido) {
        return AuthResult(exitoso: false, mensaje: 'Credenciales incorrectas');
      }

      final usuarioAuth = UsuarioAuth.fromUsuario(usuarioEncontrado);
      await _saveLoginSuccess(usuarioAuth);

      // Inicializar servicios básicos (NO Device Log todavía)
      try {
        await AppServices().inicializarEnLogin();
      } catch (e) {
        logger.e('Error iniciando servicios básicos: $e');
      }

      // Sincronización automática de censos
      // if (usuarioEncontrado.id != null) {
      //   CensoUploadService.iniciarSincronizacionAutomatica(usuarioEncontrado.id!);
      //   OperacionComercialSyncService.iniciarSincronizacionAutomatica(usuarioEncontrado.id!);
      // }

      return AuthResult(
        exitoso: true,
        mensaje: 'Bienvenido, ${usuarioEncontrado.fullname}',
        usuario: usuarioAuth,
      );

    } catch (e) {
      logger.e('Error en login: $e');
      return AuthResult(exitoso: false, mensaje: 'Error en el inicio de sesión');
    }
  }

  Future<AuthResult> authenticateWithBiometric() async {
    logger.i('Intentando autenticación biométrica');

    try {
      final currentUser = await getCurrentUser();
      if (currentUser == null) {
        return AuthResult(exitoso: false, mensaje: 'Debes iniciar sesión con credenciales primero');
      }

      final usuarioAuth = UsuarioAuth.fromUsuario(currentUser);

      // Validar sincronización para decidir si iniciar Device Log
      if (currentUser.edfVendedorId != null) {
        // ✅ PASAMOS EL NOMBRE A LA VALIDACIÓN
        final nombreVendedor = currentUser.edfVendedorNombre ?? currentUser.username;

        final syncValidation = await validateSyncRequirement(
            currentUser.edfVendedorId!,
            nombreVendedor // Nuevo argumento
        );

        if (!syncValidation.requiereSincronizacion) {
          // Ya está sincronizado OK, iniciamos Log
          try {
            logger.i('🔍 Sync previa OK - Iniciando device logging...');
            await DeviceLogBackgroundExtension.inicializarDespuesDeLogin();
          } catch (e) {
            logger.e('Error iniciando Device Log: $e');
          }
        } else {
          logger.i('📝 Requiere sincronización - Device logging pendiente hasta finalizar sync');
        }
      }

      // if (currentUser.id != null) {
      //   CensoUploadService.iniciarSincronizacionAutomatica(currentUser.id!);
      //   OperacionComercialSyncService.iniciarSincronizacionAutomatica(currentUser.id!);
      // }

      return AuthResult(
        exitoso: true,
        mensaje: 'Bienvenido de nuevo, ${currentUser.fullname}',
        usuario: usuarioAuth,
      );

    } catch (e) {
      logger.e('Error en autenticación biométrica: $e');
      return AuthResult(exitoso: false, mensaje: 'Error en autenticación biométrica');
    }
  }

  Future<void> logout() async {
    try {
      logger.i('🚪 Iniciando logout...');

      // DETENER DEVICE LOG
      try {
        await DeviceLogBackgroundExtension.detener();
      } catch (e) {
        logger.e('Error deteniendo Device Log: $e');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyHasLoggedIn);
      await prefs.remove(_keyCurrentUser);
      await prefs.remove(_keyCurrentUserRole);

      logger.i('✅ Logout exitoso');
    } catch (e) {
      logger.e('❌ Error en logout: $e');
    }
  }

  Future<void> clearAllData() async {
    try {
      logger.i('🧹 Limpiando todos los datos...');

      // Detener Log antes de limpiar
      await DeviceLogBackgroundExtension.detener();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyHasLoggedIn);
      await prefs.remove(_keyCurrentUser);
      await prefs.remove(_keyCurrentUserRole);
      await prefs.remove(_keyLastLoginDate);
      await prefs.remove(_keyLastSyncedVendedor);
      await prefs.remove(_keyLastSyncedVendedorName); // Limpiar nombre
      await prefs.remove('last_sync_date');

      logger.i('✅ Todos los datos limpiados');
    } catch (e) {
      logger.e('❌ Error limpiando datos: $e');
    }
  }

  // ==============================================================
  // 🛠️ UTILIDADES Y GETTERS
  // ==============================================================

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
      return usuarios.where(
            (u) => u.username.toLowerCase() == username.toLowerCase(),
      ).firstOrNull;
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

  String get rol => (username == 'admin' || username == 'useradmin') ? 'admin' : 'user';
  bool get esAdmin => rol == 'admin';

  @override
  String toString() => 'UsuarioAuth(username: $username)';
}