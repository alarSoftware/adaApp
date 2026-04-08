import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ada_app/services/api/api_config_service.dart';
import 'package:ada_app/services/api/auth_service.dart';
import 'package:ada_app/utils/device_info_helper.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'package:ada_app/services/data/data_usage_service.dart';
import 'package:ada_app/models/notification_model.dart';
import 'dart:convert';
import 'package:ada_app/utils/logger.dart';

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

  final StreamController<NotificationModel> _notificationStreamController =
      StreamController<NotificationModel>.broadcast();
  Stream<NotificationModel> get notificationStream =>
      _notificationStreamController.stream;

  Future<void> connect({String? username, String? password}) async {
    // Prevenir conexión si el usuario hizo logout
    if (!_shouldReconnect) {
      AppLogger.w('SOCKET_SERVICE: Recomprensión deshabilitada. Saltando.');
      return;
    }

    if (_isConnecting) {
      AppLogger.i('SOCKET_SERVICE: Conexión en curso. Saltando.');
      return;
    }

    if (_client != null && _client!.connected) {
      AppLogger.i('SOCKET_SERVICE: Ya conectado. Saltando.');
      return;
    }

    _isConnecting = true;
    _shouldReconnect = true; // Habilitar reconexión para esta sesión

    try {
      // 0. Ensure previous client is deactivated
      if (_client != null) {
        AppLogger.i('SOCKET_SERVICE: Desactivando conexión previa...');
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

      // 4. Force /websocket suffix for SockJS compatibility with pure WS client
      // Although the guide says /stomp, pure WebSocket clients must use the /websocket sub-path
      if (!wsUrl.endsWith('/websocket')) {
        if (wsUrl.endsWith('/stomp')) {
          wsUrl = '$wsUrl/websocket';
        } else {
          // If it doesn't end in /stomp or /websocket, we assume /stomp/websocket
          wsUrl = '$wsUrl/stomp/websocket';
        }
      }

      AppLogger.i('SOCKET_SERVICE: 🛰️ Conectando a $wsUrl');

      // Obtener versión de la app
      String appVersion = 'unknown';
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
      } catch (e) {
        AppLogger.w('SOCKET_SERVICE: No se pudo obtener la versión de la app');
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
        AppLogger.w('SOCKET_SERVICE: No se pudieron obtener datos del usuario');
      }

      // Recolectar datos del dispositivo con TIMEOUT para evitar bloqueos (GPS puede tardar 30s)
      dynamic deviceLog;
      try {
        deviceLog = await DeviceInfoHelper.crearDeviceLog(requerirGps: false)
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                debugPrint('[WS] Device info timeout (15s). Proceeding.');
                return null;
              },
            );
      } catch (e) {
        debugPrint('[WS] Error gathering device info');
      }

      // Obtener estadísticas de uso de datos (Max y Avg)
      Map<String, dynamic> dataUsageStats = {
        'max_daily_usage': 0,
        'avg_daily_usage': 0,
      };
      try {
        dataUsageStats = await DataUsageService().getAggregatedStatistics();
      } catch (e) {
        debugPrint('[WS] Error gathering data usage stats');
      }

      _client = StompClient(
        config: StompConfig(
          url: wsUrl,
          onConnect: _onConnect,
          onWebSocketError: (dynamic error) {
            AppLogger.e('SOCKET_SERVICE: ❌ Error de WebSocket', error);
            connectionNotifier.value = false;
            _isConnecting = false;
          },
          onStompError: (StompFrame frame) {
            AppLogger.e('SOCKET_SERVICE: ❌ Error de STOMP', frame.body);
            connectionNotifier.value = false;
            _isConnecting = false;
          },
          onDisconnect: (StompFrame frame) {
            AppLogger.w('SOCKET_SERVICE: ⚠️ Desconectado');
            connectionNotifier.value = false;
            _isConnecting = false;
          },
          onDebugMessage: (String message) {
            final msg = message.trim();
            // Filtrar PING/PONG, indicadores de latido y mensajes vacíos
            if (msg.isEmpty ||
                msg == '<<<' ||
                msg == '>>>' ||
                msg.contains('PING') ||
                msg.contains('PONG')) {
              return;
            }
            AppLogger.i('SOCKET_SERVICE [STOMP]: $message');
          },
          stompConnectHeaders: {
            // MANDATORY HEADERS from guide:
            if (userId != null) 'user-id': userId,
            if (currentUsername != null) 'username': currentUsername,
            'client-type': 'mobile',

            // Re-adding optional but helpful headers
            if (username != null) 'login': username,
            if (password != null) 'passcode': password,
            'device-name': 'Celular de Ventas',
            'app-version': appVersion.toString(),
            if (employeeName != null) 'employee-name': employeeName.toString(),
            if (deviceLog != null) ...{
              'device-uuid': deviceLog.id.toString(),
              'battery': deviceLog.bateria.toString(),
              'coords': deviceLog.latitudLongitud.toString(),
              'model': deviceLog.modelo.toString(),
              'timestamp': deviceLog.fechaRegistro.toString(),
              if (deviceLog.imei != null)
                'device-imei': deviceLog.imei.toString(),
            },
            'max-daily-usage': dataUsageStats['max_daily_usage'].toString(),
            'avg-daily-usage': dataUsageStats['avg_daily_usage'].toString(),
          },
          webSocketConnectHeaders: {if (username != null) 'username': username},
          reconnectDelay: const Duration(seconds: 10),
          heartbeatOutgoing: const Duration(seconds: 10),
          heartbeatIncoming: const Duration(seconds: 10),
        ),
      );

      AppLogger.i(
        'SOCKET_SERVICE: Iniciando conexión con Headers: ${_client!.config.stompConnectHeaders}',
      );

      _client?.activate();
    } catch (e) {
      debugPrint('[WS] Critical error in connect: $e');
      _isConnecting = false;
    }
  }

  void _onConnect(StompFrame frame) {
    connectionNotifier.value = true;
    _isConnecting = false;
    AppLogger.i('SOCKET_SERVICE: ✅ Conectado exitosamente via STOMP');
    _subscribeToNotifications();
  }

  void _subscribeToNotifications() {
    if (_client == null || !_client!.connected) {
      AppLogger.w(
        'SOCKET_SERVICE: ⚠️ No se pudo suscribir, cliente no conectado',
      );
      return;
    }

    AppLogger.i('SOCKET_SERVICE: Suscribiendo a canales de notificación...');

    // 1. Suscripción en tiempo real (Broadcast)
    _client?.subscribe(
      destination: '/topic/notifications',
      callback: (frame) {
        AppLogger.i(
          'SOCKET_SERVICE: 📩 Mensaje recibido en /topic/notifications',
        );
        _handleNotification(frame);
      },
    );

    // 2. Suscripción a mensajes pendientes (User specific queue)
    _client?.subscribe(
      destination: '/user/queue/notifications',
      callback: (frame) {
        AppLogger.i(
          'SOCKET_SERVICE: 📩 Mensaje recibido en /user/queue/notifications',
        );
        _handleNotification(frame);
      },
    );

    AppLogger.i('SOCKET_SERVICE: ✅ Suscripciones completadas');
  }

  void _handleNotification(StompFrame frame) {
    if (frame.body == null) {
      AppLogger.w('SOCKET_SERVICE: Recibido frame STOMP sin cuerpo');
      return;
    }

    // LOG DE INVESTIGACIÓN: Muestra exactamente qué llegó del servidor
    print('-----------------------------------------');
    print('[NOTIF_DEBUG] LLEGÓ MENSAJE DEL SOCKET:');
    print(frame.body);
    print('-----------------------------------------');

    AppLogger.i('SOCKET_SERVICE: Procesando mensaje: ${frame.body}');

    try {
      final decodedBody = jsonDecode(frame.body!);
      final notification = NotificationModel.fromJson(decodedBody);
      AppLogger.i(
        'SOCKET_SERVICE: Notificación parseada: ${notification.title}',
      );
      _notificationStreamController.add(notification);
    } catch (e) {
      AppLogger.e('SOCKET_SERVICE: Error parseando notificación', e);
    }
  }

  /// Envía un acuse de recibo al servidor para una notificación específica
  void acknowledgeNotification(int notificationId, String userId) {
    if (_client == null || !_client!.connected) {
      debugPrint('[WS] Cannot ACK: Client not connected');
      return;
    }

    final body = jsonEncode({'id': notificationId, 'userId': userId});

    debugPrint('[WS] Sending ACK for notification $notificationId');

    _client?.send(destination: '/app/notification/received', body: body);
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

  void dispose() {
    _notificationStreamController.close();
  }
}
