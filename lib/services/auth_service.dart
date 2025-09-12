import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:http/http.dart' as http;
import 'package:ada_app/services/database_helper.dart';
import 'package:ada_app/services/sync_service.dart';
import 'package:ada_app/models/usuario.dart';

var logger = Logger();

class AuthService {

  // Keys para SharedPreferences
  static const String _keyHasLoggedIn = 'has_logged_in_before';
  static const String _keyCurrentUser = 'current_user';
  static const String _keyCurrentUserRole = 'current_user_role';
  static const String _keyLastLoginDate = 'last_login_date';

  // Singleton
  static AuthService? _instance;
  AuthService._internal();
  factory AuthService() => _instance ??= AuthService._internal();

  static final _dbHelper = DatabaseHelper();

  // Agregar este método en AuthService
  static Future<SyncResult> sincronizarSoloUsuarios() async {
    try {
      logger.i('🔄 Sincronizando solo usuarios...');

      final response = await http.get(
        Uri.parse('${SyncService.baseUrl}/usuarios'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> usuariosAPI = jsonDecode(response.body);

        // Procesar hashes bcrypt si es necesario
        final usuariosProcesados = usuariosAPI.map((usuario) {
          String password = usuario['password'].toString();

          if (password.startsWith('{bcrypt}')) {
            password = password.substring(8);
          }

          return {
            'id': usuario['id'],
            'nombre': usuario['nombre'],
            'password': password,
            'rol': usuario['rol'],
          };
        }).toList();

        await _dbHelper.sincronizarUsuarios(usuariosProcesados);

        return SyncResult(
          exito: true,
          mensaje: 'Usuarios sincronizados',
          itemsSincronizados: usuariosAPI.length,
        );
      } else {
        return SyncResult(
          exito: false,
          mensaje: 'Error del servidor: ${response.statusCode}',
          itemsSincronizados: 0,
        );
      }
    } catch (e) {
      return SyncResult(
        exito: false,
        mensaje: 'Error de conexión: $e',
        itemsSincronizados: 0,
      );
    }
  }

// 🔑 Login híbrido (online/offline) con soporte bcrypt + credenciales de prueba
  Future<AuthResult> login(String nombre, String password) async {
    logger.i('🔑 Intentando login para: $nombre');

    // 1. Intentar login online primero
    final loginOnline = await _intentarLoginOnline(nombre, password);
    if (loginOnline.exitoso) {
      await _saveLoginSuccess(loginOnline.usuario!);
      return loginOnline;
    }

    // 2. Si falla online, intentar offline con datos sincronizados
    final loginOffline = await _loginOffline(nombre, password);
    if (loginOffline.exitoso) {
      await _saveLoginSuccess(loginOffline.usuario!);
      return loginOffline;
    }

    // 3. Si ambos fallan, determinar el mensaje apropiado
    if (loginOffline.mensaje.contains('Usuario no encontrado')) {
      return AuthResult(
        exitoso: false,
        mensaje: 'Sincroniza los datos primero para usar sin conexión',
      );
    } else if (loginOffline.mensaje.contains('Contraseña incorrecta') ||
        loginOnline.mensaje.contains('Credenciales incorrectas')) {
      return AuthResult(
        exitoso: false,
        mensaje: 'Credenciales incorrectas',
      );
    } else {
      return AuthResult(
        exitoso: false,
        mensaje: 'Sin conexión. Verifica tu internet',
      );
    }
  }


  // 🌐 Intentar login online
  Future<AuthResult> _intentarLoginOnline(String nombre, String password) async {
    try {
      logger.i('🌐 Intentando login online...');

      final response = await http.post(
        Uri.parse('${SyncService.baseUrl}/login'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
        body: jsonEncode({'nombre': nombre, 'password': password}),
      ).timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final usuarioData = data['usuario'];
          final usuario = UsuarioAuth(
            id: usuarioData['id'],
            username: usuarioData['nombre'],
            rol: usuarioData['rol'],
          );

          logger.i('✅ Login online exitoso para: $nombre');
          return AuthResult(
            exitoso: true,
            mensaje: 'Bienvenido, $nombre',
            usuario: usuario,
            esOnline: true,
          );
        }
      } else if (response.statusCode == 401) {
        return AuthResult(
          exitoso: false,
          mensaje: 'Credenciales incorrectas',
        );
      }
    } catch (e) {
      logger.w('🌐 Error en login online: $e');
    }

    return AuthResult(exitoso: false, mensaje: 'Sin conexión');
  }

// 📱 Login offline con datos sincronizados
  Future<AuthResult> _loginOffline(String nombre, String password) async {
    try {
      logger.i('📱 Intentando login offline...');

      final usuarios = await _dbHelper.obtenerUsuarios();

      // Buscar usuarios que coincidan
      final usuariosEncontrados = usuarios.where(
            (u) => u.nombre.toLowerCase() == nombre.toLowerCase(),
      );

      if (usuariosEncontrados.isEmpty) {
        logger.w('❌ Usuario no encontrado offline: $nombre');
        return AuthResult(
          exitoso: false,
          mensaje: 'Usuario no encontrado',
        );
      }

      final usuario = usuariosEncontrados.first;

      bool passwordValido = false;

      // Validar según el tipo de password
      if (usuario.password.startsWith('{bcrypt}')) {
        // Hash bcrypt
        final hash = usuario.password.substring(8);
        passwordValido = BCrypt.checkpw(password, hash);
        logger.i('Validando con bcrypt para: $nombre');
      } else {
        // Password en texto plano (temporal)
        passwordValido = usuario.password == password;
        logger.i('Validando texto plano para: $nombre');
      }

      if (passwordValido) {
        final usuarioAuth = UsuarioAuth(
          id: usuario.id,
          username: usuario.nombre,
          rol: usuario.rol,
        );

        logger.i('Login exitoso para: $nombre');
        return AuthResult(
          exitoso: true,
          mensaje: 'Bienvenido, $nombre',
          usuario: usuarioAuth,
          esOnline: false,
        );
      } else {
        logger.w('Contraseña incorrecta offline para: $nombre');
        return AuthResult(
          exitoso: false,
          mensaje: 'Contraseña incorrecta',
        );
      }
    } catch (e) {
      logger.e('❌ Error en login offline: $e');
      return AuthResult(
        exitoso: false,
        mensaje: 'Error en login offline: $e',
      );
    }
  }

