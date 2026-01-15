import 'package:flutter/foundation.dart';
import 'package:ada_app/models/operaciones_comerciales/operacion_comercial.dart';
import 'package:ada_app/models/cliente.dart';
import 'package:ada_app/repositories/operacion_comercial_repository.dart';
import 'package:ada_app/repositories/cliente_repository.dart';

class OperacionesComercialesHistoryViewModel extends ChangeNotifier {
  final OperacionComercialRepository _operacionRepository;
  final ClienteRepository _clienteRepository;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<OperacionComercial> _operaciones = [];
  List<OperacionComercial> get operaciones => _operaciones;

  final Map<int, Cliente> _clientesCache = {};

  DateTime? _selectedDate;
  DateTime? get selectedDate => _selectedDate;

  OperacionesComercialesHistoryViewModel()
    : _operacionRepository = OperacionComercialRepositoryImpl(),
      _clienteRepository = ClienteRepository();

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _cargarClientes();
      await cargarOperaciones();
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

  Future<void> cargarOperaciones() async {
    _isLoading = true;
    notifyListeners();
    try {
      _operaciones = await _operacionRepository.obtenerTodasLasOperaciones(
        fecha: _selectedDate,
      );
    } catch (e) {
      debugPrint('Error loading operations: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void seleccionarFecha(DateTime fecha) {
    // If selecting same date, maybe toggle off? No, user can clear explicitly.
    // Or if different date, update.
    if (_selectedDate != null &&
        _selectedDate!.year == fecha.year &&
        _selectedDate!.month == fecha.month &&
        _selectedDate!.day == fecha.day) {
      // Already selected
      return;
    }
    _selectedDate = fecha;
    cargarOperaciones();
  }

  void limpiarFiltro() {
    if (_selectedDate == null) return;
    _selectedDate = null;
    cargarOperaciones();
  }

  Cliente? getCliente(int id) => _clientesCache[id];
}
