// lib/ui/widgets/operaciones_comerciales/buscador_productos_widget.dart
import 'package:flutter/material.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/viewmodels/operaciones_comerciales/operacion_comercial_viewmodel.dart';

/// Widget especializado para búsqueda de productos
/// Utiliza los patrones de diseño ya establecidos en tus widgets existentes
class BuscadorProductosWidget extends StatefulWidget {
  final String searchQuery;
  final List<ProductoDisponible> productosFiltrados;
  final List<dynamic> productosSeleccionados; // OperacionComercialDetalle list
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<ProductoDisponible> onProductoSelected;

  const BuscadorProductosWidget({
    Key? key,
    required this.searchQuery,
    required this.productosFiltrados,
    required this.productosSeleccionados,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onProductoSelected,
  }) : super(key: key);

  @override
  State<BuscadorProductosWidget> createState() => _BuscadorProductosWidgetState();
}

class _BuscadorProductosWidgetState extends State<BuscadorProductosWidget> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(BuscadorProductosWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Solo actualizar si el texto cambió externamente (por ejemplo, al limpiar)
    if (widget.searchQuery != oldWidget.searchQuery &&
        _controller.text != widget.searchQuery) {
      _controller.text = widget.searchQuery;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.primary),
      ),
      child: Column(
        children: [
          _buildSearchField(context),
          if (widget.searchQuery.isNotEmpty) ...[
            if (widget.productosFiltrados.isNotEmpty) ...[
              const Divider(height: 1),
              _buildResultsList(context),
            ] else ...[
              const Divider(height: 1),
              _buildNoResults(),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: _controller,
        onChanged: widget.onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Buscar por código o descripción...',
          hintStyle: TextStyle(color: AppColors.textSecondary),
          prefixIcon: Icon(Icons.search, color: AppColors.primary),
          suffixIcon: widget.searchQuery.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.clear, color: AppColors.textSecondary),
            onPressed: widget.onClearSearch,
          )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: AppColors.background,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildResultsList(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 200),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: widget.productosFiltrados.length,
        itemBuilder: (context, index) {
          final producto = widget.productosFiltrados[index];
          final yaSeleccionado = _isProductoSeleccionado(producto.codigo);

          return ListTile(
            dense: true,
            leading: Icon(
              yaSeleccionado ? Icons.check_circle : Icons.add_circle_outline,
              color: yaSeleccionado ? AppColors.success : AppColors.primary,
              size: 20,
            ),
            title: Text(
              producto.descripcion,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            subtitle: Text(
              producto.codigo,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            enabled: !yaSeleccionado,
            onTap: () {
              if (!yaSeleccionado) {
                widget.onProductoSelected(producto);
                // Limpiar búsqueda después de seleccionar
                widget.onClearSearch();
                // Quitar el foco del TextField
                FocusScope.of(context).unfocus();
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildNoResults() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.search_off, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Text(
            'No se encontraron productos',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  bool _isProductoSeleccionado(String codigo) {
    return widget.productosSeleccionados
        .any((detalle) => detalle.productoCodigo == codigo);
  }
}