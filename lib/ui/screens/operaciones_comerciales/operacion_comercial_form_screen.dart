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

class OperacionComercialFormScreen extends StatelessWidget {
  final Cliente cliente;
  final TipoOperacion tipoOperacion;
  final OperacionComercial? operacionExistente;
  final bool isViewOnly; // 👈 NUEVO: Parámetro explícito

  const OperacionComercialFormScreen({
    Key? key,
    required this.cliente,
    required this.tipoOperacion,
    this.operacionExistente,
    this.isViewOnly = false, // 👈 NUEVO: Por defecto falso (modo edición/creación)
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => vm.OperacionComercialFormViewModel(
        cliente: cliente,
        tipoOperacion: tipoOperacion,
        operacionExistente: operacionExistente,
        isViewOnly: isViewOnly, // 👈 Pasamos el modo al ViewModel
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

        // Bloqueo de botón atrás solo si hay cambios y NO es modo lectura
        return PopScope(
          canPop: viewModel.isViewOnly || !viewModel.isFormDirty,
          onPopInvoked: (didPop) async {
            if (!didPop && !viewModel.isViewOnly && viewModel.isFormDirty) {
              final shouldPop = await _handleBackNavigation(viewModel);
              if (shouldPop && mounted) {
                Navigator.of(context).pop();
              }
            }
          },
          child: Scaffold(
            backgroundColor: const Color(0xFFF8F9FC),
            appBar: _buildAppBar(viewModel),
            body: _buildBody(viewModel),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(vm.OperacionComercialFormViewModel viewModel) {
    return AppBar(
      // Cambiamos el título según el modo
      title: Text(
        viewModel.isViewOnly
            ? 'Detalle de Operación'
            : 'Crear ${viewModel.tipoOperacion.displayName}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      backgroundColor: AppColors.appBarBackground,
      foregroundColor: AppColors.appBarForeground,
      elevation: 0,
      centerTitle: true,
    );
  }

  Widget _buildBody(vm.OperacionComercialFormViewModel viewModel) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cliente siempre visible
                    _buildClienteInfo(viewModel),
                    const SizedBox(height: 20),

                    // 1️⃣ Fecha de Retiro
                    if (viewModel.tipoOperacion.necesitaFechaRetiro) ...[
                      // Usamos IgnorePointer para bloquear clicks en modo lectura
                      IgnorePointer(
                        ignoring: viewModel.isViewOnly,
                        child: _buildFechaRetiroField(viewModel),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // 2️⃣ Buscador: LO OCULTAMOS SI ES SOLO LECTURA
                    if (!viewModel.isViewOnly) ...[
                      BuscadorProductosWidget(
                        searchQuery: viewModel.searchQuery,
                        productosFiltrados: viewModel.productosFiltrados,
                        productosSeleccionados: viewModel.productosSeleccionados,
                        onSearchChanged: viewModel.setSearchQuery,
                        onClearSearch: viewModel.clearSearch,
                        onProductoSelected: viewModel.agregarProducto,
                      ),
                      const SizedBox(height: 20),
                    ],

                    // 3️⃣ Lista de productos
                    // Aquí usamos IgnorePointer para evitar eliminar/editar items
                    IgnorePointer(
                      ignoring: viewModel.isViewOnly,
                      child: ProductosSeleccionadosWidget(
                        productosSeleccionados: viewModel.productosSeleccionados,
                        tipoOperacion: viewModel.tipoOperacion,
                        onEliminarProducto: viewModel.isViewOnly ? (_) {} : viewModel.eliminarProducto,
                        onActualizarCantidad: viewModel.isViewOnly ? (_, __) {} : viewModel.actualizarCantidadProducto,
                        onSeleccionarReemplazo: viewModel.isViewOnly ? (_, __) {} : (index, detalle) =>
                            _seleccionarProductoReemplazo(viewModel, index, detalle),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 4️⃣ Observaciones
                    IgnorePointer(
                      ignoring: viewModel.isViewOnly,
                      child: ObservacionesWidget(
                        observaciones: viewModel.observaciones,
                        onObservacionesChanged: viewModel.setObservaciones,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 🚫 BARRA INFERIOR: Solo se muestra si NO es solo lectura
            if (!viewModel.isViewOnly)
              BottomBarWidget(
                totalProductos: viewModel.totalProductos,
                isSaving: viewModel.isSaving,
                isEditing: false, // Ya no es edición, es creación única
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
          padding: const EdgeInsets.all(4),
        ),
      ),
    );
  }

  Widget _buildFechaRetiroField(vm.OperacionComercialFormViewModel viewModel) {
    final isError = !viewModel.isViewOnly && viewModel.fechaRetiro == null;

    // Color más apagado si es solo lectura
    final containerColor = viewModel.isViewOnly ? Colors.grey.shade100 : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Fecha de Retiro',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            if (!viewModel.isViewOnly)
              Text(' *', style: TextStyle(color: AppColors.error, fontSize: 16)),
          ],
        ),
        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: containerColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: viewModel.isViewOnly ? [] : [ // Sin sombra en lectura
              BoxShadow(
                color: isError ? AppColors.error.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: isError ? AppColors.error : Colors.transparent,
              width: isError ? 1.5 : 1,
            ),
          ),
          child: InkWell(
            // Bloqueamos el tap aquí también por seguridad
            onTap: viewModel.isViewOnly ? null : () => _seleccionarFechaRetiro(viewModel),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isError
                        ? AppColors.error.withOpacity(0.1)
                        : AppColors.primary.withOpacity(viewModel.isViewOnly ? 0.05 : 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.calendar_today_rounded,
                    color: viewModel.isViewOnly
                        ? Colors.grey
                        : (isError ? AppColors.error : AppColors.primary),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        viewModel.fechaRetiro == null
                            ? 'Sin fecha definida'
                            : DateFormat('dd/MM/yyyy').format(viewModel.fechaRetiro!),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: viewModel.isViewOnly
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                        ),
                      ),
                      if (isError)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Requerido',
                            style: TextStyle(fontSize: 12, color: AppColors.error),
                          ),
                        ),
                    ],
                  ),
                ),
                if (!viewModel.isViewOnly) // Solo mostramos flecha si se puede editar
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: AppColors.textSecondary.withOpacity(0.5),
                    size: 16,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _seleccionarFechaRetiro(vm.OperacionComercialFormViewModel viewModel) async {
    if (viewModel.isViewOnly) return; // Doble chequeo

    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final manana = hoy.add(const Duration(days: 1));
    final fechaActual = viewModel.fechaRetiro ?? manana;
    // La fecha mínima es mañana (hoy está deshabilitado)
    final firstDate = manana;

    final fechaSeleccionada = await showDatePicker(
      context: context,
      initialDate: fechaActual.isBefore(manana) ? manana : fechaActual,
      firstDate: firstDate,
      lastDate: DateTime(ahora.year + 1),
      locale: const Locale('es', 'ES'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
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

  Future<void> _guardarOperacion(vm.OperacionComercialFormViewModel viewModel) async {
    if (!_formKey.currentState!.validate()) {
      AppNotification.show(
        context,
        message: 'Por favor revisa los campos marcados',
        type: NotificationType.error,
      );
      return;
    }

    final success = await viewModel.guardarOperacion();
    if (!mounted) return;

    if (success) {
      AppNotification.show(
        context,
        message: 'Operación guardada correctamente',
        type: NotificationType.success,
      );
      Navigator.pop(context, true);
    }
  }

  Future<bool> _handleBackNavigation(vm.OperacionComercialFormViewModel viewModel) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            const SizedBox(width: 12),
            const Text('Cambios sin guardar'),
          ],
        ),
        content: const Text(
          'Tienes cambios que no se han guardado. ¿Estás seguro que quieres salir?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
            ),
            child: const Text('Salir sin guardar'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ✅ VERSIÓN CORREGIDA: Método para seleccionar reemplazo
  Future<void> _seleccionarProductoReemplazo(
      vm.OperacionComercialFormViewModel viewModel,
      int index,
      dynamic detalle,
      ) async {
    if (viewModel.isViewOnly) return; // No permitir en modo solo lectura

    // Crear un objeto Producto temporal para usar con el ViewModel
    final productoOriginal = Producto(
      id: detalle.productoId,
      codigo: detalle.productoCodigo,
      nombre: detalle.productoDescripcion,
      categoria: detalle.productoCategoria,
    );

    // Obtener productos de reemplazo usando el método correcto
    final productosReemplazo = await viewModel.obtenerProductosReemplazo(productoOriginal);

    if (!mounted) return;

    if (productosReemplazo.isEmpty) {
      AppNotification.show(
        context,
        message: 'No hay productos de reemplazo disponibles',
        type: NotificationType.info,
      );
      return;
    }

    // Mostrar modal de selección
    final productoSeleccionado = await showModalBottomSheet<Producto>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Seleccionar Reemplazo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Productos de la misma categoría disponibles',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: productosReemplazo.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final producto = productosReemplazo[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.inventory_2,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      title: Text(
                        producto.nombre ?? 'Sin nombre',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            'Código: ${producto.codigo ?? 'N/A'}',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios,
                        color: AppColors.primary,
                        size: 16,
                      ),
                      onTap: () => Navigator.pop(context, producto),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (productoSeleccionado != null) {
      viewModel.seleccionarProductoReemplazo(index, productoSeleccionado);
    }
  }
}