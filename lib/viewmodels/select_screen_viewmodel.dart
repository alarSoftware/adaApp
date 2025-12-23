import 'package:flutter/foundation.dart';
import 'package:ada_app/repositories/cliente_repository.dart';
import 'package:ada_app/repositories/equipo_repository.dart';
import '../services/sync/sync_service.dart';
import 'package:ada_app/services/data/database_helper.dart';
import 'package:ada_app/services/api/auth_service.dart';

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:ada_app/services/sync/full_sync_service.dart';
import 'package:ada_app/services/sync/base_sync_service.dart';

import 'package:ada_app/models/usuario.dart';
import 'package:ada_app/services/data/database_validation_service.dart';

// ========== CLASES DE VALIDACIÓN ==========
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
}

// ========== EVENTOS PARA LA UI (CERO WIDGETS) ==========
abstract class UIEvent {}

class ShowErrorEvent extends UIEvent {
  final String message;
  ShowErrorEvent(this.message);
}

class ShowSuccessEvent extends UIEvent {
  final String message;
  ShowSuccessEvent(this.message);
}

class RequestSyncConfirmationEvent extends UIEvent {
  final SyncInfo syncInfo;
  RequestSyncConfirmationEvent(this.syncInfo);
}

class RequiredSyncEvent extends UIEvent {
  final SyncValidationResult validationResult;
  final Usuario currentUser;
  RequiredSyncEvent(this.validationResult, this.currentUser);
}

class RequestDeleteConfirmationEvent extends UIEvent {}

class RequestDeleteWithValidationEvent extends UIEvent {
  final DatabaseValidationResult validationResult;
  RequestDeleteWithValidationEvent(this.validationResult);
}

class SyncCompletedEvent extends UIEvent {
  final SyncResult result;
  SyncCompletedEvent(this.result);
}

class RedirectToLoginEvent extends UIEvent {}

class SyncProgressEvent extends UIEvent {
  final double progress;
  final String currentStep;
  final List<String> completedSteps;

  SyncProgressEvent({
    required this.progress,
    required this.currentStep,
    required this.completedSteps,
  });
}

class SyncErrorEvent extends UIEvent {
  final String message;
  final String? details;

  SyncErrorEvent(this.message, {this.details});
}

// ========== DATOS PUROS (SIN UI) ==========
class SyncInfo {
  final int estimatedClients;
  final int estimatedEquipments;
  final int estimatedImages;
  final String serverUrl;

  SyncInfo({
    required this.estimatedClients,
    required this.estimatedEquipments,
    required this.estimatedImages,
    required this.serverUrl,
  });
}

class SyncResult {
  final bool success;
  final int clientsSynced;
  final int equipmentsSynced;
  final int imagesSynced;
  final String message;

  SyncResult({
    required this.success,
    required this.clientsSynced,
    required this.equipmentsSynced,
    required this.imagesSynced,
    required this.message,
  });
}

class ConnectionStatus {
  final bool hasInternet;
  final bool hasApiConnection;
  final String statusText;
  final ConnectionType type;

  ConnectionStatus({
    required this.hasInternet,
    required this.hasApiConnection,
    required this.statusText,
    required this.type,
  });
}

enum ConnectionType { connected, noInternet, noApi }

enum SyncValidationState { checking, required, optional, error }

