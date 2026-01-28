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
  Timer? _fallbackTimer;

  OperacionesComercialesHistoryViewModel()
    : _operacionRepository = OperacionComercialRepositoryImpl(),
      _clienteRepository = ClienteRepository(),
      _censoRepository = CensoActivoRepository();

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _cargarClientes();
      await cargarDatos();
      _iniciarEscuchaEventos();
      _iniciarRefrescoRespaldo();
      debugPrint('✅ [HISTORY] ViewModel inicializado correctamente');
    } catch (e) {
      debugPrint('Error loading history: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _iniciarEscuchaEventos() {
    // Cancelar suscripción anterior si existe
    _eventSubscription?.cancel();

    // Escuchar eventos en tiempo real
    _eventSubscription = OperacionEventService().eventos.listen((event) async {
      debugPrint(
        '⚡ [HISTORY] Evento recibido: ${event.type} ID: ${event.operacionId}',
      );

      // Si estamos mostrando una fecha específica y el evento es de creación (fecha actual),
      // tal vez no necesitamos actualizar si la fecha seleccionada es antigua.
      // Pero por simplicidad, actualizamos siempre para garantizar consistencia.
      await cargarDatos();
    });

    debugPrint('✅ [HISTORY] Escuchando eventos de operaciones en tiempo real');
  }

  void _iniciarRefrescoRespaldo() {
    _fallbackTimer?.cancel();
    // Timer de respaldo cada 1 segundo para máxima responsividad
    _fallbackTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      await cargarDatos();
    });
    debugPrint('✅ [HISTORY] Timer de respaldo iniciado (cada 1s)');
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _fallbackTimer?.cancel();
    debugPrint('🛑 [HISTORY] Comprobación de cambios cancelada');
    super.dispose();
  }

  Future<void> _cargarClientes() async {
    try {
      final clientes = await _clienteRepository.obtenerTodos();
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
    // No mostrar loading en refrescos automáticos
    final esRefrescoAutomatico = !_isLoading;

    if (!esRefrescoAutomatico) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      debugPrint(
        '📥 [HISTORY] Cargando datos de DB... (Refresco auto: $esRefrescoAutomatico)',
      );

      // Cargar operaciones
      _operaciones = await _operacionRepository.obtenerTodasLasOperaciones(
        fecha: _selectedDate,
      );

      // Cargar censos
      _censos = await _censoRepository.obtenerTodos(fecha: _selectedDate);

      // Solo notificar si hay cambios o es carga inicial
      if (!esRefrescoAutomatico) {
        notifyListeners();
      } else {
        // En refresco automático, siempre notificar para actualizar UI
        notifyListeners();
        debugPrint('🔔 [HISTORY] UI Notificada');
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      if (!esRefrescoAutomatico) {
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
