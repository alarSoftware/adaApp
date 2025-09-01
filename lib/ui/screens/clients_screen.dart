// ui/screens/clients_screen.dart
import 'package:flutter/material.dart';
import 'package:ada_app/ui/screens/cliente_detail_screen.dart';
import 'package:ada_app/ui/theme/colors.dart';
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
      backgroundColor: AppColors.background,
      appBar: _buildReactiveAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            AppSearchBar(
              controller: _searchController,
              hintText: 'Buscar cliente por nombre, email o teléfono...',
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
                      color: AppColors.primary,
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Icon(
            Icons.person,
            color: AppColors.primary,
            size: 24,
          ),
        ),
        title: Text(
          cliente.nombre,
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
              Text(
                cliente.email,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
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
                      color: AppColors.textTertiary,
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
              style: TextStyle(color: AppColors.onPrimary),
            ),
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            elevation: 2,
            shadowColor: AppColors.shadowLight,
            actions: [
              IconButton(
                onPressed: _onRefresh,
                icon: Icon(
                  Icons.refresh,
                  color: AppColors.onPrimary,
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