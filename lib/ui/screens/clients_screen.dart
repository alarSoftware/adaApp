import 'package:flutter/material.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/viewmodels/client_screen_viewmodel.dart';
import 'package:ada_app/ui/widgets/app_snackbar.dart';
import 'package:ada_app/ui/widgets/app_loading.dart';
import 'package:ada_app/ui/widgets/app_loading_more.dart';
import 'package:ada_app/ui/widgets/app_empty_state.dart';
import 'package:ada_app/ui/widgets/app_search_bar.dart';
import 'package:ada_app/ui/screens/client_options_screen.dart';
import 'package:ada_app/services/sync/client_sync_service.dart';
import 'package:logger/logger.dart';
import 'dart:async';

final _logger = Logger();

class ClienteListScreen extends StatefulWidget {
  const ClienteListScreen({super.key});

  @override
  _ClienteListScreenState createState() => _ClienteListScreenState();
}

class _ClienteListScreenState extends State<ClienteListScreen> {
  late ClienteListScreenViewModel _viewModel;
  late StreamSubscription<ClienteListUIEvent> _eventSubscription;
  final TextEditingController _searchController = TextEditingController();
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _viewModel = ClienteListScreenViewModel();
    _setupEventListener();
    _setupSearchListener();
    _viewModel.initialize();
  }

  @override
  void dispose() {
    _eventSubscription.cancel();
    _searchController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  void _setupEventListener() {
    _eventSubscription =
        _viewModel.uiEvents.listen((event) {
      if (!mounted) return;

      if (event is ShowErrorEvent) {
        AppSnackbar.showError(context, event.message);
      } else if (event is NavigateToDetailEvent) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ClientOptionsScreen(cliente: event.cliente),
          ),
        ).then((_) {
          // Opcional: refrescar lista de clientes si es necesario
        });
      }
    });
  }

  void _setupSearchListener() {
    _searchController.addListener(() {
      _viewModel.updateSearchQuery(_searchController.text);
    });
  }

  Future<void> _onRefresh() async {
    await _viewModel.refresh();
  }

  void _onClearSearch() {
    _viewModel.clearSearch();
  }

  bool _onScrollNotification(ScrollNotification scrollInfo) {
    if (!_viewModel.isLoadingMore &&
        _viewModel.hasMoreData &&
        scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
      _viewModel.loadMoreClientes();
    }
    return false;
  }

  Future<void> _sincronizarClientes() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
    });

    try {
      _logger.i('Iniciando sincronización de clientes desde el servidor...');

      // Usar el método correcto del ClientSyncService
      final resultado = await ClientSyncService.sincronizarClientesDelUsuario();

      if (!mounted) return;

      if (resultado.exito) {
        final cantidadSincronizada = resultado.itemsSincronizados;
        _logger.i('Clientes sincronizados exitosamente: $cantidadSincronizada');

        // Recargar la lista de clientes
        await _viewModel.refresh();

        // Mostrar mensaje de éxito
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                cantidadSincronizada > 0
                    ? 'Se sincronizaron $cantidadSincronizada cliente${cantidadSincronizada != 1 ? 's' : ''} exitosamente'
                    : resultado.mensaje,
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        final mensaje = resultado.mensaje;
        _logger.e('Error sincronizando clientes: $mensaje');

        // Mostrar mensaje de error
        if (mounted) {
          AppSnackbar.showError(context, mensaje);
        }
      }
    } catch (e) {
      _logger.e('Error sincronizando clientes: $e');

      if (mounted) {
        AppSnackbar.showError(
          context,
          'Error al sincronizar clientes: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildReactiveAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            // Banner de sincronización
            if (_isSyncing)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.blue[50],
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Sincronizando clientes...',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

            AppSearchBar(
              controller: _searchController,
              hintText: 'Buscar por nombre, codigo o documento...',
              onClear: _onClearSearch,
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: _viewModel,
                builder: (context, child) {
                  if (_viewModel.isLoading) {
                    return AppLoading(message: 'Cargando clientes...');
                  }

                  if (_viewModel.isEmpty) {
                    return AppEmptyState(
                      icon: Icons.people_outline,
                      title: _viewModel.getEmptyStateTitle(),
                      subtitle: _viewModel.getEmptyStateSubtitle(),
                    );
                  }

                  return NotificationListener<ScrollNotification>(
                    onNotification: _onScrollNotification,
                    child: RefreshIndicator(
                      onRefresh: _onRefresh,
                      color: AppColors.buttonPrimary,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: _viewModel.displayedClientes.length +
                            (_viewModel.hasMoreData ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _viewModel.displayedClientes.length) {
                            return const AppLoadingMore();
                          }

                          final cliente = _viewModel.displayedClientes[index];
                          return _buildClienteCard(cliente);
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClienteCard(cliente) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 2,
      color: AppColors.cardBackground,
      shadowColor: AppColors.shadowLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppColors.border,
          width: 0.5,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        title: Text(
          cliente.displayName,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Propietario
              Text(
                cliente.propietario,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              // RUC/CI
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${cliente.tipoDocumento}: ${cliente.rucCi}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          size: 20,
          color: AppColors.textTertiary,
        ),
        onTap: () => _viewModel.navigateToClienteDetail(cliente),
      ),
    );
  }

  PreferredSizeWidget _buildReactiveAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, child) {
          return AppBar(
            title: Text(
              'Lista de Clientes (${_viewModel.displayedClientes.length})',
              style: TextStyle(color: AppColors.appBarForeground),
            ),
            backgroundColor: AppColors.appBarBackground,
            foregroundColor: AppColors.appBarForeground,
            elevation: 2,
            shadowColor: AppColors.shadowLight,
            actions: [
              // Botón de sincronización
              IconButton(
                onPressed: _isSyncing ? null : _sincronizarClientes,
                icon: _isSyncing
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : Icon(
                  Icons.sync,
                  color: AppColors.appBarForeground,
                ),
                tooltip: 'Sincronizar clientes',
              ),
              // Botón de actualizar
              IconButton(
                onPressed: _onRefresh,
                icon: Icon(
                  Icons.refresh,
                  color: AppColors.appBarForeground,
                ),
                tooltip: 'Actualizar lista',
              ),
            ],
          );
        },
      ),
    );
  }
}