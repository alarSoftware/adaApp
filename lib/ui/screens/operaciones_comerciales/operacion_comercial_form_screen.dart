// lib/ui/screens/operaciones_comerciales/operacion_comercial_form_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:ada_app/models/cliente.dart';
import 'package:ada_app/models/producto.dart';
import 'package:ada_app/models/operaciones_comerciales/enums/tipo_operacion.dart';
import 'package:ada_app/models/operaciones_comerciales/operacion_comercial.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/ui/widgets/client_info_card.dart';
import 'package:ada_app/ui/widgets/app_notification.dart';
import 'package:ada_app/viewmodels/operaciones_comerciales/operacion_comercial_viewmodel.dart' as vm;
import 'package:ada_app/ui/widgets/operaciones_comerciales/buscador_productos_widget.dart';
import 'package:ada_app/ui/widgets/operaciones_comerciales/productos_seleccionados_widget.dart';
import 'package:ada_app/ui/widgets/bottom_bar_widget.dart';
import 'package:ada_app/ui/widgets/observaciones_widget.dart';

/// Pantalla principal del formulario de operación comercial
/// Actualizada para trabajar con la nueva estructura de productos
class OperacionComercialFormScreen extends StatelessWidget {
  final Cliente cliente;
  final TipoOperacion tipoOperacion;
  final OperacionComercial? operacionExistente;

  const OperacionComercialFormScreen({
    Key? key,
    required this.cliente,
    required this.tipoOperacion,
    this.operacionExistente,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => vm.OperacionComercialFormViewModel(
        cliente: cliente,
        tipoOperacion: tipoOperacion,
        operacionExistente: operacionExistente,
      ),
      child: const _OperacionComercialFormView(),
    );
  }
}

class _OperacionComercialFormView extends StatefulWidget {
  const _OperacionComercialFormView();

  @override
  State<_OperacionComercialFormView> createState() => _OperacionComercialFormViewState();
}

