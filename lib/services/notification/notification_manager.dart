import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ada_app/models/notification_model.dart';
import 'package:ada_app/services/api/auth_service.dart';
import 'package:ada_app/services/websocket/socket_service.dart';
import 'package:ada_app/utils/logger.dart';
import 'package:ada_app/ui/widgets/app_notification.dart';
import 'package:ada_app/repositories/notification_repository.dart';

class NotificationManager {
  static final NotificationManager _instance = NotificationManager._internal();
  factory NotificationManager() => _instance;
  NotificationManager._internal();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription? _subscription;
  final NotificationRepository _repository = NotificationRepository();

  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  void initialize() {
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

  Future<void> refreshUnreadCount() async {
    unreadCount.value = await _repository.getUnreadCount();
  }

  void _handleNotification(NotificationModel notification) async {
    debugPrint(
      '[NotificationManager] Received notification: ${notification.title}',
    );

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
        _showBlockingDialog(context, notification);
        break;
      case NotificationLevel.important:
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
    }
  }

  void _showBlockingDialog(BuildContext context, NotificationModel notification) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 10),
            Expanded(child: Text(notification.title)),
          ],
        ),
        content: Text(notification.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ENTENDIDO'),
          ),
        ],
      ),
    );
  }

  void dispose() {
    _subscription?.cancel();
  }
}
