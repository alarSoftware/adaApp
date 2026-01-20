import 'package:flutter/material.dart';
import 'package:ada_app/models/cliente.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/ui/screens/clientes/cliente_detail_screen.dart';
import 'package:ada_app/ui/screens/dynamic_form/dynamic_form_responses_screen.dart';
import 'package:ada_app/ui/screens/operaciones_comerciales/operaciones_comerciales_menu_screen.dart';
import 'package:ada_app/ui/widgets/client_info_card.dart';
import 'package:ada_app/services/navigation/navigation_guard_service.dart';
import 'package:ada_app/services/navigation/route_constants.dart';

/// Pantalla de selección de opciones para un cliente
class ClientOptionsScreen extends StatelessWidget {
  final Cliente cliente;

  const ClientOptionsScreen({super.key, required this.cliente});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Opciones', style: TextStyle(color: AppColors.onPrimary)),
        backgroundColor: AppColors.appBarBackground,
        foregroundColor: AppColors.appBarForeground,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.containerBackground, AppColors.background],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header con información del cliente (DISEÑO CONSISTENTE)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ClientInfoCard(cliente: cliente),
              ),

              // Título de opciones
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Text(
                  '¿Qué deseas hacer?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),

              // Opciones con Permisos
              Expanded(
                child: FutureBuilder<Map<String, bool>>(
                  future: _checkNavigationPermissions(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }

                    final permissions = snapshot.data ?? {};
                    final canCreateCenso =
                        permissions[RouteConstants.serverCensos] ?? false;
                    final canCreateOperacion =
                        permissions[RouteConstants.serverOperaciones] ?? false;
                    final canViewForms =
                        permissions[RouteConstants.serverFormularios] ?? false;

                    return ListView(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _buildOptionCard(
                          context: context,
                          title: 'Operaciones Comerciales',
                          description: 'Reposiciones y retiros',
                          icon: Icons.receipt_long,
                          color: AppColors.success,
                          onTap: () =>
                              _navigateToOperacionesComerciales(context),
                          enabled: canCreateOperacion,
                        ),

                        SizedBox(height: 12),

                        _buildOptionCard(
                          context: context,
                          title: 'Realizar Censo de Equipo',
                          description:
                              'Censo de los equipos de frio del cliente',
                          icon: Icons.barcode_reader,
                          color: AppColors.primary,
                          onTap: () => _navigateToCenso(context),
                          enabled: canCreateCenso,
                        ),

                        SizedBox(height: 12),

                        _buildOptionCard(
                          context: context,
                          title: 'Formularios Dinámicos',
                          description: 'Ver historial y completar nuevos',
                          icon: Icons.assignment_turned_in,
                          color: AppColors.secondary,
                          onTap: () => _navigateToForms(context),
                          enabled: canViewForms,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Map<String, bool>> _checkNavigationPermissions() async {
    final guard = NavigationGuardService();
    // Desde Clientes (/clientes) hacia...
    final canCreateCenso = await guard.canNavigate(
      currentScreen: RouteConstants.serverClientes,
      targetScreen: RouteConstants.serverCensos,
    );
    final canCreateOperacion = await guard.canNavigate(
      currentScreen: RouteConstants.serverClientes,
      targetScreen: RouteConstants.serverOperaciones,
    );
    final canViewForms = await guard.canNavigate(
      currentScreen: RouteConstants.serverClientes,
      targetScreen: RouteConstants.serverFormularios,
    );

    return {
      RouteConstants.serverCensos: canCreateCenso,
      RouteConstants.serverOperaciones: canCreateOperacion,
      RouteConstants.serverFormularios: canViewForms,
    };
  }

  Widget _buildOptionCard({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    final effectiveColor = enabled ? color : Colors.grey;
    final contentOpacity = enabled ? 1.0 : 0.6;

    return Card(
      elevation: enabled ? 2 : 0,
      color: enabled ? AppColors.surface : Colors.grey[100],
      shadowColor: AppColors.shadowLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: enabled ? AppColors.border : Colors.grey[300]!,
          width: 0.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled
            ? onTap
            : () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'No tienes permiso para acceder a esta opción',
                    ),
                    duration: Duration(seconds: 2),
                    backgroundColor: Colors.grey[700],
                  ),
                );
              },
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Opacity(
            opacity: contentOpacity,
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: effectiveColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: effectiveColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Icon(icon, color: effectiveColor, size: 28),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: enabled ? AppColors.textPrimary : Colors.grey,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 13,
                          color: enabled
                              ? AppColors.textSecondary
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (enabled)
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppColors.textSecondary,
                  )
                else
                  Icon(Icons.lock, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToCenso(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClienteDetailScreen(cliente: cliente),
      ),
    );
  }

  void _navigateToForms(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DynamicFormResponsesScreen(cliente: cliente),
      ),
    );
  }

  void _navigateToOperacionesComerciales(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            OperacionesComercialesMenuScreen(cliente: cliente),
      ),
    );
  }
}
