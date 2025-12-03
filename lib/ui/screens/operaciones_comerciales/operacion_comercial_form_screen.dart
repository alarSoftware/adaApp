import 'package:ada_app/services/post/operaciones_comerciales_post_service.dart';
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
import 'package:ada_app/viewmodels/operaciones_comerciales/operacion_comercial_viewmodel.dart'
    as vm;
import 'package:ada_app/ui/widgets/operaciones_comerciales/buscador_productos_widget.dart';
import 'package:ada_app/ui/widgets/operaciones_comerciales/productos_seleccionados_widget.dart';
import 'package:ada_app/ui/widgets/bottom_bar_widget.dart';
import 'package:ada_app/ui/widgets/observaciones_widget.dart';
import 'package:ada_app/repositories/operacion_comercial_repository.dart';

class OperacionComercialFormScreen extends StatelessWidget {
  final Cliente cliente;
  final TipoOperacion tipoOperacion;
  final OperacionComercial? operacionExistente;
  final bool isViewOnly;

  const OperacionComercialFormScreen({
    super.key,
    required this.cliente,
    required this.tipoOperacion,
    this.operacionExistente,
    this.isViewOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    // 👇 CAMBIO: Incluir operaciones con error o sincronizadas como solo lectura
    final esVisualizacion =
        isViewOnly ||
        (operacionExistente != null &&
            (operacionExistente!.estaSincronizado ||
                operacionExistente!.tieneError));

    return ChangeNotifierProvider(
      create: (context) => vm.OperacionComercialFormViewModel(
        cliente: cliente,
        tipoOperacion: tipoOperacion,
        operacionExistente: operacionExistente,
        isViewOnly: esVisualizacion,
      ),
      child: const _OperacionComercialFormView(),
    );
  }
}

class _OperacionComercialFormView extends StatefulWidget {
  const _OperacionComercialFormView();

