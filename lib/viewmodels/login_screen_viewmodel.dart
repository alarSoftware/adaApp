import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:ada_app/services/auth_service.dart';
import 'package:ada_app/services/sync/base_sync_service.dart';
import 'package:ada_app/services/sync/equipment_sync_service.dart';

class LoginScreenViewModel extends ChangeNotifier {
  final _authService = AuthService();
  final _localAuth = LocalAuthentication();

  // Controllers
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final usernameFocusNode = FocusNode();
  final passwordFocusNode = FocusNode();

  // Estado de la UI
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _biometricAvailable = false;
  bool _usernameValid = false;
  bool _passwordValid = false;
  bool _isSyncingUsers = false;
  String? _errorMessage;
  bool _isSyncingClients = false;

  // Getters
  bool get isLoading => _isLoading;
  bool get obscurePassword => _obscurePassword;
  bool get biometricAvailable => _biometricAvailable;
  bool get usernameValid => _usernameValid;
  bool get passwordValid => _passwordValid;
  bool get isSyncingUsers => _isSyncingUsers;
  String? get errorMessage => _errorMessage;
  bool get isSyncingClientes => _isSyncingClients;

  LoginScreenViewModel() {
    _setupValidationListeners();
    _checkBiometricAvailability();
  }

  void _setupValidationListeners() {
    usernameController.addListener(_validateUsername);
    passwordController.addListener(_validatePassword);
  }

  void _validateUsername() {
    final value = usernameController.text.trim();
    final isValid = value.isNotEmpty && value.length >= 3;

    if (_usernameValid != isValid) {
      _usernameValid = isValid;
      if (_errorMessage != null) {
        _errorMessage = null;
      }
      notifyListeners();
    }
  }

  void _validatePassword() {
    final value = passwordController.text;
    final isValid = value.isNotEmpty && value.length >= 6;

    if (_passwordValid != isValid) {
      _passwordValid = isValid;
      if (_errorMessage != null) {
        _errorMessage = null;
      }
      notifyListeners();
    }
  }

  // Método actualizado para usar AuthService en lugar de SyncService
  Future<SyncResult> syncUsers() async {
    _isSyncingUsers = true;
    notifyListeners();

    try {
      final SyncResult resultado = await AuthService.sincronizarSoloUsuarios();
      return resultado;
    } catch (e) {
      return SyncResult(
        exito: false,
        mensaje: 'Error: $e',
        itemsSincronizados: 0,
      );
    } finally {
      _isSyncingUsers = false;
      notifyListeners();
    }
  }

