import 'package:flutter/foundation.dart';
import 'package:ada_app/models/cliente.dart';
import 'package:ada_app/models/producto.dart';
import 'package:ada_app/models/operaciones_comerciales/enums/tipo_operacion.dart';
import 'package:ada_app/models/operaciones_comerciales/operacion_comercial.dart';
import 'package:ada_app/models/operaciones_comerciales/operacion_comercial_detalle.dart';
import 'package:ada_app/services/post/operaciones_comerciales_post_service.dart';
import 'package:ada_app/repositories/operacion_comercial_repository.dart';
import 'package:ada_app/repositories/producto_repository.dart';

import '../../utils/unidad_medida_helper.dart';

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
  final OperacionComercial? operacionExistente;

  FormState _formState = FormState.idle;
  String? _errorMessage;

  DateTime? _fechaRetiro;
  String? _snc;
  List<OperacionComercialDetalle> _productosSeleccionados = [];
  String _observaciones = '';

  String _searchQuery = '';
  List<Producto> _productosFiltrados = [];
  List<Producto> _productosDisponibles = [];

  OperacionComercialFormViewModel({
    required this.cliente,
    required this.tipoOperacion,
    this.operacionExistente,
    this.isViewOnly = false,
    OperacionComercialRepository? operacionRepository,
    ProductoRepository? productoRepository,
  }) : _operacionRepository =
           operacionRepository ?? OperacionComercialRepositoryImpl(),
       _productoRepository = productoRepository ?? ProductoRepositoryImpl() {
    _initializeForm();
  }

  FormState get formState => _formState;
  String? get errorMessage => _errorMessage;
  DateTime? get fechaRetiro => _fechaRetiro;
  String? get snc => _snc;
  List<OperacionComercialDetalle> get productosSeleccionados =>
      List.unmodifiable(_productosSeleccionados);
  String get observaciones => _observaciones;
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
    _observaciones = operacion.observaciones ?? '';
    _fechaRetiro = operacion.fechaRetiro;
    _snc = operacion.snc;
    _productosSeleccionados = List.from(operacion.detalles);
    notifyListeners();
  }

  Future<void> _cargarProductosIniciales() async {
    try {} catch (e) {}
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

  void setObservaciones(String observaciones) {
    if (isViewOnly) return;
    _observaciones = observaciones;
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
    } catch (e) {
      _productosFiltrados = [];
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
      print('Producto ya seleccionado');
      return false;
    }

    final errorUnidad = tipoOperacion.validarUnidadMedida(
      producto.unidadMedida,
    );
    if (errorUnidad != null) {
      print('Error de unidad: $errorUnidad');
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

    print('Producto válido, agregando...');

    final detalle = OperacionComercialDetalle(
      operacionComercialId: '',
      productoId: producto.id!,
      cantidad: 0.0,
      orden: _productosSeleccionados.length + 1,
      fechaCreacion: DateTime.now(),
    );

    _productosSeleccionados.add(detalle);

    print(
      'Producto agregado a la lista: ${_productosSeleccionados.length} productos',
    );
    print('Limpiando búsqueda...');

    clearSearch();
    notifyListeners();

    print('notifyListeners() llamado');

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

  /// ✅ MÉTODO CORREGIDO - Ahora recarga la operación completa con detalles
  Future<OperacionComercial?> guardarOperacion() async {
    if (isViewOnly) return null;

    final validation = validateForm();
    if (!validation.isValid) {
      _setError(validation.errorMessage!);
      return null;
    }

    _setFormState(FormState.saving);

    try {
      final operacion = OperacionComercial(
        id: operacionExistente?.id,
        clienteId: cliente.id!,
        tipoOperacion: tipoOperacion,
        fechaCreacion: operacionExistente?.fechaCreacion ?? DateTime.now(),
        fechaRetiro: _fechaRetiro,
        snc: tipoOperacion == TipoOperacion.notaRetiro ? _snc : null,
        observaciones: _observaciones.isEmpty ? null : _observaciones,
        totalProductos: _productosSeleccionados.length,
        usuarioId: 1,
        syncStatus: 'creado',
        detalles: _productosSeleccionados,
      );

      // Guardar la operación en la base de datos
      final operacionId = await _operacionRepository.crearOperacion(operacion);

      // ✅ SOLUCIÓN: Recargar la operación completa desde la DB con sus detalles
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
          _observaciones.isNotEmpty ||
          _fechaRetiro != null ||
          _snc != null;
    }

    return _observaciones != (operacionExistente!.observaciones ?? '') ||
        _fechaRetiro != operacionExistente!.fechaRetiro ||
        _snc != operacionExistente!.snc ||
        _productosSeleccionados.length != operacionExistente!.detalles.length;
  }

  Future<Producto?> obtenerProductoPorId(int productoId) async {
    try {
      return await _productoRepository.obtenerProductoPorId(productoId);
    } catch (e) {
      return null;
    }
  }
}
