// lib/ui/screens/operaciones_comerciales/widgets/observaciones_widget.dart
import 'package:flutter/material.dart';
import 'package:ada_app/ui/theme/colors.dart';

/// Widget para el campo de observaciones
/// Siguiendo los patrones de tus widgets existentes
class ObservacionesWidget extends StatelessWidget {
  final String observaciones;
  final ValueChanged<String> onObservacionesChanged;

  const ObservacionesWidget({
    Key? key,
    required this.observaciones,
    required this.onObservacionesChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Observaciones',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: observaciones,
          onChanged: onObservacionesChanged,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Agregar observaciones (opcional)',
            hintStyle: TextStyle(color: AppColors.textSecondary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.all(12),
          ),
          style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
        ),
      ],
    );
  }
}