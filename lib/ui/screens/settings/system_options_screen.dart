import 'package:ada_app/repositories/device_log_repository.dart';
import 'package:ada_app/services/data/database_helper.dart';
import 'package:ada_app/ui/screens/device_log_screen.dart';
import 'package:ada_app/ui/screens/settings/work_hours_settings_screen.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/services/api/auth_service.dart';
import 'package:flutter/material.dart';

class SystemOptionsScreen extends StatelessWidget {
  const SystemOptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Opciones de Sistema'),
        backgroundColor: AppColors.appBarBackground,
        foregroundColor: AppColors.appBarForeground,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          _buildSectionHeader('Mantenimiento y Logs'),
          _buildOptionTile(
            context,
            icon: Icons.history,
            label: 'Device Logs',
            subtitle: 'Registro de actividad interna del dispositivo',
            onTap: () async {
              final db = await DatabaseHelper().database;
              if (context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        DeviceLogScreen(repository: DeviceLogRepository(db)),
                  ),
                );
              }
            },
          ),
          const Divider(),
          _buildSectionHeader('Configuración'),
          _buildOptionTile(
            context,
            icon: Icons.access_time,
            label: 'Horario de Trabajo',
            subtitle: 'Configurar horarios de operación',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const WorkHoursSettingsScreen(),
                ),
              );
            },
          ),
          const Divider(),
          _buildSectionHeader('Zona de Peligro'),
          _buildOptionTile(
            context,
            icon: Icons.delete_forever,
            label: 'Borrar Base de Datos',
            subtitle: 'Eliminar todos los datos locales y reiniciar',
            color: AppColors.error,
            onTap: () => _handleDeleteDatabase(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildOptionTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (color ?? AppColors.primary).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color ?? AppColors.primary, size: 24),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: color ?? AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.grey,
      ),
      onTap: onTap,
    );
  }

  Future<void> _handleDeleteDatabase(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Row(
            children: [
              Icon(Icons.delete_forever, color: AppColors.error),
              const SizedBox(width: 8),
              Text(
                'Borrar Base de Datos',
                style: TextStyle(fontSize: 20, color: AppColors.textPrimary),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¡ATENCIÓN!',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Esta acción borrará TODOS los datos locales:',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                '• Todos los clientes',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              Text(
                '• Todos los equipos',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              Text(
                '• Configuraciones locales',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Text(
                '¿Estás seguro?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancelar',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.onPrimary,
              ),
              child: const Text('Sí, Borrar Todo'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      try {
        // Mostrar indicador de carga
        if (context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) =>
                const Center(child: CircularProgressIndicator()),
          );
        }

        final dbHelper = DatabaseHelper();
        final authService = AuthService();

        // Borrar tablas principales
        await dbHelper.eliminar('clientes');
        await dbHelper.eliminar('equipos');
        await dbHelper.eliminar('equipos_pendientes');
        await dbHelper.eliminar('censo_activo');

        // Borrar tablas maestras
        await dbHelper.eliminar('marcas');
        await dbHelper.eliminar('modelos');
        await dbHelper.eliminar('logo');
        await dbHelper.eliminar('dynamic_form');
        await dbHelper.eliminar('dynamic_form_detail');
        await dbHelper.eliminar('dynamic_form_response');
        await dbHelper.eliminar('dynamic_form_response_detail');
        await dbHelper.eliminar('dynamic_form_response_image');

        // Borrar imágenes de censos
        await dbHelper.eliminar('censo_activo_foto');

        // Limpiar datos de sincronización
        await authService.clearSyncData();

        if (context.mounted) {
          // Cerrar diálogo de carga
          Navigator.pop(context);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Base de datos eliminada. Reiniciando...'),
              backgroundColor: AppColors.success,
            ),
          );

          // Navegar al Login y remover todo el historial
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false);
        }
      } catch (e) {
        if (context.mounted) {
          // Cerrar diálogo de carga si está abierto
          Navigator.pop(context);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al borrar base de datos: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }
}
