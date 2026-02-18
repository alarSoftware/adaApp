import 'package:flutter/foundation.dart';
import '../../utils/logger.dart';
import 'package:ada_app/models/cliente.dart';
import 'package:ada_app/models/producto.dart';
import 'package:ada_app/models/operaciones_comerciales/enums/tipo_operacion.dart';
import 'package:ada_app/models/operaciones_comerciales/operacion_comercial.dart';
import 'package:ada_app/models/operaciones_comerciales/operacion_comercial_detalle.dart';
import 'package:ada_app/repositories/operacion_comercial_repository.dart';
import 'package:ada_app/repositories/producto_repository.dart';
import 'package:ada_app/services/api/auth_service.dart';
import 'package:ada_app/services/device/location_service.dart';
import 'package:geolocator/geolocator.dart';

import '../../utils/unidad_medida_helper.dart';
import '../../services/sync/operacion_comercial_sync_service.dart';

enum FormState { idle, loading, saving, error, retrying }

class ValidationResult {
  final bool isValid;
  final String? errorMessage;

  ValidationResult.valid() : isValid = true, errorMessage = null;
  ValidationResult.error(this.errorMessage) : isValid = false;
}

class OperacionComercialFormViewModel extends ChangeNotifier {
  final OperacionComercialRepository _operacionRepository;
  final ProductoRepository _productoRepository;
  final bool isViewOnly;

  final Cliente cliente;
  final TipoOperacion tipoOperacion;

  OperacionComercial? _operacionActual;

  FormState _formState = FormState.idle;
  String? _errorMessage;

  DateTime? _fechaRetiro;
  String? _snc;
  List<OperacionComercialDetalle> _productosSeleccionados = [];

  String _searchQuery = '';
  List<Producto> _productosFiltrados = [];
  List<Producto> _productosDisponibles = [];

  OperacionComercialFormViewModel({
    required this.cliente,
    required this.tipoOperacion,
    OperacionComercial? operacionExistente,
    this.isViewOnly = false,
    OperacionComercialRepository? operacionRepository,
    ProductoRepository? productoRepository,
  }) : _operacionRepository =
           operacionRepository ?? OperacionComercialRepositoryImpl(),
       _productoRepository = productoRepository ?? ProductoRepositoryImpl() {
    _operacionActual = operacionExistente;
    _initializeForm();
  }

  OperacionComercial? get operacionExistente => _operacionActual;

  FormState get formState => _formState;
  String? get errorMessage => _errorMessage;
  DateTime? get fechaRetiro => _fechaRetiro;
  String? get snc => _snc;
  List<OperacionComercialDetalle> get productosSeleccionados =>
      List.unmodifiable(_productosSeleccionados);
  String get searchQuery => _searchQuery;
  List<Producto> get productosFiltrados =>
      List.unmodifiable(_productosFiltrados);

  bool get isLoading => _formState == FormState.loading;
  bool get isSaving => _formState == FormState.saving;
  bool get isRetrying => _formState == FormState.retrying;
  bool get hasError => _formState == FormState.error;
  bool get isFormDirty => _hasChanges();

  int get totalProductos => _productosSeleccionados.length;
  bool get necesitaFechaRetiro => tipoOperacion.necesitaFechaRetiro;

  void _initializeForm() {
    if (operacionExistente != null) {
      _cargarOperacionExistente();
    }
    _cargarProductosIniciales();
  }

  void _cargarOperacionExistente() {
    final operacion = operacionExistente!;
    _fechaRetiro = operacion.fechaRetiro;
    _snc = operacion.snc;
    _productosSeleccionados = List.from(operacion.detalles);
    notifyListeners();
  }

  Future<void> _cargarProductosIniciales() async {
    try {} catch (e) {
      _errorMessage = 'Error cargando productos iniciales: $e';
      notifyListeners();
    }
  }

  void setFechaRetiro(DateTime? fecha) {
    if (isViewOnly) return;
    _fechaRetiro = fecha;
    notifyListeners();
  }

  void setSnc(String value) {
    if (isViewOnly) return;
    _snc = value.trim().isEmpty ? null : value.trim();
    notifyListeners();
  }

