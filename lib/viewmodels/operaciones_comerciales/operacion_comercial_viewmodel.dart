import 'package:flutter/foundation.dart';
import 'package:ada_app/models/cliente.dart';
import 'package:ada_app/models/producto.dart';
import 'package:ada_app/models/operaciones_comerciales/enums/tipo_operacion.dart';
import 'package:ada_app/models/operaciones_comerciales/enums/estado_operacion.dart';
import 'package:ada_app/models/operaciones_comerciales/operacion_comercial.dart';
import 'package:ada_app/models/operaciones_comerciales/operacion_comercial_detalle.dart';
import 'package:ada_app/repositories/operacion_comercial_repository.dart';
import 'package:ada_app/repositories/producto_repository.dart';

/// Estados del formulario
enum FormState { idle, loading, saving, error }

/// Resultado de validación
class ValidationResult {
  final bool isValid;
  final String? errorMessage;

  ValidationResult.valid() : isValid = true, errorMessage = null;
  ValidationResult.error(this.errorMessage) : isValid = false;
}

/// ViewModel para el formulario de operación comercial
class OperacionComercialFormViewModel extends ChangeNotifier {
  // Dependencias - Repositories
  final OperacionComercialRepository _operacionRepository;
  final ProductoRepository _productoRepository;

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
  List<Producto> _productosFiltrados = [];
  List<Producto> _productosDisponibles = [];

  OperacionComercialFormViewModel({
    required this.cliente,
    required this.tipoOperacion,
    this.operacionExistente,
    OperacionComercialRepository? operacionRepository,
    ProductoRepository? productoRepository,
  })  : _operacionRepository = operacionRepository ?? OperacionComercialRepositoryImpl(),
        _productoRepository = productoRepository ?? ProductoRepositoryImpl() {
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
  List<Producto> get productosFiltrados => List.unmodifiable(_productosFiltrados);

  bool get isLoading => _formState == FormState.loading;
  bool get isSaving => _formState == FormState.saving;
  bool get hasError => _formState == FormState.error;
  bool get isFormDirty => _hasChanges();

  int get totalProductos => _productosSeleccionados.length;
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
      _productosDisponibles = await _productoRepository.obtenerProductosDisponibles();
      _setFormState(FormState.idle);
    } catch (e) {
      _setError('Error cargando productos: $e');
    }
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