// ========== VIEWMODEL 100% LIMPIO ==========
class SelectScreenViewModel extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final AuthService _authService = AuthService();

  // ========== ESTADO INTERNO ==========
  bool _isSyncing = false;
  bool _isTestingConnection = false;
  ConnectionStatus _connectionStatus = ConnectionStatus(
    hasInternet: false,
    hasApiConnection: false,
    statusText: 'Verificando...',
    type: ConnectionType.noInternet,
  );

  // Estado de progreso de sincronización
  double _syncProgress = 0.0;
  String _syncCurrentStep = '';
  List<String> _syncCompletedSteps = [];

  // ESTADO DEL USUARIO
  String _userFullName = 'Usuario';
  bool _isLoadingUser = true;
  Usuario? _currentUser;

  // ESTADO DE VALIDACIÓN DE SINCRONIZACIÓN
  SyncValidationState _syncValidationState = SyncValidationState.checking;
  SyncValidationResult? _syncValidationResult;

  // ========== STREAMS PARA COMUNICACIÓN ==========
  final StreamController<UIEvent> _eventController =
      StreamController<UIEvent>.broadcast();
  Stream<UIEvent> get uiEvents => _eventController.stream;

  // ========== SUBSCRIPTIONS ==========
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _apiMonitorTimer;

  // ========== GETTERS PÚBLICOS ==========
  bool get isSyncing => _isSyncing;
  bool get isTestingConnection => _isTestingConnection;
  ConnectionStatus get connectionStatus => _connectionStatus;
  bool get isConnected =>
      _connectionStatus.hasInternet && _connectionStatus.hasApiConnection;

  // Getters de progreso
  double get syncProgress => _syncProgress;
  String get syncCurrentStep => _syncCurrentStep;
  List<String> get syncCompletedSteps => List.from(_syncCompletedSteps);

  // GETTERS DEL USUARIO
  String get userDisplayName => _userFullName;
  bool get isLoadingUser => _isLoadingUser;
  Usuario? get currentUser => _currentUser;

  // GETTERS DE VALIDACIÓN DE SINCRONIZACIÓN
  SyncValidationState get syncValidationState => _syncValidationState;
  SyncValidationResult? get syncValidationResult => _syncValidationResult;
  bool get requiresMandatorySync =>
      _syncValidationState == SyncValidationState.required;
  bool get canAccessNormalFeatures =>
      _syncValidationState == SyncValidationState.optional;

  // ========== CONSTRUCTOR ==========
  SelectScreenViewModel() {
    _initializeMonitoring();
    _loadCurrentUserAndValidateSync();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _apiMonitorTimer?.cancel();
    _eventController.close();
    super.dispose();
  }

  // ========== INICIALIZACIÓN ==========
  void _initializeMonitoring() {
    _startConnectivityMonitoring();
    _startApiMonitoring();
    _checkInitialConnection();
  }

  // ✅ MÉTODO REFACTORIZADO - USA AuthService COMO FUENTE ÚNICA DE VERDAD
  Future<void> _loadCurrentUserAndValidateSync() async {
    try {
      _isLoadingUser = true;
      _syncValidationState = SyncValidationState.checking;
      notifyListeners();

      // 1. Obtener usuario completo actual
      _currentUser = await _authService.getCurrentUser();

      if (_currentUser == null) {
        _syncValidationState = SyncValidationState.error;
        _eventController.add(RedirectToLoginEvent());
        return;
      }


      // 2. Construir display name: Prefiriendo employeeName
      String displayName;
      if (_currentUser!.employeeName != null &&
          _currentUser!.employeeName!.trim().isNotEmpty) {
        displayName = _currentUser!.employeeName!;
      } else {
        displayName = _currentUser!.username;
      }
      _userFullName = displayName;

      // 3. ✅ USAR AuthService para validar sincronización (NO código duplicado)
      final authValidationResult = await _authService.validateSyncRequirement(
        _currentUser!.employeeId ?? '',
        displayName,
      );

      // Convertir resultado de AuthService a formato del ViewModel
      _syncValidationResult = SyncValidationResult(
        requiereSincronizacion: authValidationResult.requiereSincronizacion,
        razon: authValidationResult.razon,
        vendedorAnterior: authValidationResult.vendedorAnteriorNombre,
        vendedorActual: authValidationResult.vendedorActualNombre,
      );

      if (authValidationResult.requiereSincronizacion) {
        _syncValidationState = SyncValidationState.required;

        // Emitir evento para mostrar UI de sincronización obligatoria
        _eventController.add(
          RequiredSyncEvent(_syncValidationResult!, _currentUser!),
        );
      } else {
        _syncValidationState = SyncValidationState.optional;
      }
    } catch (e) {
      _syncValidationState = SyncValidationState.error;
      _userFullName = 'Usuario';
      _eventController.add(ShowErrorEvent('Error validando sesión: $e'));
    } finally {
      _isLoadingUser = false;
      notifyListeners();
    }
  }

  // ========== MÉTODOS DE CONECTIVIDAD ==========
  void _startConnectivityMonitoring() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _onConnectivityChanged,
    );
  }

  void _startApiMonitoring() {
    _apiMonitorTimer = Timer.periodic(
      Duration(minutes: 10),
      (_) => _checkApiConnectionSilently(),
    );
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final hasInternet = results.any((r) => r != ConnectivityResult.none);

    if (!hasInternet) {
      _updateConnectionStatus(
        hasInternet: false,
        hasApiConnection: false,
        statusText: 'Sin Internet',
        type: ConnectionType.noInternet,
      );
    } else if (_connectionStatus.hasInternet != hasInternet) {
      _checkApiConnectionSilently();
    }
  }

  Future<void> _checkInitialConnection() async {
    final connectivityResults = await Connectivity().checkConnectivity();
    final hasInternet = connectivityResults.any(
      (r) => r != ConnectivityResult.none,
    );

    if (hasInternet) {
      await _checkApiConnection();
    } else {
      _updateConnectionStatus(
        hasInternet: false,
        hasApiConnection: false,
        statusText: 'Sin Internet',
        type: ConnectionType.noInternet,
      );
    }
  }

  Future<void> _checkApiConnectionSilently() async {
    if (!_connectionStatus.hasInternet) return;

    try {
      final conexion = await SyncService.probarConexion();
      _updateConnectionStatus(
        hasInternet: true,
        hasApiConnection: conexion.exito,
        statusText: conexion.exito ? 'Conectado' : 'API Desconectada',
        type: conexion.exito ? ConnectionType.connected : ConnectionType.noApi,
      );
    } catch (e) {
      _updateConnectionStatus(
        hasInternet: true,
        hasApiConnection: false,
        statusText: 'API Desconectada',
        type: ConnectionType.noApi,
      );
    }
  }

  Future<void> _checkApiConnection() async {
    try {
      final conexion = await SyncService.probarConexion();
      _updateConnectionStatus(
        hasInternet: true,
        hasApiConnection: conexion.exito,
        statusText: conexion.exito ? 'Conectado' : 'API Desconectada',
        type: conexion.exito ? ConnectionType.connected : ConnectionType.noApi,
      );
    } catch (e) {
      _updateConnectionStatus(
        hasInternet: true,
        hasApiConnection: false,
        statusText: 'Error de conexión',
        type: ConnectionType.noApi,
      );
    }
  }

  void _updateConnectionStatus({
    required bool hasInternet,
    required bool hasApiConnection,
    required String statusText,
    required ConnectionType type,
  }) {
    _connectionStatus = ConnectionStatus(
      hasInternet: hasInternet,
      hasApiConnection: hasApiConnection,
      statusText: statusText,
      type: type,
    );
    notifyListeners();
  }

  // ========== ACCIONES PÚBLICAS ==========

  /// Solicita sincronización (pide confirmación a la UI)
  Future<void> requestSync() async {
    if (_isSyncing) return;

    // Si se requiere sincronización obligatoria, ejecutar directamente
    if (_syncValidationState == SyncValidationState.required) {
      await executeMandatorySync();
      return;
    }

    try {
      // Optimización: No probar conexión aquí para evitar 'loading' antes del diálogo.
      // Se probará al confirmar.
      final serverUrl = await BaseSyncService.getBaseUrl();

      final db = await _dbHelper.database;
      final validationService = DatabaseValidationService(db);
      final validationResult = await validationService.canDeleteDatabase();

      if (!validationResult.canDelete) {
        _eventController.add(
          RequestDeleteWithValidationEvent(validationResult),
        );
        return;
      }

      // Si todo está sincronizado, proceder normal
      final syncInfo = SyncInfo(
        estimatedClients: await _getEstimatedClients(),
        estimatedEquipments: await _getEstimatedEquipments(),
        estimatedImages: await _getEstimatedImages(),
        serverUrl: serverUrl,
      );

      _eventController.add(RequestSyncConfirmationEvent(syncInfo));
    } catch (e) {
      _eventController.add(ShowErrorEvent('Error inesperado: $e'));
    }
  }

  /// Ejecuta sincronización usando el servicio centralizado FullSyncService
  Future<void> _executeUnifiedSync({
    required String employeeId,
    String? edfVendedorNombre,
    String? previousVendedorId,
    bool forceClear = false,
  }) async {
    _setSyncLoading(true);
    _resetSyncProgress();

    try {
      final result = await FullSyncService.syncAllDataWithProgress(
        employeeId: employeeId,
        edfVendedorNombre: edfVendedorNombre,
        previousVendedorId: previousVendedorId,
        forceClear: forceClear,
        onProgress:
            ({
              required double progress,
              required String currentStep,
              required List<String> completedSteps,
            }) {
              // Actualizar estado interno
              _syncProgress = progress;
              _syncCurrentStep = currentStep;
              _syncCompletedSteps = List.from(completedSteps);

              // Emitir evento para la UI
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
        _eventController.add(
          SyncErrorEvent(
            'No se pudo completar la sincronización',
            details: result.mensaje,
          ),
        );
        return;
      }

      // Sincronización exitosa
      final syncResult = SyncResult(
        success: true,
        clientsSynced: result.itemsSincronizados,
        equipmentsSynced: 0,
        imagesSynced: 0,
        message: result.mensaje,
      );

      _eventController.add(SyncCompletedEvent(syncResult));
      await _checkApiConnection();
    } catch (e) {
      _eventController.add(
        SyncErrorEvent(
          'Error durante la sincronización',
          details: e.toString(),
        ),
      );
    } finally {
      _setSyncLoading(false);
      _resetSyncProgress();
    }
  }

  /// Ejecuta sincronización obligatoria usando el método unificado
  Future<void> executeMandatorySync() async {
    if (_currentUser == null) {
      _eventController.add(ShowErrorEvent('No hay usuario válido'));
      return;
    }

    try {
      // Verificar conexión
      final conexion = await SyncService.probarConexion();
      if (!conexion.exito) {
        _eventController.add(
          SyncErrorEvent('Sin conexión al servidor', details: conexion.mensaje),
        );
        return;
      }

      // Construir nombre para logs: username - Nombre Vendedor
      String nombreVendedor;
      if (_currentUser!.employeeName != null &&
          _currentUser!.employeeName!.trim().isNotEmpty) {
        nombreVendedor =
            '${_currentUser!.username} - ${_currentUser!.employeeName}';
      } else {
        nombreVendedor = _currentUser!.username;
      }

      // USAR MÉTODO UNIFICADO
      await _executeUnifiedSync(
        employeeId: _currentUser!.employeeId ?? '',
        edfVendedorNombre: nombreVendedor,
        previousVendedorId: _syncValidationResult?.vendedorAnterior,
      );

      // Actualizar estado de validación
      _syncValidationState = SyncValidationState.optional;
      notifyListeners();
    } catch (e) {
      _eventController.add(
        SyncErrorEvent(
          'Error en sincronización obligatoria',
          details: e.toString(),
        ),
      );
    }
  }

  /// Ejecuta la sincronización opcional (después de confirmación)
  Future<void> executeSync() async {
    if (_currentUser == null) {
      _eventController.add(ShowErrorEvent('No hay usuario válido'));
      return;
    }

    // Construir nombre para logs: username - Nombre Vendedor
    String nombreVendedor;
    if (_currentUser!.employeeName != null &&
        _currentUser!.employeeName!.trim().isNotEmpty) {
      nombreVendedor =
          '${_currentUser!.username} - ${_currentUser!.employeeName}';
    } else {
      nombreVendedor = _currentUser!.username;
    }

    // USAR MÉTODO UNIFICADO
    await _executeUnifiedSync(
      employeeId: _currentUser!.employeeId ?? '',
      edfVendedorNombre: nombreVendedor,
      previousVendedorId: null,
      forceClear: true,
    );
  }

  /// Prueba la conexión manualmente
  Future<void> testConnection() async {
    _setConnectionTestLoading(true);

    try {
      final response = await SyncService.probarConexion();

      if (response.exito) {
        _eventController.add(ShowSuccessEvent(response.mensaje));
        _updateConnectionStatus(
          hasInternet: true,
          hasApiConnection: true,
          statusText: 'Conectado',
          type: ConnectionType.connected,
        );
      } else {
        _eventController.add(ShowErrorEvent(response.mensaje));
        _updateConnectionStatus(
          hasInternet: true,
          hasApiConnection: false,
          statusText: 'API Desconectada',
          type: ConnectionType.noApi,
        );
      }
    } finally {
      _setConnectionTestLoading(false);
    }
  }

  /// Solicita borrar la base de datos CON VALIDACIÓN
  Future<void> requestDeleteDatabase() async {
    try {
      final db = await _dbHelper.database;
      final validationService = DatabaseValidationService(db);
      final validationResult = await validationService.canDeleteDatabase();

      if (validationResult.canDelete) {
        _eventController.add(RequestDeleteConfirmationEvent());
      } else {
        _eventController.add(
          RequestDeleteWithValidationEvent(validationResult),
        );
      }
    } catch (e) {
      _eventController.add(
        ShowErrorEvent('Error al validar la base de datos: $e'),
      );
    }
  }

  /// ✅ REFACTORIZADO - USA AuthService.clearSyncData()
  Future<void> executeDeleteDatabase() async {
    _setSyncLoading(true);

    try {
      // Borrar tablas principales
      await _dbHelper.eliminar('clientes');
      await _dbHelper.eliminar('equipos');
      await _dbHelper.eliminar('equipos_pendientes');
      await _dbHelper.eliminar('censo_activo');

      // Borrar tablas maestras
      await _dbHelper.eliminar('marcas');
      await _dbHelper.eliminar('modelos');
      await _dbHelper.eliminar('logo');
      await _dbHelper.eliminar('dynamic_form');
      await _dbHelper.eliminar('dynamic_form_detail');
      await _dbHelper.eliminar('dynamic_form_response');
      await _dbHelper.eliminar('dynamic_form_response_detail');
      await _dbHelper.eliminar('dynamic_form_response_image');

      // Borrar imágenes de censos
      await _dbHelper.eliminar('censo_activo_foto');

      // ✅ USAR AuthService para limpiar datos de sincronización
      await _authService.clearSyncData();

      // Revalidar sincronización después del borrado
      await _loadCurrentUserAndValidateSync();

      _eventController.add(
        ShowSuccessEvent('Base de datos borrada correctamente'),
      );

      // Recargar el estado de conexión
      await _checkInitialConnection();
    } catch (e) {
      _eventController.add(
        ShowErrorEvent('Error al borrar la base de datos: $e'),
      );
    } finally {
      _setSyncLoading(false);
    }
  }

  /// Refresca manualmente el estado de conexión
  Future<void> refresh() async {
    await _checkInitialConnection();
  }

  /// Refresca la información del usuario
  Future<void> refreshUser() async {
    await _loadCurrentUserAndValidateSync();
  }

  /// Fuerza revalidación de sincronización
  Future<void> revalidateSync() async {
    await _loadCurrentUserAndValidateSync();
  }

  /// Permite al usuario cancelar y volver al login
  Future<void> cancelAndLogout() async {
    try {
      await _authService.logout();
      _eventController.add(RedirectToLoginEvent());
    } catch (e) {
      _eventController.add(ShowErrorEvent('Error cerrando sesión: $e'));
    }
  }

  // ========== MÉTODOS PRIVADOS ==========

  void _setSyncLoading(bool loading) {
    _isSyncing = loading;
    notifyListeners();
  }

  void _setConnectionTestLoading(bool loading) {
    _isTestingConnection = loading;
    notifyListeners();
  }

  void _resetSyncProgress() {
    _syncProgress = 0.0;
    _syncCurrentStep = '';
    _syncCompletedSteps.clear();
    notifyListeners();
  }

  Future<int> _getEstimatedClients() async {
    try {
      final clienteRepo = ClienteRepository();
      return await clienteRepo.contar();
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getEstimatedEquipments() async {
    try {
      final equipoRepo = EquipoRepository();
      return await equipoRepo.contar();
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getEstimatedImages() async {
    try {
      final resultado = await _dbHelper.consultarPersonalizada(
        'SELECT COUNT(*) as total FROM censo_activo_foto',
        [],
      );
      return resultado.isNotEmpty ? (resultado.first['total'] as int? ?? 0) : 0;
    } catch (e) {
      return 0;
    }
  }
}
