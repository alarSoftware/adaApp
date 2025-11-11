// lib/ui/screens/operaciones_comerciales/operaciones_comerciales_menu_screen.dart
import 'package:flutter/material.dart';
import 'package:ada_app/models/cliente.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/ui/widgets/client_info_card.dart';
import 'package:ada_app/models/operaciones_comerciales/enums/tipo_operacion.dart';

class OperacionesComercialesMenuScreen extends StatefulWidget {
  final Cliente cliente;

  const OperacionesComercialesMenuScreen({
    Key? key,
    required this.cliente,
  }) : super(key: key);

  @override
  State<OperacionesComercialesMenuScreen> createState() => _OperacionesComercialesMenuScreenState();
}

class _OperacionesComercialesMenuScreenState extends State<OperacionesComercialesMenuScreen>
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
    );
  }

  Widget _buildClienteInfoCard() {
    return ClientInfoCard(
      cliente: widget.cliente,
    );
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
            onPressed: () => _navigateToCreateOperacion(tipoOperacion),
            icon: Icon(Icons.add),
            label: Text('Crear ${title}'),
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

          // Lista de operaciones (por ahora vacía)
          Expanded(
            child: _buildOperacionesList(tipoOperacion, color),
          ),
        ],
      ),
    );
  }

  Widget _buildOperacionesList(TipoOperacion tipoOperacion, Color color) {
    // TODO: Aquí irá la lista real de operaciones cuando tengamos el repository
    return _buildEmptyState(tipoOperacion, color);
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

  void _navigateToCreateOperacion(TipoOperacion tipoOperacion) {
    // TODO: Navegar a la pantalla de creación de operación
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Crear ${tipoOperacion.displayName}'),
        backgroundColor: AppColors.info,
      ),
    );
  }
}