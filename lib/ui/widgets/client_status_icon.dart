import 'package:flutter/material.dart';
import 'package:ada_app/ui/theme/colors.dart';

/// Widget que muestra iconos de estado para un cliente en la lista
/// Indica si ya recibió censo hoy y si tiene formularios completados
class ClientStatusIcons extends StatelessWidget {
  final bool tieneCensoHoy;
  final bool tieneFormularioCompleto;
  final double iconSize;
  final bool showTooltips;

  const ClientStatusIcons({
    super.key,
    required this.tieneCensoHoy,
    required this.tieneFormularioCompleto,
    this.iconSize = 16,
    this.showTooltips = true,
  });

  @override
  Widget build(BuildContext context) {
    // Si no hay ningún indicador, no mostrar nada
    if (!tieneCensoHoy && !tieneFormularioCompleto) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icono de censo del día
        if (tieneCensoHoy) ...[
          _buildStatusIcon(
            context: context,
            icon: Icons.fact_check,
            color: AppColors.success,
            tooltip: 'Cliente ya recibió censo hoy',
          ),
          if (tieneFormularioCompleto) const SizedBox(width: 6),
        ],

        // Icono de formulario completado
        if (tieneFormularioCompleto) ...[
          _buildStatusIcon(
            context: context,
            icon: Icons.assignment_turned_in,
            color: AppColors.primary,
            tooltip: 'Cliente tiene formulario completado',
          ),
        ],
      ],
    );
  }

  Widget _buildStatusIcon({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String tooltip,
  }) {
    Widget iconWidget = Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Icon(
        icon,
        size: iconSize,
        color: color,
      ),
    );

    if (!showTooltips) {
      return iconWidget;
    }

    return Tooltip(
      message: tooltip,
      child: iconWidget,
    );
  }
}

/// Widget mejorado para mostrar en una fila de cliente en ListView
class ClientListTile extends StatelessWidget {
  final String clienteNombre;
  final String? clienteCI;
  final String? clienteDireccion;
  final bool tieneCensoHoy;
  final bool tieneFormularioCompleto;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ClientListTile({
    super.key,
    required this.clienteNombre,
    this.clienteCI,
    this.clienteDireccion,
    required this.tieneCensoHoy,
    required this.tieneFormularioCompleto,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      color: AppColors.surface,
      shadowColor: AppColors.shadowLight,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border, width: 0.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar del cliente
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: Text(
                  clienteNombre.isNotEmpty ? clienteNombre[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Información del cliente
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clienteNombre,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (clienteCI != null && clienteCI!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.badge, size: 14, color: AppColors.textTertiary),
                          const SizedBox(width: 4),
                          Text(
                            'CI: $clienteCI',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (clienteDireccion != null && clienteDireccion!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: AppColors.textTertiary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              clienteDireccion!,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textTertiary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Iconos de estado
              ClientStatusIcons(
                tieneCensoHoy: tieneCensoHoy,
                tieneFormularioCompleto: tieneFormularioCompleto,
                iconSize: 14,
              ),

              const SizedBox(width: 8),

              // Flecha de navegación
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}