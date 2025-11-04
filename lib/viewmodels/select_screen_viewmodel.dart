import 'package:flutter/foundation.dart';
import 'package:ada_app/repositories/cliente_repository.dart';
import 'package:ada_app/repositories/equipo_repository.dart';
import '../services/sync/sync_service.dart';
import '../services/database_helper.dart';
import '../services/auth_service.dart';
import 'package:logger/logger.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ada_app/services/sync/full_sync_service.dart';
import 'package:ada_app/repositories/equipo_pendiente_repository.dart';
import 'package:ada_app/models/usuario.dart';
import 'package:ada_app/services/database_validation_service.dart'; // 🆕 NUEVO

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

// 🆕 NUEVO: Evento con validación de eliminación
class RequestDeleteWithValidationEvent extends UIEvent {
  final DatabaseValidationResult validationResult;
  RequestDeleteWithValidationEvent(this.validationResult);
}

class SyncCompletedEvent extends UIEvent {
  final SyncResult result;
  SyncCompletedEvent(this.result);
}

class RedirectToLoginEvent extends UIEvent {}

// Evento para actualizar progreso de sincronización
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

enum ConnectionType {
  connected,
  noInternet,
  noApi
}

enum SyncValidationState {
  checking,
  required,
  optional,
  error,
}

// ========== VIEWMODEL 100% LIMPIO ==========
class SelectScreenViewModel extends ChangeNotifier {
  final Logger _logger = Logger();
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
  final StreamController<UIEvent> _eventController = StreamController<UIEvent>.broadcast();
  Stream<UIEvent> get uiEvents => _eventController.stream;

  // ========== SUBSCRIPTIONS ==========
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _apiMonitorTimer;

  // ========== GETTERS PÚBLICOS ==========
  bool get isSyncing => _isSyncing;
  bool get isTestingConnection => _isTestingConnection;
  ConnectionStatus get connectionStatus => _connectionStatus;
  bool get isConnected => _connectionStatus.hasInternet && _connectionStatus.hasApiConnection;

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
  bool get requiresMandatorySync => _syncValidationState == SyncValidationState.required;
  bool get canAccessNormalFeatures => _syncValidationState == SyncValidationState.optional;

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

  // MÉTODO MEJORADO PARA CARGAR USUARIO Y VALIDAR SINCRONIZACIÓN
  Future<void> _loadCurrentUserAndValidateSync() async {
    try {
      _isLoadingUser = true;
      _syncValidationState = SyncValidationState.checking;
      notifyListeners();

      // 1. Obtener usuario completo actual
      _currentUser = await _authService.getCurrentUser();

      if (_currentUser == null) {
        _logger.w('No hay usuario logueado');
        _syncValidationState = SyncValidationState.error;
        _eventController.add(RedirectToLoginEvent());
        return;
      }

      // 2. Actualizar display name
      _userFullName = _currentUser!.fullname.isNotEmpty
          ? _currentUser!.fullname
          : _currentUser!.username;

      // 3. Validar si se requiere sincronización obligatoria
      final validationResult = await _validateSyncRequirement(
        _currentUser!.edfVendedorId ?? '',
      );

      _syncValidationResult = validationResult;

      if (validationResult.requiereSincronizacion) {
        _logger.w('Sincronización obligatoria requerida: ${validationResult.razon}');
        _syncValidationState = SyncValidationState.required;

        // Emitir evento para mostrar UI de sincronización obligatoria
        _eventController.add(RequiredSyncEvent(validationResult, _currentUser!));
      } else {
        _logger.i('No se requiere sincronización obligatoria');
        _syncValidationState = SyncValidationState.optional;
      }

    } catch (e) {
      _logger.e('Error cargando usuario y validando sincronización: $e');
      _syncValidationState = SyncValidationState.error;
      _userFullName = 'Usuario';
      _eventController.add(ShowErrorEvent('Error validando sesión: $e'));
    } finally {
      _isLoadingUser = false;
      notifyListeners();
    }
  }

