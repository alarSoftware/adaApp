// ui/screens/equipo_list_screen.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:ada_app/viewmodels/equipos_screen_viewmodel.dart';
import 'package:ada_app/ui/theme/colors.dart';

class EquipoListScreen extends StatefulWidget {
  const EquipoListScreen({super.key});

  @override
  State<EquipoListScreen> createState() => _EquipoListScreenState();
}

class _EquipoListScreenState extends State<EquipoListScreen> {
  late EquipoListScreenViewModel _viewModel;
  late StreamSubscription<EquipoListUIEvent> _eventSubscription;

  @override
  void initState() {
    super.initState();
    _viewModel = EquipoListScreenViewModel();
    _setupEventListener();
    _viewModel.initialize();
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

      if (event is ShowSnackBarEvent) {
        _showSnackBar(event.message, event.color, event.durationSeconds);
      } else if (event is ShowEquipoDetailsEvent) {
        _showEquipoDetails(event.equipo);
      }
    });
  }

  void _showSnackBar(String message, Color color, int durationSeconds) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: Duration(seconds: durationSeconds),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showEquipoDetails(Map<String, dynamic> equipo) {
    final nombreCompleto = _viewModel.getEquipoNombreCompleto(equipo);

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
                _buildDetalleRow('Código', equipo['cod_barras'] ?? 'N/A'),
                _buildDetalleRow('Marca', equipo['marca_nombre'] ?? 'Sin marca'),
                _buildDetalleRow('Modelo', equipo['modelo_nombre'] ?? 'Sin modelo'),
                _buildDetalleRow('Logo', equipo['logo_nombre'] ?? 'Sin logo'),
                if (equipo['numero_serie'] != null)
                  _buildDetalleRow('Número de Serie', equipo['numero_serie']),
                _buildDetalleRow('Estado Local', (equipo['estado_local'] == 1) ? "Activo" : "Inactivo"),
                _buildDetalleRow('Estado Asignación', _viewModel.getEstadoAsignacion(equipo)),
                if (equipo['cliente_nombre'] != null)
                  _buildDetalleRow('Asignado a', equipo['cliente_nombre']),
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
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, child) {
          return Text(_viewModel.appBarTitle);
        },
      ),
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      elevation: 2,
      shadowColor: AppColors.shadowLight,
      actions: [
        IconButton(
          onPressed: _viewModel.refrescarDatos,
          icon: const Icon(Icons.sync),
          tooltip: 'Actualizar equipos',
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: AppColors.surface,
      child: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, child) {
          return TextField(
            controller: _viewModel.searchController,
            decoration: InputDecoration(
              hintText: _viewModel.searchHint,
              hintStyle: TextStyle(color: AppColors.textTertiary),
              prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
              suffixIcon: _viewModel.shouldShowClearButton
                  ? IconButton(
                icon: Icon(Icons.clear, color: AppColors.textSecondary),
                onPressed: _viewModel.limpiarBusqueda,
              )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.focus, width: 2),
              ),
              filled: true,
              fillColor: AppColors.surfaceVariant,
            ),
            style: TextStyle(color: AppColors.textPrimary),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, child) {
        if (_viewModel.isLoading) {
          return _buildLoadingState();
        }

        if (_viewModel.equiposMostrados.isEmpty) {
          return _buildEmptyState();
        }

        return _buildEquiposList();
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            _viewModel.loadingMessage,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _viewModel.isSearching ? Icons.search_off : Icons.devices,
            size: 80,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            _viewModel.emptyStateTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
          if (_viewModel.shouldShowRefreshButton) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _viewModel.refrescarDatos,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar equipos'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEquiposList() {
    return SafeArea(
      top: false, // El AppBar ya maneja el top
      child: RefreshIndicator(
        onRefresh: _viewModel.refrescarDatos,
        color: AppColors.primary,
        child: ListView.builder(
          controller: _viewModel.scrollController,
          padding: EdgeInsets.only(
            left: 8.0,
            right: 8.0,
            bottom: MediaQuery.of(context).padding.bottom,
          ),
          itemCount: _viewModel.equiposMostrados.length + (_viewModel.cargandoMas ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _viewModel.equiposMostrados.length) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              );
            }

            return _buildEquipoCard(_viewModel.equiposMostrados[index]);
          },
        ),
      ),
    );
  }

  Widget _buildEquipoCard(Map<String, dynamic> equipo) {
    final nombreCompleto = _viewModel.getEquipoNombreCompleto(equipo);
    final logoNombre = equipo['logo_nombre'];
    final estadoAsignacion = _viewModel.getEstadoAsignacion(equipo);
    final clienteNombre = equipo['cliente_nombre'];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      elevation: 2,
      color: AppColors.surface,
      shadowColor: AppColors.shadowLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppColors.border,
          width: 0.5,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        leading: CircleAvatar(
          backgroundColor: _viewModel.getColorByLogo(logoNombre),
          child: Icon(
            _viewModel.getIconByLogo(logoNombre),
            color: AppColors.onPrimary,
            size: 20,
          ),
        ),
        title: Text(
          nombreCompleto,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Logo: ${logoNombre ?? 'Sin logo'}',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            Text(
              'Código: ${equipo['cod_barras'] ?? 'N/A'}',
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 12,
              ),
            ),
            if (equipo['numero_serie'] != null)
              Text(
                'Serie: ${equipo['numero_serie']}',
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 12,
                ),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _viewModel.getEstadoColor(estadoAsignacion),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    estadoAsignacion,
                    style: TextStyle(
                      color: AppColors.onPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (clienteNombre != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      clienteNombre,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 14,
          color: AppColors.textTertiary,
        ),
        onTap: () => _viewModel.mostrarDetallesEquipo(equipo),
      ),
    );
  }
}