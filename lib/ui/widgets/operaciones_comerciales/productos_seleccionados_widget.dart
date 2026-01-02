import 'package:flutter/material.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/models/operaciones_comerciales/enums/tipo_operacion.dart';
import 'package:ada_app/models/operaciones_comerciales/operacion_comercial_detalle.dart';
import 'package:ada_app/models/producto.dart';
import 'package:ada_app/repositories/producto_repository.dart';

class ProductosSeleccionadosWidget extends StatelessWidget {
  final List<OperacionComercialDetalle> productosSeleccionados;
  final TipoOperacion tipoOperacion;
  final Function(int) onEliminarProducto;
  final Function(int, double) onActualizarCantidad;
  final Function(int, dynamic)? onSeleccionarReemplazo;
  final bool isReadOnly;
  final ProductoRepository _productoRepository;

  ProductosSeleccionadosWidget({
    Key? key,
    required this.productosSeleccionados,
    required this.tipoOperacion,
    required this.onEliminarProducto,
    required this.onActualizarCantidad,
    this.onSeleccionarReemplazo,
    this.isReadOnly = false,
    ProductoRepository? productoRepository,
  }) : _productoRepository = productoRepository ?? ProductoRepositoryImpl(),
       super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (productosSeleccionados.isEmpty)
          _buildEmptyState()
        else
          _buildProductsList(),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.3),
          width: 2,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Sin productos agregados',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Busca productos arriba para agregarlos',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProductsList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: productosSeleccionados.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 300 + (index * 50)),
          tween: Tween(begin: 0.0, end: 1.0),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: _buildProductCard(context, index),
        );
      },
    );
  }

  Widget _buildProductCard(BuildContext context, int index) {
    final detalle = productosSeleccionados[index];
    final esDiscontinuos =
        tipoOperacion == TipoOperacion.notaRetiroDiscontinuos;

    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: esDiscontinuos
              ? AppColors.error.withValues(alpha: 0.2)
              : AppColors.border.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: esDiscontinuos
                ? AppColors.error.withValues(alpha: 0.1)
                : AppColors.shadow.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            if (esDiscontinuos)
              Container(
                height: 4,
                decoration: BoxDecoration(gradient: AppColors.errorGradient),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  FutureBuilder<Producto?>(
                    future: _productoRepository.obtenerProductoPorId(
                      detalle.productoId!,
                    ),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const SizedBox(
                          height: 60,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final producto = snapshot.data!;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildProductInfo(producto, esDiscontinuos),
                          ),
                          const SizedBox(width: 12),
                          _buildQuantityField(index, detalle),
                          if (!isReadOnly) ...[
                            const SizedBox(width: 8),
                            _buildDeleteButton(index),
                          ],
                        ],
                      );
                    },
                  ),

                  if (esDiscontinuos) ...[
                    const SizedBox(height: 16),
                    _buildExchangeSection(context, index, detalle),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductInfo(Producto producto, bool esDiscontinuos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (esDiscontinuos)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: AppColors.errorGradient,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.error.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Text(
                  'RETIRAR',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            if (esDiscontinuos) const SizedBox(width: 8),
          ],
        ),
        if (esDiscontinuos) const SizedBox(height: 6),
        RichText(
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
            children: [
              TextSpan(
                text: '[${producto.codigo ?? 'S/C'}] ',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(text: producto.nombre ?? 'Sin nombre'),
            ],
          ),
        ),
        const SizedBox(height: 4),
        if (producto.codigoBarras != null && producto.codigoBarras!.isNotEmpty)
          Row(
            children: [
              Icon(
                Icons.barcode_reader,
                size: 12,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                producto.codigoBarras!,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        if (producto.tieneCategoria || producto.tieneUnidadMedida) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              if (producto.tieneCategoria)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    producto.categoria!,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (producto.tieneCategoria && producto.tieneUnidadMedida)
                const SizedBox(width: 6),
              if (producto.tieneUnidadMedida)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    producto.displayUnidadMedida,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildQuantityField(int index, OperacionComercialDetalle detalle) {
    return Container(
      width: 70,
      decoration: BoxDecoration(
        color: isReadOnly ? Colors.grey.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isReadOnly
              ? Colors.grey.shade300
              : AppColors.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: isReadOnly
            ? []
            : [
                BoxShadow(
                  color: AppColors.shadow.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: TextFormField(
        initialValue: detalle.cantidad > 0
            ? detalle.cantidad.toInt().toString()
            : '',
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        enabled: !isReadOnly,
        decoration: InputDecoration(
          hintText: '0',
          hintStyle: TextStyle(
            color: AppColors.textTertiary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 12,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
        ),
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: isReadOnly ? AppColors.textSecondary : AppColors.textPrimary,
        ),
        onChanged: (value) {
          if (!isReadOnly) {
            final cantidad = int.tryParse(value) ?? 0;
            onActualizarCantidad(index, cantidad.toDouble());
          }
        },
        validator: (value) {
          if (isReadOnly) return null;
          final cantidad = int.tryParse(value ?? '');
          if (cantidad == null || cantidad <= 0) {
            return '';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDeleteButton(int index) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onEliminarProducto(index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.delete_outline_rounded,
            color: AppColors.error,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildExchangeSection(
    BuildContext context,
    int index,
    OperacionComercialDetalle detalle,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.warning.withValues(alpha: 0.05),
            AppColors.warning.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 1500),
                tween: Tween(begin: 0.0, end: 1.0),
                curve: Curves.easeInOut,
                builder: (context, value, child) {
                  return Transform.rotate(angle: value * 3.14159, child: child);
                },
              ),
              const SizedBox(width: 12),
              Text(
                'INTERCAMBIO',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.warning,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (detalle.productoReemplazoId == null)
            _buildSelectReplacementButton(index, detalle)
          else
            _buildReplacementInfo(index, detalle),
        ],
      ),
    );
  }

  Widget _buildSelectReplacementButton(
    int index,
    OperacionComercialDetalle detalle,
  ) {
    if (isReadOnly) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300, width: 2),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Sin producto de reemplazo',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onSeleccionarReemplazo?.call(index, detalle),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.success.withValues(alpha: 0.1),
                AppColors.success.withValues(alpha: 0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.success.withValues(alpha: 0.4),
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppColors.successGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.success.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seleccionar producto de reemplazo',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(height: 4),
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
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: AppColors.success,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReplacementInfo(int index, OperacionComercialDetalle detalle) {
    return FutureBuilder<Producto?>(
      future: _productoRepository.obtenerProductoPorId(
        detalle.productoReemplazoId!,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 60,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final productoReemplazo = snapshot.data!;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.success.withValues(alpha: 0.15),
                AppColors.success.withValues(alpha: 0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.success.withValues(alpha: 0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.success.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        children: [
                          TextSpan(
                            text: '[${productoReemplazo.codigo ?? 'S/C'}] ',
                            style: TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: productoReemplazo.nombre ?? 'Sin nombre',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (productoReemplazo.codigoBarras != null &&
                        productoReemplazo.codigoBarras!.isNotEmpty)
                      Row(
                        children: [
                          Icon(
                            Icons.barcode_reader,
                            size: 11,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            productoReemplazo.codigoBarras!,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              if (!isReadOnly)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onSeleccionarReemplazo?.call(index, detalle),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.edit_rounded,
                        color: AppColors.success,
                        size: 18,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