  @override
  State<_OperacionComercialFormView> createState() =>
      _OperacionComercialFormViewState();
}

class _OperacionComercialFormViewState
    extends State<_OperacionComercialFormView> {
  final _formKey = GlobalKey<FormState>();
  bool _isRetrying = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<vm.OperacionComercialFormViewModel>(
      builder: (context, viewModel, child) {
        // ✅ CORREGIDO: Verificar si tiene error O está pendiente
        final tieneError = viewModel.operacionExistente?.tieneError ?? false;
        final estaPendiente =
            viewModel.operacionExistente?.estaPendiente ?? false;
        final necesitaReintento = tieneError || estaPendiente;

        return PopScope(
          canPop: viewModel.isViewOnly || !viewModel.isFormDirty,
          onPopInvokedWithResult: (didPop, result) async {
            if (!didPop && !viewModel.isViewOnly && viewModel.isFormDirty) {
              final shouldPop = await _handleBackNavigation(viewModel);
              if (shouldPop && mounted) {
                Navigator.of(this.context).pop();
              }
            }
          },
          child: Scaffold(
            backgroundColor: const Color(0xFFF8F9FC),
            appBar: _buildFixedAppBar(viewModel),
            body: Column(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => FocusScope.of(context).unfocus(),
                    child: Form(
                      key: _formKey,
                      child: CustomScrollView(
                        slivers: [
                          // Banner de estado
                          if (viewModel.isViewOnly)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  8,
                                ),
                                child: _buildModernStatusBanner(viewModel),
                              ),
                            ),

                          // Cuerpo
                          SliverPadding(
                            padding: const EdgeInsets.all(16.0),
                            sliver: SliverList(
                              delegate: SliverChildListDelegate([
                                _buildHeaderCard(viewModel),
                                const SizedBox(height: 24),

                                if (!viewModel.isViewOnly) ...[
                                  _buildSectionTitle('Agregar Productos'),
                                  const SizedBox(height: 12),
                                  BuscadorProductosWidget(
                                    searchQuery: viewModel.searchQuery,
                                    productosFiltrados:
                                        viewModel.productosFiltrados,
                                    productosSeleccionados:
                                        viewModel.productosSeleccionados,
                                    onSearchChanged: viewModel.setSearchQuery,
                                    onClearSearch: viewModel.clearSearch,
                                    onProductoSelected:
                                        viewModel.agregarProducto,
                                  ),
                                  const SizedBox(height: 24),
                                ],

                                _buildSectionTitle(
                                  'Detalle del Pedido',
                                  trailing: Text(
                                    '${viewModel.productosSeleccionados.length} items',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                ProductosSeleccionadosWidget(
                                  productosSeleccionados:
                                      viewModel.productosSeleccionados,
                                  tipoOperacion: viewModel.tipoOperacion,
                                  onEliminarProducto: viewModel.isViewOnly
                                      ? (_) {}
                                      : viewModel.eliminarProducto,
                                  onActualizarCantidad: viewModel.isViewOnly
                                      ? (_, __) {}
                                      : viewModel.actualizarCantidadProducto,
                                  onSeleccionarReemplazo: viewModel.isViewOnly
                                      ? (_, __) {}
                                      : (index, detalle) =>
                                            _seleccionarProductoReemplazo(
                                              viewModel,
                                              index,
                                              detalle,
                                            ),
                                  isReadOnly: viewModel.isViewOnly,
                                ),
                                const SizedBox(height: 24),

                                IgnorePointer(
                                  ignoring: viewModel.isViewOnly,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildSectionTitle('Notas Adicionales'),
                                      const SizedBox(height: 8),
                                      ObservacionesWidget(
                                        observaciones: viewModel.observaciones,
                                        onObservacionesChanged:
                                            viewModel.setObservaciones,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 80),
                              ]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ✅ CORREGIDO: Mostrar botón de reintentar si necesita reintento O si no es viewOnly
                if (!viewModel.isViewOnly || necesitaReintento)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          offset: const Offset(0, -4),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: necesitaReintento
                        ? _buildRetryButton(viewModel)
                        : BottomBarWidget(
                            totalProductos: viewModel.totalProductos,
                            isSaving: viewModel.isSaving,
                            isEditing: false,
                            onGuardar: () => _guardarOperacion(viewModel),
                          ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- WIDGETS ---

  // 👇 NUEVO: Widget para el botón de reintentar
  Widget _buildRetryButton(vm.OperacionComercialFormViewModel viewModel) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mensaje de error resumido
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: AppColors.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      viewModel.operacionExistente?.syncError ??
                          'Error de sincronización',
                      style: TextStyle(color: AppColors.error, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Botón de reintentar
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isRetrying
                    ? null
                    : () => _reintentarSincronizacion(viewModel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.warning.withValues(
                    alpha: 0.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isRetrying
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Reintentando...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.refresh, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Reintentar Envio',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildFixedAppBar(
    vm.OperacionComercialFormViewModel viewModel,
  ) {
    return AppBar(
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
      actions: viewModel.isViewOnly ? [_buildSyncStatusBadge(viewModel)] : null,
    );
  }

  Widget _buildSyncStatusBadge(vm.OperacionComercialFormViewModel viewModel) {
    final operacion = viewModel.operacionExistente;
    if (operacion == null) return const SizedBox.shrink();

    IconData icon;
    Color color;
    String tooltip;

    switch (operacion.syncStatus) {
      case 'migrado':
        icon = Icons.check_circle;
        color = Colors.green;
        tooltip = 'Sincronizado';
        break;
      case 'error':
        icon = Icons.error;
        color = Colors.red;
        tooltip = 'Error al sincronizar';
        break;
      case 'creado':
      default:
        icon = Icons.sync;
        color = Colors.orange;
        tooltip = 'Pendiente de sincronizar';
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Tooltip(
        message: tooltip,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }

  Widget _buildModernStatusBanner(
    vm.OperacionComercialFormViewModel viewModel,
  ) {
    final operacion = viewModel.operacionExistente;
    final tieneError = operacion?.syncStatus == 'error';
    final colorBase = tieneError ? Colors.red : Colors.blue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorBase.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorBase.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: colorBase.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              tieneError ? Icons.warning_amber_rounded : Icons.lock_outline,
              size: 18,
              color: colorBase.shade700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tieneError ? 'Error de Sincronización' : 'Modo Lectura',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorBase.shade900,
                    fontSize: 13,
                  ),
                ),
                Text(
                  tieneError
                      ? (operacion?.syncError ?? 'Error desconocido')
                      : 'Esta operación ya fue procesada.',
                  style: TextStyle(color: colorBase.shade700, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(vm.OperacionComercialFormViewModel viewModel) {
    return Column(
      children: [
        ClientInfoCard(cliente: viewModel.cliente),

        if (viewModel.tipoOperacion.necesitaFechaRetiro) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _buildFechaRetiroRow(viewModel),
          ),
        ],
      ],
    );
  }

  Widget _buildFechaRetiroRow(vm.OperacionComercialFormViewModel viewModel) {
    final isError = !viewModel.isViewOnly && viewModel.fechaRetiro == null;

    return InkWell(
      onTap: viewModel.isViewOnly
          ? null
          : () => _seleccionarFechaRetiro(viewModel),
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isError
                  ? AppColors.error.withValues(alpha: 0.1)
                  : AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.calendar_today_rounded,
              color: isError ? AppColors.error : AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fecha de Retiro',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                viewModel.fechaRetiro == null
                    ? 'Seleccionar fecha *'
                    : DateFormat('dd/MM/yyyy').format(viewModel.fechaRetiro!),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: isError ? AppColors.error : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (!viewModel.isViewOnly)
            Icon(Icons.edit_outlined, size: 18, color: Colors.grey[400]),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, {Widget? trailing}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  // --- LÓGICA DE NEGOCIO ---

  Future<void> _reintentarSincronizacion(
    vm.OperacionComercialFormViewModel viewModel,
  ) async {
    final operacion = viewModel.operacionExistente;
    if (operacion == null) return;

    setState(() => _isRetrying = true);

    try {
      final repository = OperacionComercialRepositoryImpl();

      // Reintentar envío
      await OperacionesComercialesPostService.enviarOperacion(operacion);

      // Éxito - marcar como migrado
      await repository.marcarComoMigrado(operacion.id!, null);

      if (!mounted) return;

      AppNotification.show(
        context,
        message: 'Operación sincronizada correctamente',
        type: NotificationType.success,
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      // Error - actualizar mensaje
      final repository = OperacionComercialRepositoryImpl();
      await repository.marcarComoError(
        operacion.id!,
        e.toString().replaceAll('Exception: ', ''),
      );

      if (!mounted) return;

      AppNotification.show(
        context,
        message:
            'Error al reintentar: ${e.toString().replaceAll('Exception: ', '')}',
        type: NotificationType.error,
      );
    } finally {
      if (mounted) setState(() => _isRetrying = false);
    }
  }

  Future<void> _seleccionarFechaRetiro(
    vm.OperacionComercialFormViewModel viewModel,
  ) async {
    if (viewModel.isViewOnly) return;

    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final manana = hoy.add(const Duration(days: 1));
    final fechaActual = viewModel.fechaRetiro ?? manana;
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

  Future<void> _guardarOperacion(
    vm.OperacionComercialFormViewModel viewModel,
  ) async {
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

  Future<bool> _handleBackNavigation(
    vm.OperacionComercialFormViewModel viewModel,
  ) async {
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
            child: Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textSecondary),
            ),
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

  Future<void> _seleccionarProductoReemplazo(
    vm.OperacionComercialFormViewModel viewModel,
    int index,
    dynamic detalle,
  ) async {
    if (viewModel.isViewOnly) return;

    final productoOriginal = Producto(
      id: detalle.productoId,
      codigo: detalle.productoCodigo,
      nombre: detalle.productoDescripcion,
      categoria: detalle.productoCategoria,
    );

    final productosReemplazo = await viewModel.obtenerProductosReemplazo(
      productoOriginal,
    );

    if (!mounted) return;

    if (productosReemplazo.isEmpty) {
      AppNotification.show(
        context,
        message: 'No hay productos de reemplazo disponibles',
        type: NotificationType.info,
      );
      return;
    }

    final productoSeleccionado = await showModalBottomSheet<Producto>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    Text(
                      'Seleccionar Reemplazo',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Productos de la misma categoría',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: productosReemplazo.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final producto = productosReemplazo[index];
                    return InkWell(
                      onTap: () => Navigator.pop(context, producto),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.inventory_2_outlined,
                                color: AppColors.primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    producto.nombre ?? 'Sin nombre',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
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
                            ),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: AppColors.primary,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (productoSeleccionado != null) {
      viewModel.seleccionarProductoReemplazo(index, productoSeleccionado);
    }
  }
}
