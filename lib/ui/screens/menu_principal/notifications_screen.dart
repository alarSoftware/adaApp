import 'package:ada_app/models/notification_model.dart';
import 'package:ada_app/repositories/notification_repository.dart';
import 'package:ada_app/services/notification/notification_manager.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationRepository _repository = NotificationRepository();
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final notifications = await _repository.getAll();
    if (mounted) {
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
      // Marcar todas como leídas al entrar
      await NotificationManager().markAllAsRead();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notificaciones'),
        backgroundColor: AppColors.appBarBackground,
        foregroundColor: AppColors.appBarForeground,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Borrar todas',
            onPressed: _notifications.isEmpty ? null : _confirmClearAll,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _notifications.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1, indent: 70),
                  itemBuilder: (context, index) {
                    return _NotificationTile(notification: _notifications[index]);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_outlined,
              size: 80, color: AppColors.textSecondary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'No tienes notificaciones',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Borrar todas?'),
        content: const Text(
            'Se eliminarán todas las notificaciones guardadas de forma permanente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('BORRAR TODAS'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _repository.clearAll();
      _loadNotifications();
    }
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;

  const _NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context) {
    final Color iconColor;
    final IconData iconData;

    switch (notification.type) {
      case NotificationLevel.blocking:
        iconColor = AppColors.error;
        iconData = Icons.block_flipped;
        break;
      case NotificationLevel.important:
        iconColor = AppColors.warning;
        iconData = Icons.warning_amber_rounded;
        break;
      case NotificationLevel.info:
        iconColor = AppColors.info;
        iconData = Icons.info_outline;
        break;
    }

    final date = DateTime.fromMillisecondsSinceEpoch(notification.timestamp);
    final timeStr = DateFormat('dd/MM HH:mm').format(date);

    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(iconData, color: iconColor),
      ),
      title: Text(
        notification.title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            notification.message,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            timeStr,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
        ],
      ),
      isThreeLine: true,
    );
  }
}
