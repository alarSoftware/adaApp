import 'package:flutter/foundation.dart';
import 'package:ada_app/models/operaciones_comerciales/operacion_comercial.dart';
import 'package:ada_app/models/censo_activo.dart';
import 'package:ada_app/models/cliente.dart';
import 'package:ada_app/repositories/operacion_comercial_repository.dart';
import 'package:ada_app/repositories/cliente_repository.dart';
import 'package:ada_app/repositories/censo_activo_repository.dart';

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
    } catch (e) {
      debugPrint('Error loading history: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
    _isLoading = true;
    notifyListeners();
    try {
      // Cargar operaciones
      _operaciones = await _operacionRepository.obtenerTodasLasOperaciones(
        fecha: _selectedDate,
      );

      // Cargar censos
      _censos = await _censoRepository.obtenerTodos(fecha: _selectedDate);
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
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
