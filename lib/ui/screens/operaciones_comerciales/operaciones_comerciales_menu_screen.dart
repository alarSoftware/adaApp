// lib/ui/screens/operaciones_comerciales/operaciones_comerciales_menu_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:ada_app/models/cliente.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/ui/widgets/client_info_card.dart';
import 'package:ada_app/models/operaciones_comerciales/enums/tipo_operacion.dart';
import 'package:ada_app/models/operaciones_comerciales/operacion_comercial.dart';
import 'package:ada_app/ui/screens/operaciones_comerciales/operacion_comercial_form_screen.dart';
import 'package:ada_app/viewmodels/operaciones_comerciales/operaciones_comerciales_menu_viewmodel.dart';
import 'package:ada_app/main.dart';

class OperacionesComercialesMenuScreen extends StatelessWidget {
  final Cliente cliente;

  const OperacionesComercialesMenuScreen({super.key, required this.cliente});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          OperacionesComercialesMenuViewModel(clienteId: cliente.id!),
      child: _OperacionesComercialesMenuView(cliente: cliente),
    );
  }
}

class _OperacionesComercialesMenuView extends StatefulWidget {
  final Cliente cliente;

  const _OperacionesComercialesMenuView({required this.cliente});

  @override
  State<_OperacionesComercialesMenuView> createState() =>
      _OperacionesComercialesMenuViewState();
}