  // 📱 Verificar si el usuario ya se logueó antes
  Future<bool> hasUserLoggedInBefore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasLoggedIn = prefs.getBool(_keyHasLoggedIn) ?? false;

      logger.i('📱 ¿Usuario logueado antes?: $hasLoggedIn');
      return hasLoggedIn;
    } catch (e) {
      logger.e('❌ Error verificando login previo: $e');
      return false;
    }
  }

  // 💾 Guardar estado de login exitoso
  Future<void> _saveLoginSuccess(UsuarioAuth usuario) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool(_keyHasLoggedIn, true);
      await prefs.setString(_keyCurrentUser, usuario.username);
      await prefs.setString(_keyCurrentUserRole, usuario.rol);
      await prefs.setString(_keyLastLoginDate, DateTime.now().toIso8601String());

      logger.i('💾 Sesión guardada para: ${usuario.username}');
    } catch (e) {
      logger.e('❌ Error guardando sesión: $e');
    }
  }

  // 👤 Obtener usuario actual (si existe sesión)
  Future<UsuarioAuth?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString(_keyCurrentUser);
      final role = prefs.getString(_keyCurrentUserRole);

      if (username != null && role != null) {
        logger.i('👤 Usuario actual: $username ($role)');
        return UsuarioAuth(id: null, username: username, rol: role);
      }

      logger.i('👤 No hay usuario logueado');
      return null;
    } catch (e) {
      logger.e('❌ Error obteniendo usuario actual: $e');
      return null;
    }
  }

  // 🔓 Logout
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Solo remover datos de sesión actual, mantener historial de login
      await prefs.remove(_keyCurrentUser);
      await prefs.remove(_keyCurrentUserRole);

      logger.i('🔓 Logout exitoso');
    } catch (e) {
      logger.e('❌ Error en logout: $e');
    }
  }

  // 👆 Autenticación biométrica (verifica usuario guardado)
  Future<AuthResult> authenticateWithBiometric() async {
    logger.i('👆 Intentando autenticación biométrica');

    try {
      // Verificar si hay un usuario previamente autenticado
      final currentUser = await getCurrentUser();
      logger.i('🔍 Usuario actual encontrado: $currentUser');

      if (currentUser == null) {
        logger.w('❌ No hay usuario previamente autenticado para biometría');
        return AuthResult(
          exitoso: false,
          mensaje: 'Debes iniciar sesión con credenciales primero',
        );
      }

      // Si hay usuario guardado, la biometría es válida
      logger.i('✅ Autenticación biométrica exitosa para: ${currentUser.username}');
      return AuthResult(
        exitoso: true,
        mensaje: 'Bienvenido de nuevo, ${currentUser.username}',
        usuario: currentUser,
      );

    } catch (e) {
      logger.e('❌ Error en autenticación biométrica: $e');
      return AuthResult(
        exitoso: false,
        mensaje: 'Error en autenticación biométrica',
      );
    }
  }

  // 🗑️ Limpiar completamente (para testing o reset)
  Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.remove(_keyHasLoggedIn);
      await prefs.remove(_keyCurrentUser);
      await prefs.remove(_keyCurrentUserRole);
      await prefs.remove(_keyLastLoginDate);

      logger.i('🗑️ Todos los datos limpiados');
    } catch (e) {
      logger.e('❌ Error limpiando datos: $e');
    }
  }

  // 📅 Obtener fecha del último login
  Future<DateTime?> getLastLoginDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dateString = prefs.getString(_keyLastLoginDate);

      if (dateString != null) {
        return DateTime.parse(dateString);
      }

      return null;
    } catch (e) {
      logger.e('❌ Error obteniendo fecha de último login: $e');
      return null;
    }
  }

  // 🔍 Verificar si hay sesión activa
  Future<bool> hasActiveSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString(_keyCurrentUser);

      final hasSession = username != null;
      logger.i('🔍 ¿Sesión activa?: $hasSession');

      return hasSession;
    } catch (e) {
      logger.e('❌ Error verificando sesión activa: $e');
      return false;
    }
  }

  // 📊 Obtener información de sesión (para debug)
  Future<Map<String, dynamic>> getSessionInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      return {
        'hasLoggedInBefore': prefs.getBool(_keyHasLoggedIn) ?? false,
        'currentUser': prefs.getString(_keyCurrentUser),
        'currentUserRole': prefs.getString(_keyCurrentUserRole),
        'lastLoginDate': prefs.getString(_keyLastLoginDate),
        'hasActiveSession': prefs.getString(_keyCurrentUser) != null,
      };
    } catch (e) {
      logger.e('❌ Error obteniendo info de sesión: $e');
      return {};
    }
  }
}

// Resultado del login actualizado
class AuthResult {
  final bool exitoso;
  final String mensaje;
  final UsuarioAuth? usuario;
  final bool esOnline;

  AuthResult({
    required this.exitoso,
    required this.mensaje,
    this.usuario,
    this.esOnline = false,
  });
}

// Usuario para autenticación
class UsuarioAuth {
  final int? id;
  final String username;
  final String rol;

  UsuarioAuth({
    this.id,
    required this.username,
    required this.rol,
  });

  @override
  String toString() => 'UsuarioAuth(id: $id, username: $username, rol: $rol)';
}