  // Validación de sincronización
  Future<SyncValidationResult> _validateSyncRequirement(String currentEdfVendedorId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncedVendedor = prefs.getString('last_synced_vendedor_id');

      _logger.i('Validando sincronización: Usuario actual edf_vendedor_id: $currentEdfVendedorId');
      _logger.i('Último vendedor sincronizado: $lastSyncedVendedor');

      // Si es la primera vez o no hay vendedor previo
      if (lastSyncedVendedor == null) {
        _logger.i('Primera sincronización - se requiere sincronizar');
        return SyncValidationResult(
          requiereSincronizacion: true,
          razon: 'Primera sincronización requerida',
          vendedorAnterior: null,
          vendedorActual: currentEdfVendedorId,
        );
      }

      // Si el vendedor es diferente al último sincronizado
      if (lastSyncedVendedor != currentEdfVendedorId) {
        _logger.w('Vendedor diferente detectado - sincronización obligatoria');
        return SyncValidationResult(
          requiereSincronizacion: true,
          razon: 'Cambio de vendedor detectado',
          vendedorAnterior: lastSyncedVendedor,
          vendedorActual: currentEdfVendedorId,
        );
      }

      // Vendedor es el mismo, no requiere sincronización forzada
      _logger.i('Mismo vendedor - no requiere sincronización forzada');
      return SyncValidationResult(
        requiereSincronizacion: false,
        razon: 'Mismo vendedor que la sincronización anterior',
        vendedorAnterior: lastSyncedVendedor,
        vendedorActual: currentEdfVendedorId,
      );

    } catch (e) {
      _logger.e('Error validando requerimiento de sincronización: $e');
      return SyncValidationResult(
        requiereSincronizacion: true,
        razon: 'Error en validación - sincronización por seguridad',
        vendedorAnterior: null,
        vendedorActual: currentEdfVendedorId,
      );
    }
  }

  Future<void> _markSyncCompleted(String edfVendedorId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_synced_vendedor_id', edfVendedorId);
      await prefs.setString('last_sync_date', DateTime.now().toIso8601String());

      _logger.i('Sincronización marcada como completada para vendedor: $edfVendedorId');
    } catch (e) {
      _logger.e('Error marcando sincronización completada: $e');
    }
  }

  Future<void> _clearSyncData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_synced_vendedor_id');
      await prefs.remove('last_sync_date');

      // Limpiar clientes de la base de datos local
      await _dbHelper.eliminar('clientes');

      _logger.i('Datos de sincronización limpiados');
    } catch (e) {
      _logger.e('Error limpiando datos de sincronización: $e');
    }
  }

  // IMPLEMENTACIÓN REAL DE BÚSQUEDA EN BASE DE DATOS
  Future<String?> _getFullNameFromDatabase(String username) async {
    try {
      _logger.i('Buscando en BD el fullname para: $username');

      final resultado = await _dbHelper.consultarPersonalizada(
          'SELECT fullname FROM Users WHERE username = ? LIMIT 1',
          [username]
      );

      if (resultado.isNotEmpty) {
        final fullname = resultado.first['fullname']?.toString();
        if (fullname != null && fullname.isNotEmpty) {
          return fullname;
        }
      }

      return null;
    } catch (e) {
      _logger.e('Error buscando usuario en BD: $e');
      return null;
    }
  }

  void _startConnectivityMonitoring() {
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen(_onConnectivityChanged);
  }

  void _startApiMonitoring() {
    _apiMonitorTimer = Timer.periodic(
      Duration(minutes: 10),
          (_) => _checkApiConnectionSilently(),
    );
  }

  // ========== LÓGICA DE CONECTIVIDAD ==========
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
    final hasInternet = connectivityResults.any((r) => r != ConnectivityResult.none);

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
      _logger.w('API no disponible: $e');
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
      _logger.e('Error verificando conexión: $e');
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
      final conexion = await SyncService.probarConexion();
      if (!conexion.exito) {
        _eventController.add(ShowErrorEvent('Sin conexión al servidor: ${conexion.mensaje}'));
        return;
      }

      // Obtener información para mostrar en el diálogo
      final syncInfo = SyncInfo(
        estimatedClients: await _getEstimatedClients(),
        estimatedEquipments: await _getEstimatedEquipments(),
        estimatedImages: await _getEstimatedImages(),
        serverUrl: conexion.mensaje,
      );

      // Solicitar confirmación a la UI
      _eventController.add(RequestSyncConfirmationEvent(syncInfo));
    } catch (e) {
      _eventController.add(ShowErrorEvent('Error inesperado: $e'));
    }
  }

  // ========== 🎯 MÉTODO UNIFICADO DE SINCRONIZACIÓN ==========
  /// Ejecuta sincronización usando el servicio centralizado FullSyncService
  Future<void> _executeUnifiedSync({
    required String edfVendedorId,
    String? previousVendedorId,
  }) async {
    _setSyncLoading(true);
    _resetSyncProgress();

    try {
      // USAR EL SERVICIO UNIFICADO
      final result = await FullSyncService.syncAllDataWithProgress(
        edfVendedorId: edfVendedorId,
        previousVendedorId: previousVendedorId,
        onProgress: ({
          required double progress,
          required String currentStep,
          required List<String> completedSteps,
        }) {
          // Actualizar estado interno
          _syncProgress = progress;
          _syncCurrentStep = currentStep;
          _syncCompletedSteps = List.from(completedSteps);

          // Emitir evento para la UI
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

      _logger.i('✅ Sincronización unificada completada exitosamente');

    } catch (e) {
      _logger.e('❌ Error en sincronización unificada: $e');
      _eventController.add(ShowErrorEvent('Error en sincronización: $e'));
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
        _eventController.add(ShowErrorEvent('Sin conexión al servidor: ${conexion.mensaje}'));
        return;
      }

      // USAR MÉTODO UNIFICADO
      await _executeUnifiedSync(
        edfVendedorId: _currentUser!.edfVendedorId ?? '',
        previousVendedorId: _syncValidationResult?.vendedorAnterior,
      );

      // Actualizar estado de validación
      _syncValidationState = SyncValidationState.optional;
      notifyListeners();

    } catch (e) {
      _logger.e('Error en sincronización obligatoria: $e');
      _eventController.add(ShowErrorEvent('Error en sincronización: $e'));
    }
  }

  /// Ejecuta la sincronización opcional (después de confirmación)
  Future<void> executeSync() async {
    if (_currentUser == null) {
      _eventController.add(ShowErrorEvent('No hay usuario válido'));
      return;
    }

    // USAR MÉTODO UNIFICADO
    await _executeUnifiedSync(
      edfVendedorId: _currentUser!.edfVendedorId ?? '',
      previousVendedorId: null,
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

  // 🔒 VALIDACIÓN ANTES DE ELIMINAR BASE DE DATOS
  /// Solicita borrar la base de datos CON VALIDACIÓN
  Future<void> requestDeleteDatabase() async {
    try {
      _logger.i('🔍 Validando si se puede eliminar la base de datos...');

      // Obtener la base de datos
      final db = await _dbHelper.database;

      // Crear servicio de validación
      final validationService = DatabaseValidationService(db);

      // Verificar si se puede eliminar
      final validationResult = await validationService.canDeleteDatabase();

      if (validationResult.canDelete) {
        _logger.i('✅ Base de datos puede ser eliminada de forma segura');
        // Enviar evento de confirmación normal
        _eventController.add(RequestDeleteConfirmationEvent());
      } else {
        _logger.w('⚠️ Hay registros pendientes de sincronizar');
        // Enviar evento con la validación para mostrar detalles
        _eventController.add(RequestDeleteWithValidationEvent(validationResult));
      }

    } catch (e) {
      _logger.e('❌ Error validando base de datos: $e');
      _eventController.add(ShowErrorEvent('Error al validar la base de datos: $e'));
    }
  }

  /// Ejecuta el borrado de la base de datos (excepto usuarios)
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

      // Limpiar datos de sincronización
      await _clearSyncData();

      // NOTA: NO se borra la tabla Users

      _logger.i('Base de datos limpiada (usuarios preservados)');

      // Revalidar sincronización después del borrado
      await _loadCurrentUserAndValidateSync();

      _eventController.add(ShowSuccessEvent('Base de datos borrada correctamente'));

      // Recargar el estado de conexión
      await _checkInitialConnection();
    } catch (e) {
      _logger.e('Error al borrar la base de datos: $e');
      _eventController.add(ShowErrorEvent('Error al borrar la base de datos: $e'));
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
      _logger.e('Error en logout: $e');
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