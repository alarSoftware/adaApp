import 'package:flutter/material.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/viewmodels/client_screen_viewmodel.dart';
import 'package:ada_app/ui/widgets/app_snackbar.dart';
import 'package:ada_app/ui/widgets/app_loading.dart';
import 'package:ada_app/ui/widgets/app_loading_more.dart';
import 'package:ada_app/ui/widgets/app_empty_state.dart';
import 'package:ada_app/ui/widgets/app_search_bar.dart';
import 'package:ada_app/ui/screens/clientes/client_options_screen.dart';
import 'package:ada_app/ui/widgets/client_status_icon.dart';
import 'package:ada_app/ui/widgets/iconography_dialog.dart';
import 'package:ada_app/services/sync/client_sync_service.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:async';

import 'package:ada_app/main.dart';

class ClienteListScreen extends StatefulWidget {
  const ClienteListScreen({super.key});

  @override
  State<ClienteListScreen> createState() => _ClienteListScreenState();
}

class _ClienteListScreenState extends State<ClienteListScreen> with RouteAware {
  late ClienteListScreenViewModel _viewModel;
  late StreamSubscription<ClienteListUIEvent> _eventSubscription;
  final TextEditingController _searchController = TextEditingController();

  // Variables de estado
  bool _isSyncing = false;
  DateTime? _ultimaSincronizacion;
  bool _necesitaSincronizar = true;

  @override
  void initState() {
    super.initState();
    _viewModel = ClienteListScreenViewModel();
    _setupEventListener();
    _setupSearchListener();
    _verificarEstadoSincronizacion();
    _viewModel.loadClientes();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ModalRoute? modalRoute = ModalRoute.of(context);
    if (modalRoute is PageRoute) {
      MyApp.routeObserver.subscribe(this, modalRoute);
    }
  }

  @override
  void didPopNext() {
    // Auto-refresh when returning to this screen
    _viewModel.refresh();
  }

