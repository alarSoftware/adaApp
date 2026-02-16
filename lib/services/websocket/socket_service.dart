import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ada_app/services/api/api_config_service.dart';
import 'package:ada_app/services/api/auth_service.dart';
import 'package:ada_app/utils/device_info_helper.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  StompClient? _client;
  final ValueNotifier<bool> connectionNotifier = ValueNotifier<bool>(false);
  bool _isConnecting = false;
  bool _shouldReconnect =
      true; // Flag para controlar reconexión después de logout

  bool get isConnected => connectionNotifier.value;

  Future<void> connect({String? username, String? password}) async {
    // Prevenir conexión si el usuario hizo logout
    if (!_shouldReconnect) {
      debugPrint('[WS] Reconnection disabled. Skipping.');
      return;
    }

    if (_isConnecting) {
      debugPrint('[WS] Already connecting. Skipping.');
      return;
    }

    if (_client != null && _client!.connected) {
      debugPrint('[WS] Already connected. Skipping.');
      return;
    }

    _isConnecting = true;
    _shouldReconnect = true; // Habilitar reconexión para esta sesión

    try {
      // 0. Ensure previous client is deactivated
      if (_client != null) {
        debugPrint('[WS] Deactivating previous connection...');
        _client?.deactivate();
        _client = null;
      }

      String baseUrlStr = (await ApiConfigService.getBaseUrl()).trim();

      // 1. Remove fragments and clean whitespace
      String cleanBase = baseUrlStr.split('#').first.split('?').first.trim();

      // 2. Aggressive protocol replacement
      String wsUrl = cleanBase;
      if (wsUrl.toLowerCase().startsWith('http://')) {
        wsUrl = 'ws://${wsUrl.substring(7)}';
      } else if (wsUrl.toLowerCase().startsWith('https://')) {
        wsUrl = 'wss://${wsUrl.substring(8)}';
      } else if (!wsUrl.toLowerCase().startsWith('ws://') &&
          !wsUrl.toLowerCase().startsWith('wss://')) {
        wsUrl = 'ws://$wsUrl';
      }

      // 3. Ensure no trailing slashes
      while (wsUrl.endsWith('/')) {
        wsUrl = wsUrl.substring(0, wsUrl.length - 1);
      }

      // 4. Force verified endpoint
      if (!wsUrl.endsWith('/stomp/websocket')) {
        if (wsUrl.endsWith('/stomp')) {
          wsUrl = '$wsUrl/websocket';
        } else {
          wsUrl = '$wsUrl/stomp/websocket';
        }
      }

      debugPrint('[WS] Connecting...');

      // Obtener versión de la app
      String appVersion = 'unknown';
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
      } catch (e) {
        debugPrint('[WS] Could not get app version');
      }

      // Obtener nombre del empleado y datos de usuario
      String? employeeName;
      String? userId;
      String? currentUsername;
      try {
        final currentUser = await AuthService().getCurrentUser();
        employeeName = currentUser?.employeeName;
        userId = currentUser?.id?.toString();
        currentUsername = currentUser?.username;
      } catch (e) {
        debugPrint('[WS] Could not get user data');
      }

      // Recolectar datos del dispositivo con TIMEOUT para evitar bloqueos (GPS puede tardar 30s)
      dynamic deviceLog;
      try {
        deviceLog = await DeviceInfoHelper.crearDeviceLog().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint('[WS] Device info timeout. Proceeding.');
            return null;
          },
        );
      } catch (e) {
        debugPrint('[WS] Error gathering device info');
      }

      _client = StompClient(
        config: StompConfig(
          url: wsUrl,
          onConnect: _onConnect,
          onWebSocketError: (dynamic error) {
            debugPrint('[WS] WebSocket Error');
            connectionNotifier.value = false;
            _isConnecting = false;
          },
          onStompError: (StompFrame frame) {
            debugPrint('[WS] STOMP Error');
            connectionNotifier.value = false;
            _isConnecting = false;
          },
          onDisconnect: (StompFrame frame) {
            debugPrint('[WS] Disconnected');
            connectionNotifier.value = false;
            _isConnecting = false;
          },
          onDebugMessage: (String message) {
            if (message.contains('CONNECTED') ||
                message.contains('CONNECT') ||
                message.contains('Error')) {
              debugPrint('[WS] STOMP event');
            }
          },
          stompConnectHeaders: {
            if (username != null) 'login': username,
            if (password != null) 'passcode': password,
            'device-name': 'Celular de Ventas',
            'client-type': 'mobile',
            'app-version': appVersion.toString(),
            if (employeeName != null) 'employee-name': employeeName.toString(),
            if (userId != null) 'user-id': userId,
            if (currentUsername != null) 'username': currentUsername,
            if (deviceLog != null) ...{
              'device-uuid': deviceLog.id.toString(),
              'battery': deviceLog.bateria.toString(),
              'coords': deviceLog.latitudLongitud.toString(),
              'model': deviceLog.modelo.toString(),
              'timestamp': deviceLog.fechaRegistro.toString(),
            },
          },
          webSocketConnectHeaders: {if (username != null) 'username': username},
          reconnectDelay: const Duration(seconds: 10),
          heartbeatOutgoing: const Duration(seconds: 10),
          heartbeatIncoming: const Duration(seconds: 10),
        ),
      );

      _client?.activate();
    } catch (e) {
      debugPrint('[WS] Critical error in connect');
      _isConnecting = false;
    }
  }

  void _onConnect(StompFrame frame) {
    connectionNotifier.value = true;
    _isConnecting = false;
    debugPrint('[WS] Connected successfully');
  }

  void disconnect() {
    _shouldReconnect = false; // Deshabilitar reconexión automática
    _client?.deactivate();
    _client = null; // Clear client on manual disconnect
    connectionNotifier.value = false;
    _isConnecting = false;
    debugPrint('[WS] Disconnected manually');
  }

  /// Habilita la reconexión (llamar antes de iniciar sesión)
  void enableReconnect() {
    _shouldReconnect = true;
    debugPrint('[WS] Reconnection enabled');
  }
}
