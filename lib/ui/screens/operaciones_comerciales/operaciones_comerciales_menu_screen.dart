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
/* with TickerProviderStateMixin */ {
  // 👈 COMENTADO PARA FUTURO

  /* // 🔮 CÓDIGO COMENTADO PARA FUTURO USO DE TABS
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
  */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC), // Fondo suave
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildClienteInfoCard(),
            ),

            /* // 🔮 AQUÍ IBAN LOS TABS (COMENTADO)
            _buildTabBar(),
            Expanded(
              child: _buildTabBarView(),
            ),
            */

            // 👇 MODO ACTUAL: Solo mostramos Discontinuos directamente
            Expanded(
              child: _buildOperacionTab(
                tipoOperacion: TipoOperacion.notaRetiroDiscontinuos,
                icon: Icons.inventory_2_outlined,
                color: AppColors.error, // Rojo
                title: 'Retiro de Discontinuos',
                description:
                    'Retira productos discontinuados (misma categoría)',
              ),
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
              icon: const Icon(Icons.refresh_rounded),
              onPressed: viewModel.isLoading
                  ? null
                  : viewModel.cargarOperaciones,
            );
          },
        ),
      ],
    );
  }

  Widget _buildClienteInfoCard() {
    return ClientInfoCard(cliente: widget.cliente);
  }

  /*
  // 🔮 WIDGETS DE TABS COMENTADOS PARA FUTURO
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
        // ... estilos ...
        tabs: const [
          Tab(text: 'Reposición', icon: Icon(Icons.add_shopping_cart)),
          Tab(text: 'Retiro', icon: Icon(Icons.remove_shopping_cart)),
          Tab(text: 'Discontinuos', icon: Icon(Icons.inventory_2_outlined)),
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
  */

  // ESTE WIDGET SÍ LO USAMOS (GENÉRICO)
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
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Encabezado (Banner de color)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 28),
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

              const SizedBox(height: 20),

              // Botón Principal (Acción)
              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () =>
                      _navigateToCreateOperacion(tipoOperacion, viewModel),
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: Text(
                    'Nueva Solicitud',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: color.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Título de sección
              Row(
                children: [
                  Icon(Icons.history, size: 20, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    'Historial Reciente',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

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
    // Formateador de fecha
    final fechaStr = DateFormat(
      'dd/MM/yyyy HH:mm',
    ).format(operacion.fechaCreacion);

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
                // Icono circular
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

                // Info central
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Chip de Estado de Sincronización
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

                      const SizedBox(height: 6),

                      // 2. La fecha
                      Text(
                        fechaStr,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Info derecha (Total items)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${operacion.totalProductos}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'items',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
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

  // Helper para colores de syncStatus
  Color _getSyncStatusColor(String syncStatus) {
    switch (syncStatus) {
      case 'creado':
        return AppColors.warning; // Amarillo/Naranja para pendiente
      case 'migrado':
        return AppColors.success; // Verde para sincronizado
      case 'error':
        return AppColors.error; // Rojo para error
      default:
        return Colors.grey;
    }
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
      if (!mounted) return;
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
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OperacionComercialFormScreen(
          cliente: widget.cliente,
          tipoOperacion: operacion.tipoOperacion,
          operacionExistente: operacion,
          isViewOnly: true, //SIEMPRE solo lectura para operaciones existentes
        ),
      ),
    );

    if (result == true && mounted) {
      await viewModel.cargarOperaciones();
    }
  }
}
