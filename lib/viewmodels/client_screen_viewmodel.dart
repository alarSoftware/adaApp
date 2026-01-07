import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import '../models/cliente.dart';
import '../repositories/cliente_repository.dart';

abstract class ClienteListUIEvent {}

class ShowErrorEvent extends ClienteListUIEvent {
  final String message;
  ShowErrorEvent(this.message);
}

class NavigateToDetailEvent extends ClienteListUIEvent {
  final Cliente cliente;
  NavigateToDetailEvent(this.cliente);
}

class ClienteListState {
  final bool isLoading;
  final bool isLoadingMore;
  final List<Cliente> displayedClientes;
  final String searchQuery;
  final bool hasMoreData;
  final int currentPage;
  final int totalCount;
  final String? error;
  final String? filterMode;
  final int countTodayRoute;
  final int countVisitedToday;
  final int countAll;

  ClienteListState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.displayedClientes = const [],
    this.searchQuery = '',
    this.hasMoreData = true,
    this.currentPage = 0,
    this.totalCount = 0,
    this.error,
    this.filterMode = 'today_route',
    this.countTodayRoute = 0,
    this.countVisitedToday = 0,
    this.countAll = 0,
  });

  ClienteListState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    List<Cliente>? displayedClientes,
    String? searchQuery,
    String? selectedDia,
    bool clearSelectedDia = false,
    bool? hasMoreData,
    int? currentPage,
    int? totalCount,
    String? error,
    String? filterMode,
    int? countTodayRoute,
    int? countVisitedToday,
    int? countAll,
  }) {
    return ClienteListState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      displayedClientes: displayedClientes ?? this.displayedClientes,
      searchQuery: searchQuery ?? this.searchQuery,
      hasMoreData: hasMoreData ?? this.hasMoreData,
      currentPage: currentPage ?? this.currentPage,
      totalCount: totalCount ?? this.totalCount,
      error: error ?? this.error,
      filterMode: filterMode ?? this.filterMode,
      countTodayRoute: countTodayRoute ?? this.countTodayRoute,
      countVisitedToday: countVisitedToday ?? this.countVisitedToday,
      countAll: countAll ?? this.countAll,
    );
  }
}

class ClienteListScreenViewModel extends ChangeNotifier {
  final ClienteRepository _repository = ClienteRepository();

  static const int clientesPorPagina = 10;
  static const Duration searchDelay = Duration(milliseconds: 100);

  ClienteListState _state = ClienteListState();
  List<Cliente> _allClientes = [];
  List<Cliente> _filteredClientes = [];
  Timer? _searchTimer;

  final StreamController<ClienteListUIEvent> _eventController =
      StreamController<ClienteListUIEvent>.broadcast();
  Stream<ClienteListUIEvent> get uiEvents => _eventController.stream;

  ClienteListState get state => _state;
  bool get isLoading => _state.isLoading;
  bool get isLoadingMore => _state.isLoadingMore;
  List<Cliente> get displayedClientes => _state.displayedClientes;
  String get searchQuery => _state.searchQuery;
  bool get hasMoreData => _state.hasMoreData;
  int get totalCount => _state.totalCount;
  bool get isEmpty => _state.displayedClientes.isEmpty && !_state.isLoading;

  @override
  void dispose() {
    _searchTimer?.cancel();
    _eventController.close();
    super.dispose();
  }

  void updateSelectedDia(String? dia) {
    _updateState(_state.copyWith(selectedDia: dia));
    _applyFilters();
  }

  void clearDiaFilter() {
    _updateState(_state.copyWith(clearSelectedDia: true));
    _applyFilters();
  }

  void setFilterMode(String mode) {
    if (_state.filterMode == mode) return;
    _updateState(_state.copyWith(filterMode: mode));
    _applyFilters();
  }

