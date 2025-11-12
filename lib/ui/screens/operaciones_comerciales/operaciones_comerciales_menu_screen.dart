// lib/ui/screens/operaciones_comerciales/operaciones_comerciales_menu_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:ada_app/models/cliente.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/ui/widgets/client_info_card.dart';
import 'package:ada_app/models/operaciones_comerciales/enums/estado_operacion.dart';
import 'package:ada_app/models/operaciones_comerciales/enums/tipo_operacion.dart';
import 'package:ada_app/models/operaciones_comerciales/operacion_comercial.dart';
import 'package:ada_app/ui/screens/operaciones_comerciales/operacion_comercial_form_screen.dart';
import 'package:ada_app/viewmodels/operaciones_comerciales/operaciones_comerciales_menu_viewmodel.dart';
class OperacionesComercialesMenuScreen extends StatelessWidget {
  final Cliente cliente;

  const OperacionesComercialesMenuScreen({
    Key? key,
    required this.cliente,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => OperacionesComercialesMenuViewModel(
        clienteId: cliente.id!,
      ),
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
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
            Expanded(
              child: _buildTabBarView(),
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
      elevation: 2,
      actions: [
        Consumer<OperacionesComercialesMenuViewModel>(
          builder: (context, viewModel, _) {
            return IconButton(
              icon: Icon(Icons.refresh),
              onPressed: viewModel.isLoading ? null : viewModel.cargarOperaciones,
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
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
        tabs: [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_shopping_cart, size: 16),
                const SizedBox(width: 6),
                Text('Reposición'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.remove_shopping_cart, size: 16),
                const SizedBox(width: 6),
                Text('Retiro'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inventory_2_outlined, size: 16),
                const SizedBox(width: 6),
                Text('Discontinuos'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBarView() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildOperacionTab(
          tipoOperacion: TipoOperacion.notaReposicion,
          icon: Icons.add_shopping_cart,
          color: AppColors.success,
          title: 'Nota de Reposición',
          description: 'Solicita productos para reponer en el cliente',
        ),
        _buildOperacionTab(
          tipoOperacion: TipoOperacion.notaRetiro,
          icon: Icons.remove_shopping_cart,
          color: AppColors.warning,
          title: 'Nota de Retiro',
          description: 'Retira productos del cliente',
        ),
        _buildOperacionTab(
          tipoOperacion: TipoOperacion.notaRetiroDiscontinuos,
          icon: Icons.inventory_2_outlined,
          color: AppColors.error,
          title: 'Retiro de Discontinuos',
          description: 'Retira productos discontinuados (misma categoría)',
        ),
      ],
    );
  }

  Widget _buildOperacionTab({
    required TipoOperacion tipoOperacion,
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return Consumer<OperacionesComercialesMenuViewModel>(
      builder: (context, viewModel, _) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Encabezado del tipo de operación
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            description,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Botón para crear nueva operación
              ElevatedButton.icon(
                onPressed: () => _navigateToCreateOperacion(tipoOperacion, viewModel),
                icon: Icon(Icons.add),
                label: Text('Crear $title'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Lista de operaciones
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
      return Center(child: CircularProgressIndicator());
    }

    final operaciones = viewModel.getOperacionesPorTipo(tipoOperacion);

    if (operaciones.isEmpty) {
      return _buildEmptyState(tipoOperacion, color);
    }

    return ListView.separated(
      itemCount: operaciones.length,
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
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
      child: InkWell(
        onTap: () => _navigateToEditOperacion(operacion, viewModel),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Icono de estado
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getEstadoIcon(operacion.estado),
                  color: color,
                  size: 20,
                ),
              ),

              const SizedBox(width: 12),

              // Información de la operación
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'ID: ${operacion.id?.substring(0, 8)}...',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getEstadoColor(operacion.estado).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            operacion.estado.displayName,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _getEstadoColor(operacion.estado),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(operacion.fechaCreacion)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (operacion.fechaRetiro != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Retiro: ${DateFormat('dd/MM/yyyy').format(operacion.fechaRetiro!)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.shopping_cart, size: 12, color: AppColors.textTertiary),
                        const SizedBox(width: 4),
                        Text(
                          '${operacion.totalProductos} productos',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (!operacion.estaSincronizado) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.cloud_off, size: 12, color: AppColors.warning),
                          const SizedBox(width: 4),
                          Text(
                            'Sin sincronizar',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.warning,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Botón de más opciones
              PopupMenuButton(
                icon: Icon(Icons.more_vert, size: 20),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 18),
                        const SizedBox(width: 8),
                        Text('Editar'),
                      ],
                    ),
                    onTap: () => _navigateToEditOperacion(operacion, viewModel),
                  ),
                  PopupMenuItem(
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 18, color: AppColors.error),
                        const SizedBox(width: 8),
                        Text('Eliminar', style: TextStyle(color: AppColors.error)),
                      ],
                    ),
                    onTap: () => _confirmarEliminar(operacion.id!, viewModel),
                  ),
                ],
              ),
            ],
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
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(40),
            ),
            child: Icon(
              Icons.inbox_outlined,
              size: 40,
              color: color,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Sin operaciones',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No hay ${tipoOperacion.displayName.toLowerCase()} registradas',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Helpers
  IconData _getEstadoIcon(dynamic estado) {
    // Ajusta según tus estados
    return Icons.pending_actions;
  }

  Color _getEstadoColor(dynamic estado) {
    // Ajusta según tus estados
    return AppColors.warning;
  }

  // Navegación
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
      await viewModel.cargarOperaciones();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${tipoOperacion.displayName} creada exitosamente'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _navigateToEditOperacion(
      OperacionComercial operacion,
      OperacionesComercialesMenuViewModel viewModel,
      ) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OperacionComercialFormScreen(
          cliente: widget.cliente,
          tipoOperacion: operacion.tipoOperacion,
          operacionExistente: operacion,
        ),
      ),
    );

    if (result == true && mounted) {
      await viewModel.cargarOperaciones();
    }
  }

  Future<void> _confirmarEliminar(
      String operacionId,
      OperacionesComercialesMenuViewModel viewModel,
      ) async {
    // Pequeño delay porque PopupMenu cierra inmediatamente
    await Future.delayed(Duration(milliseconds: 100));

    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Eliminar operación?'),
        content: Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final success = await viewModel.eliminarOperacion(operacionId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Operación eliminada'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }
}