  void setSearchQuery(String query) {
    if (isViewOnly) return;
    _searchQuery = query;
    _filtrarProductos();
    notifyListeners();
  }

  void clearSearch() {
    if (isViewOnly) return;
    _searchQuery = '';
    _productosFiltrados = [];
    notifyListeners();
  }

  Future<void> _filtrarProductos() async {
    if (_searchQuery.isEmpty) {
      _productosFiltrados = [];
      return;
    }

    try {
      final todosLosProductos = await _productoRepository.buscarProductos(
        _searchQuery,
      );
      _productosFiltrados = todosLosProductos.where((producto) {
        final errorUnidad = tipoOperacion.validarUnidadMedida(
          producto.unidadMedida,
        );
        return errorUnidad == null;
      }).toList();
      notifyListeners(); // linea cambiada porque no funcionaba el buscador
    } catch (e) {
      _errorMessage = 'Error buscando productos: $e';
      _productosFiltrados = [];
      notifyListeners();
    }
  }

  bool isProductoSeleccionado(int? productoId) {
    if (productoId == null) return false;
    return _productosSeleccionados.any(
      (detalle) => detalle.productoId == productoId,
    );
  }

  bool agregarProducto(Producto producto) {
    if (isViewOnly) return false;

    if (producto.id == null) {
      _setError('El producto no tiene un ID válido');
      return false;
    }

    if (isProductoSeleccionado(producto.id)) {
      _setError('El producto ya está seleccionado');
      return false;
    }

    final errorUnidad = tipoOperacion.validarUnidadMedida(
      producto.unidadMedida,
    );
    if (errorUnidad != null) {
      String mensajeEspecifico;

      if (tipoOperacion.esNotaRetiro) {
        mensajeEspecifico =
            'Este producto viene en "${UnidadMedidaHelper.obtenerNombreDisplay(producto.unidadMedida)}".\n\nPara notas de retiro solo puedes usar productos en "Unidades".';
      } else if (tipoOperacion.esNotaReposicion) {
        mensajeEspecifico =
            'Este producto viene en "${UnidadMedidaHelper.obtenerNombreDisplay(producto.unidadMedida)}".\n\nPara notas de reposición solo puedes usar productos en packs/cajas (X 6, X 12, X 24, etc.).';
      } else {
        mensajeEspecifico = errorUnidad;
      }

      _setError(mensajeEspecifico);
      return false;
    }

    final detalle = OperacionComercialDetalle(
      operacionComercialId: '',
      productoId: producto.id!,
      cantidad: 0.0,
      orden: _productosSeleccionados.length + 1,
      fechaCreacion: DateTime.now(),
    );

    _productosSeleccionados.add(detalle);

    clearSearch();
    notifyListeners();

    return true;
  }

  void eliminarProducto(int index) {
    if (isViewOnly) return;

    if (index >= 0 && index < _productosSeleccionados.length) {
      _productosSeleccionados.removeAt(index);
      for (int i = 0; i < _productosSeleccionados.length; i++) {
        _productosSeleccionados[i] = _productosSeleccionados[i].copyWith(
          orden: i + 1,
        );
      }
      notifyListeners();
    }
  }

  void actualizarCantidadProducto(int index, double cantidad) {
    if (isViewOnly) return;

    if (index >= 0 && index < _productosSeleccionados.length) {
      if (cantidad < 0) cantidad = 0;

      _productosSeleccionados[index] = _productosSeleccionados[index].copyWith(
        cantidad: cantidad,
      );
      notifyListeners();
    }
  }

  Future<List<Producto>> obtenerProductosReemplazo(
    Producto productoOriginal,
  ) async {
    if (productoOriginal.categoria == null) {
      return [];
    }

    try {
      final productos = await _productoRepository.obtenerProductosPorCategoria(
        productoOriginal.categoria!,
        excluirId: productoOriginal.id,
      );

      // Filtrar por unidad de medida según el tipo de operación
      return productos.where((p) {
        final error = tipoOperacion.validarUnidadMedida(p.unidadMedida);
        return error == null;
      }).toList();
    } catch (e) {
      AppLogger.e("OPERACION_COMERCIAL_VIEWMODEL: Error", e);
      return [];
    }
  }

