import 'package:flutter/material.dart';
import 'package:ada_app/ui/theme/colors.dart';
import 'package:ada_app/viewmodels/client_screen_viewmodel.dart';
import 'package:ada_app/ui/widgets/app_snackbar.dart';
import 'package:ada_app/ui/widgets/app_loading.dart';
import 'package:ada_app/ui/widgets/app_loading_more.dart';
import 'package:ada_app/ui/widgets/app_empty_state.dart';
import 'package:ada_app/ui/widgets/app_search_bar.dart';
import 'package:ada_app/ui/screens/client_options_screen.dart';
import 'package:ada_app/ui/widgets/client_status_icon.dart';
import 'package:ada_app/services/sync/client_sync_service.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  // Variables de estado
  bool _isSyncing = false;
  DateTime? _ultimaSincronizacion;
  bool _necesitaSincronizar = true;

  // Lista de días de la semana
  final List<String> _diasSemana = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  @override
  void initState() {
    super.initState();
    _viewModel = ClienteListScreenViewModel();
    _setupEventListener();
    _setupSearchListener();
    _viewModel.initialize();
    _verificarEstadoSincronizacion();
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

  Future<void> _verificarEstadoSincronizacion() async {
    final prefs = await SharedPreferences.getInstance();
    final stringDate = prefs.getString('last_sync_date');

    if (stringDate != null) {
      setState(() {
        _ultimaSincronizacion = DateTime.parse(stringDate);
        final now = DateTime.now();
        final lastSync = _ultimaSincronizacion!;

        _necesitaSincronizar = lastSync.year != now.year ||
            lastSync.month != now.month ||
            lastSync.day != now.day;
      });
    } else {
      setState(() {
        _necesitaSincronizar = true;
      });
    }
  }

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
        _logger.e('Error sincronizando clientes: $mensaje');

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
    final fechaHoy = DateFormat("EEEE, d 'de' MMMM", 'es').format(DateTime.now());
    final fechaFormateada = toBeginningOfSentenceCase(fechaHoy) ?? fechaHoy;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildReactiveAppBar(fechaString: fechaFormateada),
      body: SafeArea(
        child: Column(
          children: [
            // A. Banner de Advertencia (Naranja)
            if (_necesitaSincronizar && !_isSyncing)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border(
                    bottom: BorderSide(color: Colors.orange.shade200),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
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
                                fontSize: 12
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
                    )
                  ],
                ),
              ),

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

            // C. Selector de Día de Ruta (Chips Horizontales)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: AppColors.border),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Filtrar por día de ruta',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      ListenableBuilder(
                        listenable: _viewModel,
                        builder: (context, child) {
                          if (_viewModel.selectedDia != null) {
                            return TextButton(
                              onPressed: () => _viewModel.clearDiaFilter(),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(50, 30),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Ver todos',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.buttonPrimary,
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ListenableBuilder(
                      listenable: _viewModel,
                      builder: (context, child) {
                        return Row(
                          children: _diasSemana.map((dia) {
                            final isSelected = _viewModel.selectedDia == dia;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(dia),
                                selected: isSelected,
                                onSelected: (selected) {
                                  _viewModel.updateSelectedDia(selected ? dia : null);
                                },
                                backgroundColor: Colors.grey[100],
                                selectedColor: AppColors.buttonPrimary.withOpacity(0.2),
                                checkmarkColor: AppColors.buttonPrimary,
                                labelStyle: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  color: isSelected ? AppColors.buttonPrimary : AppColors.textSecondary,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: isSelected ? AppColors.buttonPrimary : AppColors.border,
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // D. Buscador
            AppSearchBar(
              controller: _searchController,
              hintText: 'Buscar por nombre, codigo o documento...',
              onClear: _onClearSearch,
            ),

            // E. Lista
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
                      fontSize: 18
                  ),
                ),
                Text(
                  fechaString,
                  style: TextStyle(
                    color: AppColors.appBarForeground.withOpacity(0.8),
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
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : Icon(
                  _necesitaSincronizar ? Icons.notification_important : Icons.sync,
                  color: _necesitaSincronizar ? Colors.orangeAccent : AppColors.appBarForeground,
                ),
                tooltip: 'Sincronizar clientes',
              ),
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
                        maxLines: 1,
                      ),
                    ),
                    ClientStatusIcons(
                      tieneCensoHoy: cliente.tieneCensoHoy,
                      tieneFormularioCompleto: cliente.tieneFormularioCompleto,
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