class _OperacionComercialFormViewState extends State<_OperacionComercialFormView> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Consumer<vm.OperacionComercialFormViewModel>(
      builder: (context, viewModel, child) {
        _handleViewModelStateChanges(viewModel);

        return PopScope(
          canPop: !viewModel.isFormDirty,
          onPopInvoked: (didPop) async {
            if (!didPop && viewModel.isFormDirty) {
              final shouldPop = await _handleBackNavigation(viewModel);
              if (shouldPop && mounted) {
                Navigator.of(context).pop();
              }
            }
          },
          child: Scaffold(
            appBar: _buildAppBar(viewModel),
            body: _buildBody(viewModel),
          ),
        );
      },
    );
  }

  void _handleViewModelStateChanges(vm.OperacionComercialFormViewModel viewModel) {
    if (viewModel.hasError && viewModel.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          AppNotification.show(
            context,
            message: viewModel.errorMessage!,
            type: NotificationType.error,
          );
          viewModel.clearError();
        }
      });
    }
  }

  PreferredSizeWidget _buildAppBar(vm.OperacionComercialFormViewModel viewModel) {
    return AppBar(
      title: Text(
        viewModel.operacionExistente != null
            ? 'Editar ${viewModel.tipoOperacion.displayName}'
            : 'Crear ${viewModel.tipoOperacion.displayName}',
      ),
      backgroundColor: AppColors.appBarBackground,
      foregroundColor: AppColors.appBarForeground,
      elevation: 2,
    );
  }

  Widget _buildBody(vm.OperacionComercialFormViewModel viewModel) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildClienteInfo(viewModel),
                    const SizedBox(height: 16),

                    BuscadorProductosWidget(
                      searchQuery: viewModel.searchQuery,
                      productosFiltrados: viewModel.productosFiltrados,
                      productosSeleccionados: viewModel.productosSeleccionados,
                      onSearchChanged: viewModel.setSearchQuery,
                      onClearSearch: viewModel.clearSearch,
                      onProductoSelected: viewModel.agregarProducto,
                    ),
                    const SizedBox(height: 16),

                    if (viewModel.tipoOperacion.necesitaFechaRetiro) ...[
                      _buildFechaRetiroField(viewModel),
                      const SizedBox(height: 16),
                    ],

                    ProductosSeleccionadosWidget(
                      productosSeleccionados: viewModel.productosSeleccionados,
                      tipoOperacion: viewModel.tipoOperacion,
                      onEliminarProducto: viewModel.eliminarProducto,
                      onActualizarCantidad: viewModel.actualizarCantidadProducto,
                      onSeleccionarReemplazo: (index, detalle) =>
                          _seleccionarProductoReemplazo(viewModel, index, detalle),
                    ),
                    const SizedBox(height: 16),

                    ObservacionesWidget(
                      observaciones: viewModel.observaciones,
                      onObservacionesChanged: viewModel.setObservaciones,
                    ),
                  ],
                ),
              ),
            ),

            BottomBarWidget(
              totalProductos: viewModel.totalProductos,
              isSaving: viewModel.isSaving,
              isEditing: viewModel.operacionExistente != null,
              onGuardar: () => _guardarOperacion(viewModel),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClienteInfo(vm.OperacionComercialFormViewModel viewModel) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: ClientInfoCard(
          cliente: viewModel.cliente,
          showFullDetails: false,
          padding: const EdgeInsets.all(12),
        ),
      ),
    );
  }

  Widget _buildFechaRetiroField(vm.OperacionComercialFormViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fecha de Retiro *',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _seleccionarFechaRetiro(viewModel),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(
                color: viewModel.fechaRetiro == null
                    ? AppColors.error
                    : AppColors.border,
                width: viewModel.fechaRetiro == null ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    viewModel.fechaRetiro == null
                        ? 'Seleccionar fecha'
                        : DateFormat('dd/MM/yyyy').format(viewModel.fechaRetiro!),
                    style: TextStyle(
                      fontSize: 14,
                      color: viewModel.fechaRetiro == null
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
        if (viewModel.fechaRetiro == null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.error_outline, size: 14, color: AppColors.error),
              const SizedBox(width: 4),
              Text(
                'La fecha de retiro es obligatoria',
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // EVENT HANDLERS
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _seleccionarFechaRetiro(vm.OperacionComercialFormViewModel viewModel) async {
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);

    final fechaSeleccionada = await showDatePicker(
      context: context,
      initialDate: viewModel.fechaRetiro ?? hoy,
      firstDate: hoy,
      lastDate: DateTime(ahora.year + 1, ahora.month, ahora.day),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.onPrimary,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (fechaSeleccionada != null) {
      viewModel.setFechaRetiro(fechaSeleccionada);
    }
  }

  Future<void> _seleccionarProductoReemplazo(
      vm.OperacionComercialFormViewModel viewModel,
      int index,
      dynamic detalle,
      ) async {
    // ✅ Usar el ID que ya está guardado en el detalle
    final productosReemplazo = await viewModel.getProductosReemplazo(
      detalle.productoCategoria ?? '',
      detalle.productoCodigo,
      detalle.productoId, // 👈 Usar el ID guardado directamente
    );

    if (productosReemplazo.isEmpty) {
      if (mounted) {
        AppNotification.show(
          context,
          message: 'No hay productos disponibles en la categoría ${detalle.productoCategoria}',
          type: NotificationType.warning,
        );
      }
      return;
    }

    if (!mounted) return;

    final productoSeleccionado = await showModalBottomSheet<Producto>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ProductoReemplazoModal(
        productos: productosReemplazo,
        categoriaOriginal: detalle.productoCategoria ?? '',
      ),
    );

    if (productoSeleccionado != null) {
      viewModel.setProductoReemplazo(index, productoSeleccionado);
    }
  }

  Future<void> _guardarOperacion(vm.OperacionComercialFormViewModel viewModel) async {
    if (!_formKey.currentState!.validate()) {
      AppNotification.show(
        context,
        message: 'Por favor corrige los errores en el formulario',
        type: NotificationType.error,
      );
      return;
    }

    final success = await viewModel.guardarOperacion();

    if (!mounted) return;

    if (success) {
      AppNotification.show(
        context,
        message: 'Operación guardada exitosamente',
        type: NotificationType.success,
      );
      Navigator.pop(context, true);
    }
  }

  Future<bool> _handleBackNavigation(vm.OperacionComercialFormViewModel viewModel) async {
    if (!viewModel.isFormDirty) {
      return true;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('¿Descartar cambios?'),
        content: const Text(
          'Tienes cambios sin guardar. ¿Estás seguro que deseas salir?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );

    return confirm ?? false;
  }
}

// ═══════════════════════════════════════════════════════════════════
// MODAL PARA SELECCIONAR PRODUCTO DE REEMPLAZO
// ═══════════════════════════════════════════════════════════════════

class _ProductoReemplazoModal extends StatefulWidget {
  final List<Producto> productos;
  final String categoriaOriginal;

  const _ProductoReemplazoModal({
    required this.productos,
    required this.categoriaOriginal,
  });

  @override
  State<_ProductoReemplazoModal> createState() => _ProductoReemplazoModalState();
}

class _ProductoReemplazoModalState extends State<_ProductoReemplazoModal> {
  final _searchController = TextEditingController();
  List<Producto> _productosFiltrados = [];

  @override
  void initState() {
    super.initState();
    _productosFiltrados = widget.productos;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filtrarProductos(String query) {
    setState(() {
      if (query.isEmpty) {
        _productosFiltrados = widget.productos;
      } else {
        final queryLower = query.toLowerCase();
        _productosFiltrados = widget.productos.where((producto) {
          // ✅ CORREGIDO: Usar campos que existen en la nueva estructura
          final codigo = producto.codigo?.toLowerCase() ?? '';
          final nombre = producto.nombre?.toLowerCase() ?? '';
          final codigoBarras = producto.codigoBarras?.toLowerCase() ?? '';

          return codigo.contains(queryLower) ||
              nombre.contains(queryLower) ||
              codigoBarras.contains(queryLower);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.swap_horiz,
                color: AppColors.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seleccionar Reemplazo',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Categoría: ${widget.categoriaOriginal}',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, color: AppColors.textSecondary),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Buscador
          TextField(
            controller: _searchController,
            onChanged: _filtrarProductos,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Buscar por código, nombre o código de barras...', // ✅ Actualizado
              hintStyle: TextStyle(color: AppColors.textSecondary),
              prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                icon: Icon(Icons.clear, color: AppColors.textSecondary),
                onPressed: () {
                  _searchController.clear();
                  _filtrarProductos('');
                },
              )
                  : null,
              filled: true,
              fillColor: AppColors.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),

          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Icon(
                  Icons.inventory_2,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  _productosFiltrados.length == widget.productos.length
                      ? '${widget.productos.length} productos disponibles'
                      : '${_productosFiltrados.length} de ${widget.productos.length} productos',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Lista de productos
          Expanded(
            child: _productosFiltrados.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 64,
                    color: AppColors.textSecondary.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No se encontraron productos',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Intenta con otro término de búsqueda',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: _productosFiltrados.length,
              itemBuilder: (context, index) {
                final producto = _productosFiltrados[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.pop(context, producto),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            // Icono
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.inventory_2,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Información del producto
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    producto.codigo ?? 'Sin código', // ✅ CORREGIDO: Manejar nullable
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    producto.nombre ?? 'Sin nombre', // ✅ CORREGIDO: Usar nombre en lugar de descripcion
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  // ✅ CORREGIDO: Mostrar código de barras en lugar de stock
                                  if (producto.tieneCodigoBarras) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.qr_code,
                                          size: 12,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'CB: ${producto.codigoBarras}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // Flecha
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}