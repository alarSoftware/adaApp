import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:http/http.dart' as http;
import 'package:ada_app/services/database_helper.dart';
import 'package:ada_app/services/sync/base_sync_service.dart';
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

  // Método para sincronizar usuarios desde la nueva API
  static Future<SyncResult> sincronizarSoloUsuarios() async {
    try {
      logger.i('Sincronizando solo usuarios...');

      final response = await http.get(
        Uri.parse('${BaseSyncService.baseUrl}/getUsers'),
        headers: BaseSyncService.headers,
      ).timeout(BaseSyncService.timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = jsonDecode(response.body);

        logger.i('=== RESPUESTA DE API ===');
        logger.i('Response data: $responseData');

        // Extraer el array de usuarios del campo "data"
        final String dataString = responseData['data'];
        final List<dynamic> usuariosAPI = jsonDecode(dataString);

        logger.i('=== USUARIOS DE API ===');
        for (int i = 0; i < usuariosAPI.length; i++) {
          logger.i('Usuario API ${i + 1}: ${usuariosAPI[i]}');

          final usuario = usuariosAPI[i];
          logger.i('=== DEBUG CAMPOS USUARIO ${i + 1} ===');
          logger.i('Todos los campos disponibles: ${usuario.keys.toList()}');
          logger.i('edf_vendedor_id específico: ${usuario['edf_vendedor_id']}');
          logger.i('¿Existe el campo?: ${usuario.containsKey('edf_vendedor_id')}');
        }

        if (usuariosAPI.isEmpty) {
          logger.w('No hay usuarios en el servidor');
          return SyncResult(
            exito: true,
            mensaje: 'No hay usuarios en el servidor',
            itemsSincronizados: 0,
          );
        }

        // PROCESAMIENTO CORREGIDO - mapear correctamente el ID a code
        final usuariosProcesados = usuariosAPI.map((usuario) {
          String password = usuario['password'].toString();
          if (password.startsWith('{bcrypt}')) {
            password = password.substring(8);
          }

          final now = DateTime.now().toIso8601String();

          final usuarioProcesado = {
            'edf_vendedor_id': usuario['edfVendedorId']?.toString(),
            'code': usuario['id'], // CRÍTICO: Mapear ID de API a code
            'username': usuario['username'],
            'password': password,
            'fullname': usuario['fullname'],
            'sincronizado': 1,
            'fecha_creacion': usuario['fecha_creacion'] ?? now,
            'fecha_actualizacion': usuario['fecha_actualizacion'] ?? now,
          };

          logger.i('Usuario procesado: $usuarioProcesado');
          return usuarioProcesado;
        }).toList();

        logger.i('=== ENVIANDO A DATABASE_HELPER ===');
        logger.i('Total usuarios procesados: ${usuariosProcesados.length}');

        await _dbHelper.sincronizarUsuarios(usuariosProcesados);

        logger.i('Sincronización de usuarios completada');
        return SyncResult(
          exito: true,
          mensaje: 'Usuarios sincronizados correctamente',
          itemsSincronizados: usuariosProcesados.length,
          totalEnAPI: usuariosProcesados.length,
        );

      } else {
        final mensaje = BaseSyncService.extractErrorMessage(response);
        logger.e('Error del servidor: ${response.statusCode} - ${response.body}');
        return SyncResult(
          exito: false,
          mensaje: mensaje,
          itemsSincronizados: 0,
        );
      }
    } catch (e) {
      logger.e('Error sincronizando usuarios: $e');
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

      // Debug de la URL
      final url = '${BaseSyncService.baseUrl}/getEdfClientes?edfvendedorId=$edfVendedorId';
      logger.i('URL completa: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: BaseSyncService.headers,
      ).timeout(BaseSyncService.timeout);

      // Debug de la respuesta
      logger.i('Status code: ${response.statusCode}');
      logger.i('Response body completo: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<dynamic> clientesAPI = BaseSyncService.parseResponse(response.body);

        logger.i('=== CLIENTES DE API PARA VENDEDOR $edfVendedorId ===');
        logger.i('Total clientes recibidos: ${clientesAPI.length}');

        for (int i = 0; i < clientesAPI.length; i++) {
          logger.i('Cliente API ${i + 1}: ${clientesAPI[i]}');
        }

        if (clientesAPI.isEmpty) {
          logger.w('No hay clientes para el vendedor $edfVendedorId');
          return SyncResult(
            exito: true,
            mensaje: 'No hay clientes para este vendedor',
            itemsSincronizados: 0,
          );
        }

        // Procesar clientes
        final clientesProcesados = <Map<String, dynamic>>[];

        for (int i = 0; i < clientesAPI.length; i++) {
          final cliente = clientesAPI[i];

          logger.i('=== PROCESANDO CLIENTE ${i + 1} ===');
          logger.i('Cliente completo: $cliente');
          logger.i('Campos disponibles: ${cliente.keys.toList()}');

          // Validar campos críticos
          if (cliente['cliente'] == null || cliente['cliente'].toString().trim().isEmpty) {
            logger.e('Cliente ${i + 1} tiene nombre null o vacío - SALTANDO');
            continue;
          }

          // Determinar RUC/CI
          String rucCi = '';
          if (cliente['ruc'] != null && cliente['ruc'].toString().trim().isNotEmpty) {
            rucCi = cliente['ruc'].toString().trim();
            logger.i('RUC obtenido: $rucCi');
          } else if (cliente['cedula'] != null && cliente['cedula'].toString().trim().isNotEmpty) {
            rucCi = cliente['cedula'].toString().trim();
            logger.i('Cedula obtenida: $rucCi');
          } else {
            logger.w('Cliente sin RUC ni cedula');
          }

          final clienteProcesado = {
            'id': cliente['id'],
            'nombre': cliente['cliente'].toString().trim(),
            'telefono': cliente['telefono']?.toString().trim() ?? '',
            'direccion': cliente['direccion']?.toString().trim() ?? '',
            'ruc_ci': rucCi,
            'propietario': cliente['propietario']?.toString().trim() ?? '',
          };

          clientesProcesados.add(clienteProcesado);
          logger.i('Cliente ${i + 1} procesado: $clienteProcesado');
        }

        if (clientesProcesados.isEmpty) {
          logger.e('No se pudieron procesar clientes válidos');
          return SyncResult(
            exito: false,
            mensaje: 'No se pudieron procesar clientes válidos del servidor',
            itemsSincronizados: 0,
          );
        }

        logger.i('=== ENVIANDO ${clientesProcesados.length} CLIENTES A DATABASE_HELPER ===');

        await _dbHelper.sincronizarClientes(clientesProcesados);

        logger.i('Sincronización de clientes completada');
        return SyncResult(
          exito: true,
          mensaje: 'Clientes sincronizados correctamente',
          itemsSincronizados: clientesProcesados.length,
          totalEnAPI: clientesProcesados.length,
        );

      } else {
        final mensaje = BaseSyncService.extractErrorMessage(response);
        logger.e('Error del servidor: ${response.statusCode} - ${response.body}');
        return SyncResult(
          exito: false,
          mensaje: mensaje,
          itemsSincronizados: 0,
        );
      }
    } catch (e) {
      logger.e('Error sincronizando clientes: $e');
      return SyncResult(
        exito: false,
        mensaje: BaseSyncService.getErrorMessage(e),
        itemsSincronizados: 0,
      );
    }
  }

  // Login híbrido (online/offline) actualizado
  Future<AuthResult> login(String username, String password) async {
    logger.i('Intentando login para: $username');

    // 1. Intentar login online primero
    final loginOnline = await _intentarLoginOnline(username, password);
    if (loginOnline.exitoso) {
      await _saveLoginSuccess(loginOnline.usuario!);
      return loginOnline;
    }

    // 2. Si falla online, intentar offline con datos sincronizados
    final loginOffline = await _loginOffline(username, password);
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

  // Intentar login online actualizado
  Future<AuthResult> _intentarLoginOnline(String username, String password) async {
    try {
      logger.i('Intentando login online...');

      final response = await http.post(
        Uri.parse('${BaseSyncService.baseUrl}/login'),
        headers: BaseSyncService.headers,
        body: jsonEncode({'username': username, 'password': password}),
      ).timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final usuarioData = data['usuario'];
          final usuario = UsuarioAuth(
            id: usuarioData['id'],
            username: usuarioData['username'],
            fullname: usuarioData['fullname'],
          );

          logger.i('Login online exitoso para: $username');
          return AuthResult(
            exitoso: true,
            mensaje: 'Bienvenido, ${usuarioData['fullname']}',
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
      logger.w('Error en login online: $e');
    }

    return AuthResult(exitoso: false, mensaje: 'Sin conexión');
  }

  // Login offline actualizado para nuevos campos
  Future<AuthResult> _loginOffline(String username, String password) async {
    try {
      logger.i('Intentando login offline...');

      final usuarios = await _dbHelper.obtenerUsuarios();

      // Buscar usuarios que coincidan
      final usuariosEncontrados = usuarios.where(
            (u) => u.username.toLowerCase() == username.toLowerCase(),
      );

      if (usuariosEncontrados.isEmpty) {
        logger.w('Usuario no encontrado offline: $username');
        return AuthResult(
          exitoso: false,
          mensaje: 'Usuario no encontrado',
        );
      }

      final usuario = usuariosEncontrados.first;

      bool passwordValido = false;

      // Validar según el tipo de password
      if (usuario.password.isNotEmpty) {
        // Hash bcrypt
        final hash = usuario.password;
        passwordValido = BCrypt.checkpw(password, hash);
        logger.i('Validando con bcrypt para: $username');
      } else {
        // Password en texto plano (temporal)
        passwordValido = usuario.password == password;
        logger.i('Validando texto plano para: $username');
      }

      if (passwordValido) {
        final usuarioAuth = UsuarioAuth(
          id: usuario.id,
          username: usuario.username,
          fullname: usuario.fullname,
        );

        logger.i('Login exitoso para: $username');
        return AuthResult(
          exitoso: true,
          mensaje: 'Bienvenido, ${usuario.fullname}',
          usuario: usuarioAuth,
          esOnline: false,
        );
      } else {
        logger.w('Contraseña incorrecta offline para: $username');
        return AuthResult(
          exitoso: false,
          mensaje: 'Contraseña incorrecta',
        );
      }
    } catch (e) {
      logger.e('Error en login offline: $e');
      return AuthResult(
        exitoso: false,
        mensaje: 'Error en login offline: $e',
      );
    }
  }

  // Verificar si el usuario ya se logueó antes
  Future<bool> hasUserLoggedInBefore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasLoggedIn = prefs.getBool(_keyHasLoggedIn) ?? false;

      logger.i('¿Usuario logueado antes?: $hasLoggedIn');
      return hasLoggedIn;
    } catch (e) {
      logger.e('Error verificando login previo: $e');
      return false;
    }
  }

  // Guardar estado de login exitoso
  Future<void> _saveLoginSuccess(UsuarioAuth usuario) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool(_keyHasLoggedIn, true);
      await prefs.setString(_keyCurrentUser, usuario.username);
      await prefs.setString(_keyCurrentUserRole, usuario.rol);
      await prefs.setString(_keyLastLoginDate, DateTime.now().toIso8601String());

      logger.i('Sesión guardada para: ${usuario.username}');
    } catch (e) {
      logger.e('Error guardando sesión: $e');
    }
  }

  // Obtener usuario actual (si existe sesión)
  Future<Usuario?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString(_keyCurrentUser);

      if (username == null) {
        logger.i('No hay usuario actual en SharedPreferences');
        return null;
      }

      logger.i('Buscando usuario completo para: $username');

      // Buscar el usuario completo en la base de datos local
      final usuarios = await _dbHelper.obtenerUsuarios();

      final usuarioEncontrado = usuarios.where(
            (u) => u.username.toLowerCase() == username.toLowerCase(),
      ).firstOrNull;

      if (usuarioEncontrado != null) {
        logger.i('Usuario completo encontrado: ${usuarioEncontrado.username} - edf_vendedor_id: ${usuarioEncontrado.edfVendedorId}');
        return usuarioEncontrado;
      } else {
        logger.w('Usuario $username no encontrado en base de datos local');
        return null;
      }

    } catch (e) {
      logger.e('Error obteniendo usuario completo: $e');
      return null;
    }
  }

  Future<UsuarioAuth?> getCurrentUserAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString(_keyCurrentUser);
      final role = prefs.getString(_keyCurrentUserRole);

      if (username != null && role != null) {
        logger.i('Usuario actual: $username ($role)');
        return UsuarioAuth(id: null, username: username, fullname: '');
      }

      logger.i('No hay usuario logueado');
      return null;
    } catch (e) {
      logger.e('Error obteniendo usuario actual: $e');
      return null;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Solo remover datos de sesión actual, mantener historial de login
      await prefs.remove(_keyCurrentUser);
      await prefs.remove(_keyCurrentUserRole);

      logger.i('Logout exitoso');
    } catch (e) {
      logger.e('Error en logout: $e');
    }
  }

  // Autenticación biométrica CORREGIDA
  Future<AuthResult> authenticateWithBiometric() async {
    logger.i('Intentando autenticación biométrica');

    try {
      // Verificar si hay un usuario previamente autenticado
      final currentUser = await getCurrentUser();
      logger.i('Usuario actual encontrado: $currentUser');

      if (currentUser == null) {
        logger.w('No hay usuario previamente autenticado para biometría');
        return AuthResult(
          exitoso: false,
          mensaje: 'Debes iniciar sesión con credenciales primero',
        );
      }

      // CORRECCIÓN: Convertir Usuario a UsuarioAuth usando constructor de conversión
      final usuarioAuth = UsuarioAuth.fromUsuario(currentUser);

      // Si hay usuario guardado, la biometría es válida
      logger.i('Autenticación biométrica exitosa para: ${currentUser.username}');
      return AuthResult(
        exitoso: true,
        mensaje: 'Bienvenido de nuevo, ${currentUser.fullname}',
        usuario: usuarioAuth,
      );

    } catch (e) {
      logger.e('Error en autenticación biométrica: $e');
      return AuthResult(
        exitoso: false,
        mensaje: 'Error en autenticación biométrica',
      );
    }
  }

  // Método de conversión auxiliar
  UsuarioAuth _convertirAUsuarioAuth(Usuario usuario) {
    return UsuarioAuth(
      id: usuario.id,
      username: usuario.username,
      fullname: usuario.fullname,
    );
  }

  // Limpiar completamente (para testing o reset)
  Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.remove(_keyHasLoggedIn);
      await prefs.remove(_keyCurrentUser);
      await prefs.remove(_keyCurrentUserRole);
      await prefs.remove(_keyLastLoginDate);

      logger.i('Todos los datos limpiados');
    } catch (e) {
      logger.e('Error limpiando datos: $e');
    }
  }

  // Obtener fecha del último login
  Future<DateTime?> getLastLoginDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dateString = prefs.getString(_keyLastLoginDate);

      if (dateString != null) {
        return DateTime.parse(dateString);
      }

      return null;
    } catch (e) {
      logger.e('Error obteniendo fecha de último login: $e');
      return null;
    }
  }

  // Verificar si hay sesión activa
  Future<bool> hasActiveSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString(_keyCurrentUser);

      final hasSession = username != null;
      logger.i('¿Sesión activa?: $hasSession');

      return hasSession;
    } catch (e) {
      logger.e('Error verificando sesión activa: $e');
      return false;
    }
  }

  // Obtener información de sesión (para debug)
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
      logger.e('Error obteniendo info de sesión: $e');
      return {};
    }
  }
}

// Resultado del login
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

// Usuario para autenticación CORREGIDO
class UsuarioAuth {
  final int? id;
  final String username;
  final String fullname;

  UsuarioAuth({
    this.id,
    required this.username,
    required this.fullname,
  });

  // Constructor de conversión desde Usuario
  UsuarioAuth.fromUsuario(Usuario usuario)
      : id = usuario.id,
        username = usuario.username,
        fullname = usuario.fullname;

  // Getter para mantener compatibilidad si necesitas determinar rol
  String get rol {
    if (username == 'admin' || username == 'useradmin') {
      return 'admin';
    }
    return 'user';
  }

  // Getters de conveniencia
  bool get esAdmin => username == 'admin' || username == 'useradmin';

  @override
  String toString() => 'UsuarioAuth(id: $id, username: $username, fullname: $fullname)';
}