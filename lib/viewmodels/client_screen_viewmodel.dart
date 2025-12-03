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

  // ========== OBTENER DÍA ACTUAL ==========
  String _getDiaActual() {
    final diasSemana = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    final now = DateTime.now();
    return diasSemana[now.weekday - 1];
  }

  // ========== INICIALIZACIÓN ==========
  Future<void> initialize() async {
    final diaActual = _getDiaActual();
    _logger.i('Inicializando con día actual: $diaActual');

    _updateState(_state.copyWith(selectedDia: diaActual));

    await loadClientes();
  }

  // ========== FILTROS ==========
  void updateSelectedDia(String? dia) {
    _logger.i('Actualizando día seleccionado: $dia');
    _updateState(_state.copyWith(selectedDia: dia));
    _applyFilters();
  }

  void clearDiaFilter() {
    _logger.i('Limpiando filtro de día');
    _updateState(_state.copyWith(clearSelectedDia: true));
    _applyFilters();
  }

  Future<void> _applyFilters() async {
    try {
      _logger.i('Aplicando filtros - Query: "${_state.searchQuery}", Día: "${_state.selectedDia}"');

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

      _logger.i('Filtros aplicados: ${resultados.length} resultados');
    } catch (e) {
      _logger.e('Error aplicando filtros: $e');
      _eventController.add(ShowErrorEvent('Error al filtrar: $e'));
    }
  }

  // ========== CARGA DE DATOS ==========
  Future<void> loadClientes() async {
    _logger.i('=== INICIANDO loadClientes ===');
    _logger.i('Estado inicial - displayedClientes.length: ${_state.displayedClientes.length}');
    _logger.i('Estado inicial - currentPage: ${_state.currentPage}');
    _logger.i('Estado inicial - hasMoreData: ${_state.hasMoreData}');
    _logger.i('Query actual: "${_state.searchQuery}"');

    _updateState(_state.copyWith(
      isLoading: true,
      currentPage: 0,
      displayedClientes: [],
      error: null,
    ));

    try {
      _logger.i('Cargando clientes desde la base de datos...');

      final clientesDB = await _repository.buscarConFiltros(
        query: _state.searchQuery,
        rutaDia: _state.selectedDia,
      );

      _logger.i('Clientes obtenidos de BD: ${clientesDB.length}');

      _allClientes = clientesDB;
      _filteredClientes = clientesDB;

      _updateState(_state.copyWith(
        isLoading: false,
        totalCount: clientesDB.length,
        hasMoreData: true,
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

    _logger.i('=== FINALIZANDO loadClientes ===');
  }

  // ========== REFRESH MEJORADO ==========
  Future<void> refresh() async {
    _logger.i('=== REFRESH - Query actual: "${_state.searchQuery}", Día: "${_state.selectedDia}" ===');

    if (_state.searchQuery.isNotEmpty || _state.selectedDia != null) {
      await _applyFilters();
    } else {
      await loadClientes();
    }
  }

  // ========== PAGINACIÓN ==========
  Future<void> _loadNextPage() async {
    _logger.d('=== INICIANDO _loadNextPage ===');
    _logger.d('hasMoreData: ${_state.hasMoreData}');
    _logger.d('isLoadingMore: ${_state.isLoadingMore}');
    _logger.d('currentPage: ${_state.currentPage}');
    _logger.d('displayedClientes.length actual: ${_state.displayedClientes.length}');
    _logger.d('_filteredClientes.length: ${_filteredClientes.length}');

    if (!_state.hasMoreData || _state.isLoadingMore) {
      _logger.w('Saliendo temprano de _loadNextPage - hasMoreData: ${_state.hasMoreData}, isLoadingMore: ${_state.isLoadingMore}');
      return;
    }

    _updateState(_state.copyWith(isLoadingMore: true));

    await Future.delayed(Duration(milliseconds: 150));

    final startIndex = _state.currentPage * clientesPorPagina;
    final endIndex = startIndex + clientesPorPagina;

    _logger.d('Cálculos de paginación:');
    _logger.d('- startIndex: $startIndex');
    _logger.d('- endIndex: $endIndex');
    _logger.d('- clientesPorPagina: $clientesPorPagina');

    if (startIndex < _filteredClientes.length) {
      final nuevosClientes = _filteredClientes
          .skip(startIndex)
          .take(clientesPorPagina)
          .toList();

      _logger.d('nuevosClientes.length: ${nuevosClientes.length}');

      final updatedDisplayedClientes = List<Cliente>.from(_state.displayedClientes)
        ..addAll(nuevosClientes);

      _logger.d('displayedClientes antes de agregar: ${_state.displayedClientes.length}');
      _logger.d('displayedClientes después de agregar: ${updatedDisplayedClientes.length}');

      final newHasMoreData = endIndex < _filteredClientes.length;
      final newCurrentPage = _state.currentPage + 1;

      _logger.d('Actualizando estado:');
      _logger.d('- newCurrentPage: $newCurrentPage');
      _logger.d('- newHasMoreData: $newHasMoreData');

      _updateState(_state.copyWith(
        displayedClientes: updatedDisplayedClientes,
        currentPage: newCurrentPage,
        hasMoreData: newHasMoreData,
        isLoadingMore: false,
      ));

      _logger.d('Estado final después de _updateState:');
      _logger.d('- currentPage: ${_state.currentPage}');
      _logger.d('- displayedClientes.length: ${_state.displayedClientes.length}');
      _logger.d('- hasMoreData: ${_state.hasMoreData}');
    } else {
      _logger.w('startIndex ($startIndex) >= _filteredClientes.length (${_filteredClientes.length}) - No hay más datos');
      _updateState(_state.copyWith(
        hasMoreData: false,
        isLoadingMore: false,
      ));
    }

    _logger.d('=== FINALIZANDO _loadNextPage ===');
  }

  Future<void> loadMoreClientes() async {
    _logger.d('loadMoreClientes llamado');
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
      _logger.i('Buscando clientes con query: "$query"');
      await _applyFilters();
    } catch (e) {
      _logger.e('Error en búsqueda: $e');
      _eventController.add(ShowErrorEvent('Error en la búsqueda: $e'));
    }
  }

  // ========== NAVEGACIÓN ==========
  void navigateToClienteDetail(Cliente cliente) {
    _eventController.add(NavigateToDetailEvent(cliente));
  }

  // ========== UTILIDADES ==========
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
      'dia_seleccionado': _state.selectedDia,
      'esta_cargando': _state.isLoading,
      'esta_cargando_mas': _state.isLoadingMore,
    };
  }

  void logDebugInfo() {
    _logger.d('ClienteListScreenViewModel Debug Info: ${getDebugInfo()}');
  }
}