  @override
  void dispose() {
    MyApp.routeObserver.unsubscribe(this);
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
            builder: (context) => ClientOptionsScreen(cliente: event.cliente),
          ),
        ).then((_) {});
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

  Future<void> _verificarEstadoSincronizacion() async {
    final prefs = await SharedPreferences.getInstance();
    final stringDate = prefs.getString('last_sync_date');

    if (stringDate != null) {
      setState(() {
        _ultimaSincronizacion = DateTime.parse(stringDate);
        final now = DateTime.now();
        final lastSync = _ultimaSincronizacion!;

        _necesitaSincronizar =
            lastSync.year != now.year ||
            lastSync.month != now.month ||
            lastSync.day != now.day;
      });
    } else {
      setState(() {
        _necesitaSincronizar = true;
      });
    }
  }

  //BOTON INDEPENDIENTE DE SINCRONIZACION
  Future<void> _sincronizarClientes() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
    });

    try {
      final resultado = await ClientSyncService.sincronizarClientesDelUsuario();

      if (!mounted) return;

      if (resultado.exito) {
        final cantidadSincronizada = resultado.itemsSincronizados;

        await _viewModel.refresh();

        final now = DateTime.now();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_sync_date', now.toIso8601String());

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

        setState(() {
          _ultimaSincronizacion = now;
          _necesitaSincronizar = false;
        });
      } else {
        final mensaje = resultado.mensaje;

        if (mounted) {
          AppSnackbar.showError(context, mensaje);
        }
      }
    } catch (e) {
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
    final fechaHoy = DateFormat(
      "EEEE, d 'de' MMMM",
      'es',
    ).format(DateTime.now());
    final fechaFormateada = toBeginningOfSentenceCase(fechaHoy);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildReactiveAppBar(fechaString: fechaFormateada),
        body: GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: SafeArea(
            child: Column(
              children: [
                // A. Banner de Advertencia (Naranja)
                /*if (_necesitaSincronizar && !_isSyncing)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      border: Border(
                        bottom: BorderSide(color: Colors.orange.shade200),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orange.shade800,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Ruta sin actualizar",
                                style: TextStyle(
                                  color: Colors.orange.shade900,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                "No has descargado los clientes de hoy.",
                                style: TextStyle(
                                  color: Colors.orange.shade800,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _sincronizarClientes,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.orange.shade900,
                            elevation: 0,
                            side: BorderSide(color: Colors.orange.shade300),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Text("Descargar"),
                        ),
                      ],
                    ),
                  ),*/

                // B. Banner de Carga (Azul)
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
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.blue,
                            ),
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
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: ListenableBuilder(
                    listenable: _viewModel,
                    builder: (context, _) {
                      final state = _viewModel.state;
                      return TabBar(
                        onTap: (index) {
                          String mode = 'all';
                          if (index == 0) mode = 'today_route';
                          if (index == 1) mode = 'visited_today';
                          // index 2 is 'all'
                          _viewModel.setFilterMode(mode);
                        },
                        indicator: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.grey.shade600,
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                        dividerColor: Colors.transparent,
                        indicatorSize: TabBarIndicatorSize.tab,
                        tabs: [
                          Tab(text: "De Hoy (${state.countTodayRoute})"),
                          Tab(text: "Visitados (${state.countVisitedToday})"),
                          Tab(text: "Todos (${state.countAll})"),
                        ],
                      );
                    },
                  ),
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
                            itemCount:
                                _viewModel.displayedClientes.length +
                                (_viewModel.hasMoreData ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index ==
                                  _viewModel.displayedClientes.length) {
                                return const AppLoadingMore();
                              }

                              final cliente =
                                  _viewModel.displayedClientes[index];
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
        ),
      ),
    );
  }

  PreferredSizeWidget _buildReactiveAppBar({required String fechaString}) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight + 10),
      child: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, child) {
          return AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lista de Clientes (${_viewModel.displayedClientes.length})',
                  style: TextStyle(
                    color: AppColors.appBarForeground,
                    fontSize: 18,
                  ),
                ),
                Text(
                  fechaString,
                  style: TextStyle(
                    color: AppColors.appBarForeground.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.appBarBackground,
            foregroundColor: AppColors.appBarForeground,
            elevation: 2,
            shadowColor: AppColors.shadowLight,
            actions: [
              IconButton(
                onPressed: _isSyncing ? null : _sincronizarClientes,
                icon: _isSyncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Icon(
                        /*_necesitaSincronizar
                            ? Icons.notification_important
                            : */
                        Icons.sync,
                        color: /*_necesitaSincronizar
                            ? Colors.orangeAccent
                            : */
                            AppColors.appBarForeground,
                      ),
                tooltip: 'Sincronizar clientes',
              ),
              IconButton(
                onPressed: _onRefresh,
                icon: Icon(Icons.refresh, color: AppColors.appBarForeground),
                tooltip: 'Actualizar lista',
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: AppColors.appBarForeground),
                onSelected: (value) {
                  if (value == 'simbologia') {
                    showDialog(
                      context: context,
                      builder: (context) => const IconographyDialog(),
                    );
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'simbologia',
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.textPrimary),
                        SizedBox(width: 12),
                        Text('Simbología de iconos'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
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
        side: BorderSide(color: AppColors.border, width: 0.5),
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
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${cliente.tipoDocumento}: ${cliente.rucCi}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: cliente.esCredito
                            ? AppColors.warning.withValues(alpha: 0.1)
                            : AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: cliente.esCredito
                              ? AppColors.warning.withValues(alpha: 0.5)
                              : AppColors.success.withValues(alpha: 0.5),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        cliente.displayCondicionVenta,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: cliente.esCredito
                              ? AppColors.warning
                              : AppColors.success,
                        ),
                      ),
                    ),
                    ClientStatusIcons(
                      tieneCensoHoy: cliente.tieneCensoHoy,
                      tieneFormularioCompleto: cliente.tieneFormularioCompleto,
                      tieneOperacionComercialHoy:
                          cliente.tieneOperacionComercialHoy,
                      iconSize: 14,
                    ),
                  ],
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
}
