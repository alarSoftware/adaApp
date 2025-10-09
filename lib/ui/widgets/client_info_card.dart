import 'package:flutter/material.dart';
import 'package:ada_app/models/cliente.dart';
import 'package:ada_app/ui/theme/colors.dart';

/// Widget reutilizable para mostrar información del cliente en un card
class ClientInfoCard extends StatelessWidget {
  final Cliente cliente;
  final String? title;
  final List<ClientInfoRow>? additionalInfo;
  final EdgeInsets? padding;
  final bool showDefaultInfo;

  const ClientInfoCard({
    super.key,
    required this.cliente,
    this.title,
    this.additionalInfo,
    this.padding,
    this.showDefaultInfo = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border),
      ),
      elevation: 2,
      child: Padding(
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0), // <- Cambia aquí
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título opcional
            if (title != null) ...[
              Text(
                title!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 8),
            ],

            // Espacio superior (igual que en el código original)
            SizedBox(height: 8),

            // Nombre del cliente
            Text(
              cliente.nombre,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),

            // Propietario
            if (showDefaultInfo) ...[
              SizedBox(height: 4),
              Text(
                cliente.propietario,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],

            // Información adicional
            if (additionalInfo != null && additionalInfo!.isNotEmpty) ...[
              SizedBox(height: 12),
              ...additionalInfo!.map((info) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildInfoRow(info),
              )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(ClientInfoRow info) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (info.icon != null) ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.neutral300,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(info.icon, size: 20, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (info.label != null) ...[
                Text(
                  info.label!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
              ],
              Text(
                info.value,
                style: TextStyle(
                  fontSize: info.label != null ? 16 : 14,
                  fontWeight: info.label != null ? FontWeight.w600 : FontWeight.normal,
                  color: AppColors.textPrimary,
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
  final IconData? icon;
  final String? label;
  final String value;

  ClientInfoRow({
    this.icon,
    this.label,
    required this.value,
  });
}