import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:http/http.dart' as http;
import 'package:ada_app/services/database_helper.dart';
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/services/sync/dynamic_form_sync_service.dart';
import 'package:ada_app/models/usuario.dart';

var logger = Logger();

// Clase para el resultado de validación de sincronización
class SyncValidationResult {
  final bool requiereSincronizacion;
  final String razon;
  final String? vendedorAnterior;
  final String vendedorActual;

  SyncValidationResult({
    required this.requiereSincronizacion,
    required this.razon,
    required this.vendedorAnterior,
    required this.vendedorActual,
  });

  @override
  String toString() => 'SyncValidationResult(requiere: $requiereSincronizacion, razon: $razon, anterior: $vendedorAnterior, actual: $vendedorActual)';
}

class AuthService {
  // Keys para SharedPreferences
  static const String _keyHasLoggedIn = 'has_logged_in_before';
  static const String _keyCurrentUser = 'current_user';
  static const String _keyCurrentUserRole = 'current_user_role';
  static const String _keyLastLoginDate = 'last_login_date';
  static const String _keyLastSyncedVendedor = 'last_synced_vendedor_id'; // NUEVA KEY

  // Singleton
  static AuthService? _instance;
  AuthService._internal();
  factory AuthService() => _instance ??= AuthService._internal();

  static final _dbHelper = DatabaseHelper();

  // NUEVOS MÉTODOS PARA VALIDACIÓN DE VENDEDOR

