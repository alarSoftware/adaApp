// viewmodels/cliente_list_screen_viewmodel.dart
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:logger/logger.dart';
import '../models/cliente.dart';
import '../repositories/cliente_repository.dart';

// ========== EVENTOS PARA LA UI ==========
abstract class ClienteListUIEvent {}

class ShowErrorEvent extends ClienteListUIEvent {
  final String message;
  ShowErrorEvent(this.message);
}

class NavigateToDetailEvent extends ClienteListUIEvent {
  final Cliente cliente;
  NavigateToDetailEvent(this.cliente);
}

// ========== DATOS PUROS ==========
class ClienteListState {
  final bool isLoading;
  final bool isLoadingMore;
  final List<Cliente> displayedClientes;
  final String searchQuery;
  final bool hasMoreData;
  final int currentPage;
  final int totalCount;
  final String? error;

  ClienteListState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.displayedClientes = const [],
    this.searchQuery = '',
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
      hasMoreData: hasMoreData ?? this.hasMoreData,
      currentPage: currentPage ?? this.currentPage,
      totalCount: totalCount ?? this.totalCount,
      error: error ?? this.error,
    );
  }
}

// ========== VIEWMODEL LIMPIO ==========
class ClienteListScreenViewModel extends ChangeNotifier {
  final Logger _logger = Logger();
  final ClienteRepository _repository = ClienteRepository();

  // ========== CONFIGURACIÓN ==========
  static const int clientesPorPagina = 10;
  static const Duration searchDelay = Duration(milliseconds: 500);

  // ========== ESTADO INTERNO ==========
  ClienteListState _state = ClienteListState();
  List<Cliente> _allClientes = [];
  List<Cliente> _filteredClientes = [];
  Timer? _searchTimer;

  // ========== STREAMS PARA EVENTOS ==========
  final StreamController<ClienteListUIEvent> _eventController =
  StreamController<ClienteListUIEvent>.broadcast();
  Stream<ClienteListUIEvent> get uiEvents => _eventController.stream;

  // ========== GETTERS PÚBLICOS ==========
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

  // ========== INICIALIZACIÓN ==========
  Future<void> initialize() async {
    await loadClientes();
  }

  // ========== CARGA DE DATOS ==========
  Future<void> loadClientes() async {
    _updateState(_state.copyWith(
      isLoading: true,
      currentPage: 0,
      displayedClientes: [],
      error: null,
    ));

    try {
      _logger.i('Cargando clientes desde la base de datos...');

      final clientesDB = await _repository.buscar('');

      _allClientes = clientesDB;
      _filteredClientes = clientesDB;

      _updateState(_state.copyWith(
        isLoading: false,
        totalCount: clientesDB.length,
      ));

      await _loadNextPage();

      _logger.i('Clientes cargados: ${clientesDB.length}');
    } catch (e, stackTrace) {
      _logger.e('Error al cargar clientes', error: e, stackTrace: stackTrace);

      _updateState(_state.copyWith(
        isLoading: false,
        error: 'Error al cargar clientes: $e',
      ));

      _eventController.add(ShowErrorEvent('Error al cargar clientes: $e'));
    }
  }

  // ========== PAGINACIÓN ==========
  Future<void> _loadNextPage() async {
    if (!_state.hasMoreData || _state.isLoadingMore) return;

    _updateState(_state.copyWith(isLoadingMore: true));

    // Simulamos un pequeño delay para mejor UX
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

      _updateState(_state.copyWith(
        displayedClientes: updatedDisplayedClientes,
        currentPage: _state.currentPage + 1,
        hasMoreData: endIndex < _filteredClientes.length,
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

  // ========== BÚSQUEDA ==========
  void updateSearchQuery(String query) {
    _searchTimer?.cancel();

    _updateState(_state.copyWith(searchQuery: query));

    if (query.trim().isEmpty) {
      _resetSearch();
      return;
    }

    // Debounce la búsqueda
    _searchTimer = Timer(searchDelay, () => _performSearch(query));
  }

  void clearSearch() {
    _searchTimer?.cancel();
    _updateState(_state.copyWith(searchQuery: ''));
    _resetSearch();
  }

  void _resetSearch() {
    _filteredClientes = _allClientes;
    _updateState(_state.copyWith(
      currentPage: 0,
      displayedClientes: [],
      hasMoreData: true,
    ));
    _loadNextPage();
  }

  Future<void> _performSearch(String query) async {
    try {
      _logger.i('Buscando clientes con query: "$query"');

      final resultados = await _repository.buscar(query);

      _filteredClientes = resultados;
      _updateState(_state.copyWith(
        currentPage: 0,
        displayedClientes: [],
        hasMoreData: true,
        totalCount: resultados.length,
      ));

      await _loadNextPage();

      _logger.i('Búsqueda completada: ${resultados.length} resultados');
    } catch (e) {
      _logger.e('Error en búsqueda: $e');
      _eventController.add(ShowErrorEvent('Error en la búsqueda: $e'));
    }
  }

  // ========== NAVEGACIÓN ==========
  void navigateToClienteDetail(Cliente cliente) {
    _eventController.add(NavigateToDetailEvent(cliente));
  }

  // ========== REFRESH ==========
  Future<void> refresh() async {
    await loadClientes();
  }

  // ========== UTILIDADES ==========
  String getInitials(Cliente cliente) {
    return cliente.nombre.isNotEmpty
        ? cliente.nombre[0].toUpperCase()
        : '?';
  }

  bool shouldShowPhone(Cliente cliente) {
    return cliente.telefono != null && cliente.telefono!.isNotEmpty;
  }

  String getEmptyStateTitle() {
    return _state.searchQuery.isEmpty ? 'No hay clientes' : 'No se encontraron clientes';
  }

  String getEmptyStateSubtitle() {
    return _state.searchQuery.isEmpty
        ? 'No hay clientes registrados en el sistema'
        : 'con "${_state.searchQuery}"';
  }

  // ========== MÉTODOS PRIVADOS ==========
  void _updateState(ClienteListState newState) {
    _state = newState;
    notifyListeners();
  }

  // ========== ESTADÍSTICAS Y DEBUGGING ==========
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

  void logDebugInfo() {
    _logger.d('ClienteListScreenViewModel Debug Info: ${getDebugInfo()}');
  }
}