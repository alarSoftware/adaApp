import 'package:ada_app/models/notification_model.dart';
import 'package:ada_app/repositories/notification_repository.dart';
import 'package:ada_app/services/notification/notification_manager.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ada_app/services/api/api_config_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationRepository _repository = NotificationRepository();
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  String _activeFilter = 'todas'; // 'todas', 'criticas', 'info'

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
        _notifications = notifications.toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
        _isLoading = false;
      });
      await NotificationManager().markAllAsRead();
    }
  }

  List<NotificationModel> get _filteredList {
    if (_activeFilter == 'criticas') {
      return _notifications.where((n) => 
        n.type == NotificationLevel.blocking || 
        n.type == NotificationLevel.important).toList();
    }
    if (_activeFilter == 'info') {
      return _notifications.where((n) => 
        n.type == NotificationLevel.info || 
        n.type == NotificationLevel.unblocking).toList();
    }
    return _notifications;
  }

  List<dynamic> _getDisplayItems() {
    final List<dynamic> items = [];
    final filtered = _filteredList;
    if (filtered.isEmpty) return items;

    String? lastHeader;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (var n in filtered) {
      final date = DateTime.fromMillisecondsSinceEpoch(n.timestamp);
      final compareDate = DateTime(date.year, date.month, date.day);
      
      String header;
      if (compareDate == today) {
        header = 'Hoy';
      } else if (compareDate == yesterday) {
        header = 'Ayer';
      } else {
        header = DateFormat('d MMMM', 'es_ES').format(compareDate);
      }

      if (header != lastHeader) {
        items.add(header);
        lastHeader = header;
      }
      items.add(n);
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final displayItems = _getDisplayItems();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            'Notificaciones${_notifications.isNotEmpty ? " (${_notifications.length})" : ""}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
              tooltip: 'Borrar historial',
              onPressed: _notifications.isEmpty ? null : _confirmClearAll,
            ),
          ],
        ),
        body: Column(
          children: [
            // Filtros tipo Tabs similares a Clientes Screen
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(25),
              ),
              child: TabBar(
                onTap: (index) {
                  if (index == 0) setState(() => _activeFilter = 'todas');
                  if (index == 1) setState(() => _activeFilter = 'criticas');
                  if (index == 2) setState(() => _activeFilter = 'info');
                },
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(25),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey.shade600,
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: const [
                  Tab(text: "Todas"),
                  Tab(text: "Críticas"),
                  Tab(text: "Informativas"),
                ],
              ),
            ),

            // Content List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : displayItems.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadNotifications,
                          color: AppColors.primary,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: ListView.builder(
                              key: ValueKey(_activeFilter),
                              padding: const EdgeInsets.only(bottom: 24, top: 4),
                              itemCount: displayItems.length,
                              itemBuilder: (context, index) {
                                final item = displayItems[index];

                                if (item is String) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 16, bottom: 8, left: 24, right: 24),
                                    child: Text(
                                      item,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  );
                                }

                                final notification = item as NotificationModel;
                                return Dismissible(
                                  key: Key('notif_${notification.id}'),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                                    padding: const EdgeInsets.only(right: 20),
                                    decoration: BoxDecoration(
                                      color: AppColors.error,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
                                  ),
                                  onDismissed: (_) => _deleteNotification(notification.id),
                                  child: _NotificationTile(notification: notification),
                                );
                              },
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 64, color: AppColors.textTertiary),
          const SizedBox(height: 16),
          Text(
            _activeFilter == 'todas' ? 'No hay notificaciones' : 'Sin resultados',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            _activeFilter == 'todas' 
                ? 'Tu bandeja de entrada está vacía.' 
                : 'No se encontraron notificaciones en esta categoría.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Borrar historial?'),
        content: const Text('Se eliminarán todas las notificaciones guardadas.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('BORRAR TODO'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _repository.clearAll();
      _loadNotifications();
    }
  }

  Future<void> _deleteNotification(int id) async {
    await _repository.delete(id);
    if (mounted) setState(() => _notifications.removeWhere((n) => n.id == id));
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  const _NotificationTile({required this.notification});

  String _formatTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final Color accentColor;
    final IconData iconData;

    switch (notification.type) {
      case NotificationLevel.blocking: 
        accentColor = AppColors.error; 
        iconData = Icons.security_rounded; 
        break;
      case NotificationLevel.important: 
        accentColor = AppColors.warning; 
        iconData = Icons.priority_high_rounded; 
        break;
      case NotificationLevel.info: 
        accentColor = AppColors.info; 
        iconData = Icons.info_rounded; 
        break;
      case NotificationLevel.unblocking: 
        accentColor = AppColors.success; 
        iconData = Icons.check_circle_rounded; 
        break;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 2,
      color: AppColors.cardBackground,
      shadowColor: AppColors.shadowLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border, width: 0.5),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        onTap: () {
          if (notification.blockingUrl != null && notification.blockingUrl!.isNotEmpty) {
            NotificationManager().executeAction(context, notification);
          }
        },
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10), // Esquinas redondeadas suaves
          ),
          child: Icon(iconData, color: accentColor, size: 24),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                notification.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatTime(notification.timestamp),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notification.message,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              if (notification.blockingUrl != null && notification.blockingUrl!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      _buildCompactAction(context, notification.blockingUrl!),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactAction(BuildContext context, String url) {
    final bool isWhatsApp = url.contains('wa.me') || url.contains('wa.link');
    final bool isApk = ApiConfigService.isApkUrl(url);

    final IconData actionIcon = isWhatsApp
        ? Icons.chat_rounded
        : (isApk ? Icons.system_update_rounded : Icons.open_in_new_rounded);

    final String actionLabel = isWhatsApp
        ? 'Contactar Soporte'
        : (isApk ? 'Instalar Actualización' : 'Abrir Enlace');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(actionIcon, size: 16, color: AppColors.secondary),
          const SizedBox(width: 6),
          Text(
            actionLabel,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }
}
