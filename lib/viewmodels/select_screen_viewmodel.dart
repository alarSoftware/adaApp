import 'package:flutter/foundation.dart';
import 'package:ada_app/repositories/cliente_repository.dart';
import 'package:ada_app/repositories/equipo_repository.dart';
import '../services/sync/sync_service.dart';
import '../services/database_helper.dart';
import 'package:logger/logger.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ada_app/repositories/equipo_pendiente_repository.dart';

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

class RequestDeleteConfirmationEvent extends UIEvent {}

class SyncCompletedEvent extends UIEvent {
  final SyncResult result;
  SyncCompletedEvent(this.result);
}

// ========== DATOS PUROS (SIN UI) ==========
class SyncInfo {
  final int estimatedClients;
  final int estimatedEquipments;
  final String serverUrl;

  SyncInfo({
    required this.estimatedClients,
    required this.estimatedEquipments,
    required this.serverUrl,
  });
}

class SyncResult {
  final bool success;
  final int clientsSynced;
  final int equipmentsSynced;
  final String message;

  SyncResult({
    required this.success,
    required this.clientsSynced,
    required this.equipmentsSynced,
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

// ========== VIEWMODEL 100% LIMPIO ==========
class SelectScreenViewModel extends ChangeNotifier {
  final Logger _logger = Logger();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // ========== ESTADO INTERNO ==========
  bool _isSyncing = false;
  bool _isTestingConnection = false;
  ConnectionStatus _connectionStatus = ConnectionStatus(
    hasInternet: false,
    hasApiConnection: false,
    statusText: 'Verificando...',
    type: ConnectionType.noInternet,
  );

  // ESTADO DEL USUARIO
  String _userFullName = 'Usuario';
  bool _isLoadingUser = true;

  // ========== STREAMS PARA COMUNICACIÓN ==========
  final StreamController<UIEvent> _eventController = StreamController<UIEvent>.broadcast();
  Stream<UIEvent> get uiEvents => _eventController.stream;

  // ========== SUBSCRIPTIONS ==========
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _apiMonitorTimer;

  // ========== GETTERS PÚBLICOS ==========
  bool get isSyncing => _isSyncing;
  bool get isTestingConnection => _isTestingConnection; // NUEVO: Getter para prueba de conexión
  ConnectionStatus get connectionStatus => _connectionStatus;
  bool get isConnected => _connectionStatus.hasInternet && _connectionStatus.hasApiConnection;

  // GETTERS DEL USUARIO
  String get userDisplayName => _userFullName;
  bool get isLoadingUser => _isLoadingUser;

  // ========== CONSTRUCTOR ==========
  SelectScreenViewModel() {
    _initializeMonitoring();
    _loadCurrentUser();
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

  // MÉTODO PARA CARGAR USUARIO DESDE SHAREDPREFERENCES Y BD
  Future<void> _loadCurrentUser() async {
    try {
      _isLoadingUser = true;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();

      // Intentar obtener el fullname directamente
      final fullName = prefs.getString('user_fullname');

      if (fullName != null && fullName.isNotEmpty) {
        _userFullName = fullName;
        _logger.i('Usuario cargado desde SharedPreferences: $fullName');
      } else {
        // Si no está el fullname, intentar obtenerlo desde la BD
        final currentUsername = prefs.getString('current_user');

        if (currentUsername != null && currentUsername.isNotEmpty) {
          final fullNameFromDB = await _getFullNameFromDatabase(currentUsername);
          if (fullNameFromDB != null && fullNameFromDB.isNotEmpty) {
            _userFullName = fullNameFromDB;
            await prefs.setString('user_fullname', fullNameFromDB);
            _logger.i('Usuario cargado desde BD: $fullNameFromDB');
          } else {
            _userFullName = currentUsername; // Usar username como fallback
            _logger.w('No se encontró fullname en BD, usando username: $currentUsername');
          }
        } else {
          _userFullName = 'Usuario';
          _logger.w('No se encontró current_user en SharedPreferences');
        }
      }
    } catch (e) {
      _logger.e('Error cargando usuario: $e');
      _userFullName = 'Usuario';
    } finally {
      _isLoadingUser = false;
      notifyListeners();
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
        serverUrl: conexion.mensaje,
      );

      // Solicitar confirmación a la UI
      _eventController.add(RequestSyncConfirmationEvent(syncInfo));
    } catch (e) {
      _eventController.add(ShowErrorEvent('Error inesperado: $e'));
    }
  }

  /// Ejecuta la sincronización (después de confirmación)
  Future<void> executeSync() async {
    _setSyncLoading(true);

    try {
      final resultado = await SyncService.sincronizarTodosLosDatos();

      final syncResult = SyncResult(
        success: resultado.exito,
        clientsSynced: resultado.clientesSincronizados,
        equipmentsSynced: resultado.equiposSincronizados,
        message: _buildSyncMessage(resultado),
      );

      if (resultado.exito) {
        _eventController.add(SyncCompletedEvent(syncResult));

        await _checkApiConnection();
      } else {
        _eventController.add(ShowErrorEvent('Error en sincronización: ${resultado.mensaje}'));
      }
    } catch (e) {
      _eventController.add(ShowErrorEvent('Error inesperado: $e'));
    } finally {
      _setSyncLoading(false);
    }
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
      _setConnectionTestLoading(false); // CAMBIO: Usar método específico para prueba
    }
  }

  /// Solicita borrar la base de datos
  Future<void> requestDeleteDatabase() async {
    _eventController.add(RequestDeleteConfirmationEvent());
  }

  /// Ejecuta el borrado de la base de datos
  Future<void> executeDeleteDatabase() async {
    _setSyncLoading(true); // CAMBIO: Usar método específico para sync (porque es una operación importante)

    try {
      final clienteRepo = ClienteRepository();
      final equipoRepo = EquipoRepository();

      // Usar métodos que realmente existen en BaseRepository
      await clienteRepo.vaciar();
      await equipoRepo.vaciar();

      // Para otras tablas, usar limpiarYSincronizar con lista vacía
      await clienteRepo.limpiarYSincronizar([]);
      await equipoRepo.limpiarYSincronizar([]);

      // Limpiar también las tablas maestras usando consultas directas
      await _dbHelper.consultarPersonalizada('DELETE FROM marcas');
      await _dbHelper.consultarPersonalizada('DELETE FROM modelos');
      await _dbHelper.consultarPersonalizada('DELETE FROM logo');
      await _dbHelper.consultarPersonalizada('DELETE FROM Users');

      _eventController.add(ShowSuccessEvent('Base de datos completa borrada correctamente'));
    } catch (e) {
      _eventController.add(ShowErrorEvent('Error al borrar la base de datos: $e'));
    } finally {
      _setSyncLoading(false); // CAMBIO: Usar método específico para sync
    }
  }

  /// Refresca manualmente el estado de conexión
  Future<void> refresh() async {
    await _checkInitialConnection();
  }

  /// Refresca la información del usuario
  Future<void> refreshUser() async {
    await _loadCurrentUser();
  }

  // ========== MÉTODOS PRIVADOS ==========

  // CAMBIO: Métodos específicos para cada tipo de loading
  void _setSyncLoading(bool loading) {
    _isSyncing = loading;
    notifyListeners();
  }

  void _setConnectionTestLoading(bool loading) {
    _isTestingConnection = loading;
    notifyListeners();
  }

  String _buildSyncMessage(dynamic resultado) {
    String mensaje = 'Sincronización completada';

    List<String> detalles = [];

    if (resultado.clientesSincronizados > 0) {
      detalles.add('Clientes: ${resultado.clientesSincronizados}');
    }

    if (resultado.equiposSincronizados > 0) {
      detalles.add('Equipos: ${resultado.equiposSincronizados}');
    }

    // NUEVO: Incluir censos en el mensaje
    if (resultado.censosSincronizados > 0) {
      detalles.add('Censos: ${resultado.censosSincronizados}');
    }

    if (resultado.asignacionesSincronizadas > 0) {
      detalles.add('Asignaciones: ${resultado.asignacionesSincronizadas}');
    }

    if (detalles.isNotEmpty) {
      mensaje += '\n• ${detalles.join('\n• ')}';
    }

    return mensaje;
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

}