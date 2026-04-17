import 'package:flutter/material.dart';
import 'package:ada_app/models/cliente.dart';
import 'package:ada_app/viewmodels/cliente_detail_screen_viewmodel.dart';
import 'package:ada_app/ui/screens/menu_principal/equipos_clientes_detail_screen.dart';
import 'package:ada_app/ui/widgets/client_info_card.dart';
import '../censo_activo/forms_screen.dart';
import 'dart:async';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/main.dart';

class ClienteDetailScreen extends StatefulWidget {
  final Cliente cliente;

  const ClienteDetailScreen({super.key, required this.cliente});

  @override
  State<ClienteDetailScreen> createState() => _ClienteDetailScreenState();
}

class _ClienteDetailScreenState extends State<ClienteDetailScreen>
    with TickerProviderStateMixin, RouteAware {
  late ClienteDetailScreenViewModel _viewModel;
  late StreamSubscription<ClienteDetailUIEvent> _eventSubscription;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _viewModel = ClienteDetailScreenViewModel();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 0);
    _setupEventListener();
    _viewModel.initialize(widget.cliente);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    MyApp.routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void didPopNext() {
    if (mounted) {
      _viewModel.refresh();
    }
  }

  @override
  void dispose() {
    MyApp.routeObserver.unsubscribe(this);
    _eventSubscription.cancel();
    _tabController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  void _setupEventListener() {
    _eventSubscription = _viewModel.uiEvents.listen((event) {
      if (!mounted) return;

      if (event is ShowErrorEvent) {
        _showError(event.message);
      } else if (event is NavigateToFormsEvent) {
        _navigateToForms(event.cliente);
      } else if (event is NavigateToEquipoDetailEvent) {
        _navigateToEquipoDetail(event.equipoData);
      }
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ $message'),
        backgroundColor: AppColors.error,
        duration: Duration(seconds: 4),
      ),
    );
  }

  Future<void> _navigateToForms(Cliente cliente) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => FormsScreen(cliente: cliente)),
    );
    if (!mounted) return;
    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Censo completado exitosamente'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 3),
        ),
      );
      await _viewModel.refresh();
    }
    _viewModel.onNavigationResult(result);
  }

  void _navigateToEquipoDetail(dynamic equipoData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            EquiposClientesDetailScreen(equipoCliente: equipoData),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildClienteInfoCard(),
            ),
            _buildTabBar(),
            Expanded(child: _buildTabBarView()),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Detalle de Cliente'),
      backgroundColor: AppColors.appBarBackground,
      foregroundColor: AppColors.appBarForeground,
      elevation: 2,
      actions: [
        ListenableBuilder(
          listenable: _viewModel,
          builder: (context, child) {
            if (!_viewModel.canCreateCenso) return SizedBox.shrink();
            return IconButton(
              onPressed: _viewModel.navegarAAsignarEquipo,
              icon: const Icon(Icons.add),
              tooltip: 'Realizar censo de equipo',
            );
          },
        ),
      ],
    );
  }

  Widget _buildClienteInfoCard() {
    return ClientInfoCard(cliente: widget.cliente);
  }

  Widget _buildTabBar() {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, child) {
        return Container(
          color: AppColors.surface,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: AppColors.primary.withValues(alpha: 0.1),
            ),
            indicatorPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            dividerColor: Colors.transparent,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.report_problem_outlined,
                      size: 16,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Extraviados',
                      style: TextStyle(color: AppColors.error),
                    ),
                    if (_viewModel.equiposExtraviadosCount > 0) ...[
                      const SizedBox(width: 6),
                      _buildCountBadge(
                        _viewModel.equiposExtraviadosCount,
                        AppColors.error,
                      ),
                    ],
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Asignados',
                      style: TextStyle(color: AppColors.success),
                    ),
                    if (_viewModel.equiposAsignadosCount > 0) ...[
                      const SizedBox(width: 6),
                      _buildCountBadge(
                        _viewModel.equiposAsignadosCount,
                        AppColors.success,
                      ),
                    ],
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.pending_outlined, size: 16),
                    const SizedBox(width: 4),
                    const Text('Pendientes'),
                    if (_viewModel.equiposPendientesCount > 0) ...[
                      const SizedBox(width: 6),
                      _buildCountBadge(
                        _viewModel.equiposPendientesCount,
                        AppColors.warning,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCountBadge(int count, Color color) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTabBarView() {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, child) {
        if (_viewModel.isLoading) {
          return _buildLoadingState();
        }

        if (_viewModel.hasError) {
          return _buildErrorState();
        }

        return TabBarView(
          controller: _tabController,
          children: [
            _buildEquiposTab(
              equipos: _viewModel.equiposExtraviadosList,
              estado: 'extraviado',
              emptyTitle: 'Sin equipos extraviados',
              emptySubtitle: 'No hay equipos marcados como extraviados para este cliente',
              emptyIcon: Icons.report_problem_outlined,
            ),
            _buildEquiposTab(
              equipos: _viewModel.equiposAsignadosList,
              estado: 'asignado',
              emptyTitle: 'Sin equipos asignados',
              emptySubtitle:
                  'Este cliente no tiene equipos asignados actualmente',
              emptyIcon: Icons.check_circle_outline,
            ),
            _buildEquiposTab(
              equipos: _viewModel.equiposPendientesList,
              estado: 'pendiente',
              emptyTitle: 'Sin equipos no asignados',
              emptySubtitle: 'No hay equipos no asignados a este cliente',
              emptyIcon: Icons.pending_outlined,
            ),
          ],
        );
      },
    );
  }

  Widget _buildEquiposTab({
    required List<Map<String, dynamic>> equipos,
    required String estado,
    required String emptyTitle,
    required String emptySubtitle,
    required IconData emptyIcon,
  }) {
    if (equipos.isEmpty) {
      return _buildEmptyStateForTab(
        title: emptyTitle,
        subtitle: emptySubtitle,
        icon: emptyIcon,
        estado: estado,
      );
    }

    return RefreshIndicator(
      onRefresh: _viewModel.refresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: equipos.length,
        itemBuilder: (context, index) {
          final equipoData = equipos[index];
          return _buildEquipoCard(equipoData, estado: estado);
        },
      ),
    );
  }

  Widget _buildEmptyStateForTab({
    required String title,
    required String subtitle,
    required IconData icon,
    required String estado,
  }) {
    Color color;
    Color backgroundColor;

    if (estado == 'asignado') {
      color = AppColors.success;
      backgroundColor = AppColors.successContainer;
    } else if (estado == 'extraviado') {
      color = AppColors.error;
      backgroundColor = AppColors.errorContainer;
    } else {
      color = AppColors.warning;
      backgroundColor = AppColors.warningContainer;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(height: 24),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            if (_viewModel.canCreateCenso)
              ElevatedButton.icon(
                onPressed: _viewModel.navegarAAsignarEquipo,
                icon: const Icon(Icons.qr_code_scanner, size: 20),
                label: const Text('Realizar Censo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEquipoCard(
    Map<String, dynamic> equipoData, {
    required String estado,
  }) {
    Color equipoColor;
    Color borderColor;

    if (estado == 'asignado') {
      equipoColor = AppColors.success;
      borderColor = AppColors.borderSuccess;
    } else if (estado == 'extraviado') {
      equipoColor = AppColors.error;
      borderColor = AppColors.borderError;
    } else {
      equipoColor = AppColors.warning;
      borderColor = AppColors.borderWarning;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        color: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderColor, width: 1),
        ),
        child: InkWell(
          onTap: () => _viewModel.navegarADetalleEquipo(equipoData),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: equipoColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    estado == 'asignado'
                        ? Icons.check_circle
                        : (estado == 'extraviado'
                            ? Icons.report_problem
                            : Icons.pending),
                    color: AppColors.onPrimary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _getFormattedEquipoTitle(equipoData),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildSyncIcon(equipoData),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (_viewModel.getEquipoBarcode(equipoData) != null)
                        Text(
                          _viewModel.getEquipoBarcode(equipoData)!,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (_viewModel.getEquipoLogo(equipoData) != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          _viewModel.getEquipoLogo(equipoData)!,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (estado != 'pendiente') ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _viewModel.getEquipoFechaCensado(equipoData),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textTertiary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getFormattedEquipoTitle(Map<String, dynamic> equipoData) {
    final marca = (equipoData['marca_nombre'] ?? '').toString().trim();
    final modelo = (equipoData['modelo_nombre'] ?? '').toString().trim();

    if (marca.isNotEmpty && modelo.isNotEmpty) {
      return '$marca $modelo';
    } else if (marca.isNotEmpty) {
      return marca;
    } else if (modelo.isNotEmpty) {
      return modelo;
    } else {
      return _viewModel.getEquipoTitle(equipoData);
    }
  }

  Widget _buildSyncIcon(Map<String, dynamic> equipoData) {
    final tipoEstado = equipoData['tipo_estado']?.toString();

    if (tipoEstado == 'asignado' || tipoEstado == 'extraviado') {
      final iconColor =
          tipoEstado == 'asignado' ? AppColors.success : AppColors.error;
      return Tooltip(
        message: tipoEstado == 'asignado'
            ? 'Equipo sincronizado desde servidor'
            : 'Equipo marcado como extraviado',
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: iconColor.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
          child: Icon(
            tipoEstado == 'asignado' ? Icons.cloud_done : Icons.report_problem,
            size: 14,
            color: iconColor,
          ),
        ),
      );
    } else {
      return FutureBuilder<Map<String, dynamic>?>(
        future: _viewModel.getEstadoCensoInfo(equipoData),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data == null) {
            return SizedBox.shrink();
          }

          final estadoInfo = snapshot.data!;
          Color iconColor;
          IconData icon;
          String tooltip;

          final estadoCenso = estadoInfo['estado_censo']
              ?.toString()
              .toLowerCase();

          final sincronizado =
              estadoInfo['sincronizado']?.toString() == '1' ||
              estadoInfo['sincronizado'] == 1 ||
              estadoInfo['sincronizado'] == true ||
              estadoInfo['esta_sincronizado'] == true;

          if (estadoCenso == 'migrado' || sincronizado) {
            iconColor = AppColors.success;
            icon = Icons.cloud_done;
            tooltip = 'Sincronizado con servidor';
          } else if (estadoCenso == 'creado') {
            iconColor = AppColors.warning;
            icon = Icons.cloud_upload;
            tooltip = 'Pendiente de sincronizar';
          } else if (estadoCenso == 'error') {
            iconColor = AppColors.error;
            icon = Icons.cloud_off;
            tooltip = 'Error en sincronización';
          } else {
            return SizedBox.shrink();
          }

          return Tooltip(
            message: tooltip,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: iconColor.withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
              child: Icon(icon, size: 14, color: iconColor),
            ),
          );
        },
      );
    }
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
            const SizedBox(height: 16),
            Text(
              _viewModel.getLoadingMessage(),
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderError),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Text(
            _viewModel.getErrorStateTitle(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.error,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _viewModel.errorMessage!,
            style: TextStyle(fontSize: 14, color: AppColors.error),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _viewModel.cargarEquipos,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
