import 'package:ada_app/services/post/operaciones_comerciales_post_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:ada_app/models/cliente.dart';
import 'package:ada_app/models/producto.dart';
import 'package:ada_app/models/operaciones_comerciales/enums/tipo_operacion.dart';
import 'package:ada_app/models/operaciones_comerciales/operacion_comercial.dart';

import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/ui/widgets/client_info_card.dart';
import 'package:ada_app/ui/widgets/app_notification.dart';
import 'package:ada_app/ui/widgets/operaciones_comerciales/buscador_productos_widget.dart';
import 'package:ada_app/ui/widgets/operaciones_comerciales/productos_seleccionados_widget.dart';
import 'package:ada_app/ui/widgets/bottom_bar_widget.dart';

import 'package:ada_app/viewmodels/operaciones_comerciales/operacion_comercial_viewmodel.dart'
    as vm;
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

  @override
  Widget build(BuildContext context) {
    return Consumer<vm.OperacionComercialFormViewModel>(
      builder: (context, viewModel, child) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (viewModel.hasError && viewModel.errorMessage != null) {
            AppNotification.show(
              context,
              message: viewModel.errorMessage!,
              type: NotificationType.error,
            );
            viewModel.clearError();
          }
        });

        final tieneError = viewModel.operacionExistente?.tieneError ?? false;
        final estaPendiente =
            viewModel.operacionExistente?.estaPendiente ?? false;
        final necesitaReintento = tieneError || estaPendiente;
        final itemCount = viewModel.productosSeleccionados.length;

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
            backgroundColor: const Color(0xFFF8FAFC),
            appBar: _buildStaticAppBar(viewModel),
            resizeToAvoidBottomInset: true,
            body: Column(
              children: [
                if (viewModel.isViewOnly)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: _buildModernStatusBanner(viewModel),
                  ),

                Expanded(
                  child: GestureDetector(
                    onTap: () => FocusScope.of(context).unfocus(),
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          _buildHeaderSection(viewModel),

                          const SizedBox(height: 20),

                          if (!viewModel.isViewOnly) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'AGREGAR ITEMS',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.grey[500],
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  BuscadorProductosWidget(
                                    searchQuery: viewModel.searchQuery,
                                    productosFiltrados:
                                        viewModel.productosFiltrados,
                                    productosSeleccionados:
                                        viewModel.productosSeleccionados,
                                    onSearchChanged: viewModel.setSearchQuery,
                                    onClearSearch: viewModel.clearSearch,
                                    onProductoSelected: (producto) {
                                      HapticFeedback.selectionClick();
                                      viewModel.agregarProducto(producto);
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],

                          if (itemCount > 0) _buildProductListDirect(viewModel),
                        ],
                      ),
                    ),
                  ),
                ),

                if ((!viewModel.isViewOnly || necesitaReintento) &&
                    MediaQuery.of(context).viewInsets.bottom == 0)
                  _buildBottomArea(viewModel, necesitaReintento),
              ],
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildStaticAppBar(
    vm.OperacionComercialFormViewModel viewModel,
  ) {
    return AppBar(
      title: Column(
        children: [
          Text(
            viewModel.isViewOnly ? 'Detalle de Pedido' : 'Nueva Operación',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
              fontSize: 17,
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              viewModel.tipoOperacion.displayName.toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      scrolledUnderElevation: 0,
      iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
      actions: viewModel.isViewOnly ? [_buildSyncStatusBadge(viewModel)] : null,
    );
  }

  Widget _buildHeaderSection(vm.OperacionComercialFormViewModel viewModel) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ClientInfoCard(
              cliente: viewModel.cliente,
              bottomContent: _buildFechaRetiroCompact(viewModel),
            ),
          ),
          if (viewModel.tipoOperacion == TipoOperacion.notaRetiro) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildSncField(viewModel),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSncField(vm.OperacionComercialFormViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.numbers_rounded,
                  size: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'SNC',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (viewModel.isViewOnly)
            Text(
              viewModel.snc?.isEmpty ?? true ? 'Sin SNC' : viewModel.snc!,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(0xFF334155),
              ),
            )
          else
            TextFormField(
              initialValue: viewModel.snc,
              enabled: !viewModel.isViewOnly,
              onChanged: (value) => viewModel.setSnc(value),
              decoration: InputDecoration(
                hintText: 'Ingrese el SNC',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(0xFF334155),
              ),
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.done,
            ),
        ],
      ),
    );
  }

  Widget _buildFechaRetiroCompact(
    vm.OperacionComercialFormViewModel viewModel,
  ) {
    final isError = !viewModel.isViewOnly && viewModel.fechaRetiro == null;
    final operacion = viewModel.operacionExistente;

    final adaSequence = operacion?.adaSequence;
    final odooName = operacion?.odooName;
    final hasAdaSequence = adaSequence != null && adaSequence.isNotEmpty;
    final hasOdooName = odooName != null && odooName.isNotEmpty;

    final adaEstado = operacion?.adaEstado;
    final estadoOdoo = operacion?.estadoOdoo;
    final hasAdaEstado = adaEstado != null && adaEstado.isNotEmpty;
    final hasEstadoOdoo = estadoOdoo != null && estadoOdoo.isNotEmpty;

    final motivoOdoo = operacion?.motivoOdoo;
    final hasMotivo = motivoOdoo != null && motivoOdoo.isNotEmpty;
    final ordenTransporte = operacion?.ordenTransporteOdoo;
    final hasOrden = ordenTransporte != null && ordenTransporte.isNotEmpty;

    return Column(
      children: [
        // 1. FECHA (Siempre es importante que sea claro)
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: viewModel.isViewOnly
                ? null
                : () => _seleccionarFechaRetiro(viewModel),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                children: [
                  _buildIconContainer(
                    Icons.calendar_today_rounded,
                    isError ? AppColors.error : Colors.grey[600]!,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabelText('Fecha de Entrega / Retiro'),
                        const SizedBox(height: 2),
                        Text(
                          viewModel.fechaRetiro == null
                              ? 'Seleccionar fecha...'
                              : DateFormat(
                                  'EEEE d, MMMM yyyy',
                                  'es',
                                ).format(viewModel.fechaRetiro!),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: isError
                                ? AppColors.error
                                : const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!viewModel.isViewOnly)
                    Icon(Icons.edit, size: 16, color: Colors.grey[400]),
                ],
              ),
            ),
          ),
        ),

        // 2. IDENTIFICADORES (Grupo Horizontal)
        if (hasAdaSequence || hasOdooName || viewModel.isViewOnly) ...[
          _buildDivider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildIconContainer(Icons.tag_rounded, Colors.grey[600]!),
                const SizedBox(width: 12),
                if (hasAdaSequence)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabelText('Ada Sequence'),
                        Text(
                          adaSequence,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (viewModel.isViewOnly)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabelText('Odoo Name'),
                        Text(
                          hasOdooName ? odooName : 'Sin asignar',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: hasOdooName
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: hasOdooName
                                ? AppColors.primary
                                : Colors.grey[400],
                            fontStyle: hasOdooName
                                ? FontStyle.normal
                                : FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],

        // 3. ESTADOS (Badges Horizontales)
        if (hasAdaEstado || hasEstadoOdoo) ...[
          _buildDivider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                _buildIconContainer(Icons.sync, Colors.grey[600]!),
                const SizedBox(width: 12),
                if (hasAdaEstado) ...[
                  _buildCompactStatusBadge(
                    'ADA',
                    adaEstado,
                    Colors.blue,
                    Icons.info_outline,
                  ),
                  const SizedBox(width: 8),
                ],
                if (hasEstadoOdoo)
                  _buildCompactStatusBadge(
                    'ODOO',
                    estadoOdoo,
                    Colors.teal,
                    Icons.sync_alt_rounded,
                  ),
              ],
            ),
          ),
        ],

        // 4. LOGÍSTICA (OT y MOTIVO en grupo compacto)
        if (hasOrden || hasMotivo) ...[
          _buildDivider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildIconContainer(
                  Icons.local_shipping_outlined,
                  Colors.grey[600]!,
                ),
                const SizedBox(width: 12),
                if (hasOrden)
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabelText('Orden Transporte'),
                        Text(
                          ordenTransporte,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (hasMotivo)
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabelText('Motivo Odoo'),
                        Text(
                          motivoOdoo,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        // 5. BOTÓN DE ACTUALIZACIÓN CON TEXTO (Debajo de los datos técnicos)
        if (viewModel.isViewOnly) ...[
          _buildDivider(),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: viewModel.isLoading
                  ? null
                  : () => viewModel.sincronizarOperacionActual(),
              icon: viewModel.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFFFC107),
                      ),
                    )
                  : const Icon(
                      Icons.refresh_rounded,
                      color: Color(0xFF1E293B),
                      size: 18,
                    ),
              label: Text(
                viewModel.isLoading
                    ? 'ACTUALIZANDO...'
                    : 'ACTUALIZAR INFORMACIÓN',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                  letterSpacing: 0.5,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(
                  color: const Color(0xFFFFC107).withValues(alpha: 0.5),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                backgroundColor: const Color(
                  0xFFFFC107,
                ).withValues(alpha: 0.95),
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ],
    );
  }

  Widget _buildCompactStatusBadge(
    String prefix,
    String status,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            prefix,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 1),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 10, color: color),
              const SizedBox(width: 4),
              Text(
                status.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconContainer(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.neutral300, // Match ClientInfoCard icon bg
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        icon,
        size: 16, // Match ClientInfoCard icon size
        color: color == AppColors.primary
            ? AppColors.primary
            : AppColors.textSecondary, // Match default textSecondary
      ),
    );
  }

  Widget _buildLabelText(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 10,
        color: Colors.grey[500],
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.grey.withValues(alpha: 0.1),
      indent: 40, // Alineado con el inicio del texto (28 icon + 12 gap)
    );
  }

  Widget _buildProductListDirect(vm.OperacionComercialFormViewModel viewModel) {
    final itemCount = viewModel.productosSeleccionados.length;

    if (itemCount == 0) {
      return Padding(
        padding: const EdgeInsets.only(top: 20),
        child: _buildEmptyState(),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ProductosSeleccionadosWidget(
        productosSeleccionados: viewModel.productosSeleccionados,
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
                  _seleccionarProductoReemplazo(viewModel, index, detalle),
        isReadOnly: viewModel.isViewOnly,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.post_add_rounded, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            "Sin productos",
            style: TextStyle(
              color: Colors.grey[400],
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomArea(
    vm.OperacionComercialFormViewModel viewModel,
    bool necesitaReintento,
  ) {
    return Container(
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
      child: SafeArea(
        top: false,
        child: necesitaReintento
            ? _buildRetryButton(viewModel)
            : BottomBarWidget(
                totalProductos: viewModel.totalProductos,
                isSaving: viewModel.isSaving,
                isEditing: false,
                onGuardar: () => _guardarOperacion(viewModel),
              ),
      ),
    );
  }

  Widget _buildRetryButton(vm.OperacionComercialFormViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 16, color: AppColors.error),
              const SizedBox(width: 8),
              Text(
                'Error de sincronización',
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => _reintentarSincronizacion(viewModel),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text(
                'Reintentar Sincronización',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernStatusBanner(
    vm.OperacionComercialFormViewModel viewModel,
  ) {
    final operacion = viewModel.operacionExistente;
    final tieneError = operacion?.syncStatus == 'error';
    final colorBase = tieneError ? AppColors.error : const Color(0xFF64748B);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorBase.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorBase.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            tieneError ? Icons.cloud_off_rounded : Icons.lock_clock_rounded,
            color: colorBase,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tieneError ? 'Sincronización Fallida' : 'Modo Solo Lectura',
                  style: TextStyle(
                    color: colorBase,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (tieneError)
                  Text(
                    operacion?.syncError ?? 'Error desconocido',
                    style: TextStyle(
                      color: colorBase.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncStatusBadge(vm.OperacionComercialFormViewModel viewModel) {
    final status = viewModel.operacionExistente?.syncStatus;
    IconData icon = Icons.sync;
    Color color = Colors.orange;
    String tooltip = 'Pendiente';

    if (status == 'migrado') {
      icon = Icons.check_circle_rounded;
      color = Colors.green;
      tooltip = 'Sincronizado';
    }
    if (status == 'error') {
      icon = Icons.error_rounded;
      color = Colors.red;
      tooltip = 'Error';
    }

    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: Tooltip(
        message: tooltip,
        child: Icon(icon, color: color),
      ),
    );
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return PopScope(
          canPop: false,
          child: Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    const SizedBox(height: 16),
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _hideLoadingDialog() {
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _reintentarSincronizacion(
    vm.OperacionComercialFormViewModel viewModel,
  ) async {
    final operacion = viewModel.operacionExistente;
    if (operacion == null) return;

    _showLoadingDialog('Sincronizando operación...');

    try {
      final repository = OperacionComercialRepositoryImpl();
      final serverResponse =
          await OperacionesComercialesPostService.enviarOperacion(operacion);

      String? odooName;
      String? adaSequence;

      if (serverResponse.resultJson != null) {
        final parsedData =
            OperacionesComercialesPostService.parsearRespuestaJson(
              serverResponse.resultJson,
            );
        odooName = parsedData['odooName'];
        adaSequence = parsedData['adaSequence'];
      }

      await repository.marcarComoMigrado(
        operacion.id!,
        serverResponse.resultId,
        odooName: odooName,
        adaSequence: adaSequence,
      );

      if (!mounted) return;

      _hideLoadingDialog();

      AppNotification.show(
        context,
        message: 'Operación sincronizada correctamente',
        type: NotificationType.success,
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      _hideLoadingDialog();

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
    }
  }

  Future<void> _seleccionarFechaRetiro(
    vm.OperacionComercialFormViewModel viewModel,
  ) async {
    if (viewModel.isViewOnly) return;
    HapticFeedback.selectionClick();

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
            dialogBackgroundColor: Colors.white,
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
      HapticFeedback.heavyImpact();
      AppNotification.show(
        context,
        message: 'Por favor revisa los campos marcados',
        type: NotificationType.error,
      );
      return;
    }

    _showLoadingDialog('Guardando operación...');

    final operacionGuardada = await viewModel.guardarOperacion();

    if (!mounted) return;

    _hideLoadingDialog();

    if (operacionGuardada != null) {
      AppNotification.show(
        context,
        message: 'Operación guardada correctamente',
        type: NotificationType.success,
      );

      if (!mounted) return;

      final result = await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => OperacionComercialFormScreen(
            cliente: viewModel.cliente,
            tipoOperacion: viewModel.tipoOperacion,
            operacionExistente: operacionGuardada,
            isViewOnly: true,
          ),
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, result ?? true);
    }
  }

  Future<bool> _handleBackNavigation(
    vm.OperacionComercialFormViewModel viewModel,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            const SizedBox(width: 12),
            const Text('¿Salir sin guardar?', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: const Text(
          'Tienes productos o datos sin guardar. Se perderá el progreso actual.',
          style: TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Salir'),
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

    // Obtener el producto original desde el repository usando el productoId
    final productoOriginal = await viewModel.obtenerProductoPorId(
      detalle.productoId,
    );

    if (productoOriginal == null) {
      if (!mounted) return;
      AppNotification.show(
        context,
        message: 'No se pudo cargar la información del producto',
        type: NotificationType.error,
      );
      return;
    }

    final productosReemplazo = await viewModel.obtenerProductosReemplazo(
      productoOriginal,
    );

    if (!mounted) return;

    if (productosReemplazo.isEmpty) {
      AppNotification.show(
        context,
        message: 'No hay productos similares en el catálogo',
        type: NotificationType.info,
      );
      return;
    }

    final productoSeleccionado = await showModalBottomSheet<Producto>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ReemplazoProductoModal(
        productosReemplazo: productosReemplazo,
        productoOriginal: productoOriginal,
      ),
    );

    if (productoSeleccionado != null) {
      viewModel.seleccionarProductoReemplazo(index, productoSeleccionado);
    }
  }
}

class _ReemplazoProductoModal extends StatefulWidget {
  final List<Producto> productosReemplazo;
  final Producto productoOriginal;

  const _ReemplazoProductoModal({
    required this.productosReemplazo,
    required this.productoOriginal,
  });

  @override
  State<_ReemplazoProductoModal> createState() =>
      _ReemplazoProductoModalState();
}

class _ReemplazoProductoModalState extends State<_ReemplazoProductoModal> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Producto> _productosFiltrados = [];

  @override
  void initState() {
    super.initState();
    _productosFiltrados = widget.productosReemplazo;
    _searchController.addListener(_filtrarProductos);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _filtrarProductos() {
    final query = _searchController.text.toLowerCase().trim();

    setState(() {
      if (query.isEmpty) {
        _productosFiltrados = widget.productosReemplazo;
      } else {
        _productosFiltrados = widget.productosReemplazo.where((producto) {
          final nombre = producto.nombre?.toLowerCase() ?? '';
          final codigo = producto.codigo?.toLowerCase() ?? '';
          return nombre.contains(query) || codigo.contains(query);
        }).toList();
      }
    });
  }

  void _limpiarBusqueda() {
    _searchController.clear();
    _searchFocusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.92,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Scaffold(
          backgroundColor: Colors.white,
          resizeToAvoidBottomInset: true,
          body: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.swap_horiz_rounded,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Reemplazar Producto',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Categoría: "${widget.productoOriginal.categoria}"',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.grey.withValues(alpha: 0.1),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre o código...',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: Colors.grey[400]),
                            onPressed: _limpiarBusqueda,
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Text(
                      '${_productosFiltrados.length} ${_productosFiltrados.length == 1 ? "resultado" : "resultados"}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _productosFiltrados.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _productosFiltrados.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final producto = _productosFiltrados[index];
                          return _buildProductoItem(producto);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductoItem(Producto producto) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.pop(context, producto);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    producto.nombre ?? 'Sin nombre',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xFF1E293B),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          producto.codigo ?? 'S/C',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '• ${producto.unidadMedida}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No se encontraron resultados',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