  Future<void> _filtrarProductos() async {
    if (_searchQuery.isEmpty) {
      _productosFiltrados = [];
      return;
    }

    try {
      _productosFiltrados = await _productoRepository.buscarProductos(_searchQuery);
    } catch (e) {
      print('Error filtrando productos: $e');
      _productosFiltrados = [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // MANEJO DE PRODUCTOS
  // ═══════════════════════════════════════════════════════════════════

  bool isProductoSeleccionado(String? codigoProducto) {
    if (codigoProducto == null) return false;
    return _productosSeleccionados.any((detalle) => detalle.productoCodigo == codigoProducto);
  }

  void agregarProducto(Producto producto) {
    if (producto.codigo == null || isProductoSeleccionado(producto.codigo)) {
      return;
    }

    final cantidadInicial = 0.0;

    final detalle = OperacionComercialDetalle(
      operacionComercialId: '',
      productoCodigo: producto.codigo!,
      productoDescripcion: producto.nombre ?? 'Sin nombre',
      productoCategoria: producto.categoria,
      productoId: producto.id, // 👈 NUEVO: Guardar el ID
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
      for (int i = 0; i < _productosSeleccionados.length; i++) {
        _productosSeleccionados[i] = _productosSeleccionados[i].copyWith(orden: i + 1);
      }
      notifyListeners();
    }
  }

  void actualizarCantidadProducto(int index, double cantidad) {
    if (index >= 0 && index < _productosSeleccionados.length) {
      if (cantidad < 0) {
        cantidad = 0;
      }

      _productosSeleccionados[index] = _productosSeleccionados[index].copyWith(
        cantidad: cantidad,
      );
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // MANEJO DE PRODUCTOS DE REEMPLAZO (PARA DISCONTINUOS)
  // ═══════════════════════════════════════════════════════════════════

  Future<List<Producto>> getProductosReemplazo(
      String? categoriaOriginal,
      String? codigoOriginal,
      int? idProductoActual, // 👈 NUEVO PARÁMETRO
      ) async {
    if (categoriaOriginal == null) return [];

    try {
      return await _productoRepository.obtenerProductosPorCategoria(
        categoriaOriginal,
        excluirId: idProductoActual, // 👈 Usar ID en lugar de código
      );
    } catch (e) {
      print('Error obteniendo productos de reemplazo: $e');
      return [];
    }
  }

  void setProductoReemplazo(int index, Producto productoReemplazo) {
    if (index >= 0 && index < _productosSeleccionados.length) {
      _productosSeleccionados[index] = _productosSeleccionados[index].copyWith(
        productoReemplazoCodigo: productoReemplazo.codigo,
        productoReemplazoDescripcion: productoReemplazo.nombre ?? 'Sin nombre',
        productoReemplazoCategoria: productoReemplazo.categoria,
      );
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // VALIDACIONES MEJORADAS CON MENSAJES ESPECÍFICOS
  // ═══════════════════════════════════════════════════════════════════

  ValidationResult validateForm() {
    if (tipoOperacion.necesitaFechaRetiro && _fechaRetiro == null) {
      return ValidationResult.error('⚠️ Falta seleccionar la fecha de retiro');
    }

    if (_productosSeleccionados.isEmpty) {
      return ValidationResult.error('⚠️ Debes agregar al menos un producto a la operación');
    }

    final productosSinCantidad = _productosSeleccionados
        .asMap()
        .entries
        .where((entry) => entry.value.cantidad <= 0)
        .toList();

    if (productosSinCantidad.isNotEmpty) {
      final nombresProductos = productosSinCantidad
          .take(3)
          .map((entry) => '• ${entry.value.productoDescripcion}')
          .join('\n');

      final cantidadRestante = productosSinCantidad.length > 3
          ? ' y ${productosSinCantidad.length - 3} más'
          : '';

      return ValidationResult.error(
          '⚠️ Los siguientes productos tienen cantidad inválida (debe ser mayor a 0):\n'
              '$nombresProductos$cantidadRestante'
      );
    }

    if (tipoOperacion == TipoOperacion.notaRetiroDiscontinuos) {
      final sinReemplazo = _productosSeleccionados
          .asMap()
          .entries
          .where((entry) =>
      entry.value.productoReemplazoCodigo == null ||
          entry.value.productoReemplazoCodigo!.isEmpty)
          .toList();

      if (sinReemplazo.isNotEmpty) {
        final nombresProductos = sinReemplazo
            .take(3)
            .map((entry) => '• ${entry.value.productoDescripcion}')
            .join('\n');

        final cantidadRestante = sinReemplazo.length > 3
            ? ' y ${sinReemplazo.length - 3} más'
            : '';

        return ValidationResult.error(
            '⚠️ Los siguientes productos necesitan un reemplazo:\n'
                '$nombresProductos$cantidadRestante'
        );
      }

      final categoriasDiferentes = _productosSeleccionados
          .asMap()
          .entries
          .where((entry) =>
      entry.value.productoCategoria != entry.value.productoReemplazoCategoria)
          .toList();

      if (categoriasDiferentes.isNotEmpty) {
        final detalles = categoriasDiferentes
            .take(2)
            .map((entry) =>
        '• ${entry.value.productoDescripcion} (${entry.value.productoCategoria}) '
            '→ Reemplazo (${entry.value.productoReemplazoCategoria})')
            .join('\n');

        return ValidationResult.error(
            '⚠️ Los productos de reemplazo deben ser de la misma categoría:\n'
                '$detalles'
        );
      }
    }

    return ValidationResult.valid();
  }

  ValidationResult validateCantidad(String? value) {
    if (value == null || value.trim().isEmpty) {
      return ValidationResult.error('⚠️ La cantidad es obligatoria');
    }

    final cantidad = double.tryParse(value);
    if (cantidad == null) {
      return ValidationResult.error('⚠️ Debes ingresar un número válido');
    }

    if (cantidad <= 0) {
      return ValidationResult.error('⚠️ La cantidad debe ser mayor a 0');
    }

    return ValidationResult.valid();
  }

  // ═══════════════════════════════════════════════════════════════════
  // GUARDADO
  // ═══════════════════════════════════════════════════════════════════

  Future<bool> guardarOperacion() async {
    final validation = validateForm();
    if (!validation.isValid) {
      _setError(validation.errorMessage!);
      return false;
    }

    _setFormState(FormState.saving);

    try {
      final operacion = OperacionComercial(
        id: operacionExistente?.id,
        clienteId: cliente.id!,
        tipoOperacion: tipoOperacion,
        fechaCreacion: operacionExistente?.fechaCreacion ?? DateTime.now(),
        fechaRetiro: _fechaRetiro,
        estado: EstadoOperacion.borrador,
        observaciones: _observaciones.isEmpty ? null : _observaciones,
        totalProductos: _productosSeleccionados.length,
        usuarioId: 1,
        estaSincronizado: false,
        syncStatus: 'pending',
        intentosSync: 0,
        detalles: _productosSeleccionados,
      );

      if (operacionExistente != null) {
        await _operacionRepository.actualizarOperacion(operacion);
      } else {
        await _operacionRepository.crearOperacion(operacion);
      }

      _setFormState(FormState.idle);
      return true;
    } catch (e) {
      _setError('❌ Error al guardar: $e');
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

  bool _hasChanges() {
    if (operacionExistente == null) {
      return _productosSeleccionados.isNotEmpty || _observaciones.isNotEmpty || _fechaRetiro != null;
    }

    return _observaciones != (operacionExistente!.observaciones ?? '') ||
        _fechaRetiro != operacionExistente!.fechaRetiro ||
        _productosSeleccionados.length != operacionExistente!.detalles.length;
  }

  @override
  void dispose() {
    super.dispose();
  }
}