  Future<List<Producto>> getProductosReemplazo(
    String? categoriaOriginal,
    int? idProductoActual,
  ) async {
    if (categoriaOriginal == null) return [];

    try {
      return await _productoRepository.obtenerProductosPorCategoria(
        categoriaOriginal,
        excluirId: idProductoActual,
      );
    } catch (e) {
      AppLogger.e("OPERACION_COMERCIAL_VIEWMODEL: Error", e);
      return [];
    }
  }

  void seleccionarProductoReemplazo(int index, Producto productoReemplazo) {
    if (isViewOnly) return;
    setProductoReemplazo(index, productoReemplazo);
  }

  void setProductoReemplazo(int index, Producto productoReemplazo) {
    if (isViewOnly) return;

    if (index >= 0 && index < _productosSeleccionados.length) {
      _productosSeleccionados[index] = _productosSeleccionados[index].copyWith(
        productoReemplazoId: productoReemplazo.id,
      );
      notifyListeners();
    }
  }

  ValidationResult validateForm() {
    if (isViewOnly) return ValidationResult.valid();

    if (tipoOperacion.necesitaFechaRetiro && _fechaRetiro == null) {
      return ValidationResult.error('Falta seleccionar la fecha de retiro');
    }

    if (_productosSeleccionados.isEmpty) {
      return ValidationResult.error(
        'Debes agregar al menos un producto a la operación',
      );
    }

    final productosSinCantidad = _productosSeleccionados
        .where((detalle) => detalle.cantidad <= 0)
        .toList();

    if (productosSinCantidad.isNotEmpty) {
      return ValidationResult.error('Hay productos con cantidad 0');
    }

    if (tipoOperacion == TipoOperacion.notaRetiroDiscontinuos) {
      final sinReemplazo = _productosSeleccionados
          .where((detalle) => detalle.productoReemplazoId == null)
          .toList();

      if (sinReemplazo.isNotEmpty) {
        return ValidationResult.error(
          'Debes seleccionar un reemplazo para todos los productos',
        );
      }
    }

    return ValidationResult.valid();
  }

  ValidationResult validateCantidad(String? value) {
    if (value == null || value.trim().isEmpty) {
      return ValidationResult.error('Requerido');
    }
    final cantidad = double.tryParse(value);
    if (cantidad == null || cantidad <= 0) {
      return ValidationResult.error('Inválido');
    }
    return ValidationResult.valid();
  }

  Future<OperacionComercial?> guardarOperacion() async {
    if (isViewOnly) return null;

    final validation = validateForm();
    if (!validation.isValid) {
      _setError(validation.errorMessage!);
      return null;
    }

    _setFormState(FormState.saving);

    try {
      // Obtener usuario actual
      final authService = AuthService();
      final currentUser = await authService.getCurrentUser();

      // Obtener ubicación
      final locationService = LocationService();
      Position? position;
      try {
        position = await locationService.getCurrentLocation();
      } catch (e) {
        // Si falla la ubicación, continuamos sin ella
        debugPrint('Error obteniendo ubicación: $e');
      }

      final operacion = OperacionComercial(
        id: operacionExistente?.id,
        clienteId: cliente.id!,
        tipoOperacion: tipoOperacion,
        fechaCreacion: operacionExistente?.fechaCreacion ?? DateTime.now(),
        fechaRetiro: _fechaRetiro,
        snc: tipoOperacion == TipoOperacion.notaRetiro ? _snc : null,
        totalProductos: _productosSeleccionados.length,
        usuarioId: currentUser?.id ?? 1,
        employeeId: currentUser?.employeeId,
        latitud: position?.latitude,
        longitud: position?.longitude,
        syncStatus: 'creado',
        detalles: _productosSeleccionados,
      );

      // Guardar la operación en la base de datos
      final operacionId = await _operacionRepository.crearOperacion(operacion);

      // Recargar la operación completa desde la DB con sus detalles
      final operacionCompleta = await _operacionRepository
          .obtenerOperacionPorId(operacionId);

      _setFormState(FormState.idle);

      // Si por alguna razón falla la recarga, devolver la operación con el ID
      if (operacionCompleta == null) {
        return operacion.copyWith(id: operacionId);
      }

      return operacionCompleta;
    } catch (e) {
      _setError('Error al guardar: $e');
      return null;
    }
  }

