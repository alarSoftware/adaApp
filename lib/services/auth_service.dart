import 'package:logger/logger.dart';

var logger = Logger();

class AuthService {
  // Credenciales de prueba
  static const Map<String, String> _defaultCredentials = {
    'admin': 'admin123',
    'usuario': 'usuario123',
    'supervisor': 'super456',
  };

  // Singleton
  static AuthService? _instance;
  AuthService._internal();
  factory AuthService() => _instance ??= AuthService._internal();

  // 🔑 Login básico
  Future<AuthResult> login(String username, String password) async {
    logger.i('🔑 Intentando login para: $username');

    if (_defaultCredentials.containsKey(username) &&
        _defaultCredentials[username] == password) {
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

  // Obtener rol
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
}
