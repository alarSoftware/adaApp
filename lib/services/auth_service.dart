import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

var logger = Logger();

class AuthService {
  // Credenciales de prueba
  static const Map<String, String> _defaultCredentials = {
    'admin': 'admin123',
    'usuario': 'usuario123',
    'supervisor': 'super456',
  };

  // Keys para SharedPreferences
  static const String _keyHasLoggedIn = 'has_logged_in_before';
  static const String _keyCurrentUser = 'current_user';
  static const String _keyCurrentUserRole = 'current_user_role';
  static const String _keyLastLoginDate = 'last_login_date';

  // Singleton
  static AuthService? _instance;
  AuthService._internal();
  factory AuthService() => _instance ??= AuthService._internal();

  // 🔑 Login básico mejorado
  Future<AuthResult> login(String username, String password) async {
    logger.i('🔑 Intentando login para: $username');

    if (_defaultCredentials.containsKey(username) &&
        _defaultCredentials[username] == password) {

      // Guardar que el usuario ya se logueó antes
      await _saveLoginSuccess(username);

      logger.i('✅ Login exitoso para: $username');
      return AuthResult(
        exitoso: true,
        mensaje: 'Bienvenido, $username',
        usuario: Usuario(username: username, rol: _getRolByUsername(username)),
      );
    } else {
      logger.w('❌ Credenciales incorrectas para: $username');
      return AuthResult(
        exitoso: false,
        mensaje: 'Usuario o contraseña incorrectos',
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
  Future<void> _saveLoginSuccess(String username) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool(_keyHasLoggedIn, true);
      await prefs.setString(_keyCurrentUser, username);
      await prefs.setString(_keyCurrentUserRole, _getRolByUsername(username));
      await prefs.setString(_keyLastLoginDate, DateTime.now().toIso8601String());

      logger.i('💾 Sesión guardada para: $username');
    } catch (e) {
      logger.e('❌ Error guardando sesión: $e');
    }
  }

  // 👤 Obtener usuario actual (si existe sesión)
  Future<Usuario?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString(_keyCurrentUser);
      final role = prefs.getString(_keyCurrentUserRole);

      if (username != null && role != null) {
        logger.i('👤 Usuario actual: $username ($role)');
        return Usuario(username: username, rol: role);
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

  // Obtener rol (método privado existente)
  String _getRolByUsername(String username) {
    switch (username.toLowerCase()) {
      case 'admin':
        return 'Administrador';
      case 'supervisor':
        return 'Supervisor';
      case 'usuario':
      default:
        return 'Usuario';
    }
  }
}

// Resultado del login
class AuthResult {
  final bool exitoso;
  final String mensaje;
  final Usuario? usuario;

  AuthResult({required this.exitoso, required this.mensaje, this.usuario});
}

// Usuario
class Usuario {
  final String username;
  final String rol;

  Usuario({required this.username, required this.rol});

  @override
  String toString() => 'Usuario(username: $username, rol: $rol)';
}