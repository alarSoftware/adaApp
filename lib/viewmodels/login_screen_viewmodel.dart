import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:ada_app/services/auth_service.dart';
import 'package:ada_app/services/database_helper.dart';
import 'package:ada_app/services/database_validation_service.dart';
import 'package:ada_app/services/sync/full_sync_service.dart';
import 'package:ada_app/models/usuario.dart';
import 'dart:async';

abstract class LoginUIEvent {}

class ShowErrorEvent extends LoginUIEvent {
  final String message;
  ShowErrorEvent(this.message);
}

class ShowSuccessEvent extends LoginUIEvent {
  final String message;
  final IconData? icon;
  ShowSuccessEvent(this.message, [this.icon]);
}

class NavigateToHomeEvent extends LoginUIEvent {}

class ShowSyncRequiredDialogEvent extends LoginUIEvent {
  final SyncValidationResult validation;
  final Usuario currentUser;
  ShowSyncRequiredDialogEvent(this.validation, this.currentUser);
}

class ShowPendingRecordsDialogEvent extends LoginUIEvent {
  final DatabaseValidationResult validationResult;
  ShowPendingRecordsDialogEvent(this.validationResult);
}

class SyncProgressEvent extends LoginUIEvent {
  final double progress;
  final String currentStep;
  final List<String> completedSteps;

  SyncProgressEvent({
    required this.progress,
    required this.currentStep,
    required this.completedSteps,
  });
}

class SyncCompletedEvent extends LoginUIEvent {
  final String message;
  final int itemsSynced;
  SyncCompletedEvent(this.message, this.itemsSynced);
}

class LoginScreenViewModel extends ChangeNotifier {
  final _authService = AuthService();
  final _localAuth = LocalAuthentication();
  final _dbHelper = DatabaseHelper();

  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final usernameFocusNode = FocusNode();
  final passwordFocusNode = FocusNode();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _biometricAvailable = false;
  bool _usernameValid = false;
  bool _passwordValid = false;
  bool _isSyncing = false;
  String? _errorMessage;

  Usuario? _currentUser;

  SyncValidationResult? _syncValidationResult;
  double _syncProgress = 0.0;
  String _syncCurrentStep = '';
  List<String> _syncCompletedSteps = [];

  final StreamController<LoginUIEvent> _eventController =
  StreamController<LoginUIEvent>.broadcast();
  Stream<LoginUIEvent> get uiEvents => _eventController.stream;

  bool get isLoading => _isLoading;
  bool get obscurePassword => _obscurePassword;
  bool get biometricAvailable => _biometricAvailable;
  bool get usernameValid => _usernameValid;
  bool get passwordValid => _passwordValid;
  bool get isSyncing => _isSyncing;
  String? get errorMessage => _errorMessage;
  Usuario? get currentUser => _currentUser;

  double get syncProgress => _syncProgress;
  String get syncCurrentStep => _syncCurrentStep;
  List<String> get syncCompletedSteps => List.from(_syncCompletedSteps);

  LoginScreenViewModel() {
    _setupValidationListeners();
    _checkBiometricAvailability();
  }

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    usernameFocusNode.dispose();
    passwordFocusNode.dispose();
    _eventController.close();
    super.dispose();
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

  Future<void> _checkBiometricAvailability() async {
    try {
      final bool isAvailable = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      final bool hasLoggedInBefore = await _authService.hasUserLoggedInBefore();

      _biometricAvailable = isAvailable && isDeviceSupported && hasLoggedInBefore;
      notifyListeners();
    } catch (e) {
      // Silently fail
    }
  }

