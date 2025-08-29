// ui/screens/clients_screen.dart
import 'package:flutter/material.dart';
import 'package:ada_app/ui/screens/cliente_detail_screen.dart';
import 'package:ada_app/viewmodels/client_screen_viewmodel.dart';
import 'package:ada_app/ui/widgets/app_snackbar.dart';
import 'package:ada_app/ui/widgets/app_loading.dart';
import 'package:ada_app/ui/widgets/app_loading_more.dart';
import 'package:ada_app/ui/widgets/app_empty_state.dart';
import 'package:ada_app/ui/widgets/app_search_bar.dart';
import 'dart:async';

class ClienteListScreen extends StatefulWidget {
  const ClienteListScreen({super.key});

  @override
  _ClienteListScreenState createState() => _ClienteListScreenState();
}

class _ClienteListScreenState extends State<ClienteListScreen> {
  late ClienteListScreenViewModel _viewModel;
  late StreamSubscription<ClienteListUIEvent> _eventSubscription;
  final TextEditingController _searchController = TextEditingController();

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
    _eventSubscription = _viewModel.uiEvents.listen((event) {
      if (!mounted) return;

      if (event is ShowErrorEvent) {
        AppSnackbar.showError(context, event.message);
      } else if (event is NavigateToDetailEvent) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ClienteDetailScreen(cliente: event.cliente),
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildReactiveAppBar(),
      body: Column(
        children: [
          // Barra de búsqueda
          AppSearchBar(
            controller: _searchController,
            hintText: 'Buscar cliente por nombre, email o teléfono...',
            onClear: _onClearSearch,
          ),

          // Contenido principal
          Expanded(
            child: ListenableBuilder(
              listenable: _viewModel,
              builder: (context, child) {
                // Estado de carga inicial
                if (_viewModel.isLoading) {
                  return AppLoading(message: 'Cargando clientes...');
                }

                // Estado vacío
                if (_viewModel.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.people_outline,
                    title: _viewModel.getEmptyStateTitle(),
                    subtitle: _viewModel.getEmptyStateSubtitle(),
                  );
                }

                // Lista con datos
                return NotificationListener<ScrollNotification>(
                  onNotification: _onScrollNotification,
                  child: RefreshIndicator(
                    onRefresh: _onRefresh,
                    color: Colors.grey[700],
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: _viewModel.displayedClientes.length +
                          (_viewModel.hasMoreData ? 1 : 0),
                      itemBuilder: (context, index) {
                        // Indicador de carga para más elementos
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
    );
  }

  Widget _buildClienteCard(cliente) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Colors.grey[700],
          foregroundColor: Colors.white,
          child: Text(
            _viewModel.getInitials(cliente),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          cliente.nombre,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
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
              Text(
                cliente.email,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              if (_viewModel.shouldShowPhone(cliente))
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    cliente.telefono!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey[400],
            ),
          ],
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
            title: Text('Lista de Clientes (${_viewModel.displayedClientes.length})'),
            backgroundColor: Colors.grey[800],
            foregroundColor: Colors.white,
            elevation: 2,
            actions: [
              IconButton(
                onPressed: _onRefresh,
                icon: const Icon(Icons.refresh),
                tooltip: 'Actualizar lista',
              ),
            ],
          );
        },
      ),
    );
  }
}