// lib/ui/screens/operaciones_comerciales/widgets/bottom_bar_widget.dart
import 'package:flutter/material.dart';
import 'package:ada_app/ui/theme/colors.dart';

/// Widget para la barra inferior con resumen y acción de guardar
/// Sigue el patrón de tus widgets existentes
class BottomBarWidget extends StatelessWidget {
  final int totalProductos;
  final bool isSaving;
  final bool isEditing;
  final VoidCallback onGuardar;

  const BottomBarWidget({
    Key? key,
    required this.totalProductos,
    required this.isSaving,
    required this.isEditing,
    required this.onGuardar,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowLight,
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Resumen
            _buildSummaryCard(),
            const SizedBox(height: 12),

            // Botón guardar
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.infoContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.shopping_cart, color: AppColors.info, size: 18),
              const SizedBox(width: 8),
              Text(
                'Total de productos:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          Text(
            '$totalProductos ${totalProductos == 1 ? 'unidad' : 'unidades'}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isSaving ? null : onGuardar,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.success,
          foregroundColor: AppColors.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: isSaving
            ? Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: AppColors.onPrimary,
                strokeWidth: 2,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Guardando...'),
          ],
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 20),
            const SizedBox(width: 8),
            Text(
              isEditing ? 'Actualizar' : 'Crear',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}