  void _setFormState(FormState state) {
    _formState = state;
    if (state != FormState.error) _errorMessage = null;
    notifyListeners();
  }

  void _setError(String message) {
    _formState = FormState.error;
    _errorMessage = message;
    notifyListeners();
  }

  void clearError() {
    if (_formState == FormState.error) {
      _formState = FormState.idle;
      _errorMessage = null;
      notifyListeners();
    }
  }

  bool _hasChanges() {
    if (isViewOnly) return false;

    if (operacionExistente == null) {
      return _productosSeleccionados.isNotEmpty ||
          _fechaRetiro != null ||
          _snc != null;
    }

    // Check for changes in main operation fields
    if (_fechaRetiro != operacionExistente!.fechaRetiro ||
        _snc != operacionExistente!.snc) {
      return true;
    }

    // Check for changes in product details
    if (_productosSeleccionados.length != operacionExistente!.detalles.length) {
      return true;
    }

    // Compare each product detail
    for (int i = 0; i < _productosSeleccionados.length; i++) {
      final currentDetail = _productosSeleccionados[i];
      final originalDetail = operacionExistente!.detalles[i];

      // Assuming details are ordered or can be matched by product ID
      // For simplicity, we'll compare by index. A more robust solution might match by product ID.
      if (currentDetail.productoId != originalDetail.productoId ||
          currentDetail.cantidad != originalDetail.cantidad ||
          currentDetail.productoReemplazoId !=
              originalDetail.productoReemplazoId) {
        return true;
      }
    }

    return false; // No changes found
  }

  Future<bool> sincronizarOperacionActual() async {
    if (_operacionActual == null || cliente.id == null) return false;

    _setFormState(FormState.loading);

    try {
      // 1. Si tiene adaSequence, intentar obtener odooName específicamente
      if (_operacionActual!.adaSequence != null &&
          _operacionActual!.adaSequence!.isNotEmpty) {
        final odooStatus = await OperacionComercialSyncService.obtenerOdooName(
          _operacionActual!.adaSequence!,
        );

        if (odooStatus != null && odooStatus.isNotEmpty) {
          await _operacionRepository.marcarComoMigrado(
            _operacionActual!.id!,
            _operacionActual!.serverId,
            odooName: odooStatus['odooName'],
            estadoOdoo: odooStatus['estadoOdoo'],
            motivoOdoo: odooStatus['motivoOdoo'],
            ordenTransporteOdoo: odooStatus['ordenDeTransporteOdoo'],
            adaEstado: odooStatus['adaEstado'],
          );

          final operacionActualizada = await _operacionRepository
              .obtenerOperacionPorId(_operacionActual!.id!);

          if (operacionActualizada != null) {
            _operacionActual = operacionActualizada;
            _cargarOperacionExistente();
            _setFormState(FormState.idle);
            return true;
          }
        }
      }

      // 2. Fallback: Sincronización general por cliente
      await OperacionComercialSyncService.obtenerOperacionesPorCliente(
        cliente.id!,
      );

      final operacionActualizada = await _operacionRepository
          .obtenerOperacionPorId(_operacionActual!.id!);

      if (operacionActualizada != null) {
        _operacionActual = operacionActualizada;
        _cargarOperacionExistente();
      }

      _setFormState(FormState.idle);
      return true;
    } catch (e) {
      _setError('Error al descargar: $e');
      _setFormState(FormState.idle);
      return false;
    }
  }

  Future<Producto?> obtenerProductoPorId(int productoId) async {
    try {
      return await _productoRepository.obtenerProductoPorId(productoId);
    } catch (e) {
      AppLogger.e("OPERACION_COMERCIAL_VIEWMODEL: Error", e);
      return null;
    }
  }
}
