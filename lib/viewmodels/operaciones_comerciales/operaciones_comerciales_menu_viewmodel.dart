// lib/viewmodels/operaciones_comerciales/operaciones_comerciales_menu_viewmodel.dart

import 'package:flutter/foundation.dart';
import '../../utils/logger.dart';
import 'package:ada_app/models/operaciones_comerciales/operacion_comercial.dart';
import 'package:ada_app/models/operaciones_comerciales/enums/tipo_operacion.dart';
import 'package:ada_app/repositories/operacion_comercial_repository.dart';
import 'package:ada_app/services/sync/operacion_comercial_sync_service.dart';
import 'package:ada_app/services/data/database_helper.dart';

class OperacionesComercialesMenuViewModel extends ChangeNotifier {
  final OperacionComercialRepository _repository;
  final int clienteId;
  bool _isLoading = false;
  bool _isSyncing = false;
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
  bool get isSyncing => _isSyncing;
  String? get errorMessage => _errorMessage;

  List<OperacionComercial> get operacionesReposicion =>
      List.unmodifiable(_operacionesReposicion);
  List<OperacionComercial> get operacionesRetiro =>
      List.unmodifiable(_operacionesRetiro);
  List<OperacionComercial> get operacionesDiscontinuos =>
      List.unmodifiable(_operacionesDiscontinuos);

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

  // Sincronizar operaciones desde el servidor
  Future<Map<String, int>?> sincronizarOperacionesDesdeServidor() async {
    if (_isSyncing) return null;

    _isSyncing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Obtener employeeId del usuario actual
      final employeeId = await _obtenerEmployeeId();

      if (employeeId == null) {
        _errorMessage = 'No se pudo obtener el ID del vendedor';
        _isSyncing = false;
        notifyListeners();
        return null;
      }

      // Sincronizar con el servidor
      final resultado =
          await OperacionComercialSyncService.obtenerOperacionesPorVendedor(
            employeeId,
          );

      if (resultado.exito) {
        // Recargar las operaciones locales después de sincronizar
        await cargarOperaciones();

        _isSyncing = false;
        notifyListeners();

        return {
          'total': resultado.itemsSincronizados,
          'nuevas': resultado.itemsSincronizados,
        };
      } else {
        _errorMessage = resultado.mensaje;
        _isSyncing = false;
        notifyListeners();
        return null;
      }
    } catch (e) {
      _errorMessage = 'Error sincronizando: $e';
      _isSyncing = false;
      notifyListeners();
      return null;
    }
  }

  // Obtener el employeeId del usuario actual
  Future<String?> _obtenerEmployeeId() async {
    try {
      final db = await DatabaseHelper().database;
      final result = await db.query(
        'Users',
        columns: ['employee_id'],
        limit: 1,
      );

      if (result.isNotEmpty) {
        return result.first['employee_id'] as String?;
      }
      return null;
    } catch (e) { AppLogger.e("OPERACIONES_COMERCIALES_MENU_VIEWMODEL: Error", e); return null; }
  }

  // Cargar todas las operaciones del cliente
  Future<void> cargarOperaciones() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Cargar operaciones por tipo
      _operacionesReposicion = await _repository
          .obtenerOperacionesPorClienteYTipo(
            clienteId,
            TipoOperacion.notaReposicion,
          );

      _operacionesRetiro = await _repository.obtenerOperacionesPorClienteYTipo(
        clienteId,
        TipoOperacion.notaRetiro,
      );

      _operacionesDiscontinuos = await _repository
          .obtenerOperacionesPorClienteYTipo(
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
