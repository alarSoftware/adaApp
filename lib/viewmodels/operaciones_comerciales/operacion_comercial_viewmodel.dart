import 'package:flutter/foundation.dart';
import 'package:ada_app/models/cliente.dart';
import 'package:ada_app/models/producto.dart';
import 'package:ada_app/models/operaciones_comerciales/enums/tipo_operacion.dart';
import 'package:ada_app/models/operaciones_comerciales/enums/estado_operacion.dart';
import 'package:ada_app/models/operaciones_comerciales/operacion_comercial.dart';
import 'package:ada_app/models/operaciones_comerciales/operacion_comercial_detalle.dart';
import 'package:ada_app/services/post/operaciones_comerciales_post_service.dart';
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
  final bool isViewOnly;

  // Datos básicos
  final Cliente cliente;
  final TipoOperacion tipoOperacion;
  final OperacionComercial? operacionExistente;

  // Estado del formulario
  FormState _formState = FormState.idle;
  String? _errorMessage;

  // Datos del formulario
  DateTime? _fechaRetiro;
  List<OperacionComercialDetalle> _productosSeleccionados = [];
  String _observaciones = '';

  // Búsqueda de productos
  String _searchQuery = '';
  List<Producto> _productosFiltrados = [];
  List<Producto> _productosDisponibles = []; // Cache de productos si es necesario

  OperacionComercialFormViewModel({
    required this.cliente,
    required this.tipoOperacion,
    this.operacionExistente,
    this.isViewOnly = false,
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
    // Precargar productos si es necesario, o dejarlo bajo demanda en búsqueda
    _cargarProductosIniciales();
  }

  void _cargarOperacionExistente() {
    final operacion = operacionExistente!;
    _observaciones = operacion.observaciones ?? '';
    _fechaRetiro = operacion.fechaRetiro;
    // Crear una copia de la lista para no mutar el objeto original directamente
    _productosSeleccionados = List.from(operacion.detalles);
    notifyListeners();
  }

  Future<void> _cargarProductosIniciales() async {
    // Opcional: Cargar productos disponibles al inicio si no son demasiados
    try {
      // _productosDisponibles = await _productoRepository.obtenerProductosDisponibles();
    } catch (e) {
      print('Error carga inicial productos: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // MANEJO DE FECHA
  // ═══════════════════════════════════════════════════════════════════

  void setFechaRetiro(DateTime? fecha) {
    if (isViewOnly) return; // 👈 NUEVO: Bloqueo en modo lectura
    _fechaRetiro = fecha;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════
  // MANEJO DE OBSERVACIONES
  // ═══════════════════════════════════════════════════════════════════

  void setObservaciones(String observaciones) {
    if (isViewOnly) return; // 👈 NUEVO: Bloqueo en modo lectura
    _observaciones = observaciones;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════
  // BÚSQUEDA DE PRODUCTOS
  // ═══════════════════════════════════════════════════════════════════

  void setSearchQuery(String query) {
    if (isViewOnly) return; // 👈 NUEVO: Bloqueo en modo lectura
    _searchQuery = query;
    _filtrarProductos();
    notifyListeners();
  }

  void clearSearch() {
    if (isViewOnly) return; // 👈 NUEVO: Bloqueo en modo lectura
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
  // MANEJO DE PRODUCTOS (AGREGAR / QUITAR / CANTIDAD)
  // ═══════════════════════════════════════════════════════════════════

  bool isProductoSeleccionado(String? codigoProducto) {
    if (codigoProducto == null) return false;
    return _productosSeleccionados.any((detalle) => detalle.productoCodigo == codigoProducto);
  }

  void agregarProducto(Producto producto) {
    if (isViewOnly) return; // 👈 NUEVO: Bloqueo en modo lectura

    // Validación básica para no duplicar por código
    if (producto.codigo == null || isProductoSeleccionado(producto.codigo)) {
      return;
    }

    final cantidadInicial = 0.0;

    final detalle = OperacionComercialDetalle(
      operacionComercialId: '', // Se asignará al guardar o por backend
      productoCodigo: producto.codigo!,
      productoDescripcion: producto.nombre ?? 'Sin nombre',
      productoCategoria: producto.categoria,
      productoId: producto.id,
      cantidad: cantidadInicial,
      unidadMedida: 'UN', // O obtener del producto si existe
      orden: _productosSeleccionados.length + 1,
      fechaCreacion: DateTime.now(),
      estaSincronizado: false,
    );

    _productosSeleccionados.add(detalle);
    notifyListeners();
  }

  void eliminarProducto(int index) {
    if (isViewOnly) return; // 👈 NUEVO: Bloqueo en modo lectura

    if (index >= 0 && index < _productosSeleccionados.length) {
      _productosSeleccionados.removeAt(index);
      // Reordenar secuencialmente
      for (int i = 0; i < _productosSeleccionados.length; i++) {
        _productosSeleccionados[i] = _productosSeleccionados[i].copyWith(orden: i + 1);
      }
      notifyListeners();
    }
  }

  void actualizarCantidadProducto(int index, double cantidad) {
    if (isViewOnly) return; // 👈 NUEVO: Bloqueo en modo lectura

    if (index >= 0 && index < _productosSeleccionados.length) {
      if (cantidad < 0) cantidad = 0;

      _productosSeleccionados[index] = _productosSeleccionados[index].copyWith(
        cantidad: cantidad,
      );
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // MANEJO DE PRODUCTOS DE REEMPLAZO (CORREGIDO ✅)
  // ═══════════════════════════════════════════════════════════════════

  // 👈 NUEVO: Método que espera el FormScreen (obtenerProductosReemplazo)
  Future<List<Producto>> obtenerProductosReemplazo(Producto productoOriginal) async {
    // Verificamos que tenga categoría
    if (productoOriginal.categoria == null) {
      print('Producto sin categoría: ${productoOriginal.nombre}');
      return [];
    }

    try {
      return await _productoRepository.obtenerProductosPorCategoria(
        productoOriginal.categoria!, // 👈 Usamos ! porque ya verificamos que no es null
        excluirId: productoOriginal.id,
      );
    } catch (e) {
      print('Error obteniendo productos de reemplazo: $e');
      return [];
    }
  }

  // Método original renombrado para claridad
  Future<List<Producto>> getProductosReemplazo(
      String? categoriaOriginal,
      String? codigoOriginal,
      int? idProductoActual,
      ) async {
    if (categoriaOriginal == null) return [];

    try {
      return await _productoRepository.obtenerProductosPorCategoria(
        categoriaOriginal!, // 👈 Usamos ! porque ya verificamos que no es null arriba
        excluirId: idProductoActual,
      );
    } catch (e) {
      print('Error obteniendo productos de reemplazo: $e');
      return [];
    }
  }

  // 👈 NUEVO: Método que espera el FormScreen (seleccionarProductoReemplazo)
  void seleccionarProductoReemplazo(int index, Producto productoReemplazo) {
    if (isViewOnly) return; // Bloqueo en modo lectura
    setProductoReemplazo(index, productoReemplazo);
  }

  void setProductoReemplazo(int index, Producto productoReemplazo) {
    if (isViewOnly) return; // 👈 NUEVO: Bloqueo en modo lectura

    if (index >= 0 && index < _productosSeleccionados.length) {
      // ✅ SOLUCIÓN APLICADA: Guardamos el ID y la categoría explícitamente
      // Si el código viene vacío, ponemos un placeholder o lo dejamos vacío,
      // pero la validación dependerá del ID.

      _productosSeleccionados[index] = _productosSeleccionados[index].copyWith(
        // 1. Guardamos el ID para validación de existencia
        productoReemplazoId: productoReemplazo.id,

        // 2. Guardamos datos descriptivos
        productoReemplazoCodigo: productoReemplazo.codigo ?? 'S/C',
        productoReemplazoDescripcion: productoReemplazo.nombre ?? 'Sin nombre',

        // 3. Guardamos categoría para validación de negocio
        productoReemplazoCategoria: productoReemplazo.categoria,
      );
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // VALIDACIONES (CORREGIDAS ✅)
  // ═══════════════════════════════════════════════════════════════════

  ValidationResult validateForm() {
    // En modo solo lectura no validamos
    if (isViewOnly) return ValidationResult.valid();

    // 1. Fecha de retiro
    if (tipoOperacion.necesitaFechaRetiro && _fechaRetiro == null) {
      return ValidationResult.error('⚠️ Falta seleccionar la fecha de retiro');
    }

    // 2. Mínimo un producto
    if (_productosSeleccionados.isEmpty) {
      return ValidationResult.error('⚠️ Debes agregar al menos un producto a la operación');
    }

    // 3. Cantidades válidas
    final productosSinCantidad = _productosSeleccionados
        .where((detalle) => detalle.cantidad <= 0)
        .toList();

    if (productosSinCantidad.isNotEmpty) {
      final nombres = productosSinCantidad
          .take(3)
          .map((d) => '• ${d.productoDescripcion}')
          .join('\n');
      return ValidationResult.error(
          '⚠️ Productos con cantidad 0:\n$nombres' +
              (productosSinCantidad.length > 3 ? '\n...y más.' : ''));
    }

    // 4. Validación específica para DISCONTINUOS
    if (tipoOperacion == TipoOperacion.notaRetiroDiscontinuos) {

      // A) ¿Se seleccionó un reemplazo? (Usamos ID, no código)
      final sinReemplazo = _productosSeleccionados
          .where((detalle) => detalle.productoReemplazoId == null)
          .toList();

      if (sinReemplazo.isNotEmpty) {
        final nombres = sinReemplazo
            .take(3)
            .map((d) => '• ${d.productoDescripcion}')
            .join('\n');
        return ValidationResult.error(
            '⚠️ Debes seleccionar un reemplazo para:\n$nombres');
      }

      // B) ¿El reemplazo es de la misma categoría?
      final categoriasDiferentes = _productosSeleccionados
          .where((detalle) =>
      detalle.productoReemplazoId != null && // Ya sabemos que existe
          detalle.productoCategoria != detalle.productoReemplazoCategoria)
          .toList();

      if (categoriasDiferentes.isNotEmpty) {
        final detalles = categoriasDiferentes
            .take(2)
            .map((d) =>
        '• ${d.productoDescripcion} (${d.productoCategoria}) \n'
            '   → Intenta reemplazar con (${d.productoReemplazoCategoria})')
            .join('\n\n');

        return ValidationResult.error(
            '⚠️ Los reemplazos deben ser de la misma categoría:\n\n$detalles');
      }
    }

    return ValidationResult.valid();
  }

  // Helper para validación individual de campos de texto (si usas TextFormField)
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

  // ═══════════════════════════════════════════════════════════════════
  // GUARDADO
  // ═══════════════════════════════════════════════════════════════════

  Future<bool> guardarOperacion() async {
    if (isViewOnly) return false;

    final validation = validateForm();
    if (!validation.isValid) {
      _setError(validation.errorMessage!);
      return false;
    }

    _setFormState(FormState.saving);

    try {
      // 1. Preparar el objeto (igual que antes)
      var operacion = OperacionComercial( // Cambié final por var para poder actualizarla
        id: operacionExistente?.id,
        clienteId: cliente.id!,
        tipoOperacion: tipoOperacion,
        fechaCreacion: operacionExistente?.fechaCreacion ?? DateTime.now(),
        fechaRetiro: _fechaRetiro,
        estado: EstadoOperacion.borrador,
        observaciones: _observaciones.isEmpty ? null : _observaciones,
        totalProductos: _productosSeleccionados.length,
        usuarioId: 1, // Ajustar según auth
        estaSincronizado: false,
        syncStatus: 'pending',
        intentosSync: 0,
        detalles: _productosSeleccionados,
      );

      // 2. Guardar en BD Local (igual que antes)
      if (operacionExistente != null) {
        await _operacionRepository.actualizarOperacion(operacion);
      } else {
        await _operacionRepository.crearOperacion(operacion);
      }

      // 3. INTENTAR ENVIAR AL SERVIDOR (NUEVO) <---
      try {
        final resultado = await OperacionesComercialesPostService.enviarOperacion(operacion);

        if (resultado['exito'] == true) {
          // Si se envió bien, actualizamos el estado local a 'sincronizado' o 'enviado'
          operacion = operacion.copyWith(
            estaSincronizado: true,
            syncStatus: 'synced',
            estado: EstadoOperacion.sincronizado, // O el estado que prefieras
            serverId: resultado['id'], // Si el server devuelve ID
            fechaSincronizacion: DateTime.now(),
          );

          // Actualizamos en local el nuevo estado
          await _operacionRepository.actualizarOperacion(operacion);
        }
      } catch (e) {
        print('Error al intentar enviar online: $e');
        // No fallamos el guardado general, solo queda pendiente de sync
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
    // En modo solo lectura nunca hay cambios
    if (isViewOnly) return false;

    if (operacionExistente == null) {
      return _productosSeleccionados.isNotEmpty ||
          _observaciones.isNotEmpty ||
          _fechaRetiro != null;
    }

    return _observaciones != (operacionExistente!.observaciones ?? '') ||
        _fechaRetiro != operacionExistente!.fechaRetiro ||
        _productosSeleccionados.length != operacionExistente!.detalles.length;
  }
}