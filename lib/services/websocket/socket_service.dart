import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ada_app/services/api/api_config_service.dart';
import 'package:ada_app/utils/device_info_helper.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  StompClient? _client;
  final ValueNotifier<bool> connectionNotifier = ValueNotifier<bool>(false);

  bool get isConnected => connectionNotifier.value;

  Future<void> connect({String? username, String? password}) async {
    if (_client != null && _client!.connected) {
      return;
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

    print('[V8-DEBUG] WebSocket Connecting to: $wsUrl');

    _client = StompClient(
      config: StompConfig(
        url: wsUrl,
        onConnect: _onConnect,
        onWebSocketError: (dynamic error) {
          print('[V8-DEBUG] ❌ WebSocket Error: $error');
          print(
            '[V8-DEBUG] 🔄 La conexión falló. Se reintentará automáticamente en 10 segundos...',
          );
          connectionNotifier.value = false;
        },
        onStompError: (StompFrame frame) {
          print('[V8-DEBUG] ❌ STOMP Error: ${frame.body}');
          connectionNotifier.value = false;
        },
        onDisconnect: (StompFrame frame) {
          print('[V8-DEBUG] 🔌 WebSocket Disconnected');
          connectionNotifier.value = false;
        },
        onDebugMessage: (String message) {
          if (message.contains('CONNECTED') ||
              message.contains('CONNECT') ||
              message.contains('Error')) {
            print('[V8-DEBUG] 🛰️ STOMP: $message');
          }
          if (message.contains('reconnecting')) {
            print(
              '[V8-DEBUG] 🔄 Reintentando conexión WebSocket automáticamente...',
            );
          }
        },
        stompConnectHeaders: {
          if (username != null) 'login': username,
          if (password != null) 'passcode': password,
          'device-name': 'Celular de Ventas', // Identificador del dispositivo
          'client-type': 'mobile', // Tipo de cliente
        },
        webSocketConnectHeaders: {if (username != null) 'username': username},
        reconnectDelay: const Duration(seconds: 10),
        heartbeatOutgoing: const Duration(seconds: 10),
        heartbeatIncoming: const Duration(seconds: 10),
      ),
    );

    _client?.activate();
  }

  void _onConnect(StompFrame frame) {
    connectionNotifier.value = true;
    print('[V8-DEBUG] ✅ WebSocket: Connection established successfully');

    // Recolectar y enviar datos del dispositivo inmediatamente
    _sendDeviceLogData();
  }

  /// Recolecta datos del dispositivo y los envía por WebSocket
  Future<void> _sendDeviceLogData() async {
    try {
      print('[WebSocket] Recolectando datos del dispositivo...');

      // Usar el método existente de recolección
      final deviceLog = await DeviceInfoHelper.crearDeviceLog();

      if (deviceLog == null) {
        print('[WebSocket] No se pudo recolectar datos del dispositivo');
        return;
      }

      // Convertir a JSON usando el método del modelo
      final json = jsonEncode(deviceLog.toMap());

      // Enviar por WebSocket
      if (_client != null && _client!.connected) {
        _client!.send(destination: '/app/device-log', body: json);
        print('[WebSocket] ✅ Datos del dispositivo enviados');
        print('[WebSocket] JSON: $json');
      } else {
        print('[WebSocket] ⚠️ Cliente no conectado, no se enviaron datos');
      }
    } catch (e) {
      print('[WebSocket] ❌ Error enviando datos del dispositivo: $e');
    }
  }

  void disconnect() {
    _client?.deactivate();
    connectionNotifier.value = false;
    print('[V8-DEBUG] 🔌 WebSocket: Connection deactivated manually');
  }
}
