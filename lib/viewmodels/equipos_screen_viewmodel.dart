import 'package:flutter/material.dart';
import 'package:ada_app/repositories/equipo_repository.dart';

import 'package:logger/logger.dart';
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
      final query = searchController.text.trim();
      _logger.i('=== CARGANDO EQUIPOS ===');
      _logger.i('Query: "$query"');

      List<Map<String, dynamic>> equiposDB;

      if (query.isEmpty) {
        // Sin filtro: cargar todos - SIN parámetro soloActivos
        _logger.i('Cargando TODOS los equipos...');
        equiposDB = await _equipoRepository
            .obtenerCompletos(); // CORREGIDO: sin parámetro
      } else {
        // Con filtro: usar búsqueda del Repository
        _logger.i('Usando buscarConDetalles con query: "$query"');
        equiposDB = await _equipoRepository.buscarConDetalles(query);
      }

      _logger.i('Equipos obtenidos de Repository: ${equiposDB.length}');

      // Log de algunos ejemplos para debug
      if (equiposDB.isNotEmpty) {
        _logger.i('Primer equipo: ${equiposDB.first}');
        if (equiposDB.length > 1) {
          _logger.i('Segundo equipo: ${equiposDB[1]}');
        }
      } else {
        _logger.w('¡NO SE ENCONTRARON EQUIPOS!');

        // Hacer una prueba: cargar todos para ver si hay datos
        final todosLosEquipos = await _equipoRepository
            .obtenerCompletos(); // CORREGIDO: sin parámetro
        _logger.i('Prueba - Total de equipos en DB: ${todosLosEquipos.length}');

        if (todosLosEquipos.isNotEmpty) {
          _logger.i('Ejemplo de equipo en DB: ${todosLosEquipos.first}');
        }
      }

      _equipos = equiposDB;
      _equiposFiltrados = equiposDB;

      _hayMasDatos = true;

      _logger.i('Equipos asignados: ${_equipos.length}');
      _logger.i('Equipos filtrados: ${_equiposFiltrados.length}');

      _cargarSiguientePagina();
    } catch (e, stackTrace) {
      _logger.e('Error cargando equipos: $e');
      _logger.e('StackTrace: $stackTrace');
      _eventController.add(
        ShowSnackBarEvent('Error cargando equipos: $e', Colors.red),
      );
    } finally {
      _setLoading(false);
    }
  }

  void _filtrarEquipos() {
    final query = searchController.text.trim();
    _logger.i('=== FILTRANDO EQUIPOS ===');
    _logger.i('Query actual: "$query"');

    // Volver a cargar desde Repository
    cargarEquipos();
  }

  Future<void> refrescarDatos() async {
    try {
      final query = searchController.text.trim();
      _logger.i('=== REFRESH - Query actual: "$query" ===');

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
        _logger.w('Error en sincronización: ${result.mensaje}');
        _eventController.add(
          ShowSnackBarEvent(
            'Error descarga: ${result.mensaje}',
            Colors.orange,
            durationSeconds: 4,
          ),
        );
      } else {
        _logger.i('Sincronización exitosa: ${result.itemsSincronizados} items');
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
      _logger.e('Error refrescando datos: $e');
      _eventController.add(
        ShowSnackBarEvent('Error al actualizar: $e', Colors.red),
      );
      _setLoading(
        false,
      ); // Ensure loading is off in case of error outside cargarEquipos
    }
  }

  // Método auxiliar para probar la búsqueda simple
  Future<void> _testBusquedaSimple() async {
    try {
      _logger.i('=== TEST BÚSQUEDA SIMPLE ===');

      // Probar obtener todos - SIN parámetro soloActivos
      final todos = await _equipoRepository
          .obtenerCompletos(); // CORREGIDO: sin parámetro
      _logger.i('Total equipos: ${todos.length}');

      // Probar búsqueda con "pepsi"
      final conPepsi = await _equipoRepository.buscarConDetalles('pepsi');
      _logger.i('Con "pepsi": ${conPepsi.length}');

      // Probar búsqueda vacía
      final vacia = await _equipoRepository.buscarConDetalles('');
      _logger.i('Búsqueda vacía: ${vacia.length}');
    } catch (e) {
      _logger.e('Error en test: $e');
    }
  }

  // ===============================
  // LÓGICA DE NEGOCIO - PAGINACIÓN
  // ===============================

  void _resetPaginacion() {
    _logger.i('=== RESET PAGINACIÓN ===');
    _logger.i(
      'Antes - _paginaActual: $_paginaActual, _equiposMostrados.length: ${_equiposMostrados.length}',
    );

    _paginaActual = 0;
    _equiposMostrados.clear();

    _logger.i(
      'Después - _paginaActual: $_paginaActual, _equiposMostrados.length: ${_equiposMostrados.length}',
    );
  }

  void _cargarSiguientePagina() {
    _logger.i('=== CARGANDO SIGUIENTE PÁGINA ===');
    _logger.i('_cargandoMas: $_cargandoMas');
    _logger.i('_hayMasDatos: $_hayMasDatos');
    _logger.i('_paginaActual: $_paginaActual');
    _logger.i('_equiposFiltrados.length: ${_equiposFiltrados.length}');
    _logger.i('_equiposMostrados.length: ${_equiposMostrados.length}');

    if (_cargandoMas || !_hayMasDatos) {
      _logger.w(
        'Saliendo temprano - _cargandoMas: $_cargandoMas, _hayMasDatos: $_hayMasDatos',
      );
      return;
    }

    _setCargandoMas(true);

    final startIndex = _paginaActual * equiposPorPagina;
    final endIndex = (startIndex + equiposPorPagina).clamp(
      0,
      _equiposFiltrados.length,
    );

    _logger.i('startIndex: $startIndex');
    _logger.i('endIndex: $endIndex');
    _logger.i('equiposPorPagina: $equiposPorPagina');

    if (startIndex < _equiposFiltrados.length) {
      final nuevosEquipos = _equiposFiltrados.sublist(startIndex, endIndex);

      _logger.i('nuevosEquipos.length: ${nuevosEquipos.length}');

      _equiposMostrados.addAll(nuevosEquipos);
      _paginaActual++;
      _hayMasDatos = endIndex < _equiposFiltrados.length;

      _logger.i('Después de agregar:');
      _logger.i('- _equiposMostrados.length: ${_equiposMostrados.length}');
      _logger.i('- _paginaActual: $_paginaActual');
      _logger.i('- _hayMasDatos: $_hayMasDatos');
    } else {
      _logger.w(
        'startIndex ($startIndex) >= _equiposFiltrados.length (${_equiposFiltrados.length})',
      );
      _hayMasDatos = false;
    }

    _setCargandoMas(false);
    _logger.i('Llamando notifyListeners()...');
    notifyListeners();
    _logger.i('=== FIN CARGANDO SIGUIENTE PÁGINA ===');
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
