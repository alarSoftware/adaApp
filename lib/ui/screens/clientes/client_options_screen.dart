import 'package:flutter/material.dart';
import 'package:ada_app/models/cliente.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/ui/screens/clientes/cliente_detail_screen.dart';
import 'package:ada_app/ui/screens/dynamic_form/dynamic_form_responses_screen.dart';
import 'package:ada_app/ui/screens/operaciones_comerciales/operaciones_comerciales_menu_screen.dart';
import 'package:ada_app/ui/widgets/client_info_card.dart';
import 'package:ada_app/services/permissions_service.dart';

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
                  future: PermissionsService.checkPermissions([
                    'CrearCensoActivo',
                    'CrearOperacionComercial',
                    'VerFormularios',
                  ]),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }

                    final permissions = snapshot.data ?? {};
                    final canCreateCenso =
                        permissions['CrearCensoActivo'] ?? false;
                    final canCreateOperacion =
                        permissions['CrearOperacionComercial'] ?? false;
                    final canViewForms = permissions['VerFormularios'] ?? false;

                    return ListView(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        if (canCreateCenso)
                          _buildOptionCard(
                            context: context,
                            title: 'Realizar Censo de Equipo',
                            description:
                                'Censo de los equipos de frio del cliente',
                            icon: Icons.barcode_reader,
                            color: AppColors.primary,
                            onTap: () => _navigateToCenso(context),
                          ),

                        if (canCreateCenso) SizedBox(height: 12),

                        if (canCreateOperacion)
                          _buildOptionCard(
                            context: context,
                            title: 'Operaciones Comerciales',
                            description: 'Reposiciones y retiros',
                            icon: Icons.receipt_long,
                            color: AppColors.success,
                            onTap: () =>
                                _navigateToOperacionesComerciales(context),
                          ),

                        if (canCreateOperacion && canViewForms)
                          SizedBox(height: 12),

                        if (canViewForms)
                          _buildOptionCard(
                            context: context,
                            title: 'Formularios Dinámicos',
                            description: 'Ver historial y completar nuevos',
                            icon: Icons.assignment_turned_in,
                            color: AppColors.secondary,
                            onTap: () => _navigateToForms(context),
                          ),

                        if (!canCreateCenso &&
                            !canCreateOperacion &&
                            !canViewForms)
                          Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.lock_outline,
                                  size: 48,
                                  color: AppColors.textSecondary,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  "No tienes permisos habilitados para este módulo.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
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

  Widget _buildOptionCard({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      color: AppColors.surface,
      shadowColor: AppColors.shadowLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border, width: 0.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Icon(icon, color: color, size: 28),
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
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ],
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
