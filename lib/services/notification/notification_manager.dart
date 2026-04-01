import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:ada_app/models/notification_model.dart';
import 'package:ada_app/services/api/auth_service.dart';
import 'package:ada_app/services/websocket/socket_service.dart';
import 'package:ada_app/utils/logger.dart';
import 'package:ada_app/ui/widgets/app_notification.dart';
import 'package:ada_app/repositories/notification_repository.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ada_app/ui/widgets/blocking_notification_dialog.dart';
import 'package:ada_app/utils/device_info_helper.dart';
import 'package:package_info_plus/package_info_plus.dart';

class NotificationManager {
  static final NotificationManager _instance = NotificationManager._internal();
  factory NotificationManager() => _instance;
  NotificationManager._internal();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription? _subscription;
  final NotificationRepository _repository = NotificationRepository();
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);
  Route? _blockingRoute;
  static const String _keyIsBlocked = 'is_app_blocked';
  static const String _keyBlockedNotification = 'blocked_notification_data';

  Future<void> initialize() async {
    // Inicializar notificaciones locales
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    await _localNotifications.initialize(initializationSettings);

    // Crear canal de importancia alta para notificaciones importantes
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'important_notifications',
      'Notificaciones Importantes',
      description: 'Canal para notificaciones que requieren atención inmediata',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    _subscription?.cancel();
    _subscription = SocketService().notificationStream.listen((notification) {
      AppLogger.i(
        'NOTIFICATION_MANAGER: 🔉 Notificación recibida del stream: ${notification.title}',
      );
      _handleNotification(notification);
    });
    refreshUnreadCount();
    AppLogger.i(
      'NOTIFICATION_MANAGER: 🚀 Inicializado y escuchando stream de SocketService',
    );
  }

  Future<void> _checkTarget(NotificationModel notification) async {
    final currentUser = await AuthService().getCurrentUser();
    if (currentUser == null) {
      AppLogger.w('NOTIFICATION_MANAGER: No hay usuario autenticado para verificar destino');
      throw 'No hay usuario autenticado';
    }

    final currentId = currentUser.id?.toString();
    final currentUsername = currentUser.username.toLowerCase();
    final currentEmployeeId = currentUser.employeeId?.toLowerCase();
    
    // Obtener datos de hardware/versión para validación cruzada
    final String currentAndroidId = await DeviceInfoHelper.obtenerIdUnicoDispositivo() ?? '';
    final packageInfo = await PackageInfo.fromPlatform();
    final String currentVersion = packageInfo.version;

    bool isForMe = false;

    // 1. Si es para todos, se acepta siempre
    // Soporta tanto target: "all" (String) como target: ["all"] (List)
    if (notification.target == null || 
        notification.target == "all" ||
        (notification.target is List && (notification.target as List).map((e) => e.toString().toLowerCase()).contains("all"))) {
      isForMe = true;
    } 
    // 2. Si hay configuración detallada por canales (targetConfig), esta tiene prioridad
    else if (notification.targetConfig != null && notification.targetConfig!.isNotEmpty) {
      // Buscar si ALGUNA de las configuraciones me incluye
      for (final config in notification.targetConfig!) {
        final configValue = config.username.toLowerCase();
        
        // Match por Usuario/Employee
        bool matchUser = configValue == currentUsername || 
                         configValue == currentId || 
                         configValue == currentEmployeeId;
        
        // Match por IMEI (Android ID)
        bool matchHardware = config.imei?.toLowerCase() == currentAndroidId.toLowerCase() ||
                            (config.type == 'IMEI' && configValue == currentAndroidId.toLowerCase());
        
        // Match por Versión
        bool matchVersion = config.appVersion == currentVersion ||
                           (config.type == 'VERSION' && configValue == currentVersion);

        if (matchUser || matchHardware || matchVersion) {
          isForMe = true;
          AppLogger.i('NOTIFICATION_MANAGER: ✅ Match encontrado en targetConfig: '
              '[Type: ${config.type}, Value: $configValue]');
          break;
        }
      }
    } 
    // 3. Fallback: Lógica de lista simple (el comportamiento anterior + Hardware/Version)
    if (!isForMe) {
      if (notification.target is List) {
        final targets = (notification.target as List)
            .map((e) => e.toString().toLowerCase())
            .toList();
        
        isForMe = targets.contains(currentId) || 
                  targets.contains(currentUsername) || 
                  targets.contains(currentEmployeeId) ||
                  targets.contains(currentAndroidId.toLowerCase()) ||
                  targets.contains(currentVersion);
      } else {
        final targetStr = notification.target.toString().toLowerCase();
        isForMe = targetStr == currentId || 
                  targetStr == currentUsername || 
                  targetStr == currentEmployeeId ||
                  targetStr == currentAndroidId.toLowerCase() ||
                  targetStr == currentVersion;
      }
    }

    if (!isForMe) {
      AppLogger.i(
        'NOTIFICATION_MANAGER: Notificación rechazada. '
        'Usuario actual: [ID: $currentId, Username: $currentUsername, EmployeeId: $currentEmployeeId]',
      );
      throw 'Notificación no destinada a este usuario o canal';
    }
    
    AppLogger.i('NOTIFICATION_MANAGER: ✅ Notificación aceptada para el usuario $currentUsername');
  }

  Future<void> refreshUnreadCount() async {
    unreadCount.value = await _repository.getUnreadCount();
  }

  void _handleNotification(NotificationModel notification) async {
    debugPrint(
      '[NotificationManager] Received notification: ${notification.title}',
    );

    // 0. Verificar Target
    try {
      await _checkTarget(notification);
    } catch (e) {
      debugPrint('[NotificationManager] $e');
      return;
    }

    // 1. Persistir en base de datos
    await _repository.insert(notification);
    refreshUnreadCount();

    final context = navigatorKey.currentContext;
    if (context == null) {
      debugPrint(
        '[NotificationManager] Context is null, cannot show notification',
      );
      return;
    }

    // 2. Mostrar la notificación según el nivel
    _showUI(context, notification);

    // 3. Enviar ACK al servidor
    final currentUser = await AuthService().getCurrentUser();
    if (currentUser?.id != null) {
      SocketService().acknowledgeNotification(
        notification.id,
        currentUser!.id.toString(),
      );
    }
  }

  Future<void> markAsRead(int id) async {
    await _repository.markAsRead(id);
    refreshUnreadCount();
  }

  Future<void> markAllAsRead() async {
    await _repository.markAllAsRead();
    refreshUnreadCount();
  }

  void _showUI(BuildContext context, NotificationModel notification) {
    switch (notification.type) {
      case NotificationLevel.blocking:
        _saveBlockingState(notification);
        _showBlockingDialog(context, notification);
        break;
      case NotificationLevel.important:
        // 1. Mostrar notificación push local (barra de sistema)
        _showLocalNotification(notification);

        // 2. Mostrar banner en la app
        AppNotification.show(
          context,
          message: '${notification.title}: ${notification.message}',
          type: NotificationType.warning, // Naranja
          duration: const Duration(seconds: 10),
          overlay: navigatorKey.currentState?.overlay,
        );
        break;
      case NotificationLevel.info:
        AppNotification.show(
          context,
          message: notification.message,
          type: NotificationType.info, // Azul
          overlay: navigatorKey.currentState?.overlay,
        );
        break;
      case NotificationLevel.unblocking:
        _clearBlockingState();
        _hideBlockingScreen();
        // Mostrar aviso de que se ha desbloqueado
        AppNotification.show(
          context,
          message: notification.message.isNotEmpty
              ? notification.message
              : 'El acceso a la aplicación ha sido restaurado.',
          type: NotificationType.success,
          overlay: navigatorKey.currentState?.overlay,
        );
        break;
    }
  }

  void _showBlockingDialog(BuildContext context, NotificationModel notification) {
    if (_blockingRoute != null) return;

    _blockingRoute = DialogRoute(
      context: context,
      barrierDismissible: false,
      builder: (context) => BlockingNotificationDialog(notification: notification),
    );

    // Navegamos al diálogo de bloqueo (modal no cancelable)
    navigatorKey.currentState?.push(_blockingRoute!);
  }

  void _hideBlockingScreen() {
    if (_blockingRoute != null) {
      navigatorKey.currentState?.removeRoute(_blockingRoute!);
      _blockingRoute = null;
    }
  }

  Future<void> _showLocalNotification(NotificationModel notification) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'important_notifications',
          'Notificaciones Importantes',
          channelDescription:
              'Canal para notificaciones que requieren atención inmediata',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );
    await _localNotifications.show(
      notification.id,
      notification.title,
      notification.message,
      platformChannelSpecifics,
    );
  }

  void dispose() {
    _subscription?.cancel();
  }

  Future<void> _saveBlockingState(NotificationModel notification) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsBlocked, true);
      await prefs.setString(_keyBlockedNotification, jsonEncode(notification.toJson()));
      AppLogger.i('NOTIFICATION_MANAGER: Estado de bloqueo persistido');
    } catch (e) {
      AppLogger.e('Error al persistir estado de bloqueo', e);
    }
  }

  Future<void> _clearBlockingState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyIsBlocked);
      await prefs.remove(_keyBlockedNotification);
      AppLogger.i('NOTIFICATION_MANAGER: Estado de bloqueo limpiado');
    } catch (e) {
      AppLogger.e('Error al limpiar estado de bloqueo', e);
    }
  }

  Future<void> checkPersistentBlock() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isBlocked = prefs.getBool(_keyIsBlocked) ?? false;

      if (isBlocked) {
        final notificationJson = prefs.getString(_keyBlockedNotification);
        if (notificationJson != null) {
          final notification = NotificationModel.fromJson(
            jsonDecode(notificationJson) as Map<String, dynamic>,
          );

          AppLogger.i('NOTIFICATION_MANAGER: Detectado bloqueo persistente. Mostrando diálogo.');
          
          // Esperamos un momento para asegurar que el Navigator esté listo
          Timer(const Duration(milliseconds: 1000), () {
            final context = navigatorKey.currentContext;
            if (context != null) {
              _showBlockingDialog(context, notification);
            } else {
              AppLogger.w('NOTIFICATION_MANAGER: No se pudo mostrar bloqueo persistente (Contexto nulo)');
            }
          });
        }
      }
    } catch (e) {
      AppLogger.e('Error al verificar bloqueo persistente', e);
    }
  }
}