  // Método para verificar si se necesita sincronización forzada
  Future<SyncValidationResult> validateSyncRequirement(String currentEdfVendedorId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncedVendedor = prefs.getString(_keyLastSyncedVendedor);

      logger.i('Validando sincronización: Usuario actual edf_vendedor_id: $currentEdfVendedorId');
      logger.i('Último vendedor sincronizado: $lastSyncedVendedor');

      // Si es la primera vez o no hay vendedor previo
      if (lastSyncedVendedor == null) {
        logger.i('Primera sincronización - se requiere sincronizar');
        return SyncValidationResult(
          requiereSincronizacion: true,
          razon: 'Primera sincronización requerida',
          vendedorAnterior: null,
          vendedorActual: currentEdfVendedorId,
        );
      }

      // Si el vendedor es diferente al último sincronizado
      if (lastSyncedVendedor != currentEdfVendedorId) {
        logger.w('Vendedor diferente detectado - sincronización obligatoria');
        return SyncValidationResult(
          requiereSincronizacion: true,
          razon: 'Cambio de vendedor detectado',
          vendedorAnterior: lastSyncedVendedor,
          vendedorActual: currentEdfVendedorId,
        );
      }

      // Vendedor es el mismo, no requiere sincronización forzada
      logger.i('Mismo vendedor - no requiere sincronización forzada');
      return SyncValidationResult(
        requiereSincronizacion: false,
        razon: 'Mismo vendedor que la sincronización anterior',
        vendedorAnterior: lastSyncedVendedor,
        vendedorActual: currentEdfVendedorId,
      );

    } catch (e) {
      logger.e('Error validando requerimiento de sincronización: $e');
      // En caso de error, mejor requerir sincronización por seguridad
      return SyncValidationResult(
        requiereSincronizacion: true,
        razon: 'Error en validación - sincronización por seguridad',
        vendedorAnterior: null,
        vendedorActual: currentEdfVendedorId,
      );
    }
  }

  // Método para marcar que se completó la sincronización
  Future<void> markSyncCompleted(String edfVendedorId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLastSyncedVendedor, edfVendedorId);
      await prefs.setString('last_sync_date', DateTime.now().toIso8601String());

      logger.i('Sincronización marcada como completada para vendedor: $edfVendedorId');
    } catch (e) {
      logger.e('Error marcando sincronización completada: $e');
    }
  }

  // Método para limpiar datos de sincronización
  Future<void> clearSyncData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyLastSyncedVendedor);
      await prefs.remove('last_sync_date');

      // También limpiar los clientes de la base de datos local
      await _dbHelper.eliminar('clientes');

      logger.i('Datos de sincronización limpiados');
    } catch (e) {
      logger.e('Error limpiando datos de sincronización: $e');
    }
  }

  // Método para sincronizar usuarios desde la nueva API
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

        logger.i('=== RESPUESTA DE API ===');
        logger.i('Response data: $responseData');

        final String dataString = responseData['data'];
        final List<dynamic> usuariosAPI = jsonDecode(dataString);

        logger.i('=== USUARIOS DE API ===');
        logger.i('Total usuarios recibidos: ${usuariosAPI.length}');

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

          // ✅ Mapeo correcto según tu tabla actual
          final usuarioProcesado = {
            'id': usuario['id'],  // ✅ ID del servidor
            'edf_vendedor_id': usuario['edfVendedorId']?.toString(),  // ✅ camelCase de API
            'code': usuario['id'],  // ✅ code = mismo ID
            'username': usuario['username'],
            'password': password,
            'fullname': usuario['fullname'],
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

      final baseUrl = await BaseSyncService.getBaseUrl();
      final url = '$baseUrl/api/getEdfClientes?edfvendedorId=$edfVendedorId';
      logger.i('URL completa: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: BaseSyncService.headers,
      ).timeout(BaseSyncService.timeout);

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

        final clientesProcesados = <Map<String, dynamic>>[];

        for (int i = 0; i < clientesAPI.length; i++) {
          final cliente = clientesAPI[i];

          logger.i('=== PROCESANDO CLIENTE ${i + 1} ===');
          logger.i('Cliente completo: $cliente');
          logger.i('Campos disponibles: ${cliente.keys.toList()}');

          if (cliente['cliente'] == null || cliente['cliente'].toString().trim().isEmpty) {
            logger.e('Cliente ${i + 1} tiene nombre null o vacío - SALTANDO');
            continue;
          }

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

  static Future<SyncResult> sincronizarRespuestasDelVendedor(String edfVendedorId) async {
    try {
      print('🔄 Iniciando sincronización de respuestas para vendedor: $edfVendedorId');
      print('🕐 Timestamp: ${DateTime.now()}');

      final resultado = await DynamicFormSyncService.obtenerRespuestasPorVendedor(edfVendedorId);

      if (resultado.exito) {
        print('✅ Sincronización de respuestas completada: ${resultado.itemsSincronizados} items');
      } else {
        print('❌ Error en sincronización de respuestas: ${resultado.mensaje}');
      }

      return resultado;
    } catch (e) {
      print('❌ Error sincronizando respuestas: $e');
      return SyncResult(
        exito: false,
        mensaje: 'Error al sincronizar respuestas: $e',
        itemsSincronizados: 0,
      );
    }
  }


  // Login simplificado - solo valida contra base de datos local
  Future<AuthResult> login(String username, String password) async {
    logger.i('Intentando login para: $username');

    try {
      final usuarios = await _dbHelper.obtenerUsuarios();

      final usuariosEncontrados = usuarios.where(
            (u) => u.username.toLowerCase() == username.toLowerCase(),
      );

      if (usuariosEncontrados.isEmpty) {
        logger.w('Usuario no encontrado: $username');
        return AuthResult(
          exitoso: false,
          mensaje: 'Usuario no encontrado',
        );
      }

      final usuario = usuariosEncontrados.first;

      // Validar password con bcrypt
      final passwordValido = BCrypt.checkpw(password, usuario.password);

      if (!passwordValido) {
        logger.w('Password incorrecto para: $username');
        return AuthResult(
          exitoso: false,
          mensaje: 'Credenciales incorrectas',
        );
      }

      final usuarioAuth = UsuarioAuth.fromUsuario(usuario);

      await _saveLoginSuccess(usuarioAuth);

      logger.i('Login exitoso para: $username');
      return AuthResult(
        exitoso: true,
        mensaje: 'Bienvenido, ${usuario.fullname}',
        usuario: usuarioAuth,
      );

    } catch (e) {
      logger.e('Error en login: $e');
      return AuthResult(
        exitoso: false,
        mensaje: 'Error en el inicio de sesión',
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

  // Obtener usuario actual completo
  Future<Usuario?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString(_keyCurrentUser);

      if (username == null) {
        logger.i('No hay usuario actual en SharedPreferences');
        return null;
      }

      logger.i('Buscando usuario completo para: $username');

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

      await prefs.remove(_keyCurrentUser);
      await prefs.remove(_keyCurrentUserRole);

      logger.i('Logout exitoso');
    } catch (e) {
      logger.e('Error en logout: $e');
    }
  }

  // Autenticación biométrica
  Future<AuthResult> authenticateWithBiometric() async {
    logger.i('Intentando autenticación biométrica');

    try {
      final currentUser = await getCurrentUser();
      logger.i('Usuario actual encontrado: $currentUser');

      if (currentUser == null) {
        logger.w('No hay usuario previamente autenticado para biometría');
        return AuthResult(
          exitoso: false,
          mensaje: 'Debes iniciar sesión con credenciales primero',
        );
      }

      final usuarioAuth = UsuarioAuth.fromUsuario(currentUser);

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

  // Limpiar completamente (para testing o reset) - MÉTODO ACTUALIZADO
  Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.remove(_keyHasLoggedIn);
      await prefs.remove(_keyCurrentUser);
      await prefs.remove(_keyCurrentUserRole);
      await prefs.remove(_keyLastLoginDate);
      await prefs.remove(_keyLastSyncedVendedor); // NUEVA LÍNEA
      await prefs.remove('last_sync_date'); // NUEVA LÍNEA

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

  // Obtener información de sesión (para debug) - MÉTODO ACTUALIZADO
  Future<Map<String, dynamic>> getSessionInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      return {
        'hasLoggedInBefore': prefs.getBool(_keyHasLoggedIn) ?? false,
        'currentUser': prefs.getString(_keyCurrentUser),
        'currentUserRole': prefs.getString(_keyCurrentUserRole),
        'lastLoginDate': prefs.getString(_keyLastLoginDate),
        'hasActiveSession': prefs.getString(_keyCurrentUser) != null,
        'lastSyncedVendedor': prefs.getString(_keyLastSyncedVendedor), // NUEVA LÍNEA
        'lastSyncDate': prefs.getString('last_sync_date'), // NUEVA LÍNEA
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

  AuthResult({
    required this.exitoso,
    required this.mensaje,
    this.usuario,
  });
}

// Usuario para autenticación
class UsuarioAuth {
  final int? id;
  final String username;
  final String fullname;

  UsuarioAuth({
    this.id,
    required this.username,
    required this.fullname,
  });

  UsuarioAuth.fromUsuario(Usuario usuario)
      : id = usuario.id,
        username = usuario.username,
        fullname = usuario.fullname;

  String get rol {
    if (username == 'admin' || username == 'useradmin') {
      return 'admin';
    }
    return 'user';
  }

  bool get esAdmin => username == 'admin' || username == 'useradmin';

  @override
  String toString() => 'UsuarioAuth(id: $id, username: $username, fullname: $fullname)';
}