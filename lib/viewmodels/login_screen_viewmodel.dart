import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:ada_app/services/api/auth_service.dart';
import 'package:ada_app/services/data/database_helper.dart';
import 'package:ada_app/services/data/database_validation_service.dart';
import 'package:ada_app/services/sync/full_sync_service.dart';
import 'package:ada_app/models/usuario.dart';
import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:ada_app/services/censo/censo_upload_service.dart';
import 'package:ada_app/services/dynamic_form/dynamic_form_upload_service.dart';
import 'package:ada_app/services/device_log/device_log_upload_service.dart';
import 'package:permission_handler/permission_handler.dart';

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
    _checkUsersTableEmpty();
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
    final isValid = value.isNotEmpty;

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

      _biometricAvailable =
          isAvailable && isDeviceSupported && hasLoggedInBefore;
      notifyListeners();
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _checkUsersTableEmpty() async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery('SELECT count(*) as count FROM Users');
      final count = Sqflite.firstIntValue(result) ?? 0;

      if (count == 0) {
        _errorMessage =
            'No hay usuarios registrados.\nPor favor sincronice los usuarios.';
        // No enviamos evento ShowErrorEvent aquí para no mostrar un snackbar/dialog intrusivo al inicio,
        // pero sí mostramos el mensaje en el formulario (que usa _errorMessage).
        notifyListeners();
      }
    } catch (e) {
      // Silently fail or log
    }
  }

  String? validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) return 'El usuario es requerido';
    if (value.length < 3) return 'Usuario debe tener al menos 3 caracteres';
    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'La contraseña es requerida';
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

  // ✅ MÉTODO HELPER PARA CONSTRUIR EL DISPLAY NAME (igual que en AuthService)
  String _buildVendorDisplayName(Usuario usuario) {
    if (usuario.employeeName != null &&
        usuario.employeeName!.trim().isNotEmpty) {
      return '${usuario.username} - ${usuario.employeeName}';
    }
    return usuario.username;
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
          ShowSyncRequiredDialogEvent(syncValidation, _currentUser!),
        );
        return;
      }

      await _checkBiometricAvailability();

      // Solicitud de permisos proactiva
      await checkAndRequestPermissions();

      _eventController.add(
        ShowSuccessEvent(
          'Bienvenido ${_currentUser!.fullname}',
          Icons.check_circle_outline,
        ),
      );
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
        _eventController.add(
          ShowErrorEvent('Error obteniendo información del usuario'),
        );
        return;
      }

      final validationResult = await _validateUserAssignment();
      if (!validationResult) return;

      final syncValidation = await _validateSyncRequirement();

      if (syncValidation.requiereSincronizacion) {
        _syncValidationResult = syncValidation;
        _eventController.add(
          ShowSyncRequiredDialogEvent(syncValidation, _currentUser!),
        );
        return;
      }

      // Solicitud de permisos proactiva
      await checkAndRequestPermissions();

      _eventController.add(
        ShowSuccessEvent(
          'Bienvenido ${_currentUser!.fullname}',
          Icons.fingerprint,
        ),
      );
      _eventController.add(NavigateToHomeEvent());
    } on PlatformException catch (e) {
      _eventController.add(
        ShowErrorEvent('Error: ${e.message ?? 'Error desconocido'}'),
      );
    } catch (e) {
      _eventController.add(ShowErrorEvent('Error de autenticación'));
    }
  }

  Future<bool> _validateUserAssignment() async {
    try {
      if (_currentUser?.employeeId == null ||
          _currentUser!.employeeId!.trim().isEmpty) {
        final errorMsg =
            'Su usuario no tiene vendedor asociado.\n\n'
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

  // ✅ MÉTODO CORREGIDO - Construye el display name completo antes de validar
  Future<SyncValidationResult> _validateSyncRequirement() async {
    try {
      // ✅ CORRECCIÓN CLAVE: Construir el nombre completo "username - Nombre Vendedor"
      final displayName = _buildVendorDisplayName(_currentUser!);

      // ✅ Pasar el nombre completo construido a validateSyncRequirement
      return await _authService.validateSyncRequirement(
        _currentUser!.employeeId!,
        displayName, // ← Ahora incluye "username - Nombre Vendedor"
      );
    } catch (e) {
      // ✅ En caso de error, también construir el nombre completo
      final displayName = _buildVendorDisplayName(_currentUser!);

      return SyncValidationResult(
        requiereSincronizacion: true,
        razon: 'Error en validación - sincronización por seguridad',
        vendedorAnteriorId: null,
        vendedorActualId: _currentUser!.employeeId ?? '',
        vendedorAnteriorNombre: null,
        vendedorActualNombre: displayName, // ← Nombre completo
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

  /// 🛡️ Validar y solicitar permisos críticos antes de entrar a la app
  Future<void> checkAndRequestPermissions() async {
    try {
      // 2. Ubicación
      // Primero 'location' (precisa/coarse en uso)
      var locStatus = await Permission.location.status;
      if (!locStatus.isGranted) {
        locStatus = await Permission.location.request();
      }

      // Si se concedió ubicación básica, intentar 'locationAlways' para background
      // Nota: En Android 11+ el sistema puede requerir hacerlo en pasos separados o ajustes
      if (locStatus.isGranted) {
        if (await Permission.locationAlways.isDenied) {
          // No bloqueamos el login si esto falla, pero lo intentamos
          await Permission.locationAlways.request();
        }
      }

      // 1. Notificaciones (Android 13+)
      // Requerido para ver la notificación persistente
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }

      // 3. Optimización de batería
      // Importante para que el servicio no muera
      if (await Permission.ignoreBatteryOptimizations.isDenied) {
        await Permission.ignoreBatteryOptimizations.request();
      }
    } catch (e) {
      debugPrint('Error solicitando permisos: $e');
    }
  }

  Future<void> uploadPendingData() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Intentar subir censos
      try {
        final censoService = CensoUploadService();
        final userId = _currentUser?.id ?? 0;
        await censoService.sincronizarCensosNoMigrados(userId);
      } catch (e) {
        debugPrint('Error subiendo censos: $e');
      }

      // 2. Intentar subir formularios
      try {
        final formService = DynamicFormUploadService();
        final userIdStr = _currentUser?.id?.toString() ?? '0';
        await formService.sincronizarRespuestasPendientes(userIdStr);
      } catch (e) {
        debugPrint('Error subiendo formularios: $e');
      }

      // 3. Intentar subir logs
      try {
        await DeviceLogUploadService.sincronizarDeviceLogsPendientes();
      } catch (e) {
        debugPrint('Error subiendo logs: $e');
      }

      // 4. Re-verificar estado
      final db = await _dbHelper.database;
      final validationService = DatabaseValidationService(db);
      final validationResult = await validationService.canDeleteDatabase();

      _isLoading = false;
      notifyListeners();

      if (!validationResult.canDelete) {
        // Aún hay pendientes
        _eventController.add(ShowPendingRecordsDialogEvent(validationResult));
        _eventController.add(
          ShowErrorEvent(
            'Aún quedan registros pendientes. Revise su conexión.',
          ),
        );
      } else {
        // Ya no hay pendientes, ¡Éxito!
        _eventController.add(
          ShowSuccessEvent(
            'Datos pendientes enviados correctamente',
            Icons.cloud_upload,
          ),
        );
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      _eventController.add(
        ShowErrorEvent('Error enviando datos pendientes: $e'),
      );
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
      // ✅ Usar el método helper para construir el nombre consistentemente
      final displayName = _buildVendorDisplayName(_currentUser!);

      final result = await FullSyncService.syncAllDataWithProgress(
        employeeId: _currentUser!.employeeId!,
        edfVendedorNombre:
            displayName, // ← Nombre completo "username - Nombre Vendedor"
        previousVendedorId: _syncValidationResult?.vendedorAnteriorId,
        onProgress:
            ({
              required double progress,
              required String currentStep,
              required List<String> completedSteps,
            }) {
              _syncProgress = progress;
              _syncCurrentStep = currentStep;
              _syncCompletedSteps = List.from(completedSteps);

              _eventController.add(
                SyncProgressEvent(
                  progress: progress,
                  currentStep: currentStep,
                  completedSteps: completedSteps,
                ),
              );
              notifyListeners();
            },
      );

      if (!result.exito) {
        throw Exception(result.mensaje);
      }

      // FullSyncService ya marca la sincronización como completada internamente
      // por lo que no necesitamos llamar a markSyncCompleted aquí

      _eventController.add(
        SyncCompletedEvent(result.mensaje, result.itemsSincronizados),
      );

      _eventController.add(
        ShowSuccessEvent(
          '${result.itemsSincronizados} registros sincronizados',
          Icons.cloud_done,
        ),
      );

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
        _eventController.add(
          ShowSuccessEvent('Usuarios sincronizados', Icons.cloud_done),
        );
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
      _eventController.add(
        ShowSuccessEvent(
          'Tabla de usuarios eliminada correctamente',
          Icons.delete_sweep,
        ),
      );
    } catch (e) {
      _eventController.add(ShowErrorEvent('Error al eliminar usuarios: $e'));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> performDebugAdminLogin() async {
    _isLoading = true;
    notifyListeners();
    HapticFeedback.lightImpact();

    try {
      final db = await _dbHelper.database;
      // Buscar usuario admin o useradmin
      final result = await db.query(
        'Users',
        where: 'LOWER(username) IN (?, ?)',
        whereArgs: ['admin', 'useradmin'],
        limit: 1,
      );

      if (result.isEmpty) {
        _eventController.add(
          ShowErrorEvent('No se encontró usuario administrador en la BD local'),
        );
        return;
      }

      final adminUser = Usuario.fromMap(result.first);

      // Usar login forzado (bypass contraseña)
      final authResult = await _authService.forceLogin(adminUser);

      if (!authResult.exitoso) {
        _eventController.add(ShowErrorEvent(authResult.mensaje));
        return;
      }

      _currentUser = await _authService.getCurrentUser();

      if (_currentUser == null) {
        _eventController.add(
          ShowErrorEvent('Error obteniendo información del usuario'),
        );
        return;
      }

      final validationResult = await _validateUserAssignment();
      if (!validationResult) return;

      final syncValidation = await _validateSyncRequirement();

      if (syncValidation.requiereSincronizacion) {
        _syncValidationResult = syncValidation;
        _eventController.add(
          ShowSyncRequiredDialogEvent(syncValidation, _currentUser!),
        );
        return;
      }

      await _checkBiometricAvailability();
      await checkAndRequestPermissions();

      _eventController.add(
        ShowSuccessEvent(
          'Modo Debug: ${_currentUser!.fullname}',
          Icons.admin_panel_settings,
        ),
      );
      _eventController.add(NavigateToHomeEvent());
    } catch (e) {
      _eventController.add(ShowErrorEvent('Error en debug login: $e'));
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
