// lib/viewmodels/operaciones_comerciales_menu_viewmodel.dart
import 'package:flutter/foundation.dart';
import 'package:ada_app/models/operaciones_comerciales/operacion_comercial.dart';
import 'package:ada_app/models/operaciones_comerciales/enums/tipo_operacion.dart';
import 'package:ada_app/repositories/operacion_comercial_repository.dart';

class OperacionesComercialesMenuViewModel extends ChangeNotifier {
  final OperacionComercialRepository _repository;
  final int clienteId;
  bool _isLoading = false;
  String? _errorMessage;
  List<OperacionComercial> _operacionesReposicion = [];
  List<OperacionComercial> _operacionesRetiro = [];
  List<OperacionComercial> _operacionesDiscontinuos = [];

  OperacionesComercialesMenuViewModel({
    required this.clienteId,
    OperacionComercialRepository? repository,
  }) : _repository = repository ?? OperacionComercialRepositoryImpl() {
    cargarOperaciones();
  }

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<OperacionComercial> get operacionesReposicion => List.unmodifiable(_operacionesReposicion);
  List<OperacionComercial> get operacionesRetiro => List.unmodifiable(_operacionesRetiro);
  List<OperacionComercial> get operacionesDiscontinuos => List.unmodifiable(_operacionesDiscontinuos);

  // Obtener operaciones por tipo
  List<OperacionComercial> getOperacionesPorTipo(TipoOperacion tipo) {
    switch (tipo) {
      case TipoOperacion.notaReposicion:
        return operacionesReposicion;
      case TipoOperacion.notaRetiro:
        return operacionesRetiro;
      case TipoOperacion.notaRetiroDiscontinuos:
        return operacionesDiscontinuos;
      default:
        return [];
    }
  }

  // Cargar todas las operaciones del cliente
  Future<void> cargarOperaciones() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Cargar operaciones por tipo
      _operacionesReposicion = await _repository.obtenerOperacionesPorClienteYTipo(
        clienteId,
        TipoOperacion.notaReposicion,
      );

      _operacionesRetiro = await _repository.obtenerOperacionesPorClienteYTipo(
        clienteId,
        TipoOperacion.notaRetiro,
      );

      _operacionesDiscontinuos = await _repository.obtenerOperacionesPorClienteYTipo(
        clienteId,
        TipoOperacion.notaRetiroDiscontinuos,
      );

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error cargando operaciones: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  // Eliminar operación
  Future<bool> eliminarOperacion(String operacionId) async {
    try {
      await _repository.eliminarOperacion(operacionId);
      await cargarOperaciones();
      return true;
    } catch (e) {
      _errorMessage = 'Error eliminando operación: $e';
      notifyListeners();
      return false;
    }
  }
}