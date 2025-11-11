// lib/ui/screens/operaciones_comerciales/operacion_comercial_form_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:ada_app/models/cliente.dart';
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
/// Diseño compacto y profesional restaurado
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
      behavior: HitTestBehavior.opaque, // Solo captura toques en áreas vacías
      onTap: () {
        // Ocultar el teclado al tocar fuera
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

                    // Buscador siempre visible
                    BuscadorProductosWidget(
                      searchQuery: viewModel.searchQuery,
                      productosFiltrados: viewModel.productosFiltrados,
                      productosSeleccionados: viewModel.productosSeleccionados,
                      onSearchChanged: viewModel.setSearchQuery,
                      onClearSearch: viewModel.clearSearch,
                      onProductoSelected: viewModel.agregarProducto,
                    ),
                    const SizedBox(height: 16),

                    // Fecha de retiro si es necesaria
                    if (viewModel.tipoOperacion.necesitaFechaRetiro) ...[
                      _buildFechaRetiroField(viewModel),
                      const SizedBox(height: 16),
                    ],

                    // Productos seleccionados
                    ProductosSeleccionadosWidget(
                      productosSeleccionados: viewModel.productosSeleccionados,
                      tipoOperacion: viewModel.tipoOperacion,
                      onEliminarProducto: viewModel.eliminarProducto,
                      onActualizarCantidad: viewModel.actualizarCantidadProducto,
                      onSeleccionarReemplazo: (index, detalle) =>
                          _seleccionarProductoReemplazo(viewModel, index, detalle),
                    ),
                    const SizedBox(height: 16),

                    // Observaciones
                    ObservacionesWidget(
                      observaciones: viewModel.observaciones,
                      onObservacionesChanged: viewModel.setObservaciones,
                    ),
                  ],
                ),
              ),
            ),

            // Bottom bar
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
    final productosReemplazo = await viewModel.getProductosReemplazo(
      detalle.productoCategoria ?? '',
      detalle.productoCodigo,
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

    final productoSeleccionado = await showModalBottomSheet<vm.ProductoDisponible>(
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

class _ProductoReemplazoModal extends StatelessWidget {
  final List<vm.ProductoDisponible> productos;
  final String categoriaOriginal;

  const _ProductoReemplazoModal({
    required this.productos,
    required this.categoriaOriginal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.swap_horiz,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Seleccionar Reemplazo',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Categoría: $categoriaOriginal',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: productos.length,
              itemBuilder: (context, index) {
                final producto = productos[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    leading: Icon(
                      Icons.inventory_2,
                      color: AppColors.primary,
                    ),
                    title: Text(producto.codigo),
                    subtitle: Text(producto.descripcion),
                    trailing: Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => Navigator.pop(context, producto),
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