  String? validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) return 'El usuario es requerido';
    if (value.length < 3) return 'Usuario debe tener al menos 3 caracteres';
    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'La contraseña es requerida';
    if (value.length < 6) return 'Mínimo 6 caracteres';
    return null;
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

  void focusNextField() {
    passwordFocusNode.requestFocus();
  }

  Future<void> handleLogin() async {
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

      if (!result.exitoso) {
        HapticFeedback.heavyImpact();
        _errorMessage = result.mensaje;
        _eventController.add(ShowErrorEvent(result.mensaje));
        return;
      }

      HapticFeedback.lightImpact();

      _currentUser = await _authService.getCurrentUser();

      if (_currentUser == null) {
        _errorMessage = 'Error obteniendo información del usuario';
        _eventController.add(ShowErrorEvent(_errorMessage!));
        return;
      }

      final validationResult = await _validateUserAssignment();
      if (!validationResult) return;

      final syncValidation = await _validateSyncRequirement();

      if (syncValidation.requiereSincronizacion) {
        _syncValidationResult = syncValidation;
        _eventController.add(
            ShowSyncRequiredDialogEvent(syncValidation, _currentUser!)
        );
        return;
      }

      await _checkBiometricAvailability();
      _eventController.add(ShowSuccessEvent(
        'Bienvenido ${_currentUser!.fullname}',
        Icons.check_circle_outline,
      ));
      _eventController.add(NavigateToHomeEvent());

    } catch (e) {
      HapticFeedback.heavyImpact();
      _errorMessage = 'Error de conexión. Intenta nuevamente.';
      _eventController.add(ShowErrorEvent(_errorMessage!));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> authenticateWithBiometric() async {
    try {
      HapticFeedback.lightImpact();

      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Autentica tu identidad para acceder a la aplicación',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          sensitiveTransaction: true,
        ),
      );

      if (!didAuthenticate) {
        _eventController.add(ShowErrorEvent('Autenticación cancelada'));
        return;
      }

      HapticFeedback.lightImpact();

      final result = await _authService.authenticateWithBiometric();

      if (!result.exitoso) {
        _eventController.add(ShowErrorEvent(result.mensaje));
        return;
      }

      _currentUser = await _authService.getCurrentUser();

      if (_currentUser == null) {
        _eventController.add(ShowErrorEvent('Error obteniendo información del usuario'));
        return;
      }

      final validationResult = await _validateUserAssignment();
      if (!validationResult) return;

      final syncValidation = await _validateSyncRequirement();

      if (syncValidation.requiereSincronizacion) {
        _syncValidationResult = syncValidation;
        _eventController.add(
            ShowSyncRequiredDialogEvent(syncValidation, _currentUser!)
        );
        return;
      }

      _eventController.add(ShowSuccessEvent(
        'Bienvenido ${_currentUser!.fullname}',
        Icons.fingerprint,
      ));
      _eventController.add(NavigateToHomeEvent());

    } on PlatformException catch (e) {
      _eventController.add(ShowErrorEvent(
        'Error: ${e.message ?? 'Error desconocido'}',
      ));
    } catch (e) {
      _eventController.add(ShowErrorEvent('Error de autenticación'));
    }
  }

  Future<bool> _validateUserAssignment() async {
    try {
      if (_currentUser?.edfVendedorId == null ||
          _currentUser!.edfVendedorId!.trim().isEmpty) {

        final errorMsg = 'Su usuario no tiene vendedor asociado.\n\n'
            'Comuníquese con el administrador del sistema para obtener acceso a los clientes.\n\n'
            'Si es un usuario nuevo, es posible que su cuenta aún no haya sido configurada completamente.';

        _errorMessage = errorMsg;
        _eventController.add(ShowErrorEvent(errorMsg));
        return false;
      }
      return true;
    } catch (e) {
      final errorMsg = 'Error validando información del usuario.';
      _errorMessage = errorMsg;
      _eventController.add(ShowErrorEvent(errorMsg));
      return false;
    }
  }

  Future<SyncValidationResult> _validateSyncRequirement() async {
    try {
      final nombreVendedor = _currentUser!.edfVendedorNombre ?? _currentUser!.username;

      return await _authService.validateSyncRequirement(
        _currentUser!.edfVendedorId!,
        nombreVendedor,
      );
    } catch (e) {
      final nombreVendedor = _currentUser?.edfVendedorNombre ?? 'Desconocido';

      return SyncValidationResult(
        requiereSincronizacion: true,
        razon: 'Error en validación - sincronización por seguridad',
        vendedorAnteriorId: null,
        vendedorActualId: _currentUser!.edfVendedorId ?? '',
        vendedorAnteriorNombre: null,
        vendedorActualNombre: nombreVendedor,
      );
    }
  }

  Future<void> requestSync() async {
    if (_isSyncing || _currentUser == null) return;

    try {
      final db = await _dbHelper.database;
      final validationService = DatabaseValidationService(db);
      final validationResult = await validationService.canDeleteDatabase();

      if (!validationResult.canDelete) {
        _eventController.add(ShowPendingRecordsDialogEvent(validationResult));
        return;
      }

      await executeSync();

    } catch (e) {
      _eventController.add(ShowErrorEvent('Error al validar datos: $e'));
    }
  }

  Future<void> executeSync() async {
    if (_currentUser == null) {
      _eventController.add(ShowErrorEvent('No hay usuario válido'));
      return;
    }

    _isSyncing = true;
    _resetSyncProgress();
    notifyListeners();

    try {
      final result = await FullSyncService.syncAllDataWithProgress(
        edfVendedorId: _currentUser!.edfVendedorId!,
        previousVendedorId: _syncValidationResult?.vendedorAnteriorId,
        onProgress: ({
          required double progress,
          required String currentStep,
          required List<String> completedSteps,
        }) {
          _syncProgress = progress;
          _syncCurrentStep = currentStep;
          _syncCompletedSteps = List.from(completedSteps);

          _eventController.add(SyncProgressEvent(
            progress: progress,
            currentStep: currentStep,
            completedSteps: completedSteps,
          ));
          notifyListeners();
        },
      );

      if (!result.exito) {
        throw Exception(result.mensaje);
      }

      final nombreVendedor = _currentUser!.edfVendedorNombre ?? _currentUser!.username;

      await _authService.markSyncCompleted(
        _currentUser!.edfVendedorId!,
        nombreVendedor,
      );

      _eventController.add(SyncCompletedEvent(
        result.mensaje,
        result.itemsSincronizados,
      ));

      _eventController.add(ShowSuccessEvent(
        '${result.itemsSincronizados} registros sincronizados',
        Icons.cloud_done,
      ));

      _eventController.add(NavigateToHomeEvent());

    } catch (e) {
      _eventController.add(ShowErrorEvent('Error en sincronización: $e'));
    } finally {
      _isSyncing = false;
      _resetSyncProgress();
      notifyListeners();
    }
  }

  Future<void> syncUsers() async {
    _isSyncing = true;
    notifyListeners();

    try {
      final resultado = await AuthService.sincronizarSoloUsuarios();

      if (resultado.exito) {
        _eventController.add(ShowSuccessEvent('Usuarios sincronizados', Icons.cloud_done));
      } else {
        _eventController.add(ShowErrorEvent(resultado.mensaje));
      }
    } catch (e) {
      _eventController.add(ShowErrorEvent('Error: $e'));
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> deleteUsersTable() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _dbHelper.eliminar('Users');
      _eventController.add(ShowSuccessEvent('Tabla de usuarios eliminada correctamente', Icons.delete_sweep));
    } catch (e) {
      _eventController.add(ShowErrorEvent('Error al eliminar usuarios: $e'));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _resetSyncProgress() {
    _syncProgress = 0.0;
    _syncCurrentStep = '';
    _syncCompletedSteps.clear();
  }
}