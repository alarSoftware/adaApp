import 'package:flutter/material.dart';
import 'package:ada_app/models/cliente.dart';
import 'package:ada_app/ui/theme/colors.dart';

/// Widget reutilizable para mostrar información del cliente en un card
class ClientInfoCard extends StatelessWidget {
  final Cliente cliente;
  final List<ClientInfoRow>? additionalInfo;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final bool showFullDetails; // Nueva opción para mostrar detalles completos

  const ClientInfoCard({
    super.key,
    required this.cliente,
    this.additionalInfo,
    this.padding,
    this.onTap,
    this.showFullDetails = true,
  });

  @override
  Widget build(BuildContext context) {
    final card = Card(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border),
      ),
      elevation: 2,
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Nombre con Código
            Text(
              cliente.displayName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),

            // Información básica del cliente
            if (showFullDetails) ...[
              const SizedBox(height: 12),

              // RUC/CI
              if (cliente.rucCi.isNotEmpty)
                _buildInfoRow(ClientInfoRow(
                  icon: Icons.badge_outlined,
                  label: cliente.tipoDocumento,
                  value: cliente.rucCi,
                )),

              // Condición de Venta
              if (cliente.condicionVenta != null && cliente.condicionVenta!.isNotEmpty) ...[
                const SizedBox(height: 10),
                _buildInfoRow(ClientInfoRow(
                  icon: cliente.esCredito
                      ? Icons.credit_card_outlined
                      : Icons.payments_outlined,
                  label: 'Condición de Venta',
                  value: cliente.displayCondicionVenta,
                  valueColor: cliente.esCredito
                      ? Colors.orange.shade700
                      : Colors.green.shade700,
                )),
              ],

              // Propietario
              if (cliente.propietario.isNotEmpty) ...[
                const SizedBox(height: 10),
                _buildInfoRow(ClientInfoRow(
                  icon: Icons.person_outline,
                  label: 'Propietario',
                  value: cliente.propietario,
                )),
              ],

              // Teléfono
              if (cliente.telefono.isNotEmpty) ...[
                const SizedBox(height: 10),
                _buildInfoRow(ClientInfoRow(
                  icon: Icons.phone_outlined,
                  label: 'Teléfono',
                  value: cliente.telefono,
                )),
              ],

              // Dirección
              if (cliente.direccion.isNotEmpty) ...[
                const SizedBox(height: 10),
                _buildInfoRow(ClientInfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'Dirección',
                  value: cliente.direccion,
                )),
              ],
            ],

            // Información adicional personalizada
            if (additionalInfo != null && additionalInfo!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              ...additionalInfo!.map((info) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildInfoRow(info),
              )),
            ],
          ],
        ),
      ),
    );

    // Si tiene onTap, envolver en InkWell
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: card,
      );
    }

    return card;
  }

  Widget _buildInfoRow(ClientInfoRow info) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icono con fondo
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.neutral300,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            info.icon,
            size: 16,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 10),

        // Label y valor
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label (opcional)
              if (info.label != null) ...[
                Text(
                  info.label!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
              ],

              // Valor
              Text(
                info.value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: info.valueColor ?? AppColors.textPrimary,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Clase para definir filas de información adicional
class ClientInfoRow {
  final IconData icon;
  final String? label;
  final String value;
  final Color? valueColor;

  ClientInfoRow({
    required this.icon,
    this.label,
    required this.value,
    this.valueColor,
  });
}