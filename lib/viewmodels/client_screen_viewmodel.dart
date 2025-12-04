import 'package:flutter/foundation.dart';
import 'dart:async';
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
  final String? selectedDia;
  final bool hasMoreData;
  final int currentPage;
  final int totalCount;
  final String? error;

  ClienteListState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.displayedClientes = const [],
    this.searchQuery = '',
    this.selectedDia,
    this.hasMoreData = true,
    this.currentPage = 0,
    this.totalCount = 0,
    this.error,
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
  }) {
    return ClienteListState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      displayedClientes: displayedClientes ?? this.displayedClientes,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedDia: clearSelectedDia ? null : (selectedDia ?? this.selectedDia),
      hasMoreData: hasMoreData ?? this.hasMoreData,
      currentPage: currentPage ?? this.currentPage,
      totalCount: totalCount ?? this.totalCount,
      error: error ?? this.error,
    );
  }
}

class ClienteListScreenViewModel extends ChangeNotifier {
  final ClienteRepository _repository = ClienteRepository();

  static const int clientesPorPagina = 10;
  static const Duration searchDelay = Duration(milliseconds: 500);

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
  String? get selectedDia => _state.selectedDia;
  bool get hasMoreData => _state.hasMoreData;
  int get totalCount => _state.totalCount;
  bool get isEmpty => _state.displayedClientes.isEmpty && !_state.isLoading;

  @override
  void dispose() {
    _searchTimer?.cancel();
    _eventController.close();
    super.dispose();
  }

  String _getDiaActual() {
    final diasSemana = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    final now = DateTime.now();
    return diasSemana[now.weekday - 1];
  }

  Future<void> initialize() async {
    final diaActual = _getDiaActual();
    _updateState(_state.copyWith(selectedDia: diaActual));
    await loadClientes();
  }

  void updateSelectedDia(String? dia) {
    _updateState(_state.copyWith(selectedDia: dia));
    _applyFilters();
  }

  void clearDiaFilter() {
    _updateState(_state.copyWith(clearSelectedDia: true));
    _applyFilters();
  }

  Future<void> _applyFilters() async {
    try {
      final resultados = await _repository.buscarConFiltros(
        query: _state.searchQuery,
        rutaDia: _state.selectedDia,
      );

      _filteredClientes = resultados;
      _updateState(_state.copyWith(
        currentPage: 0,
        displayedClientes: [],
        hasMoreData: true,
        totalCount: resultados.length,
      ));

      await _loadNextPage();
    } catch (e) {
      _eventController.add(ShowErrorEvent('Error al filtrar: $e'));
    }
  }

  Future<void> loadClientes() async {
    _updateState(_state.copyWith(
      isLoading: true,
      currentPage: 0,
      displayedClientes: [],
      error: null,
    ));

    try {
      final clientesDB = await _repository.buscarConFiltros(
        query: _state.searchQuery,
        rutaDia: _state.selectedDia,
      );

      _allClientes = clientesDB;
      _filteredClientes = clientesDB;

      _updateState(_state.copyWith(
        isLoading: false,
        totalCount: clientesDB.length,
        hasMoreData: true,
      ));

      await _loadNextPage();
    } catch (e, stackTrace) {
      _updateState(_state.copyWith(
        isLoading: false,
        error: 'Error al cargar clientes: $e',
      ));

      _eventController.add(ShowErrorEvent('Error al cargar clientes: $e'));
    }
  }

  Future<void> refresh() async {
    if (_state.searchQuery.isNotEmpty || _state.selectedDia != null) {
      await _applyFilters();
    } else {
      await loadClientes();
    }
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

      final updatedDisplayedClientes = List<Cliente>.from(_state.displayedClientes)
        ..addAll(nuevosClientes);

      final newHasMoreData = endIndex < _filteredClientes.length;
      final newCurrentPage = _state.currentPage + 1;

      _updateState(_state.copyWith(
        displayedClientes: updatedDisplayedClientes,
        currentPage: newCurrentPage,
        hasMoreData: newHasMoreData,
        isLoadingMore: false,
      ));
    } else {
      _updateState(_state.copyWith(
        hasMoreData: false,
        isLoadingMore: false,
      ));
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
    return _state.searchQuery.isEmpty && _state.selectedDia == null
        ? 'No hay clientes'
        : 'No se encontraron clientes';
  }

  String getEmptyStateSubtitle() {
    if (_state.searchQuery.isEmpty && _state.selectedDia == null) {
      return 'No hay clientes registrados en el sistema';
    }

    List<String> filtros = [];
    if (_state.searchQuery.isNotEmpty) {
      filtros.add('búsqueda: "${_state.searchQuery}"');
    }
    if (_state.selectedDia != null) {
      filtros.add('día: ${_state.selectedDia}');
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
      'dia_seleccionado': _state.selectedDia,
      'esta_cargando': _state.isLoading,
      'esta_cargando_mas': _state.isLoadingMore,
    };
  }

  void logDebugInfo() {
  }
}