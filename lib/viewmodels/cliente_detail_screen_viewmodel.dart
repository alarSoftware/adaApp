// viewmodels/cliente_detail_screen_viewmodel.dart
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:logger/logger.dart';
import '../models/cliente.dart';
import '../models/equipos_cliente.dart';
import '../repositories/equipo_cliente_repository.dart';

// ========== EVENTOS PARA LA UI ==========
abstract class ClienteDetailUIEvent {}

class ShowErrorEvent extends ClienteDetailUIEvent {
  final String message;
  ShowErrorEvent(this.message);
}

class NavigateToFormsEvent extends ClienteDetailUIEvent {
  final Cliente cliente;
  NavigateToFormsEvent(this.cliente);
}

class NavigateToEquipoDetailEvent extends ClienteDetailUIEvent {
  final EquipoCliente equipoCliente;
  NavigateToEquipoDetailEvent(this.equipoCliente);
}

class RefreshCompletedEvent extends ClienteDetailUIEvent {}

// ========== ESTADO PURO ==========
class ClienteDetailState {
  final bool isLoading;
  final List<Map<String, dynamic>> equiposCompletos;
  final List<EquipoCliente> equiposAsignados;
  final String? errorMessage;

  ClienteDetailState({
    this.isLoading = false,
    this.equiposCompletos = const [],
    this.equiposAsignados = const [],
    this.errorMessage,
  });

  ClienteDetailState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? equiposCompletos,
    List<EquipoCliente>? equiposAsignados,
    String? errorMessage,
  }) {
    return ClienteDetailState(
      isLoading: isLoading ?? this.isLoading,
      equiposCompletos: equiposCompletos ?? this.equiposCompletos,
      equiposAsignados: equiposAsignados ?? this.equiposAsignados,
      errorMessage: errorMessage,
    );
  }

  bool get hasError => errorMessage != null;
  bool get isEmpty => equiposCompletos.isEmpty && !isLoading && !hasError;
  int get equiposCount => equiposCompletos.length;
}

// ========== VIEWMODEL LIMPIO ==========
class ClienteDetailScreenViewModel extends ChangeNotifier {
  final Logger _logger = Logger();
  final EquipoClienteRepository _repository = EquipoClienteRepository();

  // ========== ESTADO INTERNO ==========
  ClienteDetailState _state = ClienteDetailState();
  Cliente? _cliente;

  // ========== STREAMS PARA EVENTOS ==========
  final StreamController<ClienteDetailUIEvent> _eventController =
  StreamController<ClienteDetailUIEvent>.broadcast();
  Stream<ClienteDetailUIEvent> get uiEvents => _eventController.stream;

  // ========== GETTERS PÚBLICOS ==========
  ClienteDetailState get state => _state;
  bool get isLoading => _state.isLoading;
  List<Map<String, dynamic>> get equiposCompletos => _state.equiposCompletos;
  List<EquipoCliente> get equiposAsignados => _state.equiposAsignados;
  String? get errorMessage => _state.errorMessage;
  bool get hasError => _state.hasError;
  bool get isEmpty => _state.isEmpty;
  int get equiposCount => _state.equiposCount;
  Cliente? get cliente => _cliente;

  @override
  void dispose() {
    _eventController.close();
    super.dispose();
  }

  // ========== INICIALIZACIÓN ==========
  Future<void> initialize(Cliente cliente) async {
    _cliente = cliente;
    await cargarEquiposAsignados();
  }

  // ========== CARGA DE DATOS ==========
  Future<void> cargarEquiposAsignados() async {
    _updateState(_state.copyWith(
      isLoading: true,
      errorMessage: null,
    ));

    try {
      if (_cliente?.id == null) {
        _setEquiposVacios();
        return;
      }

      final equiposDelCliente = await _repository.obtenerPorClienteCompleto(
        _cliente!.id!,
        soloActivos: true,
      );

      // Convertir los Map a objetos EquipoCliente para compatibilidad
      final equiposAsignados = equiposDelCliente.map((equipoData) {
        return EquipoCliente.fromMap(equipoData);
      }).toList();

      _updateState(_state.copyWith(
        isLoading: false,
        equiposCompletos: equiposDelCliente,
        equiposAsignados: equiposAsignados,
      ));

      _logger.i('Equipos cargados para cliente ${_cliente!.id}: ${equiposDelCliente.length}');
    } catch (e, stackTrace) {
      _logger.e('Error cargando equipos del cliente', error: e, stackTrace: stackTrace);

      _updateState(_state.copyWith(
        isLoading: false,
        errorMessage: 'Error cargando equipos: ${e.toString()}',
      ));

      _eventController.add(ShowErrorEvent('Error cargando equipos: ${e.toString()}'));
    }
  }

  void _setEquiposVacios() {
    _updateState(_state.copyWith(
      isLoading: false,
      equiposCompletos: [],
      equiposAsignados: [],
    ));
  }

  // ========== REFRESH ==========
  Future<void> refresh() async {
    await cargarEquiposAsignados();
    _eventController.add(RefreshCompletedEvent());
  }

