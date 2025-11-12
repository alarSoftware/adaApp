import 'package:flutter/material.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/models/producto.dart';

/// Widget especializado para búsqueda de productos
class BuscadorProductosWidget extends StatefulWidget {
  final String searchQuery;
  final List<Producto> productosFiltrados;
  final List<dynamic> productosSeleccionados;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<Producto> onProductoSelected;

  const BuscadorProductosWidget({
    super.key,
    required this.searchQuery,
    required this.productosFiltrados,
    required this.productosSeleccionados,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onProductoSelected,
  });

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
          hintText: 'Buscar por código, nombre o código de barras...', // ✅ Actualizado
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
            // ✅ Usa displayName de tu modelo (funciona con la nueva estructura)
            title: Text(
              producto.displayName, // "[BEB001] Coca Cola 2L" o "Coca Cola 2L"
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            // ✅ Mejora: Muestra categoría y código de barras si están disponibles
            subtitle: _buildSubtitle(producto),
            // ✅ Solo verificar si es válido (no stock/precio que no existen)
            enabled: !yaSeleccionado && producto.isValid,
            onTap: () {
              if (!yaSeleccionado && producto.isValid) {
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

  // ✅ Actualizado: Construir subtitle solo con información disponible
  Widget _buildSubtitle(Producto producto) {
    final parts = <String>[];

    // Agregar categoría si existe
    if (producto.tieneCategoria) {
      parts.add(producto.displayCategoria);
    }

    // Agregar código de barras si existe
    if (producto.tieneCodigoBarras) {
      parts.add('CB: ${producto.codigoBarras}');
    }

    // Si no hay información adicional, mostrar el ID
    if (parts.isEmpty && producto.id != null) {
      parts.add('ID: ${producto.id}');
    }

    return Text(
      parts.join(' • '),
      style: TextStyle(
        fontSize: 11,
        color: AppColors.textSecondary,
        fontWeight: FontWeight.normal,
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

  bool _isProductoSeleccionado(String? codigo) {
    // ✅ Manejar código nullable
    if (codigo == null) return false;
    return widget.productosSeleccionados
        .any((detalle) => detalle.productoCodigo == codigo);
  }
}