  Future<void> _applyFilters() async {
    try {
      List<Cliente> resultados;
      final query = _state.searchQuery.toLowerCase().trim();
      List<Cliente> baseList = _allClientes;

      if (_state.filterMode == 'today_route') {
        final now = DateTime.now();
        String diaHoy;
        try {
          diaHoy = DateFormat('EEEE', 'es').format(now).toLowerCase().trim();
        } catch (e) {
          final englishDay = DateFormat(
            //Cambio de idioma para los dias de la semana para evitar que la consulta sql no funcione
            'EEEE',
          ).format(now).toLowerCase().trim();
          const dayMap = {
            'monday': 'lunes',
            'tuesday': 'martes',
            'wednesday': 'miércoles',
            'thursday': 'jueves',
            'friday': 'viernes',
            'saturday': 'sábado',
            'sunday': 'domingo',
          };
          diaHoy = dayMap[englishDay] ?? englishDay;
        }

        baseList = baseList.where((c) {
          if (c.rutaDia == null || c.rutaDia!.isEmpty) return false;

          final rutasCliente = c.rutaDia!.toLowerCase();

          final dias = rutasCliente.split(',').map((d) {
            return d.trim();
          }).toList();

          return dias.contains(diaHoy);
        }).toList();
      } else if (_state.filterMode == 'visited_today') {
        baseList = baseList.where((c) {
          return c.tieneCensoHoy ||
              c.tieneOperacionComercialHoy ||
              c.tieneFormularioCompleto;
        }).toList();
      }

      // 2. Filtrar por Búsqueda
      if (query.isEmpty) {
        resultados = List.from(baseList);
      } else {
        resultados = baseList.where((cliente) {
          final nombreMatches = cliente.nombre.toLowerCase().contains(query);
          final rucMatches = cliente.rucCi.toLowerCase().contains(query);
          final codigoMatches = cliente.codigo.toString().contains(query);
          final propMatches = cliente.propietario.toLowerCase().contains(query);

          return nombreMatches || rucMatches || codigoMatches || propMatches;
        }).toList();
      }

      _filteredClientes = resultados;
      _updateState(
        _state.copyWith(
          currentPage: 0,
          displayedClientes: [],
          hasMoreData: true,
          totalCount: resultados.length,
          error: null, // Limpiar error si hubo
        ),
      );

      await _loadNextPage();
    } catch (e) {
      _eventController.add(ShowErrorEvent('Error al filtrar: $e'));
    }
  }

  void _calculateCount() {
    final now = DateTime.now();
    String diaHoy;
    try {
      diaHoy = DateFormat('EEEE', 'es').format(now).toLowerCase().trim();
    } catch (e) {
      final englishDay = DateFormat('EEEE').format(now).toLowerCase().trim();
      const dayMap = {
        'monday': 'lunes',
        'tuesday': 'martes',
        'wednesday': 'miércoles',
        'thursday': 'jueves',
        'friday': 'viernes',
        'saturday': 'sábado',
        'sunday': 'domingo',
      };
      diaHoy = dayMap[englishDay] ?? englishDay;
    }

    final rutaHoyCount = _allClientes.where((c) {
      if (c.rutaDia == null || c.rutaDia!.isEmpty) return false;
      return c.rutaDia!.toLowerCase().contains(diaHoy);
    }).length;

    final visitadosCount = _allClientes.where((c) {
      return c.tieneCensoHoy ||
          c.tieneOperacionComercialHoy ||
          c.tieneFormularioCompleto;
    }).length;

    final totalCount = _allClientes.length;

    _state = _state.copyWith(
      countTodayRoute: rutaHoyCount,
      countVisitedToday: visitadosCount,
      countAll: totalCount,
    );
    notifyListeners();
  }

  Future<void> loadClientes() async {
    _updateState(
      _state.copyWith(
        isLoading: true,
        currentPage: 0,
        displayedClientes: [],
        error: null,
      ),
    );

    try {
      // Cargar TODOS los clientes una sola vez
      final clientesDB = await _repository.buscarConFiltros(query: '');

      _allClientes = clientesDB;
      // _filteredClientes = clientesDB; // FIX: No asignar todos por defecto, esperar al filtro

      _calculateCount();

      // Aplicar filtros siempre para respetar el filterMode inicial
      await _applyFilters();

      _updateState(
        _state.copyWith(
          isLoading: false,
          totalCount: _filteredClientes.length, // Usar filtrados, no total DB
          hasMoreData: true,
        ),
      );

      await _loadNextPage();
    } catch (e, stackTrace) {
      _updateState(
        _state.copyWith(
          isLoading: false,
          error: 'Error al cargar clientes: $e',
        ),
      );

      _eventController.add(ShowErrorEvent('Error al cargar clientes: $e'));
    }
  }

