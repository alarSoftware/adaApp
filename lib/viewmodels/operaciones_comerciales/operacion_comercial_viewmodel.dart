// lib/ui/screens/operaciones_comerciales/viewmodels/operacion_comercial_form_viewmodel.dart
import 'package:flutter/foundation.dart';
import 'package:ada_app/models/cliente.dart';
import 'package:ada_app/models/operaciones_comerciales/enums/tipo_operacion.dart';
import 'package:ada_app/models/operaciones_comerciales/enums/estado_operacion.dart';
import 'package:ada_app/models/operaciones_comerciales/operacion_comercial.dart';
import 'package:ada_app/models/operaciones_comerciales/operacion_comercial_detalle.dart';
import 'package:ada_app/repositories/operacion_comercial_repository.dart';

/// Estados del formulario
enum FormState { idle, loading, saving, error }

/// Resultado de validación
class ValidationResult {
  final bool isValid;
  final String? errorMessage;

  ValidationResult.valid() : isValid = true, errorMessage = null;
  ValidationResult.error(this.errorMessage) : isValid = false;
}

/// Clase para representar productos disponibles
/// TODO: Integrar con tu repository de productos real
class ProductoDisponible {
  final String codigo;
  final String descripcion;
  final String categoria;

  ProductoDisponible({
    required this.codigo,
    required this.descripcion,
    required this.categoria,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is ProductoDisponible &&
              runtimeType == other.runtimeType &&
              codigo == other.codigo;

  @override
  int get hashCode => codigo.hashCode;

  @override
  String toString() => 'ProductoDisponible{codigo: $codigo, descripcion: $descripcion}';
}

/// ViewModel para el formulario de operación comercial
/// Integrado completamente con tu modelo OperacionComercial real
class OperacionComercialFormViewModel extends ChangeNotifier {
  // Dependencias - Repository
  final OperacionComercialRepository _operacionRepository;

  // Datos básicos
  final Cliente cliente;
  final TipoOperacion tipoOperacion;
  final OperacionComercial? operacionExistente;

  // Estado del formulario
  FormState _formState = FormState.idle;
  String? _errorMessage;

  // Datos del formulario usando tu modelo
  DateTime? _fechaRetiro;
  List<OperacionComercialDetalle> _productosSeleccionados = [];
  String _observaciones = '';

  // Búsqueda de productos
  String _searchQuery = '';
  List<ProductoDisponible> _productosFiltrados = [];
  List<ProductoDisponible> _productosDisponibles = [];

  OperacionComercialFormViewModel({
    required this.cliente,
    required this.tipoOperacion,
    this.operacionExistente,
    OperacionComercialRepository? operacionRepository,
  }) : _operacionRepository = operacionRepository ?? OperacionComercialRepositoryImpl() {
    _initializeForm();
  }

  // ═══════════════════════════════════════════════════════════════════
  // GETTERS
  // ═══════════════════════════════════════════════════════════════════

  FormState get formState => _formState;
  String? get errorMessage => _errorMessage;
  DateTime? get fechaRetiro => _fechaRetiro;
  List<OperacionComercialDetalle> get productosSeleccionados =>
      List.unmodifiable(_productosSeleccionados);
  String get observaciones => _observaciones;
  String get searchQuery => _searchQuery;
  List<ProductoDisponible> get productosFiltrados =>
      List.unmodifiable(_productosFiltrados);

  bool get isLoading => _formState == FormState.loading;
  bool get isSaving => _formState == FormState.saving;
  bool get hasError => _formState == FormState.error;
  bool get isFormDirty => _hasChanges();

  // Usar tu modelo real
  int get totalProductos => _productosSeleccionados.length;

  // Getter para saber si necesita fecha de retiro usando tu enum extension
  bool get necesitaFechaRetiro => tipoOperacion.necesitaFechaRetiro;

  // ═══════════════════════════════════════════════════════════════════
  // INICIALIZACIÓN
  // ═══════════════════════════════════════════════════════════════════

  void _initializeForm() {
    if (operacionExistente != null) {
      _cargarOperacionExistente();
    }
    _cargarProductos();
  }

  void _cargarOperacionExistente() {
    final operacion = operacionExistente!;
    _observaciones = operacion.observaciones ?? '';
    _fechaRetiro = operacion.fechaRetiro;
    _productosSeleccionados = List.from(operacion.detalles);
    notifyListeners();
  }

  Future<void> _cargarProductos() async {
    try {
      _setFormState(FormState.loading);

      // TODO: Integrar con tu repository de productos real
      // Por ahora usamos datos mock
      _productosDisponibles = _obtenerProductosMock();

      _setFormState(FormState.idle);

    } catch (e) {
      _setError('Error cargando productos: $e');
    }
  }

  /// Mock de productos - reemplazar por tu repository real
  List<ProductoDisponible> _obtenerProductosMock() {
    return [
      ProductoDisponible(codigo: 'PROD001', descripcion: 'Producto de ejemplo 1', categoria: 'Categoría A'),
      ProductoDisponible(codigo: 'PROD002', descripcion: 'Producto de ejemplo 2', categoria: 'Categoría A'),
      ProductoDisponible(codigo: 'PROD003', descripcion: 'Producto de ejemplo 3', categoria: 'Categoría B'),
      ProductoDisponible(codigo: 'PROD004', descripcion: 'Producto de ejemplo 4', categoria: 'Categoría B'),
      ProductoDisponible(codigo: 'PROD005', descripcion: 'Producto de ejemplo 5', categoria: 'Categoría C'),
    ];
  }

  // ═══════════════════════════════════════════════════════════════════
  // MANEJO DE FECHA
  // ═══════════════════════════════════════════════════════════════════

  void setFechaRetiro(DateTime? fecha) {
    _fechaRetiro = fecha;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════
  // MANEJO DE OBSERVACIONES
  // ═══════════════════════════════════════════════════════════════════

  void setObservaciones(String observaciones) {
    _observaciones = observaciones;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════
  // BÚSQUEDA DE PRODUCTOS
  // ═══════════════════════════════════════════════════════════════════

  void setSearchQuery(String query) {
    _searchQuery = query;
    _filtrarProductos();
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    _productosFiltrados = [];
    notifyListeners();
  }

  void _filtrarProductos() {
    if (_searchQuery.isEmpty) {
      _productosFiltrados = [];
    } else {
      final searchLower = _searchQuery.toLowerCase();
      _productosFiltrados = _productosDisponibles.where((producto) {
        return producto.codigo.toLowerCase().contains(searchLower) ||
            producto.descripcion.toLowerCase().contains(searchLower);
      }).toList();
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // MANEJO DE PRODUCTOS
  // ═══════════════════════════════════════════════════════════════════

  bool isProductoSeleccionado(String codigoProducto) {
    return _productosSeleccionados
        .any((detalle) => detalle.productoCodigo == codigoProducto);
  }

  void agregarProducto(ProductoDisponible producto) {
    if (isProductoSeleccionado(producto.codigo)) {
      return;
    }

    final cantidadInicial = tipoOperacion == TipoOperacion.notaReposicion ? 3.0 : 1.0;

    // Usar tu modelo real de OperacionComercialDetalle
    final detalle = OperacionComercialDetalle(
      operacionComercialId: '', // Se asignará al guardar
      productoCodigo: producto.codigo,
      productoDescripcion: producto.descripcion,
      productoCategoria: producto.categoria,
      cantidad: cantidadInicial,
      unidadMedida: 'UN',
      orden: _productosSeleccionados.length + 1,
      fechaCreacion: DateTime.now(),
      estaSincronizado: false,
    );

    _productosSeleccionados.add(detalle);
    notifyListeners();
  }

  void eliminarProducto(int index) {
    if (index >= 0 && index < _productosSeleccionados.length) {
      _productosSeleccionados.removeAt(index);
      // Reordenar
      for (int i = 0; i < _productosSeleccionados.length; i++) {
        _productosSeleccionados[i] = _productosSeleccionados[i].copyWith(orden: i + 1);
      }
      notifyListeners();
    }
  }

  void actualizarCantidadProducto(int index, double cantidad) {
    if (index >= 0 && index < _productosSeleccionados.length) {
      _productosSeleccionados[index] = _productosSeleccionados[index].copyWith(
        cantidad: cantidad,
      );
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // MANEJO DE PRODUCTOS DE REEMPLAZO (PARA DISCONTINUOS)
  // ═══════════════════════════════════════════════════════════════════

  Future<List<ProductoDisponible>> getProductosReemplazo(String categoriaOriginal, String codigoOriginal) async {
    try {
      // TODO: Integrar con tu repository de productos real
      // Por ahora filtramos de los productos mock
      return _productosDisponibles
          .where((p) => p.categoria == categoriaOriginal && p.codigo != codigoOriginal)
          .toList();

    } catch (e) {
      print('Error obteniendo productos de reemplazo: $e');
      return [];
    }
  }

  void setProductoReemplazo(int index, ProductoDisponible productoReemplazo) {
    if (index >= 0 && index < _productosSeleccionados.length) {
      _productosSeleccionados[index] = _productosSeleccionados[index].copyWith(
        productoReemplazoCodigo: productoReemplazo.codigo,
        productoReemplazoDescripcion: productoReemplazo.descripcion,
        productoReemplazoCategoria: productoReemplazo.categoria,
      );
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // VALIDACIONES USANDO TU MODELO
  // ═══════════════════════════════════════════════════════════════════

  ValidationResult validateForm() {
    // Validar fecha de retiro usando tu extension
    if (tipoOperacion.necesitaFechaRetiro && _fechaRetiro == null) {
      return ValidationResult.error('Debes seleccionar una fecha de retiro');
    }

    // Validar que haya productos
    if (_productosSeleccionados.isEmpty) {
      return ValidationResult.error('Debes agregar al menos un producto');
    }

    // Validar cantidades
    final tieneCantidadesInvalidas = _productosSeleccionados.any(
          (detalle) => detalle.cantidad <= 0,
    );

    if (tieneCantidadesInvalidas) {
      return ValidationResult.error('Todas las cantidades deben ser mayores a 0');
    }

    // Validar intercambio en discontinuos
    if (tipoOperacion == TipoOperacion.notaRetiroDiscontinuos) {
      final sinReemplazo = _productosSeleccionados.where(
            (detalle) => detalle.productoReemplazoCodigo == null || detalle.productoReemplazoCodigo!.isEmpty,
      ).toList();

      if (sinReemplazo.isNotEmpty) {
        return ValidationResult.error(
            'Todos los productos discontinuados deben tener un producto de reemplazo'
        );
      }

      // Validar que los reemplazos sean de la misma categoría
      final categoriasDiferentes = _productosSeleccionados.where(
            (detalle) => detalle.productoCategoria != detalle.productoReemplazoCategoria,
      ).toList();

      if (categoriasDiferentes.isNotEmpty) {
        return ValidationResult.error(
            'Los productos de reemplazo deben ser de la misma categoría'
        );
      }
    }

    return ValidationResult.valid();
  }

  ValidationResult validateCantidad(String? value) {
    final cantidad = double.tryParse(value ?? '');
    if (cantidad == null || cantidad <= 0) {
      return ValidationResult.error('Cantidad inválida');
    }
    return ValidationResult.valid();
  }

  // ═══════════════════════════════════════════════════════════════════
  // GUARDADO USANDO TU MODELO COMPLETO
  // ═══════════════════════════════════════════════════════════════════

  Future<bool> guardarOperacion() async {
    // Validar formulario
    final validation = validateForm();
    if (!validation.isValid) {
      _setError(validation.errorMessage!);
      return false;
    }

    _setFormState(FormState.saving);

    try {
      // Crear operación comercial usando tu modelo completo
      final operacion = OperacionComercial(
        id: operacionExistente?.id, // null para nuevas operaciones
        clienteId: cliente.id!, // ✅ Usar ! para convertir int? a int
        tipoOperacion: tipoOperacion,
        fechaCreacion: operacionExistente?.fechaCreacion ?? DateTime.now(),
        fechaRetiro: _fechaRetiro,
        estado: EstadoOperacion.borrador, // Usar tu enum
        observaciones: _observaciones.isEmpty ? null : _observaciones,
        totalProductos: _productosSeleccionados.length,
        usuarioId: 1, // TODO: Obtener del usuario actual
        estaSincronizado: false,
        syncStatus: 'pending',
        intentosSync: 0,
        detalles: _productosSeleccionados,
      );

      if (operacionExistente != null) {
        // Actualizar operación existente
        await _operacionRepository.actualizarOperacion(operacion);
      } else {
        // Crear nueva operación
        await _operacionRepository.crearOperacion(operacion);
      }

      _setFormState(FormState.idle);
      return true;

    } catch (e) {
      _setError('Error al guardar: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // MÉTODOS PRIVADOS DE ESTADO
  // ═══════════════════════════════════════════════════════════════════

  void _setFormState(FormState state) {
    _formState = state;
    _errorMessage = null;
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

  // Verificar si hay cambios sin guardar
  bool _hasChanges() {
    if (operacionExistente == null) {
      return _productosSeleccionados.isNotEmpty ||
          _observaciones.isNotEmpty ||
          _fechaRetiro != null;
    }

    // Comparar con operación existente usando tu modelo
    return _observaciones != (operacionExistente!.observaciones ?? '') ||
        _fechaRetiro != operacionExistente!.fechaRetiro ||
        _productosSeleccionados.length != operacionExistente!.detalles.length;
  }

  @override
  void dispose() {
    super.dispose();
  }
}