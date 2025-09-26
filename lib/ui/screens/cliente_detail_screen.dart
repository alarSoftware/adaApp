import 'package:flutter/material.dart';
import 'package:ada_app/models/cliente.dart';
import 'package:ada_app/viewmodels/cliente_detail_screen_viewmodel.dart';
import 'package:ada_app/ui/screens/equipos_clientes_detail_screen.dart';
import 'forms_screen.dart';
import 'dart:async';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:logger/logger.dart';

var logger = Logger();

class ClienteDetailScreen extends StatefulWidget {
  final Cliente cliente;

  const ClienteDetailScreen({
    super.key,
    required this.cliente,
  });

  @override
  State<ClienteDetailScreen> createState() => _ClienteDetailScreenState();
}

class _ClienteDetailScreenState extends State<ClienteDetailScreen>
    with TickerProviderStateMixin {
  late ClienteDetailScreenViewModel _viewModel;
  late StreamSubscription<ClienteDetailUIEvent> _eventSubscription;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _viewModel = ClienteDetailScreenViewModel();
    _tabController = TabController(length: 2, vsync: this);
    _setupEventListener();
    _viewModel.initialize(widget.cliente);
  }

  @override
  void dispose() {
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
      MaterialPageRoute(
        builder: (context) => FormsScreen(cliente: cliente),
      ),
    );
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
    final isAsignado = equipoData['tipo_estado'] == 'asignado';

    logger.i('Navegando a detalle de equipo:');
    logger.i('- Código: ${equipoData['cod_barras']}');
    logger.i('- Tipo estado: ${equipoData['tipo_estado']}');
    logger.i('- Es asignado: $isAsignado');

    if (isAsignado) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EquiposClientesDetailScreen(
            equipoCliente: equipoData,
          ),
        ),
      ).then((_) => _viewModel.refresh());
    } else {
      _showEquipoDetailsDialog(equipoData);
    }
  }

  void _showEquipoDetailsDialog(dynamic equipoData) {
    final nombreCompleto = _viewModel.getEquipoTitle(equipoData);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          nombreCompleto,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetalleRow('Código', equipoData['cod_barras'] ?? 'N/A'),
                _buildDetalleRow('Marca', equipoData['marca_nombre'] ?? 'Sin marca'),
                _buildDetalleRow('Modelo', equipoData['modelo_nombre'] ?? 'Sin modelo'),
                _buildDetalleRow('Logo', equipoData['logo_nombre'] ?? 'Sin logo'),
                if (equipoData['numero_serie'] != null && equipoData['numero_serie'].toString().isNotEmpty)
                  _buildDetalleRow('Número de Serie', equipoData['numero_serie']),
                _buildEstadoRow('Pendiente', AppColors.warning),
                _buildDetalleRow('Cliente', widget.cliente.nombre),
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warningContainer,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Este equipo está pendiente de confirmación',
                            style: TextStyle(
                              color: AppColors.warning,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
            ),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildEstadoRow(String estado, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              'Estado:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              estado,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetalleRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ),
        ],
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
      title: const Text('Detalle de Cliente'),
      backgroundColor: AppColors.appBarBackground,
      foregroundColor: AppColors.appBarForeground,
      elevation: 2,
      actions: [
        IconButton(
          onPressed: _viewModel.navegarAAsignarEquipo,
          icon: const Icon(Icons.add),
          tooltip: 'Realizar censo de equipo',
        ),
      ],
    );
  }

  Widget _buildClienteInfoCard() {
    return Card(
      elevation: 3,
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.cliente.nombre,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildInfoRow(Icons.person_outline, 'Propietario', widget.cliente.propietario),
            if (_viewModel.shouldShowPhone())
              _buildInfoRow(Icons.phone_outlined, 'Teléfono', _viewModel.getClientePhone()),
            if (_viewModel.shouldShowAddress())
              _buildInfoRow(Icons.location_on_outlined, 'Dirección', _viewModel.getClienteAddress()),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.neutral300,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, child) {
        return Container(
          color: AppColors.surface,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
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
                    Icon(Icons.check_circle_outline, size: 16),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Asignados',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_viewModel.equiposAsignadosCount > 0) ...[
                      const SizedBox(width: 4),
                      _buildCountBadge(_viewModel.equiposAsignadosCount, AppColors.success),
                    ],
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.pending_outlined, size: 16),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Pendientes',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_viewModel.equiposPendientesCount > 0) ...[
                      const SizedBox(width: 4),
                      _buildCountBadge(_viewModel.equiposPendientesCount, AppColors.warning),
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
              equipos: _viewModel.equiposAsignadosList,
              isAsignado: true,
              emptyTitle: 'Sin equipos asignados',
              emptySubtitle: 'Este cliente no tiene equipos asignados actualmente',
              emptyIcon: Icons.check_circle_outline,
            ),
            _buildEquiposTab(
              equipos: _viewModel.equiposPendientesList,
              isAsignado: false,
              emptyTitle: 'Sin equipos pendientes',
              emptySubtitle: 'No hay equipos pendientes de confirmación',
              emptyIcon: Icons.pending_outlined,
            ),
          ],
        );
      },
    );
  }

  Widget _buildEquiposTab({
    required List<Map<String, dynamic>> equipos,
    required bool isAsignado,
    required String emptyTitle,
    required String emptySubtitle,
    required IconData emptyIcon,
  }) {
    if (equipos.isEmpty) {
      return _buildEmptyStateForTab(
        title: emptyTitle,
        subtitle: emptySubtitle,
        icon: emptyIcon,
        isAsignado: isAsignado,
      );
    }

    return RefreshIndicator(
      onRefresh: _viewModel.refresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: equipos.length,
        itemBuilder: (context, index) {
          final equipoData = equipos[index];
          return _buildEquipoCard(equipoData, isAsignado: isAsignado);
        },
      ),
    );
  }

  Widget _buildEmptyStateForTab({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isAsignado,
  }) {
    final color = isAsignado ? AppColors.success : AppColors.warning;
    final backgroundColor = isAsignado ? AppColors.successContainer : AppColors.warningContainer;

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
              child: Icon(
                icon,
                size: 40,
                color: color,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _viewModel.navegarAAsignarEquipo,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Realizar Censo'),
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEquipoCard(Map<String, dynamic> equipoData, {required bool isAsignado}) {
    final equipoColor = isAsignado ? AppColors.success : AppColors.warning;
    final borderColor = isAsignado ? AppColors.borderSuccess : AppColors.borderWarning;
    final backgroundColor = isAsignado ? AppColors.successContainer : AppColors.warningContainer;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        color: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: borderColor,
            width: 1,
          ),
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
                    isAsignado ? Icons.check_circle : Icons.pending,
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
                          // Solo icono de sincronización
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
                      if (isAsignado) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 14, color: AppColors.textTertiary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _viewModel.getEquipoFechaCensado(equipoData),
                                style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
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
                Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Método helper para formatear el título del equipo sin espacios excesivos
  String _getFormattedEquipoTitle(Map<String, dynamic> equipoData) {
    final marca = equipoData['marca_nombre']?.toString()?.trim() ?? '';
    final modelo = equipoData['modelo_nombre']?.toString()?.trim() ?? '';

    // Si tenemos marca y modelo, los unimos con un solo espacio
    if (marca.isNotEmpty && modelo.isNotEmpty) {
      return '$marca $modelo';
    } else if (marca.isNotEmpty) {
      return marca;
    } else if (modelo.isNotEmpty) {
      return modelo;
    } else {
      // Fallback al método original si no hay marca ni modelo
      return _viewModel.getEquipoTitle(equipoData);
    }
  }

  // ICONO DE SINCRONIZACIÓN - USANDO DATOS REALES DE ESTADO_EQUIPO
  Widget _buildSyncIcon(Map<String, dynamic> equipoData) {
    final tipoEstado = equipoData['tipo_estado']?.toString();

    if (tipoEstado == 'asignado') {
      // Para equipos asignados (de API), mostrar icono fijo de "sincronizado"
      return Tooltip(
        message: 'Equipo sincronizado desde servidor',
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: AppColors.success.withOpacity(0.3),
              width: 0.5,
            ),
          ),
          child: Icon(
            Icons.cloud_done,
            size: 14,
            color: AppColors.success,
          ),
        ),
      );
    } else {
      // Para equipos pendientes, usar FutureBuilder para verificar estado real
      return FutureBuilder<Map<String, dynamic>?>(
        future: _viewModel.getEstadoCensoInfo(equipoData),
        builder: (context, snapshot) {
          // Debug: Agregar logs para ver qué datos llegan
          if (snapshot.hasData && snapshot.data != null) {
            logger.i('Estado info para ${equipoData['cod_barras']}: ${snapshot.data}');
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return SizedBox.shrink();
          }

          final estadoInfo = snapshot.data!;
          Color iconColor;
          IconData icon;
          String tooltip;

          // CORRECCIÓN: Buscar en el campo correcto 'estado_censo' de la tabla Estado_Equipo
          final estadoCenso = estadoInfo['estado_censo']?.toString().toLowerCase();

          // También verificar el campo 'sincronizado' si existe (equivalente a migrado)
          final sincronizado = estadoInfo['sincronizado']?.toString() == '1' ||
              estadoInfo['sincronizado'] == 1 ||
              estadoInfo['sincronizado'] == true ||
              estadoInfo['esta_sincronizado'] == true; // Por si usa el nombre del modelo

          logger.i('Estado censo: $estadoCenso, Sincronizado: $sincronizado');

          // Lógica correcta usando estado_censo:
          if (estadoCenso == 'migrado' || sincronizado) {
            // Datos ya enviados al servidor
            iconColor = AppColors.success;
            icon = Icons.cloud_done;
            tooltip = 'Sincronizado con servidor';
          } else if (estadoCenso == 'creado') {
            // Creado localmente pero no enviado al servidor
            iconColor = AppColors.warning;
            icon = Icons.cloud_upload;
            tooltip = 'Pendiente de sincronizar';
          } else if (estadoCenso == 'error') {
            // Error en la sincronización
            iconColor = AppColors.error;
            icon = Icons.cloud_off;
            tooltip = 'Error en sincronización';
          } else {
            // Si no hay estado_censo válido, no mostrar icono
            logger.w('No se encontró estado_censo válido: $estadoCenso');
            return SizedBox.shrink();
          }

          return Tooltip(
            message: tooltip,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: iconColor.withOpacity(0.3),
                  width: 0.5,
                ),
              ),
              child: Icon(
                icon,
                size: 14,
                color: iconColor,
              ),
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
            CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),
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