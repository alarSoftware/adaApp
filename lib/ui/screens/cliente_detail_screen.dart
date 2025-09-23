// ui/screens/cliente_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:ada_app/models/cliente.dart';
import 'package:ada_app/viewmodels/cliente_detail_screen_viewmodel.dart';
import 'package:ada_app/ui/screens/equipos_clientes_detail_screen.dart';
import 'forms_screen.dart';
import 'dart:async';
import 'package:ada_app/ui/theme/colors.dart';

class ClienteDetailScreen extends StatefulWidget {
  final Cliente cliente;

  const ClienteDetailScreen({
    super.key,
    required this.cliente,
  });

  @override
  State<ClienteDetailScreen> createState() => _ClienteDetailScreenState();
}

class _ClienteDetailScreenState extends State<ClienteDetailScreen> {
  late ClienteDetailScreenViewModel _viewModel;
  late StreamSubscription<ClienteDetailUIEvent> _eventSubscription;

  @override
  void initState() {
    super.initState();
    _viewModel = ClienteDetailScreenViewModel();
    _setupEventListener();
    _viewModel.initialize(widget.cliente);
  }

  @override
  void dispose() {
    _eventSubscription.cancel();
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
      // Censo completado exitosamente: refrescar datos y mostrar mensaje
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Censo completado exitosamente'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 3),
        ),
      );
      // Refrescar los equipos del cliente
      await _viewModel.refresh();
    }

    // Notificar al ViewModel del resultado
    _viewModel.onNavigationResult(result);
  }

  void _navigateToEquipoDetail(dynamic equipoData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EquiposClientesDetailScreen(
          equipoCliente: equipoData, // Pasar directamente el QueryRow/Map
        ),
      ),
    ).then((_) => _viewModel.refresh());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _viewModel.refresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              top: 16.0,
              bottom: 16.0 + MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildClienteInfoCard(),
                const SizedBox(height: 24),
                _buildEquiposSection(),
              ],
            ),
          ),
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

  Widget _buildEquiposSection() {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, child) {
        if (_viewModel.isLoading) {
          return _buildLoadingState();
        }

        if (_viewModel.hasError) {
          return _buildErrorState();
        }

        if (_viewModel.noTieneEquipos) {
          return _buildEmptyState();
        }

        // NUEVA ESTRUCTURA: Secciones separadas
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sección de Equipos Asignados
            if (_viewModel.tieneEquiposAsignados) ...[
              _buildEquiposSectionHeader(
                title: 'Equipos Asignados',
                count: _viewModel.equiposAsignadosCount,
                icon: Icons.check_circle_outline,
                isAsignado: true,
              ),
              const SizedBox(height: 16),
              _buildEquiposList(_viewModel.equiposAsignadosList, isAsignado: true),
              const SizedBox(height: 24),
            ],

            // Sección de Equipos Pendientes
            if (_viewModel.tieneEquiposPendientes) ...[
              _buildEquiposSectionHeader(
                title: 'Equipos Pendientes',
                count: _viewModel.equiposPendientesCount,
                icon: Icons.pending_outlined,
                isAsignado: false,
              ),
              const SizedBox(height: 16),
              _buildEquiposList(_viewModel.equiposPendientesList, isAsignado: false),
            ],
          ],
        );
      },
    );
  }

  Widget _buildEquiposSectionHeader({
    required String title,
    required int count,
    required IconData icon,
    required bool isAsignado,
  }) {
    final headerColor = isAsignado ? AppColors.success : AppColors.warning;
    final backgroundColor = isAsignado ? AppColors.successContainer : AppColors.warningContainer;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: headerColor,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: headerColor,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: headerColor.withOpacity(0.3)),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: headerColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEquiposList(List<Map<String, dynamic>> equipos, {required bool isAsignado}) {
    final equipoColor = isAsignado ? AppColors.success : AppColors.warning;
    final borderColor = isAsignado ? AppColors.borderSuccess : AppColors.borderWarning;
    final backgroundColor = isAsignado ? AppColors.successContainer : AppColors.warningContainer;

    return Column(
      children: equipos.map((equipoData) {
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
                                  _viewModel.getEquipoTitle(equipoData),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // Contenedor para badge + ícono de sync en línea horizontal
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: backgroundColor,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: borderColor),
                                    ),
                                    child: Text(
                                      isAsignado ? 'ASIGNADO' : 'PENDIENTE',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: equipoColor,
                                      ),
                                    ),
                                  ),
                                  // NUEVO: Ícono de sincronización compacto
                                  const SizedBox(width: 6),
                                  _buildSyncIcon(equipoData),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (_viewModel.getEquipoBarcode(equipoData) != null)
                            Text(
                              _viewModel.getEquipoBarcode(equipoData)!,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                                fontFamily: 'monospace',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (_viewModel.getEquipoLogo(equipoData) != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Logo: ${_viewModel.getEquipoLogo(equipoData)}',
                              style: TextStyle(
                                fontSize: 12,
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
                                Text(
                                  _viewModel.getEquipoFechaCensado(equipoData),
                                  style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textTertiary),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // MÉTODO SEPARADO PARA EL ÍCONO DE SINCRONIZACIÓN
  Widget _buildSyncIcon(Map<String, dynamic> equipoData) {
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

        if (estadoInfo['todos_migrados'] == true) {
          iconColor = AppColors.success;
          icon = Icons.cloud_done;
          tooltip = 'Sincronizado con servidor';
        } else if (estadoInfo['tiene_pendientes'] == true) {
          iconColor = AppColors.warning;
          icon = Icons.cloud_upload;
          final pendientes = estadoInfo['pendientes_count'] ?? 0;
          tooltip = pendientes > 1
              ? '$pendientes registros pendientes'
              : 'Sincronización pendiente';
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
  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
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
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderError),
      ),
      child: Column(
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
            onPressed: _viewModel.cargarEquiposAsignados,
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

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.kitchen_outlined, size: 64, color: AppColors.neutral400),
          const SizedBox(height: 16),
          Text(
            _viewModel.getEmptyStateTitle(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _viewModel.getEmptyStateSubtitle(),
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _viewModel.navegarAAsignarEquipo,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Realizar Censo'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );

  }
}