  Future<void> refresh() async {
    await loadClientes();
  }

  Future<void> _loadNextPage() async {
    if (!_state.hasMoreData || _state.isLoadingMore) {
      return;
    }

    _updateState(_state.copyWith(isLoadingMore: true));

    await Future.delayed(Duration(milliseconds: 150));

    final startIndex = _state.currentPage * clientesPorPagina;
    final endIndex = startIndex + clientesPorPagina;

    if (startIndex < _filteredClientes.length) {
      final nuevosClientes = _filteredClientes
          .skip(startIndex)
          .take(clientesPorPagina)
          .toList();

      final updatedDisplayedClientes = List<Cliente>.from(
        _state.displayedClientes,
      )..addAll(nuevosClientes);

      final newHasMoreData = endIndex < _filteredClientes.length;
      final newCurrentPage = _state.currentPage + 1;

      _updateState(
        _state.copyWith(
          displayedClientes: updatedDisplayedClientes,
          currentPage: newCurrentPage,
          hasMoreData: newHasMoreData,
          isLoadingMore: false,
        ),
      );
    } else {
      _updateState(_state.copyWith(hasMoreData: false, isLoadingMore: false));
    }
  }

  Future<void> loadMoreClientes() async {
    await _loadNextPage();
  }

  void updateSearchQuery(String query) {
    _searchTimer?.cancel();

    _updateState(_state.copyWith(searchQuery: query));

    if (query.trim().isEmpty) {
      _resetSearch();
      return;
    }

    _searchTimer = Timer(searchDelay, () => _performSearch(query));
  }

  void clearSearch() {
    _searchTimer?.cancel();
    _updateState(_state.copyWith(searchQuery: ''));
    _resetSearch();
  }

  void _resetSearch() {
    _applyFilters();
  }

  Future<void> _performSearch(String query) async {
    try {
      await _applyFilters();
    } catch (e) {
      _eventController.add(ShowErrorEvent('Error en la búsqueda: $e'));
    }
  }

  void navigateToClienteDetail(Cliente cliente) {
    _eventController.add(NavigateToDetailEvent(cliente));
  }

  String getInitials(Cliente cliente) {
    return cliente.nombre.isNotEmpty ? cliente.nombre[0].toUpperCase() : '?';
  }

  bool shouldShowPhone(Cliente cliente) {
    return cliente.telefono.isNotEmpty;
  }

  String getEmptyStateTitle() {
    return _state.searchQuery.isEmpty
        ? 'No hay clientes'
        : 'No se encontraron clientes';
  }

  String getEmptyStateSubtitle() {
    if (_state.searchQuery.isEmpty) {
      return 'No hay clientes registrados en el sistema';
    }

    List<String> filtros = [];
    if (_state.searchQuery.isNotEmpty) {
      filtros.add('búsqueda: "${_state.searchQuery}"');
    }

    return 'con ${filtros.join(' y ')}';
  }

  void _updateState(ClienteListState newState) {
    _state = newState;
    notifyListeners();
  }

  Map<String, dynamic> getDebugInfo() {
    return {
      'total_clientes': _allClientes.length,
      'clientes_filtrados': _filteredClientes.length,
      'clientes_mostrados': _state.displayedClientes.length,
      'pagina_actual': _state.currentPage,
      'tiene_mas_datos': _state.hasMoreData,
      'query_busqueda': _state.searchQuery,
      'esta_cargando': _state.isLoading,
      'esta_cargando_mas': _state.isLoadingMore,
    };
  }

  void logDebugInfo() {}
}
