// lib/ui/screens/operaciones_comerciales/widgets/productos_seleccionados_widget.dart
import 'package:flutter/material.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/models/operaciones_comerciales/enums/tipo_operacion.dart';
import 'package:ada_app/models/operaciones_comerciales/operacion_comercial_detalle.dart';

/// Widget para mostrar y manejar productos seleccionados
/// Incluye funcionalidad específica para productos discontinuos con reemplazos
class ProductosSeleccionadosWidget extends StatelessWidget {
  final List<OperacionComercialDetalle> productosSeleccionados;
  final TipoOperacion tipoOperacion;
  final Function(int) onEliminarProducto;
  final Function(int, double) onActualizarCantidad;
  final Function(int, dynamic)? onSeleccionarReemplazo;

  const ProductosSeleccionadosWidget({
    Key? key,
    required this.productosSeleccionados,
    required this.tipoOperacion,
    required this.onEliminarProducto,
    required this.onActualizarCantidad,
    this.onSeleccionarReemplazo,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Productos Seleccionados *',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),

        // Lista de productos seleccionados
        if (productosSeleccionados.isEmpty)
          _buildEmptyState()
        else
          _buildProductsList(),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
        color: AppColors.background,
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text(
            'Sin productos agregados',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Busca productos arriba para agregarlos',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProductsList() {
    return Card(
      elevation: 1,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Header de la tabla
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    'Producto',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    'Cantidad',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 40),
              ],
            ),
          ),

          // Filas de productos
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: productosSeleccionados.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: AppColors.border.withOpacity(0.5),
            ),
            itemBuilder: (context, index) {
              return _buildProductRow(context, index);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProductRow(BuildContext context, int index) {
    final detalle = productosSeleccionados[index];
    final esDiscontinuos = tipoOperacion == TipoOperacion.notaRetiroDiscontinuos;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              // Información del producto
              Expanded(
                flex: 5,
                child: _buildProductInfo(detalle, esDiscontinuos),
              ),

              const SizedBox(width: 8),

              // 👈 CAMBIO: Campo de cantidad SIEMPRE visible (incluso en discontinuos)
              _buildQuantityField(index, detalle),

              const SizedBox(width: 8),

              // Botón eliminar
              _buildDeleteButton(index),
            ],
          ),

          // Sección de intercambio para discontinuos
          if (esDiscontinuos) ...[
            const SizedBox(height: 12),
            _buildExchangeSection(context, index, detalle),
          ],
        ],
      ),
    );
  }

  Widget _buildProductInfo(OperacionComercialDetalle detalle, bool esDiscontinuos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (esDiscontinuos)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: Text(
                  'RETIRAR',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                  ),
                ),
              ),
            if (esDiscontinuos) const SizedBox(width: 6),
            Expanded(
              child: Text(
                detalle.productoDescripcion,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          detalle.productoCodigo,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
        if (detalle.productoCategoria != null) ...[
          const SizedBox(height: 2),
          Text(
            'Categoría: ${detalle.productoCategoria}',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textTertiary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuantityField(int index, OperacionComercialDetalle detalle) {
    return SizedBox(
      width: 80,
      child: TextFormField(
        initialValue: detalle.cantidad > 0 ? detalle.cantidad.toInt().toString() : '', // 👈 CAMBIO: Vacío si es 0
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          hintText: '0', // 👈 NUEVO: Placeholder
          hintStyle: TextStyle(color: AppColors.textTertiary),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
          // 👈 CAMBIO: Borde rojo si cantidad es 0
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: AppColors.error, width: 2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: AppColors.error, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        onChanged: (value) {
          final cantidad = int.tryParse(value) ?? 0;
          onActualizarCantidad(index, cantidad.toDouble());
        },
        validator: (value) {
          final cantidad = int.tryParse(value ?? '');
          if (cantidad == null || cantidad <= 0) {
            return ''; // Mostrar error visual
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDeleteButton(int index) {
    return IconButton(
      icon: Icon(Icons.delete_outline, color: AppColors.error, size: 20),
      onPressed: () => onEliminarProducto(index),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }

  Widget _buildExchangeSection(BuildContext context, int index, OperacionComercialDetalle detalle) {
    return Column(
      children: [
        // Icono de intercambio
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.swap_vert,
              color: AppColors.warning,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'INTERCAMBIO',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.warning,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Producto de reemplazo
        if (detalle.productoReemplazoCodigo == null)
          _buildSelectReplacementButton(index, detalle)
        else
          _buildReplacementInfo(index, detalle),
      ],
    );
  }

  Widget _buildSelectReplacementButton(int index, OperacionComercialDetalle detalle) {
    return InkWell(
      onTap: () => onSeleccionarReemplazo?.call(index, detalle),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.success.withOpacity(0.3),
            style: BorderStyle.solid,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.add_circle_outline, color: AppColors.success, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Seleccionar producto de reemplazo',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Debe ser de la misma categoría',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.success),
          ],
        ),
      ),
    );
  }

  Widget _buildReplacementInfo(int index, OperacionComercialDetalle detalle) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.successContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSuccess),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.success,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'NUEVO',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detalle.productoReemplazoDescripcion ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  detalle.productoReemplazoCodigo ?? '',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit, color: AppColors.primary, size: 18),
            onPressed: () => onSeleccionarReemplazo?.call(index, detalle),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}