  // ========== NAVEGACIÓN ==========
  void navegarAAsignarEquipo() {
    if (_cliente != null) {
      _eventController.add(NavigateToFormsEvent(_cliente!));
    }
  }

// En ClienteDetailScreenViewModel.dart
// Reemplaza el método navegarADetalleEquipo existente con este:

  void navegarADetalleEquipo(Map<String, dynamic> equipoData) {
    // Crear una copia del map con los campos mapeados correctamente
    final equipoDataCorregido = Map<String, dynamic>.from(equipoData);

    // Mapear los campos que vienen con nombres diferentes
    if (equipoData.containsKey('marca_nombre')) {
      equipoDataCorregido['equipo_marca'] = equipoData['marca_nombre'];
    }

    if (equipoData.containsKey('modelo_nombre')) {
      equipoDataCorregido['equipo_modelo'] = equipoData['modelo_nombre'];
    }

    // También mapear otros campos que podrían tener nombres diferentes
    if (equipoData.containsKey('equipo_nombre') && !equipoDataCorregido.containsKey('equipo_nombre')) {
      equipoDataCorregido['equipo_nombre'] = equipoData['equipo_nombre'];
    }

    // Log para debug
    _logger.i('Navegando a detalle con datos corregidos:');
    _logger.i('- marca_nombre: ${equipoData['marca_nombre']} → equipo_marca: ${equipoDataCorregido['equipo_marca']}');
    _logger.i('- modelo_nombre: ${equipoData['modelo_nombre']} → equipo_modelo: ${equipoDataCorregido['equipo_modelo']}');

    final equipoCliente = EquipoCliente.fromMap(equipoDataCorregido);

    // Log adicional para verificar que el mapeo funcionó
    _logger.i('EquipoCliente creado:');
    _logger.i('- equipoMarca: ${equipoCliente.equipoMarca}');
    _logger.i('- equipoModelo: ${equipoCliente.equipoModelo}');
    _logger.i('- equipoNombreCompleto: ${equipoCliente.equipoNombreCompleto}');

    _eventController.add(NavigateToEquipoDetailEvent(equipoCliente));
  }
  // ========== UTILIDADES PARA LA UI ==========
  String formatearFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/'
        '${fecha.month.toString().padLeft(2, '0')}/'
        '${fecha.year}';
  }

  String getEquipoTitle(Map<String, dynamic> equipoData) {
    final marca = equipoData['marca_nombre'] ?? 'Sin marca';
    final modelo = equipoData['modelo_nombre'] ?? 'Sin modelo';
    return '$marca $modelo';
  }

  String? getEquipoBarcode(Map<String, dynamic> equipoData) {
    final barcode = equipoData['equipo_cod_barras']?.toString();
    return barcode?.isNotEmpty == true ? barcode : null;
  }

  String? getEquipoLogo(Map<String, dynamic> equipoData) {
    final logo = equipoData['logo_nombre']?.toString();
    return logo?.isNotEmpty == true ? logo : null;
  }

  String getEquipoFechaCensado(Map<String, dynamic> equipoData) {
    final fechaStr = equipoData['fecha_asignacion'];
    if (fechaStr != null) {
      final fecha = DateTime.parse(fechaStr);
      return 'Censado: ${formatearFecha(fecha)}';
    }
    return 'Fecha no disponible';
  }

  // ========== INFORMACIÓN DEL CLIENTE ==========
  bool shouldShowPhone() {
    return _cliente?.telefono?.isNotEmpty == true;
  }

  bool shouldShowAddress() {
    return _cliente?.direccion?.isNotEmpty == true;
  }

  String getClientePhone() {
    return _cliente?.telefono ?? '';
  }

  String getClienteAddress() {
    return _cliente?.direccion ?? '';
  }

  String getClienteCreationDate() {
    return _cliente != null ? formatearFecha(_cliente!.fechaCreacion) : '';
  }

  // ========== MENSAJES PARA ESTADOS ==========
  String getEmptyStateTitle() {
    return 'Sin equipos censados';
  }

  String getEmptyStateSubtitle() {
    return 'Este cliente no tiene equipos censados actualmente';
  }

  String getErrorStateTitle() {
    return 'Error al cargar equipos';
  }

  String getLoadingMessage() {
    return 'Cargando equipos...';
  }

  // ========== MÉTODO PRIVADO ==========
  void _updateState(ClienteDetailState newState) {
    _state = newState;
    notifyListeners();
  }

  // ========== CALLBACK PARA RESULTADOS DE NAVEGACIÓN ==========
  void onNavigationResult(bool? result) {
    // Si se asignó un equipo exitosamente, recargar los datos
    if (result == true) {
      cargarEquiposAsignados();
    }
  }

  // ========== DEBUG INFO ==========
  Map<String, dynamic> getDebugInfo() {
    return {
      'cliente_id': _cliente?.id,
      'cliente_nombre': _cliente?.nombre,
      'equipos_count': _state.equiposCount,
      'is_loading': _state.isLoading,
      'has_error': _state.hasError,
      'is_empty': _state.isEmpty,
    };
  }

  void logDebugInfo() {
    _logger.d('ClienteDetailScreenViewModel Debug Info: ${getDebugInfo()}');
  }
}