  Future<SyncResult> syncClientsForVendor(String edfVendedorId) async {
    _isSyncingClients = true;
    notifyListeners();

    try {
      final SyncResult resultado = await AuthService.sincronizarClientesDelVendedor(edfVendedorId);
      return resultado;
    } catch (e) {
      return SyncResult(
        exito: false,
        mensaje: 'Error: $e',
        itemsSincronizados: 0,
      );
    } finally {
      _isSyncingClients = false;
      notifyListeners();
    }
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final bool isAvailable = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      final bool hasLoggedInBefore = await _authService.hasUserLoggedInBefore();

      _biometricAvailable = isAvailable && isDeviceSupported && hasLoggedInBefore;
      notifyListeners();
    } catch (e) {
      debugPrint('Error verificando biométricos: $e');
    }
  }

  void togglePasswordVisibility() {
    _obscurePassword = !_obscurePassword;
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  String? validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El usuario es requerido';
    }
    if (value.length < 3) {
      return 'Usuario debe tener al menos 3 caracteres';
    }
    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'La contraseña es requerida';
    }
    if (value.length < 6) {
      return 'Mínimo 6 caracteres';
    }
    return null;
  }

  Future<AuthResult> authenticateWithBiometric() async {
    try {
      HapticFeedback.lightImpact();

      // 1. Primero verificar biometría del dispositivo
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Autentica tu identidad para acceder a la aplicación',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          sensitiveTransaction: true,
        ),
      );

      if (didAuthenticate) {
        HapticFeedback.lightImpact();

        // 2. Verificar si hay usuario válido en la app
        final result = await _authService.authenticateWithBiometric();

        if (result.exitoso) {
          // NUEVA VALIDACIÓN: Verificar asignación de clientes después de autenticación biométrica
          final validationResult = await _validateUserAssignment();
          if (!validationResult.success) {
            return validationResult;
          }

          return AuthResult(
              success: true,
              message: result.mensaje,
              icon: Icons.fingerprint
          );
        } else {
          return AuthResult(
              success: false,
              message: result.mensaje
          );
        }
      } else {
        return AuthResult(success: false, message: 'Autenticación cancelada');
      }
    } on PlatformException catch (e) {
      debugPrint('Error en autenticación biométrica: $e');
      return AuthResult(
          success: false,
          message: 'Error: ${e.message ?? 'Error desconocido'}'
      );
    }
  }

  Future<AuthResult> handleLogin() async {
    // Limpiar focus
    usernameFocusNode.unfocus();
    passwordFocusNode.unfocus();

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    HapticFeedback.lightImpact();

    try {
      final result = await _authService.login(
        usernameController.text.trim(),
        passwordController.text,
      );

      if (result.exitoso) {
        HapticFeedback.lightImpact();

        // NUEVA VALIDACIÓN: Verificar si el usuario tiene clientes asignados
        final validationResult = await _validateUserAssignment();
        if (!validationResult.success) {
          _errorMessage = validationResult.message;
          notifyListeners();
          return validationResult;
        }

        // Después del primer login exitoso, verificar biometría nuevamente
        await _checkBiometricAvailability();

        return AuthResult(
            success: true,
            message: result.mensaje,
            icon: Icons.check_circle_outline
        );
      } else {
        HapticFeedback.heavyImpact();
        _errorMessage = result.mensaje;
        notifyListeners();

        return AuthResult(success: false, message: result.mensaje);
      }
    } catch (e) {
      HapticFeedback.heavyImpact();
      _errorMessage = 'Error de conexión. Intenta nuevamente.';
      notifyListeners();

      return AuthResult(
          success: false,
          message: 'Error de conexión. Intenta nuevamente.'
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// NUEVA FUNCIÓN: Validar que el usuario tenga clientes asignados
  Future<AuthResult> _validateUserAssignment() async {
    try {
      // Obtener el usuario completo desde la base de datos
      final usuario = await _authService.getCurrentUser();

      // Verificar si edf_vendedor_id es null o vacío
      if (usuario?.edfVendedorId == null || usuario!.edfVendedorId!.trim().isEmpty) {
        return AuthResult(
            success: false,
            message: 'Su usuario no tiene clientes asignados.\n\n'
                'Comuníquese con el administrador del sistema para obtener acceso a los clientes.\n\n'
                'Si es un usuario nuevo, es posible que su cuenta aún no haya sido configurada completamente.',
            icon: Icons.admin_panel_settings
        );
      }

      // Si llegamos aquí, el usuario tiene edf_vendedor_id válido
      debugPrint('Usuario validado - edf_vendedor_id: ${usuario.edfVendedorId}');
      return AuthResult(
          success: true,
          message: 'Usuario validado correctamente'
      );

    } catch (e) {
      debugPrint('Error validando asignación de usuario: $e');
      return AuthResult(
          success: false,
          message: 'Error validando información del usuario. Intente nuevamente.\n\n'
              'Si el problema persiste, contacte al administrador.',
          icon: Icons.error_outline
      );
    }
  }

  void focusNextField() {
    passwordFocusNode.requestFocus();
  }

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    usernameFocusNode.dispose();
    passwordFocusNode.dispose();
    super.dispose();
  }
}

// Clase auxiliar para resultados de autenticación
class AuthResult {
  final bool success;
  final String message;
  final IconData? icon;

  AuthResult({
    required this.success,
    required this.message,
    this.icon,
  });
}