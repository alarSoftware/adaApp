// viewmodels/select_screen_view_model.dart
import 'package:flutter/foundation.dart';
import 'package:ada_app/repositories/cliente_repository.dart';
import 'package:ada_app/repositories/equipo_repository.dart';
import '../services/sync/sync_service.dart';
import '../services/api_service.dart';
import 'package:logger/logger.dart';
import '../repositories/models_repository.dart';
import '../repositories/logo_repository.dart';
import '../models/usuario.dart'; // ← Usar tu modelo Usuario
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // ========== ESTADO INTERNO ==========
  bool _isSyncing = false;
  ConnectionStatus _connectionStatus = ConnectionStatus(
    hasInternet: false,
    hasApiConnection: false,
    statusText: 'Verificando...',
    type: ConnectionType.noInternet,
  );

  // ← ESTADO DEL USUARIO
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
  ConnectionStatus get connectionStatus => _connectionStatus;
  bool get isConnected => _connectionStatus.hasInternet && _connectionStatus.hasApiConnection;

  // ← GETTERS DEL USUARIO
  String get userDisplayName => _userFullName;
  bool get isLoadingUser => _isLoadingUser;

  // ========== CONSTRUCTOR ==========
  SelectScreenViewModel() {
    _initializeMonitoring();
    _loadCurrentUser(); // ← Cargar usuario al inicializar
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

  // ← MÉTODO PARA CARGAR USUARIO DESDE SHAREDPREFERENCES Y BD
  Future<void> _loadCurrentUser() async {
    try {
      _isLoadingUser = true;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();

      // DEBUGGING: Ver todas las keys guardadas
      final keys = prefs.getKeys();
      _logger.i('🔍 TODAS LAS KEYS EN SHAREDPREFERENCES: $keys');

      // Primero intentar obtener el fullname directamente
      final fullName = prefs.getString('user_fullname');

      if (fullName != null && fullName.isNotEmpty) {
        _userFullName = fullName;
        _logger.i('✅ Usuario cargado desde SharedPreferences: $fullName');
      } else {
        // Si no está el fullname, intentar obtenerlo usando el current_user (username)
        final currentUsername = prefs.getString('current_user');
        _logger.i('🔍 Buscando fullname para username: $currentUsername');

        if (currentUsername != null && currentUsername.isNotEmpty) {
          // TEMPORAL: Mapeo hardcodeado para testing
          String? tempFullName;
          if (currentUsername == 'rrebollo') {
            tempFullName = 'Ronaldo Rebollo';
          }
          // Aquí puedes agregar más mapeos si tienes otros usuarios

          if (tempFullName != null) {
            _userFullName = tempFullName;
            // Guardarlo para la próxima vez
            await prefs.setString('user_fullname', tempFullName);
            _logger.i('✅ Usuario cargado (temporal): $tempFullName');
          } else {
            // Aquí necesitamos buscar en la base de datos local
            final fullNameFromDB = await _getFullNameFromDatabase(currentUsername);
            if (fullNameFromDB != null && fullNameFromDB.isNotEmpty) {
              _userFullName = fullNameFromDB;
              // Guardarlo para la próxima vez
              await prefs.setString('user_fullname', fullNameFromDB);
              _logger.i('✅ Usuario cargado desde BD: $fullNameFromDB');
            } else {
              _userFullName = 'Usuario';
              _logger.w('❌ No se encontró fullname en BD para: $currentUsername');
            }
          }
        } else {
          _userFullName = 'Usuario';
          _logger.w('❌ No se encontró current_user en SharedPreferences');
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

  // ← NUEVO MÉTODO: Obtener fullname desde la base de datos
  Future<String?> _getFullNameFromDatabase(String username) async {
    try {
      // Necesitarás ajustar esto según tu implementación de base de datos
      // Por ejemplo, usando sqflite:

      // final db = await database; // Tu instancia de base de datos
      // final List<Map<String, dynamic>> maps = await db.query(
      //   'usuarios', // nombre de tu tabla
      //   where: 'username = ?',
      //   whereArgs: [username],
      // );

      // if (maps.isNotEmpty) {
      //   final usuario = Usuario.fromMap(maps.first);
      //   return usuario.fullname;
      // }

      // POR AHORA: Método temporal - puedes reemplazar esto
      _logger.i('🔍 Buscando en BD el fullname para: $username');

      // TODO: Implementar búsqueda real en base de datos
      // Por ahora retornamos null para que uses la Opción 2
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
    _setLoading(true);

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
        await _checkApiConnection(); // Actualizar estado de conexión
      } else {
        _eventController.add(ShowErrorEvent('Error en sincronización: ${resultado.mensaje}'));
      }
    } catch (e) {
      _eventController.add(ShowErrorEvent('Error inesperado: $e'));
    } finally {
      _setLoading(false);
    }
  }

  /// Prueba la conexión manualmente
  Future<void> testConnection() async {
    _setLoading(true);

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
      _setLoading(false);
    }
  }

  /// Prueba la API de clientes
  Future<void> testAPI() async {
    _setLoading(true);

    try {
      _logger.i('🔍 INICIANDO TEST DE CLIENTES...');

      final resultado = await ApiService.obtenerTodosLosClientes();

      _logger.i('🔍 RESULTADO:');
      _logger.i('Éxito: ${resultado.exito}');
      _logger.i('Total clientes: ${resultado.clientes.length}');
      _logger.i('Mensaje: ${resultado.mensaje}');

      // Log de primeros 5 clientes
      for (int i = 0; i < resultado.clientes.length && i < 5; i++) {
        _logger.i('Cliente ${i + 1}: ${resultado.clientes[i].nombre}');
      }

      _eventController.add(
          ShowSuccessEvent('Test completado: ${resultado.clientes.length} clientes recibidos')
      );
    } catch (e) {
      _logger.e('❌ Error en test: $e');
      _eventController.add(ShowErrorEvent('Error en test: $e'));
    } finally {
      _setLoading(false);
    }
  }

  /// Solicita borrar la base de datos
  Future<void> requestDeleteDatabase() async {
    _eventController.add(RequestDeleteConfirmationEvent());
  }

  /// Ejecuta el borrado de la base de datos
  Future<void> executeDeleteDatabase() async {
    _setLoading(true);

    try {
      final clienteRepo = ClienteRepository();
      final equipoRepo = EquipoRepository();
      final modeloRepo = ModeloRepository();
      final logoRepo = LogoRepository();

      await clienteRepo.limpiarYSincronizar([]);
      await equipoRepo.limpiarYSincronizar([]);
      await modeloRepo.borrarTodos();
      await logoRepo.borrarTodos();

      _eventController.add(ShowSuccessEvent('Base de datos completa borrada correctamente'));
    } catch (e) {
      _eventController.add(ShowErrorEvent('Error al borrar la base de datos: $e'));
    } finally {
      _setLoading(false);
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
  void _setLoading(bool loading) {
    _isSyncing = loading;
    notifyListeners();
  }

  String _buildSyncMessage(dynamic resultado) {
    String mensaje = 'Sincronización completada';
    if (resultado.clientesSincronizados > 0 || resultado.equiposSincronizados > 0) {
      mensaje += '\n• Clientes: ${resultado.clientesSincronizados}';
      mensaje += '\n• Equipos: ${resultado.equiposSincronizados}';
    }
    return mensaje;
  }

  Future<int> _getEstimatedClients() async {
    try {
      return 0; // Implementar según tu lógica
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getEstimatedEquipments() async {
    try {
      return 0; // Implementar según tu lógica
    } catch (e) {
      return 0;
    }
  }
}