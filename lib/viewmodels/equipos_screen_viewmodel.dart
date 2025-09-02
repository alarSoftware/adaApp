// viewmodels/equipo_list_screen_viewmodel.dart
import 'package:flutter/material.dart';
import 'package:ada_app/repositories/equipo_repository.dart';
import 'package:ada_app/services/sync_service.dart';
import 'package:logger/logger.dart';
import 'dart:async';

// Eventos UI
abstract class EquipoListUIEvent {}

class ShowSnackBarEvent extends EquipoListUIEvent {
  final String message;
  final Color color;
  final int durationSeconds;

  ShowSnackBarEvent(this.message, this.color, {this.durationSeconds = 3});
}

class ShowEquipoDetailsEvent extends EquipoListUIEvent {
  final Map<String, dynamic> equipo;

  ShowEquipoDetailsEvent(this.equipo);
}

class EquipoListScreenViewModel extends ChangeNotifier {
  final Logger _logger = Logger();
  final EquipoRepository _equipoRepository = EquipoRepository();
  late final StreamController<EquipoListUIEvent> _eventController;
  Timer? _debounceTimer;

  // Controladores
  final TextEditingController searchController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  // Estado privado
  List<Map<String, dynamic>> _equipos = [];
  List<Map<String, dynamic>> _equiposFiltrados = [];
  List<Map<String, dynamic>> _equiposMostrados = [];
  bool _isLoading = true;
  bool _cargandoMas = false;
  bool _hayMasDatos = true;
  int _paginaActual = 0;

  // Constantes
  static const int equiposPorPagina = 10;

  // Getters públicos
  List<Map<String, dynamic>> get equipos => _equipos;
  List<Map<String, dynamic>> get equiposFiltrados => _equiposFiltrados;
  List<Map<String, dynamic>> get equiposMostrados => _equiposMostrados;
  bool get isLoading => _isLoading;
  bool get cargandoMas => _cargandoMas;
  bool get hayMasDatos => _hayMasDatos;
  bool get isSearching => searchController.text.isNotEmpty;
  Stream<EquipoListUIEvent> get uiEvents => _eventController.stream;

  // Constructor
  EquipoListScreenViewModel() {
    _eventController = StreamController<EquipoListUIEvent>.broadcast();
    _inicializar();
  }

  void _inicializar() {
    searchController.addListener(_onSearchChanged);
    scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    searchController.dispose();
    scrollController.dispose();
    _debounceTimer?.cancel();
    _eventController.close();
    super.dispose();
  }

  // ===============================
  // LÓGICA DE NEGOCIO - CARGA DE DATOS
  // ===============================

  Future<void> initialize() async {
    await cargarEquipos();
  }

