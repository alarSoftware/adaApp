import 'package:flutter/material.dart';
import '../utils/logger.dart';
import 'package:ada_app/repositories/equipo_repository.dart';

import 'package:ada_app/services/sync/equipment_sync_service.dart';
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
      final query = searchController.text.trim();

      List<Map<String, dynamic>> equiposDB;

      if (query.isEmpty) {
        // Sin filtro: cargar todos
        equiposDB = await _equipoRepository.obtenerCompletos();
      } else {
        // Con filtro: usar búsqueda del Repository
        equiposDB = await _equipoRepository.buscarConDetalles(query);
      }

      // Log de algunos ejemplos para debug
      if (equiposDB.isEmpty) {
        // Hacer una prueba: cargar todos para ver si hay datos
        final todosLosEquipos = await _equipoRepository.obtenerCompletos();
      }

      _equipos = equiposDB;
      _equiposFiltrados = equiposDB;

      _hayMasDatos = true;

      _cargarSiguientePagina();
    } catch (e, stackTrace) {
      _eventController.add(
        ShowSnackBarEvent('Error cargando equipos: $e', Colors.red),
      );
    } finally {
      _setLoading(false);
    }
  }

  void _filtrarEquipos() {
    // Volver a cargar desde Repository
    cargarEquipos();
  }

  Future<void> refrescarDatos() async {
    try {
      _setLoading(true);

      // 1. Sincronizar con el servidor (Descargar)
      _eventController.add(
        ShowSnackBarEvent(
          'Sincronizando equipos... (Esto puede tardar unos minutos)',
          Colors.blue,
          durationSeconds: 2,
        ),
      );

      final result = await EquipmentSyncService.sincronizarEquipos();

      if (!result.exito) {
        _eventController.add(
          ShowSnackBarEvent(
            'Error descarga: ${result.mensaje}',
            Colors.orange,
            durationSeconds: 4,
          ),
        );
      } else {
        _eventController.add(
          ShowSnackBarEvent(
            'Descarga completada: ${result.itemsSincronizados} equipos',
            Colors.green,
            durationSeconds: 3,
          ),
        );
      }

      // 2. Solo recargar datos locales manteniendo el filtro
      await cargarEquipos();
    } catch (e) {
      _eventController.add(
        ShowSnackBarEvent('Error al actualizar: $e', Colors.red),
      );
      _setLoading(false);
    }
  }

  // Método auxiliar para probar la búsqueda simple
  Future<void> _testBusquedaSimple() async {
    try {
      // Probar obtener todos - SIN parámetro soloActivos
      final todos = await _equipoRepository
          .obtenerCompletos(); // CORREGIDO: sin parámetro

      // Probar búsqueda con "pepsi"
      final conPepsi = await _equipoRepository.buscarConDetalles('pepsi');

      // Probar búsqueda vacía
      final vacia = await _equipoRepository.buscarConDetalles('');
    } catch (e) { AppLogger.e("EQUIPOS_SCREEN_VIEWMODEL: Error", e); }
  }

  // ===============================
  // LÓGICA DE NEGOCIO - PAGINACIÓN
  // ===============================

  void _resetPaginacion() {
    _paginaActual = 0;
    _equiposMostrados.clear();
  }

  void _cargarSiguientePagina() {
    if (_cargandoMas || !_hayMasDatos) {
      return;
    }

    _setCargandoMas(true);

    final startIndex = _paginaActual * equiposPorPagina;
    final endIndex = (startIndex + equiposPorPagina).clamp(
      0,
      _equiposFiltrados.length,
    );

    if (startIndex < _equiposFiltrados.length) {
      final nuevosEquipos = _equiposFiltrados.sublist(startIndex, endIndex);

      _equiposMostrados.addAll(nuevosEquipos);
      _paginaActual++;
      _hayMasDatos = endIndex < _equiposFiltrados.length;
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

  String get appBarTitle =>
      'Equipos (${_equiposFiltrados.length}/${_equipos.length})';

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
