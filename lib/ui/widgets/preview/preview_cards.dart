// ui/widgets/preview/preview_cards.dart

import 'package:flutter/material.dart';
import 'package:ada_app/models/cliente.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/ui/widgets/gps_navigation_widget.dart';

/// Card para mostrar información del cliente
class PreviewClienteCard extends StatelessWidget {
  final Cliente cliente;

  const PreviewClienteCard({super.key, required this.cliente});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      color: AppColors.surface,
      shadowColor: AppColors.shadowLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: AppColors.secondary, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Informacion del Cliente',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Divider(height: 20, color: AppColors.border),
            InfoRow(
              label: 'Nombre',
              value: cliente.nombre,
              icon: Icons.account_circle,
            ),
            InfoRow(
              label: 'Direccion',
              value: cliente.direccion,
              icon: Icons.location_on,
            ),
            InfoRow(
              label: 'Telefono',
              value: cliente.telefono,
              icon: Icons.phone,
            ),
          ],
        ),
      ),
    );
  }
}

/// Card para mostrar información del equipo/visicooler
class PreviewEquipoCard extends StatelessWidget {
  final Map<String, dynamic> datos;

  const PreviewEquipoCard({super.key, required this.datos});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      color: AppColors.surface,
      shadowColor: AppColors.shadowLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.devices, color: AppColors.primary, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Datos del Visicooler',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Divider(height: 20, color: AppColors.border),
            InfoRow(
              label: 'Codigo de Barras',
              value: datos['codigo_barras'] ?? 'No especificado',
              icon: Icons.qr_code,
            ),
            InfoRow(
              label: 'Modelo del Equipo',
              value: datos['modelo'] ?? 'No especificado',
              icon: Icons.devices,
            ),
            InfoRow(
              label: 'Logo',
              value: datos['logo'] ?? 'No especificado',
              icon: Icons.business,
            ),
            if (datos['observaciones'] != null &&
                datos['observaciones'].toString().isNotEmpty)
              InfoRow(
                label: 'Observaciones',
                value: datos['observaciones'].toString(),
                icon: Icons.note_add,
              ),
          ],
        ),
      ),
    );
  }
}

/// Card para mostrar información de ubicación y registro
class PreviewUbicacionCard extends StatelessWidget {
  final Map<String, dynamic> datos;
  final String Function(String?) formatearFecha;

  const PreviewUbicacionCard({
    super.key,
    required this.datos,
    required this.formatearFecha,
  });

  @override
  Widget build(BuildContext context) {
    final latitud = datos['latitud'];
    final longitud = datos['longitud'];
    final fechaRegistro = datos['fecha_registro'];

    final tieneUbicacion = latitud != null && longitud != null;

    return Card(
      elevation: 2,
      color: AppColors.surface,
      shadowColor: AppColors.shadowLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: AppColors.warning, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Informacion de Registro',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Divider(height: 20, color: AppColors.border),

            // Coordenadas en una sola línea con botón
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.gps_fixed,
                    size: 18,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Coordenadas GPS',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (tieneUbicacion) ...[
                          Text(
                            'Lat: ${latitud.toStringAsFixed(6)}, Lon: ${longitud.toStringAsFixed(6)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () =>
                                GPSNavigationWidget.abrirUbicacionEnMapa(
                                  context,
                                  latitud.toDouble(),
                                  longitud.toDouble(),
                                ),
                            icon: Icon(Icons.map, size: 18),
                            label: Text('Ver en Google Maps'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: BorderSide(color: AppColors.primary),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ] else
                          Text(
                            'No disponible',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Fecha y hora
            InfoRow(
              label: 'Fecha y Hora',
              value: formatearFecha(fechaRegistro?.toString()),
              icon: Icons.access_time,
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget reutilizable para mostrar una fila de información
class InfoRow extends StatelessWidget {
  final String label;
  final String? value;
  final IconData icon;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textTertiary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value ?? 'No especificado',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.visible,
                  softWrap: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Indicador de estado de sincronización para historial
class SyncStatusIndicator extends StatelessWidget {
  final String mensaje;
  final IconData icono;
  final Color color;
  final String? errorDetalle;

  const SyncStatusIndicator({
    super.key,
    required this.mensaje,
    required this.icono,
    required this.color,
    this.errorDetalle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  mensaje,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          // 🆕 Mostrar el error específico si existe
          if (errorDetalle != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: color, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      errorDetalle!,
                      style: TextStyle(
                        color: color.withValues(alpha: 0.95),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