  Future<void> cargarEquipos() async {
    _setLoading(true);
    _resetPaginacion();

    try {
      final equiposDB = await _equipoRepository.obtenerCompletos(soloActivos: true);

      _equipos = equiposDB;
      _equiposFiltrados = equiposDB;
      _hayMasDatos = _equiposFiltrados.length > equiposPorPagina;

      _logger.i('Equipos cargados: ${_equipos.length}');

      _cargarSiguientePagina();

    } catch (e) {
      _logger.e('Error cargando equipos: $e');
      _eventController.add(ShowSnackBarEvent('Error cargando equipos: $e', Colors.red));
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refrescarDatos() async {
    try {
      final resultado = await SyncService.sincronizarEquipos();

      if (resultado.exito) {
        await cargarEquipos();
        _eventController.add(ShowSnackBarEvent(
            'Equipos actualizados: ${resultado.itemsSincronizados}',
            Colors.green,
            durationSeconds: 2
        ));
      } else {
        throw Exception(resultado.mensaje);
      }
    } catch (e) {
      _logger.e('Error refrescando datos: $e');
      _eventController.add(ShowSnackBarEvent('Error al actualizar: $e', Colors.red));
    }
  }

  // ===============================
  // LÓGICA DE NEGOCIO - PAGINACIÓN
  // ===============================

  void _resetPaginacion() {
    _paginaActual = 0;
    _equiposMostrados.clear();
  }

  void _cargarSiguientePagina() {
    if (_cargandoMas || !_hayMasDatos) return;

    _setCargandoMas(true);

    final startIndex = _paginaActual * equiposPorPagina;
    final endIndex = (startIndex + equiposPorPagina).clamp(0, _equiposFiltrados.length);

    if (startIndex < _equiposFiltrados.length) {
      final nuevosEquipos = _equiposFiltrados.sublist(startIndex, endIndex);

      _equiposMostrados.addAll(nuevosEquipos);
      _paginaActual++;
      _hayMasDatos = endIndex < _equiposFiltrados.length;

      _logger.d('Página cargada: $_paginaActual, Equipos mostrados: ${_equiposMostrados.length}');
    } else {
      _hayMasDatos = false;
    }

    _setCargandoMas(false);
    notifyListeners();
  }

  void _onScroll() {
    if (scrollController.position.pixels >=
        scrollController.position.maxScrollExtent - 200) {
      _cargarSiguientePagina();
    }
  }

  // ===============================
  // LÓGICA DE NEGOCIO - BÚSQUEDA Y FILTROS
  // ===============================

  void _onSearchChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer?.cancel();

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _filtrarEquipos();
    });
  }

  void _filtrarEquipos() {
    final query = searchController.text.toLowerCase().trim();

    if (query.isEmpty) {
      _equiposFiltrados = List.from(_equipos);
    } else {
      _equiposFiltrados = _equipos.where((equipo) {
        final codBarras = equipo['cod_barras']?.toString().toLowerCase() ?? '';
        final marcaNombre = equipo['marca_nombre']?.toString().toLowerCase() ?? '';
        final modeloNombre = equipo['modelo_nombre']?.toString().toLowerCase() ?? '';
        final estadoAsignacion = equipo['estado_asignacion']?.toString().toLowerCase() ?? '';
        final logoNombre = equipo['logo_nombre']?.toString().toLowerCase() ?? '';

        return codBarras.contains(query) ||
            marcaNombre.contains(query) ||
            modeloNombre.contains(query) ||
            estadoAsignacion.contains(query) ||
            logoNombre.contains(query);
      }).toList();
    }

    _resetPaginacion();
    _hayMasDatos = _equiposFiltrados.isNotEmpty;

    _cargarSiguientePagina();

    _logger.d('Filtro aplicado: "$query", Resultados: ${_equiposFiltrados.length}');
  }

  void limpiarBusqueda() {
    searchController.clear();
    _filtrarEquipos();
  }

  // ===============================
  // LÓGICA DE NEGOCIO - DETALLES Y NAVEGACIÓN
  // ===============================

  void mostrarDetallesEquipo(Map<String, dynamic> equipo) {
    _eventController.add(ShowEquipoDetailsEvent(equipo));
  }

  // ===============================
  // HELPERS PARA UI
  // ===============================

  Color getColorByLogo(String? logoNombre) {
    if (logoNombre == null) return Colors.grey;

    final logo = logoNombre.toLowerCase();

    switch (logo) {
      case 'pepsi':
        return Colors.blue;
      case 'pulp':
        return Colors.orange;
      case 'paso de los toros':
        return Colors.green;
      case 'mirinda':
        return Colors.deepOrange;
      case '7up':
        return Colors.lightGreen;
      case 'gatorade':
        return Colors.blue[800]!;
      case 'red bull':
        return Colors.red;
      default:
        return Colors.grey[600]!;
    }
  }

  IconData getIconByLogo(String? logoNombre) {
    if (logoNombre == null) return Icons.kitchen;

    final logo = logoNombre.toLowerCase();

    switch (logo) {
      case 'pepsi':
      case 'mirinda':
      case '7up':
      case 'paso de los toros':
      case 'gatorade':
      case 'red bull':
      case 'aquafina':
      case 'puro sol':
      case 'split':
      case 'watts':
      case 'la fuente':
      case 'pulp':
      case 'rockstar':
        return Icons.kitchen;
      default:
        return Icons.kitchen_outlined;
    }
  }

  String getEquipoNombreCompleto(Map<String, dynamic> equipo) {
    final marcaNombre = equipo['marca_nombre'] ?? 'Sin marca';
    final modeloNombre = equipo['modelo_nombre'] ?? 'Sin modelo';
    return '$marcaNombre $modeloNombre';
  }

  String getEstadoAsignacion(Map<String, dynamic> equipo) {
    return equipo['estado_asignacion'] ?? 'Disponible';
  }

  Color getEstadoColor(String estado) {
    return estado == 'Disponible' ? Colors.green : Colors.orange;
  }

  // ===============================
  // GETTERS PARA UI
  // ===============================

  String get appBarTitle => 'Equipos (${_equiposFiltrados.length}/${_equipos.length})';

  String get searchHint => 'Buscar por código, marca, modelo o logo...';

  String get emptyStateTitle => isSearching
      ? 'No se encontraron equipos\ncon "${searchController.text}"'
      : 'No hay equipos disponibles';

  String get loadingMessage => 'Cargando equipos...';

  bool get shouldShowClearButton => searchController.text.isNotEmpty;

  bool get shouldShowRefreshButton => !isSearching;

  // ===============================
  // MÉTODOS PRIVADOS
  // ===============================

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setCargandoMas(bool cargando) {
    _cargandoMas = cargando;
    notifyListeners();
  }
}