class _OperacionesComercialesMenuViewState
    extends State<_OperacionesComercialesMenuView>
    with TickerProviderStateMixin, RouteAware {
  late TabController _tabController;
  late List<_TabConfig> _availableTabs;

  bool _canCreateOperacion = true;

  @override
  void initState() {
    super.initState();
    // _checkPermission(); -> SIMPLIFICADO: Si entra al módulo, puede crear.
    _availableTabs = _getAvailableTabs();
    _tabController = TabController(length: _availableTabs.length, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ModalRoute? modalRoute = ModalRoute.of(context);
    if (modalRoute is PageRoute) {
      MyApp.routeObserver.subscribe(this, modalRoute);
    }
  }

  @override
  void dispose() {
    MyApp.routeObserver.unsubscribe(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didPush() {
    _refreshData();
  }

  @override
  void didPopNext() {
    _refreshData();
  }

  void _refreshData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<OperacionesComercialesMenuViewModel>().cargarOperaciones();
      }
    });
  }

  List<_TabConfig> _getAvailableTabs() {
    final List<_TabConfig> tabs = [];

    tabs.add(
      _TabConfig(
        tipo: TipoOperacion.notaReposicion,
        label: 'Reposición',
        icon: Icons.add_shopping_cart,
        color: AppColors.success,
        title: 'Nota de Reposición',
        description: 'Solicita productos para reponer en el cliente',
      ),
    );

    if (widget.cliente.esCredito) {
      tabs.add(
        _TabConfig(
          tipo: TipoOperacion.notaRetiro,
          label: 'Nota de Retiro',
          icon: Icons.remove_shopping_cart,
          color: AppColors.warning,
          title: 'Nota de Retiro',
          description: 'Retira productos del cliente',
        ),
      );
    }

    if (widget.cliente.esContado) {
      tabs.add(
        _TabConfig(
          tipo: TipoOperacion.notaRetiroDiscontinuos,
          label: 'NDR Discontinuos',
          icon: Icons.inventory_2_outlined,
          color: AppColors.error,
          title: 'Retiro de Discontinuos',
          description: 'Retira productos discontinuados (misma categoría)',
        ),
      );
    }

    return tabs;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: ClientInfoCard(cliente: widget.cliente),
            ),
            if (_availableTabs.length > 1) _buildTabBar(),
            Expanded(
              child: _availableTabs.length > 1
                  ? _buildTabBarView()
                  : _buildSingleTab(_availableTabs.first),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Operaciones Comerciales'),
      backgroundColor: AppColors.appBarBackground,
      foregroundColor: AppColors.appBarForeground,
      elevation: 0,
      centerTitle: true,
      actions: [
        Consumer<OperacionesComercialesMenuViewModel>(
          builder: (context, viewModel, _) {
            return IconButton(
              icon: viewModel.isSyncing
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.appBarForeground,
                      ),
                    )
                  : const Icon(Icons.refresh_rounded),
              onPressed: viewModel.isLoading || viewModel.isSyncing
                  ? null
                  : () => _sincronizarYCargar(viewModel),
              tooltip: 'Sincronizar con servidor',
            );
          },
        ),
      ],
    );
  }

  Future<void> _sincronizarYCargar(
    OperacionesComercialesMenuViewModel viewModel,
  ) async {
    final resultado = await viewModel.sincronizarOperacionesDesdeServidor();

    if (!mounted) return;

    if (resultado != null) {
      final itemsSincronizados = resultado['total'] ?? 0;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            itemsSincronizados > 0
                ? '✓ $itemsSincronizados operaciones sincronizadas'
                : 'Sin nuevas operaciones',
          ),
          backgroundColor: itemsSincronizados > 0
              ? AppColors.success
              : Colors.grey.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Widget _buildTabBar() {
    return Container(
      color: AppColors.surface,
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary,
        indicatorWeight: 3,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
        ),
        tabs: _availableTabs
            .map((tab) => Tab(text: tab.label, icon: Icon(tab.icon, size: 20)))
            .toList(),
      ),
    );
  }

  Widget _buildTabBarView() {
    return TabBarView(
      controller: _tabController,
      children: _availableTabs
          .map(
            (tab) =>
                _buildOperacionTab(tipoOperacion: tab.tipo, color: tab.color),
          )
          .toList(),
    );
  }

  Widget _buildSingleTab(_TabConfig tab) {
    return _buildOperacionTab(tipoOperacion: tab.tipo, color: tab.color);
  }

  Widget _buildOperacionTab({
    required TipoOperacion tipoOperacion,
    required Color color,
  }) {
    return Consumer<OperacionesComercialesMenuViewModel>(
      builder: (context, viewModel, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              if (_canCreateOperacion)
                SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _navigateToCreateOperacion(tipoOperacion, viewModel),
                    icon: const Icon(
                      Icons.add_circle_outline_rounded,
                      size: 20,
                    ),
                    label: const Text(
                      'Nueva Solicitud',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shadowColor: color.withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
              if (_canCreateOperacion) const SizedBox(height: 24),
              const SizedBox(height: 12),
              Expanded(
                child: _buildOperacionesList(viewModel, tipoOperacion, color),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOperacionesList(
    OperacionesComercialesMenuViewModel viewModel,
    TipoOperacion tipoOperacion,
    Color color,
  ) {
    if (viewModel.isLoading) {
      return Center(child: CircularProgressIndicator(color: color));
    }

    final operaciones = viewModel.getOperacionesPorTipo(tipoOperacion);

    if (operaciones.isEmpty) {
      return _buildEmptyState(tipoOperacion, color);
    }

    return ListView.separated(
      itemCount: operaciones.length,
      padding: const EdgeInsets.only(bottom: 20),
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final operacion = operaciones[index];
        return _buildOperacionCard(operacion, color, viewModel);
      },
    );
  }

  Widget _buildOperacionCard(
    OperacionComercial operacion,
    Color color,
    OperacionesComercialesMenuViewModel viewModel,
  ) {
    final fechaCreacionStr = DateFormat(
      'dd/MM/yyyy HH:mm',
    ).format(operacion.fechaCreacion);

    final isReposicion =
        operacion.tipoOperacion == TipoOperacion.notaReposicion;
    final fechaRetiroLabel = isReposicion ? 'Fecha Reposicion' : 'Fecha Retiro';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _navigateToEditOperacion(operacion, viewModel),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.description_outlined,
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getSyncStatusColor(
                            operacion.syncStatus,
                          ).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          operacion.displaySyncStatus,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _getSyncStatusColor(operacion.syncStatus),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (operacion.odooName != null &&
                          operacion.odooName!.isNotEmpty)
                        Text(
                          'Odoo: ${operacion.odooName}',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      if (operacion.adaSequence != null &&
                          operacion.adaSequence!.isNotEmpty)
                        Text(
                          'Seq: ${operacion.adaSequence}',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      if ((operacion.odooName == null ||
                              operacion.odooName!.isEmpty) &&
                          (operacion.adaSequence == null ||
                              operacion.adaSequence!.isEmpty))
                        Text(
                          'Sin Identificadores',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontStyle: FontStyle.italic,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Creado:',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      fechaCreacionStr,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (operacion.fechaRetiro != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '$fechaRetiroLabel:',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 12,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat(
                              'dd/MM/yyyy',
                            ).format(operacion.fechaRetiro!),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: Colors.grey.shade300),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(TipoOperacion tipoOperacion, Color color) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Icon(
              Icons.folder_off_outlined,
              size: 40,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Sin registros aún',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Crea una nueva solicitud arriba',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Color _getSyncStatusColor(String syncStatus) {
    switch (syncStatus) {
      case 'creado':
        return AppColors.warning;
      case 'migrado':
        return AppColors.success;
      case 'error':
        return AppColors.error;
      default:
        return Colors.grey;
    }
  }

  Future<void> _navigateToCreateOperacion(
    TipoOperacion tipoOperacion,
    OperacionesComercialesMenuViewModel viewModel,
  ) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OperacionComercialFormScreen(
          cliente: widget.cliente,
          tipoOperacion: tipoOperacion,
        ),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Operación creada exitosamente'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _navigateToEditOperacion(
    OperacionComercial operacion,
    OperacionesComercialesMenuViewModel viewModel,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OperacionComercialFormScreen(
          cliente: widget.cliente,
          tipoOperacion: operacion.tipoOperacion,
          operacionExistente: operacion,
          isViewOnly: true,
        ),
      ),
    );
  }
}

class _TabConfig {
  final TipoOperacion tipo;
  final String label;
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  _TabConfig({
    required this.tipo,
    required this.label,
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });
}
