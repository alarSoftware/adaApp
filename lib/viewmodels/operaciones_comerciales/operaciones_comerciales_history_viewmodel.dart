import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:ada_app/models/operaciones_comerciales/operacion_comercial.dart';
import 'package:ada_app/models/censo_activo.dart';
import 'package:ada_app/models/cliente.dart';
import 'package:ada_app/repositories/operacion_comercial_repository.dart';
import 'package:ada_app/repositories/cliente_repository.dart';
import 'package:ada_app/repositories/censo_activo_repository.dart';
import 'package:ada_app/services/events/operacion_event_service.dart';

class OperacionesComercialesHistoryViewModel extends ChangeNotifier {
  final OperacionComercialRepository _operacionRepository;
  final ClienteRepository _clienteRepository;
  final CensoActivoRepository _censoRepository;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<OperacionComercial> _operaciones = [];
  List<OperacionComercial> get operaciones => _operaciones;

  List<CensoActivo> _censos = [];
  List<CensoActivo> get censos => _censos;

  final Map<int, Cliente> _clientesCache = {};

  DateTime? _selectedDate;
  DateTime? get selectedDate => _selectedDate;

  StreamSubscription<OperacionEvent>? _eventSubscription;
  bool _disposed = false;

  OperacionesComercialesHistoryViewModel()
    : _operacionRepository = OperacionComercialRepositoryImpl(),
      _clienteRepository = ClienteRepository(),
      _censoRepository = CensoActivoRepository();

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _cargarClientes();
      if (_disposed) return;

      await cargarDatos();
      if (_disposed) return;

      _iniciarEscuchaEventos();
      debugPrint('✅ [HISTORY] ViewModel inicializado correctamente');
    } catch (e) {
      debugPrint('Error loading history: $e');
    } finally {
      if (!_disposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void _iniciarEscuchaEventos() {
    // Cancelar suscripción anterior si existe
    _eventSubscription?.cancel();

    // Escuchar eventos en tiempo real
    _eventSubscription = OperacionEventService().eventos.listen((event) async {
      if (_disposed) return;
      debugPrint(
        '⚡ [HISTORY] Evento recibido: ${event.type} ID: ${event.operacionId}',
      );
      await cargarDatos();
    });

    debugPrint('✅ [HISTORY] Escuchando eventos de operaciones en tiempo real');
  }

  @override
  void dispose() {
    _disposed = true;
    _eventSubscription?.cancel();
    debugPrint('🛑 [HISTORY] Comprobación de cambios cancelada (disposed)');
    super.dispose();
  }

  Future<void> _cargarClientes() async {
    try {
      final clientes = await _clienteRepository.obtenerTodos();
      if (_disposed) return;

      _clientesCache.clear();
      for (var c in clientes) {
        if (c.id != null) {
          _clientesCache[c.id!] = c;
        }
      }
    } catch (e) {
      debugPrint('Error loading clients: $e');
    }
  }

  Future<void> cargarDatos() async {
    if (_disposed) return;

    // Solo mostrar el indicador de carga si no están cargados ya para evitar parpadeos
    if (_operaciones.isEmpty && _censos.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      debugPrint('📥 [HISTORY] Cargando datos de DB...');

      final operacionesNuevas = await _operacionRepository
          .obtenerTodasLasOperaciones(fecha: _selectedDate);

      final censosNuevos = await _censoRepository.obtenerTodos(
        fecha: _selectedDate,
      );

      if (_disposed) return;

      _operaciones = operacionesNuevas;
      _censos = censosNuevos;

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      if (!_disposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void seleccionarFecha(DateTime fecha) {
    if (_selectedDate != null &&
        _selectedDate!.year == fecha.year &&
        _selectedDate!.month == fecha.month &&
        _selectedDate!.day == fecha.day) {
      return;
    }
    _selectedDate = fecha;
    cargarDatos();
  }

  void limpiarFiltro() {
    if (_selectedDate == null) return;
    _selectedDate = null;
    cargarDatos();
  }

  Cliente? getCliente(int id) => _clientesCache[id];
}
